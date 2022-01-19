import 'dart:convert';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/tex.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:provider/provider.dart';
import 'package:highlight/highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:google_fonts/google_fonts.dart';

class PostSpanRenderOptions {
	final GestureRecognizer? recognizer;
	final bool overrideRecognizer;
	final Color? overrideTextColor;
	final bool showCrossThreadLabel;
	final bool addExpandingPosts;
	final TextStyle baseTextStyle;
	final bool showRawSource;
	PostSpanRenderOptions({
		this.recognizer,
		this.overrideRecognizer = false,
		this.overrideTextColor,
		this.showCrossThreadLabel = true,
		this.addExpandingPosts = true,
		this.baseTextStyle = const TextStyle(),
		this.showRawSource = false
	});
	GestureRecognizer? get overridingRecognizer => overrideRecognizer ? recognizer : null;
}

abstract class PostSpan {
	List<int> referencedPostIds(String forBoard) {
		return [];
	}
	InlineSpan build(BuildContext context, PostSpanRenderOptions options);
	String buildText();
}

class PostNodeSpan extends PostSpan {
	List<PostSpan> children;
	PostNodeSpan(this.children);

	@override
	List<int> referencedPostIds(String forBoard) {
		return children.expand((child) => child.referencedPostIds(forBoard)).toList();
	}

	@override
	InlineSpan build(context, options) {
		return TextSpan(
			children: children.map((child) => child.build(context, options)).toList()
		);
	}

	@override
	String buildText() {
		return children.map((x) => x.buildText()).join(' ');
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	PostTextSpan(this.text);

	@override
	InlineSpan build(context, options) {
		return TextSpan(
			text: context.read<EffectiveSettings>().filterProfanity(text),
			style: options.baseTextStyle,
			recognizer: options.recognizer
		);
	}

	@override
	String buildText() {
		return text;
	}
}
class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	PostQuoteSpan(this.child);

	@override
	InlineSpan build(context, options) {
		return TextSpan(
			children: [child.build(context, options)],
			style: options.baseTextStyle.copyWith(color: options.overrideTextColor ?? const Color.fromRGBO(120, 153, 34, 1)),
			recognizer: options.recognizer
		);
	}

	@override
	String buildText() {
		return child.buildText();
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
		if (context.watch<PostSpanZoneData>().thread.board != board) {
			text += '/$board/';
		}
		text += '$postId';
		if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		return TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? CupertinoTheme.of(context).textTheme.actionTextStyle.color,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
				(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
					builder: (ctx) => ThreadPage(
						thread: ThreadIdentifier(
							board: board,
							id: threadId!
						),
						initialPostId: postId,
						initiallyUseArchive: dead,
						boardSemanticId: -1
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
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? CupertinoTheme.of(context).textTheme.actionTextStyle.color,
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
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? (expandedImmediatelyAbove ? CupertinoTheme.of(context).textTheme.actionTextStyle.color?.towardsWhite(0.2) : CupertinoTheme.of(context).textTheme.actionTextStyle.color),
				decoration: TextDecoration.underline,
				decorationStyle: expandedSomewhereAbove ? TextDecorationStyle.dashed : null
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
				if (!zone.stackIds.contains(postId)) {
					if (context.read<EffectiveSettings>().useTouchLayout) {
						WeakNavigator.push(context, PostsPage(
								zone: zone.childZoneFor(postId),
								postsIdsToShow: [postId],
								postIdForBackground: zone.stackIds.last,
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

		if (threadId != null && (board != zone.thread.board || threadId != zone.thread.id)) {
			return _buildCrossThreadLink(context, options);
		}
		else {
			// Normal link
			final span = _buildNormalLink(context, options);
			final thisPostInThread = zone.thread.posts.where((p) => p.id == postId);
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
								post: thisPostInThread.first,
								shrinkWrap: true
							)
						)
					)
				);
			}
		}
	}
	@override
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		if (options.addExpandingPosts && (threadId == zone.thread.id && board == zone.thread.board)) {
			return TextSpan(
				children: [
					_build(context, options),
					WidgetSpan(child: ExpandingPost(id: postId))
			]);
		}
		else {
			return _build(context, options);
		}
	}

