import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/embed.dart';
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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:highlight/highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tuple/tuple.dart';

class PostSpanRenderOptions {
	final GestureRecognizer? recognizer;
	final bool overrideRecognizer;
	final Color? overrideTextColor;
	final bool showCrossThreadLabel;
	final bool addExpandingPosts;
	final TextStyle baseTextStyle;
	final bool showRawSource;
	final bool avoidBuggyClippers;
	final PointerEnterEventListener? onEnter;
	final PointerExitEventListener? onExit;
	final bool ownLine;
	PostSpanRenderOptions({
		this.recognizer,
		this.overrideRecognizer = false,
		this.overrideTextColor,
		this.showCrossThreadLabel = true,
		this.addExpandingPosts = true,
		this.baseTextStyle = const TextStyle(),
		this.showRawSource = false,
		this.avoidBuggyClippers = false,
		this.onEnter,
		this.onExit,
		this.ownLine = false
	});
	GestureRecognizer? get overridingRecognizer => overrideRecognizer ? recognizer : null;

	PostSpanRenderOptions copyWith({
		bool? ownLine
	}) => PostSpanRenderOptions(
		recognizer: recognizer,
		overrideRecognizer: overrideRecognizer,
		overrideTextColor: overrideTextColor,
		showCrossThreadLabel: showCrossThreadLabel,
		addExpandingPosts: addExpandingPosts,
		baseTextStyle: baseTextStyle,
		showRawSource: showRawSource,
		avoidBuggyClippers: avoidBuggyClippers,
		onEnter: onEnter,
		onExit: onExit,
		ownLine: ownLine ?? this.ownLine
	);
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
		final _children = <InlineSpan>[];
		for (int i = 0; i < children.length; i++) {
			if ((i == 0 || children[i - 1] is PostLineBreakSpan) && (i == children.length - 1 || children[i + 1] is PostLineBreakSpan)) {
				_children.add(children[i].build(context, options.copyWith(ownLine: true)));
			}
			else {
				_children.add(children[i].build(context, options));
			}
		}
		return TextSpan(
			children: _children
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
			recognizer: options.recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		);
	}

	@override
	String buildText() {
		return text;
	}
}

class PostLineBreakSpan extends PostTextSpan {
	PostLineBreakSpan() : super('\n');
}

