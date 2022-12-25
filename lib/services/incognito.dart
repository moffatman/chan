import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';

import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:chan/util.dart';
import 'package:tuple/tuple.dart';

class IncognitoPersistence implements Persistence {
	final Persistence parent;
	final _ephemeralThreadStates = <ThreadIdentifier, Tuple2<PersistentThreadState, EasyListenable>>{};

	IncognitoPersistence(this.parent);

	@override
  Box<PersistentThreadState> get threadStateBox => parent.threadStateBox;

  @override
  void addListener(VoidCallback listener) => parent.addListener;

  @override
  Map<String, ImageboardBoard> get boards => parent.boards;

  @override
  PersistentBrowserState get browserState => parent.browserState;

  @override
  Future<void> deleteAllData() async {
    _ephemeralThreadStates.clear();
    await parent.deleteAllData();
  }

  @override
  void deleteSavedAttachment(Attachment attachment) => parent.deleteSavedAttachment(attachment);

  @override
  Future<void> didUpdateBrowserState() => parent.didUpdateBrowserState();

  @override
  Future<void> didUpdateHiddenMD5s() => parent.didUpdateHiddenMD5s();

  @override
  Future<void> didUpdateSavedPost() => parent.didUpdateSavedPost();

  @override
  void dispose() {
    print('IncognitoPersistence.dispose()');
    print(StackTrace.current);
		for (final pair in _ephemeralThreadStates.values) {
			pair.item2.dispose();
		}
	}

  @override
  ImageboardBoard getBoard(String boardName) => parent.getBoard(boardName);

  @override
  SavedAttachment? getSavedAttachment(Attachment attachment) => parent.getSavedAttachment(attachment);

  @override
  SavedPost? getSavedPost(Post post) => parent.getSavedPost(post);

  @override
  PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false}) {
    final existing = getThreadStateIfExists(thread);
		if (existing != null) {
			return existing;
		}
		final newState = PersistentThreadState(ephemeralOwner: this);
		_ephemeralThreadStates[thread] = Tuple2(newState, EasyListenable());
		return newState;
  }

  @override
  PersistentThreadState? getThreadStateIfExists(ThreadIdentifier thread) {
    return _ephemeralThreadStates[thread]?.item1 ?? parent.getThreadStateIfExists(thread);
  }

  @override
  bool get hasListeners => parent.hasListeners;

  @override
  EasyListenable get hiddenMD5sListenable => parent.hiddenMD5sListenable;

  @override
  String get id => parent.id;

  @override
  Future<void> initialize() => parent.initialize();

  @override
  Listenable listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return _ephemeralThreadStates[thread]?.item2 ?? parent.listenForPersistentThreadStateChanges(thread);
	}

  @override
  void notifyListeners() => parent.notifyListeners();

  @override
  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  @override
  void saveAttachment(Attachment attachment, File fullResolutionFile) => parent.saveAttachment(attachment, fullResolutionFile);

  @override
  void savePost(Post post, Thread thread) => parent.savePost(post, thread);

  @override
  Map<String, SavedAttachment> get savedAttachments => parent.savedAttachments;

  @override
  EasyListenable get savedAttachmentsListenable => parent.savedAttachmentsListenable;

  @override
  Map<String, SavedPost> get savedPosts => parent.savedPosts;

  @override
  EasyListenable get savedPostsListenable => parent.savedPostsListenable;

  @override
  Future<void> storeBoards(List<ImageboardBoard> newBoards) => parent.storeBoards(newBoards);

  @override
  void unsavePost(Post post) => parent.unsavePost(post);
	
	@override
	Future<void> ephemeralThreadStateDidUpdate(PersistentThreadState state) async {
		await Future.microtask(() => _ephemeralThreadStates[state.identifier]?.item2.didUpdate());
	}

  @override
  String toString() => 'IncognitoPersistence(parent: $parent)';
}