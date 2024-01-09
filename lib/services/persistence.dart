import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/incognito.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/pick_attachment.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/util.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:chan/util.dart';
part 'persistence.g.dart';

const _knownCacheDirs = {
	cacheImageFolderName: 'Images',
	'httpcache': 'Videos',
	'webmcache': 'Converted videos',
	'sharecache': 'Media exported for sharing',
	'webpickercache': 'Images picked from web'
};

const _boxPrefix = '';
const _backupBoxPrefix = 'backup_';
const _backupUpdateDuration = Duration(minutes: 10);

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
const _maxAutosavedIdsPerBoard = 250;
const _maxHiddenIdsPerBoard = 1000;

abstract class EphemeralThreadStateOwner {
	Future<void> ephemeralThreadStateDidUpdate(PersistentThreadState state);
}

const _deletedRatio = 0.15;
const _deletedThreshold = 60;

/// Default compaction strategy compacts if 15% of total values and at least 60
/// values have been deleted
bool defaultCompactionStrategy(int entries, int deletedEntries) {
  return deletedEntries > _deletedThreshold &&
      deletedEntries / entries > _deletedRatio;
}

class DurationAdapter extends TypeAdapter<Duration> {
	@override
	final int typeId = 39;

	@override
  Duration read(BinaryReader reader) {
		return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

class Persistence extends ChangeNotifier {
	final String imageboardKey;
	Persistence(this.imageboardKey);
	static late final Box<PersistentThreadState> _sharedThreadStateBox;
	static Box<PersistentThreadState> get sharedThreadStateBox => _sharedThreadStateBox;
	static late final Box<ImageboardBoard> _sharedBoardsBox;
	static late final LazyBox<Thread> _sharedThreadsBox;
	Map<String, SavedAttachment> get savedAttachments => settings.savedAttachmentsBySite[imageboardKey]!;
	Map<String, SavedPost> get savedPosts => settings.savedPostsBySite[imageboardKey]!;
	static PersistentRecentSearches get recentSearches => settings.recentSearches;
	PersistentBrowserState get browserState => settings.browserStateBySite[imageboardKey]!;
	static List<PersistentBrowserTab> get tabs => settings.tabs;
	static int get currentTabIndex => settings.currentTabIndex;
	static set currentTabIndex(int setting) {
		settings.currentTabIndex = setting;
	}
	final savedAttachmentsListenable = EasyListenable();
	final savedPostsListenable = EasyListenable();
	static late final SavedSettings settings;
	static late final Directory temporaryDirectory;
	static late final Directory documentsDirectory;
	static late final Directory webmCacheDirectory;
	static late final Directory httpCacheDirectory;
	static late final PersistCookieJar wifiCookies;
	static late final PersistCookieJar cellularCookies;
	static PersistCookieJar get currentCookies {
		if (EffectiveSettings.instance.isConnectedToWifi) {
			return wifiCookies;
		}
		return cellularCookies;
	}
	static final globalTabMutator = ValueNotifier(0);
	static final recentSearchesListenable = EasyListenable();
	static String get _settingsBoxName => 'settings';
	static String get _sharedThreadStatesBoxName => 'threadStates';
	static String get _sharedBoardsBoxName => 'boards';
	static String get _sharedThreadsBoxName => 'threads';
	static late final DateTime appLaunchTime;
	static (String?, ThreadIdentifier?)? _threadIdToBumpInHistory;

	static Future<Box<T>> _openBoxWithBackup<T>(String name, {
		CompactionStrategy compactionStrategy = defaultCompactionStrategy,
	}) async {
		final boxName = '$_boxPrefix$name';
		final boxPath = '${documentsDirectory.path}/$boxName.hive';
		final backupBoxName = '$_backupBoxPrefix$name';
		final backupBoxPath = '${documentsDirectory.path}/$backupBoxName.hive';
		Box<T> box;
		try {
			box = await Hive.openBox<T>(boxName, compactionStrategy: compactionStrategy, crashRecovery: false);
			if (await File(boxPath).exists()) {
				await File(boxPath).copy(backupBoxPath);
			}
			else if (await File(boxPath.toLowerCase()).exists()) {
				await File(boxPath.toLowerCase()).copy(backupBoxPath);
			}
		}
		catch (e, st) {
			if (await File(backupBoxPath).exists()) {
				print('Attempting to handle $e opening some Box<$T> by restoring backup');
				print(st);
				final backupTime = (await File(backupBoxPath).stat()).modified;
				if (await File(boxPath).exists()) {
					await File(boxPath).copy('${documentsDirectory.path}/$boxName.broken.hive');
					await File(backupBoxPath).copy(boxPath);
				}
				else if (await File(boxPath.toLowerCase()).exists()) {
					await File(boxPath.toLowerCase()).copy('${documentsDirectory.path}/$boxName.broken.hive');
					await File(backupBoxPath).copy(boxPath.toLowerCase());
				}
				box = await Hive.openBox<T>(boxName, compactionStrategy: compactionStrategy);
				Future.delayed(const Duration(seconds: 5), () {
					alertError(ImageboardRegistry.instance.context!, 'Database corruption\nDatabase was restored to backup from $backupTime (${formatRelativeTime(backupTime)} ago)');
				});
			}
			else {
				rethrow;
			}
		}
		return box;
	}

	static Future<LazyBox<T>> _openLazyBoxWithBackup<T>(String name, {
		CompactionStrategy compactionStrategy = defaultCompactionStrategy,
		bool gzip = false
	}) async {
		final boxName = '$_boxPrefix$name';
		final boxPath = '${documentsDirectory.path}/$boxName.hive';
		final backupBoxName = '$_backupBoxPrefix$name';
		final backupBoxPath = '${documentsDirectory.path}/$backupBoxName.hive${gzip ? '.gz' : ''}';
		LazyBox<T> box;
		bool backupCorrupted = false;
		try {
			box = await Hive.openLazyBox<T>(boxName, compactionStrategy: compactionStrategy, crashRecovery: false);
			_backupBox(boxPath, backupBoxPath, gzip: gzip);
		}
		catch (e, st) {
			if (await File(backupBoxPath).exists()) {
				print('Attempting to handle $e opening some Box<$T> by restoring backup');
				print(st);
				final backupTime = (await File(backupBoxPath).stat()).modified;
				if (await File(boxPath).exists()) {
					await File(boxPath).copy('${documentsDirectory.path}/$boxName.broken.hive');
					if (gzip) {
						try {
							await copyUngzipped(backupBoxPath, boxPath);
						}
						on FormatException {
							// Backup box is corrupted
							backupCorrupted = true;
							await File(backupBoxPath).rename('${documentsDirectory.path}/$backupBoxName.broken.hive.gz');
							await File(boxPath).delete();
						}
					}
					else {
						await File(backupBoxPath).copy(boxPath);
					}
				}
				else if (await File(boxPath.toLowerCase()).exists()) {
					await File(boxPath.toLowerCase()).copy('${documentsDirectory.path}/$boxName.broken.hive');
					if (gzip) {
						try {
							await copyUngzipped(backupBoxPath, boxPath.toLowerCase());
						}
						on FormatException {
							// Backup box is corrupted
							backupCorrupted = true;
							await File(backupBoxPath).rename('${documentsDirectory.path}/$backupBoxName.broken.hive.gz');
							await File(boxPath.toLowerCase()).delete();
						}
					}
					else {
						await File(backupBoxPath).copy(boxPath.toLowerCase());
					}
				}
				box = await Hive.openLazyBox<T>(boxName, compactionStrategy: compactionStrategy);
				Future.delayed(const Duration(seconds: 5), () {
					String message = 'Database corruption\n';
					if (backupCorrupted) {
						message += 'The backup was also corrupted. Data may have been permanently lost.';
					}
					else {
						message += 'Database was restored to backup from $backupTime (${formatRelativeTime(backupTime)} ago)';
					}
					alertError(ImageboardRegistry.instance.context!, message);
				});
			}
			else {
				rethrow;
			}
		}
		return box;
	}

	static Future<void> _backupBox(String boxPath, String backupBoxPath, {bool gzip = false}) async {
		if (await File(boxPath).exists()) {
			if (gzip) {
				await copyGzipped(boxPath, backupBoxPath);
			}
			else {
				await File(boxPath).copy(backupBoxPath);
			}
		}
		else if (await File(boxPath.toLowerCase()).exists()) {
			if (gzip) {
				await copyGzipped(boxPath.toLowerCase(), backupBoxPath);
			}
			else {
				await File(boxPath.toLowerCase()).copy(backupBoxPath);
			}
		}
		else {
			print('Box not found on disk: $boxPath');
		}
	}

	static void _startBoxBackupTimer(String name, {bool gzip = false}) {
		final boxName = '$_boxPrefix$name';
		final boxPath = '${documentsDirectory.path}/$boxName.hive';
		final backupBoxName = '$_backupBoxPrefix$name';
		final backupBoxPath = '${documentsDirectory.path}/$backupBoxName.hive${gzip ? '.gz' : ''}';
		Timer.periodic(_backupUpdateDuration, (_) async {
			if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
				await _backupBox(boxPath, backupBoxPath);
			}
		});
	}

	static bool get doesCachedThreadBoxExist {
		try {
			final dir = documentsDirectory.path;
			for (final path in [
				'$dir/$_sharedThreadsBoxName.hive',
				'$dir/$_backupBoxPrefix$_sharedThreadsBoxName.hive.gz'
			]) {
				final file = File(path);
				if (file.existsSync()) {
					return true;
				}
			}
		}
		catch (_) { }
		return false;
	}

	static Future<void> deleteCachedThreadBoxAndBackup() async {
		final dir = (await getApplicationDocumentsDirectory()).path;
		for (final path in [
			'$dir/$_sharedThreadsBoxName.hive',
			'$dir/$_backupBoxPrefix$_sharedThreadsBoxName.hive.gz'
		]) {
			final file = File(path);
			if (await file.exists()) {
				await file.delete();
			}
		}
	}

	static Future<Thread?> getCachedThread(String imageboardKey, String board, int id) async {
		return await _sharedThreadsBox.get('$imageboardKey/$board/$id');
	}

	static Future<void> setCachedThread(String imageboardKey, String board, int id, Thread? thread) async {
		if (thread != null) {
			await _sharedThreadsBox.put('$imageboardKey/$board/$id', thread);
		}
		else {
			await _sharedThreadsBox.delete('$imageboardKey/$board/$id');
		}
	}

	static Future<void> ensureTemporaryDirectoriesExist() async {
		await webmCacheDirectory.create(recursive: true);
		final oldHttpCache = Directory('${webmCacheDirectory.path}/httpcache');
		if (oldHttpCache.statSync().type == FileSystemEntityType.directory) {
			await oldHttpCache.rename(httpCacheDirectory.path);
		}
		await httpCacheDirectory.create(recursive: true);
	}

	static Future<void> initializeStatic() async {
		appLaunchTime = DateTime.now();
		await Hive.initFlutter();
		Hive.registerAdapter(PostAdapter());
		Hive.registerAdapter(PostSpanFormatAdapter());
		Hive.registerAdapter(ImageboardBoardAdapter());
		Hive.registerAdapter(UriAdapter());
		Hive.registerAdapter(AttachmentAdapter());
		Hive.registerAdapter(AttachmentTypeAdapter());
		Hive.registerAdapter(PersistentThreadStateAdapter());
		Hive.registerAdapter(PostReceiptAdapter());
		Hive.registerAdapter(ColorAdapter());
		Hive.registerAdapter(SavedThemeAdapter());
		Hive.registerAdapter(TristateSystemSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(ThreadSortingMethodAdapter());
		Hive.registerAdapter(CatalogVariantAdapter());
		Hive.registerAdapter(ThreadVariantAdapter());
		Hive.registerAdapter(ContentSettingsAdapter());
		Hive.registerAdapter(PostDisplayFieldAdapter());
		Hive.registerAdapter(SettingsQuickActionAdapter());
		Hive.registerAdapter(WebmTranscodingSettingAdapter());
		Hive.registerAdapter(SavedSettingsAdapter());
		Hive.registerAdapter(ImageboardFlagAdapter());
		Hive.registerAdapter(ImageboardMultiFlagAdapter());
		Hive.registerAdapter(ThreadAdapter());
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
		Hive.registerAdapter(BoardWatchAdapter());
		Hive.registerAdapter(PersistentBrowserStateAdapter());
		Hive.registerAdapter(WebImageSearchMethodAdapter());
		Hive.registerAdapter(GallerySavePathOrganizingAdapter());
		Hive.registerAdapter(MediaScanAdapter());
		Hive.registerAdapter(DurationAdapter());
		Hive.registerAdapter(EfficientlyStoredIntSetAdapter());
		Hive.registerAdapter(PostSortingMethodAdapter());
		Hive.registerAdapter(ShareablePostsStyleAdapter());
		Hive.registerAdapter(ImagePeekingSettingAdapter());
		Hive.registerAdapter(MouseModeQuoteLinkBehaviorAdapter());
		Hive.registerAdapter(DrawerModeAdapter());
		temporaryDirectory = await getTemporaryDirectory();
		webmCacheDirectory = Directory('${temporaryDirectory.path}/webmcache');
		httpCacheDirectory = Directory('${temporaryDirectory.path}/httpcache');
		await ensureTemporaryDirectoriesExist();
		documentsDirectory = await getApplicationDocumentsDirectory();
		wifiCookies = PersistCookieJar(
			storage: FileStorage(temporaryDirectory.path)
		);
		cellularCookies = PersistCookieJar(
			storage: FileStorage('${temporaryDirectory.path}/cellular')
		);
		await Directory('${documentsDirectory.path}/$_savedAttachmentsDir').create(recursive: true);
		await Directory('${documentsDirectory.path}/$_savedAttachmentThumbnailsDir').create(recursive: true);
		final settingsBox = await _openBoxWithBackup<SavedSettings>(_settingsBoxName, compactionStrategy: (int entries, int deletedEntries) {
			return deletedEntries > 5;
		});
		settings = settingsBox.get('settings', defaultValue: SavedSettings(
			useInternalBrowser: true
		))!;
		if (settings.automaticCacheClearDays < 100000) {
			// Don't await
			clearFilesystemCaches(Duration(days: settings.automaticCacheClearDays));
		}
		settings.launchCount++;
		_startBoxBackupTimer(_settingsBoxName);
		_sharedThreadStateBox = await _openBoxWithBackup<PersistentThreadState>(_sharedThreadStatesBoxName);
		_startBoxBackupTimer(_sharedThreadStatesBoxName);
		_sharedBoardsBox = await _openBoxWithBackup<ImageboardBoard>(_sharedBoardsBoxName);
		_startBoxBackupTimer(_sharedBoardsBoxName);
		if (_sharedBoardsBox.isEmpty) {
			// First launch on new version
			Future.delayed(const Duration(milliseconds: 50), () => splashStage.value = 'Migrating...');
		}
		_sharedThreadsBox = await _openLazyBoxWithBackup<Thread>(_sharedThreadsBoxName, gzip: true);
		_startBoxBackupTimer(_sharedThreadsBoxName, gzip: true);
		if (settings.homeImageboardKey != null) {
			currentTabIndex = 0;
		}
		if (settings.homeImageboardKey != null && settings.homeImageboardKey != tabs.first.imageboardKey) {
			// Open at some other board switcher
			_threadIdToBumpInHistory = (tabs.first.imageboardKey, tabs.first.thread);
			tabs.first.imageboardKey = settings.homeImageboardKey;
			tabs.first.board = null; // settings.initialBoardName will be handled in specific initialize() below
			tabs.first.thread = null;
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
		await for (final child in temporaryDirectory.list(recursive: true).handleError(
			(e) => print('Ignoring list error $e'),
			test: (e) => e is FileSystemException)
		) {
			final stat = await child.stat();
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
			else if (stat.type == FileSystemEntityType.directory) {
				final dir = Directory(child.path);
				if (!await dir.exists()) {
					// Might have been deleted already, and we are in a cached recursive listing
					continue;
				}
				try {
					if (!await dir.list().isEmpty) {
						// Don't delete non-empty directories
						continue;
					}
				}
				on PathNotFoundException {
					// Race condition - deleted already?
					continue;
				}
				if (deadline == null || stat.accessed.isBefore(deadline)) {
					deletedCount++;
					try {
						await dir.delete();
					}
					catch (e) {
						print('Error deleting directory: $e');
					}
				}
			}
		}
		if (deletedCount > 0) {
			print('Deleted $deletedCount files totalling ${(deletedSize / 1000000).toStringAsFixed(1)} MB');
		}
	}

	Future<void> _cleanupThreads(Duration olderThan) async {
		final deadline = DateTime.now().subtract(olderThan);
		final toPreserve = savedPosts.values.map((v) => '$imageboardKey/${v.post.board}/${v.post.threadId}').toSet();
		toPreserve.addAll(browserState.threadWatches.keys.map((v) => '$imageboardKey/${v.board}/${v.id}'));
		final toDelete = sharedThreadStateBox.keys.where((key) {
			if (!(key as String).startsWith('$imageboardKey/')) {
				// Not this Persistence
				return false;
			}
			final ts = sharedThreadStateBox.get(key);
			return (ts?.youIds.isEmpty ?? false) // no replies
				  && (ts?.lastOpenedTime.isBefore(deadline) ?? false) // not opened recently
					&& (ts?.savedTime == null) // not saved
				  && (!toPreserve.contains(key)); // connect to a saved post or thread watch
		});
		if (toDelete.isNotEmpty) {
			print('[$imageboardKey] Deleting ${toDelete.length} thread states');
		}
		await sharedThreadStateBox.deleteAll(toDelete);
		final cachedThreadKeys = Persistence._sharedThreadsBox.keys.where((k) => (k as String).startsWith('$imageboardKey/')).toSet();
		for (final threadStateKey in sharedThreadStateBox.keys) {
			cachedThreadKeys.remove(threadStateKey);
		}
		if (cachedThreadKeys.isNotEmpty) {
			print('[$imageboardKey] Deleting ${cachedThreadKeys.length} cached threads');
		}
		await _sharedThreadsBox.deleteAll(cachedThreadKeys);
	}

	Future<void> deleteAllData() async {
		settings.savedPostsBySite.remove(imageboardKey);
		settings.browserStateBySite.remove(imageboardKey);
		for (final ts in sharedThreadStateBox.values) {
			if (ts.imageboardKey == imageboardKey) {
				ts.delete();
			}
		}
	}

	String get _deprecatedThreadStatesBoxName => '${_boxPrefix}threadStates_$imageboardKey';
	String get _deprecatedThreadStatesBackupBoxName => '${_backupBoxPrefix}threadStates_$imageboardKey';

	Future<void> initialize() async {
		if (await Hive.boxExists(_deprecatedThreadStatesBoxName)) {
			Box<PersistentThreadState>? deprecatedThreadStatesBox;
			try {
				deprecatedThreadStatesBox = await Hive.openBox(_deprecatedThreadStatesBoxName);
			}
			catch (e, st) {
				if (await Hive.boxExists(_deprecatedThreadStatesBackupBoxName)) {
					try {
						deprecatedThreadStatesBox = await Hive.openBox(_deprecatedThreadStatesBackupBoxName);
					}
					catch (e, st) {
						Future.error(e, st);
					}
				}
				else {
					Future.error(e, st);
				}
			}
			if (deprecatedThreadStatesBox != null) {
				for (final String key in deprecatedThreadStatesBox.keys) {
					if (sharedThreadStateBox.containsKey('imageboardKey/$key')) {
						continue;
					}
					final ts = deprecatedThreadStatesBox.get(key)!;
					final newTs = PersistentThreadState(
						imageboardKey: imageboardKey,
						board: ts.board,
						id: ts.id,
						showInHistory: true
					);
					newTs.lastSeenPostId = ts.lastSeenPostId;
					newTs.lastOpenedTime = ts.lastOpenedTime;
					newTs.savedTime = ts.savedTime;
					newTs.receipts = ts.receipts;
					//newTs._thread = ts._thread;
					newTs.board = ts._deprecatedThread?.board ?? '';
					newTs.id = ts._deprecatedThread?.id ?? 0;
					setCachedThread(imageboardKey, newTs.board, newTs.id, ts._deprecatedThread);
					newTs.useArchive = ts.useArchive;
					newTs.postsMarkedAsYou = ts.postsMarkedAsYou;
					newTs.hiddenPostIds = ts.hiddenPostIds;
					newTs.draftReply = ts.draftReply;
					newTs.treeHiddenPostIds = ts.treeHiddenPostIds;
					newTs.hiddenPosterIds = ts.hiddenPosterIds;
					newTs.translatedPosts = ts.translatedPosts;
					newTs.autoTranslate = ts.autoTranslate;
					newTs.useTree = ts.useTree;
					newTs.variant = ts.variant;
					newTs.collapsedItems = ts.collapsedItems;
					newTs.downloadedAttachmentIds = ts.downloadedAttachmentIds;
					sharedThreadStateBox.put('$imageboardKey/$key', newTs);
				}
				await deprecatedThreadStatesBox.close();
				if (await Hive.boxExists(_deprecatedThreadStatesBoxName)) {
					await Hive.deleteBoxFromDisk(_deprecatedThreadStatesBoxName);
				}
				if (await Hive.boxExists(_deprecatedThreadStatesBackupBoxName)) {
					await Hive.deleteBoxFromDisk(_deprecatedThreadStatesBackupBoxName);
				}
			}
		}
		if (await Hive.boxExists('searches_$imageboardKey')) {
			print('Migrating searches box');
			final searchesBox = await Hive.openBox<PersistentRecentSearches>('${_boxPrefix}searches_$imageboardKey');
			final existingRecentSearches = searchesBox.get('recentSearches');
			if (existingRecentSearches != null) {
				settings.deprecatedRecentSearchesBySite[imageboardKey] = existingRecentSearches;
			}
			await searchesBox.deleteFromDisk();
		}
		if (settings.deprecatedRecentSearchesBySite[imageboardKey]?.entries.isNotEmpty == true) {
			print('Migrating recent searches');
			for (final search in settings.deprecatedRecentSearchesBySite[imageboardKey]!.entries) {
				Persistence.recentSearches.add(search..imageboardKey = imageboardKey);
			}
		}
		settings.deprecatedRecentSearchesBySite.remove(imageboardKey);
		if (await Hive.boxExists('browserStates_$imageboardKey')) {
			print('Migrating browser states box');
			final browserStateBox = await Hive.openBox<PersistentBrowserState>('${_boxPrefix}browserStates_$imageboardKey');
			final existingBrowserState = browserStateBox.get('browserState');
			if (existingBrowserState != null) {
				settings.browserStateBySite[imageboardKey] = existingBrowserState;
			}
			await browserStateBox.deleteFromDisk();
		}
		settings.browserStateBySite.putIfAbsent(imageboardKey, () => PersistentBrowserState(
			hiddenIds: {},
			favouriteBoards: [],
			autosavedIds: {},
			autowatchedIds: {},
			deprecatedHiddenImageMD5s: [],
			loginFields: {},
			threadWatches: {},
			boardWatches: [],
			notificationsMigrated: true,
			deprecatedBoardSortingMethods: {},
			deprecatedBoardReverseSortings: {},
			catalogVariants: {},
			postingNames: {},
			useCatalogGridPerBoard: {},
			overrideShowIds: {}
		));
		if (browserState.deprecatedTabs.isNotEmpty && ImageboardRegistry.instance.getImageboardUnsafe(imageboardKey) != null) {
			print('Migrating tabs');
			for (final deprecatedTab in browserState.deprecatedTabs) {
				if (Persistence.tabs.length == 1 && Persistence.tabs.first.imageboardKey == null) {
					// It's the dummy tab
					Persistence.tabs.clear();
				}
				Persistence.tabs.add(deprecatedTab..imageboardKey = imageboardKey);
			}
			browserState.deprecatedTabs.clear();
			didUpdateBrowserState();
		}
		if (await Hive.boxExists('boards_$imageboardKey')) {
			print('Migrating from site-specific boards box');
			final boardBox = await Hive.openBox<ImageboardBoard>('${_boxPrefix}boards_$imageboardKey');
			settings.deprecatedBoardsBySite[imageboardKey] = {
				for (final key in boardBox.keys) key.toString(): boardBox.get(key)!
			};
			await boardBox.deleteFromDisk();
		}
		if (settings.deprecatedBoardsBySite.containsKey(imageboardKey)) {
			print('Migrating to shared boards box');
			for (final board in settings.deprecatedBoardsBySite[imageboardKey]!.values) {
				_sharedBoardsBox.put('$imageboardKey/${board.name}', board);
			}
			settings.deprecatedBoardsBySite.remove(imageboardKey);
		}
		if (await Hive.boxExists('savedAttachments_$imageboardKey')) {
			print('Migrating saved attachments box');
			final savedAttachmentsBox = await Hive.openBox<SavedAttachment>('${_boxPrefix}savedAttachments_$imageboardKey');
			settings.savedAttachmentsBySite[imageboardKey] = {
				for (final key in savedAttachmentsBox.keys) key.toString(): savedAttachmentsBox.get(key)!
			};
			await savedAttachmentsBox.deleteFromDisk();
		}
		settings.savedAttachmentsBySite.putIfAbsent(imageboardKey, () => {});
		if (await Hive.boxExists('savedPosts_$imageboardKey')) {
			print('Migrating saved posts box');
			final savedPostsBox = await Hive.openBox<SavedPost>('${_boxPrefix}savedPosts_$imageboardKey');
			settings.savedPostsBySite[imageboardKey] = {
				for (final key in savedPostsBox.keys) key.toString(): savedPostsBox.get(key)!
			};
			await savedPostsBox.deleteFromDisk();
		}
		settings.savedPostsBySite.putIfAbsent(imageboardKey, () => {});
		// Cleanup expanding lists
		for (final list in browserState.autosavedIds.values) {
			list.removeRange(0, max(0, list.length - _maxAutosavedIdsPerBoard));
		}
		for (final list in browserState.autowatchedIds.values) {
			list.removeRange(0, max(0, list.length - _maxAutosavedIdsPerBoard));
		}
		for (final list in browserState.hiddenIds.values) {
			list.removeRange(0, max(0, list.length - _maxHiddenIdsPerBoard));
		}
		for (final list in browserState.overrideShowIds.values) {
			list.removeRange(0, max(0, list.length - _maxHiddenIdsPerBoard));
		}
		if (!browserState.notificationsMigrated) {
			browserState.threadWatches.clear();
			for (final threadState in sharedThreadStateBox.values) {
				if (threadState.imageboardKey == imageboardKey && threadState.savedTime != null && threadState.thread?.isArchived == false) {
					browserState.threadWatches[threadState.identifier] ??= ThreadWatch(
						board: threadState.board,
						threadId: threadState.id,
						youIds: threadState.youIds,
						localYousOnly: true,
						pushYousOnly: true,
						lastSeenId: threadState.thread?.posts.last.id ?? threadState.id
					);
				}
			}
			browserState.notificationsMigrated = true;
		}
		for (final savedPost in savedPosts.values) {
			if (savedPost.deprecatedThread != null) {
				print('Migrating saved ${savedPost.post} to ${savedPost.post.threadIdentifier}');
				getThreadState(savedPost.post.threadIdentifier).thread ??= savedPost.deprecatedThread;
				savedPost.deprecatedThread = null;
			}
		}
		for (final threadWatch in browserState.deprecatedThreadWatches) {
			browserState.threadWatches[threadWatch.threadIdentifier] ??= threadWatch;
		}
		browserState.deprecatedThreadWatches = []; // Can't use .clear(), it could be const
		for (final savedAttachment in savedAttachments.values) {
			if (savedAttachment.savedExt == null) {
				if (savedAttachment.attachment.ext == '.webm') {
					// It might be WEBM saved with .mp4 extension
					try {
						final fileBefore = savedAttachment.file;
						final scan = await MediaScan.scan(fileBefore.uri);
						savedAttachment.savedExt = (scan.codec == 'h264') ? '.mp4' : '.webm';
						final fileAfter = savedAttachment.file;
						if (fileBefore.path != fileAfter.path) {
							await fileBefore.rename(fileAfter.path);
						}
					}
					catch (e, st) {
						Future.error(e, st); // Report to crashlytics
					}
				}
				else {
					savedAttachment.savedExt = savedAttachment.attachment.ext;
				}
			}
		}
		if (settings.homeImageboardKey == imageboardKey) {
			tabs.first.board = maybeGetBoard(settings.homeBoardName);
			// Open at catalog, but keep previous thread available in pull tab
			tabs.first.threadForPullTab = tabs.first.thread;
			tabs.first.thread = null;
			// Clear catalog search
			tabs.first.initialSearch = null;
		}
		if (_threadIdToBumpInHistory?.$1 == imageboardKey) {
			// The previous thread in the home tab was replaced by the board switcher
			// Make sure it appears at the top of the history
			final threadToBump = _threadIdToBumpInHistory?.$2;
			if (threadToBump != null) {
				getThreadStateIfExists(threadToBump)?..lastOpenedTime = DateTime.now()..save();
			}
		}
		if (settings.automaticCacheClearDays < 100000) {
			await _cleanupThreads(Duration(days: settings.automaticCacheClearDays));
		}
		settings.save();
	}

	PersistentThreadState? getThreadStateIfExists(ThreadIdentifier? thread) {
		if (thread == null) {
			return null;
		}
		return sharedThreadStateBox.get(getThreadStateBoxKey(imageboardKey, thread));
	}

	PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false}) {
		final existingState = sharedThreadStateBox.get(getThreadStateBoxKey(imageboardKey, thread));
		if (existingState != null) {
			if (updateOpenedTime) {
				existingState.lastOpenedTime = DateTime.now();
				existingState.save();
			}
			return existingState;
		}
		final newState = PersistentThreadState(
			imageboardKey: imageboardKey,
			board: thread.board,
			id: thread.id,
			showInHistory: Persistence.settings.recordThreadsInHistory
		);
		sharedThreadStateBox.put(getThreadStateBoxKey(imageboardKey, thread), newState);
		return newState;
	}

	ImageboardBoard? maybeGetBoard(String boardName) => _sharedBoardsBox.get('$imageboardKey/$boardName');

	ImageboardBoard getBoard(String boardName) {
		final board = maybeGetBoard(boardName);
		if (board != null) {
			return board;
		}
		else {
			return ImageboardBoard(
				title: boardName,
				name: boardName,
				webmAudioAllowed: false,
				isWorksafe: true,
				maxImageSizeBytes: 4000000,
				maxWebmSizeBytes: 4000000
			);
		}
	}

	Iterable<ImageboardBoard> get boards => _sharedBoardsBox.keys.where((k) => (k as String).startsWith('$imageboardKey/')).map((k) => _sharedBoardsBox.get(k)!);

	Future<void> setBoard(String boardName, ImageboardBoard board) async{
		await _sharedBoardsBox.put('$imageboardKey/$boardName', board);
	}

	Future<void> removeBoard(String boardName) async{
		await _sharedBoardsBox.delete('$imageboardKey/$boardName');
	}

	SavedAttachment? getSavedAttachment(Attachment attachment) {
		return savedAttachments[attachment.globalId];
	}

	void saveAttachment(Attachment attachment, File fullResolutionFile, String ext) {
		final newSavedAttachment = SavedAttachment(
			attachment: attachment,
			savedTime: DateTime.now(),
			savedExt: ext
		);
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
		savedAttachmentsListenable.didUpdate();
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
		savedAttachmentsListenable.didUpdate();
	}

	SavedPost? getSavedPost(Post post) {
		return savedPosts[post.globalId];
	}

	void savePost(Post post) {
		savedPosts[post.globalId] = SavedPost(post: post, savedTime: DateTime.now());
		settings.save();
		// Likely will force the widget to rebuild
		getThreadState(post.threadIdentifier).save();
		savedPostsListenable.didUpdate();
	}

	void unsavePost(Post post) {
		savedPosts.remove(post.globalId);
		settings.save();
		// Likely will force the widget to rebuild
		getThreadStateIfExists(post.threadIdentifier)?.save();
		savedPostsListenable.didUpdate();
	}

	static String getThreadStateBoxKey(String imageboardKey, ThreadIdentifier thread) => '$imageboardKey/${thread.board}/${thread.id}';

	Listenable listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return sharedThreadStateBox.listenable(keys: [getThreadStateBoxKey(imageboardKey, thread)]);
	}

