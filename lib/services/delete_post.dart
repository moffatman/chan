import 'dart:async';

import 'package:chan/models/thread.dart';
import 'package:chan/services/captcha.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

Future<void> deletePost({
	required BuildContext context,
	required Imageboard imageboard,
	required ThreadIdentifier thread,
	required PostReceipt receipt
}) async {
	try {
		final entry = Outbox.instance.submitDeletion(context, imageboard.key, thread, receipt);
		QueueState<void>? lastState;
		DateTime? lastWaitUntil;
		void listener() {
			if (!context.mounted) {
				entry.removeListener(listener);
				return;
			}
			final state = entry.state;
			if (state == lastState) {
				// Sometimes notifyListeners() is called for internal reasons
				return;
			}
			lastState = state;
			if (state is QueueStateDone<void>) {
				onSuccessfulCaptchaSubmitted(state.captchaSolution);
				entry.removeListener(listener);
				showToast(context: context, message: 'Deleted post /${thread.board}/${receipt.id}', icon: CupertinoIcons.delete);
			}
			else if (state is QueueStateFailed<void>) {
				alertError(context, 'Deletion failed\n${state.error.toStringDio()}', actions: {
					'More info': () => showOutboxModalForThread(
						context: context,
						imageboardKey: context.read<Imageboard?>()?.key,
						board: thread.board,
						threadId: thread.id,
						canPopWithDraft: false
					)
				});
			}
			final waitUntil = entry.queue?.allowedTime;
			if (waitUntil != lastWaitUntil) {
				if (waitUntil != null) {
					final delta = waitUntil.difference(DateTime.now());
					if (delta > const Duration(seconds: 3)) {
						showToast(
							context: context,
							icon: CupertinoIcons.clock,
							message: 'Waiting ${formatDuration(delta)} to submit report'
						);
					}
				}
				lastWaitUntil = waitUntil;
			}
		}
		entry.addListener(listener);
	}
	catch (e, st) {
		if (e is! ReportFailedException) {
			Future.error(e, st); // Report to crashlytics
		}
		if (context.mounted) {
			alertError(context, e.toStringDio());
		}
	}
}