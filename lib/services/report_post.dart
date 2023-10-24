import 'dart:async';

import 'package:chan/services/captcha.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

bool _submissionFailed = false;

Future<void> reportPost({
	required BuildContext context,
	required ImageboardSite site,
	required String board,
	required int threadId,
	required int postId
}) async {
	try {
		final method = await modalLoad(
			context,
			'Fetching report details...',
			(_) => site.getPostReportMethod(board, threadId, postId),
			wait: const Duration(milliseconds: 100)
		);
		if (!context.mounted) {
			return;
		}
		switch (method) {
			case WebReportMethod():
				openBrowser(context, method.uri);
			case ChoiceReportMethod():
				Map<String, String>? choice;
				final completer = Completer<void>();
				showAdaptiveDialog<bool>(
					context: context,
					builder: (context) => StatefulBuilder(
						builder: (context, setDialogState) => AdaptiveAlertDialog(
							title: Text(method.question),
							content: Container(
								padding: const EdgeInsets.only(top: 16),
								width: 350,
								child: Column(
									children: [
										for (int i = 0; i < method.choices.length; i++) ...[
											if (i > 0) Divider(
												color: ChanceTheme.primaryColorOf(context),
												height: 8
											),
											AdaptiveButton(
												padding: const EdgeInsets.all(8),
												onPressed: () => setDialogState(() {
													if (choice == method.choices[i].value) {
														choice = null;
													}
													else {
														choice = method.choices[i].value;
													}
												}),
												child: Row(
													children: [
														Expanded(
															child: Text(method.choices[i].name)
														),
														const SizedBox(width: 8),
														choice == method.choices[i].value ? const Icon(Icons.radio_button_on_outlined) : const Icon(Icons.radio_button_off_outlined)
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
									onPressed: choice == null ? null : () {
										modalLoad(context, 'Submitting...', (_) async {
											final captchaSolution = await solveCaptcha(
												context: context,
												site: site,
												request: method.captchaRequest,
												// Don't want to implement failed headless tracking here
												disableHeadlessSolve: _submissionFailed
											);
											if (captchaSolution == null) {
												return;
											}
											await method.onSubmit(choice!, captchaSolution);
											if (context.mounted) {
												Navigator.pop(context);
											}
										}).then(completer.complete, onError: completer.completeError);
									},
									child: const Text('Submit')
								),
								AdaptiveDialogAction(
									child: const Text('Cancel'),
									onPressed: () => Navigator.pop(context, false)
								)
							]
						)
					)
				);
				await completer.future;
				if (!context.mounted) {
					return;
				}
				showToast(
					context: context,
					icon: CupertinoIcons.check_mark,
					message: 'Report submitted'
				);
		}
	}
	catch (e, st) {
		_submissionFailed = true; // Disable future headless solve
		Future.error(e, st); // Report to crashlytics
		if (context.mounted) {
			alertError(context, e.toStringDio());
		}
	}
}