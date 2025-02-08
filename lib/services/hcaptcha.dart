import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';

Future<HCaptchaSolution> solveHCaptcha(HCaptchaRequest request, {CancelToken? cancelToken}) async {
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
						window.hcaptcha.render("t-tc-cnt", {
							sitekey: "${request.siteKey}",
							callback: "pcd_c_done"
						});
					};
					window.pcd_c_done = resolve;
					let script = document.createElement("script");
					script.src = "https://js.hcaptcha.com/1/api.js?onload=pcd_c_loaded&render=explicit&recaptchacompat=off";
					script.onerror = () => reject(new Error("failed to load HCaptcha script"));
					document.head.appendChild(script);
				});
			''');
			if (result?.value case String token) {
				return token;
			}
			throw Exception('Got bad value from HCaptcha injection: $result');
		},
		uri: request.hostPage,
		priority: RequestPriority.interactive,
		gatewayName: 'HCaptcha',
		skipHeadless: true,
		cancelToken: cancelToken
	);
	return HCaptchaSolution(
		token: token,
		acquiredAt: DateTime.now()
	);
}
