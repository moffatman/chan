import 'package:chan/models/thread.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/attachment.dart';

import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:chan/util.dart';

class IncognitoPersistence implements Persistence {
	final Persistence parent;
	final _ephemeralThreadStates = <ThreadIdentifier, PersistentThreadState>{};

	IncognitoPersistence(this.parent);

  @override
  void addListener(VoidCallback listener) => parent.addListener;

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
  Future<void> didUpdateSavedPost() => parent.didUpdateSavedPost();

  @override
  void dispose() {
    print('IncognitoPersistence.dispose()');
    print(StackTrace.current);
		for (final state in _ephemeralThreadStates.values) {
			state.dispose();
		}
	}

  @override
  ImageboardBoard getBoard(String boardName) => parent.getBoard(boardName);

  @override
  SavedAttachment? getSavedAttachment(Attachment attachment) => parent.getSavedAttachment(attachment);

  @override
  SavedPost? getSavedPost(Post post) => parent.getSavedPost(post);

  @override
  PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false, bool initiallyHideFromHistory = false}) {
    final existing = getThreadStateIfExists(thread);
		if (existing != null) {
      existing.showInHistory ??= Persistence.settings.recordThreadsInHistory;
			return existing;
		}
		final newState = PersistentThreadState(
			imageboardKey: imageboardKey,
			board: thread.board,
			id: thread.id,
			showInHistory: initiallyHideFromHistory ? null : Persistence.settings.recordThreadsInHistory,
			incognito: true
		);
		_ephemeralThreadStates[thread] = newState;
		return newState;
  }

  @override
  PersistentThreadState? getThreadStateIfExists(ThreadIdentifier? thread) {
    return _ephemeralThreadStates[thread] ?? parent.getThreadStateIfExists(thread);
  }

  @override
  bool get hasListeners => parent.hasListeners;

  @override
  String get imageboardKey => parent.imageboardKey;

  @override
  Future<void> initialize() => parent.initialize();

  @override
  Listenable listenForThreadChanges(ThreadIdentifier thread) {
		return parent.listenForThreadChanges(thread);
	}

  @override
  ValueListenable<PersistentThreadState?> listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return _ephemeralThreadStates[thread] ?? parent.listenForPersistentThreadStateChanges(thread);
	}

  @override
  void notifyListeners() => parent.notifyListeners();

  @override
  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  @override
  void saveAttachment(Attachment attachment, File fullResolutionFile, String ext) => parent.saveAttachment(attachment, fullResolutionFile, ext);

  @override
  void savePost(Post post, {DateTime? savedTime}) => parent.savePost(post, savedTime: savedTime);

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
  String toString() => 'IncognitoPersistence(parent: $parent)';
  
  @override
  ImageboardBoard? maybeGetBoard(String boardName) => parent.maybeGetBoard(boardName);
  
  @override
  Future<void> setBoard(String boardName, ImageboardBoard board) => parent.setBoard(boardName, board);

	@override
	Future<void> removeBoard(String boardName) => parent.removeBoard(boardName);
	
	@override
	Iterable<ImageboardBoard> get boards => parent.boards;

  @override
  SpamFilterStatus getSpamFilterStatus(String? ip) => parent.getSpamFilterStatus(ip);
}