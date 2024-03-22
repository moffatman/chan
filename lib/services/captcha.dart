import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/captcha_4chan.dart';
import 'package:chan/widgets/captcha_dvach.dart';
import 'package:chan/widgets/captcha_lynxchan.dart';
import 'package:chan/widgets/captcha_nojs.dart';
import 'package:chan/widgets/captcha_secucap.dart';
import 'package:chan/widgets/captcha_securimage.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

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
	Future<CaptchaSolution?> pushModal(Widget Function(ValueChanged<CaptchaSolution> onCaptchaSolved) builder) async {
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
		case Chan4CustomCaptchaRequest():
			CloudGuessedCaptcha4ChanCustom? initialCloudGuess;
			Exception? initialCloudChallengeException;
			if ((settings.useCloudCaptchaSolver ?? false) && (settings.useHeadlessCloudCaptchaSolver ?? false) && (forceHeadless ?? true)) {
				try {
					final cloudSolution = await headlessSolveCaptcha4ChanCustom(
						request: request,
						site: site,
						priority: switch (forceHeadless) {
							true => RequestPriority.cosmetic,
							null || false => RequestPriority.interactive
						}
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
						initialCloudChallengeException = e;
					}
					else if (e is DioError && e.error is CloudflareHandlerInterruptedException) {
						// Avoid two cloudflare popups
						initialCloudChallengeException = e.error;
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
				initialCloudChallengeException: initialCloudChallengeException,
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
		case NoCaptchaRequest():
			return NoCaptchaSolution(DateTime.now());
	}
}
