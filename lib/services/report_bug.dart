import 'package:chan/version.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

Future<void> reportBug(Object error, StackTrace stackTrace)
	=> FlutterEmailSender.send(Email(
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
						'''
	));
