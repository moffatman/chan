import 'dart:math' as math;

import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/sorting.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/tab_menu.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';
import 'package:provider/provider.dart';

extension ShouldCountAsUnread on ImageboardScoped<ThreadWatch> {
	PersistentThreadState? get threadState => imageboard.persistence.getThreadStateIfExists(item.threadIdentifier);
	bool get shouldCountAsUnread {
		if (item.localYousOnly) {
			return (threadState?.unseenReplyIdsToYouCount() ?? 0) > 0;
		}
		return (threadState?.unseenReplyCount() ?? 0) > 0;
	}
}

final _watchMutex = ReadWriteMutex();
Future<List<ImageboardScoped<ThreadWatch>>> loadWatches() => _watchMutex.protectRead(() async {
	final watches = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.browserState.threadWatches.values.map(i.scope)).toList();
	await Future.wait(watches.map((watch) async {
		await watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier)?.ensureThreadLoaded();
	}));
	sortWatchedThreads(watches);
	return watches;
});

bool anyUnreadWatches() {
	return ImageboardRegistry.instance.imageboards.any(
		(i) => i.persistence.browserState.threadWatches.values.any(
			(w) => (i.persistence.getThreadStateIfExists(w.threadIdentifier)?.unseenReplyCount() ?? 0) > 0));
}

Future<void> markAllWatchedThreadsAsRead(BuildContext context, {VoidCallback? onMutate}) async {
	final watches = await loadWatches();
	final cleared = <({
		PersistentThreadState threadState,
		Set<int> unseenPostIds,
		int? lastSeenPostId
	})>[];
	for (final watch in watches) {
		final threadState = watch.imageboard.persistence.getThreadStateIfExists(watch.item.threadIdentifier);
		if (threadState != null && threadState.unseenPostIds.data.isNotEmpty) {
			cleared.add((
				threadState: threadState,
				unseenPostIds: threadState.unseenPostIds.data.toSet(),
				lastSeenPostId: threadState.lastSeenPostId
			));
			threadState.unseenPostIds.data.clear();
			threadState.lastSeenPostId = threadState.thread?.posts_.fold<int>(0, (m, p) => math.max(m, p.id));
			threadState.didUpdate();
			await threadState.save();
		}
	}
	if (context.mounted) {
		showUndoToast(
			context: context,
			message: 'Marked ${describeCount(cleared.length, 'thread')} as read',
			onUndo: () async {
				for (final item in cleared) {
					item.threadState.unseenPostIds.data.addAll(item.unseenPostIds);
					item.threadState.lastSeenPostId = item.lastSeenPostId;
					item.threadState.didUpdate();
					await item.threadState.save();
				}
				onMutate?.call();
			}
		);
	}
	onMutate?.call();
}

bool anyWatches() {
	return ImageboardRegistry.instance.imageboards.any(
		(i) => i.persistence.browserState.threadWatches.isNotEmpty);
}

bool anyZombieWatches() {
	return ImageboardRegistry.instance.imageboards.any(
		(i) => i.persistence.browserState.threadWatches.values.any(
			(w) => w.zombie));
}

Future<void> removeZombieWatches(BuildContext context, {VoidCallback? onMutate}) => _watchMutex.protectWrite(() async {
	final toRemove = ImageboardRegistry.instance.imageboards.expand(
		(i) => i.persistence.browserState.threadWatches.values.where(
			(w) => w.zombie).map(i.scope)).toList();
	for (final watch in toRemove) {
		await watch.imageboard.notifications.removeWatch(watch.item);
	}
	if (context.mounted) {
		showUndoToast(
			context: context,
			message: 'Removed ${describeCount(toRemove.length, 'watch', plural: 'watches')}',
			onUndo: () => _watchMutex.protectWrite(() async {
				for (final watch in toRemove) {
					await watch.imageboard.notifications.insertWatch(watch.item);
				}
				onMutate?.call();
			})
		);
	}
	onMutate?.call();
});

Future<void> removeAllWatches(BuildContext context, {VoidCallback? onMutate}) => _watchMutex.protectWrite(() async {
	final toRemove = ImageboardRegistry.instance.imageboards.expand(
		(i) => i.persistence.browserState.threadWatches.values.map(i.scope)).toList();
	for (final watch in toRemove) {
		await watch.imageboard.notifications.removeWatch(watch.item);
	}
	if (context.mounted) {
		showUndoToast(
			context: context,
			message: 'Removed ${describeCount(toRemove.length, 'watch', plural: 'watches')}',
			onUndo: () => _watchMutex.protectWrite(() async {
				for (final watch in toRemove) {
					await watch.imageboard.notifications.insertWatch(watch.item);
				}
				onMutate?.call();
			})
		);
	}
	onMutate?.call();
});

List<TabMenuAction> getWatchedThreadsActions(BuildContext context, {VoidCallback? onMutate}) => [
	TabMenuAction(
		icon: CupertinoIcons.xmark_circle,
		title: 'Mark all as read',
		onPressed: anyUnreadWatches() ? () {
			markAllWatchedThreadsAsRead(context, onMutate: onMutate);
		} : null
	),
	TabMenuAction(
		icon: CupertinoIcons.bin_xmark,
		title: 'Remove archived',
		onPressed: anyZombieWatches() ? () {
			removeZombieWatches(context, onMutate: onMutate);
		} : null,
		isDestructiveAction: true
	),
	TabMenuAction(
		icon: CupertinoIcons.xmark,
		title: 'Remove all',
		onPressed: anyWatches() ? () {
			removeAllWatches(context, onMutate: onMutate);
		} : null,
		isDestructiveAction: true
	)
];

