import 'dart:ui';

import 'package:chan/main.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/draft_post.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _OutboxModalPopType {
	copy,
	move,
	goToThread
}

typedef _OutboxModalPop = (QueueEntry entry, _OutboxModalPopType type);

extension _CapitalizedName on MapEntry<QueueEntryActionKey, OutboxQueue> {
	String get capitalizedName => switch (value.list.length) {
		1 => key.$3.nounSingularCapitalized,
		_ => key.$3.nounPluralCapitalized
	};
}

class QueueEntryWidget<T> extends StatelessWidget {
	final QueueEntry<T> entry;
	final bool replyBoxMode;
	final VoidCallback? onMove;
	final VoidCallback? onCopy;
	final VoidCallback? onGoToThread;

	const QueueEntryWidget({
		required this.entry,
		required this.replyBoxMode,
		this.onMove,
		this.onCopy,
		this.onGoToThread,
		super.key
	});

	Widget _buildQueuedReport(QueuedReport entry) {
		final thread = entry.imageboard.persistence.getThreadStateIfExists(entry.thread)?.thread;
		if (thread != null) {
			final target = thread.posts_.tryFirstWhere((p) => p.id == entry.method.post.postId);
			if (target != null) {
				return Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Text('${entry.method.question}: ${entry.choice.name}'),
						const SizedBox(height: 16),
						Builder(
							builder: (context) => DecoratedBox(
								decoration: BoxDecoration(
									border: Border.all(color: ChanceTheme.primaryColorWithBrightness20Of(context))
								),
								position: DecorationPosition.foreground,
								child: ChangeNotifierProvider<PostSpanZoneData>(
									create: (context) => PostSpanRootZoneData(
										imageboard: entry.imageboard,
										thread: thread,
										style: PostSpanZoneStyle.linear
									),
									child: IgnorePointer(
										child: PostRow(
											post: target
										)
									)
								)
							)
						)
					]
				);
			}
		}
		return Text('${entry.method.question}: ${entry.choice.name}\n\n${entry.site.getWebUrl(
			board: entry.method.post.board,
			threadId: entry.method.post.threadId,
			postId: entry.method.post.postId
		)}');
	}

	Widget _buildQueuedDeletion(QueuedDeletion entry) {
		// Lazy but this should never really be seen
		return Text('Deletion of ${entry.imageboardKey}/${entry.thread.board}/${entry.thread.id}/${entry.receipt.id}');
	}

	@override
	Widget build(BuildContext context) {
		final queue = entry.queue;
		final aboveAnimatedBuilderContext = context;
		return AnimatedBuilder(
			animation: entry,
			builder: (context, _) {
				final state = entry.state;
				final WaitMetadata? wait;
				final CancelToken? cancelToken;
				if (state is QueueStateSubmitting<T>) {
					wait = state.wait;
					cancelToken = state.cancelToken;
				}
				else {
					wait = null;
					cancelToken = null;
				}
				// Need these to have immediate feedback before events processed and this builder reruns
				bool skipWaitPressed = false;
				bool skipQueuePressed = false;
				bool cancelPressed = cancelToken?.isCancelled ?? false;
				final onCopy = this.onCopy;
				final onMove = this.onMove;
				final onGoToThread = this.onGoToThread;
				final canPress = onMove != null || onCopy != null || onGoToThread != null;
				return ContextMenu(
					useLayoutBuilder: false,
					actions: [
						if (onCopy != null) ContextMenuAction(
							trailingIcon: CupertinoIcons.doc_on_doc,
							child: const Text('Copy'),
							onPressed: onCopy
						),
						if (onMove != null) ContextMenuAction(
							trailingIcon: CupertinoIcons.scissors,
							child: const Text('Move'),
							onPressed: onMove
						),
						if (onGoToThread != null) ContextMenuAction(
							trailingIcon: CupertinoIcons.return_icon,
							child: const Text('Go to thread'),
							onPressed: onGoToThread
						),
						if (state.isSubmittable) ContextMenuAction(
							trailingIcon: CupertinoIcons.delete,
							child: const Text('Delete'),
							onPressed: () {
								entry.delete();
								showUndoToast(
									context: context,
									message: 'Deleted queued ${entry.action.nounSingularLowercase}',
									onUndo: entry.undelete
								);
							}
						)
						// Avoid empty [actions]
						else if (!canPress) ContextMenuAction(
							trailingIcon: CupertinoIcons.xmark,
							child: const Text('Dummy'),
							onPressed: () {}
						)
					],
					child: Container(
						decoration: BoxDecoration(
							border: Border(
								top: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))
							),
							color: ChanceTheme.backgroundColorOf(context)
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Stack(
									children: [
										if (!state.isIdle) LinearProgressIndicator(
											valueColor: AlwaysStoppedAnimation(ChanceTheme.primaryColorOf(context)),
											backgroundColor: ChanceTheme.primaryColorOf(context).withOpacity(0.7)
										),
										Padding(
											padding: const EdgeInsets.symmetric(vertical: 8),
											child: Row(
												children: [
													const SizedBox(width: 16),
													if (state is QueueStateFailed<T>) AdaptiveIconButton(
														icon: const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.red),
														onPressed: () => alertError(context, state.error.toStringDio())
													),
													if (entry.isArchived) Padding(
														padding: const EdgeInsets.all(8),
														child: Icon(CupertinoIcons.archivebox, color: ChanceTheme.primaryColorWithBrightness50Of(context))
													),
													Expanded(
														child: Text(
															switch (state) {
																QueueStateSubmitting<T>() => state.message ?? 'Submitting',
																QueueStateNeedsCaptcha<T>() => 'Waiting',
																QueueStateWaitingWithCaptcha<T>() => 'Waiting with captcha',
																QueueStateIdle<T>() => 'Draft',
																QueueStateDeleted<T>() || QueueStateFailed<T>() || QueueStateDone<T>() => switch (entry.isArchived) {
																	true => 'Thread archived',
																	false => ''
																}
															},
															style: TextStyle(
																color: switch (state) {
																	QueueStateSubmitting<T>() => ChanceTheme.primaryColorWithBrightness80Of(context),
																	_ => ChanceTheme.primaryColorWithBrightness50Of(context)
																}
															)
														)
													),
													// Skip queue timer button
													if (!state.isIdle && queue != null) StatefulBuilder(
														builder: (context, setState) => AnimatedBuilder(
															animation: queue,
															builder: (context, _) {
																final (DateTime, VoidCallback) pair;
																if (queue.captchaAllowedTime.isAfter(DateTime.now())) {
																	pair = (queue.captchaAllowedTime, () => queue.captchaAllowedTime = DateTime.now());
																}
																else if (queue.allowedTime.isAfter(DateTime.now())) {
																	pair = (queue.allowedTime, () => queue.allowedTime = DateTime.now());
																}
																else {
																	return const SizedBox.shrink();
																}
																return AdaptiveThinButton(
																	padding: const EdgeInsets.all(4),
																	onPressed: skipQueuePressed ? null : () {
																		pair.$2();
																		setState(() {
																			skipQueuePressed = true;
																		});
																	},
																	child: TimedRebuilder<String>(
																		interval: const Duration(seconds: 1),
																		function: () => formatDuration(pair.$1.difference(DateTime.now())),
																		builder: (context, s) => Text(s, style: const TextStyle(
																			fontFeatures: [FontFeature.tabularFigures()]
																		))
																	)
																);
															}
														)
													),
													if (wait != null) Padding(
														padding: const EdgeInsets.only(right: 8),
														child: StatefulBuilder(
															builder: (context, setState) => AdaptiveThinButton(
																padding: const EdgeInsets.all(4),
																onPressed: skipWaitPressed ? null : () {
																	wait!.skip();
																	setState(() {
																		skipWaitPressed = true;
																	});
																},
																child: TimedRebuilder<String>(
																	interval: const Duration(seconds: 1),
																	function: () => formatDuration(wait!.until.difference(DateTime.now())),
																	builder: (context, s) => Text(s, style: const TextStyle(
																		fontFeatures: [FontFeature.tabularFigures()]
																	))
																)
															)
														)
													),
													if (entry.state.isSubmittable && entry.site.loginSystem?.getSavedLoginFields() != null) AdaptiveIconButton(
														onPressed: entry.isArchived ? null : () {
															entry.useLoginSystem = !entry.useLoginSystem;
														},
														icon: Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																SizedBox(
																	width: 16,
																	height: 16,
																	child: ExtendedImage.network(
																		entry.site.passIconUrl.toString(),
																		cache: true,
																		enableLoadState: false,
																		fit: BoxFit.contain
																	)
																),
																const SizedBox(width: 4),
																Icon(entry.useLoginSystem ? CupertinoIcons.checkmark_square : CupertinoIcons.square)
															]
														)
													),
													if (cancelToken != null || state is QueueStateNeedsCaptcha<T> || state is QueueStateWaitingWithCaptcha<T>) StatefulBuilder(
														builder: (context, setState) => AdaptiveIconButton(
															onPressed: cancelPressed ? null : () {
																entry.cancel();
																setState(() {
																	cancelPressed = true;
																});
															},
															icon: const Icon(CupertinoIcons.xmark, size: 20)
														)
													)
													else if (state.isSubmittable) AdaptiveIconButton(
														icon: const Icon(CupertinoIcons.paperplane, size: 20),
														onPressed: entry.isArchived ? null : () => entry.submit(aboveAnimatedBuilderContext)
													),
													const SizedBox(width: 16)
												]
											)
										)
									]
								),
								Flexible(
									child: Container(
										margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
										foregroundDecoration: BoxDecoration(
											border: Border.all(color: ChanceTheme.primaryColorWithBrightness20Of(context))
										),
										child: CupertinoButton(
											padding: const EdgeInsets.all(16),
											onPressed: canPress ? () async {
												if (!entry.isArchived || replyBoxMode) {
													(onGoToThread ?? onMove)?.call();
													return;
												}
												final outerContext = context;
												final action = await showAdaptiveDialog<VoidCallback>(
													barrierDismissible: true,
													context: context,
													builder: (context) => AdaptiveAlertDialog(
														title: const Text('Thread is archived'),
														content: const Text('What would you like to do with this orphan draft reply?'),
														actions: [
															if (onMove != null) AdaptiveDialogAction(
																onPressed: () => Navigator.pop(context, onMove),
																child: const Text('Move to current thread')
															),
															if (onCopy != null) AdaptiveDialogAction(
																onPressed: () => Navigator.pop(context, onCopy),
																child: const Text('Copy to current thread')
															),
															if (onGoToThread != null) AdaptiveDialogAction(
																onPressed: () => Navigator.pop(context, onGoToThread),
																child: const Text('Go to archived thread')
															),
															AdaptiveDialogAction(
																onPressed: () => Navigator.pop(context, () {
																	entry.delete();
																	showUndoToast(
																		context: outerContext,
																		message: 'Deleted queued ${entry.action.nounSingularLowercase}',
																		onUndo: entry.undelete
																	);
																}),
																child: const Text('Delete it')
															),
															AdaptiveDialogAction(
																onPressed: () => Navigator.pop(context),
																child: const Text('Cancel')
															)
														]
													)
												);
												action?.call();
											} : null,
											child: switch (entry) {
												QueuedPost p => DraftPostWidget(
													imageboard: entry.imageboard,
													post: p.post,
													origin: switch (onGoToThread) {
														null => DraftPostWidgetOrigin.inCurrentThread,
														_ => DraftPostWidgetOrigin.elsewhere
													}
												),
												QueuedReport e => _buildQueuedReport(e),
												QueuedDeletion e => _buildQueuedDeletion(e)
											}
										)
									)
								)
							]
						)
					)
				);
			}
		);
	}
}

