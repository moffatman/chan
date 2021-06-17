import 'dart:io';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/flag.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:hive/hive.dart';
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

const _SAVED_ATTACHMENTS_THUMBS_DIR = 'saved_attachments_thumbs';
const _SAVED_ATTACHMENTS_DIR = 'saved_attachments';

class Persistence {
	static final threadStateBox = Hive.box<PersistentThreadState>('threadStates');
	static final boardBox = Hive.box<ImageboardBoard>('boards');
	static final savedAttachmentBox = Hive.box<SavedAttachment>('savedAttachments');
	static final savedPostsBox = Hive.box<SavedPost>('savedPosts');
	static late final PersistentRecentSearches recentSearches;
	static late final Directory temporaryDirectory;
	static late final Directory documentsDirectory;

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
		Hive.registerAdapter(SavedAttachmentAdapter());
		Hive.registerAdapter(SavedPostAdapter());
		temporaryDirectory = await getTemporaryDirectory();
		documentsDirectory = await getApplicationDocumentsDirectory();
		await Directory('${documentsDirectory.path}/$_SAVED_ATTACHMENTS_DIR').create(recursive: true);
		await Directory('${documentsDirectory.path}/$_SAVED_ATTACHMENTS_THUMBS_DIR').create(recursive: true);
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
		await Hive.openBox<SavedAttachment>('savedAttachments');
		await Hive.openBox<SavedPost>('savedPosts');
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

	static SavedAttachment? getSavedAttachment(Attachment attachment) {
		return savedAttachmentBox.get(attachment.globalId);
	}

	static void saveAttachment(Attachment attachment, File fullResolutionFile) {
		final newSavedAttachment = SavedAttachment(attachment: attachment, savedTime: DateTime.now());
		savedAttachmentBox.put(attachment.globalId, newSavedAttachment);
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

	static SavedPost? getSavedPost(Post post) {
		return savedPostsBox.get(post.globalId);
	}

	static void savePost(Post post, Thread thread) {
		final newSavedPost = SavedPost(post: post, savedTime: DateTime.now(), thread: thread);
		savedPostsBox.put(post.globalId, newSavedPost);
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

	PersistentThreadState() : this.lastOpenedTime = DateTime.now();

	List<int> get youIds => receipts.map((receipt) => receipt.id).toList();
	List<Post>? get repliesToYou => thread?.posts.where((p) => p.span.referencedPostIds(thread!.board).any((id) => youIds.contains(id))).toList();
	List<Post>? get unseenRepliesToYou => repliesToYou?.where((p) => p.id > lastSeenPostId!).toList();
	int? get unseenReplyCount => (lastSeenPostId == null) ? null : thread?.posts.where((p) => p.id > lastSeenPostId!).length;

	@override
	String toString() => 'PersistentThreadState(lastSeenPostId: $lastSeenPostId, receipts: $receipts, lastOpenedTime: $lastOpenedTime, savedTime: $savedTime)';

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
	}) : this.tags = tags ?? [];

	@override
	Future<void> delete() async {
		super.delete();
		await thumbnailFile.delete();
		await file.delete();
	}

	File get thumbnailFile => File('${Persistence.documentsDirectory.path}/$_SAVED_ATTACHMENTS_THUMBS_DIR/${attachment.globalId}.jpg');
	File get file => File('${Persistence.documentsDirectory.path}/$_SAVED_ATTACHMENTS_DIR/${attachment.globalId}${attachment.ext == '.webm' ? '.mp4' : attachment.ext}');
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

	List<String> getSearchableText() => [post.text];
}