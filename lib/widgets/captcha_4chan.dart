import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui show Image, ImageByteFormat, PictureRecorder;

import 'package:chan/services/captcha.dart';
import 'package:chan/services/captcha_4chan.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/css.dart';
import 'package:chan/services/hcaptcha.dart';
import 'package:chan/services/html_error.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/4chan.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/html.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;
import 'package:provider/provider.dart';

final _reusableChallenges = <Captcha4ChanCustomChallenge>[];
void _storeChallengeForReuse(Captcha4ChanCustomChallenge? challenge) {
	if (challenge == null) {
		return;
	}
	_reusableChallenges.add(challenge);
	Future.delayed(challenge.expiresAt.difference(DateTime.now()) + const Duration(seconds: 1), _cleanupChallenges);
}
void _cleanupChallenges() {
	final now = DateTime.now();
	_reusableChallenges.removeWhere((c) {
		if (c.expiresAt.isBefore(now)) {
			c.dispose();
			return true;
		}
		return false;
	});
}

bool _isFalsy(Object obj) {
	return {false, 0, '', null}.contains(obj);
}

typedef _CloudGuess = ({
	String answer,
	double confidence,
	String? ip
});

typedef CloudGuessedCaptcha4ChanCustom = ({
	Captcha4ChanCustomChallenge challenge,
	Chan4CustomCaptchaSolution solution,
	int? slide,
	bool confident
});

class Captcha4ChanCustomChallengeException extends ExtendedException {
	final String message;
	final bool cloudflare;
	const Captcha4ChanCustomChallengeException(this.message, this.cloudflare, {super.additionalFiles});

	@override
	String toString() => 'Failed to get 4chan captcha: $message';
	
	@override
	bool get isReportable => true;
}

class Captcha4ChanCustomChallengeCooldownException extends Captcha4ChanCustomChallengeException implements CooldownException {
	@override
	final DateTime tryAgainAt;
	const Captcha4ChanCustomChallengeCooldownException(super.message, super.cloudflare, this.tryAgainAt);

	@override
	String toString() => 'Failed to get 4chan captcha: $message';
}

Future<Captcha4ChanCustomChallenge> requestCaptcha4ChanCustomChallenge({
	required ImageboardSite site,
	required Chan4CustomCaptchaRequest request,
	RequestPriority priority = RequestPriority.interactive,
	HCaptchaSolution? hCaptchaSolution,
	CancelToken? cancelToken
}) async {
	final reusable = _reusableChallenges.tryFirstWhere((c) => c.isReusableFor(request, const Duration(seconds: 15)));
	if (reusable != null) {
		_reusableChallenges.remove(reusable);
		return reusable;
	}
	final Response challengeResponse = await site.client.getUri(request.challengeUrl.replace(
		queryParameters: {
			...request.challengeUrl.queryParameters,
			'ticket': await Persistence.currentCookies.readPseudoCookie(Site4Chan.kTicketPseudoCookieKey),
			if (hCaptchaSolution != null) 'ticket_resp': Uri.encodeComponent(hCaptchaSolution.token)
		}
	), options: Options(
		headers: request.challengeHeaders,
		extra: {
			kPriority: priority,
			// They started to add various clever JavaScript cookies in the page
			// Forcing kCloudflare=true to make sure it gets evaluated
			kCloudflare: true
		}
	), cancelToken: cancelToken);
	if (challengeResponse.statusCode != 200) {
		throw Captcha4ChanCustomChallengeException('Got status code ${challengeResponse.statusCode}', challengeResponse.cloudflare);
	}
	final Map data;
	if (challengeResponse.data case Map map) {
		data = map;
	}
	else if (challengeResponse.data case String str) {
		final match = RegExp(r'window.parent.postMessage\(({.*\}),').firstMatch(str);
		if (match == null) {
			throw Captcha4ChanCustomChallengeException(
				extractHtmlError(str) ?? 'Response doesn\'t match, 4chan must have changed their captcha system',
				challengeResponse.cloudflare,
				additionalFiles: {
					'challenge.txt': utf8.encode(str)
				}
			);
		}
		data = (jsonDecode(match.group(1)!) as Map)['twister'] as Map;
	}
	else {
		throw Exception('challengeResponse.data had wrong type: ${challengeResponse.data}');
	}
	final ticket = data['ticket'];
	if (ticket is Object) {
		if (_isFalsy(ticket)) {
			await Persistence.currentCookies.deletePseudoCookie(Site4Chan.kTicketPseudoCookieKey);
		}
		else {
			await Persistence.currentCookies.writePseudoCookie(Site4Chan.kTicketPseudoCookieKey, ticket.toString());
		}
	}
	if (site is Site4Chan) {
		site.resetCaptchaTicketTimer();
	}
	if (data['mpcd'] == true) {
		// hCaptcha block
		if (priority == RequestPriority.cosmetic || priority == RequestPriority.lowest) {
			throw const HeadlessSolveNotPossibleException();
		}
		if (hCaptchaSolution != null) {
			throw Captcha4ChanCustomChallengeException('Still got hCaptcha block even with $hCaptchaSolution', challengeResponse.cloudflare);
		}
		final hCaptchaKey = request.hCaptchaKey;
		if (hCaptchaKey == null) {
			throw Captcha4ChanCustomChallengeException('Got hCaptcha block, but don\'t know what key to use', challengeResponse.cloudflare);
		}
		final solution = await solveHCaptcha(site, HCaptchaRequest(
			/// Relatively safe page to load and replace
			hostPage: Uri.https(request.challengeUrl.host, '/robots.txt'),
			siteKey: hCaptchaKey,
		), cancelToken: cancelToken);
		// Retry with hCaptcha
		return await requestCaptcha4ChanCustomChallenge(
			site: site,
			request: request,
			priority: priority,
			hCaptchaSolution: solution,
			cancelToken: cancelToken
		);
	}
	return await unsafeAsync(data, () async {
		if (data['pcd'] case num pcd) {
			throw Captcha4ChanCustomChallengeCooldownException(data['pcd_msg'] as String? ?? 'Please wait a while.', challengeResponse.cloudflare, DateTime.now().add(Duration(seconds: pcd.toInt())));
		}
		final acquiredAt = DateTime.now();
		final DateTime? tryAgainAt;
		if (data['cd'] case num cd) {
			tryAgainAt = acquiredAt.add(Duration(seconds: cd.toInt()));
		}
		else {
			tryAgainAt = null;
		}
		if (data['error'] case String error) {
			if (tryAgainAt != null) {
				throw Captcha4ChanCustomChallengeCooldownException(error, challengeResponse.cloudflare, tryAgainAt);
			}
			throw Captcha4ChanCustomChallengeException(error, challengeResponse.cloudflare);
		}
		final challenge = data['challenge'] as String;
		final lifetime = Duration(seconds: (data['ttl'] as num).toInt());
		if (data['tasks'] case List rawTasks) {
			final tasks = <Captcha4ChanCustomChallengeTasksTask>[];
			for (final rawTask in rawTasks) {
				final choices = <ui.Image>[];
				for (final item in (rawTask as Map)['items'] as List) {
					final completer = Completer<ui.Image>();
					MemoryImage(base64Decode(item as String)).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
						completer.complete(info.image);
					}, onError: (e, st) {
						completer.completeError(e, st);
					}));
					choices.add(await completer.future);
				}
				tasks.add((choices: choices, text: rawTask['str'] as String));
			}
			return Captcha4ChanCustomChallengeTasks(
				request: request,
				challenge: challenge,
				acquiredAt: acquiredAt,
				tryAgainAt: tryAgainAt,
				lifetime: lifetime,
				cloudflare: challengeResponse.cloudflare,
				originalData: data,
				tasks: tasks
			);
		}
		Completer<ui.Image>? foregroundImageCompleter;
		if (data['img'] != null) {
			foregroundImageCompleter = Completer<ui.Image>();
			MemoryImage(base64Decode(data['img'] as String)).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
				foregroundImageCompleter!.complete(info.image);
			}, onError: (e, st) {
				foregroundImageCompleter!.completeError(e, st);
			}));
		}
		Completer<ui.Image>? backgroundImageCompleter;
		if (data['bg'] != null) {
			backgroundImageCompleter = Completer<ui.Image>();
			MemoryImage(base64Decode(data['bg'] as String)).resolve(const ImageConfiguration()).addListener(ImageStreamListener((info, isSynchronous) {
				backgroundImageCompleter!.complete(info.image);
			}, onError: (e, st) {
				backgroundImageCompleter!.completeError(e, st);
			}));
		}
		final foregroundImage = await foregroundImageCompleter?.future;
		final backgroundImage = await backgroundImageCompleter?.future;
		return Captcha4ChanCustomChallengeText(
			request: request,
			challenge: challenge,
			acquiredAt: acquiredAt,
			tryAgainAt: tryAgainAt,
			lifetime: lifetime,
			foregroundImage: foregroundImage,
			backgroundImage: backgroundImage,
			backgroundWidth: (data['bg_width'] as num?)?.toInt(),
			cloudflare: challengeResponse.cloudflare,
			originalData: data
		);
	});
}

