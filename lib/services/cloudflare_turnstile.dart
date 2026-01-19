import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:dio/dio.dart';

Future<CloudflareTurnstileCaptchaSolution> solveCloudflareTurnstile(ImageboardSite site, CloudflareTurnstileCaptchaRequest request, {CancelToken? cancelToken}) async {
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
						turnstile.render("#t-tc-cnt", {
							sitekey: "${request.siteKey}",
							callback: resolve
						});
					};
					let script = document.createElement("script");
					script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=pcd_c_loaded&render=explicit";
					script.onerror = () => reject(new Error("failed to load turnstile script"));
					document.head.appendChild(script);
				});
			''');
			if (result?.value case String token) {
				return token;
			}
			throw Exception('Got bad value from turnstile injection: $result');
		},
		uri: request.hostPage,
		priority: RequestPriority.interactive,
		gatewayName: 'Turnstile',
		site: site,
		skipHeadless: true,
		cancelToken: cancelToken
	);
	return CloudflareTurnstileCaptchaSolution(
		token: token,
		acquiredAt: DateTime.now()
	);
}
