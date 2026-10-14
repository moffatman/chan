import 'dart:async';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/interceptor.dart';
import 'package:chan/services/priority_queue.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

final httpRateLimitQueue = PriorityQueue<RequestOptions, String>(
	groupKeyer: (options) => options.uri.host
);
final _budgets = <String, _RateLimitBudget>{};

class HttpRateLimitException extends ExtendedException {
	final Uri url;
	final DateTime waitUntil;
	final bool exhausted;
	HttpRateLimitException(this.url, this.waitUntil, {required this.exhausted});

	@override
	bool get isReportable => false;

	@override
	Map<String, FutureOr<void> Function(BuildContext)> get remedies => {
		'Reset timer': (context) {
			_budgets.remove(url.host);
			httpRateLimitQueue.reset(RequestOptions(path: url.toString()));
		}
	};

	@override
	String toString() => 'HttpRateLimitException(url: $url, waitUntil: $waitUntil, exhausted: $exhausted)';
}

class _RateLimitBudget {
	final Duration interval;
	final DateTime expires;
	final bool exhausted;
	_RateLimitBudget(this.interval, this.expires, {required this.exhausted});
}

/// Reddit-style reset headers contain seconds until the window ends.
Duration? getRateLimitDelay(Headers headers) {
	final remaining = double.tryParse(headers.value('x-ratelimit-remaining') ?? '');
	final reset = double.tryParse(headers.value('x-ratelimit-reset') ?? '');
	if (remaining == null || reset == null || !remaining.isFinite || !reset.isFinite || reset <= 0) {
		return null;
	}
	final milliseconds = 1000 * reset / (remaining < 1 ? 1 : remaining);
	if (!milliseconds.isFinite || milliseconds > 9007199254740991) {
		return null;
	}
	return Duration(milliseconds: milliseconds.ceil());
}

/// Register before HTTP429BackoffInterceptor to record headers before retries.
/// Queue slots cover dispatch only: never hold a budget slot during a request
/// or a 429 retry, since the retry must pass through this interceptor again.
class XRateLimitInterceptor extends InterceptorBase {
	final Duration maxWait;
	XRateLimitInterceptor({this.maxWait = const Duration(minutes: 1)});

	void _checkWait(RequestOptions options) {
		final delay = httpRateLimitQueue.getCurrentDelay(options);
		if (delay > Duration.zero && (
			options.priority == RequestPriority.lowest ||
			(options.priority == RequestPriority.interactive && delay > const Duration(seconds: 15)) ||
			delay > maxWait
		)) {
			throw HttpRateLimitException(
				options.uri,
				DateTime.now().add(delay),
				exhausted: _budgets[options.uri.host]?.exhausted ?? false
			);
		}
	}

	void _record(Response response) {
		final delay = getRateLimitDelay(response.headers);
		if (delay != null) {
			final reset = double.parse(response.headers.value('x-ratelimit-reset')!);
			final now = DateTime.now();
			final resetMilliseconds = reset * 1000;
			// DateTime supports at most 100 million days from the Unix epoch.
			if (!resetMilliseconds.isFinite || resetMilliseconds > 8640000000000000 - now.millisecondsSinceEpoch) {
				return;
			}
			_budgets[response.requestOptions.uri.host] = _RateLimitBudget(
				delay,
				now.add(Duration(milliseconds: resetMilliseconds.ceil())),
				exhausted: double.parse(response.headers.value('x-ratelimit-remaining')!) < 1
			);
			httpRateLimitQueue.defer(response.requestOptions, delay);
		}
	}

	@override
	Future<void> onRequestImpl(RequestOptions options, RequestInterceptorHandler handler) async {
		_checkWait(options);
		final turn = httpRateLimitQueue.start(options, priority: options.priority.index);
		try {
			if (options.cancelToken case final token?) {
				final cancellation = await Future.any<DioError?>([
					token.whenCancel,
					turn.then((_) => null)
				]);
				if (cancellation != null) {
					throw cancellation;
				}
			}
			else {
				await turn;
			}
			final budget = _budgets[options.uri.host];
			if (budget != null) {
				final remainingWindow = budget.expires.difference(DateTime.now());
				if (remainingWindow > Duration.zero) {
					httpRateLimitQueue.defer(options, budget.interval < remainingWindow ? budget.interval : remainingWindow);
				}
				else {
					_budgets.remove(options.uri.host);
				}
			}
		}
		finally {
			httpRateLimitQueue.end(options);
		}
		handler.next(options);
	}

	@override
	Future<void> onResponseImpl(Response response, ResponseInterceptorHandler handler) async {
		_record(response);
		handler.next(response);
	}

	@override
	Future<void> onErrorImpl(DioError err, ErrorInterceptorHandler handler) async {
		if (err.response case final response?) {
			_record(response);
		}
		handler.next(err);
	}
}
