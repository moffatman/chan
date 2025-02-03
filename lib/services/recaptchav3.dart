import 'package:chan/services/javascript_challenge.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';

Future<Recaptcha3Solution> solveRecaptchaV3(Recaptcha3Request request, {CancelToken? cancelToken}) async {
	final token = await solveJavascriptChallenge(
		url: Uri.parse(request.sourceUrl),
		javascript: 'grecaptcha.execute("${request.key}"${request.action == null ? '' : ', {action: "${request.action}"}'})',
		priority: RequestPriority.interactive,
		name: 'reCAPTCHA v3',
		cancelToken: cancelToken
	);
	return Recaptcha3Solution(
		response: token,
		acquiredAt: DateTime.now()
	);
}
