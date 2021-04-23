import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

class PostSpanRenderOptions {
	final GestureRecognizer? recognizer;
	final bool overrideRecognizer;
	final Color? overrideTextColor;
	final bool showCrossThreadLabel;
	final bool addExpandingPosts;
	PostSpanRenderOptions({
		this.recognizer,
		this.overrideRecognizer = false,
		this.overrideTextColor,
		this.showCrossThreadLabel = true,
		this.addExpandingPosts = true
	});
	GestureRecognizer? get overridingRecognizer => overrideRecognizer ? recognizer : null;
}

abstract class PostSpan {
	List<int> referencedPostIds(String forBoard) {
		return [];
	}
	InlineSpan build(BuildContext context, PostSpanRenderOptions options);
}

class PostNodeSpan extends PostSpan {
	List<PostSpan> children;

	PostNodeSpan(this.children);

	List<int> referencedPostIds(String forBoard) {
		return children.expand((child) => child.referencedPostIds(forBoard)).toList();
	}

	build(context, options) {
		return TextSpan(
			children: children.map((child) => child.build(context, options)).toList()
		);
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	PostTextSpan(this.text);
	build(context, options) {
		return TextSpan(
			text: this.text,
			recognizer: options.recognizer
		);
	}
}
class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	PostQuoteSpan(this.child);
	build(context, options) {
		return TextSpan(
			children: [child.build(context, options)],
			style: TextStyle(color: options.overrideTextColor ?? Colors.green),
			recognizer: options.recognizer
		);
	}
}

class PostQuoteLinkSpan extends PostSpan {
	final String board;
	int? threadId;
	final int postId;
	final bool dead;
	PostQuoteLinkSpan({
		required this.board,
		this.threadId,
		required this.postId,
		required this.dead
	}) {
		if (!dead && threadId == null) {
			throw StateError('A live QuoteLinkSpan should know its threadId');
		}
	}
	@override
	List<int> referencedPostIds(String forBoard) {
		if (forBoard == board) {
			return [postId];
		}
		return [];
	}
	InlineSpan _buildCrossThreadLink(BuildContext context, PostSpanRenderOptions options) {
		String text = '>>';
		if (context.watch<PostSpanZoneData>().board != board) {
			text += '/$board/';
		}
		text += '$postId';
		if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		return TextSpan(
			text: text,
			style: TextStyle(
				color: options.overrideTextColor ?? Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
				context.read<GlobalKey<NavigatorState>>().currentState!.push(cpr.CupertinoPageRoute(
					builder: (ctx) => ThreadPage(
						thread: ThreadIdentifier(
							board: board,
							id: this.threadId!
						),
						initialPostId: this.postId,
						initiallyUseArchive: this.dead
					)
				));
			})
		);
	}
	InlineSpan _buildDeadLink(BuildContext context, PostSpanRenderOptions options) {
		final zone = context.watch<PostSpanZoneData>();
		String text = '>>$postId';
		if (zone.postFromArchiveError(postId) != null) {
			text += ' (Error: ${zone.postFromArchiveError(postId)}';
		}
		else if (zone.isLoadingPostFromArchive(postId)) {
			text += ' (Loading...)';
		}
		else {
			text += ' (Dead)';
		}
		return TextSpan(
			text: text,
			style: TextStyle(
				color: options.overrideTextColor ?? Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
				if (!zone.isLoadingPostFromArchive(postId)) zone.loadPostFromArchive(postId);
			})
		);
	}
	InlineSpan _buildNormalLink(BuildContext context, PostSpanRenderOptions options) {
		final zone = context.watch<PostSpanZoneData>();
		String text = '>>$postId';
		if (postId == threadId) {
			text += ' (OP)';
		}
		if (zone.threadState?.youIds.contains(postId) ?? false) {
			text += ' (You)';
		}
		final bool expandedImmediatelyAbove = zone.shouldExpandPost(postId) || zone.stackIds.length > 1 && zone.stackIds.elementAt(zone.stackIds.length - 2) == postId;
		final bool expandedSomewhereAbove = expandedImmediatelyAbove || zone.stackIds.contains(postId);
		return TextSpan(
			text: text,
			style: TextStyle(
				color: options.overrideTextColor ?? (expandedImmediatelyAbove ? Colors.pink : Colors.red),
				decoration: TextDecoration.underline,
				decorationStyle: expandedSomewhereAbove ? TextDecorationStyle.dashed : null
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
				if (!zone.stackIds.contains(postId)) {
					if (context.read<EffectiveSettings>().useTouchLayout) {
						Navigator.of(context).push(
							TransparentRoute(
								builder: (ctx) => PostsPage(
									zone: zone.childZoneFor(postId),
									postsIdsToShow: [postId]								
								)
							)
						);
					}
					else {
						zone.toggleExpansionOfPost(postId);
					}
				}
			})
		);
	}
	_build(BuildContext context, PostSpanRenderOptions options) {
		final zone = context.watch<PostSpanZoneData>();
		if (dead && threadId == null) {
			// Dead links do not know their thread
			final thisPostLoaded = zone.postFromArchive(postId);
			if (thisPostLoaded != null) {
				threadId = thisPostLoaded.threadId;
			}
			else {
				return _buildDeadLink(context, options);
			}
		}

		if (threadId != null && (board != zone.board || threadId != zone.threadId)) {
			return _buildCrossThreadLink(context, options);
		}
		else {
			// Normal link
			final span = _buildNormalLink(context, options);
			final thisPostInThread = zone.threadPosts.where((p) => p.id == postId);
			if (thisPostInThread.isEmpty || context.read<EffectiveSettings>().useTouchLayout || zone.stackIds.contains(postId) || zone.shouldExpandPost(postId)) {
				return span;
			}
			else {
				return WidgetSpan(
					child: HoverPopup(
						child: Text.rich(
							span,
							textScaleFactor: 1
						),
						popup: ChangeNotifierProvider.value(
							value: zone,
							child: PostRow(
								post: thisPostInThread.first
							)
						)
					)
				);
			}
		}
	}
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		if (options.addExpandingPosts && (threadId == zone.threadId && board == zone.board)) {
			return TextSpan(
				children: [
					_build(context, options),
					WidgetSpan(child: ExpandingPost(postId))
			]);
		}
		else {
			return _build(context, options);
		}
	}
}

