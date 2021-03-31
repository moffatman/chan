import 'package:chan/services/settings.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
part 'persistence.g.dart';

class Persistence {
	static final threadStateBox = Hive.lazyBox<PersistentThreadState>('threadStates');

	static Future<void> initialize() async {
		await Hive.initFlutter();
		Hive.registerAdapter(ThemeSettingAdapter());
		Hive.registerAdapter(AutoloadAttachmentsSettingAdapter());
		Hive.registerAdapter(SavedSettingsAdapter());
		await Hive.openBox<SavedSettings>('settings');
		Hive.registerAdapter(PostReceiptAdapter());
		Hive.registerAdapter(PersistentThreadStateAdapter());
		await Hive.openLazyBox<PersistentThreadState>('threadStates');
	}

	static Future<PersistentThreadState> getThreadState(String board, int id, {bool updateOpenedTime = false}) async {
		final existingState = await threadStateBox.get('$board/$id');
		if (existingState != null) {
			if (updateOpenedTime) {
				existingState.lastOpenedTime = DateTime.now();
				await existingState.save();
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