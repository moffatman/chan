import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive/modal_popup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

Future<void> selectWatchedThreadsSortMethod(BuildContext context, {VoidCallback? onMutate}) => showAdaptiveModalPopup<DateTime>(
	context: context,
	builder: (context) => AdaptiveActionSheet(
		title: const Text('Sort by...'),
		actions: {
			ThreadSortingMethod.savedTime: 'Order added',
			ThreadSortingMethod.lastPostTime: 'Latest reply',
			ThreadSortingMethod.lastReplyByYouTime: 'Latest reply by you',
			ThreadSortingMethod.alphabeticByTitle: 'Alphabetically',
			ThreadSortingMethod.threadPostTime: 'Latest thread'
		}.entries.map((entry) => AdaptiveActionSheetAction(
			child: Text(entry.value, style: TextStyle(
				fontWeight: entry.key == Persistence.settings.watchedThreadsSortingMethod ? FontWeight.bold : null
			)),
			onPressed: () {
				Settings.watchedThreadsSortingMethodSetting.value = entry.key;
				Navigator.of(context, rootNavigator: true).pop();
				onMutate?.call();
			}
		)).toList(),
		cancelButton: AdaptiveActionSheetAction(
			child: const Text('Cancel'),
			onPressed: () => Navigator.of(context, rootNavigator: true).pop()
		)
	)
);

void sortWatchedThreads(List<ImageboardScoped<ThreadWatch>> watches) {
	final d = DateTime(2000);
	if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastReplyByYouTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			final ta = a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier);
			final tb = b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier);
			Post? pa;
			Post? pb;
			if (ta?.youIds.isNotEmpty == true) {
				pa = ta!.thread?.posts_.tryFirstWhere((p) => p.id == ta.youIds.last);
			}
			if (tb?.youIds.isNotEmpty == true) {
				pb = tb!.thread?.posts_.tryFirstWhere((p) => p.id == tb.youIds.last);
			}
			return (pb?.time ?? d).compareTo(pa?.time ?? d);
		});
	}
	else if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			return (b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier)?.thread?.posts.last.time ?? d).compareTo(a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier)?.thread?.posts.last.time ?? d);
		});
	}
	else if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.alphabeticByTitle) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			final ta = a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier)?.thread;
			final tb = b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier)?.thread;
			return ta.compareTo(tb);
		});
	}
	else if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.threadPostTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			final ta = a.imageboard.persistence.getThreadStateIfExists(a.item.threadIdentifier)?.thread;
			final tb = b.imageboard.persistence.getThreadStateIfExists(b.item.threadIdentifier)?.thread;
			return (tb?.time ?? d).compareTo(ta?.time ?? d);
		});
	}
	else if (Persistence.settings.watchedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
		mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
			return (b.item.watchTime ?? d).compareTo((a.item.watchTime ?? d));
		});
	}
	mergeSort<ImageboardScoped<ThreadWatch>>(watches, compare: (a, b) {
		if (a.item.zombie == b.item.zombie) {
			return 0;
		}
		else if (a.item.zombie) {
			return 1;
		}
		else {
			return -1;
		}
	});
}

Comparator<PersistentThreadState> getSavedThreadsSortMethod() {
	final noDate = DateTime.fromMillisecondsSinceEpoch(0);
	return switch (Persistence.settings.savedThreadsSortingMethod) {
		ThreadSortingMethod.alphabeticByTitle => (a, b) => a.thread.compareTo(b.thread),
		ThreadSortingMethod.lastPostTime => (a, b) => (b.thread?.posts.last.time ?? noDate).compareTo(a.thread?.posts.last.time ?? noDate),
		ThreadSortingMethod.threadPostTime => (a, b) => (b.thread?.time ?? noDate).compareTo(a.thread?.time ?? noDate),
		ThreadSortingMethod.savedTime || _ => (a, b) => (b.savedTime ?? noDate).compareTo(a.savedTime ?? noDate)
	};
}

Future<void> selectSavedThreadsSortMethod(BuildContext context) => showAdaptiveModalPopup(
	context: context,
	useRootNavigator: true,
	builder: (context) => AdaptiveActionSheet(
		title: const Text('Sort by...'),
		actions: {
			ThreadSortingMethod.savedTime: 'Order added',
			ThreadSortingMethod.lastPostTime: 'Latest reply',
			ThreadSortingMethod.alphabeticByTitle: 'Alphabetically',
			ThreadSortingMethod.threadPostTime: 'Latest thread'
		}.entries.map((entry) => AdaptiveActionSheetAction(
			child: Text(entry.value, style: TextStyle(
				fontWeight: entry.key == Persistence.settings.savedThreadsSortingMethod ? FontWeight.bold : null
			)),
			onPressed: () {
				Settings.savedThreadsSortingMethodSetting.value = entry.key;
				Navigator.of(context, rootNavigator: true).pop();
			}
		)).toList(),
		cancelButton: AdaptiveActionSheetAction(
			child: const Text('Cancel'),
			onPressed: () => Navigator.of(context, rootNavigator: true).pop()
		)
	)
);

Comparator<ImageboardScoped<SavedPost>> getSavedPostsSortMethod() {
	return switch (Persistence.settings.savedThreadsSortingMethod) {
		ThreadSortingMethod.lastPostTime => (a, b) => b.item.post.time.compareTo(a.item.post.time),
		ThreadSortingMethod.threadPostTime => (a, b) {
						final ta = a.imageboard.persistence.getThreadStateIfExists(a.item.post.threadIdentifier)?.thread;
						final tb = b.imageboard.persistence.getThreadStateIfExists(b.item.post.threadIdentifier)?.thread;
						return (tb?.time ?? b.item.post.time).compareTo(ta?.time ?? a.item.post.time);
					},
		ThreadSortingMethod.savedTime || _ => (a, b) => b.item.savedTime.compareTo(a.item.savedTime)
	};
}