	Future<void> storeBoards(List<ImageboardBoard> newBoards) async {
		final deadline = DateTime.now().subtract(const Duration(days: 3));
		for (final String k in _sharedBoardsBox.keys) {
			if (!k.startsWith('$imageboardKey/')) {
				continue;
			}
			final v = _sharedBoardsBox.get(k)!;
			if ((v.additionalDataTime == null || v.additionalDataTime!.isBefore(deadline)) && !browserState.favouriteBoards.contains(v.name)) {
				_sharedBoardsBox.delete(k);
			}
		}
		for (final newBoard in newBoards) {
			final key = '$imageboardKey/${newBoard.name}';
			if (_sharedBoardsBox.get(key)?.additionalDataTime == null) {
				_sharedBoardsBox.put(key, newBoard);
			}
		}
	}

	static Future<void> saveTabs() async {
		await settings.save();
	}
	Future<void> didUpdateBrowserState() async {
		settings.save();
		notifyListeners();
	}

	static Future<void> didUpdateRecentSearches() async {
		settings.save();
		recentSearchesListenable.didUpdate();
	}

	Future<void> didUpdateSavedPost() async {
		settings.save();
		savedPostsListenable.didUpdate();
	}

	static List<String> get recentWebImageSearches => settings.recentWebImageSearches;
	static Future<void> handleWebImageSearch(String query) async {
		if (recentWebImageSearches.contains(query)) {
			// Bump
			settings.recentWebImageSearches = [query, ...recentWebImageSearches.where((e) => e != query)];
		}
		else {
			settings.recentWebImageSearches = [query, ...recentWebImageSearches.take(_maxRecentItems)];
		}
		await settings.save();
	}
	static Future<void> removeRecentWebImageSearch(String query) async {
		recentWebImageSearches.remove(query);
		await settings.save();
	}