Future<int> _alignImage(Captcha4ChanCustomChallengeText challenge) async {
	final fgWidth = challenge.foregroundImage!.width;
	final fgHeight = challenge.foregroundImage!.height;
	final fgBytes = (await challenge.foregroundImage!.toByteData())!;
	final bgWidth = challenge.backgroundImage!.width;
	final maxSlide = (challenge.backgroundWidth ?? bgWidth) - fgWidth;
	if (maxSlide <= 0) {
		return 0;
	}
	final toCheck = <({int x, int offset, int fgIdx})>[];
	final y0fg = (fgHeight * 0.2).floor();
	final y1fg = (fgHeight * 0.8).ceil();
	/// Just keep using same buffer, avoid an allocation
	final fgSortedColumn = Uint8List(y1fg - y0fg);
	final fgClearColumns = <int>[];
	for (int x = 2; x < fgWidth - 3; x++) {
		for (int y = y0fg; y < y1fg; y++) {
			final thisIndex = 4 * (x + (y * fgWidth));
			final thisRed = fgBytes.getUint8(thisIndex);
			fgSortedColumn[y - y0fg] = thisRed;
		}
		fgSortedColumn.sort();
		bool isClearColumn = true;
		for (int y = y0fg; y < y1fg; y++) {
			final thisIndex = 4 * (x + (y * fgWidth));
			final thisRed = fgBytes.getUint8(thisIndex);
			final thisA = fgBytes.getUint8(thisIndex + 3);
			if (thisA != 0) {
				isClearColumn = false;
			}
			final rightIndex1 = thisIndex + 4;
			final rightIndex2 = thisIndex + 8;
			final rightIndex3 = thisIndex + 12;
			final rightA1 = fgBytes.getUint8(rightIndex1 + 3);
			final rightA2 = fgBytes.getUint8(rightIndex2 + 3);
			final rightA3 = fgBytes.getUint8(rightIndex3 + 3);
			final downIndex1 = thisIndex + (4 * fgWidth);
			final downIndex2 = thisIndex + (8 * fgWidth);
			final downIndex3 = thisIndex + (12 * fgWidth);
			final downA1 = fgBytes.getUint8(downIndex1 + 3);
			final downA2 = fgBytes.getUint8(downIndex2 + 3);
			final downA3 = fgBytes.getUint8(downIndex3 + 3);
			final leftIndex1 = thisIndex - 4;
			final leftIndex2 = thisIndex - 8;
			final leftA1 = fgBytes.getUint8(leftIndex1 + 3);
			final leftA2 = fgBytes.getUint8(leftIndex2 + 3);
			final upIndex1 = thisIndex - (4 * fgWidth);
			final upIndex2 = thisIndex - (8 * fgWidth);
			final upA1 = fgBytes.getUint8(upIndex1 + 3);
			final upA2 = fgBytes.getUint8(upIndex2 + 3);
			if (thisA > rightA1 && thisA == leftA1 && thisA == leftA2 && rightA1 == rightA2 && rightA1 == rightA3) {
				// this is the opaque fg pixel
				final thisFgIdx = fgSortedColumn.binarySearchCountBefore((r) => r > thisRed);
				toCheck.add((x: x + 1, offset: 4 * (x + 1 + (y * bgWidth)), fgIdx: thisFgIdx));
			}
			else if (thisA < rightA1 && thisA == leftA1 && thisA == leftA2 && rightA1 == rightA2 && rightA1 == rightA3) {
				// this is the transparent fg pixel
				final rightRed = fgBytes.getUint8(rightIndex1);
				final rightFgIdx = fgSortedColumn.binarySearchCountBefore((r) => r > rightRed);
				toCheck.add((x: x, offset: 4 * (x + (y * bgWidth)), fgIdx: rightFgIdx));
			}
			if (thisA > downA1 && thisA == upA1 && thisA == upA2 && downA1 == downA2 && downA1 == downA3) {
				// this is the opaque fg pixel
				final thisFgIdx = fgSortedColumn.binarySearchCountBefore((r) => r > thisRed);
				toCheck.add((x: x, offset: 4 * (x + ((y + 1) * bgWidth)), fgIdx: thisFgIdx));
			}
			else if (thisA < downA1 && thisA == upA1 && thisA == upA2 && downA1 == downA2 && downA1 == downA3) {
				// this is the transparent fg pixel
				final downRed = fgBytes.getUint8(downIndex1);
				final downFgIdx = fgSortedColumn.binarySearchCountBefore((r) => r > downRed);
				toCheck.add((x: x, offset: 4 * (x + (y * bgWidth)), fgIdx: downFgIdx));
			}
		}
		if (isClearColumn) {
			fgClearColumns.add(x);
		}
	}
	final bgHeight = challenge.backgroundImage!.height;
	final bgBytes = (await challenge.backgroundImage!.toByteData())!;
	final y0bg = (bgHeight * 0.2).floor();
	final y1bg = (bgHeight * 0.8).ceil();
	final bgSortedColumns = List.generate(bgWidth, (_) => List.filled(y1bg - y0bg, 0), growable: false);
	for (int x = 0; x < bgWidth; x++) {
		for (int y = y0bg; y < y1bg; y++) {
			final thisIndex = 4 * (x + (y * bgWidth));
			final thisRed = bgBytes.getUint8(thisIndex);
			bgSortedColumns[x][y - y0bg] = thisRed;
		}
		bgSortedColumns[x].sort();
	}
	final bestDupes = List.filled(bgWidth, (mismatch: 2 << 50, sweep: -1));
	for (int x0 = 0; x0 < bgWidth - 5; x0++) {
		sweep_loop:
		for (final sweep in const [5, 6, 7, 8, 9, 11, 13]) {
			final x1 = x0 + sweep;
			if (x1 >= bgWidth) {
				continue;
			}
			int mismatch = 0;
			final bestMismatch = bestDupes[x0].mismatch;
			for (int y = 0; y < bgHeight; y++) {
				final r0 = bgBytes.getUint8(4 * (x0 + (y * bgWidth)));
				final r1 = bgBytes.getUint8(4 * (x1 + (y * bgWidth)));
				mismatch += (r1 - r0).abs();
				if (mismatch >= bestMismatch) {
					continue sweep_loop;
				}
			}
			bestDupes[x0] = (mismatch: mismatch, sweep: sweep);
			if (mismatch == 0) {
				// No point continuing to check
				break;
			}
		}
	}
	final dupeThreshold = 5 * bgHeight; // avg. 5px value diff
	final dupeCols = List.generate(bgWidth, (x) {
		return bestDupes[x].mismatch < dupeThreshold && x > 0 && (bestDupes[x - 1].sweep == bestDupes[x].sweep);
	});
	final emptyCols = List.generate(bgWidth, (x) {
		final mMin = bgSortedColumns[x].first;
		final mMax = bgSortedColumns[x].last;
		return
			mMin > 103 // no black
			|| (mMax - mMin) < 10; // <10 dynamic range in the column
	});
	// Some future optimization could be to ignore 1-2px horizontal lines here
	final bgSize = 4 * bgWidth * bgHeight;
	final halfBgHeight = (y1bg - y0bg) ~/ 2;
	final mismatches = List.filled(maxSlide, 0);
	final dupePenalty = bgHeight * 250;
	final emptyPenalty = (0.75 * dupePenalty).round();
	for (int xSlide = 0; xSlide < maxSlide; xSlide++) {
		int mismatch = 0;
		for (final x0 in fgClearColumns) {
			final x = x0 + xSlide;
			if (x >= bgWidth) {
				continue;
			}
			if (dupeCols[x]) {
				mismatch += dupePenalty;
			}
			if (emptyCols[x]) {
				mismatch += emptyPenalty;
			}
		}
		final offset = 4 * xSlide;
		for (int i = 0; i < toCheck.length; i++) {
			final check = toCheck[i];
			final pos = check.offset + offset;
			if (pos >= bgSize) {
				// Offscreen. Presumably this won't happen, they won't let you slide the end of background to be visible.
				// Since you may just start wrapping silently if not checking the last row.
				continue;
			}
			final thisRed = bgBytes.getUint8(pos);
			final bgIdx = bgSortedColumns[check.x + xSlide].binarySearchCountBefore((r) => r > thisRed);
			final diff = bgIdx - check.fgIdx;
			if (diff != 0) {
				// Weight mismatches at the extreme of color more
				mismatch += diff.abs() * (bgIdx - halfBgHeight).abs();
			}
		}
		mismatches[xSlide] = mismatch;
	}
	// Do some smoothing, the perfect slide should be
	// continuous, not abrupt, that more indicates a trick slide.
	int bestSlide = 0;
	double lowestMismatch = double.infinity;
	for (int x = 0; x < maxSlide; x++) {
		final double mismatch;
		if (x == 0) {
			mismatch = (mismatches[0] + mismatches[0] + mismatches[1]) / 3;
		}
		else if (x == maxSlide - 1) {
			mismatch = (mismatches[maxSlide - 2] + mismatches[maxSlide - 1] + mismatches[maxSlide - 1]) / 3;
		}
		else {
			mismatch = (mismatches[x - 1] + mismatches[x] + mismatches[x] + mismatches[x + 1]) / 4;
		}
		if (mismatch < lowestMismatch) {
			lowestMismatch = mismatch;
			bestSlide = x;
		}
	}
	return bestSlide;
}

