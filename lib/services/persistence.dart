import 'dart:io';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
part 'persistence.g.dart';

const _knownCacheDirs = {
	cacheImageFolderName: 'Images',
	'webmcache': 'Converted WEBM files',
	'sharecache': 'Media exported for sharing',
	'webpickercache': 'Images picked from web'
};

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

class EasyListenable extends ChangeNotifier {
	void didUpdate() {
		notifyListeners();
	}
}

const _savedAttachmentThumbnailsDir = 'saved_attachments_thumbs';
const _savedAttachmentsDir = 'saved_attachments';
const _maxAutosavedIdsPerBoard = 250;
const _maxHiddenIdsPerBoard = 1000;

class Persistence extends ChangeNotifier {
	final String id;
	Persistence(this.id);
	late final Box<PersistentThreadState> threadStateBox;
	Map<String, ImageboardBoard> get boards => settings.boardsBySite[id]!;
	Map<String, SavedAttachment> get savedAttachments => settings.savedAttachmentsBySite[id]!;
	Map<String, SavedPost> get savedPosts => settings.savedPostsBySite[id]!;
	static PersistentRecentSearches get recentSearches => settings.recentSearches;
	PersistentBrowserState get browserState => settings.browserStateBySite[id]!;
	static List<PersistentBrowserTab> get tabs => settings.tabs;
	static int get currentTabIndex => settings.currentTabIndex;
	static set currentTabIndex(int setting) {
		settings.currentTabIndex = setting;
	}
	final savedAttachmentsNotifier = PublishSubject<void>();
	final savedPostsNotifier = PublishSubject<void>();
	static late final SavedSettings settings;
	static late final Directory temporaryDirectory;
	static late final Directory documentsDirectory;
	static late final PersistCookieJar cookies;
	// Do not persist
	static bool enableHistory = true;
	static final browserHistoryStatusListenable = EasyListenable();
	static final tabsListenable = EasyListenable();
	static final recentSearchesListenable = EasyListenable();

	static Future<void> initializeStatic() async {
		await Hive.initFlutter();
		Hive.registerAdapter(ColorAdapter());
		Hive.registerAdapter(SavedThemeAdapter());
		Hive.registerAdapter(TristateSystemSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(ThreadSortingMethodAdapter());
		Hive.registerAdapter(ContentSettingsAdapter());
		Hive.registerAdapter(PostDisplayFieldAdapter());
		Hive.registerAdapter(SettingsQuickActionAdapter());
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
		Hive.registerAdapter(PostDeletionStatusFilterAdapter());
		Hive.registerAdapter(PersistentRecentSearchesAdapter());
		Hive.registerAdapter(SavedAttachmentAdapter());
		Hive.registerAdapter(SavedPostAdapter());
		Hive.registerAdapter(ThreadIdentifierAdapter());
		Hive.registerAdapter(PersistentBrowserTabAdapter());
		Hive.registerAdapter(ThreadWatchAdapter());
		Hive.registerAdapter(NewThreadWatchAdapter());
		Hive.registerAdapter(PersistentBrowserStateAdapter());
		temporaryDirectory = await getTemporaryDirectory();
		documentsDirectory = await getApplicationDocumentsDirectory();
		cookies = PersistCookieJar(
			storage: FileStorage(temporaryDirectory.path)
		);
		await Directory('${documentsDirectory.path}/$_savedAttachmentsDir').create(recursive: true);
		await Directory('${documentsDirectory.path}/$_savedAttachmentThumbnailsDir').create(recursive: true);
		final settingsBox = await Hive.openBox<SavedSettings>('settings');
		settings = settingsBox.get('settings', defaultValue: SavedSettings(
			useInternalBrowser: true
		))!;
		if (settings.automaticCacheClearDays < 100000) {
			// Don't await
			clearFilesystemCaches(Duration(days: settings.automaticCacheClearDays));
		}
	}

	static Future<Map<String, int>> getFilesystemCacheSizes() async {
		final folderSizes = <String, int>{};
		final systemTempDirectory = Persistence.temporaryDirectory;
		await for (final directory in systemTempDirectory.list()) {
			int size = 0;
			final stat = await directory.stat();
			if (stat.type == FileSystemEntityType.directory) {
				await for (final subentry in Directory(directory.path).list(recursive: true)) {
					size += (await subentry.stat()).size;
				}
			}
			else {
				size = stat.size;
			}
			folderSizes.update(_knownCacheDirs[directory.path.split('/').last] ?? 'Other', (total) => total + size, ifAbsent: () => size);
		}
		return folderSizes;
	}

	static Future<void> clearFilesystemCaches(Duration? olderThan) async {
		if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
			// The temporary directory is shared between applications, it's not safe to clear it. 
			return;
		}
		DateTime? deadline;
		if (olderThan != null) {
			deadline = DateTime.now().subtract(olderThan);
		}
		int deletedSize = 0;
		int deletedCount = 0;
		await for (final child in temporaryDirectory.list(recursive: true)) {
			final stat = child.statSync();
			if (stat.type == FileSystemEntityType.file) {
				// Probably something from file_pickers
				if (deadline == null || stat.accessed.compareTo(deadline) < 0) {
					deletedSize += stat.size;
					deletedCount++;
					try {
						await child.delete();
					}
					catch (e) {
						print('Error deleting file: $e');
					}
				}
			}
		}
		print('Deleted $deletedCount files totalling ${(deletedSize / 1000000).toStringAsFixed(1)} MB');
	}

