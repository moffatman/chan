import 'dart:async';

import 'package:chan/services/captcha.dart';
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
								child: SingleChildScrollView(
									child: AdaptiveChoiceControl<Map<String, String>>(
										knownWidth: 0,
										children: {
											for (final choice in method.choices)
												choice.value: (null, choice.name)
										},
										groupValue: choice,
										onValueChanged: (v) {
											setDialogState(() {
												choice = v;
											});
										}
									)
								)
							),
							actions: [
								AdaptiveDialogAction(
									isDefaultAction: true,
									onPressed: choice == null ? null : () {
										() async {
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
										}().then(completer.complete, onError: completer.completeError);
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