Future<_CloudGuess> _cloudGuess({
	required ImageboardSite site,
	required ui.Image image,
	CancelToken? cancelToken
}) async {
	final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
	if (pngData == null) {
		throw Exception('Could not encode captcha image');
	}
	final bytes = pngData.buffer.asUint8List();
	final response = await site.client.postUri<String>(Uri.https('captcha.chance.surf', '/solve'), 
		data: bytes,
		options: Options(
			responseType: ResponseType.plain,
			headers: {
				Headers.contentLengthHeader: bytes.length.toString()
			},
			requestEncoder: (request, options) {
				return bytes;
			}
		),
		cancelToken: cancelToken
	).timeout(const Duration(seconds: 8));
	final answer = response.data!;
	if (answer.length > 10) {
		// Answer shouldn't be that long
		throw FormatException('Something seems wrong with cloud solver response', answer);
	}
	return (
		answer: answer,
		confidence: response.headers.value('Chance-Confidence')?.tryParseDouble ?? 0,
		ip: response.headers.value('Chance-X-Forwarded-For')
	);
}

Future<CloudGuessedCaptcha4ChanCustom?> headlessSolveCaptcha4ChanCustom({
	required ImageboardSite site,
	required Chan4CustomCaptchaRequest request,
	required RequestPriority priority,
	Captcha4ChanCustomChallenge? challenge,
	CancelToken? cancelToken
}) async {
	if (challenge?.isReusableFor(request, const Duration(seconds: 15)) == false) {
		challenge?.dispose();
		challenge = null;
	}
	try {
		challenge ??= await requestCaptcha4ChanCustomChallenge(
			site: site,
			request: request,
			priority: priority,
			cancelToken: cancelToken
		);
	}
	on Captcha4ChanCustomChallengeCooldownException catch (first) {
		if (!first.cloudflare || !request.stickyCloudflare) {
			rethrow;
		}
		// If we cleared cloudflare on challenge
		// Just try again, we appparently will get a better captcha
		// This is also meaningful, because we can have an actual HTTP socket to
		// KeepAlive (for the T-Mobile IPv4 CGNAT issue)
		await Future.delayed(const Duration(seconds: 1));
		try {
			challenge = await requestCaptcha4ChanCustomChallenge(
				site: site,
				request: request,
				priority: RequestPriority.cosmetic,
				cancelToken: cancelToken
			);
		}
		on DioError catch (second) {
			if (second.error is! CloudflareHandlerNotAllowedException) {
				rethrow;
			}
			throw first;
		}
	}

	if (challenge is! Captcha4ChanCustomChallengeText) {
		// Other captcha types not auto-solvable
		return null;
	}

	final Chan4CustomCaptchaSolution solution;
	final bool confident;
	int? slide;

	if (challenge.foregroundImage == null && challenge.backgroundImage == null) {
		if (challenge.instantSolution case Chan4CustomCaptchaSolution instantSolution) {
			solution = instantSolution;
			confident = true;
		}
		else {
			throw Captcha4ChanCustomException('Unknown error, maybe the captcha format has changed: ${challenge.challenge}');
		}
	}
	else {
		final ui.Image image;

		if (challenge.backgroundImage != null) {
			slide = await _alignImage(challenge);
			final recorder = ui.PictureRecorder();
			final canvas = Canvas(recorder);
			final width = challenge.foregroundImage!.width;
			final height = challenge.foregroundImage!.height;
			_Captcha4ChanCustomPainter(
				backgroundImage: challenge.backgroundImage,
				foregroundImage: challenge.foregroundImage!,
				backgroundSlide: slide
			).paint(canvas, Size(width.toDouble(), height.toDouble()));
			image = await recorder.endRecording().toImage(width, height);
		}
		else {
			// Need to clone it to dispose properly in both places
			image = challenge.foregroundImage!.clone();
		}

		final cloudGuess = await _cloudGuess(
			site: site,
			image: image,
			cancelToken: cancelToken
		);

		solution = Chan4CustomCaptchaSolution(
			challenge: challenge.challenge,
			response: cloudGuess.answer,
			acquiredAt: challenge.acquiredAt,
			lifetime: challenge.lifetime,
			originalData: challenge.originalData,
			slide: slide,
			cloudflare: challenge.cloudflare,
			ip: cloudGuess.ip,
			autoSolved: true
		);
		confident = cloudGuess.confidence >= 1;
	}

	return (
		challenge: challenge,
		solution: solution,
		slide: slide,
		confident: confident
	);
}

class _ModifiedBouncingScrollSimulation extends Simulation {
  _ModifiedBouncingScrollSimulation({
    required double position,
    required double velocity,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.spring,
    Tolerance tolerance = Tolerance.defaultTolerance,
  }): assert(leadingExtent <= trailingExtent), super(tolerance: tolerance) {
    if (position < leadingExtent) {
      _springSimulation = _underscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else if (position > trailingExtent) {
      _springSimulation = _overscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else {
      // Modified to increase friction
      _frictionSimulation = FrictionSimulation(0.0004, position, velocity);
      final double finalX = _frictionSimulation.finalX;
      if (velocity > 0.0 && finalX > trailingExtent) {
        _springTime = _frictionSimulation.timeAtX(trailingExtent);
        _springSimulation = _overscrollSimulation(
          trailingExtent,
          min(_frictionSimulation.dx(_springTime), maxSpringTransferVelocity),
        );
        assert(_springTime.isFinite);
      } else if (velocity < 0.0 && finalX < leadingExtent) {
        _springTime = _frictionSimulation.timeAtX(leadingExtent);
        _springSimulation = _underscrollSimulation(
          leadingExtent,
          min(_frictionSimulation.dx(_springTime), maxSpringTransferVelocity),
        );
        assert(_springTime.isFinite);
      } else {
        _springTime = double.infinity;
      }
    }
  }

  static const double maxSpringTransferVelocity = 5000.0;

  final double leadingExtent;

  final double trailingExtent;

  final SpringDescription spring;

  late FrictionSimulation _frictionSimulation;
  late Simulation _springSimulation;
  late double _springTime;
  double _timeOffset = 0.0;

  Simulation _underscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, leadingExtent, dx);
  }

  Simulation _overscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, trailingExtent, dx);
  }

  Simulation _simulation(double time) {
    final Simulation simulation;
    if (time > _springTime) {
      _timeOffset = _springTime.isFinite ? _springTime : 0.0;
      simulation = _springSimulation;
    } else {
      _timeOffset = 0.0;
      simulation = _frictionSimulation;
    }
    return simulation..tolerance = tolerance;
  }

  @override
  double x(double time) => _simulation(time).x(time - _timeOffset);

  @override
  double dx(double time) => _simulation(time).dx(time - _timeOffset);

  @override
  bool isDone(double time) => _simulation(time).isDone(time - _timeOffset);

  @override
  String toString() {
    return '${objectRuntimeType(this, '_ModifiedBouncingScrollSimulation')}(leadingExtent: $leadingExtent, trailingExtent: $trailingExtent)';
  }
}