	Future<void> cleanupThreads(Duration olderThan) async {
		final deadline = DateTime.now().subtract(olderThan);
		final toDelete = threadStateBox.keys.where((key) {
			return (threadStateBox.get(key)?.youIds.isNotEmpty ?? false) && ((threadStateBox.get(key)?.lastOpenedTime.compareTo(deadline) ?? 0) < 0);
		});
		print('Deleting ${toDelete.length} threads');
		await threadStateBox.deleteAll(toDelete);
	}

	Future<void> deleteAllData() async {
		settings.boardsBySite.remove(id);
		settings.savedPostsBySite.remove(id);
		settings.browserStateBySite.remove(id);
		await threadStateBox.deleteFromDisk();
	}

	Future<void> initialize() async {
		threadStateBox = await Hive.openBox<PersistentThreadState>('threadStates_$id');
		if (await Hive.boxExists('searches_$id')) {
			print('Migrating searches box');
			final searchesBox = await Hive.openBox<PersistentRecentSearches>('searches_$id');
			final existingRecentSearches = searchesBox.get('recentSearches');
			if (existingRecentSearches != null) {
				settings.deprecatedRecentSearchesBySite[id] = existingRecentSearches;
			}
			await searchesBox.deleteFromDisk();
		}
		if (settings.deprecatedRecentSearchesBySite[id]?.entries.isNotEmpty == true) {
			print('Migrating recent searches');
			for (final search in settings.deprecatedRecentSearchesBySite[id]!.entries) {
				Persistence.recentSearches.add(search..imageboardKey = id);
			}
		}
		settings.deprecatedRecentSearchesBySite.remove(id);
		if (await Hive.boxExists('browserStates_$id')) {
			print('Migrating browser states box');
			final browserStateBox = await Hive.openBox<PersistentBrowserState>('browserStates_$id');
			final existingBrowserState = browserStateBox.get('browserState');
			if (existingBrowserState != null) {
				settings.browserStateBySite[id] = existingBrowserState;
			}
			await browserStateBox.deleteFromDisk();
		}
		settings.browserStateBySite.putIfAbsent(id, () => PersistentBrowserState(
			hiddenIds: {},
			favouriteBoards: [],
			autosavedIds: {},
			hiddenImageMD5s: [],
			loginFields: {},
			threadWatches: [],
			newThreadWatches: [],
			notificationsMigrated: true,
			boardSortingMethods: {},
			boardReverseSortings: {}
		));
		if (browserState.deprecatedTabs.isNotEmpty && ImageboardRegistry.instance.getImageboardUnsafe(id) != null) {
			print('Migrating tabs');
			for (final deprecatedTab in browserState.deprecatedTabs) {
				if (Persistence.tabs.length == 1 && Persistence.tabs.first.imageboardKey == null) {
					// It's the dummy tab
					Persistence.tabs.clear();
				}
				Persistence.tabs.add(deprecatedTab..imageboardKey = id);
			}
			browserState.deprecatedTabs.clear();
			didUpdateBrowserState();
			Persistence.didUpdateTabs();
		}
		if (await Hive.boxExists('boards_$id')) {
			print('Migrating boards box');
			final boardBox = await Hive.openBox<ImageboardBoard>('boards_$id');
			settings.boardsBySite[id] = {
				for (final key in boardBox.keys) key.toString(): boardBox.get(key)!
			};
			await boardBox.deleteFromDisk();
		}
		settings.boardsBySite.putIfAbsent(id, () => {});
		if (await Hive.boxExists('savedAttachments_$id')) {
			print('Migrating saved attachments box');
			final savedAttachmentsBox = await Hive.openBox<SavedAttachment>('savedAttachments_$id');
			settings.savedAttachmentsBySite[id] = {
				for (final key in savedAttachmentsBox.keys) key.toString(): savedAttachmentsBox.get(key)!
			};
			await savedAttachmentsBox.deleteFromDisk();
		}
		settings.savedAttachmentsBySite.putIfAbsent(id, () => {});
		if (await Hive.boxExists('savedPosts_$id')) {
			print('Migrating saved posts box');
			final savedPostsBox = await Hive.openBox<SavedPost>('savedPosts_$id');
			settings.savedPostsBySite[id] = {
				for (final key in savedPostsBox.keys) key.toString(): savedPostsBox.get(key)!
			};
			await savedPostsBox.deleteFromDisk();
		}
		settings.savedPostsBySite.putIfAbsent(id, () => {});
		// Cleanup expanding lists
		for (final list in browserState.autosavedIds.values) {
			list.removeRange(0, max(0, list.length - _maxAutosavedIdsPerBoard));
		}
		for (final list in browserState.hiddenIds.values) {
			list.removeRange(0, max(0, list.length - _maxHiddenIdsPerBoard));
		}
		if (!browserState.notificationsMigrated) {
			browserState.threadWatches.clear();
			for (final threadState in threadStateBox.values) {
				if (threadState.savedTime != null && threadState.thread?.isArchived == false) {
					browserState.threadWatches.add(ThreadWatch(
						board: threadState.board,
						threadId: threadState.id,
						youIds: threadState.youIds,
						localYousOnly: true,
						pushYousOnly: true,
						lastSeenId: threadState.thread?.posts.last.id ?? threadState.id
					));
				}
			}
			browserState.notificationsMigrated = true;
		}
		if (settings.automaticCacheClearDays < 100000) {
			await cleanupThreads(Duration(days: settings.automaticCacheClearDays));
		}
		await settings.save();
	}

