import 'dart:isolate';

import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/embed.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/tex.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
	final TapGestureRecognizer? recognizer;
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
	final bool shrinkWrap;
	final int maxLines;
	final int charactersPerLine;
	final String? highlightString;
	final InlineSpan? postInject;
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
		this.ownLine = false,
		this.shrinkWrap = false,
		this.maxLines = 999999,
		this.charactersPerLine = 999999,
		this.highlightString,
		this.postInject
	});
	TapGestureRecognizer? get overridingRecognizer => overrideRecognizer ? recognizer : null;

	PostSpanRenderOptions copyWith({
		TapGestureRecognizer? recognizer,
		bool? overrideRecognizer,
		Color? overrideTextColor,
		bool? ownLine,
		TextStyle? baseTextStyle,
		bool? showCrossThreadLabel,
		bool? shrinkWrap,
		bool? addExpandingPosts,
		bool? avoidBuggyClippers,
		PointerEnterEventListener? onEnter,
		PointerExitEventListener? onExit,
		int? maxLines,
		int? charactersPerLine,
		InlineSpan? postInject,
		bool removePostInject = false
	}) => PostSpanRenderOptions(
		recognizer: recognizer ?? this.recognizer,
		overrideRecognizer: overrideRecognizer ?? this.overrideRecognizer,
		overrideTextColor: overrideTextColor ?? this.overrideTextColor,
		showCrossThreadLabel: showCrossThreadLabel ?? this.showCrossThreadLabel,
		addExpandingPosts: addExpandingPosts ?? this.addExpandingPosts,
		baseTextStyle: baseTextStyle ?? this.baseTextStyle,
		showRawSource: showRawSource,
		avoidBuggyClippers: avoidBuggyClippers ?? this.avoidBuggyClippers,
		onEnter: onEnter ?? this.onEnter,
		onExit: onExit ?? this.onExit,
		ownLine: ownLine ?? this.ownLine,
		shrinkWrap: shrinkWrap ?? this.shrinkWrap,
		highlightString: highlightString,
		maxLines: maxLines ?? this.maxLines,
		charactersPerLine: charactersPerLine ?? this.charactersPerLine,
		postInject: removePostInject ? null : (postInject ?? this.postInject)
	);
}

@immutable
abstract class PostSpan {
	const PostSpan();
	Iterable<int> referencedPostIds(String forBoard) => const Iterable.empty();
	InlineSpan build(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options);
	String buildText();
}

class _PostWrapperSpan extends PostSpan {
	final InlineSpan span;
	const _PostWrapperSpan(this.span);
	@override
	InlineSpan build(context, zone, settings, options) => span;
	@override
	String buildText() => '';
}

class PostNodeSpan extends PostSpan {
	final List<PostSpan> children;
	const PostNodeSpan(this.children);

	@override
	Iterable<int> referencedPostIds(String forBoard) sync* {
		for (final child in children) {
			yield* child.referencedPostIds(forBoard);
		}
	}

	@override
	InlineSpan build(context, zone, settings, options) {
		PostSpanRenderOptions effectiveOptions = options.copyWith(maxLines: 99999);
		final renderChildren = <InlineSpan>[];
		List<PostSpan> effectiveChildren = children;
		if (options.postInject != null) {
			effectiveOptions = effectiveOptions.copyWith(removePostInject: true);
			effectiveChildren = children.toList()..add(_PostWrapperSpan(options.postInject!));
		}
		final ownLineOptions = effectiveOptions.copyWith(ownLine: true);
		int lines = 0;
		double lineGuess = 0;
		for (int i = 0; i < effectiveChildren.length && lines < options.maxLines; i++) {
			if ((i == 0 || effectiveChildren[i - 1] is PostLineBreakSpan) && (i == effectiveChildren.length - 1 || effectiveChildren[i + 1] is PostLineBreakSpan)) {
				renderChildren.add(effectiveChildren[i].build(context, zone, settings, ownLineOptions));
			}
			else {
				renderChildren.add(effectiveChildren[i].build(context, zone, settings, effectiveOptions));
			}
			if (effectiveChildren[i] is PostLineBreakSpan) {
				lines += lineGuess.ceil();
				lineGuess = 0;
			}
			else {
				lineGuess += effectiveChildren[i].buildText().length / options.charactersPerLine;
			}
		}
		return TextSpan(
			children: renderChildren
		);
	}