	@override
	String buildText() {
		return '>>$postId';
	}
}

class PostBoardLink extends PostSpan {
	final String board;
	PostBoardLink(this.board);
	@override
	build(context, options) {
		return TextSpan(
			text: '>>/$board/',
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? CupertinoTheme.of(context).textTheme.actionTextStyle.color,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
				(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
					builder: (ctx) => BoardPage(
						initialBoard: context.read<Persistence>().getBoard(board),
						semanticId: -1
					)
				));
			})
		);
	}

	@override
	String buildText() {
		return '>>/$board/';
	}
}

class PostCodeSpan extends PostSpan {
	final String text;
	final List<TextSpan> _spans = [];

	PostCodeSpan(this.text) {
		const theme = atomOneDarkReasonableTheme;
		final nodes = highlight.parse(text.replaceAll('\t', ' ' * 4), autoDetection: true).nodes!;

		List<TextSpan> currentSpans = _spans;
		List<List<TextSpan>> stack = [];

		_traverse(Node node) {
			if (node.value != null) {
				currentSpans.add(node.className == null
						? TextSpan(text: node.value)
						: TextSpan(text: node.value, style: theme[node.className!]));
			} else if (node.children != null) {
				List<TextSpan> tmp = [];
				currentSpans.add(TextSpan(children: tmp, style: theme[node.className!]));
				stack.add(currentSpans);
				currentSpans = tmp;

				for (final n in node.children!) {
					_traverse(n);
					if (n == node.children!.last) {
						currentSpans = stack.isEmpty ? _spans : stack.removeLast();
					}
				}
			}
		}

		for (var node in nodes) {
			_traverse(node);
		}
	}

	@override
	build(context, options) {
		return WidgetSpan(
			child: Container(
				padding: const EdgeInsets.all(8),
				decoration: const BoxDecoration(
					color: Colors.black,
					borderRadius: BorderRadius.all(Radius.circular(8))
				),
				child: RichText(
					text: TextSpan(
						style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle),
						children: _spans
					)
				)
			)
		);
	}

	@override
	String buildText() {
		return '[code]' + text + '[/code]';
	}
}

class PostSpoilerSpan extends PostSpan {
	final PostSpan child;
	final int id;
	PostSpoilerSpan(this.child, this.id);
	@override
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
			style: options.baseTextStyle.copyWith(
				backgroundColor: hiddenColor,
				color: showSpoiler ? visibleColor : null
			),
			recognizer: toggleRecognizer
		);
	}

	@override
	String buildText() {
		return '[spoiler]' + child.buildText() + '[/spoiler]';
	}
}