class OutboxModal extends StatelessWidget {
	final String? imageboardKey;
	final String? board;
	final int? threadId;
	final bool canPopWithDraft;

	const OutboxModal({
		required this.imageboardKey,
		required this.board,
		required this.threadId,
		required this.canPopWithDraft,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		final parentThread = switch ((board, threadId)) {
			(String board, int threadId) => ThreadIdentifier(board, threadId),
			_ => null
		};
		return AnimatedBuilder(
			animation: Outbox.instance,
			builder: (context, _) {
				final queues = Outbox.instance.queues.entries.where((q) => q.value.list.any((e) => !e.state.isFinished)).toList();
				return OverscrollModalPage.sliver(
					sliver: SliverList(
						delegate: SliverChildBuilderDelegate(
							(context, i) {
								if (i == 0) {
									return Builder(
										builder: (context) => Container(
											padding: const EdgeInsets.all(16),
											decoration: BoxDecoration(
												color: ChanceTheme.backgroundColorOf(context),
												border: Border(
													bottom: BorderSide(color: ChanceTheme.primaryColorWithBrightness20Of(context))
												)
											),
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													const Row(
														children: [
															SizedBox(width: 16),
															Icon(CupertinoIcons.tray_arrow_up),
															SizedBox(width: 8),
															Expanded(
																child: Text('Outbox')
															)
														]
													),
													if (queues.isEmpty) const Center(
														child: Padding(
															padding: EdgeInsets.all(16),
															child: Text('Nothing queued')
														)
													)
												]
											)
										)
									);
								}
								final queue = queues[i - 1];
								return Column(
									key: ObjectKey(queue),
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Builder(
											builder: (context) => Container(
												padding: const EdgeInsets.all(8),
												color: ChanceTheme.barColorOf(context),
												child: Row(
													children: [
														const SizedBox(width: 16),
														ImageboardIcon(
															imageboardKey: queue.key.$1,
														),
														const SizedBox(width: 8),
														Expanded(
															child: Text((ImageboardRegistry.instance.getImageboard(queue.key.$1)?.site.formatBoardName(queue.key.$2)).toString())
														),
														const SizedBox(width: 8),
														Text(queue.capitalizedName),
														const SizedBox(width: 16)
													]
												)
											)
										),
										...queue.value.list.where((entry) => !entry.state.isFinished).map((entry) => QueueEntryWidget(
											key: ObjectKey(entry),
											entry: entry,
											replyBoxMode: false,
											onGoToThread: (imageboardKey == entry.imageboardKey && parentThread == entry.thread) ? null : () {
												Navigator.pop(context, (entry, _OutboxModalPopType.goToThread));
											},
											onMove: entry is QueuedPost && canPopWithDraft ? () {
												Navigator.pop(context, (entry, _OutboxModalPopType.move));
											} : null,
											onCopy: entry is QueuedPost && canPopWithDraft ? () {
												Navigator.pop(context, (entry, _OutboxModalPopType.copy));
											} : null
										))
									]
								);
							},
							childCount: queues.length + 1,
							findChildIndexCallback: (key) {
								if (key is ObjectKey) {
									final obj = key.value;
									if (obj is MapEntry<QueueEntryActionKey, OutboxQueue>) {
										final idx = queues.indexWhere((q) => q.key == obj.key);
										if (idx >= 0) {
											return idx;
										}
									}
								}
								return null;
							}
						)
					)
				);
			}
		);
	}
}

