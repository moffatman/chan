import 'package:chan/models/flag.dart';
import 'package:chan/models/intern.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';

part 'thread.g.dart';

void _readHookThreadFields(Map<int, dynamic> fields) {
	fields.update(ThreadFields.attachments.fieldNumber, (attachments) {
		return (attachments as List?)?.toList(growable: false);
	}, ifAbsent: () {
		final deprecatedAttachment = fields[7] as Attachment?;
		if (deprecatedAttachment != null) {
			return [deprecatedAttachment].toList(growable: false);
		}
		return const <Attachment>[];
	});
}

@HiveType(typeId: 15, isOptimized: true, readHook: _readHookThreadFields)
class Thread extends HiveObject implements Filterable {
	@HiveField(0, merger: MapLikeListMerger<Post, int>(
		childMerger: AdaptedMerger(PostAdapter.kTypeId),
		keyer: PostFields.getId,
		maintainOrder: true
	))
	final List<Post> posts_;
	@HiveField(1)
	bool isArchived;
	@override
	@HiveField(2)
	bool isDeleted;
	@override
	@HiveField(3)
	final int replyCount;
	@HiveField(4)
	final int imageCount;
	@override
	@HiveField(5)
	final int id;
	@override
	@HiveField(6)
	final String board;
	@HiveField(8)
	final String? title;
	@HiveField(9)
	bool isSticky;
	@HiveField(10)
	final DateTime time;
	@HiveField(11, isOptimized: true, merger: PrimitiveMerger())
	final Flag? flair;
	@HiveField(12, isOptimized: true)
	int? currentPage;
	@HiveField(13, isOptimized: true)
	int? uniqueIPCount;
	@HiveField(14, isOptimized: true)
	int? customSpoilerId;
	@HiveField(15, isOptimized: true, defaultValue: false)
	bool attachmentDeleted;
	@HiveField(16, merger: Attachment.unmodifiableListMerger)
	List<Attachment> attachments;
	@HiveField(17, isOptimized: true)
	ThreadVariant? suggestedVariant;
	@HiveField(18, isOptimized: true)
	String? archiveName;
	@HiveField(19, isOptimized: true)
	ImageboardPoll? poll;
	Thread({
		required this.posts_,
		this.isArchived = false,
		this.isDeleted = false,
		required this.replyCount,
		required this.imageCount,
		required this.id,
		this.attachmentDeleted = false,
		required String board,
		required this.title,
		required this.isSticky,
		required this.time,
		this.flair,
		this.currentPage,
		this.uniqueIPCount,
		this.customSpoilerId,
		required this.attachments,
		this.suggestedVariant,
		this.poll,
		this.archiveName
	}) : board = intern(board);
	
	bool _initialized = false;
	List<Post> get posts {
		if (!_initialized) {
			Map<int, Post> postsById = {};
			for (final post in posts_) {
				postsById[post.id] = post;
				post.replyIds = const [];
			}
			for (final post in posts_) {
				for (final referencedPostId in post.repliedToIds) {
					if (referencedPostId == post.id) {
						// Disallow recursive replies
						continue;
					}
					postsById[referencedPostId]?.maybeAddReplyId(post.id);
				}
			}
			_initialized = true;
		}
		return posts_;
	}

	Future<void> _fullPreinit() async {
		for (final post in posts_) {
			await post.preinit();
		}
	}

	Future<void> preinit({bool catalog = false}) async {
		if (posts_.last.isInitialized) {
			return;
		}
		if (catalog) {
			await posts_.first.preinit();
		}
		else {
			await SchedulerBinding.instance.scheduleTask(_fullPreinit, Priority.touch);
		}
	}

	void _markNewIPs(Thread other) {
		if (other.uniqueIPCount != null && uniqueIPCount != null) {
			Thread newer;
			Thread older;
			if (other.uniqueIPCount! > uniqueIPCount!) {
				newer = other;
				older = this;
			}
			else if (other.uniqueIPCount! < uniqueIPCount!) {
				newer = this;
				older = other;
			}
			else {
				return;
			}
			if ((newer.posts.length - older.posts.length) == (newer.uniqueIPCount! - older.uniqueIPCount!)) {
				int ipNumber = older.uniqueIPCount! + 1;
				for (final newPost in newer.posts.skip(older.posts.length)) {
					newPost.ipNumber = ipNumber++;
				}
			}
		}
	}