	Widget buildWidget(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options, {Widget? preInjectRow, InlineSpan? postInject}) {
		final rows = <List<InlineSpan>>[[]];
		int lines = preInjectRow != null ? 2 : 1;
		for (int i = 0; i < children.length && lines < options.maxLines; i++) {
			if (children[i] is PostLineBreakSpan) {
				rows.add([]);
				lines++;
			}
			else if ((i == 0 || children[i - 1] is PostLineBreakSpan) && (i == children.length - 1 || children[i + 1] is PostLineBreakSpan)) {
				rows.last.add(children[i].build(context, zone, settings, options.copyWith(ownLine: true)));
			}
			else {
				rows.last.add(children[i].build(context, zone, settings, options));
			}
		}
		if (postInject != null) {
			rows.last.add(postInject);
		}
		if (rows.last.isEmpty) {
			rows.removeLast();
		}
		final widgetRows = <Widget>[
			if (preInjectRow != null) preInjectRow
		];
		for (final row in rows) {
			if (row.isEmpty) {
				widgetRows.add(const Text.rich(TextSpan(text: '')));
			}
			else if (row.length == 1) {
				widgetRows.add(Text.rich(row.first));
			}
			else {
				widgetRows.add(Text.rich(TextSpan(children: row)));
			}
		}
		return Column(
			mainAxisSize: MainAxisSize.min,
			crossAxisAlignment: CrossAxisAlignment.start,
			children: widgetRows
		);
	}

	@override
	String buildText() {
		return children.map((x) => x.buildText()).join('');
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	final bool underlined;
	const PostTextSpan(this.text, {this.underlined = false});

	@override
	InlineSpan build(context, zone, settings, options) {
		final children = <TextSpan>[];
		final str = settings.filterProfanity(text);
		if (options.highlightString != null) {
			final escapedHighlight = options.highlightString!.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m.group(0)}');
			final nonHighlightedParts = str.split(RegExp(escapedHighlight, caseSensitive: false));
			int pos = 0;
			for (int i = 0; i < nonHighlightedParts.length; i++) {
				pos += nonHighlightedParts[i].length;
				children.add(TextSpan(
					text: nonHighlightedParts[i],
					recognizer: options.recognizer
				));
				if ((i + 1) < nonHighlightedParts.length) {
					children.add(TextSpan(
						text: str.substring(pos, pos + options.highlightString!.length),
						style: const TextStyle(
							color: Colors.black,
							backgroundColor: Colors.yellow
						),
						recognizer: options.recognizer
					));
					pos += options.highlightString!.length;
				}
			}
		}
		else {
			children.add(TextSpan(
				text: str,
				recognizer: options.recognizer
			));
		}
		return TextSpan(
			children: children,
			style: underlined ? options.baseTextStyle.copyWith(
				color: options.overrideTextColor,
				decoration: TextDecoration.underline
			) : options.baseTextStyle.copyWith(
				color: options.overrideTextColor
			),
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
	const PostLineBreakSpan() : super('\n');
}

class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	const PostQuoteSpan(this.child);

	@override
	InlineSpan build(context, zone, settings, options) {
		return child.build(context, zone, settings, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: settings.theme.quoteColor)
		));
	}

	@override
	String buildText() {
		return child.buildText();
	}
}

class PostQuoteLinkSpan extends PostSpan {
	final String board;
	final int? initialThreadId;
	final int postId;
	final bool dead;
	const PostQuoteLinkSpan({
		required this.board,
		int? threadId,
		required this.postId,
		required this.dead
	}) : initialThreadId = threadId;

