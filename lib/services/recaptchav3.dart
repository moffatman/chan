import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';

Future<Recaptcha3Solution> solveRecaptchaV3(Recaptcha3Request request) async {
	final token = await useCloudflareClearedWebview(
		uri: Uri.parse(request.sourceUrl),
		priority: RequestPriority.interactive,
		handler: (controller, url) async {
			final result = await controller.callAsyncJavaScript(functionBody: 'return grecaptcha.execute("${request.key}"${request.action == null ? '' : ', {action: "${request.action}"}'})');
			final v = result?.value;
			if (v is String) {
				return v;
			}
			else {
				throw Exception('JS Error: ${result?.error}');
			}
		}
	);
	return Recaptcha3Solution(
		response: token,
		acquiredAt: DateTime.now()
	);
}