	void mergePosts(Thread? other, List<Post> otherPosts, ImageboardSite site) {
		if (other != null) {
			_markNewIPs(other);
		}
		final postIdToListIndex = {
			for (final pair in posts_.asMap().entries) pair.value.id: pair.key
		};
		for (final newChild in otherPosts) {
			final indexToReplace = postIdToListIndex[newChild.id];
			if (indexToReplace != null) {
				final postToReplace = posts_[indexToReplace];
				if (postToReplace.isStub) {
					posts_.removeAt(indexToReplace);
					posts_.insert(indexToReplace, newChild);
				}
				else {
					postToReplace.migrateFrom(newChild);
					if (postToReplace.id == id && attachmentDeleted && !newChild.attachmentDeleted) {
						attachments = newChild.attachments_;
						attachmentDeleted = false;
					}
				}
			}
			else {
				final newIndex = site.placeOrphanPost(posts_, newChild);
				postIdToListIndex.updateAll((postId, listIndex) {
					if (listIndex >= newIndex) {
						return listIndex + 1;
					}
					return listIndex;
				});
				postIdToListIndex[newChild.id] = newIndex;
				if (site.isPaged) {
					// For paged sites, we can load in parents after children
					for (final post in posts_) {
						if (post.repliedToIds.contains(newChild.id)) {
							newChild.maybeAddReplyId(post.id);
						}
					}
					// We can also load multi-parent children
					for (final repliedToId in newChild.repliedToIds) {
						final parentIndex = postIdToListIndex[repliedToId];
						if (parentIndex != null) {
							final parent = posts_[parentIndex];
							parent.maybeAddReplyId(newChild.id);
						}
					}
				}
				else {
					// This only handles single-parent case but no real imageboards have omitted replies
						final parentIndex = postIdToListIndex[newChild.parentId];
						if (parentIndex != null) {
							final parent = posts_[parentIndex];
							parent.maybeAddReplyId(newChild.id);
							parent.hasOmittedReplies = false;
						}
				}
			}
		}
		final postsPerPage = site.postsPerPage;
		if (postsPerPage != null) {
			final Map<int, Post> pageMap = {};
			final Map<int, int> pageChildCountMap = {};
			for (final post in posts_) {
				if (post.id.isNegative) {
					pageMap[post.id] = post;
				}
				else {
					final page = post.parentId;
					if (page != null) {
						pageChildCountMap.update(page, (c) => c + 1, ifAbsent: () => 1);
					}
				}
			}
			for (final pair in pageChildCountMap.entries) {
				if (pair.value >= postsPerPage) {
					// We have all the posts for this page
					pageMap[pair.key]?.hasOmittedReplies = false;
				}
			}
		}
	}

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is Thread &&
		other.id == id &&
		other.posts_.length == posts_.length &&
		other.posts_.last == posts_.last &&
		other.currentPage == currentPage &&
		other.isArchived == isArchived &&
		other.isDeleted == isDeleted &&
		other.isSticky == isSticky &&
		other.replyCount == replyCount &&
		listEquals(other.attachments, attachments) &&
		listEquals(other.posts_, posts_) &&
		other.poll == poll;

	@override
	int get hashCode => id;

	@override
	String toString() {
		return 'Thread /$board/$id';
	}

	@override
	String? getFilterFieldText(String fieldName) {
		switch (fieldName) {
			case 'subject':
				return title;
			case 'name':
				return posts_.first.name;
			case 'filename':
				return attachments.map((a) => a.filename).join('\n');
			case 'dimensions':
				return attachments.map((a) => '${a.width}x${a.height}').join('\n');
			case 'text':
				return posts_.first.span.buildText();
			case 'postID':
				return id.toString();
			case 'posterID':
				return posts_.first.posterId;
			case 'flag':
				return posts_.first.flag?.name;
			case 'md5':
				return attachments.map((a) => a.md5).join(' ');
			case 'capcode':
				return posts_.first.capcode;
			case 'trip':
				return posts_.first.trip;
			default:
				return null;
		}
	}
	@override
	bool get hasFile => attachments.isNotEmpty;
	@override
	bool get isThread => true;
	@override
	List<int> get repliedToIds => [];
	@override
	Iterable<String> get md5s => attachments.map((a) => a.md5);

	ThreadIdentifier get identifier => ThreadIdentifier(board, id);
}

@HiveType(typeId: 23)
class ThreadIdentifier {
	@HiveField(0)
	final String board;
	@HiveField(1)
	final int id;
	ThreadIdentifier(String board, this.id) : board = intern(board);

	@override
	String toString() => 'ThreadIdentifier: /$board/$id';

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ThreadIdentifier &&
		other.board == board &&
		other.id == id;
	@override
	int get hashCode => Object.hash(board, id);
}

class BoardThreadOrPostIdentifier {
	final String board;
	final int? threadId;
	final int? postId;
	BoardThreadOrPostIdentifier(String board, [this.threadId, this.postId]) : board = intern(board);
	@override
	String toString() => '/$board/$threadId/$postId';
	ThreadIdentifier? get threadIdentifier => threadId == null ? null : ThreadIdentifier(board, threadId!);
	PostIdentifier? get postIdentifier => threadId == null ?
																					null :
																					postId == null ?
																						PostIdentifier(board, threadId!, threadId!) :
																						PostIdentifier(board, threadId!, postId!);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is BoardThreadOrPostIdentifier) &&
		(other.board == board) &&
		(other.threadId == threadId) &&
		(other.postId == postId);
	@override
	int get hashCode => Object.hash(board, threadId, postId);
}

extension CompareTitle on Thread? {
	int compareTo(Thread? other) {
		final a = this;
		final b = other;
		if (a == null && b == null) {
			return 0;
		}
		else if (a == null) {
			return 1;
		}
		else if (b == null) {
			return -1;
		}
		return (a.title ?? a.posts_.tryFirst?.span.buildText() ?? '').friendlyCompareTo(b.title ?? b.posts_.tryFirst?.span.buildText() ?? '');
	}
}