	@override
	Iterable<int> referencedPostIds(String forBoard) sync* {
		if (forBoard == board) {
			yield postId;
		}
	}
	Tuple2<InlineSpan, TapGestureRecognizer> _buildCrossThreadLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options, int threadId) {
		String text = '>>';
		if (zone.thread.board != board) {
			text += '/$board/';
		}
		text += '$postId';
		if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					child: ThreadPage(
						thread: ThreadIdentifier(board, threadId),
						initialPostId: postId,
						initiallyUseArchive: dead,
						boardSemanticId: -1
					)
				),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			));
		});
		return Tuple2(TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? settings.theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: recognizer
		), recognizer);
	}
	Tuple2<InlineSpan, TapGestureRecognizer> _buildDeadLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options) {
		String text = '>>$postId';
		if (zone.postFromArchiveError(postId) != null) {
			text += ' (Error: ${zone.postFromArchiveError(postId)})';
		}
		else if (zone.isLoadingPostFromArchive(postId)) {
			text += ' (Loading...)';
		}
		else {
			text += ' (Dead)';
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (zone.isLoadingPostFromArchive(postId) == false) zone.loadPostFromArchive(postId);
		});
		return Tuple2(TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? settings.theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: recognizer
		), recognizer);
	}
	Tuple2<InlineSpan, TapGestureRecognizer> _buildNormalLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options, int? threadId) {
		String text = '>>$postId';
		if (postId == threadId) {
			text += ' (OP)';
		}
		if (zone.threadState?.youIds.contains(postId) ?? false) {
			text += ' (You)';
		}
		final linkedPost = zone.thread.posts.tryFirstWhere((p) => p.id == postId);
		if (linkedPost != null && Filter.of(context).filter(linkedPost)?.type.hide == true) {
			text += ' (Hidden)';
		}
		final bool expandedImmediatelyAbove = zone.shouldExpandPost(postId) || zone.stackIds.length > 1 && zone.stackIds.elementAt(zone.stackIds.length - 2) == postId;
		final bool expandedSomewhereAbove = expandedImmediatelyAbove || zone.stackIds.contains(postId);
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (!zone.stackIds.contains(postId)) {
				if (!settings.supportMouse.value) {
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
				color: options.overrideTextColor ?? (expandedImmediatelyAbove ? settings.theme.secondaryColor.shiftSaturation(-0.5) : settings.theme.secondaryColor),
				decoration: TextDecoration.underline,
				decorationStyle: expandedSomewhereAbove ? TextDecorationStyle.dashed : null
			),
			recognizer: recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		), recognizer);
	}
	Tuple2<InlineSpan, TapGestureRecognizer> _build(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, PostSpanRenderOptions options) {
		int? threadId = initialThreadId;
		if (dead && initialThreadId == null) {
			// Dead links do not know their thread
			final thisPostLoaded = zone.postFromArchive(postId);
			if (thisPostLoaded != null) {
				threadId = thisPostLoaded.threadId;
			}
			else {
				return _buildDeadLink(context, zone, settings, options);
			}
		}

		if (threadId != null && (board != zone.thread.board || threadId != zone.thread.id)) {
			return _buildCrossThreadLink(context, zone, settings, options, threadId);
		}
		else {
			// Normal link
			final span = _buildNormalLink(context, zone, settings, options, threadId);
			final thisPostInThread = zone.thread.posts.tryFirstWhere((p) => p.id == postId);
			if (thisPostInThread == null || zone.shouldExpandPost(postId) == true) {
				return span;
			}
			else {
				final popup = HoverPopup(
					style: HoverPopupStyle.floating,
					anchor: const Offset(30, -80),
					popup: ChangeNotifierProvider.value(
						value: zone,
						child: DecoratedBox(
							decoration: BoxDecoration(
								border: Border.all(color: settings.theme.primaryColor)
							),
							position: DecorationPosition.foreground,
							child: PostRow(
								post: thisPostInThread,
								shrinkWrap: true
							)
						)
					),
					child: Text.rich(
						span.item1,
						textScaleFactor: 1
					)
				);
				return Tuple2(WidgetSpan(
					child: IntrinsicHeight(
						child: Builder(
							builder: (context) {
								zone.registerLineTapTarget('$board/$threadId/$postId', context, span.item2.onTap ?? () {});
								return popup;
							}
						)
					)
				), span.item2);
			}
		}
	}
	@override
	build(context, zone, settings, options) {
		final pair = _build(context, zone, settings, options);
		final span = TextSpan(
			children: [
				pair.item1
			]
		);
		if (options.addExpandingPosts && (initialThreadId == zone.thread.id && board == zone.thread.board)) {
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
	const PostBoardLink(this.board);
	@override
	build(context, zone, settings, options) {
		return TextSpan(
			text: '>>/$board/',
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? settings.theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
				(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
					builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
						child: BoardPage(
							initialBoard: context.read<Persistence>().getBoard(board),
							semanticId: -1
						)
					),
					showAnimations: context.read<EffectiveSettings>().showAnimations
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

class _DetectLanguageParam {
	final String text;
	final SendPort sendPort;
	const _DetectLanguageParam(this.text, this.sendPort);
}

void _detectLanguageIsolate(_DetectLanguageParam param) {
	final result = highlight.parse(param.text, autoDetection: true);
	param.sendPort.send(result.language);
}

class PostCodeSpan extends PostSpan {
	final String text;

	const PostCodeSpan(this.text);

	@override
	build(context, zone, settings, options) {
		final result = zone.getFutureForComputation(
			id: 'languagedetect $text',
			work: () async {
				final receivePort = ReceivePort();
				String? language;
				if (kDebugMode) {
					language = highlight.parse(text, autoDetection: true).language;
				}
				else {
					await Isolate.spawn(_detectLanguageIsolate, _DetectLanguageParam(text, receivePort.sendPort));
					language = await receivePort.first as String?;
				}
				const theme = atomOneDarkReasonableTheme;
				final nodes = highlight.parse(text.replaceAll('\t', ' ' * 4), language: language ?? 'plaintext').nodes!;
				final List<TextSpan> spans = [];
				List<TextSpan> currentSpans = spans;
				List<List<TextSpan>> stack = [];

				traverse(Node node) {
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
							traverse(n);
							if (n == node.children!.last) {
								currentSpans = stack.isEmpty ? spans : stack.removeLast();
							}
						}
					}
				}

				for (var node in nodes) {
					traverse(node);
				}

				return spans;
			}
		);
		final child = RichText(
			text: TextSpan(
				style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle),
				children: result.data ?? [
					TextSpan(text: text)
				]
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
		return '[code]$text[/code]';
	}
}

class PostSpoilerSpan extends PostSpan {
	final PostSpan child;
	final int id;
	const PostSpoilerSpan(this.child, this.id);
	@override
	build(context, zone, settings, options) {
		final showSpoiler = zone.shouldShowSpoiler(id);
		final toggleRecognizer = TapGestureRecognizer()..onTap = () {
			zone.toggleShowingOfSpoiler(id);
		};
		final hiddenColor = settings.theme.primaryColor;
		final visibleColor = settings.theme.backgroundColor;
		onEnter(_) => zone.showSpoiler(id);
		onExit(_) => zone.hideSpoiler(id);
		return TextSpan(
			children: [child.build(context, zone, settings, options.copyWith(
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
		return '[spoiler]${child.buildText()}[/spoiler]';
	}
}

class PostLinkSpan extends PostSpan {
	final String url;
	final String? name;
	const PostLinkSpan(this.url, {this.name});
	@override
	build(context, zone, settings, options) {
		// Remove trailing bracket or other punctuation
		final cleanedUrl = url.replaceAllMapped(
			RegExp(r'(\.[A-Za-z0-9\-._~]+)[^A-Za-z0-9\-._~\.\/?]+$'),
			(m) => m.group(1)!
		);
		final cleanedUri = Uri.tryParse(cleanedUrl);
		if (!options.showRawSource && settings.useEmbeds) {
			final check = zone.getFutureForComputation(
				id: 'embedcheck $url',
				work: () => embedPossible(
					context: context,
					url: url
				)
			);
			if (check.data == true) {
				final snapshot = zone.getFutureForComputation(
					id: 'noembed $url',
					work: () => loadEmbedData(
						context: context,
						url: url
					)
				);
				Widget buildEmbed({
					required Widget left,
					required Widget center,
					Widget? right
				}) => Padding(
					padding: const EdgeInsets.only(top: 8, bottom: 8),
					child: ClipRRect(
						borderRadius: const BorderRadius.all(Radius.circular(8)),
						child: Container(
							padding: const EdgeInsets.all(8),
							color: settings.theme.barColor,
							child: LayoutBuilder(
								builder: (context, constraints) => constraints.maxWidth < 250 ? Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										Row(
											children: [
												left,
												if (right != null) ...[
													const Spacer(),
													right,
													const SizedBox(width: 8)
												]
											]
										),
										center
									]
								) : Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										left,
										const SizedBox(width: 16),
										center,
										if (right != null) ...[
											const SizedBox(width: 8),
											right,
											const SizedBox(width: 8),
										]
									]
								)
							)
						)
					)
				);
				Widget? tapChild;
				if (snapshot.connectionState == ConnectionState.waiting) {
					tapChild = buildEmbed(
						left: const SizedBox(
							width: 75,
							height: 75,
							child: CupertinoActivityIndicator()
						),
						center: Flexible(child: Text(url, style: const TextStyle(decoration: TextDecoration.underline), textScaleFactor: 1))
					);
				}
				String? byline = snapshot.data?.provider;
				if (snapshot.data?.author != null && !(snapshot.data?.title != null && snapshot.data!.title!.contains(snapshot.data!.author!))) {
					byline = byline == null ? snapshot.data?.author : '${snapshot.data?.author} - $byline';
				}
				if (snapshot.data?.thumbnailWidget != null || snapshot.data?.thumbnailUrl != null) {
					tapChild = buildEmbed(
						left: ClipRRect(
							borderRadius: const BorderRadius.all(Radius.circular(8)),
							child: snapshot.data?.thumbnailWidget ?? ExtendedImage.network(
								snapshot.data!.thumbnailUrl!,
								cache: true,
								width: 75,
								height: 75,
								fit: BoxFit.cover
							)
						),
						center: Flexible(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									if (name != null) Text(name!),
									if (snapshot.data?.title?.isNotEmpty ?? false) Text(snapshot.data!.title!, style: TextStyle(
										color: settings.theme.primaryColor
									), textScaleFactor: 1)
									else if (name == null) Text(url, style: TextStyle(
										color: settings.theme.primaryColor
									), textScaleFactor: 1),
									if (byline != null) Text(byline, style: const TextStyle(color: Colors.grey), textScaleFactor: 1)
								]
							)
						),
						right: (cleanedUri != null && settings.hostsToOpenExternally.any((s) => cleanedUri.host.endsWith(s))) ? const Icon(Icons.launch_rounded) : null
					);
				}

				if (tapChild != null) {
					onTap() {
						openBrowser(context, cleanedUri!);
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
		}
		return TextSpan(
			text: name ?? url,
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () => openBrowser(context, Uri.parse(cleanedUrl))),
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
	const PostCatalogSearchSpan({
		required this.board,
		required this.query
	});
	@override
	build(context, zone, settings, options) {
		return TextSpan(
			text: '>>/$board/$query',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				color: settings.theme.secondaryColor
			),
			recognizer: TapGestureRecognizer()..onTap = () => (context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					child: BoardPage(
						initialBoard: context.read<Persistence>().getBoard(board),
						initialSearch: query,
						semanticId: -1
					)
				),
				showAnimations: context.read<EffectiveSettings>().showAnimations
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
	const PostTeXSpan(this.tex);
	@override
	build(context, zone, settings, options) {
		final child = TexWidget(
			tex: tex,
			color: options.overrideTextColor ?? options.baseTextStyle.color
		);
		return options.showRawSource ? TextSpan(
			text: buildText()
		) : WidgetSpan(
			alignment: PlaceholderAlignment.middle,
			child: options.avoidBuggyClippers ? child : SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				child: child
			)
		);
	}
	@override
	String buildText() => '[math]$tex[/math]';
}

class PostInlineImageSpan extends PostSpan {
	final String src;
	final int width;
	final int height;
	const PostInlineImageSpan({
		required this.src,
		required this.width,
		required this.height
	});
	@override
	build(context, zone, settings, options) {
		return WidgetSpan(
			child: SizedBox(
				width: width.toDouble(),
				height: height.toDouble(),
				child: ExtendedImage.network(
					src,
					cache: true,
					enableLoadState: false
				)
			),
			alignment: PlaceholderAlignment.bottom
		);
	}
	@override
	String buildText() => '';
}

class PostColorSpan extends PostSpan {
	final PostSpan child;
	final Color color;
	
	const PostColorSpan(this.child, this.color);
	@override
	build(context, zone, settings, options) {
		return child.build(context, zone, settings, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: color)
		));
	}
	@override
	buildText() => child.buildText();
}

class PostBoldSpan extends PostSpan {
	final PostSpan child;

	const PostBoldSpan(this.child);
	@override
	build(context, zone, settings, options) {
		return child.build(context, zone, settings, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontWeight: FontWeight.bold)
		));
	}
	@override
	buildText() => child.buildText();
}

class PostItalicSpan extends PostSpan {
	final PostSpan child;

	const PostItalicSpan(this.child);
	@override
	build(context, zone, settings, options) {
		return child.build(context, zone, settings, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontStyle: FontStyle.italic)
		));
	}
	@override
	buildText() => child.buildText();
}

