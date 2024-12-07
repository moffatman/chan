import 'dart:io';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

Future<void> reportBug(Object error, StackTrace stackTrace) async {
	final attachmentPaths = <String>[];
	if (error is ExtendedException && error.additionalFiles.isNotEmpty) {
		final dir = await Directory('${Persistence.temporaryDirectory.path}/bug_${DateTime.now().millisecondsSinceEpoch}').create(recursive: true);
		for (final file in error.additionalFiles.entries) {
			await File('${dir.path}/${file.key}').writeAsBytes(file.value);
		}
	}
	try {
		await FlutterEmailSender.send(Email(
			subject: 'Chance Bug Report',
			recipients: ['callum@moffatman.com'],
			isHTML: true,
			body: '''<p>Hi Callum,</p>
							<p>Chance v$kChanceVersion is giving me a problem:</p>
							<p>[insert your problem here]</p>
							<p>Error: <pre>$error</pre></p>
							<p>
							Stack Trace:
							<pre>$stackTrace</pre>
							</p>
							''',
			attachmentPaths: attachmentPaths
		));
	}
	catch (e, st) {
		// Mail client missing?
		Future.error(e, st);
		final message = '${error.toStringDio()}\n\n$stackTrace';
		alert(ImageboardRegistry.instance.context!, 'Error', message, actions: {
			'Copy': () => Clipboard.setData(ClipboardData(text: message))
		});
	}
}
