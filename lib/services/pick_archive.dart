import 'package:chan/services/imageboard.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<String?> pickArchive(BuildContext context, Imageboard imageboard, List<String> boards, {
	bool offerAny = false
}) async {
	List<ImageboardSiteArchive> archives;
	try {
		archives = await modalLoad(
			context,
			'Scanning archives...',
			(controller) async {
				(Object, StackTrace)? firstError;
				final results = await Future.wait(imageboard.site.enabledArchives.map((archive) async {
					try {
						await archive.checkBoards(boards, priority: RequestPriority.interactive, cancelToken: controller.cancelToken);
						return archive;
					}
					on BoardNotFoundException {
						return null;
					}
					catch (e, st) {
						if (e is DioError && CancelToken.isCancel(e)) rethrow;
						firstError ??= (e, st);
						return null;
					}
				}));
				final archives = results.whereType<ImageboardSiteArchive>().toList();
				if (firstError case (final error, final stackTrace)? when archives.isEmpty) {
					Error.throwWithStackTrace(error, stackTrace);
				}
				return archives;
			},
			cancellable: true
		);
	}
	catch (e) {
		if (e is DioError && CancelToken.isCancel(e)) return null;
		if (!offerAny) rethrow;
		// Keep "Any" available so the user can clear an unavailable archive.
		archives = [];
	}
	if (!context.mounted) {
		return null;
	}
	if (archives.isEmpty && !offerAny) {
		showToast(
			context: context,
			message: 'Board not archived',
			icon: CupertinoIcons.exclamationmark_triangle
		);
		return null;
	}
	return await showAdaptiveDialog<String>(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Select archive'),
			actions: [
				for (final a in archives) AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context, a.name),
					child: Text(a.name)
				),
				if (offerAny) AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context, ''),
					child: const Text('Any')
				),
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context),
					child: const Text('Cancel')
				)
			]
		)
	);
}