class PostSuperscriptSpan extends PostSpan {
	final PostSpan child;

	const PostSuperscriptSpan(this.child);
	@override
	build(context, zone, settings, options) {
		return child.build(context, zone, settings, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontSize: 10)
		));
	}
	@override
	buildText() => child.buildText();
}


class PostPopupSpan extends PostSpan {
	final PostSpan popup;
	final String title;
	const PostPopupSpan({
		required this.popup,
		required this.title
	});
	@override
	build(context, zone, settings, options) {
		return TextSpan(
			text: 'Show $title',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? TapGestureRecognizer()..onTap = () {
				showCupertinoModalPopup(
					context: context,
					barrierDismissible: true,
					builder: (context) => CupertinoActionSheet(
						title: Text(title),
						message: Text.rich(
							popup.build(context, zone, settings, options),
							textAlign: TextAlign.left,
						),
						actions: [
							CupertinoActionSheetAction(
								child: const Text('Close'),
								onPressed: () {
									Navigator.of(context).pop(true);
								}
							)
						]
					)
				);
			}
		);
	}

	@override
	buildText() => '$title\n${popup.buildText()}';
}

class PostTableSpan extends PostSpan {
	final List<List<PostSpan>> rows;
	const PostTableSpan(this.rows);
	@override
	build(context, zone, settings, options) {
		return WidgetSpan(
			child: Table(
				children: rows.map((row) => TableRow(
					children: row.map((col) => TableCell(
						child: Text.rich(
							col.build(context, zone, settings, options),
							textAlign: TextAlign.left,
							textScaleFactor: 1
						)
					)).toList()
				)).toList()
			)
		);
	}
	@override
	buildText() => rows.map((r) => r.join(', ')).join('\n');
}

