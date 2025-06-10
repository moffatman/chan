import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';

Future<RecaptchaSolution> solveRecaptchaV2(RecaptchaRequest request, {CancelToken? cancelToken}) async {
	final token = await useCloudflareClearedWebview<String>(
		handler: (controller, url) async {
			final result = await controller.callAsyncJavaScript(functionBody: '''
				let meta = document.createElement("meta");
				meta.name = "viewport";
				meta.content = "width=device-width, initial-scale=1.0";
				document.head.appendChild(meta);
				return new Promise(function (resolve, reject) {
					window.pcd_c_loaded = function() {
						let t = document.createElement("div");
        		t.id = "t-tc-cnt";
						document.body.replaceChildren(t);
						grecaptcha.render("t-tc-cnt", {
							sitekey: "${request.key}",
							callback: "pcd_c_done"
						});
					};
					window.pcd_c_done = resolve;
					let script = document.createElement("script");
					script.src = "https://www.google.com/recaptcha/api.js?onload=pcd_c_loaded&render=explicit";
					script.onerror = () => reject(new Error("failed to load reCAPTCHA v2 script"));
					document.head.appendChild(script);
				});
			''');
			if (result?.value case String token) {
				return token;
			}
			throw Exception('Got bad value from reCAPTCHA v2 injection: $result');
		},
		uri: Uri.parse(request.sourceUrl),
		priority: RequestPriority.interactive,
		gatewayName: 'reCAPTCHA v2',
		cancelToken: cancelToken
	);
	return RecaptchaSolution(
		response: token,
		cloudflare: true,
		acquiredAt: DateTime.now()
	);
}
