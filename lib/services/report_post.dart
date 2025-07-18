import 'dart:async';

import 'package:chan/models/post.dart';
import 'package:chan/services/captcha.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
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
			(c) => site.getPostReportMethod(post, cancelToken: c.cancelToken),
			wait: const Duration(milliseconds: 100)
		);
		final outerContext = context;
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
										Navigator.pop(context, Outbox.instance.submitReport(outerContext, site.imageboard!.key, method, choice!, useLoginSystem));
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
						showToast(
							context: context,
							icon: CupertinoIcons.check_mark,
							message: 'Report submitted'
						);
					}
					else if (state is QueueStateFailed<void>) {
						alertError(context, state.error, state.stackTrace, actions: {
							'More info': () => showOutboxModalForThread(
								context: context,
								imageboardKey: context.read<Imageboard?>()?.key,
								board: post.board,
								threadId: post.threadId,
								canPopWithDraft: false
							)
						});
					}
				}
				entry.addListener(listener);
				break;
		}
	}
	catch (e, st) {
		if (e is! ReportFailedException && e is! BannedException) {
			Future.error(e, st); // Report to crashlytics
		}
		if (context.mounted) {
			alertError(context, e, st);
		}
	}
}