class PostDividerSpan extends PostSpan {
	const PostDividerSpan();
	@override
	build(context, zone, settings, options) => WidgetSpan(
		child: Divider(
			thickness: 1,
			height: 25,
			color: settings.theme.primaryColorWithBrightness(0.2)
		)
	);

	@override
	buildText() => '\n';
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
	List<Comparator<Post>> get postSortingMethods;
	bool get tree;

	final Map<int, bool> _shouldExpandPost = {};
	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}
	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		if (!_shouldExpandPost[id]!) {
			_children[id]?.unExpandAllPosts();
		}
		notifyListeners();
	}
	void unExpandAllPosts() => throw UnimplementedError();
	bool isLoadingPostFromArchive(int id) => false;
	Future<void> loadPostFromArchive(int id) => throw UnimplementedError();
	Post? postFromArchive(int id) => null;
	String? postFromArchiveError(int id) => null;
	final Map<int, bool> _shouldShowSpoiler = {};
	bool shouldShowSpoiler(int id) {
		return _shouldShowSpoiler[id] ?? false;
	}
	void showSpoiler(int id) {
		_shouldShowSpoiler[id] = true;
		notifyListeners();
	}
	void hideSpoiler(int id) {
		_shouldShowSpoiler[id] = false;
		notifyListeners();
	}
	void toggleShowingOfSpoiler(int id) {
		_shouldShowSpoiler[id] = !shouldShowSpoiler(id);
		notifyListeners();
	}

	final Map<String, AsyncSnapshot> _futures = {};
	static final Map<String, AsyncSnapshot> _globalFutures = {};
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

	PostSpanZoneData childZoneFor(int postId) {
		if (!_children.containsKey(postId)) {
			_children[postId] = PostSpanChildZoneData(
				parent: this,
				postId: postId
			);
		}
		return _children[postId]!;
	}

	void notifyAllListeners() {
		notifyListeners();
		for (final child in _children.values) {
			child.notifyAllListeners();
		}
	}

	final Map<String, Tuple2<BuildContext, VoidCallback>> _lineTapCallbacks = {};
	void registerLineTapTarget(String id, BuildContext context, VoidCallback callback) {
		_lineTapCallbacks[id] = Tuple2(context, callback);
	}

	bool _onTap(Offset position, bool runCallback) {
		for (final pair in _lineTapCallbacks.values) {
			final box = pair.item1.findRenderObject() as RenderBox?;
			if (box != null) {
				final y0 = box.localToGlobal(box.paintBounds.topLeft).dy;
				if (y0 > position.dy) {
					continue;
				}
				final y1 = box.localToGlobal(box.paintBounds.bottomRight).dy;
				if (position.dy < y1) {
					if (runCallback) {
						pair.item2();
					}
					return true;
				}
			}
		}
		return false;
	}

	bool onTap(Offset position) => _onTap(position, true);

	bool canTap(Offset position) => _onTap(position, false);

	@override
	void dispose() {
		for (final zone in _children.values) {
			zone.dispose();	
		}
		super.dispose();
		disposed = true;
	}

	AsyncSnapshot<Post>? translatedPost(int postId);
	Future<void> translatePost(int postId);
	void clearTranslatedPosts([int? postId]);
}