	@override
	String toString() => 'Persistence($imageboardKey)';
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

enum PostHidingState {
	none,
	shown,
	hidden,
	treeHidden;
}

@HiveType(typeId: 3)
class PersistentThreadState extends EasyListenable with HiveObjectMixin implements Filterable {
	@HiveField(0)
	int? lastSeenPostId;
	@HiveField(1)
	DateTime lastOpenedTime;
	@HiveField(6)
	DateTime? savedTime;
	@HiveField(3)
	List<PostReceipt> receipts = [];
	@HiveField(4)
	Thread? _deprecatedThread;
	@HiveField(5)
	bool useArchive = false;
	@HiveField(7, defaultValue: [])
	List<int> postsMarkedAsYou = [];
	@HiveField(8, defaultValue: [])
	List<int> hiddenPostIds = [];
	@HiveField(9, defaultValue: '')
	String draftReply = '';
	// Don't persist this
	EphemeralThreadStateOwner? ephemeralOwner;
	@HiveField(10, defaultValue: [])
	List<int> treeHiddenPostIds = [];
	@HiveField(11, defaultValue: [])
	List<String> hiddenPosterIds = [];
	@HiveField(12, defaultValue: {})
	Map<int, Post> translatedPosts = {};
	@HiveField(13, defaultValue: false)
	bool autoTranslate = false;
	@HiveField(14)
	bool? useTree;
	@HiveField(15)
	ThreadVariant? variant;
	@HiveField(16, defaultValue: [])
	List<List<int>> collapsedItems = [];
	@HiveField(17, defaultValue: [])
	List<String> downloadedAttachmentIds = [];
	@HiveField(18, defaultValue: '')
	String imageboardKey;
	// Don't persist this
	Thread? _thread;
	@HiveField(21, defaultValue: {})
	Map<int, int> primarySubtreeParents = {};
	@HiveField(22, defaultValue: true)
	bool showInHistory;
	/// To track scroll position
	@HiveField(23)
	int? firstVisiblePostId;
	@HiveField(24)
	final EfficientlyStoredIntSet unseenPostIds;
	@HiveField(25)
	double? firstVisiblePostAlignment;
	@HiveField(26, defaultValue: PostSortingMethod.none)
	PostSortingMethod postSortingMethod;
	@HiveField(27)
	final EfficientlyStoredIntSet postIdsToStartRepliesAtBottom;
	@HiveField(28, defaultValue: [])
	List<int> overrideShowPostIds = [];
	@HiveField(29, defaultValue: '')
	String replyOptions;
	@HiveField(30)
	int? treeSplitId;

