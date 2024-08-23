import 'package:chan/services/cloudflare.dart';
import 'package:chan/sites/imageboard_site.dart';

/// [javascript] should be an expression. could resolve to a Promise.
Future<String> solveJavascriptChallenge({
	required Uri url,
	required String javascript,
	required RequestPriority priority
}) async {
	return await useCloudflareClearedWebview(
		handler: (controller, url) async {
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
		priority: priority
	);
}
