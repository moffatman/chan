import 'package:chan/pages/overscroll_modal.dart';
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
import 'package:flutter/cupertino.dart';

Future<CaptchaSolution?> solveCaptcha({
	required BuildContext context,
	required ImageboardSite site,
	required CaptchaRequest request,
	VoidCallback? beforeModal,
	VoidCallback? afterModal,
	bool disableHeadlessSolve = false
}) async {
	Future<CaptchaSolution?> pushModal(Widget Function(ValueChanged<CaptchaSolution> onCaptchaSolved) builder) async {
		beforeModal?.call();
		final solution = await Navigator.of(context, rootNavigator: true).push(TransparentRoute(
			builder: (context) => OverscrollModalPage(
				child: builder(Navigator.of(context).pop)
			)
		));
		afterModal?.call();
		return solution;
	}
	final settings = EffectiveSettings.instance;
	switch (request) {
		case RecaptchaRequest():
			return pushModal((onCaptchaSolved) => CaptchaNoJS(
				site: site,
				request: request,
				onCaptchaSolved: onCaptchaSolved
			));
		case Chan4CustomCaptchaRequest():
			CloudGuessedCaptcha4ChanCustom? initialCloudGuess;
			if ((settings.useCloudCaptchaSolver ?? false) && (settings.useHeadlessCloudCaptchaSolver ?? false) && !disableHeadlessSolve) {
				try {
					final cloudSolution = await headlessSolveCaptcha4ChanCustom(
						request: request,
						site: site
					);
					if (!context.mounted) {
						cloudSolution.challenge.dispose();
						return null;
					}
					if (cloudSolution.confident) {
						cloudSolution.challenge.dispose();
						showToast(
							context: context,
							icon: CupertinoIcons.checkmark_seal,
							message: 'Solved captcha'
						);
						return cloudSolution.solution;
					}
					// Cloud solver did not report being "confident"
					// Just pass the current work so far into the widget
					initialCloudGuess = cloudSolution;
				}
				catch (e, st) {
					Future.error(e, st); // Report to crashlytics
					showToast(
						context: context,
						icon: CupertinoIcons.exclamationmark_triangle,
						message: 'Cloud solve failed: ${e.toStringDio()}'
					);
				}
			}
			return pushModal((onCaptchaSolved) => Captcha4ChanCustom(
				site: site,
				request: request,
				initialCloudGuess: initialCloudGuess,
				onCaptchaSolved: onCaptchaSolved
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
			return NoCaptchaSolution();
	}
}