	Imageboard? get imageboard => ImageboardRegistry.instance.getImageboard(imageboardKey);

	bool get incognito => ephemeralOwner != null;

	PersistentThreadState({
		required this.imageboardKey,
		required this.board,
		required this.id,
		required this.showInHistory,
		this.ephemeralOwner,
		EfficientlyStoredIntSet? unseenPostIds,
		this.postSortingMethod = PostSortingMethod.none,
		EfficientlyStoredIntSet? postIdsToStartRepliesAtBottom,
		this.replyOptions = '',
	}) : lastOpenedTime = DateTime.now(),
	     unseenPostIds = unseenPostIds ?? EfficientlyStoredIntSet({}),
			 postIdsToStartRepliesAtBottom = postIdsToStartRepliesAtBottom ?? EfficientlyStoredIntSet({});

	void _invalidate() {
		_replyIdsToYou = null;
		_filteredPosts = null;
	}

	Future<void> ensureThreadLoaded({bool preinit = true, bool catalog = false}) async {
		_thread ??= await Persistence.getCachedThread(imageboardKey, board, id);
		if (preinit) {
			await _thread?.preinit(catalog: catalog);
		}
	}

	Future<Thread?> getThread() async {
		return _thread ?? (await Persistence.getCachedThread(imageboardKey, board, id));
	}

