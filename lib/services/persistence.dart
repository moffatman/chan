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
import 'package:chan/services/cookies.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/incognito.dart';
import 'package:chan/services/json_cache.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
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

class UriFields {
	static String getValueOnUri(Uri x) => x.toString();
	static const value = ReadOnlyHiveFieldAdapter<Uri, String>(
		getter: getValueOnUri,
		fieldNumber: 0,
		fieldName: 'value',
		merger: PrimitiveMerger()
	);
}

class UriAdapter extends TypeAdapter<Uri> {
	const UriAdapter();

	static const int kTypeId = 12;

	@override
	final typeId = kTypeId;

	@override
	final fields = const {
		0: UriFields.value
	};

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

class DurationFields {
	static int getMicroseconds(Duration x) => x.inMicroseconds;
	static const microseconds = ReadOnlyHiveFieldAdapter<Duration, int>(
		getter: getMicroseconds,
		fieldNumber: 0,
		fieldName: 'microseconds',
		merger: PrimitiveMerger()
	);
}

class DurationAdapter extends TypeAdapter<Duration> {
	const DurationAdapter();

	static const int kTypeId = 39;

	@override
	final int typeId = kTypeId;

	@override
	final fields = const {
		0: DurationFields.microseconds
	};

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
	static late final Box<PersistentThreadState> sharedThreadStateBox;
	static late final Box<ImageboardBoard> sharedBoardsBox;
	static late final LazyBox<Thread> sharedThreadsBox;
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
	static late final Directory shareCacheDirectory;
	static late final PersistCookieJar wifiCookies;
	static late final PersistCookieJar cellularCookies;
	static PersistCookieJar get currentCookies {
		if (Settings.instance.isConnectedToWifi) {
			return wifiCookies;
		}
		return cellularCookies;
	}
	static PersistCookieJar get nonCurrentCookies {
		if (Settings.instance.isConnectedToWifi) {
			return cellularCookies;
		}
		return wifiCookies;
	}
	static final globalTabMutator = ValueNotifier(0);
	static final recentSearchesListenable = EasyListenable();
	static const settingsBoxName = 'settings';
	static const settingsBoxKey = 'settings';
	static const sharedThreadStatesBoxName = 'threadstates';
	static const sharedBoardsBoxName = 'boards';
	static const sharedThreadsBoxName = 'threads';
	static const savedAttachmentsDir = 'saved_attachments';
	static const fontsDir = 'ttf';
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
				box = await Hive.openBox<T>(boxName, compactionStrategy: compactionStrategy);
				Future.delayed(const Duration(seconds: 5), () {
					alertError(ImageboardRegistry.instance.context!, 'Database corruption\nDatabase was restored to backup from $backupTime (${formatRelativeTime(backupTime)} ago)', null);
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
				box = await Hive.openLazyBox<T>(boxName, compactionStrategy: compactionStrategy);
				Future.delayed(const Duration(seconds: 5), () {
					String message = 'Database corruption\n';
					if (backupCorrupted) {
						message += 'The backup was also corrupted. Data may have been permanently lost.';
					}
					else {
						message += 'Database was restored to backup from $backupTime (${formatRelativeTime(backupTime)} ago)';
					}
					alertError(ImageboardRegistry.instance.context!, message, null);
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
				await _backupBox(boxPath, backupBoxPath, gzip: gzip);
			}
		});
	}