class PostLinkSpan extends PostSpan {
	final String url;
	String? title;
	PostLinkSpan(this.url);
	@override
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		final embedPossible = context.watch<EffectiveSettings>().embedRegexes.any((regex) => regex.hasMatch(url));
		if (embedPossible && !options.showRawSource) {
			final snapshot = zone.getFutureForComputation(
				id: 'noembed $url',
				work: () => context.read<ImageboardSite>().client.get('https://noembed.com/embed', queryParameters: {
					'url': url
				})
			);
			String? title;
			String? provider;
			String? author;
			String? thumbnailUrl;
			if (snapshot.data?.data != null) {
				final data = jsonDecode(snapshot.data?.data);
				title = data['title'];
				author = data['author_name'];
				thumbnailUrl = data['thumbnail_url'];
				provider = data['provider_name'];
			}
			String? byline = provider;
			if (author != null && !(title != null && title.contains(author))) {
				byline = byline == null ? author : '$author - $byline';
			}
			if (thumbnailUrl != null) {
				return WidgetSpan(
					alignment: PlaceholderAlignment.middle,
					child: GestureDetector(
						onTap: () => openBrowser(context, Uri.parse(url)),
						child: Padding(
							padding: const EdgeInsets.only(top: 8, bottom: 8),
							child: ClipRRect(
								borderRadius: const BorderRadius.all(Radius.circular(8)),
								child: Container(
									color: CupertinoTheme.of(context).barBackgroundColor,
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.center,
										mainAxisSize: MainAxisSize.min,
										children: [
											ExtendedImage.network(
												thumbnailUrl,
												cache: true,
												width: 75,
												height: 75,
												fit: BoxFit.cover
											),
											const SizedBox(width: 16),
											Flexible(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														if (title != null) Text(title),
														if (byline != null) Text(byline, style: const TextStyle(color: Colors.grey))
													]
												)
											),
											const SizedBox(width: 16)
										]
									)
								)
							)
						)
					)
				);	
			}
		}
		return TextSpan(
			text: url,
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			),
			recognizer: TapGestureRecognizer()..onTap = () => openBrowser(context, Uri.parse(url))
		);
	}

	@override
	String buildText() {
		return url;
	}
}

class PostCatalogSearchSpan extends PostSpan {
	final String board;
	final String query;
	PostCatalogSearchSpan({
		required this.board,
		required this.query
	});
	@override
	build(context, options) {
		return TextSpan(
			text: '>>/$board/$query',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
			),
			recognizer: TapGestureRecognizer()..onTap = () => (context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => BoardPage(
					initialBoard: context.read<Persistence>().getBoard(board),
					initialSearch: query,
					semanticId: -1
				)
			))
		);
	}

	@override
	String buildText() {
		return '>>/$board/$query';
	}
}

class PostTeXSpan extends PostSpan {
	final String tex;
	PostTeXSpan(this.tex);
	@override
	build(context, options) {
		return options.showRawSource ? TextSpan(
			text: buildText()
		) : WidgetSpan(
			alignment: PlaceholderAlignment.middle,
			child: TexWidget(
				tex: tex,
			)
		);
	}
	@override
	String buildText() => '[math]$tex[/math]';
}

class PostSpanZone extends StatelessWidget {
	final int postId;
	final WidgetBuilder builder;

	const PostSpanZone({
		required this.postId,
		required this.builder,
		Key? key
	}) : super(key: key);

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
	final Map<int, PostSpanZoneData> _children = {};
	Thread get thread;
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
	AsyncSnapshot<T> getFutureForComputation<T>({
		required String id,
		required Future<T> Function() work
	}) => throw UnimplementedError();
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
		for (final zone in _children.values) {
			zone.dispose();	
		}
		super.dispose();
	}
}

class PostSpanChildZoneData extends PostSpanZoneData {
	final int postId;
	final Map<int, bool> _shouldExpandPost = {};
	final PostSpanZoneData parent;
	final Map<int, bool> _shouldShowSpoiler = {};

	PostSpanChildZoneData({
		required this.parent,
		required this.postId
	});

	@override
	Thread get thread => parent.thread;

	@override
	ImageboardSite get site => parent.site;

	@override
	PersistentThreadState? get threadState => parent.threadState;

	@override
	ValueChanged<Post>? get onNeedScrollToPost => parent.onNeedScrollToPost;

	@override
	Iterable<int> get stackIds {
		return parent.stackIds.followedBy([postId]);
	}

	@override
	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	@override
	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}

	@override
	bool shouldShowSpoiler(int id) {
		return _shouldShowSpoiler[id] ?? false;
	}

	@override
	void toggleShowingOfSpoiler(int id) {
		_shouldShowSpoiler[id] = !shouldShowSpoiler(id);
		notifyListeners();
	}

	@override
	bool isLoadingPostFromArchive(int id) => parent.isLoadingPostFromArchive(id);
	@override
	Future<void> loadPostFromArchive(int id) => parent.loadPostFromArchive(id);
	@override
	Post? postFromArchive(int id) => parent.postFromArchive(id);
	@override
	String? postFromArchiveError(int id) => parent.postFromArchiveError(id);

	@override
	AsyncSnapshot<T> getFutureForComputation<T>({
		required String id,
		required Future<T> Function() work
	}) => parent.getFutureForComputation(id: id, work: work);
}