	Thread? get thread => _thread;
	set thread(Thread? newThread) {
		if (newThread != _thread) {
			if (_thread != null && newThread != null) {
				final oldMaxId = _thread?.posts_.fold(0, (m, p) => max(m, p.id)) ?? 0;
				unseenPostIds.data.addAll(newThread.posts_.map((p) => p.id).where((id) => id > oldMaxId && !youIds.contains(id)));
			}
			Persistence.setCachedThread(imageboardKey, board, id, newThread);
			_thread = newThread;
			_youIds = null;
			_invalidate();
			save(); // Inform listeners
		}
	}

	void didUpdateYourPosts() {
		_youIds = null;
		_invalidate();
	}

	List<int> freshYouIds() {
		return receipts.where((receipt) => receipt.markAsYou).map((receipt) => receipt.id).followedBy(postsMarkedAsYou).toList();
	}
	List<int>? _youIds;
	List<int> get youIds {
		_youIds ??= freshYouIds();
		return _youIds!;
	}
	List<int>? _replyIdsToYou;
	List<int>? replyIdsToYou() => _replyIdsToYou ??= () {
		return filteredPosts()?.where((p) {
			return p.repliedToIds.any((id) => youIds.contains(id));
		}).map((p) => p.id).toList();
	}();

	int? unseenReplyIdsToYouCount() => replyIdsToYou()?.where(unseenPostIds.data.contains).length;
	(Filter, List<Post>)? _filteredPosts;
	List<Post>? filteredPosts() {
		if (_filteredPosts != null && _filteredPosts?.$1 != EffectiveSettings.instance.globalFilter) {
			_filteredPosts = null;
		}
		return (_filteredPosts ??= () {
			if (lastSeenPostId == null) {
				return null;
			}
			final posts = thread?.posts.where((p) {
				return threadFilter.filter(p)?.type.hide != true
					&& EffectiveSettings.instance.globalFilter.filter(p)?.type.hide != true;
			}).toList();
			if (posts != null) {
				return (EffectiveSettings.instance.globalFilter, posts);
			}
			return null;
		}())?.$2;
	}
	int? unseenReplyCount() => filteredPosts()?.where((p) => unseenPostIds.data.contains(p.id)).length;
	int? unseenImageCount() => filteredPosts()?.map((p) {
		if (!unseenPostIds.data.contains(p.id)) {
			return 0;
		}
		return p.attachments.length;
	}).fold<int>(0, (a, b) => a + b);

