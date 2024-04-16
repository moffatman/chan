
import 'package:chan/services/persistence.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CookieBrowser extends StatefulWidget {
	final Uri initialUrl;

	const CookieBrowser({
		required this.initialUrl,
		super.key
	});

	@override
	createState() => _CookieBrowserState();
}

class _CookieBrowserState extends State<CookieBrowser> {
	AsyncSnapshot<bool> _initialized = const AsyncSnapshot.waiting();

	@override
	void initState() {
		super.initState();
		_initialize();
	}

	void _initialize() async {
		try {
			final manager = CookieManager.instance();
			await manager.deleteAllCookies();
			final cookies = await Persistence.currentCookies.loadForRequest(widget.initialUrl);
			for (final cookie in cookies) {
				await manager.setCookie(
					url: WebUri.uri(widget.initialUrl),
					domain: cookie.domain,
					name: cookie.name,
					value: cookie.value,
					path: cookie.path ?? '/',
					expiresDate: cookie.expires?.millisecondsSinceEpoch,
					maxAge: cookie.maxAge,
					isHttpOnly: cookie.httpOnly,
					isSecure: cookie.secure,
					sameSite: HTTPCookieSameSitePolicy.fromValue(cookie.sameSite?.name)
				);
			}
			_initialized = const AsyncSnapshot.withData(ConnectionState.done, true);
		}
		catch (e, st) {
			Future.error(e, st);
			_initialized = AsyncSnapshot.withError(ConnectionState.done, e, st);
		}
		if (mounted) {
			setState(() {});
		}
	}

	Widget _buildBody() {
		if (_initialized.hasError) {
			return Center(
				child: ErrorMessageCard('${_initialized.error}')
			);
		}
		if (!_initialized.hasData) {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
		return SafeArea(
			child: InAppWebView(
				initialUrlRequest: URLRequest(
					url: WebUri.uri(widget.initialUrl)
				),
				onLoadStop: (controller, webUrl) {
					if (webUrl != null && webUrl.isValidUri) {
						Persistence.saveCookiesFromWebView(webUrl.uriValue);
					}
				},
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return AdaptiveScaffold(
			bar: const AdaptiveBar(
				title: Text('Browser')
			),
			body: _buildBody()
		);
	}
}

Future<void> openCookieBrowser(BuildContext context, Uri url) => Navigator.push(context, adaptivePageRoute(
	builder: (context) => CookieBrowser(
		initialUrl: url
	)
));
