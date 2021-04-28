import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

class Persistence {
	static final threadStateBox = Hive.box<PersistentThreadState>('threadStates');
	static final boardBox = Hive.box<ImageboardBoard>('boards');
	static late final PersistentRecentSearches recentSearches;

	static Future<void> initialize() async {
		await Hive.initFlutter();
		Hive.registerAdapter(ThemeSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(ThreadSortingMethodAdapter());
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
		await Hive.openBox<SavedSettings>('settings');
		await Hive.openBox<PersistentThreadState>('threadStates');
		final searchesBox = await Hive.openBox<PersistentRecentSearches>('recentSearches');
		final existingRecentSearches = searchesBox.get('recentSearches');
		if (existingRecentSearches != null) {
			recentSearches = existingRecentSearches;
		}
		else {
			recentSearches = PersistentRecentSearches();
			searchesBox.put('recentSearches', recentSearches);
		}
		await Hive.openBox<ImageboardBoard>('boards');
	}

	static PersistentThreadState? getThreadStateIfExists(ThreadIdentifier thread) {
		return threadStateBox.get('${thread.board}/${thread.id}');
	}

	static PersistentThreadState getThreadState(ThreadIdentifier thread, {bool updateOpenedTime = false}) {
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

	static ImageboardBoard getBoard(String boardName) {
		final board = boardBox.get(boardName);
		if (board != null) {
			return board;
		}
		else {
			throw BoardNotFoundException(boardName);
		}
	}
}

const _MAX_RECENT_ITEMS = 50;
@HiveType(typeId: 8)
class PersistentRecentSearches extends HiveObject {
	@HiveField(0)
	List<ImageboardArchiveSearchQuery> entries = [];

	void add(ImageboardArchiveSearchQuery entry) {
		entries = [entry, ...entries.take(_MAX_RECENT_ITEMS)];
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
class PersistentThreadState extends HiveObject {
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

	PersistentThreadState() : this.lastOpenedTime = DateTime.now();

	List<int> get youIds => receipts.map((receipt) => receipt.id).toList();
	List<Post>? get repliesToYou => thread?.posts.where((p) => p.span.referencedPostIds(thread!.board).any((id) => youIds.contains(id))).toList();
	List<Post>? get unseenRepliesToYou => repliesToYou?.where((p) => p.id > lastSeenPostId!).toList();
	int? get unseenReplyCount => (lastSeenPostId == null) ? null : thread?.posts.where((p) => p.id > lastSeenPostId!).length;

	@override
	String toString() => 'PersistentThreadState(lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime)';
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