	@override
	String toString() => 'PersistentThreadState(key: $imageboardKey/$board/$id, lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime, useArchive: $useArchive, showInHistory: $showInHistory)';

	@override
	@HiveField(19, defaultValue: '')
	String board;
	@override
	@HiveField(20, defaultValue: 0)
	int id;
	@override
	String? getFilterFieldText(String fieldName) => thread?.getFilterFieldText(fieldName);
	@override
	bool get hasFile => thread?.hasFile ?? false;
	@override
	bool get isThread => true;
	@override
	List<int> get repliedToIds => [];
	@override
	int get replyCount => thread?.replyCount ?? 0;
	@override
	Iterable<String> get md5s => thread?.md5s ?? [];
	@override
	bool get isDeleted => thread?.isDeleted ?? false;

	Filter get _makeThreadFilter => FilterCache(ThreadFilter(
		hideIds: hiddenPostIds,
		showIds: overrideShowPostIds,
		repliedToIds: treeHiddenPostIds,
		posterIds: hiddenPosterIds
	));
	late Filter threadFilter = _makeThreadFilter;
	void setPostHiding(int id, PostHidingState state) {
		switch (state) {
			case PostHidingState.none:
				hiddenPostIds.remove(id);
				treeHiddenPostIds.remove(id);
				overrideShowPostIds.remove(id);
				break;
			case PostHidingState.shown:
				hiddenPostIds.remove(id);
				treeHiddenPostIds.remove(id);
				if (!overrideShowPostIds.contains(id)) {
					overrideShowPostIds.add(id);
				}
				break;
			case PostHidingState.hidden:
				if (!hiddenPostIds.contains(id)) {
					hiddenPostIds.add(id);
				}
				treeHiddenPostIds.remove(id);
				overrideShowPostIds.remove(id);
				break;
			case PostHidingState.treeHidden:
				if (!hiddenPostIds.contains(id)) {
					hiddenPostIds.add(id);
				}
				if (!treeHiddenPostIds.contains(id)) {
					treeHiddenPostIds.add(id);
				}
				overrideShowPostIds.remove(id);
				break;
		}
		// invalidate cache
		threadFilter = _makeThreadFilter;
		_invalidate();
	}
	PostHidingState getPostHiding(int id) {
		if (treeHiddenPostIds.contains(id)) {
			return PostHidingState.treeHidden;
		}
		else if (hiddenPostIds.contains(id)) {
			return PostHidingState.hidden;
		}
		else if (overrideShowPostIds.contains(id)) {
			return PostHidingState.shown;
		}
		return PostHidingState.none;
	}