class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	PostQuoteSpan(this.child);

	@override
	InlineSpan build(context, options) {
		return TextSpan(
			children: [child.build(context, options)],
			style: options.baseTextStyle.copyWith(color: options.overrideTextColor ?? context.read<EffectiveSettings>().theme.quoteColor),
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
	Tuple2<InlineSpan, GestureRecognizer> _buildCrossThreadLink(BuildContext context, PostSpanRenderOptions options) {
		String text = '>>';
		if (context.watch<PostSpanZoneData>().thread.board != board) {
			text += '/$board/';
		}
		text += '$postId';
		if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
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
		});
		return Tuple2(TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? CupertinoTheme.of(context).textTheme.actionTextStyle.color,
				decoration: TextDecoration.underline
			),
			recognizer: recognizer
		), recognizer);
	}
	Tuple2<InlineSpan, GestureRecognizer> _buildDeadLink(BuildContext context, PostSpanRenderOptions options) {
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
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (!zone.isLoadingPostFromArchive(postId)) zone.loadPostFromArchive(postId);
		});
		return Tuple2(TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? CupertinoTheme.of(context).textTheme.actionTextStyle.color,
				decoration: TextDecoration.underline
			),
			recognizer: recognizer
		), recognizer);
	}
	Tuple2<InlineSpan, GestureRecognizer> _buildNormalLink(BuildContext context, PostSpanRenderOptions options) {
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
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (!zone.stackIds.contains(postId)) {
				if (!context.read<EffectiveSettings>().supportMouse.value) {
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
		});
		return Tuple2(TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? (expandedImmediatelyAbove ? CupertinoTheme.of(context).textTheme.actionTextStyle.color?.shiftSaturation(-0.3) : CupertinoTheme.of(context).textTheme.actionTextStyle.color),
				decoration: TextDecoration.underline,
				decorationStyle: expandedSomewhereAbove ? TextDecorationStyle.dashed : null
			),
			recognizer: recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		), recognizer);
	}
	Tuple2<InlineSpan, GestureRecognizer> _build(BuildContext context, PostSpanRenderOptions options) {
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
			if (thisPostInThread.isEmpty || zone.shouldExpandPost(postId)) {
				return span;
			}
			else {
				final popup = HoverPopup(
					style: HoverPopupStyle.floating,
					anchor: const Offset(30, -80),
					child: Text.rich(
						span.item1,
						textScaleFactor: 1
					),
					popup: ChangeNotifierProvider.value(
						value: zone,
						child: DecoratedBox(
							decoration: BoxDecoration(
								border: Border.all(color: CupertinoTheme.of(context).primaryColor)
							),
							position: DecorationPosition.foreground,
							child: PostRow(
								post: thisPostInThread.first,
								shrinkWrap: true
							)
						)
					)
				);
				return Tuple2(WidgetSpan(
					child: options.ownLine ? Row(
						children: [
							Expanded(child: popup)
						]
					) : popup
				), span.item2);
			}
		}
	}
	@override
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		final _span = _build(context, options);
		final span = options.ownLine ? TextSpan(
			children: [
				_span.item1,
				WidgetSpan(child: Row())
			],
			recognizer: _span.item2
		) : _span.item1;
		if (options.addExpandingPosts && (threadId == zone.thread.id && board == zone.thread.board)) {
			return TextSpan(
				children: [
					span,
					WidgetSpan(child: ExpandingPost(id: postId))
				]
			);
		}
		else {
			return span;
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
			}),
			onEnter: options.onEnter,
			onExit: options.onExit
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
	bool _initialized = false;

	PostCodeSpan(this.text);

	@override
	build(context, options) {
		if (!_initialized) {
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
			_initialized = true;
		}
		final child = RichText(
			text: TextSpan(
				style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle),
				children: _spans
			),
			softWrap: false
		);
		return WidgetSpan(
			child: Container(
				padding: const EdgeInsets.all(8),
				decoration: const BoxDecoration(
					color: Colors.black,
					borderRadius: BorderRadius.all(Radius.circular(8))
				),
				child: options.avoidBuggyClippers ? child : SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: child
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
		onEnter(_) => zone.showSpoiler(id);
		onExit(_) => zone.hideSpoiler(id);
		return TextSpan(
			children: [child.build(context, PostSpanRenderOptions(
				recognizer: toggleRecognizer,
				overrideRecognizer: !showSpoiler,
				overrideTextColor: showSpoiler ? visibleColor : hiddenColor,
				showCrossThreadLabel: options.showCrossThreadLabel,
				onEnter: onEnter,
				onExit: onExit
			))],
			style: options.baseTextStyle.copyWith(
				backgroundColor: hiddenColor,
				color: showSpoiler ? visibleColor : null
			),
			recognizer: toggleRecognizer,
			onEnter: onEnter,
			onExit: onExit
		);
	}

	@override
	String buildText() {
		return '[spoiler]' + child.buildText() + '[/spoiler]';
	}
}

class PostLinkSpan extends PostSpan {
	final String url;
	PostLinkSpan(this.url);
	@override
	build(context, options) {
		final zone = context.watch<PostSpanZoneData>();
		if (embedPossible(url: url, context: context) && !options.showRawSource) {
			final snapshot = zone.getFutureForComputation(
				id: 'noembed $url',
				work: () => loadEmbedData(
					context: context,
					url: url
				)
			);
			Widget _build(List<Widget> _children) => Padding(
				padding: const EdgeInsets.only(top: 8, bottom: 8),
				child: ClipRRect(
					borderRadius: const BorderRadius.all(Radius.circular(8)),
					child: Container(
						padding: const EdgeInsets.all(8),
						color: CupertinoTheme.of(context).barBackgroundColor,
						child: Row(
							crossAxisAlignment: CrossAxisAlignment.center,
							mainAxisSize: MainAxisSize.min,
							children: _children
						)
					)
				)
			);
			Widget? tapChild;
			if (snapshot.connectionState == ConnectionState.waiting) {
				tapChild = _build([
					const SizedBox(
						width: 75,
						height: 75,
						child: CupertinoActivityIndicator()
					),
					const SizedBox(width: 16),
					Flexible(
						child: Text(url, style: const TextStyle(decoration: TextDecoration.underline))
					),
					const SizedBox(width: 16)
				]);
			}
			String? byline = snapshot.data?.provider;
			if (snapshot.data?.author != null && !(snapshot.data?.title != null && snapshot.data!.title!.contains(snapshot.data!.author!))) {
				byline = byline == null ? snapshot.data?.author : '${snapshot.data?.author} - $byline';
			}
			if (snapshot.data?.thumbnailUrl != null) {
				tapChild = _build([
					ClipRRect(
						borderRadius: const BorderRadius.all(Radius.circular(8)),
						child: ExtendedImage.network(
							snapshot.data!.thumbnailUrl!,
							cache: true,
							width: 75,
							height: 75,
							fit: BoxFit.cover
						)
					),
					const SizedBox(width: 16),
					Flexible(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								if (snapshot.data?.title != null) Text(snapshot.data!.title!),
								if (byline != null) Text(byline, style: const TextStyle(color: Colors.grey))
							]
						)
					),
					const SizedBox(width: 16)
				]);
			}

