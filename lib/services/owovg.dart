import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chan/models/owovg_post_extras.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/owovg_captcha.dart';
import 'package:chan/widgets/util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' show parse, parseFragment;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum OwoVgPostingBackend {
	direct,
	owoVg;

	static OwoVgPostingBackend fromIndex(int index) => OwoVgPostingBackend.values[index.clamp(0, OwoVgPostingBackend.values.length - 1)];
}

class OwoVgEmailVerificationProvider {
	final String id;
	final String label;
	final String? successColor;
	final String? stockDisplay;
	final String? successRateDisplay;
	final bool disabled;
	const OwoVgEmailVerificationProvider({
		required this.id,
		required this.label,
		this.successColor,
		this.stockDisplay,
		this.successRateDisplay,
		this.disabled = false
	});

	factory OwoVgEmailVerificationProvider.fromJson(Map json) => OwoVgEmailVerificationProvider(
		id: json['id'] as String? ?? '',
		label: json['label'] as String? ?? json['id'] as String? ?? '',
		successColor: json['successColor'] as String?,
		stockDisplay: json['stockDisplay'] as String?,
		successRateDisplay: json['successRateDisplay'] as String?,
		disabled: json['disabled'] as bool? ?? false || json['stockKind'] == 'wip'
	);
}

class OwoVgMeta {
	final bool gold;
	final String? metathreadUrl;
	final String? news;
	final String? ipMarkup;
	final List<OwoVgEmailVerificationProvider> emailVerificationProviders;
	const OwoVgMeta({
		required this.gold,
		this.metathreadUrl,
		this.news,
		this.ipMarkup,
		this.emailVerificationProviders = const []
	});

	factory OwoVgMeta.fromJson(Map json) => OwoVgMeta(
		gold: json['gold'] as bool? ?? false,
		metathreadUrl: json['mt'] as String?,
		news: json['n'] as String?,
		ipMarkup: json['ipmarkup'] as String?,
		emailVerificationProviders: (json['emailVerificationProviders'] as List?)?.cast<Map>().map(OwoVgEmailVerificationProvider.fromJson).toList() ?? const []
	);
}

class OwoVgException implements Exception {
	final String message;
	const OwoVgException(this.message);
	@override
	String toString() => message;
}

const _owoVgCookieNames = {'pass_id', 'ecker_pass', 'cf_clearance'};

class OwoVgService {
	static OwoVgMeta? _cachedMeta;
	static DateTime? _cachedMetaAt;
	static OwoVgPostExtras? pendingExtras;

	static String userAgentFor(Site4Chan site) {
		final settings = Settings.instance;
		var installDate = settings.owoVgInstallDate;
		if (installDate == null) {
			installDate = DateTime.now().millisecondsSinceEpoch ~/ 1000;
			settings.owoVgInstallDate = installDate;
		}
		return 'chance-$installDate';
	}

	static Uri _baseUri(Site4Chan site) => Uri.https(site.owoVgUrl);

	static Future<String> _cookieHeader(Site4Chan site) async {
		final uri = _baseUri(site);
		final cookies = await Persistence.currentCookies.loadForRequest(uri);
		return cookies.where((c) => _owoVgCookieNames.contains(c.name)).map((c) => '${c.name}=${c.value}').join('; ');
	}

	static Future<void> _saveCookiesFromResponse(Site4Chan site, Response response) async {
		final uri = _baseUri(site);
		final setCookies = response.headers.map['set-cookie'];
		if (setCookies == null) {
			return;
		}
		final cookieJar = Persistence.currentCookies;
		for (final raw in setCookies) {
			final parts = raw.split(';').first.split('=');
			if (parts.length < 2) {
				continue;
			}
			final name = parts.first.trim();
			if (!_owoVgCookieNames.contains(name)) {
				continue;
			}
			final value = parts.sublist(1).join('=');
			await cookieJar.saveFromResponse(uri, [Cookie(name, value)]);
		}
	}