	void hidePosterId(String id) {
		hiddenPosterIds.add(id);
		// invalidate cache
		threadFilter = _makeThreadFilter;
		_invalidate();
	}
	void unHidePosterId(String id) {
		hiddenPosterIds.remove(id);
		// invalidate cache
		threadFilter = _makeThreadFilter;
		_invalidate();
	}

	bool isAttachmentDownloaded(Attachment attachment) => downloadedAttachmentIds.contains(attachment.id);

	void didDownloadAttachment(Attachment attachment) {
		downloadedAttachmentIds.add(attachment.id);
		save();
	}

	@override
	Future<void> save() async {
		if (ephemeralOwner != null) {
			await ephemeralOwner!.ephemeralThreadStateDidUpdate(this);
		}
		else {
			await super.save();
		}
	}

	@override
	Future<void> delete() async {
		// Don't delete cached thread, it will be cleaned up next launch
		// This allows time to undo safely
		await super.delete();
	}

	ThreadIdentifier get identifier => ThreadIdentifier(board, id);
	
	ThreadWatch? get threadWatch => imageboard?.notifications.getThreadWatch(identifier);

	String get boxKey => '$imageboardKey/$board/$id';
}

@HiveType(typeId: 4)
class PostReceipt {
	@HiveField(0)
	final String password;
	@HiveField(1)
	final int id;
	@HiveField(2, defaultValue: '')
	final String name;
	@HiveField(3, defaultValue: '')
	final String options;
	@HiveField(4)
	final DateTime? time;
	@HiveField(5, defaultValue: true)
	bool markAsYou;
	PostReceipt({
		required this.password,
		required this.id,
		required this.name,
		required this.options,
		required this.time,
		this.markAsYou = true
	});
	@override
	String toString() => 'PostReceipt(id: $id, password: $password, name: $name, options: $options, time: $time, markAsYou: $markAsYou)';
}

@HiveType(typeId: 18)
class SavedAttachment {
	@HiveField(0)
	final Attachment attachment;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2)
	final List<int> tags;
	@HiveField(3)
	String? savedExt;
	SavedAttachment({
		required this.attachment,
		required this.savedTime,
		List<int>? tags,
		required this.savedExt
	}) : tags = tags ?? [];

	Future<void> deleteFiles() async {
		await thumbnailFile.delete();
		await file.delete();
	}

	File get thumbnailFile => File('${Persistence.documentsDirectory.path}/$_savedAttachmentThumbnailsDir/${attachment.globalId}.jpg');
	File get file {
		final base = '${Persistence.documentsDirectory.path}/$_savedAttachmentsDir/${attachment.globalId}';
		if (savedExt == null) {
			// Not yet fixed
			return File('$base${attachment.ext == '.webm' ? '.mp4' : attachment.ext}');
		}
		return File('$base$savedExt');
	}
}

class SavedPost {
	Post post;
	final DateTime savedTime;
	Thread? deprecatedThread;