class _ModifiedBouncingScrollPhysics extends BouncingScrollPhysics {
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return _ModifiedBouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
      );
    }
    return null;
  }

	@override
	String toString() => '_ModifiedBouncingScrollPhysics()';
}

class Captcha4ChanCustom extends StatefulWidget {
	final ImageboardSite site;
	final Chan4CustomCaptchaRequest request;
	final ValueChanged<Chan4CustomCaptchaSolution?> onCaptchaSolved;
	final CloudGuessedCaptcha4ChanCustom? initialCloudGuess;
	final Captcha4ChanCustomChallenge? initialChallenge;
	final (Object, StackTrace)? initialChallengeException;
	final ValueChanged<DateTime>? onTryAgainAt;

	const Captcha4ChanCustom({
		required this.site,
		required this.request,
		required this.onCaptchaSolved,
		this.initialCloudGuess,
		this.initialChallenge,
		this.initialChallengeException,
		this.onTryAgainAt,
		Key? key
	}) : super(key: key);

	@override
	createState() => _Captcha4ChanCustomState();
}

class Captcha4ChanCustomException implements Exception {
	String message;
	Captcha4ChanCustomException(this.message);

	@override
	String toString() => '4chan captcha error: $message';
}

sealed class Captcha4ChanCustomChallenge {
	final Chan4CustomCaptchaRequest request;
	final String challenge;
	final DateTime acquiredAt;
	final DateTime? tryAgainAt;
	final Duration lifetime;
	DateTime get expiresAt => acquiredAt.add(lifetime);
	final bool cloudflare;
	final Map originalData;
	bool _isDisposed = false;

	Captcha4ChanCustomChallenge({
		required this.request,
		required this.challenge,
		required this.acquiredAt,
		required this.tryAgainAt,
		required this.lifetime,
		required this.cloudflare,
		required this.originalData
	});

	bool isReusableFor(Chan4CustomCaptchaRequest request, Duration validityPeriod) {
		return !_isDisposed && this.request == request && expiresAt.isAfter(DateTime.now().add(validityPeriod));
	}

	bool get isNoop;

	Chan4CustomCaptchaSolution? get instantSolution {
		if (challenge == 'noop' && isNoop) {
			return Chan4CustomCaptchaSolution(
				challenge: 'noop',
				response: '',
				acquiredAt: acquiredAt,
				lifetime: lifetime,
				originalData: originalData,
				cloudflare: cloudflare,
				slide: null,
				ip: null
			);
		}
		return null;
	}

	@override
	String toString() => 'Captcha4ChanCustomChallenge(request: $request, challenge: $challenge, expiresAt: $expiresAt, cloudflare: $cloudflare)';

	void _disposeImpl();

	void dispose() {
		if (!_isDisposed) {
			_isDisposed = true;
			_disposeImpl();
		}
	}
}

class Captcha4ChanCustomChallengeText extends Captcha4ChanCustomChallenge {
	final ui.Image? foregroundImage;
	final ui.Image? backgroundImage;
	final int? backgroundWidth;

	Captcha4ChanCustomChallengeText({
		required super.request,
		required super.challenge,
		required super.acquiredAt,
		required super.tryAgainAt,
		required super.lifetime,
		required super.cloudflare,
		required super.originalData,
		required this.foregroundImage,
		required this.backgroundImage,
		required this.backgroundWidth
	});

	Future<ui.Image> _screenshotImage(int backgroundSlide) {
		final recorder = ui.PictureRecorder();
		final canvas = Canvas(recorder);
		final width = foregroundImage!.width;
		final height = foregroundImage!.height;
		_Captcha4ChanCustomPainter(
			backgroundImage: backgroundImage,
			foregroundImage: foregroundImage!,
			backgroundSlide: backgroundSlide
		).paint(canvas, Size(width.toDouble(), height.toDouble()));
		return recorder.endRecording().toImage(width, height);
	}

	@override
	bool get isNoop => foregroundImage == null && backgroundImage == null;

	@override
	void _disposeImpl() {
		foregroundImage?.dispose();
		backgroundImage?.dispose();
	}
}

typedef Captcha4ChanCustomChallengeTasksTask = ({List<ui.Image> choices, String text});

class Captcha4ChanCustomChallengeTasks extends Captcha4ChanCustomChallenge {
	final List<Captcha4ChanCustomChallengeTasksTask> tasks;

	Captcha4ChanCustomChallengeTasks({
		required super.request,
		required super.challenge,
		required super.acquiredAt,
		required super.tryAgainAt,
		required super.lifetime,
		required super.cloudflare,
		required super.originalData,
		required this.tasks
	});

	@override
	bool get isNoop => tasks.isEmpty;

	@override
	void _disposeImpl() {
		for (final task in tasks) {
			for (final choice in task.choices) {
				choice.dispose();
			}
		}
	}
}

class _Captcha4ChanCustomPainter extends CustomPainter{
	final ui.Image foregroundImage;
	final ui.Image? backgroundImage;
	final int backgroundSlide;

	_Captcha4ChanCustomPainter({
		required this.foregroundImage,
		required this.backgroundImage,
		required this.backgroundSlide
	});

	@override
	void paint(Canvas canvas, Size size) {
		final double height = foregroundImage.height.toDouble();
		final double width = foregroundImage.width.toDouble();
		bool fgSlide = false;
		if (backgroundImage != null) {
			fgSlide = backgroundImage!.width < foregroundImage.width;
			canvas.drawImageRect(
				backgroundImage!,
				Rect.fromLTWH(fgSlide ? 0 : backgroundSlide.toDouble(), 0, width, height),
				Rect.fromLTWH(0, 0, size.width, size.height),
				Paint()
			);
		}
		canvas.drawImageRect(
			foregroundImage,
			Rect.fromLTWH(fgSlide ? backgroundSlide.toDouble() : 0, 0, width, height),
			Rect.fromLTWH(0, 0, size.width, size.height),
			Paint()
		);
	}

	@override
	bool shouldRepaint(_Captcha4ChanCustomPainter oldDelegate) {
		return foregroundImage != oldDelegate.foregroundImage ||
		       backgroundImage != oldDelegate.backgroundImage ||
					 backgroundSlide != oldDelegate.backgroundSlide;
	}
}

typedef _PickerStuff = ({GlobalKey key, UniqueKey wrapperKey, FixedExtentScrollController controller});

class _Captcha4ChanCustomState extends State<Captcha4ChanCustom> {
	(Object, StackTrace)? error;
	DateTime? tryAgainAt;
	Captcha4ChanCustomChallenge? challenge;
	int backgroundSlide = 0;
	final GlobalKey<AdaptiveTextFieldState> _solutionKey = GlobalKey(debugLabel: '_Captcha4ChanCustomState._solutionKey');
	late final FocusNode _solutionNode;
	late final TextEditingController _solutionController;
	List<double> _guessConfidences = List.generate(6, (i) => 1.0);
	Chan4CustomCaptchaGuesses? _lastGuesses;
	late Chan4CustomCaptchaGuess _lastGuess;
	bool get _greyOutPickers => cancelToken != null;
	final Map<Chan4CustomCaptchaLetterKey, _PickerStuff> _pickerStuff = {};
	final List<_PickerStuff> _orphanPickerStuff = [];
	List<int?> _taskChoices = [];
	bool _cloudGuessFailed = false;
	String? _lastCloudGuess;
	String? _ip;
	CancelToken? cancelToken;

	int get numLetters => Settings.instance.captcha4ChanCustomNumLetters;
	set numLetters(int setting) => Settings.captcha4ChanCustomNumLettersSetting.value = setting;

	bool get useNewCaptchaForm => Settings.instance.useNewCaptchaForm && widget.request.possibleLetterCounts.isNotEmpty;

	Future<void> _animateCloudGuess() async {
		cancelToken?.cancel();
		final thisCancelToken = cancelToken = CancelToken();
		setState(() {});
		try {
			final image = await (challenge as Captcha4ChanCustomChallengeText)._screenshotImage(backgroundSlide);
			final guess = await _cloudGuess(
				site: widget.site,
				image: image,
				cancelToken: thisCancelToken
			);
			_ip = guess.ip ?? _ip;
			_useCloudGuess(guess.answer);
		}
		catch (e, st) {
			if (!thisCancelToken.isCancelled) {
				if (mounted) {
					showToast(
						context: context,
						icon: CupertinoIcons.exclamationmark_triangle,
						message: 'Cloud solver failed: ${e.toStringDio()}'
					);
				}
				Future.error(e, st);
				_cloudGuessFailed = true;
			}
		}
		if (cancelToken == thisCancelToken) {
			cancelToken = null;
		}
		if (mounted) {
			setState(() {});
		}
	}

