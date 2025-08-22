import 'dart:async';

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/version.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

bool isReportableBug(dynamic error) => error != null && (ExtendedException.extract(error)?.isReportable ?? true);

Future<void> reportBug(Object error, StackTrace stackTrace) async {
	final attachmentPaths = <String>[];
	if (ExtendedException.extract(error) case ExtendedException e) {
		if (e.additionalFiles.isNotEmpty) {
			final dir = await Persistence.temporaryDirectory.dir('bug_${DateTime.now().millisecondsSinceEpoch}').create(recursive: true);
			for (final file in e.additionalFiles.entries) {
				final f = await dir.file(file.key).writeAsBytes(file.value);
				attachmentPaths.add(f.path);
			}
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

Map<String, FutureOr<void> Function()> generateBugRemedies(Object e, StackTrace? st, BuildContext context, {FutureOr<void> Function()? afterFix}) {
	final ex = ExtendedException.extract(e);
	final exRemedies = ex?.remedies ?? const {};
	return {
		if (st != null && (ex?.isReportable ?? true)) 'Report bug': () => reportBug(e, st),
		...exRemedies.map((k, v) => MapEntry(k, () async {
			await v(context);
			await afterFix?.call();
		}))
	};
}
