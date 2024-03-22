import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> reportPost({
	required BuildContext context,
	required ImageboardSite site,
	required PostIdentifier post
}) async {
	try {
		final method = await modalLoad(
			context,
			'Fetching report details...',
			(_) => site.getPostReportMethod(post),
			wait: const Duration(milliseconds: 100)
		);
		if (!context.mounted) {
			return;
		}
		switch (method) {
			case WebReportMethod():
				openBrowser(context, method.uri);
			case ChoiceReportMethod():
				ChoiceReportMethodChoice? choice;
				final couldUseLoginSystem = site.loginSystem?.getSavedLoginFields() != null;
				bool useLoginSystem = couldUseLoginSystem;
				final entry = await showAdaptiveDialog<QueuedReport>(
					context: context,
					builder: (context) => StatefulBuilder(
						builder: (context, setDialogState) => AdaptiveAlertDialog(
							title: Text(method.question),
							content: Container(
								padding: const EdgeInsets.only(top: 16),
								width: 350,
								child: Column(
									children: [
										if (couldUseLoginSystem) Row(
											children: [
												ImageboardIcon(
													site: site
												),
												Expanded(
													child: Text('Use ${site.loginSystem?.name}?')
												),
												const SizedBox(width: 8),
												Checkbox.adaptive(
													activeColor: ChanceTheme.primaryColorOf(context),
													checkColor: ChanceTheme.backgroundColorOf(context),
													value: useLoginSystem,
													onChanged: (v) {
														setDialogState(() {
															useLoginSystem = v!;
														});
													}
												)
											],
										),
										for (int i = 0; i < method.choices.length; i++) ...[
											if (i > 0 || couldUseLoginSystem) Divider(
												color: ChanceTheme.primaryColorOf(context),
												height: 8
											),
											AdaptiveButton(
												padding: const EdgeInsets.all(8),
												onPressed: () => setDialogState(() {
													if (choice == method.choices[i]) {
														choice = null;
													}
													else {
														choice = method.choices[i];
													}
												}),
												child: Row(
													children: [
														Expanded(
															child: Text(method.choices[i].name)
														),
														const SizedBox(width: 8),
														choice == method.choices[i] ? const Icon(Icons.radio_button_on_outlined) : const Icon(Icons.radio_button_off_outlined)
													]
												)
											)
										]
									]
								)
							),
							actions: [
								AdaptiveDialogAction(
									isDefaultAction: true,
									onPressed: choice == null ? null : () async {
										Navigator.pop(context, Outbox.instance.submitReport(context, site.imageboard!.key, method, choice!, useLoginSystem));
									},
									child: const Text('Submit')
								),
								AdaptiveDialogAction(
									child: const Text('Cancel'),
									onPressed: () => Navigator.pop(context)
								)
							]
						)
					)
				);
				if (!context.mounted || entry == null) {
					return;
				}
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
						entry.removeListener(listener);
						showToast(
							context: context,
							icon: CupertinoIcons.check_mark,
							message: 'Report submitted'
						);
					}
					else if (state is QueueStateFailed<void>) {
						alertError(context, 'Report failed\n${state.error.toStringDio()}', actions: {
							'More info': () => showOutboxModalForThread(
								context: context,
								imageboardKey: context.read<Imageboard?>()?.key,
								board: post.board,
								threadId: post.threadId,
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
				break;
		}
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