	PersistentThreadState? getThreadStateIfExists(ThreadIdentifier thread) {
		return threadStateBox.get('${thread.board}/${thread.id}');
	}

	static final Map<String, Map<ThreadIdentifier, PersistentThreadState>> _cachedEphemeralThreadStatesById = {};
	Map<ThreadIdentifier, PersistentThreadState> get _cachedEphemeralThreadStates => _cachedEphemeralThreadStatesById.putIfAbsent(id, () => {});
	PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false}) {
		final existingState = threadStateBox.get('${thread.board}/${thread.id}');
		if (existingState != null) {
			if (updateOpenedTime) {
				existingState.lastOpenedTime = DateTime.now();
				existingState.save();
			}
			return existingState;
		}
		else if (enableHistory) {
			final newState = PersistentThreadState();
			threadStateBox.put('${thread.board}/${thread.id}', newState);
			return newState;
		}
		else {
			return _cachedEphemeralThreadStates.putIfAbsent(thread, () => PersistentThreadState(ephemeral: true));
		}
	}

	ImageboardBoard getBoard(String boardName) {
		final board = boards[boardName];
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
		return savedAttachments[attachment.globalId];
	}

	void saveAttachment(Attachment attachment, File fullResolutionFile) {
		final newSavedAttachment = SavedAttachment(attachment: attachment, savedTime: DateTime.now());
		savedAttachments[attachment.globalId] = newSavedAttachment;
		fullResolutionFile.copy(newSavedAttachment.file.path);
		getCachedImageFile(attachment.thumbnailUrl.toString()).then((file) {
			if (file != null) {
				file.copy(newSavedAttachment.thumbnailFile.path);
			}
			else {
				print('Failed to find cached copy of ${attachment.thumbnailUrl.toString()}');
			}
		});
		settings.save();
		savedAttachmentsNotifier.add(null);
		if (savedAttachments.length == 1) {
			attachmentSourceNotifier.didUpdate();
		}
	}

	void deleteSavedAttachment(Attachment attachment) {
		final removed = savedAttachments.remove(attachment.globalId);
		if (removed != null) {
			removed.deleteFiles();
		}
		if (savedAttachments.isEmpty) {
			attachmentSourceNotifier.didUpdate();
		}
		settings.save();
		savedAttachmentsNotifier.add(null);
	}

	SavedPost? getSavedPost(Post post) {
		return savedPosts[post.globalId];
	}

	void savePost(Post post, Thread thread) {
		savedPosts[post.globalId] = SavedPost(post: post, savedTime: DateTime.now(), thread: thread);
		settings.save();
		// Likely will force the widget to rebuild
		getThreadStateIfExists(post.threadIdentifier)?.save();
		savedPostsNotifier.add(null);
	}

	void unsavePost(Post post) {
		savedPosts.remove(post.globalId);
		settings.save();
		// Likely will force the widget to rebuild
		getThreadStateIfExists(post.threadIdentifier)?.save();
		savedPostsNotifier.add(null);
	}

	ValueListenable<Box<PersistentThreadState>> listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return threadStateBox.listenable(keys: ['${thread.board}/${thread.id}']);
	}

	Future<void> storeBoards(List<ImageboardBoard> newBoards) async {
		final deadline = DateTime.now().subtract(const Duration(days: 3));
		boards.removeWhere((k, v) => v.additionalDataTime == null || v.additionalDataTime!.isBefore(deadline));
		for (final newBoard in newBoards) {
			if (boards[newBoard.name] == null || newBoard.additionalDataTime != null) {
				boards[newBoard.name] = newBoard;
			}
		}
	}

	static Future<void> didUpdateTabs() async {
		await settings.save();
		tabsListenable.didUpdate();
	}

	Future<void> didUpdateBrowserState() async {
		await settings.save();
		notifyListeners();
	}

	static Future<void> didUpdateRecentSearches() async {
		await settings.save();
		recentSearchesListenable.didUpdate();
	}

	Future<void> didUpdateSavedPost() async {
		await settings.save();
		savedPostsNotifier.add(null);
	}

	static void didChangeBrowserHistoryStatus() {
		_cachedEphemeralThreadStatesById.clear();
		browserHistoryStatusListenable.didUpdate();
	}
}