class PostBoardLink extends PostSpan {
	final String board;
	PostBoardLink(this.board);
	build(context, options) {
		return TextSpan(
			text: '>>/$board/',
			style: TextStyle(
				color: options.overrideTextColor ?? Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
				context.read<GlobalKey<NavigatorState>>().currentState!.push(cpr.CupertinoPageRoute(builder: (ctx) => BoardPage(initialBoard: Persistence.getBoard(board))));
			})
		);
	}
}

class PostSpoilerSpan extends PostSpan {
	final PostSpan child;
	final int id;
	PostSpoilerSpan(this.child, this.id);
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		final showSpoiler = zone.shouldShowSpoiler(id);
		final toggleRecognizer = TapGestureRecognizer()..onTap = () {
			zone.toggleShowingOfSpoiler(id);
		};
		final hiddenColor = DefaultTextStyle.of(context).style.color;
		final visibleColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
		return TextSpan(
			children: [child.build(context, PostSpanRenderOptions(
				recognizer: toggleRecognizer,
				overrideRecognizer: !showSpoiler,
				overrideTextColor: showSpoiler ? visibleColor : hiddenColor,
				showCrossThreadLabel: options.showCrossThreadLabel
			))],
			style: TextStyle(
				backgroundColor: hiddenColor,
				color: showSpoiler ? visibleColor : null
			),
			recognizer: toggleRecognizer
		);
	}
}

class PostLinkSpan extends PostSpan {
	final String url;
	PostLinkSpan(this.url);
	build(context, options) {
		return TextSpan(
			text: url,
			style: TextStyle(
				decoration: TextDecoration.underline
			),
			recognizer: TapGestureRecognizer()..onTap = () => openBrowser(context, Uri.parse(url))
		);
	}
}

class PostSpanZone extends StatelessWidget {
	final int postId;
	final WidgetBuilder builder;

	PostSpanZone({
		required this.postId,
		required this.builder
	});

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider<PostSpanZoneData>.value(
			value: context.read<PostSpanZoneData>().childZoneFor(postId),
			child: Builder(
				builder: builder
			)
		);
	}
}

abstract class PostSpanZoneData extends ChangeNotifier {
	final _children = Map<int, PostSpanZoneData>();
	List<Post> get threadPosts;
	int get threadId;
	String get board;
	ImageboardSite get site;
	Iterable<int> get stackIds;
	PersistentThreadState? get threadState;
	ValueChanged<Post>? get onNeedScrollToPost;

