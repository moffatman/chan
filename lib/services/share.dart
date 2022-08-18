import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_extend/share_extend.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> shareOne({
	required BuildContext context,
	required String text,
	required String type,
	String? subject,
	required Rect? sharePositionOrigin
}) async {
	if (type == 'file') {
		try {
			await ShareExtend.share(
				text,
				type,
				subject: subject ?? '',
				sharePositionOrigin: sharePositionOrigin
			);
		}
		on MissingPluginException {
			await Share.shareFiles(
				[text],
				subject: subject,
				sharePositionOrigin: sharePositionOrigin
			);
		}
	}
	else {
		final rootContext = context;
		final uri = Uri.tryParse(text);
		await showCupertinoModalPopup(
			context: rootContext,
			builder: (context) => CupertinoActionSheet(
				actions: [
					CupertinoActionSheetAction(
						child: const Text('Copy to clipboard'),
						onPressed: () async {
							Navigator.of(context, rootNavigator: true).pop();
							Clipboard.setData(ClipboardData(
								text: text
							));
							showToast(
								context: context,
								message: 'Copied "$text" to clipboard',
								icon: CupertinoIcons.doc_on_clipboard
							);
						}
					),
					if (uri?.host.isNotEmpty == true) ...[
						if (uri!.scheme == 'http' || uri.scheme == 'https') CupertinoActionSheetAction(
							child: const Text('Open in internal browser'),
							onPressed: () {
								Navigator.of(context, rootNavigator: true).pop();
								openBrowser(rootContext, Uri.parse(text), fromShareOne: true);
							}
						),
						CupertinoActionSheetAction(
							child: const Text('Open in external browser'),
							onPressed: () {
								Navigator.of(context, rootNavigator: true).pop();
								launchUrl(Uri.parse(text), mode: LaunchMode.externalApplication);
							}
						)
					],
					CupertinoActionSheetAction(
						child: const Text('Share...'),
						onPressed: () {
							Navigator.of(context, rootNavigator: true).pop();
							Share.share(
								text,
								subject: subject,
								sharePositionOrigin: sharePositionOrigin
							);
						}
					)
				],
				cancelButton: CupertinoActionSheetAction(
					child: const Text('Cancel'),
					onPressed: () => Navigator.of(context, rootNavigator: true).pop()
				)
			)
		);
	}
}