const _maxRecentItems = 50;
@HiveType(typeId: 8)
class PersistentRecentSearches {
	@HiveField(0)
	List<ImageboardArchiveSearchQuery> entries = [];

	void handleSearch(ImageboardArchiveSearchQuery entry) {
		if (entries.contains(entry)) {
			bump(entry);
		}
		else {
			add(entry);
		}
	}

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
	@HiveField(7, defaultValue: [])
	List<int> postsMarkedAsYou = [];
	@HiveField(8, defaultValue: [])
	List<int> hiddenPostIds = [];
	@HiveField(9, defaultValue: '')
	String draftReply = '';
	// Don't persist this
	final lastSeenPostIdNotifier = ValueNotifier<int?>(null);
	// Don't persist this
	bool ephemeral;
	@HiveField(10, defaultValue: [])
	List<int> treeHiddenPostIds = [];
	@HiveField(11, defaultValue: [])
	List<String> hiddenPosterIds = [];

	PersistentThreadState({this.ephemeral = false}) : lastOpenedTime = DateTime.now();

	List<int> get youIds => receipts.map((receipt) => receipt.id).followedBy(postsMarkedAsYou).toList();
	final FilterCache _filterCache = FilterCache(const DummyFilter());
	List<int>? replyIdsToYou(Filter filter) {
		_filterCache.setFilter(FilterGroup([filter, threadFilter]));
		final tmpYouIds = youIds;
		return thread?.posts.where((p) {
			return (_filterCache.filter(p)?.type != FilterResultType.hide) &&
						 p.span.referencedPostIds(thread!.board).any((id) => tmpYouIds.contains(id));
		}).map((p) => p.id).toList();
	}
	List<int>? unseenReplyIdsToYou(Filter filter) => replyIdsToYou(filter)?.where((id) => id > lastSeenPostId!).toList();
	int? unseenReplyCount(Filter filter) {
		if (lastSeenPostId != null) {
			_filterCache.setFilter(FilterGroup([filter, threadFilter]));
			return thread?.posts.where((p) {
				return (p.id > lastSeenPostId!) &&
							 _filterCache.filter(p)?.type != FilterResultType.hide;
			}).length;
		}
		return null;
	}
	int? unseenImageCount(Filter filter) {
		if (lastSeenPostId != null) {
			_filterCache.setFilter(FilterGroup([filter, threadFilter]));
			return thread?.posts.map((p) {
				if (p.id <= lastSeenPostId! || _filterCache.filter(p)?.type == FilterResultType.hide) {
					return 0;
				}
				return p.attachments.length;
			}).fold<int>(0, (a, b) => a + b);
		}
		return null;
	}

