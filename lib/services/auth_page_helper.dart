import 'package:chan/pages/cookie_browser.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/linkifier.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linkify/linkify.dart';

/// Return value true means retry the captcha, something was done
Future<bool> showAuthPageHelperPopup(BuildContext context, Imageboard imageboard) async {
	final ret = await showAdaptiveDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Login'),
			content: Text('${imageboard.site.name} uses an email-based anti-spam system. Use the form to enter your email, then copy the link from your inbox.'),
			actions: [
				AdaptiveDialogAction(
					onPressed: () async {
						await openCookieLoginBrowser(context, imageboard);
					},
					child: const Text('Open form')
				),
				AdaptiveDialogAction(
					onPressed: () async {
						final data = await Clipboard.getData(Clipboard.kTextPlain);
						final text = data?.text?.trim() ?? '';
						final url = linkify(text, linkifiers: [const LooseUrlLinkifier()]).tryMap((e) => switch (e) {
							UrlElement link => Uri.tryParse(link.url),
							_ => null
						}).trySingle;
						if (url == null) {
							throw Exception('No URL in clipboard: "$text"');
						}
						if (context.mounted) {
							bool savedAnything = false;
							await openCookieBrowser(context, url, onCookiesSaved: (cookies) {
								savedAnything |= cookies.isNotEmpty;
							});
							if (savedAnything && context.mounted) {
								Navigator.pop(context, true);
							}
						}
					},
					child: const Text('Paste link')
				),
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context, true),
					child: const Text('Recheck status')
				),
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context, false),
					child: const Text('Cancel')
				)
			]
		)
	);
	return ret ?? false;
}