	SavedPost({
		required this.post,
		required this.savedTime
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
	Imageboard? get imageboard => imageboardKey == null ? null : ImageboardRegistry.instance.getImageboard(imageboardKey!);
	// Do not persist
	ThreadPageState? threadPageState;
	// Do not persist
	final Map<ThreadIdentifier, int> initialPostId = {};
	// Do not persist
	final Map<ThreadIdentifier, bool> initiallyUseArchive = {};
	// Do not persist
	final tabKey = GlobalKey(debugLabel: 'PersistentBrowserTab.tabKey');
	// Do not persist
	final boardKey = GlobalKey<BoardPageState>(debugLabel: 'PersistentBrowserTab.boardKey');
	// Do not persist
	final incognitoProviderKey = GlobalKey(debugLabel: 'PersistentBrowserTab.incognitoProviderKey');
	// Do not persist
	final masterDetailKey = GlobalKey<MultiMasterDetailPageState>(debugLabel: 'PersistentBrowserTab.masterDetailKey');
	// Do not persist
	final unseen = ValueNotifier(0);
	@HiveField(5, defaultValue: '')
	String draftOptions;
	@HiveField(6)
	String? draftFilePath;
	@HiveField(7)
	String? initialSearch;
	@HiveField(8)
	CatalogVariant? catalogVariant;
	@HiveField(9, defaultValue: false)
	bool incognito;
	// Do not persist
	ThreadIdentifier? threadForPullTab;

	PersistentBrowserTab({
		this.board,
		this.thread,
		this.draftThread = '',
		this.draftSubject = '',
		this.imageboardKey,
		this.draftOptions = '',
		this.draftFilePath,
		this.initialSearch,
		this.catalogVariant,
		this.incognito = false
	});

	IncognitoPersistence? incognitoPersistence;
	Persistence? get persistence => incognitoPersistence ?? imageboard?.persistence;

	Future<void> initialize() async {
		if (incognito && imageboardKey != null) {
			final persistence = ImageboardRegistry.instance.getImageboardUnsafe(imageboardKey!)?.persistence;
			if (persistence != null) {
				incognitoPersistence = IncognitoPersistence(persistence);
				if (thread != null) {
					// ensure state created before accessing
					incognitoPersistence!.getThreadState(thread!);
				}
			}
		}
		else if (thread != null) {
			await persistence?.getThreadStateIfExists(thread!)?.ensureThreadLoaded(preinit: false);
		}
	}

	@override
	void didUpdate() {
		if (incognito && imageboard != null && imageboard!.persistence != incognitoPersistence?.parent) {
			incognitoPersistence?.dispose();
			incognitoPersistence = IncognitoPersistence(imageboard!.persistence);
		}
		else if (!incognito) {
			incognitoPersistence?.dispose();
			incognitoPersistence = null;
		}
		super.didUpdate();
	}

	Future<void> mutate(FutureOr<void> Function(PersistentBrowserTab tab) mutator) async {
		await mutator(this);
		runWhenIdle(const Duration(seconds: 3), Persistence.saveTabs);
	}

	@override
	String toString() => 'PersistentBrowserTab($imageboardKey, $board, $thread)';
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
	final Set<String> deprecatedHiddenImageMD5s;
	@HiveField(7, defaultValue: {})
	Map<String, String> loginFields;
	@HiveField(8)
	String notificationsId;
	@HiveField(10, defaultValue: [])
	List<ThreadWatch> deprecatedThreadWatches;
	@HiveField(11, defaultValue: [])
	List<BoardWatch> boardWatches;
	@HiveField(12, defaultValue: false)
	bool notificationsMigrated;
	@HiveField(13, defaultValue: {})
	final Map<String, ThreadSortingMethod> deprecatedBoardSortingMethods;
	@HiveField(14, defaultValue: {})
	final Map<String, bool> deprecatedBoardReverseSortings;
	@HiveField(16)
	bool? useTree;
	@HiveField(17, defaultValue: {})
	final Map<String, CatalogVariant> catalogVariants;
	@HiveField(18, defaultValue: {})
	final Map<String, String> postingNames;
	@HiveField(19, defaultValue: false)
	bool treeModeInitiallyCollapseSecondLevelReplies;
	@HiveField(20, defaultValue: false)
	bool treeModeCollapsedPostsShowBody;
	@HiveField(21)
	bool? useCatalogGrid;
	@HiveField(22, defaultValue: {})
	final Map<String, bool> useCatalogGridPerBoard;
	@HiveField(23, defaultValue: {})
	Map<ThreadIdentifier, ThreadWatch> threadWatches;
	@HiveField(24, defaultValue: true)
	bool treeModeRepliesToOPAreTopLevel;
	@HiveField(25, defaultValue: {})
	final Map<String, List<int>> overrideShowIds;
	@HiveField(26, defaultValue: true)
	bool treeModeNewRepliesAreLinear;
	@HiveField(27, defaultValue: {})
	final Map<String, List<int>> autowatchedIds;
	
	PersistentBrowserState({
		this.deprecatedTabs = const [],
		required this.hiddenIds,
		required this.favouriteBoards,
		required this.autosavedIds,
		required this.autowatchedIds,
		required List<String> deprecatedHiddenImageMD5s,
		required this.loginFields,
		String? notificationsId,
		this.deprecatedThreadWatches = const [],
		required this.threadWatches,
		required this.boardWatches,
		required this.notificationsMigrated,
		required this.deprecatedBoardSortingMethods,
		required this.deprecatedBoardReverseSortings,
		required this.catalogVariants,
		required this.postingNames,
		this.useTree,
		this.treeModeInitiallyCollapseSecondLevelReplies = false,
		this.treeModeCollapsedPostsShowBody = false,
		this.treeModeRepliesToOPAreTopLevel = true,
		this.useCatalogGrid,
		required this.useCatalogGridPerBoard,
		required this.overrideShowIds,
		this.treeModeNewRepliesAreLinear = true
	}) : deprecatedHiddenImageMD5s = deprecatedHiddenImageMD5s.toSet(), notificationsId = notificationsId ?? (const Uuid()).v4();

	final Map<String, Filter> _catalogFilters = {};
	Filter getCatalogFilter(String board) {
		return _catalogFilters.putIfAbsent(board, () => FilterCache(IDFilter(
			hideIds: hiddenIds[board] ?? [],
			showIds: overrideShowIds[board] ?? []
		)));
	}
	
	bool? getThreadHiding(ThreadIdentifier thread) {
		if (overrideShowIds[thread.board]?.contains(thread.id) ?? false) {
			return false;
		}
		return hiddenIds[thread.board]?.contains(thread.id);
	}

	void setThreadHiding(ThreadIdentifier thread, bool? hiding) {
		switch (hiding) {
			case true:
				final map = hiddenIds.putIfAbsent(thread.board, () => []);
				if (!map.contains(thread.id)) {
					map.add(thread.id);
				}
				overrideShowIds[thread.board]?.remove(thread.id);
				break;
			case false:
				final map = overrideShowIds.putIfAbsent(thread.board, () => []);
				if (!map.contains(thread.id)) {
					map.add(thread.id);
				}
				hiddenIds[thread.board]?.remove(thread.id);
				break;
			case null:
				hiddenIds[thread.board]?.remove(thread.id);
				overrideShowIds[thread.board]?.remove(thread.id);
				break;
		}
		_catalogFilters.remove(thread.board);
	}
}

/// Custom adapter to not write-out deprecatedThread
class SavedPostAdapter extends TypeAdapter<SavedPost> {
  @override
  final int typeId = 19;

  @override
  SavedPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedPost(
      post: fields[0] as Post,
      savedTime: fields[1] as DateTime,
    )..deprecatedThread = fields[2] as Thread?;
  }

  @override
  void write(BinaryWriter writer, SavedPost obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.post)
      ..writeByte(1)
      ..write(obj.savedTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EfficientlyStoredIntSet {
	final Set<int> data;
	EfficientlyStoredIntSet(this.data);
}

class EfficientlyStoredIntSetAdapter extends TypeAdapter<EfficientlyStoredIntSet> {
  @override
  final int typeId = 40;

  @override
  EfficientlyStoredIntSet read(BinaryReader reader) {
    final intWidth = reader.readByte();
		if (intWidth == 0) {
			return EfficientlyStoredIntSet({});
		}
		final numDiffs = reader.readWord();
		final diffBase = reader.readInt();
		final diffs = <int>[];
		if (intWidth == 2) {
			for (int i = 0; i < numDiffs; i++) {
				diffs.add(reader.readWord());
			}
		}
		else if (intWidth == 4) {
			for (int i = 0; i < numDiffs; i++) {
				diffs.add(reader.readUint32());
			}
		}
		else if (intWidth == 8) {
			for (int i = 0; i < numDiffs; i++) {
				diffs.add(reader.readUint32());
			}
		}
		else {
			throw UnsupportedError('Set-int width $intWidth not allowed');
		}
		final out = <int>{diffBase};
		out.addAll(diffs.map((d) => diffBase + d));
		return EfficientlyStoredIntSet(out);
  }

  @override
  void write(BinaryWriter writer, EfficientlyStoredIntSet obj) {
		if (obj.data.toList().isEmpty) {
			writer.writeByte(0);
			return;
		}
		final sorted = obj.data.toList()..sort();
		final diffs = List.generate(sorted.length - 1, (i) => sorted[i + 1] - sorted.first);
		final int intWidth;
		if ((diffs.tryLast ?? 0) < 0xFFFF) {
			intWidth = 2;
		}
		else if ((diffs.tryLast ?? 0) < 0xFFFFFFFF) {
			intWidth = 4;
		}
		else {
			intWidth = 8;
		}
		writer.writeByte(intWidth);
		writer.writeWord(diffs.length);
		writer.writeInt(sorted.first);
		if (intWidth == 2) {
			for (final diff in diffs) {
				writer.writeWord(diff);
			}
		}
		else if (intWidth == 4) {
			for (final diff in diffs) {
				writer.writeUint32(diff);
			}
		}
		else if (intWidth == 8) {
			for (final diff in diffs) {
				writer.writeInt(diff);
			}
		}
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EfficientlyStoredIntSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
