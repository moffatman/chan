import 'dart:async';
import 'dart:ui';

import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/recaptchav3.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/captcha_dvach.dart';
import 'package:chan/widgets/captcha_dvach_emoji.dart';
import 'package:chan/widgets/captcha_jschan.dart';
import 'package:chan/widgets/captcha_lynxchan.dart';
import 'package:chan/widgets/captcha_mccaptcha.dart';
import 'package:chan/widgets/captcha_nojs.dart';
import 'package:chan/widgets/captcha_secucap.dart';
import 'package:chan/widgets/captcha_securimage.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

const _captchaContributionServer = 'https://captcha.chance.surf';

bool canCaptchaBeSolvedHeadlessly({
	required CaptchaRequest request
}) => switch (request) {
	NoCaptchaRequest() => true,
	Chan4CustomCaptchaRequest() =>
		(Settings.instance.useCloudCaptchaSolver ?? false) &&
		(Settings.instance.useHeadlessCloudCaptchaSolver ?? false),
	_ => false
};

class HeadlessSolveNotPossibleException implements Exception {
	const HeadlessSolveNotPossibleException();
	@override
	String toString() => 'Exception: Solving this captcha without a popup is not possible';
}

Future<CaptchaSolution?> solveCaptcha({
	required BuildContext? context,
	required ImageboardSite site,
	required CaptchaRequest request,
	ValueChanged<DateTime>? onTryAgainAt,
	VoidCallback? beforeModal,
	VoidCallback? afterModal,
	bool? forceHeadless
}) async {
	Future<CaptchaSolution?> pushModal(Widget Function(ValueChanged<CaptchaSolution?> onCaptchaSolved) builder) async {
		if (context == null) {
			throw const HeadlessSolveNotPossibleException();
		}
		beforeModal?.call();
		final solution = await Navigator.of(context, rootNavigator: true).push(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: builder(Navigator.of(context).pop)
			)
		));
		afterModal?.call();
		return solution;
	}
	final settings = Settings.instance;
	switch (request) {
		case RecaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaNoJS(
				site: site,
				request: request,
				onCaptchaSolved: onCaptchaSolved
			));
		case Recaptcha3Request():
			return await solveRecaptchaV3(request);
		case Chan4CustomCaptchaRequest():
			final priority = switch (forceHeadless) {
				true => RequestPriority.cosmetic,
				null || false => RequestPriority.interactive
			};
			CloudGuessedCaptcha4ChanCustom? initialCloudGuess;
			Captcha4ChanCustomChallenge? initialChallenge;
			Exception? initialChallengeException;
			try {
				// Grab the challenge without popping up, to process initial cooldown without interruption
				initialChallenge = await requestCaptcha4ChanCustomChallenge(site: site, request: request, priority: priority);
			}
			on Exception catch (e) {
				if (context == null || e is CooldownException) {
					rethrow;
				}
				initialChallengeException = e;
			}
			if (initialChallengeException == null && (settings.useCloudCaptchaSolver ?? false) && (settings.useHeadlessCloudCaptchaSolver ?? false) && (forceHeadless ?? true)) {
				try {
					final cloudSolution = await headlessSolveCaptcha4ChanCustom(
						request: request,
						site: site,
						priority: priority,
						challenge: initialChallenge
					);
					if (cloudSolution.confident) {
						cloudSolution.challenge.dispose();
						return cloudSolution.solution;
					}
					// Cloud solver did not report being "confident"
					// Just pass the current work so far into the widget
					initialCloudGuess = cloudSolution;
				}
				catch (e, st) {
					if (context == null || e is CooldownException) {
						rethrow;
					}
					else if (e is Captcha4ChanCustomChallengeException) {
						initialChallengeException = e;
					}
					else if (e is dio.DioError && e.error is CloudflareHandlerInterruptedException) {
						// Avoid two cloudflare popups
						initialChallengeException = e.error;
					}
					else {
						Future.error(e, st); // Report to crashlytics
						if (context.mounted) {
							showToast(
								context: context,
								icon: CupertinoIcons.exclamationmark_triangle,
								message: 'Cloud solve failed: ${e.toStringDio()}'
							);
						}
					}
				}
			}
			if (context?.mounted != true) {
				initialCloudGuess?.challenge.dispose();
			}
			return pushModal((onCaptchaSolved) => Captcha4ChanCustom(
				site: site,
				request: request,
				initialCloudGuess: initialCloudGuess,
				initialChallenge: initialChallenge,
				initialChallengeException: initialChallengeException,
				onCaptchaSolved: onCaptchaSolved,
				onTryAgainAt: onTryAgainAt
			));
		case SecurimageCaptchaRequest():
			return await pushModal((onCaptchaSolved) => CaptchaSecurimage(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case DvachCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaDvach(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case DvachEmojiCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaDvachEmoji(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case LynxchanCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaLynxchan(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case SecucapCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaSecucap(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case McCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaMcCaptcha(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case JsChanCaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaJsChan(
				request: request,
				onCaptchaSolved: onCaptchaSolved,
				site: site
			));
		case NoCaptchaRequest():
			return NoCaptchaSolution(DateTime.now());
	}
}

/// Handles contribution and disposal of captcha solution
void onSuccessfulCaptchaSubmitted(CaptchaSolution solution) async {
	try {
		if (solution is! Chan4CustomCaptchaSolution) {
			return;
		}
		if (Settings.contributeCaptchasSetting.value == null) {
			if (random.nextDouble() > 0.25) {
				// 75% chance -> don't even ask
				return;
			}
			final showPopupCompleter = Completer<bool>();
			showToast(
				context: ImageboardRegistry.instance.context!,
				message: 'Contribute captcha?',
				icon: CupertinoIcons.group,
				hapticFeedback: false,
				easyButton: ('More info', () => showPopupCompleter.complete(true))
			);
			// Maybe there are a lot of queued toasts idk
			if (!await showPopupCompleter.future.timeout(const Duration(seconds: 30), onTimeout: () => false)) {
				// User didn't press 'More info'
				return;
			}
			Settings.contributeCaptchasSetting.value ??= await showAdaptiveDialog<bool>(
				context: ImageboardRegistry.instance.context!,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Contribute captcha solutions?'),
					content: const Text('The captcha images you solve will be collected to improve the automated solver'),
					actions: [
						AdaptiveDialogAction(
							child: const Text('Contribute'),
							onPressed: () {
								Navigator.of(context).pop(true);
							}
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
		}
		if (Settings.contributeCaptchasSetting.value != true) {
			return;
		}
		final bytes = await solution.alignedImage?.toByteData(format: ImageByteFormat.png);
		if (bytes == null) {
			print('Something went wrong converting the captcha image to bytes');
			return;
		}
		final response = await Settings.instance.client.post(
			_captchaContributionServer,
			data: dio.FormData.fromMap({
				'text': solution.response,
				'image': dio.MultipartFile.fromBytes(
					bytes.buffer.asUint8List(),
					filename: 'upload.png',
					contentType: MediaType("image", "png")
				)
			}),
			options: dio.Options(
				validateStatus: (x) => true,
				responseType: dio.ResponseType.plain
			)
		);
		print(response.data);
	}
	finally {
		solution.dispose();
	}
}