Future<void> unsaveAllSavedThreads(BuildContext context, {VoidCallback? onMutate}) async {
	final toDelete = {
		for (final state in Persistence.sharedThreadStateBox.values)
			if (state.savedTime != null)
				state: state.savedTime
	};
	final ok = await showAdaptiveDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Are you sure?'),
			content: Text('All ${describeCount(toDelete.length, 'saved thread')} will be unsaved'),
			actions: [
				AdaptiveDialogAction(
					isDestructiveAction: true,
					onPressed: () => Navigator.pop(context, true),
					child: const Text('Unsave all')
				),
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context),
					child: const Text('Cancel')
				)
			]
		)
	);
	if (!context.mounted || ok != true) {
		return;
	}
	for (final state in toDelete.keys) {
		state.savedTime = null;
		await state.save();
	}
	onMutate?.call();
	if (!context.mounted) {
		return;
	}
	showUndoToast(
		context: context,
		message: 'Unsaved ${describeCount(toDelete.length, 'thread')}',
		onUndo: () async {
			for (final entry in toDelete.entries) {
				entry.key.savedTime = entry.value;
				await entry.key.save();
			}
			onMutate?.call();
		}
	);
}

Future<void> unsaveAllSavedPosts(BuildContext context, {VoidCallback? onMutate}) async {
	final toDelete = ImageboardRegistry.instance.imageboards.expand(
		(i) => i.persistence.savedPosts.values.map(i.scope)).toList();
	final ok = await showAdaptiveDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: const Text('Are you sure?'),
			content: Text('All ${describeCount(toDelete.length, 'saved posts')} will be deleted'),
			actions: [
				AdaptiveDialogAction(
					isDestructiveAction: true,
					onPressed: () => Navigator.pop(context, true),
					child: const Text('Delete all')
				),
				AdaptiveDialogAction(
					onPressed: () => Navigator.pop(context),
					child: const Text('Cancel')
				)
			]
		)
	);
	if (!context.mounted || ok != true) {
		return;
	}
	for (final item in toDelete) {
		item.imageboard.persistence.unsavePost(item.item.post);
	}
	onMutate?.call();
	if (!context.mounted) {
		return;
	}
	showUndoToast(
		context: context,
		message: 'Deleted ${describeCount(toDelete.length, 'saved post')}',
		onUndo: () async {
			for (final item in toDelete) {
				item.imageboard.persistence.savePost(item.item.post, savedTime: item.item.savedTime);
			}
			onMutate?.call();
		}
	);
}

Future<void> showDeleteHistoryPopup(BuildContext context) async {
	final settings = context.read<Settings>();
	final toDelete = await showAdaptiveDialog<List<PersistentThreadState>>(
		context: context,
		barrierDismissible: true,
		builder: (context) => StatefulBuilder(
			builder: (context, setDialogState) {
				final openTabThreadBoxKeys = Persistence.tabs.map((t) => '${t.imageboardKey}/${t.thread?.board}/${t.thread?.id}').toSet();
				final states = Persistence.sharedThreadStateBox.values.where((i) => i.savedTime == null && i.threadWatch == null && (settings.includeThreadsYouRepliedToWhenDeletingHistory || i.youIds.isEmpty) && !openTabThreadBoxKeys.contains(i.boxKey)).toList();
				final thisSessionStates = states.where((s) => !s.lastOpenedTime.isBefore(Persistence.appLaunchTime)).toList();
				final now = DateTime.now();
				final lastDayStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 1).toList();
				final lastWeekStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 7).toList();
				return AdaptiveAlertDialog(
					title: const Text('Clear history'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const Text('Saved, watched, or opened threads will not be included'),
							const SizedBox(height: 16),
							Row(
								children: [
									const Expanded(
										child: Text('Include threads with your posts')
									),
									AdaptiveSwitch(
										value: settings.includeThreadsYouRepliedToWhenDeletingHistory,
										onChanged: (v) {
											setDialogState(() {
												Settings.includeThreadsYouRepliedToWhenDeletingHistorySetting.value = v;
											});
										}
									)
								]
							)
						]
					),
					actions: [
						AdaptiveDialogAction(
							onPressed: () async {
								Navigator.pop(context, thisSessionStates);
							},
							isDestructiveAction: true,
							child: Text('This session (${thisSessionStates.length})')
						),
						AdaptiveDialogAction(
							onPressed: () async {
								Navigator.pop(context, lastDayStates);
							},
							isDestructiveAction: true,
							child: Text('Today (${lastDayStates.length})')
						),
						AdaptiveDialogAction(
							onPressed: () async {
								Navigator.pop(context, lastWeekStates);
							},
							isDestructiveAction: true,
							child: Text('This week (${lastWeekStates.length})')
						),
						AdaptiveDialogAction(
							onPressed: () async {
								Navigator.pop(context, states);
							},
							isDestructiveAction: true,
							child: Text('All time (${states.length})')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				);
			}
		)
	);
	if (toDelete != null) {
		final watches = <ImageboardScoped<ThreadWatch>>[];
		for (final state in toDelete) {
			final watch = state.threadWatch;
			final imageboard = state.imageboard;
			if (watch != null && imageboard != null) {
				watches.add(imageboard.scope(watch));
			}
			await state.delete();
		}
		if (context.mounted) {
			showUndoToast(
				context: context,
				message: 'Deleted ${describeCount(toDelete.length, 'thread')}',
				onUndo: () async {
					for (final state in toDelete) {
						await Persistence.sharedThreadStateBox.put(state.boxKey, state);
					}
					for (final watch in watches) {
						await watch.imageboard.notifications.insertWatch(watch.item);
					}
				}
			);
		}
	}
}
