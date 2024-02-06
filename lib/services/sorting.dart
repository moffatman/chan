import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';

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
	Comparator<PersistentThreadState> sortMethod = (a, b) => 0;
	final noDate = DateTime.fromMillisecondsSinceEpoch(0);
	if (Persistence.settings.savedThreadsSortingMethod == ThreadSortingMethod.savedTime) {
		sortMethod = (a, b) => (b.savedTime ?? noDate).compareTo(a.savedTime ?? noDate);
	}
	else if (Persistence.settings.savedThreadsSortingMethod == ThreadSortingMethod.lastPostTime) {
		sortMethod = (a, b) => (b.thread?.posts.last.time ?? noDate).compareTo(a.thread?.posts.last.time ?? noDate);
	}
	else if (Persistence.settings.savedThreadsSortingMethod == ThreadSortingMethod.alphabeticByTitle) {
		sortMethod = (a, b) => a.thread.compareTo(b.thread);
	}
	return sortMethod;
}