/// If user taps a draft in this thread, return the draft
/// Else, open what they tapped
Future<({QueuedPost post, bool deleteOriginal})?> showOutboxModalForThread({
	required BuildContext context,
	required String? imageboardKey,
	required String? board,
	required int? threadId,
	required bool canPopWithDraft
}) async {
	final tuple = await Navigator.push<_OutboxModalPop>(context, TransparentRoute(
		builder: (context) => OutboxModal(
			imageboardKey: imageboardKey,
			board: board,
			threadId: threadId,
			canPopWithDraft: canPopWithDraft
		)
	));
	if (tuple == null) {
		return null;
	}
	final result = tuple.$1;
	if (result is QueuedPost) {
		if (tuple.$2 == _OutboxModalPopType.move) {
			return (
				post: result,
				deleteOriginal: true
			);
		}
		if (tuple.$2 == _OutboxModalPopType.copy) {
			return (
				post: result,
				deleteOriginal: false
			);
		}
		final link = ImageboardRegistry.instance.getImageboard(result.imageboardKey)?.site.getWebUrl(
			board: result.post.board,
			threadId: result.post.threadId
		);
		if (link != null) {
			// Opens the thread with the draft
			fakeLinkStream.add(link);
		}
	}
	else if (result is QueuedReport) {
		final link = ImageboardRegistry.instance.getImageboard(result.imageboardKey)?.site.getWebUrl(
			board: result.method.post.board,
			threadId: result.method.post.threadId,
			postId: result.method.post.postId
		);
		if (link != null) {
			// Opens the reported post
			fakeLinkStream.add(link);
		}
	}
	return null;
}