	void _useCloudGuess(String answer) {
		_lastCloudGuess = answer;
		final newGuess = Chan4CustomCaptchaGuess.dummy(answer);
		_lastGuess = newGuess;
		_lastGuesses = Chan4CustomCaptchaGuesses.dummy(answer, max(answer.length, 10));
		numLetters = newGuess.numLetters;
		final selection = _solutionController.selection;
		_previousText = ''; // Force animation of all pickers
		_solutionController.text = newGuess.guess;
		_solutionController.selection = TextSelection(
			baseOffset: min(numLetters - 1, selection.baseOffset),
			extentOffset: min(numLetters, selection.extentOffset)
		);
		_guessConfidences = newGuess.confidences.toList();
		if (mounted && context.read<MouseSettings>().supportMouse) {
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionNode.requestFocus();
		}
		setState(() {}); // numLetters may have changed
	}

	void _animateLocalGuess() {
		try {
			_lastGuesses = Chan4CustomCaptchaGuesses.dummy('000000', 10);
			numLetters = _lastGuesses!.likelyNumLetters;
			final selection = _solutionController.selection;
			final lastResolvedPickerStuff = {
				for (int i = 0; i < _pickerStuff.length; i++)
					i: _getPickerStuffForWidgetIndex(i)
			};
			_pickerStuff.clear();
			final newGuess = _lastGuesses!.forNumLetters(numLetters);
			_lastGuess = newGuess;
			// We want widget-indexes to match up to same pickerStuff, not to keys
			for (int i = 0; i < numLetters; i++) {
				final key = newGuess.keys[i];
				final previousPickerStuffInThisSlot = lastResolvedPickerStuff.remove(i);
				if (previousPickerStuffInThisSlot != null) {
					_pickerStuff[key] = previousPickerStuffInThisSlot;
				}
			}
			for (final orphan in lastResolvedPickerStuff.values) {
				_orphanPickerStuff.add(orphan);
			}
			_previousText = ''; // Force animation of all pickers
			_solutionController.text = newGuess.guess;
			_solutionController.selection = TextSelection(
				baseOffset: min(numLetters - 1, selection.baseOffset),
				extentOffset: min(numLetters, selection.extentOffset)
			);
			_guessConfidences = newGuess.confidences.toList();
			setState(() {}); // numLetters may have changed
		}
		catch (e, st) {
			print(e);
			print(st);
		}
		if (mounted) {
			// Always focus text box, since the guess is garbage
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionNode.requestFocus();
		}
	}