			if (tapChild != null) {
				onTap() {
					openBrowser(context, Uri.parse(url));
				}
				return WidgetSpan(
					alignment: PlaceholderAlignment.middle,
					child: options.avoidBuggyClippers ? GestureDetector(
						onTap: onTap,
						child: tapChild
					) : CupertinoButton(
						padding: EdgeInsets.zero,
						onPressed: onTap,
						child: tapChild
					)
				);
			}
		}
		return TextSpan(
			text: url,
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			),
			recognizer: TapGestureRecognizer()..onTap = () => openBrowser(context, Uri.parse(url)),
			onEnter: options.onEnter,
			onExit: options.onExit
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
			)),
			onEnter: options.onEnter,
			onExit: options.onExit
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
	bool disposed = false;

	bool shouldExpandPost(int id) => false;
	void toggleExpansionOfPost(int id) => throw UnimplementedError();
	void unExpandAllPosts() => throw UnimplementedError();
	bool isLoadingPostFromArchive(int id) => false;
	Future<void> loadPostFromArchive(int id) => throw UnimplementedError();
	Post? postFromArchive(int id) => null;
	String? postFromArchiveError(int id) => null;
	bool shouldShowSpoiler(int id) => false;
	void showSpoiler(int id) => throw UnimplementedError();
	void hideSpoiler(int id) => throw UnimplementedError();
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
		disposed = true;
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
		if (!_shouldExpandPost[id]!) {
			_children[id]?.unExpandAllPosts();
		}
		notifyListeners();
	}

	@override
	void unExpandAllPosts() {
		_shouldExpandPost.updateAll((key, value) => false);
		for (final child in _children.values) {
			child.unExpandAllPosts();
		}
		notifyListeners();
	}

	@override
	bool shouldShowSpoiler(int id) {
		return _shouldShowSpoiler[id] ?? false;
	}

	@override
	void showSpoiler(int id) {
		_shouldShowSpoiler[id] = true;
		notifyListeners();
	}

	@override
	void hideSpoiler(int id) {
		_shouldShowSpoiler[id] = false;
		notifyListeners();
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
	static final Map<String, AsyncSnapshot> _globalFutures = {};

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
		if (_globalFutures.containsKey(id)) {
			return _globalFutures[id]! as AsyncSnapshot<T>;
		}
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
				_globalFutures[id] = _futures[id]!;
				if (!disposed) {
					notifyListeners();
				}
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
		return zone.shouldExpandPost(id) ? TransformedMediaQuery(
			transformation: (mq) => mq.copyWith(textScaleFactor: 1),
			child: (post == null) ? Center(
				child: Text('Could not find /${zone.thread.board}/$id')
			) : Row(
				children: [
					Flexible(
						child: Padding(
							padding: const EdgeInsets.only(top: 8, bottom: 8),
							child: DecoratedBox(
								decoration: BoxDecoration(
									border: Border.all(color: CupertinoTheme.of(context).primaryColor)
								),
								position: DecorationPosition.foreground,
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
						)
					)
				]
			)
		) : const SizedBox.shrink();
	}
}