	@override
	String toString() => 'PersistentThreadState(lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime, useArchive: $useArchive)';

	@override
	String get board => thread?.board ?? '';
	@override
	int get id => thread?.id ?? 0;
	@override
	String? getFilterFieldText(String fieldName) => thread?.getFilterFieldText(fieldName);
	@override
	bool get hasFile => thread?.hasFile ?? false;
	@override
	bool get isThread => true;
	@override
	List<int> get repliedToIds => [];
	@override
	Iterable<String> get md5s => thread?.md5s ?? [];

	late Filter threadFilter = FilterCache(ThreadFilter(hiddenPostIds, treeHiddenPostIds, hiddenPosterIds));
	void hidePost(int id, {bool tree = false}) {
		hiddenPostIds.add(id);
		if (tree) {
			treeHiddenPostIds.add(id);
		}
		// invalidate cache
		threadFilter = FilterCache(ThreadFilter(hiddenPostIds, treeHiddenPostIds, hiddenPosterIds));
	}
	void unHidePost(int id) {
		hiddenPostIds.remove(id);
		treeHiddenPostIds.remove(id);
		// invalidate cache
		threadFilter = FilterCache(ThreadFilter(hiddenPostIds, treeHiddenPostIds, hiddenPosterIds));
	}

	void hidePosterId(String id) {
		hiddenPosterIds.add(id);
		// invalidate cache
		threadFilter = FilterCache(ThreadFilter(hiddenPostIds, treeHiddenPostIds, hiddenPosterIds));
	}
	void unHidePosterId(String id) {
		hiddenPosterIds.remove(id);
		// invalidate cache
		threadFilter = FilterCache(ThreadFilter(hiddenPostIds, treeHiddenPostIds, hiddenPosterIds));
	}

	@override
	Future<void> save() async {
		if (!ephemeral) {
			await super.save();
		}
	}

	ThreadIdentifier get identifier => ThreadIdentifier(board, id);
}

@HiveType(typeId: 4)
class PostReceipt {
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
class SavedAttachment {
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

	Future<void> deleteFiles() async {
		await thumbnailFile.delete();
		await file.delete();
	}

	File get thumbnailFile => File('${Persistence.documentsDirectory.path}/$_savedAttachmentThumbnailsDir/${attachment.globalId}.jpg');
	File get file => File('${Persistence.documentsDirectory.path}/$_savedAttachmentsDir/${attachment.globalId}${attachment.ext == '.webm' ? '.mp4' : attachment.ext}');
}

@HiveType(typeId: 19)
class SavedPost {
	@HiveField(0)
	Post post;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2)
	Thread thread;

	SavedPost({
		required this.post,
		required this.savedTime,
		required this.thread
	});
}

@HiveType(typeId: 21)
class PersistentBrowserTab extends EasyListenable {
	@HiveField(0)
	ImageboardBoard? board;
	@HiveField(1)
	ThreadIdentifier? thread;
	@HiveField(2, defaultValue: '')
	String draftThread;
	@HiveField(3, defaultValue: '')
	String draftSubject;
	@HiveField(4)
	String? imageboardKey;
	Imageboard? get imageboard => imageboardKey == null ? null :  ImageboardRegistry.instance.getImageboard(imageboardKey!);
	// Do not persist
	RefreshableListController<Post>? threadController;
	// Do not persist
	final Map<ThreadIdentifier, int> initialPostId = {};
	// Do not persist
	final tabKey = GlobalKey();
	// Do not persist
	final boardKey = GlobalKey();
	// Do not persist
	final unseen = ValueNotifier(0);
	@HiveField(5, defaultValue: '')
	String draftOptions;
	@HiveField(6)
	String? draftFilePath;