class PostSpanChildZoneData extends PostSpanZoneData {
	final int postId;
	final PostSpanZoneData parent;

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
	void unExpandAllPosts() {
		_shouldExpandPost.updateAll((key, value) => false);
		for (final child in _children.values) {
			child.unExpandAllPosts();
		}
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
	AsyncSnapshot<Post>? translatedPost(int postId) => parent.translatedPost(postId);
	@override
	Future<void> translatePost(int postId) async {
		try {
			await parent.translatePost(postId);
		}
		finally {
			notifyListeners();
		}
	}
	@override
	void clearTranslatedPosts([int? postId]) {
		parent.clearTranslatedPosts(postId);
		notifyListeners();
	}
	@override
	List<Comparator<Post>> get postSortingMethods => parent.postSortingMethods;
	@override
	bool get tree => parent.tree;
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
	final Map<int, AsyncSnapshot<Post>> _translatedPostSnapshots = {};
	@override
	List<Comparator<Post>> postSortingMethods;
	@override
	bool tree;

	PostSpanRootZoneData({
		required this.thread,
		required this.site,
		this.threadState,
		this.onNeedScrollToPost,
		this.semanticRootIds = const [],
		this.postSortingMethods = const [],
		this.tree = false
	}) {
		if (threadState != null) {
			_translatedPostSnapshots.addAll({
				for (final p in threadState!.translatedPosts.values)
					p.id: AsyncSnapshot.withData(ConnectionState.done, p)
			});
		}
	}

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
			_postsFromArchive[id]!.replyIds = thread.posts.where((p) => p.repliedToIds.contains(id)).map((p) => p.id).toList();
			notifyListeners();
		}
		catch (e, st) {
			print('Error getting post from archive');
			print(e);
			print(st);
			_postFromArchiveErrors[id] = e.toStringDio();
		}
		_isLoadingPostFromArchive[id] = false;
		notifyAllListeners();
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
	AsyncSnapshot<Post>? translatedPost(int postId) => _translatedPostSnapshots[postId];
	@override
	Future<void> translatePost(int postId) async {
		_translatedPostSnapshots[postId] = const AsyncSnapshot.waiting();
		notifyListeners();
		try {
			final post = thread.posts.firstWhere((p) => p.id == postId);
			final translated = await translateHtml(post.text);
			final translatedPost = Post(
				board: post.board,
				text: translated,
				name: post.name,
				time: post.time,
				trip: post.trip,
				threadId: post.threadId,
				id: post.id,
				spanFormat: post.spanFormat,
				flag: post.flag,
				attachments: post.attachments,
				attachmentDeleted: post.attachmentDeleted,
				posterId: post.posterId,
				foolfuukaLinkedPostThreadIds: post.foolfuukaLinkedPostThreadIds,
				passSinceYear: post.passSinceYear,
				capcode: post.capcode
			);
			_translatedPostSnapshots[postId] = AsyncSnapshot.withData(ConnectionState.done, translatedPost);
			threadState?.translatedPosts[postId] = translatedPost;
			threadState?.save();
		}
		catch (e, st) {
			_translatedPostSnapshots[postId] = AsyncSnapshot.withError(ConnectionState.done, e, st);
			rethrow;
		}
		finally {
			notifyListeners();
		}
	}

