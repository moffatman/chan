import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';

/// [javascript] should be an expression. could resolve to a Promise.
Future<String> solveJavascriptChallenge({
	required Uri url,
	required String javascript,
	/// Will be called for a while until true
	String waitJavascript = 'true',
	required RequestPriority priority,
	required String name
}) async {
	return await useCloudflareClearedWebview(
		handler: (controller, url) async {
			for (int i = 0; i < 20; i++) {
				if (((await controller.callAsyncJavaScript(functionBody: 'return $waitJavascript'))?.value) == true) {
					break;
				}
				await Future.delayed(const Duration(milliseconds: 500));
			}
			final result = await controller.callAsyncJavaScript(functionBody: 'return $javascript');
			final v = result?.value;
			if (v is String) {
				return v;
			}
			else {
				throw Exception('JS Error: ${result?.error}');
			}
		},
		uri: url,
		priority: priority,
		gatewayName: name
	);
}
