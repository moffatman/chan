import 'package:chan/models/search.dart';
import 'package:chan/services/settings.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
part 'persistence.g.dart';

class Persistence {
	static final threadStateBox = Hive.box<PersistentThreadState>('threadStates');
	static late final PersistentRecentSearches recentSearches;

	static Future<void> initialize() async {
		await Hive.initFlutter();
		Hive.registerAdapter(ThemeSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(SavedSettingsAdapter());
		await Hive.openBox<SavedSettings>('settings');
		Hive.registerAdapter(PostReceiptAdapter());
		Hive.registerAdapter(PersistentThreadStateAdapter());
		await Hive.openBox<PersistentThreadState>('threadStates');
		Hive.registerAdapter(ImageboardArchiveSearchQueryAdapter());
		Hive.registerAdapter(PostTypeFilterAdapter());
		Hive.registerAdapter(MediaFilterAdapter());
		Hive.registerAdapter(PersistentRecentSearchesAdapter());
		final searchesBox = await Hive.openBox<PersistentRecentSearches>('recentSearches');
		final existingRecentSearches = searchesBox.get('recentSearches');
		if (existingRecentSearches != null) {
			recentSearches = existingRecentSearches;
		}
		else {
			recentSearches = PersistentRecentSearches();
			searchesBox.put('recentSearches', recentSearches);
		}
	}

	static PersistentThreadState getThreadState(String board, int id, {bool updateOpenedTime = false}) {
		final existingState = threadStateBox.get('$board/$id');
		if (existingState != null) {
			if (updateOpenedTime) {
				existingState.lastOpenedTime = DateTime.now();
				existingState.save();
			}
			return existingState;
		}
		else {
			final newState = PersistentThreadState(
				lastOpenedTime: updateOpenedTime ? DateTime.now() : null
			);
			threadStateBox.put('$board/$id', newState);
			return newState;
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
	@HiveField(2)
	bool watched;
	@HiveField(3)
	List<PostReceipt> receipts;

	PersistentThreadState({
		this.lastSeenPostId,
		DateTime? lastOpenedTime,
		this.watched = false,
		List<PostReceipt>? receipts
	}) : this.lastOpenedTime = lastOpenedTime ?? DateTime.now(), this.receipts = receipts ?? [];

	List<int> get youIds => receipts.map((receipt) => receipt.id).toList();

	@override
	String toString() => 'PersistentThreadState(lastSeenPostId: $lastSeenPostId, receipts: $receipts';
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