	@override
	void clearTranslatedPosts([int? postId]) {
		if (postId == null) {
			_translatedPostSnapshots.clear();
		}
		else {
			_translatedPostSnapshots.remove(postId);
		}
		notifyListeners();
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

String _makeAttachmentInfo({
	required Post post,
	required EffectiveSettings settings
}) {
	String text = '';
	for (final attachment in post.attachments) {
		if (settings.showFilenameOnPosts) {
			text += '${attachment.filename} ';
		}
		if (settings.showFilesizeOnPosts || settings.showFileDimensionsOnPosts) {
			text += '(';
			bool firstItemPassed = false;
			if (settings.showFilesizeOnPosts) {
				text += '${((attachment.sizeInBytes ?? 0) / 1024).round()} KB';
				firstItemPassed = true;
			}
			if (settings.showFileDimensionsOnPosts && attachment.width != null && attachment.height != null) {
				if (firstItemPassed) {
					text += ', ';
				}
				text += '${attachment.width}x${attachment.height}';
			}
			text += ') ';
		}
	}
	return text;
}

List<InlineSpan> buildPostInfoRow({
	required Post post,
	required bool isYourPost,
	bool showSiteIcon = false,
	bool showBoardName = false,
	required EffectiveSettings settings,
	required ImageboardSite site,
	required BuildContext context,
	required PostSpanZoneData zone,
	bool interactive = true
}) {
	return [
		for (final field in settings.postDisplayFieldOrder)
			if (field == PostDisplayField.name) ...[
				if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && post.name == site.defaultUsername)) TextSpan(
					text: settings.filterProfanity(post.name) + (isYourPost ? ' (You)' : ''),
					style: TextStyle(fontWeight: FontWeight.w600, color: isYourPost ? settings.theme.secondaryColor : null)
				)
				else if (isYourPost) TextSpan(
					text: '(You)',
					style: TextStyle(fontWeight: FontWeight.w600, color: settings.theme.secondaryColor)
				),
				if (settings.showTripOnPosts && post.trip != null) TextSpan(
					text: '${settings.filterProfanity(post.trip!)} ',
					style: TextStyle(color: isYourPost ? settings.theme.secondaryColor : null)
				)
				else if (settings.showNameOnPosts || isYourPost) const TextSpan(text: ' '),
				if (post.capcode != null) TextSpan(
					text: '## ${post.capcode} ',
					style: TextStyle(fontWeight: FontWeight.w600, color: settings.theme.quoteColor.shiftHue(200).shiftSaturation(-0.3))
				)
			]
			else if (field == PostDisplayField.posterId && post.posterId != null) ...[
				IDSpan(
					id: post.posterId!,
					onPressed: interactive ? () => WeakNavigator.push(context, PostsPage(
						postsIdsToShow: zone.thread.posts.where((p) => p.posterId == post.posterId).map((p) => p.id).toList(),
						zone: zone
					)) : null
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.attachmentInfo && post.attachments.isNotEmpty) TextSpan(
				text: _makeAttachmentInfo(
					post: post,
					settings: settings
				),
				style: TextStyle(
					color: settings.theme.primaryColorWithBrightness(0.8)
				)
			)
			else if (field == PostDisplayField.pass && settings.showPassOnPosts && post.passSinceYear != null) ...[
				PassSinceSpan(
					sinceYear: post.passSinceYear!,
					site: site
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.flag && settings.showFlagOnPosts && post.flag != null) ...[
				FlagSpan(post.flag!),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.countryName && settings.showCountryNameOnPosts && post.flag != null) TextSpan(
				text: '${post.flag!.name} ',
				style: const TextStyle(
					fontStyle: FontStyle.italic
				)
			)
			else if (field == PostDisplayField.absoluteTime && settings.showAbsoluteTimeOnPosts) TextSpan(
				text: '${formatTime(post.time)} '
			)
			else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts) TextSpan(
				text: '${formatRelativeTime(post.time)} ago '
			)
			else if (field == PostDisplayField.postId && (site.explicitIds || !zone.tree)) ...[
				if (showSiteIcon) WidgetSpan(
					alignment: PlaceholderAlignment.middle,
					child: ImageboardIcon(
						boardName: post.board
					)
				),
				TextSpan(
					text: '${showBoardName ? '/${post.board}/' : ''}${post.id} ',
					style: TextStyle(color: settings.theme.primaryColor.withOpacity(0.5)),
					recognizer: interactive ? (TapGestureRecognizer()..onTap = () {
						context.read<GlobalKey<ReplyBoxState>>().currentState?.onTapPostId(post.id);
					}) : null
				)
			],
		if (site.isReddit) ...[
			WidgetSpan(
				child: Icon(CupertinoIcons.arrow_up, size: 16, color: settings.theme.primaryColorWithBrightness(0.5)),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(text: '${post.upvotes ?? '—'} ', style: TextStyle(color: settings.theme.primaryColorWithBrightness(0.5)))
		]
	];
}