class PostSpanRootZoneData extends PostSpanZoneData {
	@override
	Thread thread;
	@override
	final ImageboardSite site;
	@override
	final PersistentThreadState? threadState;
	@override
	final ValueChanged<Post>? onNeedScrollToPost;
	final Map<int, bool> _isLoadingPostFromArchive = {};
	final Map<int, Post> _postsFromArchive = {};
	final Map<int, String> _postFromArchiveErrors = {};
	final Iterable<int> semanticRootIds;
	final Map<String, AsyncSnapshot> _futures = {};

	PostSpanRootZoneData({
		required this.thread,
		required this.site,
		this.threadState,
		this.onNeedScrollToPost,
		this.semanticRootIds = const []
	});

	@override
	Iterable<int> get stackIds => semanticRootIds;

	@override
	bool isLoadingPostFromArchive(int id) {
		return _isLoadingPostFromArchive[id] ?? false;
	}

	@override
	Future<void> loadPostFromArchive(int id) async {
		try {
			_postFromArchiveErrors.remove(id);
			_isLoadingPostFromArchive[id] = true;
			notifyListeners();
			_postsFromArchive[id] = await site.getPostFromArchive(thread.board, id);
			_postsFromArchive[id]!.replyIds = thread.posts.where((p) => p.span.referencedPostIds(thread.board).contains(id)).map((p) => p.id).toList();
			notifyListeners();
		}
		catch (e, st) {
			print('Error getting post from archive');
			print(e);
			print(st);
			_postFromArchiveErrors[id] = e.toStringDio();
		}
		_isLoadingPostFromArchive[id] = false;
		notifyListeners();
	}

	@override
	Post? postFromArchive(int id) {
		return _postsFromArchive[id];
	}

	@override
	String? postFromArchiveError(int id) {
		return _postFromArchiveErrors[id];
	}

	@override
	AsyncSnapshot<T> getFutureForComputation<T>({
		required String id,
		required Future<T> Function() work
	}) {
		if (!_futures.containsKey(id)) {
			_futures[id] = AsyncSnapshot<T>.waiting();
			() async {
				try {
					final data = await work();
					_futures[id] = AsyncSnapshot<T>.withData(ConnectionState.done, data);
				}
				catch (e) {
					_futures[id] = AsyncSnapshot<T>.withError(ConnectionState.done, e);
				}
				notifyListeners();
			}();
		}
		return _futures[id] as AsyncSnapshot<T>;
	}
}

class ExpandingPost extends StatelessWidget {
	final int id;
	const ExpandingPost({
		required this.id,
		Key? key
	}) : super(key: key);
	
	@override
	Widget build(BuildContext context) {
		final zone = context.watch<PostSpanZoneData>();
		final post = zone.thread.posts.tryFirstWhere((p) => p.id == id) ?? zone.postFromArchive(id);
		if (post == null) {
			print('Could not find post with ID $id in zone for ${zone.thread.id}');
		}
		return Visibility(
			visible: zone.shouldExpandPost(id),
			child: MediaQuery(
				data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
				child: (post == null) ? Center(
					child: Text('Could not find /${zone.thread.board}/$id')
				) : Row(
					children: [
						Flexible(
							child: PostRow(
								post: post,
								onThumbnailTap: (attachment) {
									showGallery(
										context: context,
										attachments: [attachment],
										semanticParentIds: zone.stackIds
									);
								},
								shrinkWrap: true
							)
						)
					]
				)
			)
		);
	}
}