	static Future<OwoVgMeta> fetchMeta(Site4Chan site, {String? board, int? thread, bool forceRefresh = false}) async {
		if (!forceRefresh && _cachedMeta != null && _cachedMetaAt != null && DateTime.now().difference(_cachedMetaAt!) < const Duration(minutes: 5)) {
			return _cachedMeta!;
		}
		final query = <String, String>{
			if (board != null) 'board': board,
			if (thread != null) 'thread': thread.toString()
		};
		final response = await site.client.getUri<Map>(
			_baseUri(site).replace(path: '/meta', queryParameters: query.isEmpty ? null : query),
			options: Options(
				responseType: ResponseType.json,
				headers: {
					'user-agent': userAgentFor(site),
					'origin': _baseUri(site).origin,
					'referer': '${_baseUri(site).origin}/',
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			)
		);
		await _saveCookiesFromResponse(site, response);
		final meta = OwoVgMeta.fromJson(response.data as Map);
		_cachedMeta = meta;
		_cachedMetaAt = DateTime.now();
		return meta;
	}

	static void invalidateMetaCache() {
		_cachedMeta = null;
		_cachedMetaAt = null;
	}

	static List<(String, String)> parseRecycleIpOptions(String? ipMarkup) {
		if (ipMarkup == null || ipMarkup.isEmpty) {
			return const [('all', 'All')];
		}
		final fragment = parseFragment(ipMarkup);
		final options = <(String, String)>[];
		for (final option in fragment.querySelectorAll('option')) {
			final value = option.attributes['value'];
			if (value == null || value.isEmpty) continue;
			options.add((value, option.text.trim().isEmpty ? value : option.text.trim()));
		}
		return options.isEmpty ? const [('all', 'All')] : options;
	}

	static Future<String> submitFeedback(Site4Chan site, String message) async {
		final trimmed = message.trim();
		if (trimmed.isEmpty) {
			throw const OwoVgException('Empty feedback');
		}
		final response = await site.client.postUri<String>(
			_baseUri(site).replace(path: '/eck_feedback'),
			data: trimmed,
			options: Options(
				responseType: ResponseType.plain,
				contentType: 'text/plain',
				headers: {
					'user-agent': userAgentFor(site),
					'origin': _baseUri(site).origin,
					'referer': '${_baseUri(site).origin}/',
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			)
		);
		await _saveCookiesFromResponse(site, response);
		return response.data?.trim().isNotEmpty == true ? response.data!.trim() : 'Feedback sent!';
	}

	static Future<FormData> buildPostFormData({
		required Site4Chan site,
		required DraftPost post,
		required EncodedWebPost encoded,
		CaptchaSolution? captchaSolution,
		OwoVgPostExtras extras = OwoVgPostExtras.empty
	}) async {
		final settings = Settings.instance;
		final meta = await fetchMeta(site, board: post.board, thread: post.threadId);
		final peeFiles = <MultipartFile>[
			for (final path in extras.peeFiles)
				await MultipartFile.fromFile(path, filename: path.afterLast('/'))
		];
		final formData = FormData.fromMap({
			'mode': 'regist',
			if (post.threadId != null) 'resto': post.threadId.toString(),
			...encoded.fields,
			'eck_pool': settings.owoVgPool,
			if (settings.owoVgManualCaptcha) 'manualcaptcha': 'on',
			if (meta.gold && settings.owoVgEmailIps) 'emailips': 'on',
			if (meta.gold) 'recycleips': settings.owoVgRecycleIps,
			if (meta.gold && settings.owoVgEmailVerificationStock.isNotEmpty) 'emailVerificationStock': settings.owoVgEmailVerificationStock,
			if (settings.owoVgRecompression) 'recompression': 'on',
			if (settings.owoVgAntiphash) 'antiphash': 'on',
			if (extras.fakeThumbnail case final thumbnail?) 'thumbnail': await MultipartFile.fromFile(thumbnail, filename: thumbnail.afterLast('/')),
			if (extras.peeText?.trim().isNotEmpty ?? false) 'peetxt': extras.peeText!.trim(),
		});
		formData.files.addAll([
			for (final file in peeFiles) MapEntry('pee', file)
		]);
		return formData;
	}

	static Future<(Uint8List body, String contentType)> _encodeFormData(FormData formData) async {
		final contentType = 'multipart/form-data; boundary=${formData.boundary}';
		final body = Uint8List.fromList(await formData.finalize().fold<List<int>>([], (a, b) => a + b));
		return (body, contentType);
	}

	static void _notify(String message, {bool warning = false, bool error = false}) {
		final context = ImageboardRegistry.instance.context;
		final plain = _plainNotificationText(message);
		if (context == null || !context.mounted) {
			print('[owo.vg] $plain');
			return;
		}
		showToast(
			context: context,
			message: plain,
			icon: error ? CupertinoIcons.xmark_circle : warning ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.info,
			duration: error ? const Duration(seconds: 5) : const Duration(seconds: 2)
		);
	}

	static String _plainNotificationText(String html) {
		final trimmed = html.trim();
		if (trimmed.isEmpty) {
			return trimmed;
		}
		if (!trimmed.contains('<')) {
			return trimmed;
		}
		final fragment = parseFragment(trimmed);
		final spanText = fragment.querySelector('span')?.text.trim();
		if (spanText != null && spanText.isNotEmpty) {
			return spanText;
		}
		final bodyText = fragment.text?.trim();
		return (bodyText != null && bodyText.isNotEmpty) ? bodyText : trimmed;
	}

	static Future<void> _applyDeferredCookie(Site4Chan site) async {
		final response = await site.client.getUri(
			_baseUri(site).replace(path: '/ws/set-cookie'),
			options: Options(
				responseType: ResponseType.plain,
				validateStatus: (x) => x == 204 || x == 404,
				headers: {
					'user-agent': userAgentFor(site),
					'origin': _baseUri(site).origin,
					'referer': '${_baseUri(site).origin}/',
				},
				extra: {
					kPriority: RequestPriority.interactive
				}
			)
		);
		await _saveCookiesFromResponse(site, response);
	}

	static Future<PostReceipt> submitPost({
		required Site4Chan site,
		required DraftPost post,
		required EncodedWebPost encoded,
		CaptchaSolution? captchaSolution,
		required CancelToken cancelToken
	}) async {
		final formData = await buildPostFormData(
			site: site,
			post: post,
			encoded: encoded,
			captchaSolution: captchaSolution,
			extras: pendingExtras ?? OwoVgPostExtras.empty
		);
		pendingExtras = null;
		final (body, contentType) = await _encodeFormData(formData);
		final targetUrl = 'https://${site.owoVgUrl}/${post.board}/post';
		final cookieHeader = await _cookieHeader(site);

		final completer = Completer<PostReceipt>();
		WebSocketChannel? channel;
		StreamSubscription? subscription;
		var responseStarted = false;

		void cleanup() {
			subscription?.cancel();
			subscription = null;
			channel?.sink.close();
			channel = null;
		}

		void applyDeferredCookieLater(int? cookieFlag) {
			if (cookieFlag == 1) {
				unawaited(_applyDeferredCookie(site).catchError((Object e) {
					print('[owo.vg] deferred cookie failed: $e');
				}));
			}
		}

		cancelToken.whenCancel.then((_) {
			if (!completer.isCompleted) {
				cleanup();
				completer.completeError(CancelException());
			}
		});

		try {
			channel = IOWebSocketChannel.connect(
				Uri.parse('wss://${site.owoVgUrl}/ws'),
				headers: {
					'user-agent': userAgentFor(site),
					'origin': _baseUri(site).origin,
					if (cookieHeader.isNotEmpty) 'cookie': cookieHeader,
				}
			);

			subscription = channel!.stream.listen((event) async {
				if (completer.isCompleted) {
					return;
				}
				Map res;
				try {
					res = jsonDecode(event as String) as Map;
				}
				catch (e) {
					return;
				}
				switch (res['t']) {
					case 'hb':
						break;
					case 'info':
						_notify(res['d'] as String? ?? '');
						break;
					case 'tag':
						_notify(res['d'] as String? ?? '');
						break;
					case 'warn':
						_notify(res['d'] as String? ?? '', warning: true);
						break;
					case 'interactive':
						final html = res['d'] as String? ?? '';
						final context = ImageboardRegistry.instance.context;
						if (context == null || !context.mounted) {
							completer.completeError(const OwoVgException('Captcha required but no UI context available'));
							cleanup();
							return;
						}
						final solved = await showOwoVgCaptchaDialog(
							context: context,
							site: site,
							request: site.makeCaptchaRequest(post.board, post.threadId),
							html: html,
							sendMessage: (payload) {
								channel?.sink.add(jsonEncode(payload));
							}
						);
						if (!solved) {
							completer.completeError(const OwoVgException('Captcha cancelled'));
							cleanup();
						}
						break;
					case 'res':
						responseStarted = true;
						try {
							final html = res['d'] as String? ?? '';
							final receipt = _parseSuccessHtml(post, encoded, html);
							if (!completer.isCompleted) {
								completer.complete(receipt);
							}
							cleanup();
							applyDeferredCookieLater(res['c'] as int?);
						}
						catch (e) {
							if (!completer.isCompleted) {
								completer.completeError(e);
							}
							cleanup();
							applyDeferredCookieLater(res['c'] as int?);
						}
						break;
					case 'error':
						responseStarted = true;
						final html = res['d'] as String? ?? 'Post failed';
						if (!completer.isCompleted) {
							completer.completeError(OwoVgException(_extractErrorMessage(html)));
						}
						cleanup();
						applyDeferredCookieLater(res['c'] as int?);
						break;
				}
			}, onError: (Object e) {
				if (!completer.isCompleted) {
					cleanup();
					completer.completeError(OwoVgException('WebSocket error: $e'));
				}
			}, onDone: () {
				if (completer.isCompleted || responseStarted) {
					return;
				}
				Future<void>.delayed(const Duration(seconds: 2), () {
					if (!completer.isCompleted && !responseStarted) {
						cleanup();
						completer.completeError(const OwoVgException('Connection closed before post completed'));
					}
				});
			});

			channel!.sink.add(jsonEncode({
				't': 'req',
				'd': {
					'm': base64Encode(body),
					'ct': contentType,
					'u': targetUrl
				}
			}));

			_notify('Submitting post via owo.vg...');
			return await completer.future;
		}
		catch (e) {
			cleanup();
			rethrow;
		}
	}

	static PostReceipt _parseSuccessHtml(DraftPost post, EncodedWebPost encoded, String html) {
		final id = _parsePostIdFromSuccessHtml(html);
		if (id != null) {
			return PostReceipt(
				post: post,
				id: id,
				password: encoded.password,
				name: post.name ?? '',
				options: post.options ?? '',
				time: DateTime.now()
			);
		}
		final document = parse(html);
		final errSpan = document.querySelector('#errmsg');
		if (errSpan != null) {
			throw PostFailedException(_extractErrorMessage(html));
		}
		throw PostFailedException(_extractErrorMessage(html));
	}

	static int? _parsePostIdFromSuccessHtml(String html) {
		final document = parse(html);
		final content = document.querySelector('meta[http-equiv="refresh"]')?.attributes['content'];
		if (content != null) {
			final hashMatch = RegExp(r'#p(\d+)').firstMatch(content);
			if (hashMatch != null) {
				return int.tryParse(hashMatch.group(1)!);
			}
			final parts = content.split(RegExp(r'\/|(#p)')).where((part) => part.isNotEmpty);
			for (final part in parts.toList().reversed) {
				final id = int.tryParse(part);
				if (id != null) {
					return id;
				}
			}
		}
		final commentMatch = RegExp(r'thread:\d+,no:(\d+)').firstMatch(html);
		if (commentMatch != null) {
			return int.tryParse(commentMatch.group(1)!);
		}
		return null;
	}

	static String _extractErrorMessage(String html) {
		final document = parse(html);
		final errSpan = document.querySelector('#errmsg');
		if (errSpan != null) {
			final inner = errSpan.innerHtml.trim();
			if (inner.isNotEmpty) {
				return inner;
			}
			return errSpan.text.trim();
		}
		final stripped = document.body?.text.trim();
		if (stripped != null && stripped.isNotEmpty) {
			return stripped;
		}
		return html.length > 200 ? '${html.substring(0, 200)}...' : html;
	}
}

class CancelException implements Exception {}
