import 'dart:io' as io;

import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CloudflareLoginPage extends StatelessWidget {
	final Uri desiredUrl;

	const CloudflareLoginPage({
		required this.desiredUrl,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return CupertinoPageScaffold(
			navigationBar: const CupertinoNavigationBar(
				middle: Text('Cloudflare Login')
			),
			child: InAppWebView(
				initialOptions: InAppWebViewGroupOptions(
					crossPlatform: InAppWebViewOptions(
						userAgent: userAgent
					)
				),
				initialUrlRequest: URLRequest(
					url: desiredUrl
				),
				onLoadStop: (controller, uri) async {
					final title = await controller.getTitle();
					if (!(title?.contains('Cloudflare') ?? true)) {
						final cookies = await CookieManager.instance().getCookies(url: uri!);
						Persistence.cookies.saveFromResponse(uri, cookies.map((cookie) {
							final newCookie = io.Cookie(cookie.name, cookie.value);
							newCookie.domain = cookie.domain;
							if (cookie.expiresDate != null) {
								newCookie.expires = DateTime.fromMillisecondsSinceEpoch(cookie.expiresDate!);
							}
							newCookie.httpOnly = cookie.isHttpOnly ?? false;
							newCookie.path = cookie.path;
							newCookie.secure = cookie.isSecure ?? false;
							return newCookie;
						}).toList());
						Navigator.of(context).pop(await controller.getHtml());
					}
				}
			)
		);
	}
}