	bool shouldExpandPost(int id) => false;
	void toggleExpansionOfPost(int id) => throw UnimplementedError();
	bool isLoadingPostFromArchive(int id) => false;
	Future<void> loadPostFromArchive(int id) => throw UnimplementedError();
	Post? postFromArchive(int id) => null;
	String? postFromArchiveError(int id) => null;
	bool shouldShowSpoiler(int id) => false;
	void toggleShowingOfSpoiler(int id) => throw UnimplementedError();
	PostSpanZoneData childZoneFor(int postId) {
		if (!_children.containsKey(postId)) {
			_children[postId] = PostSpanChildZoneData(
				parent: this,
				postId: postId
			);
		}
		return _children[postId]!;
	}


	@override
	void dispose() {
		_children.values.forEach((zone) => zone.dispose());
		super.dispose();
	}
}

class PostSpanChildZoneData extends PostSpanZoneData {
	final int postId;
	final Map<int, bool> _shouldExpandPost = Map();
	final PostSpanZoneData parent;
	final Map<int, bool> _shouldShowSpoiler = Map();

	PostSpanChildZoneData({
		required this.parent,
		required this.postId
	});

	List<Post> get threadPosts => parent.threadPosts;

	int get threadId => threadPosts.first.threadId;

	String get board => parent.board;

	ImageboardSite get site => parent.site;

	PersistentThreadState? get threadState => parent.threadState;

	ValueChanged<Post>? get onNeedScrollToPost => parent.onNeedScrollToPost;

	Iterable<int> get stackIds {
		return parent.stackIds.followedBy([postId]);
	}

	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}

	bool shouldShowSpoiler(int id) {
		return _shouldShowSpoiler[id] ?? false;
	}

	void toggleShowingOfSpoiler(int id) {
		_shouldShowSpoiler[id] = !shouldShowSpoiler(id);
		notifyListeners();
	}

	bool isLoadingPostFromArchive(int id) => parent.isLoadingPostFromArchive(id);
	Future<void> loadPostFromArchive(int id) => parent.loadPostFromArchive(id);
	Post? postFromArchive(int id) => parent.postFromArchive(id);
	String? postFromArchiveError(int id) => parent.postFromArchiveError(id);
}

class PostSpanRootZoneData extends PostSpanZoneData {
	final String board;
	List<Post> threadPosts;
	final ImageboardSite site;
	final PersistentThreadState? threadState;
	final ValueChanged<Post>? onNeedScrollToPost;
	final int threadId;
	final Map<int, bool> _isLoadingPostFromArchive = Map();
	final Map<int, Post> _postsFromArchive = Map();
	final Map<int, String> _postFromArchiveErrors = Map();

	PostSpanRootZoneData({
		required this.board,
		required this.threadPosts,
		required this.site,
		this.threadState,
		required this.threadId,
		this.onNeedScrollToPost
	});

	@override
	Iterable<int> get stackIds => [];

	bool isLoadingPostFromArchive(int id) {
		return _isLoadingPostFromArchive[id] ?? false;
	}

	Future<void> loadPostFromArchive(int id) async {
		try {
			_postFromArchiveErrors.remove(id);
			_isLoadingPostFromArchive[id] = true;
			notifyListeners();
			_postsFromArchive[id] = await site.getPostFromArchive(board, id);
			_postsFromArchive[id]!.replyIds = threadPosts.where((p) => p.span.referencedPostIds(board).contains(id)).map((p) => p.id).toList();
			notifyListeners();
		}
		catch (e, st) {
			print('Error getting post from archive');
			print(e);
			print(st);
			_postFromArchiveErrors[id] = e.toString();
		}
		_isLoadingPostFromArchive[id] = false;
		notifyListeners();
	}

	Post? postFromArchive(int id) {
		return _postsFromArchive[id];
	}

	String? postFromArchiveError(int id) {
		return _postFromArchiveErrors[id];
	}
}

class ExpandingPost extends StatelessWidget {
	final int id;
	ExpandingPost(this.id);
	
	@override
	Widget build(BuildContext context) {
		final zone = context.watch<PostSpanZoneData>();
		Post? post;
		if (zone.threadPosts.where((p) => p.id == id).isNotEmpty) {
			post = zone.threadPosts.firstWhere((p) => p.id == id);
		}
		else {
			post = zone.postFromArchive(id);
		}
		if (post == null) {
			print('Could not find post with ID $id in zone for ${zone.threadId}');
		}
		return Visibility(
			visible: zone.shouldExpandPost(this.id),
			child: MediaQuery(
				data: MediaQueryData(textScaleFactor: 1),
				child: (post == null) ? Container(
					child: Text('Could not find /${zone.board}/$id')
				) : PostRow(
					post: post,
					onThumbnailTap: (attachment) {
						showGallery(
							context: context,
							attachments: [attachment],
							semanticParentIds: zone.stackIds
						);
					}
				)
			)
		);
	}
}