	static bool get doesCachedThreadBoxExist {
		try {
			final dir = documentsDirectory.path;
			for (final path in [
				'$dir/$sharedThreadsBoxName.hive',
				'$dir/$_backupBoxPrefix$sharedThreadsBoxName.hive.gz'
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
			'$dir/$sharedThreadsBoxName.hive',
			'$dir/$_backupBoxPrefix$sharedThreadsBoxName.hive.gz'
		]) {
			final file = File(path);
			if (await file.exists()) {
				await file.delete();
			}
		}
	}

	static bool isThreadCached(String imageboardKey, String board, int id) {
		return sharedThreadsBox.containsKey('$imageboardKey/${board.toLowerCase()}/$id');
	}

	static Future<Thread?> getCachedThread(String imageboardKey, String board, int id) async {
		return await sharedThreadsBox.get('$imageboardKey/${board.toLowerCase()}/$id');
	}

	static Future<void> setCachedThread(String imageboardKey, String board, int id, Thread? thread) async {
		if (thread != null) {
			await sharedThreadsBox.put('$imageboardKey/${board.toLowerCase()}/$id', thread);
		}
		else {
			await sharedThreadsBox.delete('$imageboardKey/${board.toLowerCase()}/$id');
		}
	}

	Listenable listenForThreadChanges(ThreadIdentifier thread) {
		return sharedThreadsBox.listenable(keys: ['$imageboardKey/${thread.board.toLowerCase()}/${thread.id}']);
	}

	static Future<void> ensureTemporaryDirectoriesExist() async {
		await webmCacheDirectory.create(recursive: true);
		final oldHttpCache = Directory('${webmCacheDirectory.path}/httpcache');
		if (oldHttpCache.statSync().type == FileSystemEntityType.directory) {
			await oldHttpCache.rename(httpCacheDirectory.path);
		}
		await httpCacheDirectory.create(recursive: true);
		await shareCacheDirectory.create(recursive: true);
	}

	@visibleForTesting
	static Future<void> initializeHive({bool forTesting = false}) async {
		if (forTesting) {
			Hive.init(null);
		}
		else {
			await Hive.initFlutter();
		}
		Hive.registerAdapter(const PostAdapter());
		Hive.registerAdapter(const PostSpanFormatAdapter());
		Hive.registerAdapter(const ImageboardBoardAdapter());
		Hive.registerAdapter(const UriAdapter());
		Hive.registerAdapter(const AttachmentAdapter());
		Hive.registerAdapter(const AttachmentTypeAdapter());
		Hive.registerAdapter(const PersistentThreadStateAdapter());
		Hive.registerAdapter(const PostReceiptAdapter());
		Hive.registerAdapter(const ColorAdapter());
		Hive.registerAdapter(const SavedThemeAdapter());
		Hive.registerAdapter(const TristateSystemSettingAdapter());
		Hive.registerAdapter(const AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(const ThreadSortingMethodAdapter());
		Hive.registerAdapter(const CatalogVariantAdapter());
		Hive.registerAdapter(const ThreadVariantAdapter());
		Hive.registerAdapter(const ContentSettingsAdapter());
		Hive.registerAdapter(const PostDisplayFieldAdapter());
		Hive.registerAdapter(const SettingsQuickActionAdapter());
		Hive.registerAdapter(const WebmTranscodingSettingAdapter());
		Hive.registerAdapter(const SavedSettingsAdapter());
		Hive.registerAdapter(const ImageboardFlagAdapter());
		Hive.registerAdapter(const ImageboardMultiFlagAdapter());
		Hive.registerAdapter(const ThreadAdapter());
		Hive.registerAdapter(const ImageboardArchiveSearchQueryAdapter());
		Hive.registerAdapter(const PostTypeFilterAdapter());
		Hive.registerAdapter(const MediaFilterAdapter());
		Hive.registerAdapter(const PostDeletionStatusFilterAdapter());
		Hive.registerAdapter(const PersistentRecentSearchesAdapter());
		Hive.registerAdapter(const SavedAttachmentAdapter());
		Hive.registerAdapter(const SavedPostAdapter());
		Hive.registerAdapter(const ThreadIdentifierAdapter());
		Hive.registerAdapter(const PersistentBrowserTabAdapter());
		Hive.registerAdapter(const ThreadWatchAdapter());
		Hive.registerAdapter(const BoardWatchAdapter());
		Hive.registerAdapter(const PersistentBrowserStateAdapter());
		Hive.registerAdapter(const WebImageSearchMethodAdapter());
		Hive.registerAdapter(const GallerySavePathOrganizingAdapter());
		Hive.registerAdapter(const MediaScanAdapter());
		Hive.registerAdapter(const DurationAdapter());
		Hive.registerAdapter(const EfficientlyStoredIntSetAdapter());
		Hive.registerAdapter(const PostSortingMethodAdapter());
		Hive.registerAdapter(const ShareablePostsStyleAdapter());
		Hive.registerAdapter(const ImagePeekingSettingAdapter());
		Hive.registerAdapter(const MouseModeQuoteLinkBehaviorAdapter());
		Hive.registerAdapter(const DrawerModeAdapter());
		Hive.registerAdapter(const ImageboardBoardFlagAdapter());
		Hive.registerAdapter(const DraftPostAdapter());
		Hive.registerAdapter(const ImageboardPollRowAdapter());
		Hive.registerAdapter(const ImageboardPollAdapter());
	}

	static Future<void> initializeStatic() async {
		appLaunchTime = DateTime.now();
		initializeHive();
		temporaryDirectory = (await getTemporaryDirectory()).absolute;
		webmCacheDirectory = Directory('${temporaryDirectory.path}/webmcache');
		httpCacheDirectory = Directory('${temporaryDirectory.path}/httpcache');
		shareCacheDirectory = Directory('${temporaryDirectory.path}/sharecache');
		try {
			if (await shareCacheDirectory.exists()) {
				// This data is always useless upon app relaunch
				await shareCacheDirectory.delete(recursive: true);
			}
		}
		catch (e, st) {
			Future.error(e, st); // Just continue and report error
		}
		await ensureTemporaryDirectoriesExist();
		documentsDirectory = await getApplicationDocumentsDirectory();
		try {
			// Boxes were always saved as lowercase, but backups may have been
			// upper case in the past. Just correct all '*.hive*' to be lower case.
			for (final doc in documentsDirectory.listSync()) {
				final filename = doc.path.split('/').last;
				if (!filename.contains('.hive')) {
					continue;
				}
				final lowerCase = filename.toLowerCase();
				if (lowerCase == filename) {
					continue;
				}
				doc.renameSync(doc.path.replaceFirst('/$filename', '/$lowerCase'));
			}
		}
		catch (e, st) {
			Future.error(e, st);
		}
		wifiCookies = PersistCookieJar(
			storage: FileStorage(temporaryDirectory.path)
		);
		await wifiCookies.forceInit();
		cellularCookies = PersistCookieJar(
			storage: FileStorage('${temporaryDirectory.path}/cellular')
		);
		await cellularCookies.forceInit();
		await Directory('${documentsDirectory.path}/$savedAttachmentsDir').create(recursive: true);
		final settingsBox = await _openBoxWithBackup<SavedSettings>(settingsBoxName, compactionStrategy: (int entries, int deletedEntries) {
			return deletedEntries > 5;
		});
		settings = settingsBox.get(settingsBoxKey, defaultValue: SavedSettings(
			useInternalBrowser: true
		))!;
		// Copy old values
		JsonCache.instance.embedRegexes.value = settings.deprecatedEmbedRegexes;
		JsonCache.instance.sites.value = settings.contentSettings.deprecatedSites;
		if (settings.automaticCacheClearDays < 100000) {
			// Don't await
			clearFilesystemCaches(Duration(days: settings.automaticCacheClearDays));
		}
		settings.launchCount++;
		_startBoxBackupTimer(settingsBoxName);
		sharedThreadStateBox = await _openBoxWithBackup<PersistentThreadState>(sharedThreadStatesBoxName);
		_startBoxBackupTimer(sharedThreadStatesBoxName);
		sharedBoardsBox = await _openBoxWithBackup<ImageboardBoard>(sharedBoardsBoxName);
		_startBoxBackupTimer(sharedBoardsBoxName);
		if (sharedBoardsBox.isEmpty) {
			// First launch on new version
			Future.delayed(const Duration(milliseconds: 50), () => splashStage.value = 'Migrating...');
		}
		sharedThreadsBox = await _openLazyBoxWithBackup<Thread>(sharedThreadsBoxName, gzip: true);
		_startBoxBackupTimer(sharedThreadsBoxName, gzip: true);
		for (final tab in tabs) {
			final board = tab.board;
			if (board != null &&
			    ((tab.deprecatedDraftThread?.isNotEmpty ?? false) ||
					 (tab.deprecatedDraftOptions?.isNotEmpty ?? false) ||
					 (tab.deprecatedDraftSubject?.isNotEmpty ?? false) ||
					 (tab.deprecatedDraftFilePath?.isNotEmpty ?? false))) {
				tab.draft = DraftPost(
					board: board,
					threadId: null,
					name: null,
					options: tab.deprecatedDraftOptions,
					text: tab.deprecatedDraftThread ?? '',
					subject: tab.deprecatedDraftSubject,
					file: tab.deprecatedDraftFilePath,
					useLoginSystem: null
				);
				tab.deprecatedDraftThread = '';
				tab.deprecatedDraftOptions = '';
				tab.deprecatedDraftSubject = '';
				tab.deprecatedDraftFilePath = null;
			}
		}
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
		if (!settings.appliedMigrations.contains('ps')) {
			Future.delayed(const Duration(milliseconds: 50), () => splashStage.value = 'Migrating...');
			// ps = "post sorting", need to nullify it to allow taking default from site
			for (final threadState in sharedThreadStateBox.values) {
				if (threadState.postSortingMethod == PostSortingMethod.none) {
					threadState.postSortingMethod = null;
					await threadState.save();
				}
			}
			settings.appliedMigrations.add('ps');
			await settings.save();
		}
		if (!settings.appliedMigrations.contains('sf')) {
			Future.delayed(const Duration(milliseconds: 50), () => splashStage.value = 'Migrating...');
			// sf = "spam filter", invalidate previous IPs as it had some false positives
			for (final threadState in sharedThreadStateBox.values) {
				bool modified = false;
				for (final receipt in threadState.receipts) {
					if (receipt.spamFiltered && receipt.ip != null) {
						receipt.ip = 'x${receipt.ip}';
						modified = true;
					}
				}
				if (modified) {
					await threadState.save();
				}
			}
			settings.appliedMigrations.add('sf');
			await settings.save();
		}
		if (!settings.appliedMigrations.contains('bB')) {
			Future.delayed(const Duration(milliseconds: 50), () => splashStage.value = 'Migrating...');
			// bB = board capitalization. They were stored with mixed caps before
			for (final pair in sharedBoardsBox.toMap().entries) {
				// This kind of mangles the greek letter boards on lainchan.
				// But I guess they wouldn't reuse the same letter.
				final lowerCase = pair.key.toString().toLowerCase();
				if (pair.key != lowerCase) {
					// Need to migrate it
					await sharedBoardsBox.delete(pair.key);
					await sharedBoardsBox.put(lowerCase, pair.value);
				}
			}
			await sharedBoardsBox.flush();
			for (final pair in sharedThreadStateBox.toMap().entries) {
				final lowerCase = pair.key.toString().toLowerCase();
				if (pair.key != lowerCase) {
					await sharedThreadStateBox.delete(pair.key);
					await sharedThreadStateBox.put(lowerCase, pair.value);
				}
			}
			await sharedThreadStateBox.flush();
			for (final key in sharedThreadsBox.keys.toList(growable: false)) {
				final lowerCase = key.toString().toLowerCase();
				if (key != lowerCase) {
					final val = await sharedThreadsBox.get(key);
					if (val != null) {
						await sharedThreadsBox.delete(key);
						await sharedThreadsBox.put(key, val);
					}
				}
			}
			await sharedThreadsBox.flush();
			for (final browserState in settings.browserStateBySite.values) {
				_fixBoardKeyList(browserState.favouriteBoards);
				_fixBoardKeyMap(browserState.hiddenIds);
				_fixBoardKeyMap(browserState.autosavedIds);
				_fixBoardKeyMap(browserState.catalogVariants);
				_fixBoardKeyMap(browserState.postingNames);
				_fixBoardKeyMap(browserState.useCatalogGridPerBoard);
				_fixBoardKeyMap(browserState.overrideShowIds);
				_fixBoardKeyMap(browserState.autowatchedIds);
				_fixBoardKeyMap(browserState.postSortingMethodPerBoard);
				_fixBoardKeyMap(browserState.downloadSubfoldersPerBoard);
			}
			settings.appliedMigrations.add('bB');
			await settings.save();
		}
	}

	/// These are not really safely lowercase when read from disk. rewrite them.
	static void _fixBoardKeyList<T>(List<BoardKey> list) {
		for (int i = 0; i < list.length; i++) {
			final lowerCase = list[i].s.toLowerCase();
			if (list[i].s != lowerCase) {
				list[i] = BoardKey(lowerCase);
			}
		}
	}
	static void _fixBoardKeyMap<T>(Map<BoardKey, T> map) {
		for (final pair in map.entries.toList(growable: false)) {
			final lowerCase = pair.key.s.toLowerCase();
			if (pair.key.s != lowerCase) {
				map.remove(pair.key);
				map[BoardKey(lowerCase)] = pair.value;
			}
		}
	}

	static void ensureSane() {
		if (tabs.isEmpty) {
			tabs.add(PersistentBrowserTab());
		}
		if (currentTabIndex >= tabs.length) {
			currentTabIndex = 0;
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
		final ignorePaths = <String>[];
		if (Persistence.wifiCookies.storage case FileStorage storage) {
			// ignore: invalid_use_of_visible_for_testing_member
			ignorePaths.add(storage.currentDirectory);
		}
		if (Persistence.cellularCookies.storage case FileStorage storage) {
			// ignore: invalid_use_of_visible_for_testing_member
			ignorePaths.add(storage.currentDirectory);
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
				if ((deadline == null || stat.accessed.compareTo(deadline) < 0) && !ignorePaths.any(child.path.startsWith)) {
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
				if ((deadline == null || stat.accessed.isBefore(deadline)) && !ignorePaths.any(child.path.startsWith)) {
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
		final oldSavedThumbnailsDir = Directory('${documentsDirectory.path}/saved_attachments_thumbs');
		if ((await oldSavedThumbnailsDir.stat()).type == FileSystemEntityType.directory) {
			// No longer needed, thumbnails handled via MediaConversion from full file
			try {
				await oldSavedThumbnailsDir.delete(recursive: true);
			}
			catch (e, st) {
				Future.error(e, st); // crashlytics
			}
		}
		if (Platform.isIOS) {
			// FlutterEXIFRotation left various discarded JPEGs in the documentsDirectory
			await for (final child in documentsDirectory.list().handleError(
				(e) => print('Ignoring list error $e'),
				test: (e) => e is FileSystemException
			)) {
				if (!child.path.endsWith('.jpg') && !child.path.endsWith('.jpeg')) {
					continue;
				}
				final stat = await child.stat();
				if (stat.type == FileSystemEntityType.file) {
					try {
						await child.delete();
					}
					on FileSystemException catch (e) {
						print('Failed to delete junk JPEG ${child.path}: $e');
					}
				}
			}
		}
		if (deletedCount > 0) {
			print('Deleted $deletedCount files totalling ${(deletedSize / 1000000).toStringAsFixed(1)} MB');
		}
		await ensureTemporaryDirectoriesExist();
	}

	Future<void> _cleanupThreads(Duration olderThan) async {
		final deadline = DateTime.now().subtract(olderThan);
		final toPreserve = savedPosts.values.map((v) => '$imageboardKey/${v.post.board.toLowerCase()}/${v.post.threadId}').toSet();
		toPreserve.addAll(browserState.threadWatches.keys.map((v) => '$imageboardKey/${v.board.toLowerCase()}/${v.id}'));
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
		final cachedThreadKeys = sharedThreadsBox.keys.where((k) => (k as String).startsWith('$imageboardKey/')).toSet();
		for (final threadStateKey in sharedThreadStateBox.keys) {
			cachedThreadKeys.remove(threadStateKey);
		}
		if (cachedThreadKeys.isNotEmpty) {
			print('[$imageboardKey] Deleting ${cachedThreadKeys.length} cached threads');
		}
		await sharedThreadsBox.deleteAll(cachedThreadKeys);
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
					newTs.deprecatedDraftReply = ts.deprecatedDraftReply;
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
			deprecatedHiddenImageMD5s: {},
			loginFields: {},
			threadWatches: {},
			boardWatches: [],
			notificationsMigrated: true,
			deprecatedBoardSortingMethods: {},
			deprecatedBoardReverseSortings: {},
			catalogVariants: {},
			postingNames: {},
			useCatalogGridPerBoard: {},
			overrideShowIds: {},
			outbox: [],
			disabledArchiveNames: {},
			postSortingMethodPerBoard: {},
			downloadSubfoldersPerBoard: {}
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
				sharedBoardsBox.put('$imageboardKey/${board.name.toLowerCase()}', board);
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
						lastSeenId: threadState.thread?.posts.last.id ?? threadState.id,
						watchTime: DateTime.now(),
						notifyOnSecondLastPage: false,
						notifyOnLastPage: true,
						notifyOnDead: false
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
			tabs.first.board = maybeGetBoard(settings.homeBoardName)?.name;
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
		for (final threadState in sharedThreadStateBox.values) {
			if (threadState.imageboardKey != imageboardKey) {
				continue;
			}
			final reply = threadState.deprecatedDraftReply;
			final options = threadState.deprecatedReplyOptions;
			if ((reply?.isNotEmpty ?? false) || (options?.isNotEmpty ?? false)) {
				threadState.draft = DraftPost(
					board: threadState.board,
					threadId: threadState.id,
					name: null,
					options: options,
					text: reply ?? '',
					useLoginSystem: null
				);
				threadState.deprecatedDraftReply = null;
				threadState.deprecatedReplyOptions = null;
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

	ImageboardBoard? maybeGetBoard(String boardName) => sharedBoardsBox.get('$imageboardKey/${boardName.toLowerCase()}');

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

	Iterable<ImageboardBoard> get boards => sharedBoardsBox.keys.where((k) {
		final str = (k as String);
		return str.length > (imageboardKey.length + 2)
			&& str[imageboardKey.length] == '/'
			&& str.startsWith(imageboardKey);
	}).map((k) => sharedBoardsBox.get(k)!);

	Future<void> setBoard(String boardName, ImageboardBoard board) async{
		await sharedBoardsBox.put('$imageboardKey/${boardName.toLowerCase()}', board);
	}

	Future<void> removeBoard(String boardName) async{
		await sharedBoardsBox.delete('$imageboardKey/${boardName.toLowerCase()}');
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

	void savePost(Post post, {DateTime? savedTime}) {
		savedPosts[post.globalId] = SavedPost(post: post, savedTime: savedTime ?? DateTime.now());
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

	static String getThreadStateBoxKey(String imageboardKey, ThreadIdentifier thread) => '$imageboardKey/${thread.board.toLowerCase()}/${thread.id}';

	Listenable listenForPersistentThreadStateChanges(ThreadIdentifier thread) {
		return sharedThreadStateBox.listenable(keys: [getThreadStateBoxKey(imageboardKey, thread)]);
	}

	Future<void> storeBoards(List<ImageboardBoard> newBoards) async {
		final deadline = DateTime.now().subtract(const Duration(days: 3));
		for (final String k in sharedBoardsBox.keys) {
			if (!k.startsWith('$imageboardKey/')) {
				continue;
			}
			final v = sharedBoardsBox.get(k)!;
			if ((v.additionalDataTime == null || v.additionalDataTime!.isBefore(deadline)) && !browserState.favouriteBoards.contains(v.boardKey)) {
				sharedBoardsBox.delete(k);
			}
		}
		for (final newBoard in newBoards) {
			final key = '$imageboardKey/${newBoard.name.toLowerCase()}';
			if (sharedBoardsBox.get(key)?.additionalDataTime == null) {
				sharedBoardsBox.put(key, newBoard);
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

	static Future<void> clearCookies({required bool? fromWifi}) async {
		final icon = switch (fromWifi ?? Settings.instance.isConnectedToWifi) {
			true => CupertinoIcons.wifi,
			false => CupertinoIcons.antenna_radiowaves_left_right
		};
		try {
			await ImageboardRegistry.instance.clearAllPseudoCookies();
			await webview.CookieManager.instance().deleteAllCookies();
			await (switch (fromWifi) {
				true => Persistence.wifiCookies,
				null => Persistence.currentCookies,
				false => Persistence.cellularCookies
			}).deleteAll();
			showToast(
				context: ImageboardRegistry.instance.context!,
				icon: icon,
				message: 'Cleared cookies'
			);
		}
		on PathNotFoundException {
			showToast(
				context: ImageboardRegistry.instance.context!,
				icon: icon,
				message: 'Cookies already cleared'
			);
		}
	}

	static Future<void> saveCookiesFromWebView(Uri uri) async {
		final cookies = await webview.CookieManager.instance().getCookies(url: webview.WebUri.uri(uri));
		await currentCookies.saveFromResponse(uri, cookies.map((cookie) {
			final newCookie = MyCookie(cookie.name, cookie.value);
			newCookie.domain = cookie.domain;
			if (cookie.expiresDate != null) {
				newCookie.expires = DateTime.fromMillisecondsSinceEpoch(cookie.expiresDate!);
			}
			newCookie.httpOnly = cookie.isHttpOnly ?? false;
			newCookie.path = cookie.path;
			newCookie.secure = cookie.isSecure ?? false;
			return newCookie;
		}).toList());
	}

	@override
	String toString() => 'Persistence($imageboardKey)';
}

const _maxRecentItems = 50;
@HiveType(typeId: 8)
class PersistentRecentSearches {
	@HiveField(0, merger: OrderedSetLikePrimitiveListMerger<ImageboardArchiveSearchQuery>())
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

class TreePathListMerger extends FieldMerger<List<List<int>>> {
	const TreePathListMerger();

	@override
  bool merge(
    MergerController<List<List<int>>> merger,
    List<List<int>> yours,
    List<List<int>> theirs,
    List<List<int>>? base
  ) {
		if (yours.length == theirs.length) {
			// Fast path
			bool ok = true;
			for (int i = 0; ok && i < yours.length; i++) {
				final your = yours[i];
				final their = theirs[i];
				if (your.length == their.length) {
					ok = false;
					break;
				}
				for (int j = 0; j < your.length; j++) {
					if (your[j] != their[j]) {
						ok = false;
						break;
					}
				}
			}
			if (ok) {
				// Complete match
				return true;
			}
		}
		final bothString = <String>{};
		for (final your in yours) {
			bothString.add(your.join(','));
		}
		for (final their in theirs) {
			bothString.add(their.join(','));
		}
		final both = bothString.map((x) => x.split(',').map(int.parse).toList(growable: false));
		yours.clear();
		yours.addAll(both);
		theirs.clear();
		theirs.addAll(both);
		return true;
	}
}

@HiveType(typeId: 3)

class PersistentThreadState extends EasyListenable with HiveObjectMixin implements Filterable {
	@HiveField(0)
	int? lastSeenPostId;
	@HiveField(1)
	DateTime lastOpenedTime;
	@HiveField(6)
	DateTime? savedTime;
	@HiveField(3, merger: MapLikeListMerger<PostReceipt, int>(
		childMerger: AdaptedMerger(PostReceiptAdapter.kTypeId),
		keyer: PostReceiptFields.getId
	))
	List<PostReceipt> receipts = [];
	@HiveField(4)
	Thread? _deprecatedThread;
	@HiveField(5)
	bool useArchive = false;
	@HiveField(7, defaultValue: <int>[], merger: SetLikePrimitiveListMerger<int>())
	List<int> postsMarkedAsYou = [];
	@HiveField(8, defaultValue: <int>[], merger: SetLikePrimitiveListMerger<int>())
	List<int> hiddenPostIds = [];
	@HiveField(9)
	String? deprecatedDraftReply;
	// Don't persist this
	EphemeralThreadStateOwner? ephemeralOwner;
	@HiveField(10, defaultValue: <int>[], merger: SetLikePrimitiveListMerger<int>())
	List<int> treeHiddenPostIds = [];
	@HiveField(11, defaultValue: <String>[], merger: SetLikePrimitiveListMerger<String>())
	List<String> hiddenPosterIds = [];
	@HiveField(12, defaultValue: <int, Post>{})
	Map<int, Post> translatedPosts = {};
	@HiveField(13, defaultValue: false)
	bool autoTranslate = false;
	@HiveField(14)
	bool? useTree;
	@HiveField(15)
	ThreadVariant? variant;
	@HiveField(16, defaultValue: <List<int>>[], merger: TreePathListMerger())
	List<List<int>> collapsedItems = [];
	@HiveField(17, defaultValue: <String>[], merger: SetLikePrimitiveListMerger<String>())
	List<String> downloadedAttachmentIds = [];
	@HiveField(18, defaultValue: '')
	String imageboardKey;
	// Don't persist this
	Thread? _thread;
	@HiveField(21, defaultValue: <int, int>{})
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
	@HiveField(26)
	PostSortingMethod? postSortingMethod;
	@HiveField(27)
	final EfficientlyStoredIntSet postIdsToStartRepliesAtBottom;
	@HiveField(28, defaultValue: <int>[], merger: SetLikePrimitiveListMerger<int>())
	List<int> overrideShowPostIds = [];
	@HiveField(29)
	String? deprecatedReplyOptions;
	@HiveField(30)
	int? treeSplitId;
	@HiveField(31)
	DraftPost? draft;
	@HiveField(32)
	String? translatedTitle;

	Imageboard? get imageboard => ImageboardRegistry.instance.getImageboard(imageboardKey);

	bool get incognito => ephemeralOwner != null;

	PersistentThreadState({
		required this.imageboardKey,
		required this.board,
		required this.id,
		required this.showInHistory,
		this.ephemeralOwner,
		EfficientlyStoredIntSet? unseenPostIds,
		this.postSortingMethod,
		EfficientlyStoredIntSet? postIdsToStartRepliesAtBottom,
		this.draft
	}) : lastOpenedTime = DateTime.now(),
	     unseenPostIds = unseenPostIds ?? EfficientlyStoredIntSet({}),
			 postIdsToStartRepliesAtBottom = postIdsToStartRepliesAtBottom ?? EfficientlyStoredIntSet({}) {
		Settings.instance.filterListenable.addListener(_onGlobalFilterUpdate);
	}

	@override
	void dispose() {
		super.dispose();
		Settings.instance.filterListenable.removeListener(_onGlobalFilterUpdate);
	}

	void _onGlobalFilterUpdate() {
		metaFilter = _makeMetaFilter();
		_invalidate();
	}

	void _invalidate() {
		_replyIdsToYou = null;
		_filteredPosts = null;
	}

	Future<void> ensureThreadLoaded({bool preinit = true, bool catalog = false}) async {
		Thread? thread = _thread;
		if (thread != null) {
			await thread.preinit(catalog: catalog);
			return;
		}
		// This is to do preinit before setting _thread (which will generate metafilter)
		thread = await Persistence.getCachedThread(imageboardKey, board, id);
		if (preinit) {
			try {
				await thread?.preinit(catalog: catalog);
			}
			catch (e, st) {
				// The thread is corrupt or something
				Future.error(e, st); // crashlytics
				await Persistence.setCachedThread(imageboardKey, board, id, null);
				thread = null;
			}
		}
		_thread = thread ?? _thread;
	}

	Future<Thread?> getThread() async {
		return _thread ?? (await Persistence.getCachedThread(imageboardKey, board, id));
	}

	bool get isThreadCached => Persistence.isThreadCached(imageboardKey, board, id);

	Thread? get thread => _thread;
	set thread(Thread? newThread) {
		if (newThread != _thread) {
			if (_thread != null && newThread != null) {
				final oldIds = {
					for (final post in _thread?.posts_ ?? [])
						post.id: post.isStub
				};
				for (final p in newThread.posts_) {
					if (!p.isPageStub && oldIds[p.id] != p.isStub && !youIds.contains(id)) {
						unseenPostIds.data.add(p.id);
					}
				}
			}
			Persistence.setCachedThread(imageboardKey, board, id, newThread);
			_thread = newThread;
			metaFilter = _makeMetaFilter();
			_youIds = null;
			_invalidate();
			save(); // Inform listeners
		}
	}

	Future<void> didMutateThread() async {
		await Persistence.setCachedThread(imageboardKey, board, id, _thread);
		metaFilter = _makeMetaFilter();
		_youIds = null;
		_invalidate();
		await save(); // Inform listeners
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
	List<Post>? _filteredPosts;
	List<Post>? filteredPosts() {
		return _filteredPosts ??= _makeFilteredPosts();
	}
	List<Post>? _makeFilteredPosts() => thread?.posts.where((p) {
		final threadResult = threadFilter.filter(p);
		if (threadResult != null) {
			return !threadResult.type.hide;
		}
		final metaResult = metaFilter.filter(p);
		if (metaResult != null) {
			return !metaResult.type.hide;
		}
		final globalResult = Settings.instance.globalFilter.filter(p);
		if (globalResult != null) {
			return !globalResult.type.hide;
		}
		return true;
	}).toList(growable: false);
	int? unseenReplyCount() => filteredPosts()?.where((p) => unseenPostIds.data.contains(p.id)).length;
	int? unseenImageCount() => filteredPosts()?.map((p) {
		if (!unseenPostIds.data.contains(p.id)) {
			return 0;
		}
		return p.attachments.length;
	}).fold<int>(0, (a, b) => a + b);

	@override
	String toString() => 'PersistentThreadState(key: $boxKey, lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime, useArchive: $useArchive, showInHistory: $showInHistory)';

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

	Filter _makeThreadFilter() => FilterCache(ThreadFilter(
		hideIds: hiddenPostIds,
		showIds: overrideShowPostIds,
		repliedToIds: treeHiddenPostIds,
		posterIds: hiddenPosterIds
	));
	late Filter threadFilter = _makeThreadFilter();
	MetaFilter _makeMetaFilter() => MetaFilter(Settings.instance.globalFilter, thread?.posts);
	late MetaFilter metaFilter = _makeMetaFilter();
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
		threadFilter = _makeThreadFilter();
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
		threadFilter = _makeThreadFilter();
		_invalidate();
	}
	void unHidePosterId(String id) {
		hiddenPosterIds.remove(id);
		// invalidate cache
		threadFilter = _makeThreadFilter();
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

	String get boxKey => '$imageboardKey/${board.toLowerCase()}/$id';

	PostSortingMethod get effectivePostSortingMethod =>
		postSortingMethod ??
		imageboard?.persistence.browserState.postSortingMethodPerBoard[board] ??
		imageboard?.persistence.browserState.postSortingMethod ??
		PostSortingMethod.none;
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
	@HiveField(6, defaultValue: false)
	bool spamFiltered;
	@HiveField(7)
	String? ip;
	@HiveField(8)
	DraftPost? post;
	PostReceipt({
		required this.password,
		required this.id,
		required this.name,
		required this.options,
		required this.time,
		required this.post,
		this.markAsYou = true,
		this.spamFiltered = false,
		this.ip
	});
	@override
	String toString() => 'PostReceipt(id: $id, password: $password, name: $name, options: $options, time: $time, markAsYou: $markAsYou, spamFiltered: $spamFiltered, ip: $ip, post: $post)';
}

@HiveType(typeId: 18)
class SavedAttachment {
	@HiveField(0)
	final Attachment attachment;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2, merger: SetLikePrimitiveListMerger<int>())
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
		try {
			await file.delete();
		}
		on PathNotFoundException {
			// Ignore
		}
	}

	static final _badPathCharacters = RegExp(r'[/:]');

	File get file {
		final base = '${Persistence.documentsDirectory.path}/${Persistence.savedAttachmentsDir}/${attachment.globalId.replaceAll(_badPathCharacters, '_')}';
		if (savedExt == null) {
			// Not yet fixed
			return File('$base${attachment.ext == '.webm' ? '.mp4' : attachment.ext}');
		}
		return File('$base$savedExt');
	}

	@override
	String toString() => 'SavedAttachment($attachment)';
}

@HiveType(typeId: 19)
class SavedPost {
	@HiveField(0)
	Post post;
	@HiveField(1)
	final DateTime savedTime;
	@HiveField(2, isDeprecated: true)
	Thread? deprecatedThread;

	SavedPost({
		required this.post,
		required this.savedTime
	});
}

void _readHookPersistentBrowserTabFields(Map<int, dynamic> fields) {
	// Migrate .board from ImageboardBoard? -> String?
	fields.update(PersistentBrowserTabFields.board.fieldNumber, (board) {
		if (board is ImageboardBoard) {
			return board.name;
		}
		return board;
	}, ifAbsent: () => null);
}

@HiveType(typeId: 21, readHook: _readHookPersistentBrowserTabFields)
class PersistentBrowserTab extends EasyListenable {
	@HiveField(0)
	String? board;
	@HiveField(1)
	ThreadIdentifier? thread;
	@HiveField(2)
	String? deprecatedDraftThread;
	@HiveField(3)
	String? deprecatedDraftSubject;
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
	final masterDetailKey = GlobalKey<MultiMasterDetailPage1State<ThreadIdentifier>>(debugLabel: 'PersistentBrowserTab.masterDetailKey');
	// Do not persist
	final unseen = ValueNotifier(0);
	@HiveField(5)
	String? deprecatedDraftOptions;
	@HiveField(6)
	String? deprecatedDraftFilePath;
	@HiveField(7)
	String? initialSearch;
	@HiveField(8)
	CatalogVariant? catalogVariant;
	@HiveField(9, defaultValue: false)
	bool incognito;
	// Do not persist
	ThreadIdentifier? threadForPullTab;
	/// For ease of merging
	@HiveField(10, defaultValue: '')
	String id;
	@HiveField(11)
	DraftPost? draft;

	PersistentBrowserTab({
		this.board,
		this.thread,
		this.deprecatedDraftThread = '',
		this.deprecatedDraftSubject = '',
		this.imageboardKey,
		this.deprecatedDraftOptions = '',
		this.deprecatedDraftFilePath,
		this.initialSearch,
		this.catalogVariant,
		this.incognito = false,
		String id = '',
		this.draft
	}) : id = id.isEmpty ? const Uuid().v4() : id;

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
		runWhenIdle(const Duration(seconds: 1), Persistence.saveTabs);
	}

	@override
	String toString() => 'PersistentBrowserTab($imageboardKey, $board, $thread)';

	static const listMerger = MapLikeListMerger<PersistentBrowserTab, String>(
		childMerger: AdaptedMerger<PersistentBrowserTab>(PersistentBrowserTabAdapter.kTypeId),
		keyer: PersistentBrowserTabFields.getId,
		maintainOrder: true
	);
}

void _readHookPersistentBrowserStateFields(Map<int, dynamic> fields) {
	fields.update(6 /* no field generated */, (deprecatedHiddenImageMD5s) {
		if (deprecatedHiddenImageMD5s is List) {
			return deprecatedHiddenImageMD5s.toSet();
		}
		return deprecatedHiddenImageMD5s;
	}, ifAbsent: () => <String>{});
}

@HiveType(typeId: 22, readHook: _readHookPersistentBrowserStateFields)
class PersistentBrowserState {
	@HiveField(0, merger: PersistentBrowserTab.listMerger)
	List<PersistentBrowserTab> deprecatedTabs;
	@HiveField(2, defaultValue: <String, List<int>>{}, merger: MapMerger<BoardKey, List<int>>(
		SetLikePrimitiveListMerger()
	))
	final Map<BoardKey, List<int>> hiddenIds;
	@HiveField(3, defaultValue: <String>[], merger: OrderedSetLikePrimitiveListMerger<BoardKey>())
	final List<BoardKey> favouriteBoards;
	@HiveField(5, defaultValue: <String, List<int>>{}, merger: MapMerger<BoardKey, List<int>>(
		SetLikePrimitiveListMerger()
	))
	final Map<BoardKey, List<int>> autosavedIds;
	@HiveField(6, defaultValue: <String>{}, isDeprecated: true)
	final Set<String> deprecatedHiddenImageMD5s;
	@HiveField(7, defaultValue: <String, String>{})
	Map<String, String> loginFields;
	@HiveField(8)
	String notificationsId;
	@HiveField(10, defaultValue: <ThreadWatch>[], isDeprecated: true)
	List<ThreadWatch> deprecatedThreadWatches;
	@HiveField(11, defaultValue: <BoardWatch>[], merger: MapLikeListMerger<BoardWatch, String>(
		childMerger: AdaptedMerger(BoardWatchAdapter.kTypeId),
		keyer: BoardWatchFields.getBoard
	))
	List<BoardWatch> boardWatches;
	@HiveField(12, defaultValue: false)
	bool notificationsMigrated;
	@HiveField(13, defaultValue: <String, ThreadSortingMethod>{}, isDeprecated: true)
	final Map<String, ThreadSortingMethod> deprecatedBoardSortingMethods;
	@HiveField(14, defaultValue: <String, bool>{}, isDeprecated: true)
	final Map<String, bool> deprecatedBoardReverseSortings;
	@HiveField(16)
	bool? useTree;
	@HiveField(17, defaultValue: <String, CatalogVariant>{})
	final Map<BoardKey, CatalogVariant> catalogVariants;
	@HiveField(18, defaultValue: <String, String>{})
	final Map<BoardKey, String> postingNames;
	@HiveField(19, defaultValue: false)
	bool treeModeInitiallyCollapseSecondLevelReplies;
	@HiveField(20, defaultValue: false)
	bool treeModeCollapsedPostsShowBody;
	@HiveField(21)
	bool? useCatalogGrid;
	@HiveField(22, defaultValue: <String, bool>{})
	final Map<BoardKey, bool> useCatalogGridPerBoard;
	@HiveField(23, defaultValue: <ThreadIdentifier, ThreadWatch>{})
	Map<ThreadIdentifier, ThreadWatch> threadWatches;
	@HiveField(24, defaultValue: true)
	bool treeModeRepliesToOPAreTopLevel;
	@HiveField(25, defaultValue: <String, List<int>>{}, merger: MapMerger<BoardKey, List<int>>(
		SetLikePrimitiveListMerger()
	))
	final Map<BoardKey, List<int>> overrideShowIds;
	@HiveField(26, defaultValue: true)
	bool treeModeNewRepliesAreLinear;
	@HiveField(27, defaultValue: <String, List<int>>{}, merger: MapMerger<BoardKey, List<int>>(
		SetLikePrimitiveListMerger()
	))
	final Map<BoardKey, List<int>> autowatchedIds;
	@HiveField(28, defaultValue: [], merger: OrderedSetLikePrimitiveListMerger())
	final List<DraftPost> outbox;
	@HiveField(29, defaultValue: <String>{}, merger: PrimitiveSetMerger())
	final Set<String> disabledArchiveNames;
	@HiveField(30)
	PostSortingMethod? postSortingMethod;
	@HiveField(31, defaultValue: {})
	final Map<BoardKey, PostSortingMethod> postSortingMethodPerBoard;
	@HiveField(32, defaultValue: {})
	final Map<BoardKey, String> downloadSubfoldersPerBoard;
	
	PersistentBrowserState({
		this.deprecatedTabs = const [],
		required this.hiddenIds,
		required this.favouriteBoards,
		required this.autosavedIds,
		required this.autowatchedIds,
		required this.deprecatedHiddenImageMD5s,
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
		this.treeModeNewRepliesAreLinear = true,
		required this.outbox,
		required this.disabledArchiveNames,
		this.postSortingMethod,
		required this.postSortingMethodPerBoard,
		required this.downloadSubfoldersPerBoard
	}) : notificationsId = notificationsId ?? (const Uuid()).v4();

	final Map<BoardKey, Filter> _catalogFilters = {};
	Filter getCatalogFilter(BoardKey board) {
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
				final map = hiddenIds.putIfAbsent(thread.boardKey, () => []);
				if (!map.contains(thread.id)) {
					map.add(thread.id);
				}
				overrideShowIds[thread.board]?.remove(thread.id);
				break;
			case false:
				final map = overrideShowIds.putIfAbsent(thread.boardKey, () => []);
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

class EfficientlyStoredIntSet {
	final Set<int> data;
	EfficientlyStoredIntSet(this.data);

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is EfficientlyStoredIntSet &&
		setEquals(other.data, data);

	@override
	int get hashCode => data.hashCode;
}

class EfficientlyStoredIntSetFields {
	static Set<int> getData(EfficientlyStoredIntSet x) => x.data;
	static const data = ReadOnlyHiveFieldAdapter(
		fieldName: 'data',
		fieldNumber: 0,
		getter: getData,
		merger: SetMerger<int>(PrimitiveMerger())
	);
}

class EfficientlyStoredIntSetAdapter extends TypeAdapter<EfficientlyStoredIntSet> {
	const EfficientlyStoredIntSetAdapter();

	static const int kTypeId = 40;

  @override
  final int typeId = kTypeId;

	@override
	final fields = const {
		0: EfficientlyStoredIntSetFields.data
	};

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

extension PseudoCookies on PersistCookieJar {
	static final _pseudoCookieUri = Uri.parse('https://chancepseudo.com');
	static const _expiresOffset = Duration(days: 1000);

	Future<String?> readPseudoCookie(String key) async {
		final cookies = await loadForRequest(_pseudoCookieUri);
		return cookies.tryFirstWhere((c) => c.name == key)?.value;
	}

	Future<DateTime?> readPseudoCookieTime(String key) async {
		final cookies = await loadForRequest(_pseudoCookieUri);
		return cookies.tryFirstWhere((c) => c.name == key)?.expires?.subtract(_expiresOffset);
	}

	Future<void> writePseudoCookie(String key, String value) async {
		await saveFromResponse(_pseudoCookieUri, [Cookie(key, value)..expires = DateTime.now().add(_expiresOffset)]);
	}

	Future<void> deletePseudoCookie(String key) async {
		final toSave = await loadForRequest(_pseudoCookieUri);
		toSave.removeWhere((c) => c.name == key);
		await this.delete(_pseudoCookieUri);
		await saveFromResponse(_pseudoCookieUri, toSave);
	}
}

extension PreserveCloudflareClearance on PersistCookieJar {
	Future<void> deletePreservingCloudflare(Uri uri, [bool withDomainSharedCookie = false]) async {
		final toSave = (await loadForRequest(uri)).where((cookie) {
			return cookie.name == 'cf_clearance';
		}).toList();
		await this.delete(uri, withDomainSharedCookie);
		await saveFromResponse(uri, toSave);
	}
}
