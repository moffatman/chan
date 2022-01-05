import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
part 'persistence.g.dart';

class UriAdapter extends TypeAdapter<Uri> {
	@override
	final typeId = 12;

	@override
	Uri read(BinaryReader reader) {
		var str = reader.readString();
		return Uri.parse(str);
	}

	@override
	void write(BinaryWriter writer, Uri obj) {
		writer.writeString(obj.toString());
	}
}

const _savedAttachmentThumbnailsDir = 'saved_attachments_thumbs';
const _savedAttachmentsDir = 'saved_attachments';

class Persistence {
	final String id;
	Persistence(this.id);
	late final Box<PersistentThreadState> threadStateBox;
	late final Box<ImageboardBoard> boardBox;
	late final Box<SavedAttachment> savedAttachmentsBox;
	late final Box<SavedPost> savedPostsBox;
	late final PersistentRecentSearches recentSearches;
	late final PersistentBrowserState browserState;
	static late final Directory temporaryDirectory;
	static late final Directory documentsDirectory;
	static late final PersistCookieJar cookies;

	static Future<void> initializeStatic() async {
		await Hive.initFlutter();
		Hive.registerAdapter(ThemeSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(ThreadSortingMethodAdapter());
		Hive.registerAdapter(ContentSettingsAdapter());
		Hive.registerAdapter(SavedSettingsAdapter());
		Hive.registerAdapter(UriAdapter());
		Hive.registerAdapter(AttachmentTypeAdapter());
		Hive.registerAdapter(AttachmentAdapter());
		Hive.registerAdapter(ImageboardFlagAdapter());
		Hive.registerAdapter(PostSpanFormatAdapter());
		Hive.registerAdapter(PostAdapter());
		Hive.registerAdapter(ThreadAdapter());
		Hive.registerAdapter(ImageboardBoardAdapter());
		Hive.registerAdapter(PostReceiptAdapter());
		Hive.registerAdapter(PersistentThreadStateAdapter());
		Hive.registerAdapter(ImageboardArchiveSearchQueryAdapter());
		Hive.registerAdapter(PostTypeFilterAdapter());
		Hive.registerAdapter(MediaFilterAdapter());
		Hive.registerAdapter(PersistentRecentSearchesAdapter());
		Hive.registerAdapter(SavedAttachmentAdapter());
		Hive.registerAdapter(SavedPostAdapter());
		Hive.registerAdapter(ThreadIdentifierAdapter());
		Hive.registerAdapter(PersistentBrowserTabAdapter());
		Hive.registerAdapter(PersistentBrowserStateAdapter());
		temporaryDirectory = await getTemporaryDirectory();
		documentsDirectory = await getApplicationDocumentsDirectory();
		cookies = PersistCookieJar(
			storage: FileStorage(temporaryDirectory.path)
		);
		await Directory('${documentsDirectory.path}/$_savedAttachmentsDir').create(recursive: true);
		await Directory('${documentsDirectory.path}/$_savedAttachmentThumbnailsDir').create(recursive: true);
		await Hive.openBox<SavedSettings>('settings');
	}

	Future<void> initialize() async {
		threadStateBox = await Hive.openBox<PersistentThreadState>('threadStates_$id');
		final searchesBox = await Hive.openBox<PersistentRecentSearches>('searches_$id');
		final existingRecentSearches = searchesBox.get('recentSearches');
		if (existingRecentSearches != null) {
			recentSearches = existingRecentSearches;
		}
		else {
			recentSearches = PersistentRecentSearches();
			searchesBox.put('recentSearches', recentSearches);
		}
		//Hive.deleteBoxFromDisk('browserStates_$id');
		final browserStateBox = await Hive.openBox<PersistentBrowserState>('browserStates_$id');
		final existingBrowserState = browserStateBox.get('browserState');
		if (existingBrowserState != null) {
			browserState = existingBrowserState;
		}
		else {
			browserState = PersistentBrowserState(
				tabs: [PersistentBrowserTab(board: null)]
			);
			browserStateBox.put('browserState', browserState);
		}
		boardBox = await Hive.openBox<ImageboardBoard>('boards_$id');
		savedAttachmentsBox = await Hive.openBox<SavedAttachment>('savedAttachments_$id');
		savedPostsBox = await Hive.openBox<SavedPost>('savedPosts_$id');
	}

	PersistentThreadState? getThreadStateIfExists(ThreadIdentifier thread) {
		return threadStateBox.get('${thread.board}/${thread.id}');
	}

	PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false}) {
		final existingState = threadStateBox.get('${thread.board}/${thread.id}');
		if (existingState != null) {
			if (updateOpenedTime) {
				existingState.lastOpenedTime = DateTime.now();
				existingState.save();
			}
			return existingState;
		}
		else {
			final newState = PersistentThreadState();
			threadStateBox.put('${thread.board}/${thread.id}', newState);
			return newState;
		}
	}

	ImageboardBoard getBoard(String boardName) {
		final board = boardBox.get(boardName);
		if (board != null) {
			return board;
		}
		else {
			return ImageboardBoard(
				title: boardName,
				name: boardName,
				webmAudioAllowed: false,
				isWorksafe: true
			);
		}
	}

	SavedAttachment? getSavedAttachment(Attachment attachment) {
		return savedAttachmentsBox.get(attachment.globalId);
	}

	void saveAttachment(Attachment attachment, File fullResolutionFile) {
		final newSavedAttachment = SavedAttachment(attachment: attachment, savedTime: DateTime.now());
		savedAttachmentsBox.put(attachment.globalId, newSavedAttachment);
		fullResolutionFile.copy(newSavedAttachment.file.path);
		getCachedImageFile(attachment.thumbnailUrl.toString()).then((file) {
			if (file != null) {
				file.copy(newSavedAttachment.thumbnailFile.path);
			}
			else {
				print('Failed to find cached copy of ${attachment.thumbnailUrl.toString()}');
			}
		});
	}

	SavedPost? getSavedPost(Post post) {
		return savedPostsBox.get(post.globalId);
	}

	void savePost(Post post, Thread thread) {
		final newSavedPost = SavedPost(post: post, savedTime: DateTime.now(), thread: thread);
		savedPostsBox.put(post.globalId, newSavedPost);
	}

	String get currentBoardName => browserState.tabs[browserState.currentTab].board?.name ?? 'tv';

	ValueListenable<Box<PersistentThreadState>> listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return threadStateBox.listenable(keys: ['${thread.board}/${thread.id}']);
	}
}