	PersistentBrowserTab({
		this.board,
		this.thread,
		this.draftThread = '',
		this.draftSubject = '',
		this.imageboardKey,
		this.draftOptions = '',
		this.draftFilePath
	});
}

@HiveType(typeId: 22)
class PersistentBrowserState {
	@HiveField(0)
	List<PersistentBrowserTab> deprecatedTabs;
	@HiveField(2, defaultValue: {})
	final Map<String, List<int>> hiddenIds;
	@HiveField(3, defaultValue: [])
	final List<String> favouriteBoards;
	@HiveField(5, defaultValue: {})
	final Map<String, List<int>> autosavedIds;
	@HiveField(6, defaultValue: [])
	final Set<String> hiddenImageMD5s;
	Persistence? persistence;
	@HiveField(7, defaultValue: {})
	Map<String, String> loginFields;
	@HiveField(8)
	String notificationsId;
	@HiveField(10, defaultValue: [])
	List<ThreadWatch> threadWatches;
	@HiveField(11, defaultValue: [])
	List<NewThreadWatch> newThreadWatches;
	@HiveField(12, defaultValue: false)
	bool notificationsMigrated;
	@HiveField(13, defaultValue: {})
	final Map<String, ThreadSortingMethod> boardSortingMethods;
	@HiveField(14, defaultValue: {})
	final Map<String, bool> boardReverseSortings;
	@HiveField(15, defaultValue: '')
	String postingName;
	
	PersistentBrowserState({
		this.deprecatedTabs = const [],
		required this.hiddenIds,
		required this.favouriteBoards,
		required this.autosavedIds,
		required List<String> hiddenImageMD5s,
		required this.loginFields,
		String? notificationsId,
		required this.threadWatches,
		required this.newThreadWatches,
		required this.notificationsMigrated,
		required this.boardSortingMethods,
		required this.boardReverseSortings,
		this.postingName = ''
	}) : hiddenImageMD5s = hiddenImageMD5s.toSet(), notificationsId = notificationsId ?? (const Uuid()).v4();

	final Map<String, Filter> _catalogFilters = {};
	Filter getCatalogFilter(String board) {
		return _catalogFilters.putIfAbsent(board, () => FilterCache(IDFilter(hiddenIds[board] ?? [])));
	}
	
	bool isThreadHidden(String board, int id) {
		return hiddenIds[board]?.contains(id) ?? false;
	}

	void hideThread(String board, int id) {
		_catalogFilters.remove(board);
		hiddenIds.putIfAbsent(board, () => []).add(id);
	}

	void unHideThread(String board, int id) {
		_catalogFilters.remove(board);
		hiddenIds[board]?.remove(id);
	}

	bool areMD5sHidden(Iterable<String> md5s) {
		for (final md5 in md5s) {
			if (hiddenImageMD5s.contains(md5)) {
				return true;
			}
		}
		return false;
	}

	late Filter imageMD5Filter = MD5Filter(hiddenImageMD5s.toSet());
	void hideByMD5(String md5) {
		hiddenImageMD5s.add(md5);
		imageMD5Filter = MD5Filter(hiddenImageMD5s.toSet());
	}

	void unHideByMD5s(Iterable<String> md5s) {
		hiddenImageMD5s.removeAll(md5s);
		imageMD5Filter = MD5Filter(hiddenImageMD5s.toSet());
	}

	void setHiddenImageMD5s(Iterable<String> md5s) {
		hiddenImageMD5s.clear();
		hiddenImageMD5s.addAll(md5s.map((md5) {
			switch (md5.length % 3) {
				case 1:
					return '$md5==';
				case 2:
					return '$md5=';
			}
			return md5;
		}));
		imageMD5Filter = MD5Filter(hiddenImageMD5s.toSet());
	}
}