	Future<void> _animateGuess() async {
		Settings.useCloudCaptchaSolverSetting.value ??= await showAdaptiveDialog<bool>(
			context: context,
			barrierDismissible: true,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Use cloud captcha solver?'),
				content: const Text('Use a machine-learning captcha solving model which is hosted on a web server to provide better captcha solver guesses. This means the captchas you open will be sent to a first-party web service for predictions. No information will be retained.'),
				actions: [
					AdaptiveDialogAction(
						isDefaultAction: true,
						child: const Text('Use cloud solver'),
						onPressed: () {
							Navigator.of(context).pop(true);
						},
					),
					AdaptiveDialogAction(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					)
				]
			)
		);
		if (Settings.instance.useCloudCaptchaSolver ?? false) {
			if (!_cloudGuessFailed) {
				await _animateCloudGuess();
				if (!_cloudGuessFailed) {
					return;
				}
			}
		}
		_animateLocalGuess();
	}

	_PickerStuff _getPickerStuffForWidgetIndex(int i) {
		return _pickerStuff.putIfAbsent(_lastGuess.keys[i], () => _orphanPickerStuff.tryRemoveFirst() ?? (
			key: GlobalKey(debugLabel: '_Captcha4ChanCustomState._pickerStuff.key'),
			wrapperKey: UniqueKey(),
			controller: FixedExtentScrollController()
		));
	}

	void _tryRequestChallenge() async {
		try {
			setState(() {
				error = null;
				tryAgainAt = null;
				challenge?.dispose();
				challenge = null;
				cancelToken = CancelToken();
			});
			challenge = await requestCaptcha4ChanCustomChallenge(
				site: widget.site,
				request: widget.request,
				cancelToken: cancelToken
			);
			tryAgainAt = challenge?.tryAgainAt;
			if (!mounted) return;
			if (challenge?.instantSolution case Chan4CustomCaptchaSolution solution) {
				widget.onCaptchaSolved(solution);
				challenge?.dispose();
				challenge = null;
				return;
			}
			cancelToken = null;
			await _setupChallenge();
		}
		catch(e, st) {
			if (e is Captcha4ChanCustomChallengeCooldownException) {
				tryAgainAt = e.tryAgainAt;
			}
			print(e);
			print(st);
			if (!mounted) return;
			setState(() {
				cancelToken = null;
				error = (e, st);
			});
		}
	}

	Future<void> _setupChallenge() async {
		_lastCloudGuess = null; // Forget about previous challenge guess
		tryAgainAt = challenge?.tryAgainAt;
		if (challenge case Captcha4ChanCustomChallengeText challenge) {
			if (challenge.backgroundImage != null) {
				final bestSlide = await _alignImage(challenge);
				if (!mounted) return;
				setState(() {
					backgroundSlide = bestSlide;
				});
			}
			else {
				backgroundSlide = 0;
			}
			if (useNewCaptchaForm) {
				await _animateGuess();
			}
			else {
				setState(() {});
				_solutionController.clear();
				_solutionNode.requestFocus();
			}
		}
		else if (challenge case Captcha4ChanCustomChallengeTasks challenge) {
			_taskChoices = List.filled(challenge.tasks.length, null);
			setState(() {});
		}
	}

	String _previousText = "000000";
	TextSelection _previousSelection = const TextSelection(baseOffset: 0, extentOffset: 1);
	bool _modifyingFromPicker = false;

	void _onSolutionControllerUpdate() {
		TextSelection newSelection = _solutionController.selection;
		String newText = _solutionController.text;
		if (newText.length != numLetters) {
			if (_previousText.length == numLetters && newText.length == numLetters - 1 && newSelection.isCollapsed && newSelection.isValid) {
				final index = newSelection.baseOffset;
				if ((_previousText.substring(0, index) == newText.substring(0, index)) &&
						(_previousText.substring(index + 1) == newText.substring(index))) {
					// backspace was pressed
					newText = _previousText;
					if (index > 0) {
						newSelection = TextSelection(baseOffset: index - 1, extentOffset: index);
					}
					else {
						newSelection = TextSelection(baseOffset: numLetters - 1, extentOffset: numLetters);
					}
				}
			}
			else {
				newText = newText.substring(0, min(numLetters, newText.length)).padRight(numLetters, ' ');
			}
		}
		final spaceLocations = <int>[];
		for (int i = 0; i < numLetters; i++) {
			final char = newText[i].toUpperCase();
			if (!widget.request.letters.contains(char)) {
				if (widget.request.lettersRemap[char] != null) {
					newText = newText.replaceRange(i, i + 1, widget.request.lettersRemap[char]!);
				}
				else {
					newText = _previousText;
					newSelection = TextSelection(baseOffset: i, extentOffset: i + 1);
					if (char == ' ') {
						spaceLocations.add(i);
					}
				}
			}
		}
		if (spaceLocations.length == 1) {
			final start = (spaceLocations.single + 1) % numLetters;
			newSelection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		int start = newSelection.baseOffset % numLetters;
		if (newSelection.isCollapsed) {
			if (_previousSelection.baseOffset == newSelection.baseOffset && _previousText == newText) {
				// Left-arrow was pressed
				start = (start - 1) % numLetters;
			}
			newSelection = TextSelection(baseOffset: start, extentOffset: start + 1);
		}
		if (!_modifyingFromPicker && _previousText != newText) {
			for (int i = 0; i < numLetters; i++) {
				if (i >= _previousText.length || _previousText[i] != newText[i] || _previousText.length != newText.length) {
					if (i < _guessConfidences.length && newText[i] != _lastGuess.guess[i]) {
						_guessConfidences[i] = 1;
					}
					WidgetsBinding.instance.addPostFrameCallback((_) => _getPickerStuffForWidgetIndex(i).controller.animateToItem(widget.request.letters.indexOf(newText[i].toUpperCase()), duration: const Duration(milliseconds: 250), curve: Curves.elasticIn));
				}
			}
		}
		_previousText = _solutionController.text;
		_previousSelection = _solutionController.selection;
		_solutionController.value = _solutionController.value.copyWith(
			text: newText,
			selection: newSelection,
			composing: TextRange.empty
		);
	}

	Future<void> _submit(String response) async {
		widget.onCaptchaSolved(Chan4CustomCaptchaSolution(
			challenge: challenge!.challenge,
			response: response,
			acquiredAt: challenge!.acquiredAt,
			lifetime: challenge!.lifetime,
			originalData: challenge!.originalData,
			slide: backgroundSlide,
			cloudflare: challenge!.cloudflare,
			ip: _ip,
			autoSolved: response == _lastCloudGuess
		));
		challenge?.dispose();
		challenge = null;
	}

	@override
	void initState() {
		super.initState();
		challenge = widget.initialChallenge;
		if (challenge?.isReusableFor(widget.request, const Duration(seconds: 15)) == false) {
			challenge?.dispose();
			challenge = null;
		}
		_solutionNode = FocusNode();
		_solutionController = TextEditingController();
		_lastGuess = Chan4CustomCaptchaGuess.dummy('0' * numLetters);
		if (useNewCaptchaForm) {
			_solutionController.text = "000000";
			_solutionController.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
			_solutionController.addListener(_onSolutionControllerUpdate);
		}
		final guess = widget.initialCloudGuess;
		if (widget.initialChallengeException != null) {
			error = widget.initialChallengeException;
			if (error?.$1 case CooldownException exception) {
				tryAgainAt = exception.tryAgainAt;
			}
		}
		else if (guess != null) {
			_ip = guess.solution.ip;
			challenge = guess.challenge;
			backgroundSlide = guess.slide ?? 0;
			tryAgainAt = guess.challenge.tryAgainAt;
			Future.delayed(const Duration(milliseconds: 10), () {
				_useCloudGuess(guess.solution.response);
			});
		}
		else if (challenge != null) {
			_setupChallenge();
		}
		else {
			_tryRequestChallenge();
		}
	}

	Widget _cooldownedRetryButton(BuildContext context) {
		if (tryAgainAt != null) {
			return TimedRebuilder(
				interval: () => const Duration(seconds: 1),
				function: () {
					return tryAgainAt!.difference(DateTime.now()).inSeconds;
				},
				builder: (context, seconds) {
					return AdaptiveIconButton(
						onPressed: seconds > 0 ? null : _tryRequestChallenge,
						icon: FittedBox(
							fit: BoxFit.scaleDown,
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									const Icon(CupertinoIcons.refresh),
									const SizedBox(width: 16),
									GreedySizeCachingBox(
										alignment: Alignment.centerRight,
										child: seconds > 0 ? Text('$seconds', style: CommonTextStyles.tabularFigures) : const SizedBox.shrink()
									)
								]
							)
						)
					);
				}
			);
		}
		return AdaptiveIconButton(
			onPressed: _tryRequestChallenge,
			icon: const Icon(CupertinoIcons.refresh)
		);
	}

	Widget _expiryWidget() {
		return FittedBox(
			fit: BoxFit.scaleDown,
			child: Row(
				mainAxisAlignment: MainAxisAlignment.end,
				children: [
					const Icon(CupertinoIcons.timer),
					const SizedBox(width: 16),
					GreedySizeCachingBox(
						alignment: Alignment.centerRight,
						child: TimedRebuilder(
							interval: () => const Duration(seconds: 1),
							function: () {
								return challenge?.expiresAt.difference(DateTime.now()).inSeconds ?? 0;
							},
							builder: (context, seconds) {
								return Text(
									seconds > 0 ? '$seconds' : 'Expired',
									style: CommonTextStyles.tabularFigures
								);
							}
						)
					)
				]
			)
		);
	}

	Widget _buildTask(String raw) {
		String ret = raw.replaceFirst('Use the scroll bar below to ', '');
		ret = ret.replaceFirst(', then click Next.', '');
		bool foundFirstText = false;
		bool unparseable = false;
		Iterable<InlineSpan> visit(Iterable<dom.Node> nodes) sync* {
			for (final node in nodes) {
				if (node is dom.Text) {
					if (!foundFirstText && node.text.isNotEmpty) {
						// recapitalize first letter
						node.text = '${node.text[0].toUpperCase()}${node.text.substring(1)}';
						foundFirstText = true;
					}
					yield TextSpan(text: node.text);
				}
				else if (node is dom.Element) {
					// Don't edit DOM in case we need to throw to HTML renderer
					final attributes = Map.of(node.attributes);
					final Map<String, Expression> styles;
					if (attributes.remove('style') case String style) {
						styles = resolveInlineCss(style);
					}
					else {
						styles = {};
					}
					final display = styles.remove('display')?.string;
					if (display == 'none') {
						// Skip it
						continue;
					}
					final visibility = styles.remove('visibility')?.string;
					if (visibility == 'hidden' || visibility == 'collapse') {
						// Skip it
						continue;
					}
					final opacity = styles.remove('opacity')?.scalar;
					if ((opacity ?? 1) < 0.01) {
						// Skip it
						continue;
					}
					final width = styles.remove('width')?.string;
					if (width == '1px') {
						// Skip it
						continue;
					}
					unparseable |= width != null; // If new width trick used
					if (node.localName == 'b') {
						yield TextSpan(children: visit(node.nodes).toList(), style: const TextStyle(
							fontWeight: FontWeight.bold,
							fontVariations: CommonFontVariations.bold
						));
					}
					else if (attributes.remove('src') case String src when node.localName == 'img' && src.startsWith('data:image/')) {
						styles.remove('float'); // TODO: PlaceholderFloating in forked_flutter_engine
						final margin = styles.remove('margin');
						final edges = margin?.edges ?? const CssEdgeSizes.all(CssEdgeSizePixels(0));
						double resolvePadding(CssEdgeSize size) => switch (size) {
							CssEdgeSizePixels(pixels: double px) => px,
							CssEdgeSizeFractional(fraction: double f) => f * 100,
							CssEdgeSizeAuto() => 0
						};
						yield WidgetSpan(
							child: Padding(
								padding: EdgeInsets.only(
									left: resolvePadding(edges.left),
									top: resolvePadding(edges.top),
									right: resolvePadding(edges.right),
									bottom: resolvePadding(edges.bottom)
								),
								child: Image(
									image: MemoryImage(base64Decode(src.afterLast(','))),
									fit: BoxFit.contain
								)
							)
						);
					}
					else {
						// Give up
						unparseable = true;
						yield TextSpan(text: node.outerHtml);
					}
					unparseable |= attributes.isNotEmpty; // If new attributes are added
					unparseable |= styles.isNotEmpty; // If new CSS is used
				}
			}
		}
		final fragment = parseFragment(ret);
		final children = visit(fragment.nodes).toList();
		if (unparseable) {
			// The fragment tree has corrected capitalization
			return HTMLWidget(html: fragment.outerHtml);
		}
		return Text.rich(TextSpan(children: children));
	}

	Widget _build(BuildContext context) {
		if (error != null) {
			return Center(
				child: Column(
					children: [
						Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Flexible(
									child: Text(error!.$1.toStringDio())
								),
								AdaptiveIconButton(
									onPressed: () => alertError(context, error!.$1, error!.$2, barrierDismissible: true),
									icon: const Icon(CupertinoIcons.info)
								)
							]
						),
						if (error?.$1.toString().contains('Posting on this board requires a verified email') ?? false) ...[
							const SizedBox(height: 16),
							const ChanceDivider(),
							const SizedBox(height: 16),
							Text.rich(TextSpan(
								children: [
									const TextSpan(text: 'Note from Chance:\nGo to '),
									TextSpan(
										text: 'https://sys.4chan.org/signin',
										recognizer: TapGestureRecognizer(debugOwner: this)..onTap = () => shareOne(
											context: context,
											text: 'https://sys.4chan.org/signin',
											type: 'text',
											sharePositionOrigin: null
										),
										style: TextStyle(
											color: Settings.instance.theme.secondaryColor,
											decoration: TextDecoration.underline
										)
									),
									const TextSpan(text: ' in your browser and enter your email. Then paste the emailed verification link within Chance Settings -> Site Settings -> '),
									const WidgetSpan(child: Icon(CupertinoIcons.link, size: 16))
								]
							))
						],
						_cooldownedRetryButton(context)
					]
				)
			);
		}
		else if (challenge case Captcha4ChanCustomChallengeText challenge) {
			// Don't highlight any letter if they all have confidence 1
			int minGuessConfidenceIndex = -1;
			double minGuessConfidence = 1;
			if (numLetters == 6) {
				// Only emphasize worst letter on 6-captcha form
				for (int i = 1; i < _guessConfidences.length; i++) {
					if (_guessConfidences[i] < minGuessConfidence) {
						minGuessConfidence = _guessConfidences[i];
						minGuessConfidenceIndex = i;
					}
				}
			}
			final theme = context.watch<SavedTheme>();
			final scaleFactor = MediaQuery.textScalerOf(context).scale(17) / 17;
			final maxWidth = 500 * scaleFactor;
			final possibleLetterCounts = switch (widget.request.possibleLetterCounts) {
				[] => [4, 5, 6],
				List<int> list => list
			};
			final maxSlide = ((challenge.backgroundWidth ?? challenge.backgroundImage?.width ?? challenge.foregroundImage?.width ?? 0) - (challenge.foregroundImage?.width ?? 0)).abs();
			return Center(
				child: ConstrainedBox(
					constraints: BoxConstraints(
						maxWidth: maxWidth
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const Text('Enter the text in the image below'),
							const SizedBox(height: 16),
							Flexible(
								child: (challenge.foregroundImage == null) ? const Text('Verification not required') : AspectRatio(
									aspectRatio: challenge.foregroundImage!.width / challenge.foregroundImage!.height,
									child: GestureDetector(
										onDoubleTap: () async {
											_cloudGuessFailed = false;
											if (challenge.backgroundImage != null) {
												backgroundSlide = await _alignImage(challenge);
												setState(() {});
											}
											await _animateGuess();
										},
										child: CustomPaint(
											size: Size(min(challenge.backgroundImage?.width ?? challenge.foregroundImage!.width, challenge.foregroundImage!.width).toDouble(), challenge.foregroundImage!.height.toDouble()),
											painter: _Captcha4ChanCustomPainter(
												foregroundImage: challenge.foregroundImage!,
												backgroundImage: challenge.backgroundImage,
												backgroundSlide: backgroundSlide
											)
										)
									)
								)
							),
							const SizedBox(height: 16),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Flexible(
										fit: FlexFit.tight,
										flex: 1,
										child:  _cooldownedRetryButton(context)
									),
									if (maxSlide > 0) Flexible(
										flex: 2,
										fit: FlexFit.tight,
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 16),
											child: Slider.adaptive(
												value: maxSlide - backgroundSlide.toDouble(),
												divisions: maxSlide,
												max: maxSlide.toDouble(),
												onChanged: (newOffset) {
													setState(() {
														backgroundSlide = maxSlide - newOffset.floor();
													});
												},
												onChangeEnd: (newOffset) {
													if (_solutionController.text.toUpperCase() == _lastGuess.guess.toUpperCase()) {
														_animateGuess();
													}
												}
											)
										)
									),
									Flexible(
										flex: 1,
										fit: FlexFit.tight,
										child: _expiryWidget()
									)
								]
							),
							const SizedBox(height: 0),
							Visibility(
								visible: !useNewCaptchaForm,
								maintainAnimation: true,
								maintainState: true,
								maintainFocusability: true,
								child: SizedBox(
									width: 150,
									child: Actions(
										actions: {
											ExtendSelectionVerticallyToAdjacentLineIntent: CallbackAction<ExtendSelectionVerticallyToAdjacentLineIntent>(
												onInvoke: (intent) {
													final controller = _getPickerStuffForWidgetIndex(_solutionController.selection.baseOffset).controller;
													if (intent.forward) {
														controller.animateToItem(
															controller.selectedItem + 1,
															duration: const Duration(milliseconds: 100),
															curve: Curves.ease
														);
													}
													else {
														controller.animateToItem(
															controller.selectedItem - 1,
															duration: const Duration(milliseconds: 100),
															curve: Curves.ease
														);
													}
													return null;
												}
											)
										},
										child: AdaptiveTextField(
											key: _solutionKey,
											focusNode: _solutionNode,
											enableIMEPersonalizedLearning: false,
											keyboardType: TextInputType.visiblePassword,
											controller: _solutionController,
											autocorrect: false,
											placeholder: 'Captcha text',
											onSubmitted: _submit
										)
									)
								)
							),
							if (useNewCaptchaForm) ...[
								const SizedBox(height: 8),
								if (possibleLetterCounts.trySingle != numLetters) ...[
									Text('Number of letters', style: TextStyle(
										color: theme.primaryColor.withValues(alpha: 0.7)
									)),
									const SizedBox(height: 8),
									SizedBox(
										width: double.infinity,
										child: IgnorePointer(
											ignoring: _greyOutPickers,
											child: Opacity(
												opacity: _greyOutPickers ? 0.5 : 1.0,
												child: AdaptiveSegmentedControl<int>(
													fillWidth: true,
													children: {
														if (numLetters < possibleLetterCounts.first)
															numLetters: (null, '$numLetters'),
														for (final count in possibleLetterCounts)
															count: (null, '$count'),
														if (numLetters > possibleLetterCounts.last)
															numLetters: (null, '$numLetters')
													},
													groupValue: numLetters,
													onValueChanged: (x) {
														if (x != numLetters) {
															numLetters = x;
															final selection = _solutionController.selection;
															final oldGuess = _lastGuess;
															_lastGuess = _lastGuesses?.forNumLetters(numLetters) ?? Chan4CustomCaptchaGuess.dummy('0' * numLetters);
															String newGuessText = _lastGuess.guess;
															_guessConfidences = _lastGuess.confidences.toList();
															// We want keys to match up to same pickerStuff, not to widget-indexes
															final tmp = _pickerStuff.keys.toSet();
															for (final id in _lastGuess.keys.asMap().entries) {
																if (_pickerStuff.containsKey(id.value)) {
																	// Same key in both guesses
																	tmp.remove(id.value);
																	final indexInOldGuess = oldGuess.keys.indexOf(id.value);
																	if (indexInOldGuess != -1) {
																		// Copy the old letter, in case the user modified it
																		newGuessText = newGuessText.replaceRange(id.key, id.key + 1, _solutionController.text[indexInOldGuess]);
																	}
																}
															}
															for (final orphanKey in tmp) {
																// Old letter slot not in new guess
																final orphan = _pickerStuff.remove(orphanKey);
																if (orphan != null) {
																	_orphanPickerStuff.add(orphan);
																}
															}
															_solutionController.text = newGuessText;
															_solutionController.selection = TextSelection(
																baseOffset: min(numLetters - 1, selection.baseOffset),
																extentOffset: min(numLetters, selection.extentOffset)
															);
															setState(() {});
														}
													}
												)
											)
										)
									)
								],
								const SizedBox(height: 8),
								IgnorePointer(
									ignoring: _greyOutPickers,
									child: Opacity(
										opacity: _greyOutPickers ? 0.5 : 1.0,
										child: SizedBox(
											height: 200 * scaleFactor,
											child: LayoutBuilder(
												builder: (context, constraints) => ReorderableListView(
													scrollDirection: Axis.horizontal,
													physics: const NeverScrollableScrollPhysics(),
													onReorder: (a, b) {
														if (a < b) {
															for (int i = a; i < b - 1; i++) {
																final tmp = _getPickerStuffForWidgetIndex(i).controller.selectedItem;
																_getPickerStuffForWidgetIndex(i).controller.jumpToItem(_getPickerStuffForWidgetIndex(i + 1).controller.selectedItem);
																_getPickerStuffForWidgetIndex(i + 1).controller.jumpToItem(tmp);
															}
														}
														else {
															for (int i = a; i > b; i--) {
																final tmp = _getPickerStuffForWidgetIndex(i).controller.selectedItem;
																_getPickerStuffForWidgetIndex(i).controller.jumpToItem(_getPickerStuffForWidgetIndex(i - 1).controller.selectedItem);
																_getPickerStuffForWidgetIndex(i - 1).controller.jumpToItem(tmp);
															}
														}
													},
													proxyDecorator: (child, index, animation) => AnimatedBuilder(
														animation: animation,
														builder: (BuildContext context, Widget? child) {
															final double animValue = Curves.easeInOut.transform(animation.value);
															return ColorFiltered(
																colorFilter: ColorFilter.mode(
																	theme.primaryColor.withValues(alpha: 0.2 * animValue),
																	BlendMode.srcOver
																),
																child: child
															);
														},
														child: child,
													),
													children: [
														for (int i = 0; i < numLetters; i++) ...[
															ReorderableDelayedDragStartListener(
																index: i,
																key: _getPickerStuffForWidgetIndex(i).wrapperKey,
																child: SizedBox(
																	height: 200 * scaleFactor,
																	width: min(constraints.maxWidth, maxWidth) / numLetters,
																	child: Stack(
																		fit: StackFit.expand,
																		children: [
																			NotificationListener(
																				onNotification: (notification) {
																					if (notification is ScrollEndNotification && notification.metrics is FixedExtentMetrics) {
																						_modifyingFromPicker = true;
																						final newLetter = widget.request.letters[(notification.metrics as FixedExtentMetrics).itemIndex];
																						_solutionController.value = TextEditingValue(
																							text: _solutionController.text.replaceRange(i, i + 1, newLetter),
																							selection: _solutionController.selection,
																							composing: TextRange.empty
																						);
																						if (_guessConfidences[i] != 1 && _lastGuess.guess.substring(i, i + 1) != newLetter) {
																							setState(() {
																								_guessConfidences[i] = 1;
																							});
																						}
																						_modifyingFromPicker = false;
																						return true;
																					}
																					return false;
																				},
																				child: ScrollConfiguration(
																					behavior: ScrollConfiguration.of(context).copyWith(
																						physics: _ModifiedBouncingScrollPhysics()
																					),
																					child: CupertinoPicker.builder(
																						key: _getPickerStuffForWidgetIndex(i).key,
																						scrollController: _getPickerStuffForWidgetIndex(i).controller,
																						selectionOverlay: AnimatedBuilder(
																							animation: _solutionController,
																							builder: (context, child) => CupertinoPickerDefaultSelectionOverlay(
																								background: ColorTween(
																									begin: CupertinoColors.tertiarySystemFill.resolveFrom(context),
																									end: theme.primaryColor
																								).transform((_solutionNode.hasFocus && (_solutionController.selection.baseOffset <= i) && (i < _solutionController.selection.extentOffset)) ? 0.5 : 0)!
																							)
																						),
																						childCount: widget.request.letters.length,
																						itemBuilder: (context, l) => Padding(
																							key: ValueKey(widget.request.letters[l]),
																							padding: const EdgeInsets.all(6),
																							child: Center(
																								child: Text(widget.request.letters[l],
																									style: TextStyle(
																										fontSize: 34,
																										color:  ColorTween(
																											begin: theme.primaryColor,
																											end: const Color.fromARGB(255, 241, 190, 19)).transform(0.4 - 0.4*_guessConfidences[min(_guessConfidences.length - 1, i)] + (i == minGuessConfidenceIndex ? 0.6 : 0)
																										)!
																									)
																								)
																							)
																						),
																						itemExtent: 50 * scaleFactor,
																						onSelectedItemChanged: null
																					)
																				)
																			),
																			Column(
																				crossAxisAlignment: CrossAxisAlignment.stretch,
																				children: [
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_getPickerStuffForWidgetIndex(i).controller.animateToItem(
																								_getPickerStuffForWidgetIndex(i).controller.selectedItem - 1,
																								duration: const Duration(milliseconds: 100),
																								curve: Curves.ease
																							);
																						},
																						child: SizedBox(height: 75 * scaleFactor)
																					),
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_solutionController.selection = TextSelection(baseOffset: i, extentOffset: i + 1);
																							_solutionNode.requestFocus();
																							_solutionKey.currentState?.editableText?.requestKeyboard();
																							setState(() {});
																						},
																						child: SizedBox(height: 50 * scaleFactor)
																					),
																					GestureDetector(
																						behavior: HitTestBehavior.translucent,
																						onTap: () {
																							_getPickerStuffForWidgetIndex(i).controller.animateToItem(
																								_getPickerStuffForWidgetIndex(i).controller.selectedItem + 1,
																								duration: const Duration(milliseconds: 100),
																								curve: Curves.ease
																							);
																						},
																						child: SizedBox(height: 75 * scaleFactor)
																					)
																				]
																			)
																		]
																	)
																)
															)
														]
													]
												)
											)
										)
									)
								),
								Row(
									children: [
										Expanded(
											child: Stack(
												children: [
													ClipRRect(
														borderRadius: BorderRadius.circular(8),
														child: LinearProgressIndicator(
															value: _greyOutPickers ? null : 1,
															minHeight: 50,
															valueColor: AlwaysStoppedAnimation(theme.primaryColor),
															backgroundColor: theme.primaryColor.withValues(alpha: 0.3)
														)
													),
													CupertinoButton(
														padding: EdgeInsets.zero,
														onPressed: _greyOutPickers ? null : () {
															_submit(_solutionController.text);
														},
														child: SizedBox(
															height: 50,
															child: Center(
																child: Text(
																	'Submit',
																	style: TextStyle(
																		fontSize: 20,
																		color: theme.backgroundColor
																	)
																)
															)
														)
													)
												]
											)
										),
										HiddenCancelButton(
											cancelToken: cancelToken,
											icon: const Icon(CupertinoIcons.xmark),
											alignment: Alignment.centerRight
										)
									]
								)
							]
						]
					)
				)
			);
		}
		else if (challenge case Captcha4ChanCustomChallengeTasks challenge) {
			final theme = context.watch<SavedTheme>();
			return Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(
						maxWidth: 500
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							for (final task in challenge.tasks.indexed) Container(
								decoration: BoxDecoration(
									color: theme.primaryColorWithBrightness(0.15),
									borderRadius: BorderRadius.circular(8)
								),
								margin: const EdgeInsets.only(bottom: 16),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										Padding(
											padding: const EdgeInsets.all(8),
											child: _buildTask(task.$2.text)
										),
										Wrap(
											children: task.$2.choices.indexed.map((choice) => CupertinoInkwell(
												padding: EdgeInsets.zero,
												onPressed: () {
													setState(() {
														_taskChoices[task.$1] = choice.$1;
													});
												},
												child: Container(
													padding: const EdgeInsets.all(8),
													decoration: BoxDecoration(
														color: _taskChoices[task.$1] == choice.$1 ? theme.secondaryColor : null,
														borderRadius: const BorderRadius.all(Radius.circular(4)),
													),
													constraints: const BoxConstraints(
														minWidth: 100,
														minHeight: 100
													),
													child: RawImage(
														image: choice.$2,
														fit: BoxFit.contain
													)
												)
											)).toList()
										)
									]
								)
							),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Flexible(
										fit: FlexFit.tight,
										flex: 1,
										child:  _cooldownedRetryButton(context)
									),
									Flexible(
										flex: 1,
										fit: FlexFit.tight,
										child: _expiryWidget()
									)
								]
							),
							const SizedBox(height: 16),
							CupertinoButton(
								padding: EdgeInsets.zero,
								color: theme.primaryColor,
								disabledColor: theme.primaryColorWithBrightness(0.5),
								onPressed: _taskChoices.any((t) => t == null) ? null : () {
									_submit(_taskChoices.join());
								},
								child: SizedBox(
									height: 50,
									child: Center(
										child: Text(
											'Submit',
											style: TextStyle(
												fontSize: 20,
												color: theme.backgroundColor
											)
										)
									)
								)
							)
						]
					)
				)
			);
		}
		else if (challenge != null) {
			return Center(
				child: Text('Unknown inner challenge: $challenge')
			);
		}
		else {
			return Center(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const CircularProgressIndicator.adaptive(),
						HiddenCancelButton(
							cancelToken: cancelToken,
							icon: const Text('Cancel'),
							alignment: Alignment.topCenter
						)
					]
				)
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			decoration: BoxDecoration(
				color: ChanceTheme.backgroundColorOf(context),
			),
			width: double.infinity,
			padding: const EdgeInsets.all(16),
			child: AnimatedSize(
				duration: const Duration(milliseconds: 100),
				child: _build(context)
			)
		);
	}

	@override
	void dispose() {
		final tryAgainAt = this.tryAgainAt;
		if (tryAgainAt != null && tryAgainAt.isAfter(DateTime.now())) {
			widget.onTryAgainAt?.call(tryAgainAt);
		}
		super.dispose();
		_solutionNode.dispose();
		_solutionController.dispose();
		for (final stuff in _pickerStuff.values.followedBy(_orphanPickerStuff)) {
			stuff.controller.dispose();
		}
		_storeChallengeForReuse(challenge);
	}
}