const _maxRecentItems = 50;
@HiveType(typeId: 8)
class PersistentRecentSearches extends HiveObject {
	@HiveField(0)
	List<ImageboardArchiveSearchQuery> entries = [];

	void add(ImageboardArchiveSearchQuery entry) {
		entries = [entry, ...entries.take(_maxRecentItems)];
	}

	void bump(ImageboardArchiveSearchQuery entry) {
		entries = [entry, ...entries.where((e) => e != entry)];
	}

	void remove(ImageboardArchiveSearchQuery entry) {
		entries = [...entries.where((e) => e != entry)];
	}

	PersistentRecentSearches();
}

@HiveType(typeId: 3)
class PersistentThreadState extends HiveObject implements Filterable {
	@HiveField(0)
	int? lastSeenPostId;
	@HiveField(1)
	DateTime lastOpenedTime;
	@HiveField(6)
	DateTime? savedTime;
	@HiveField(3)
	List<PostReceipt> receipts = [];
	@HiveField(4)
	Thread? thread;
	@HiveField(5)
	bool useArchive = false;

	PersistentThreadState() : lastOpenedTime = DateTime.now();

	List<int> get youIds => receipts.map((receipt) => receipt.id).toList();
	List<Post>? get repliesToYou => thread?.posts.where((p) => p.span.referencedPostIds(thread!.board).any((id) => youIds.contains(id))).toList();
	List<Post>? get unseenRepliesToYou => repliesToYou?.where((p) => p.id > lastSeenPostId!).toList();
	int? get unseenReplyCount => (lastSeenPostId == null) ? null : thread?.posts.where((p) => p.id > lastSeenPostId!).length;
	int? get unseenImageCount => (lastSeenPostId == null) ? null : thread?.posts.where((p) => (p.id > lastSeenPostId!) && (p.attachment != null)).length;

	@override
	String toString() => 'PersistentThreadState(lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime, useArchive: $useArchive)';

	@override
	List<String> getSearchableText() => thread?.getSearchableText() ?? [];
}

@HiveType(typeId: 4)
class PostReceipt extends HiveObject {
	@HiveField(0)
	final String password;
	@HiveField(1)
	final int id;
	PostReceipt({
		required this.password,
		required this.id
	});
	@override
	String toString() => 'PostReceipt(id: $id, password: $password)';
}

@HiveType(typeId: 18)
class SavedAttachment extends HiveObject {
	@HiveField(0)
	final Attachment attachment;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2)
	final List<int> tags;
	SavedAttachment({
		required this.attachment,
		required this.savedTime,
		List<int>? tags
	}) : tags = tags ?? [];

	@override
	Future<void> delete() async {
		super.delete();
		await thumbnailFile.delete();
		await file.delete();
	}

	File get thumbnailFile => File('${Persistence.documentsDirectory.path}/$_savedAttachmentThumbnailsDir/${attachment.globalId}.jpg');
	File get file => File('${Persistence.documentsDirectory.path}/$_savedAttachmentsDir/${attachment.globalId}${attachment.ext == '.webm' ? '.mp4' : attachment.ext}');
}

@HiveType(typeId: 19)
class SavedPost extends HiveObject implements Filterable {
	@HiveField(0)
	final Post post;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2)
	final Thread thread;

	SavedPost({
		required this.post,
		required this.savedTime,
		required this.thread
	});

	@override
	List<String> getSearchableText() => [post.text];
}

@HiveType(typeId: 21)
class PersistentBrowserTab extends HiveObject {
	@HiveField(0)
	ImageboardBoard? board;
	@HiveField(1)
	ThreadIdentifier? thread;
	PersistentBrowserTab({
		this.board,
		this.thread
	});
}

@HiveType(typeId: 22)
class PersistentBrowserState extends HiveObject {
	@HiveField(0)
	List<PersistentBrowserTab> tabs;
	@HiveField(1)
	int currentTab;
	PersistentBrowserState({
		required this.tabs,
		this.currentTab = 0
	});
}