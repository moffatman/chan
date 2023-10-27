import 'dart:isolate';
import 'dart:math' as math;

import 'package:chan/main.dart';
import 'package:chan/models/parent_and_child.dart';
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
import 'package:chan/services/theme.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/tex.dart';
import 'package:chan/widgets/thread_spans.dart';
import 'package:chan/widgets/user_info.dart';
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
	final bool imageShareMode;
	final bool revealYourPosts;
	final bool ensureTrailingNewline;
	final bool hiddenWithinSpoiler;
	const PostSpanRenderOptions({
		this.recognizer,
		this.overrideRecognizer = false,
		this.overrideTextColor,
		this.showCrossThreadLabel = true,
		this.addExpandingPosts = false,
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
		this.postInject,
		this.imageShareMode = false,
		this.revealYourPosts = true,
		this.ensureTrailingNewline = false,
		this.hiddenWithinSpoiler = false
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
		bool removePostInject = false,
		bool? ensureTrailingNewline,
		bool? hiddenWithinSpoiler
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
		postInject: removePostInject ? null : (postInject ?? this.postInject),
		imageShareMode: imageShareMode,
		revealYourPosts: revealYourPosts,
		ensureTrailingNewline: ensureTrailingNewline ?? this.ensureTrailingNewline,
		hiddenWithinSpoiler: hiddenWithinSpoiler ?? this.hiddenWithinSpoiler
	);
}

@immutable
abstract class PostSpan {
	const PostSpan();
	Iterable<int> referencedPostIds(String forBoard) => const Iterable.empty();
	Iterable<PostIdentifier> get referencedPostIdentifiers => const Iterable.empty();
	InlineSpan build(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options);
	String buildText();
	double estimateLines(double charactersPerLine) => buildText().length / charactersPerLine;
	bool get containsLink => false;
}

class _PostWrapperSpan extends PostSpan {
	final InlineSpan span;
	const _PostWrapperSpan(this.span);
	@override
	InlineSpan build(context, zone, settings, theme, options) => span;
	@override
	String buildText() => span.toPlainText();
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
	Iterable<PostIdentifier> get referencedPostIdentifiers sync* {
		for (final child in children) {
			yield* child.referencedPostIdentifiers;
		}
	}

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		PostSpanRenderOptions effectiveOptions = options.copyWith(maxLines: 99999, ensureTrailingNewline: false);
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
				renderChildren.add(effectiveChildren[i].build(context, zone, settings, theme, ownLineOptions));
			}
			else {
				renderChildren.add(effectiveChildren[i].build(context, zone, settings, theme, effectiveOptions));
			}
			if (effectiveChildren[i] is PostLineBreakSpan) {
				lines += lineGuess.ceil();
				lineGuess = 0;
			}
			else {
				lineGuess += effectiveChildren[i].buildText().length / options.charactersPerLine;
			}
		}
		if (lineGuess != 0 && options.ensureTrailingNewline) {
			renderChildren.add(const TextSpan(text: '\n'));
		}
		return TextSpan(
			children: renderChildren
		);
	}

	Widget buildWidget(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options, {Widget? preInjectRow, InlineSpan? postInject}) {
		final rows = <List<InlineSpan>>[[]];
		int lines = preInjectRow != null ? 2 : 1;
		for (int i = 0; i < children.length && lines < options.maxLines; i++) {
			if (children[i] is PostLineBreakSpan) {
				rows.add([]);
				lines++;
			}
			else if ((i == 0 || children[i - 1] is PostLineBreakSpan) && (i == children.length - 1 || children[i + 1] is PostLineBreakSpan)) {
				rows.last.add(children[i].build(context, zone, settings, theme, options.copyWith(ownLine: true)));
			}
			else {
				rows.last.add(children[i].build(context, zone, settings, theme, options));
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

	@override
	double estimateLines(double charactersPerLine) {
		double lines = 0;
		double lineGuess = 0;
		for (final child in children) {
			if (child is PostLineBreakSpan) {
				lines += lineGuess.ceil();
				lineGuess = 0;
			}
			else {
				lineGuess += child.estimateLines(charactersPerLine);
			}
		}
		lines += lineGuess.ceil();
		return lines;
	}

	@override
	bool get containsLink => children.any((c) => c.containsLink);
}

class PostTextSpan extends PostSpan {
	final String text;
	const PostTextSpan(this.text);

	@override
	InlineSpan build(context, zone, settings, theme, options) {
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
			style: options.baseTextStyle.copyWith(
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

class PostUnderlinedSpan extends PostSpan {
	final PostSpan child;

	const PostUnderlinedSpan(this.child);

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? options.baseTextStyle.color
			)
		));
	}

	@override
	String buildText() => child.buildText();

	@override
	bool get containsLink => child.containsLink;
}

class PostLineBreakSpan extends PostSpan {
	const PostLineBreakSpan();

	@override
	InlineSpan build(context, zone, settings, theme, options) =>  const TextSpan(text: '\n');

	@override
	String buildText() => '\n';
}

class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	const PostQuoteSpan(this.child);

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.quoteColor)
		));
	}

	@override
	String buildText() {
		return child.buildText();
	}

	@override
	bool get containsLink => child.containsLink;
}

class PostQuoteLinkSpan extends PostSpan {
	final String board;
	final int? threadId;
	final int postId;
	final Key? key;

	const PostQuoteLinkSpan({
		required this.board,
		required int this.threadId,
		required this.postId,
		this.key
	});

	const PostQuoteLinkSpan.dead({
		required this.board,
		required this.postId,
		this.key
	}) : threadId = null;

	@override
	Iterable<int> referencedPostIds(String forBoard) sync* {
		if (forBoard == board) {
			yield postId;
		}
	}

	@override
	Iterable<PostIdentifier> get referencedPostIdentifiers sync* {
		if (threadId != null) {
			yield PostIdentifier(board, threadId!, postId);
		}
	}

	(TextSpan, TapGestureRecognizer) _buildCrossThreadLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options, int actualThreadId) {
		String text = '>>';
		if (zone.board != board) {
			text += zone.imageboard.site.formatBoardName(zone.imageboard.site.persistence.getBoard(board)).replaceFirst(RegExp(r'\/$'), '');
			text += '/';
		}
		text += '$postId';
		if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		final Color color;
		if (actualThreadId != zone.primaryThreadId && zone.findThread(actualThreadId) != null) {
			color = theme.secondaryColor.shiftHue(-20);
		}
		else {
			color = theme.secondaryColor;
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (settings.openCrossThreadLinksInNewTab) {
				final newTabZone = context.read<OpenInNewTabZone?>();
				final imageboardKey = context.read<Imageboard>().key;
				if (newTabZone != null && ImageboardRegistry.instance.getImageboard(imageboardKey) != null) {
					// Checking ImageboardRegistry to rule-out dev board
					newTabZone.onWantOpenThreadInNewTab(imageboardKey, ThreadIdentifier(board, actualThreadId));
					return;
				}
			}
			(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					overridePersistence: context.read<Persistence>(),
					child: ThreadPage(
						thread: ThreadIdentifier(board, actualThreadId),
						initialPostId: postId,
						initiallyUseArchive: threadId == null,
						boardSemanticId: -1
					)
				)
			));
		});
		return (TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? color,
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? color
			),
			recognizer: recognizer
		), recognizer);
	}
  (TextSpan, TapGestureRecognizer) _buildDeadLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options) {
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
		return (TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor
			),
			recognizer: recognizer
		), recognizer);
	}
	(TextSpan, TapGestureRecognizer, bool) _buildNormalLink(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options, int? threadId) {
		String text = '>>$postId';
		Color color = theme.secondaryColor;
		if (postId == threadId) {
			text += ' (OP)';
		}
		if (threadId != zone.primaryThreadId) {
			color = theme.secondaryColor.shiftHue(-20);
			if (zone.findPost(zone.stackIds.last)?.threadId != threadId) {
				text += ' (Old thread)';
			}
		}
		if (threadId != null && (zone.imageboard.persistence.getThreadStateIfExists(ThreadIdentifier(board, threadId))?.youIds.contains(postId) ?? false) && options.revealYourPosts) {
			text += ' (You)';
		}
		final linkedPost = zone.findPost(postId);
		if (linkedPost != null && Filter.of(context).filter(linkedPost)?.type.hide == true && !options.imageShareMode) {
			text += ' (Hidden)';
		}
		final bool expandedImmediatelyAbove = zone.shouldExpandPost(postId) || zone.stackIds.length > 1 && zone.stackIds.elementAt(zone.stackIds.length - 2) == postId;
		final bool expandedSomewhereAbove = expandedImmediatelyAbove || zone.stackIds.contains(postId);
		final stackCount = zone.stackIds.countOf(postId);
		final enableInteraction = switch(zone.style) {
			PostSpanZoneStyle.tree => stackCount <= 1,
			_ => !expandedImmediatelyAbove
		};
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
			if (enableInteraction) {
				if (!settings.supportMouse.value || settings.mouseModeQuoteLinkBehavior == MouseModeQuoteLinkBehavior.popupPostsPage) {
					zone.highlightQuoteLinkId = postId;
					await WeakNavigator.push(context, PostsPage(
						zone: zone.childZoneFor(postId),
						postsIdsToShow: [postId],
						postIdForBackground: zone.stackIds.last,
						clearStack: zone.stackIds.contains(postId)
					));
					//await Future.delayed(const Duration(seconds: 1));
					if (zone.highlightQuoteLinkId == postId) {
						zone.highlightQuoteLinkId = null;
					}
				}
				else if (zone.shouldExpandPost(postId) || settings.mouseModeQuoteLinkBehavior == MouseModeQuoteLinkBehavior.expandInline || zone.onNeedScrollToPost == null) {
					zone.toggleExpansionOfPost(postId);
				}
				else {
					zone.onNeedScrollToPost!(zone.findPost(postId)!);
				}
			}
		});
		return (TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? color.shiftSaturation(expandedImmediatelyAbove ? -0.5 : 0),
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? color.shiftSaturation(expandedImmediatelyAbove ? -0.5 : 0),
				decorationStyle: expandedSomewhereAbove ? TextDecorationStyle.dashed : null
			),
			recognizer: recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		), recognizer, enableInteraction);
	}
	(InlineSpan, TapGestureRecognizer) _build(BuildContext context, PostSpanZoneData zone, EffectiveSettings settings, SavedTheme theme, PostSpanRenderOptions options) {
		int? actualThreadId = threadId;
		if (threadId == null) {
			// Dead links do not know their thread
			final thisPostLoaded = zone.postFromArchive(postId);
			if (thisPostLoaded != null) {
				actualThreadId = thisPostLoaded.threadId;
			}
			else {
				return _buildDeadLink(context, zone, settings, theme, options);
			}
		}

		if (actualThreadId != null && (board != zone.board || zone.findThread(actualThreadId) == null || (actualThreadId != zone.primaryThreadId && actualThreadId == postId))) {
			return _buildCrossThreadLink(context, zone, settings, theme, options, actualThreadId);
		}
		else {
			// Normal link
			final span = _buildNormalLink(context, zone, settings, theme, options, threadId);
			final thisPostInThread = zone.findPost(postId);
			final stackCount = zone.stackIds.countOf(postId);
			final enableInteraction = switch(zone.style) {
				PostSpanZoneStyle.tree => stackCount <= 1,
				_ => stackCount == 0
			};
			if (thisPostInThread == null ||
			    zone.shouldExpandPost(postId) == true ||
					!enableInteraction ||
					options.showRawSource) {
				return (span.$1, span.$2);
			}
			else {
				final popup = HoverPopup(
					style: HoverPopupStyle.floating,
					anchor: const Offset(30, -80),
					alternativeHandler: (HoverPopupPhase phase) {
						if (phase == HoverPopupPhase.start) {
							if (zone.glowOtherPost != null &&
								  (zone.isPostOnscreen?.call(postId) ?? false)) {
								Future.microtask(() {
									zone.highlightQuoteLinkId = postId;
									zone.glowOtherPost?.call(postId, true);
								});
								return true;
							}
							return false;
						}
						else {
							Future.microtask(() {
								zone.glowOtherPost?.call(postId, false);
								if (zone.highlightQuoteLinkId == postId) {
									zone.highlightQuoteLinkId = null;
								}
							});
							return true;
						}
					},
					popup: ChangeNotifierProvider.value(
						value: zone,
						child: DecoratedBox(
							decoration: BoxDecoration(
								border: Border.all(color: theme.primaryColor)
							),
							position: DecorationPosition.foreground,
							child: PostRow(
								post: thisPostInThread,
								shrinkWrap: true
							)
						)
					),
					key: key ?? ValueKey(this),
					child: Text.rich(
						span.$1,
						textScaler: TextScaler.noScaling
					)
				);
				return (WidgetSpan(
					child: IntrinsicHeight(
						child: Builder(
							builder: (context) {
								if (span.$3) {
									zone.registerLineTapTarget('$board/$threadId/$postId', context, span.$2.onTap ?? () {});
								}
								else if (zone.style == PostSpanZoneStyle.tree) {
									zone.registerConditionalLineTapTarget('$board/$threadId/$postId', context, () {
										return zone.isPostOnscreen?.call(postId) != true;
									}, span.$2.onTap ?? () {});
								}
								return TweenAnimationBuilder(
									tween: ColorTween(begin: null, end: zone.highlightQuoteLinkId == postId ? Colors.white54 : Colors.transparent),
									duration: zone.highlightQuoteLinkId != postId ? const Duration(milliseconds: 750) : const Duration(milliseconds: 250),
									curve: Curves.ease,
									builder: (context, c, child) => c == Colors.transparent ? popup : ColorFiltered(
										colorFilter: ColorFilter.mode(c ?? Colors.transparent, BlendMode.srcATop),
										child: popup
									)
								);
							}
						)
					)
				), span.$2);
			}
		}
	}
	@override
	build(context, zone, settings, theme, options) {
		final pair = _build(context, zone, settings, theme, options);
		if (options.showRawSource) {
			return pair.$1;
		}
		final span = TextSpan(
			children: [
				pair.$1
			]
		);
		if (options.addExpandingPosts && (threadId != null && zone.findThread(threadId!) != null && board == zone.board)) {
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
	build(context, zone, settings, theme, options) {
		return TextSpan(
			text: '>>/$board/',
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
				(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
					builder: (ctx) => ImageboardScope(
						imageboardKey: null,
						imageboard: context.read<Imageboard>(),
						overridePersistence: context.read<Persistence>(),
						child: BoardPage(
							initialBoard: context.read<Persistence>().getBoard(board),
							semanticId: -1,
							allowChangingBoard: false
						)
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
	build(context, zone, settings, theme, options) {
		final lineCount = RegExp(r'\n').allMatches(text).length + 1;
		final result = zone.getFutureForComputation(
			id: 'languagedetect ${identityHashCode(text)} ${text.substring(0, math.min(10, text.length - 1))}',
			work: () async {
				final startsWithCapitalLetter = RegExp(r'^[A-Z]');
				if (lineCount < 10 && startsWithCapitalLetter.hasMatch(text)) {
					// Probably just plaintext
					return [TextSpan(text: text)];
				}
				final receivePort = ReceivePort();
				String? language;
				await Isolate.spawn(_detectLanguageIsolate, _DetectLanguageParam(text, receivePort.sendPort));
				language = await receivePort.first as String?;
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
		final lineCountFieldWidth = lineCount.toString().length;
		if (options.showRawSource) {
			return TextSpan(
				children: [
					const TextSpan(text: '[code]'),
					if (result.data != null) ...result.data!
					else TextSpan(text: text),
					const TextSpan(text: '[/code]')
				],
				style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle)
			);
		}
		final content = RichText(
			text: TextSpan(
				style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle),
				children: result.data ?? [
					TextSpan(text: text)
				]
			),
			softWrap: false
		);
		final child = lineCount < 9 ? content : Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			mainAxisSize: MainAxisSize.min,
			children: [
				Container(
					decoration: const BoxDecoration(
						border: Border(right: BorderSide(color: Colors.grey))
					),
					padding: const EdgeInsets.only(right: 8),
					margin: const EdgeInsets.only(right: 8),
					child: RichText(
						text: TextSpan(
							style: GoogleFonts.ibmPlexMono(textStyle: const TextStyle(color: Colors.grey)),
							children: Iterable.generate(lineCount, (i) => TextSpan(text: (i + 1).toString().padLeft(lineCountFieldWidth))).expand((s) => [const TextSpan(text: '\n'), s]).skip(1).toList()
						)
					)
				),
				content
			]
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
	build(context, zone, settings, theme, options) {
		final showSpoiler = options.imageShareMode || options.showRawSource || zone.shouldShowSpoiler(id);
		final toggleRecognizer = TapGestureRecognizer()..onTap = () {
			zone.toggleShowingOfSpoiler(id);
		};
		final hiddenColor = theme.primaryColor;
		final visibleColor = theme.backgroundColor;
		onEnter(_) => zone.showSpoiler(id);
		onExit(_) => zone.hideSpoiler(id);
		return TextSpan(
			children: [child.build(context, zone, settings, theme, options.copyWith(
				recognizer: toggleRecognizer,
				overrideRecognizer: !showSpoiler,
				overrideTextColor: showSpoiler ? visibleColor : hiddenColor,
				showCrossThreadLabel: options.showCrossThreadLabel,
				onEnter: onEnter,
				onExit: onExit,
				hiddenWithinSpoiler: !showSpoiler
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

	@override
	bool get containsLink => child.containsLink;
}

class PostLinkSpan extends PostSpan {
	final String url;
	final String? name;
	const PostLinkSpan(this.url, {this.name});
	@override
	build(context, zone, settings, theme, options) {
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
							color: theme.barColor,
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
							child: CircularProgressIndicator.adaptive()
						),
						center: Flexible(child: Text(url, style: const TextStyle(decoration: TextDecoration.underline), textScaler: TextScaler.noScaling))
					);
				}
				String? byline = snapshot.data?.provider;
				if (snapshot.data?.author != null && !(snapshot.data?.title != null && snapshot.data!.title!.contains(snapshot.data!.author!))) {
					byline = byline == null ? snapshot.data?.author : '${snapshot.data?.author} - $byline';
				}
				if (snapshot.data?.thumbnailWidget != null || snapshot.data?.thumbnailUrl != null) {
					final lines = [
						if (name != null && !url.contains(name!)) name!,
						if (snapshot.data?.title?.isNotEmpty ?? false) snapshot.data!.title!
						else if (name == null || url.contains(name!)) url
					];
					tapChild = buildEmbed(
						left: ClipRRect(
							borderRadius: const BorderRadius.all(Radius.circular(8)),
							child: snapshot.data?.thumbnailWidget ?? ExtendedImage.network(
								snapshot.data!.thumbnailUrl!,
								cache: true,
								width: 75,
								height: 75,
								fit: BoxFit.cover,
								loadStateChanged: (loadstate) {
									if (loadstate.extendedImageLoadState == LoadState.failed) {
										return const Icon(CupertinoIcons.question);
									}
									return null;
								}
							)
						),
						center: Flexible(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									if (lines.length > 1) ...lines.skip(1).map((l) => Text(l, textScaler: TextScaler.noScaling, style: const TextStyle(color: Colors.grey, fontSize: 16))),
									Text(lines.first, textScaler: TextScaler.noScaling),
									if (byline != null) Text(byline, style: const TextStyle(color: Colors.grey, fontSize: 16), textScaler: TextScaler.noScaling)
								]
							)
						),
						right: (cleanedUri != null && settings.hostsToOpenExternally.any((s) => cleanedUri.host.endsWith(s))) ? const Icon(Icons.launch_rounded) : null
					);
				}

				if (tapChild != null) {
					if (options.hiddenWithinSpoiler) {
						tapChild = Visibility(
							maintainSize: true,
							maintainAnimation: true,
							maintainState: true,
							visible: false,
							maintainInteractivity: true,
							child: GestureDetector(
								onTap: options.recognizer?.onTap,
								child: AbsorbPointer(
									child: tapChild
								)
							)
						);
					}
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
		return PostTextSpan(name ?? url).build(context, zone, settings, theme, options.copyWith(
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () => openBrowser(context, Uri.parse(cleanedUrl))),
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			)
		));
	}

	@override
	String buildText() {
		if (name != null) {
			return '[$name]($url)';
		}
		else {
			return url;
		}
	}

	@override
	bool get containsLink => true;
}

class PostCatalogSearchSpan extends PostSpan {
	final String board;
	final String query;
	const PostCatalogSearchSpan({
		required this.board,
		required this.query
	});
	@override
	build(context, zone, settings, theme, options) {
		return TextSpan(
			text: '>>/$board/$query',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: theme.secondaryColor,
				color: theme.secondaryColor
			),
			recognizer: TapGestureRecognizer()..onTap = () => (context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					overridePersistence: context.read<Persistence>(),
					child: BoardPage(
						initialBoard: context.read<Persistence>().getBoard(board),
						initialSearch: query,
						semanticId: -1,
						allowChangingBoard: false
					)
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
	const PostTeXSpan(this.tex);
	@override
	build(context, zone, settings, theme, options) {
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
	build(context, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(
				text: '<img src="$src">'
			);
		}
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
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: color)
		));
	}
	@override
	buildText() => child.buildText();
	@override
	bool get containsLink => child.containsLink;
}

class PostBoldSpan extends PostSpan {
	final PostSpan child;

	const PostBoldSpan(this.child);
	@override
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontWeight: FontWeight.bold)
		));
	}
	@override
	buildText() => child.buildText();
	@override
	bool get containsLink => child.containsLink;
}

class PostItalicSpan extends PostSpan {
	final PostSpan child;

	const PostItalicSpan(this.child);
	@override
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontStyle: FontStyle.italic)
		));
	}
	@override
	buildText() => child.buildText();
	@override
	bool get containsLink => child.containsLink;
}

class PostSuperscriptSpan extends PostSpan {
	final PostSpan child;

	const PostSuperscriptSpan(this.child);
	@override
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontSize: 10)
		));
	}
	@override
	buildText() => child.buildText();
	@override
	bool get containsLink => child.containsLink;
}

class PostStrikethroughSpan extends PostSpan {
	final PostSpan child;

	const PostStrikethroughSpan(this.child);
	@override
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(decoration: TextDecoration.lineThrough, decorationColor: options.overrideTextColor ?? options.baseTextStyle.color)
		));
	}
	@override
	buildText() => child.buildText();
	@override
	bool get containsLink => child.containsLink;
}


class PostPopupSpan extends PostSpan {
	final PostSpan popup;
	final String title;
	const PostPopupSpan({
		required this.popup,
		required this.title
	});
	@override
	build(context, zone, settings, theme, options) {
		return TextSpan(
			text: 'Show $title',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? options.baseTextStyle.color
			),
			recognizer: options.overridingRecognizer ?? TapGestureRecognizer()..onTap = () {
				showAdaptiveModalPopup(
					context: context,
					builder: (context) => AdaptiveActionSheet(
						title: Text(title),
						message: Text.rich(
							popup.build(context, zone, settings, theme, options),
							textAlign: TextAlign.left,
						),
						actions: [
							AdaptiveActionSheetAction(
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
	build(context, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(text: buildText());
		}
		return WidgetSpan(
			child: Table(
				children: rows.map((row) => TableRow(
					children: row.map((col) => TableCell(
						child: Text.rich(
							col.build(context, zone, settings, theme, options),
							textAlign: TextAlign.left,
							textScaler: TextScaler.noScaling
						)
					)).toList()
				)).toList()
			)
		);
	}
	@override
	buildText() => rows.map((r) => r.map((r) => r.buildText()).join(', ')).join('\n');
}

class PostDividerSpan extends PostSpan {
	const PostDividerSpan();
	@override
	build(context, zone, settings, theme, options) => WidgetSpan(
		child: Divider(
			thickness: 1,
			height: 25,
			color: theme.primaryColorWithBrightness(0.2)
		)
	);

	@override
	buildText() => '\n';
}

class PostShiftJISSpan extends PostSpan {
	final String text;

	const PostShiftJISSpan(this.text);

	@override
	build(context, zone, settings, theme, options) {
		final span = TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor,
				fontFamily: 'Submona'
			),
			recognizer: options.recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		);
		if (options.showRawSource) {
			return span;
		}
		final child1 = Text.rich(
			span
		);
		return WidgetSpan(
			child: Padding(
				padding: const EdgeInsets.all(8),
				child: options.avoidBuggyClippers ? child1 : SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: child1
				)
			)
		);
	}

	@override
	buildText() => '[sjis]$text[/sjis]';
}

class PostSpanZone extends StatelessWidget {
	final int postId;
	final WidgetBuilder builder;
	final PostSpanZoneStyle? style;

	const PostSpanZone({
		required this.postId,
		required this.builder,
		this.style,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider<PostSpanZoneData>.value(
			value: context.read<PostSpanZoneData>().childZoneFor(postId, style: style),
			child: Builder(
				builder: builder
			)
		);
	}
}

enum PostSpanZoneStyle {
	linear,
	tree,
	expandedInline
}

abstract class PostSpanZoneData extends ChangeNotifier {
	final Map<(int, PostSpanZoneStyle?, int?), PostSpanZoneData> _children = {};
	String get board;
	int get primaryThreadId;
	ThreadIdentifier get primaryThread => ThreadIdentifier(board, primaryThreadId);
	PersistentThreadState? get primaryThreadState => imageboard.persistence.getThreadStateIfExists(primaryThread);
	Imageboard get imageboard;
	Iterable<int> get stackIds;
	ValueChanged<Post>? get onNeedScrollToPost;
	bool Function(int postId)? get isPostOnscreen;
	void Function(int postId, bool glow)? get glowOtherPost;
	Future<void> Function(List<ParentAndChildIdentifier>)? get onNeedUpdateWithStubItems;
	bool disposed = false;
	List<Comparator<Post>> get postSortingMethods;
	PostSpanZoneStyle get style;

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
		return _shouldShowSpoiler[id] ?? Persistence.settings.alwaysShowSpoilers;
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

	PostSpanZoneData childZoneFor(int postId, {PostSpanZoneStyle? style, int? fakeHoistedRootId}) {
		// Assuming that when a new childZone is requested, there will be some old one to cleanup
		for (final child in _children.values) {
			child._lineTapCallbacks.removeWhere((k, v) => !v.$1.mounted);
			child._conditionalLineTapCallbacks.removeWhere((k, v) => !v.$1.mounted);
		}
		final key = (postId, style, fakeHoistedRootId);
		final existingZone = _children[key];
		if (existingZone != null) {
			return existingZone;
		}
		final newZone = PostSpanChildZoneData(
			parent: this,
			postId: postId,
			style: style,
			fakeHoistedRootId: fakeHoistedRootId
		);
		_children[key] = newZone;
		return newZone;
	}

	PostSpanZoneData hoistFakeRootZoneFor(int fakeHoistedRootId, {PostSpanZoneStyle? style, bool clearStack = false});

	void notifyAllListeners() {
		notifyListeners();
		for (final child in _children.values) {
			child.notifyAllListeners();
		}
	}

	final Map<String, (BuildContext, VoidCallback)> _lineTapCallbacks = {};
	void registerLineTapTarget(String id, BuildContext context, VoidCallback callback) {
		_lineTapCallbacks[id] = (context, callback);
	}
	final Map<String, (BuildContext, bool Function(), VoidCallback)> _conditionalLineTapCallbacks = {};
	void registerConditionalLineTapTarget(String id, BuildContext context, bool Function() condition, VoidCallback callback) {
		_conditionalLineTapCallbacks[id] = (context, condition, callback);
	}

	bool _onTap(Offset position, bool runCallback) {
		for (final pair in _lineTapCallbacks.values) {
			final RenderBox? box;
			try {
				box = pair.$1.findRenderObject() as RenderBox?;
			}
			catch (e) {
				continue;
			}
			if (box != null) {
				final y0 = box.localToGlobal(box.paintBounds.topLeft).dy;
				if (y0 > position.dy) {
					continue;
				}
				final y1 = box.localToGlobal(box.paintBounds.bottomRight).dy;
				if (position.dy < y1) {
					if (runCallback) {
						pair.$2();
					}
					return true;
				}
			}
		}
		for (final pair in _conditionalLineTapCallbacks.values) {
			final RenderBox? box;
			try {
				box = pair.$1.findRenderObject() as RenderBox?;
			}
			catch (e) {
				continue;
			}
			if (box != null) {
				final y0 = box.localToGlobal(box.paintBounds.topLeft).dy;
				if (y0 > position.dy) {
					continue;
				}
				final y1 = box.localToGlobal(box.paintBounds.bottomRight).dy;
				if (position.dy < y1 && pair.$2()) {
					if (runCallback) {
						pair.$3();
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
	Future<void> translatePost(Post post);
	void clearTranslatedPosts([int? postId]);

	Thread? findThread(int threadId);
	Post? findPost(int postId);

	int? _highlightQuoteLinkId;
	int? get highlightQuoteLinkId => _highlightQuoteLinkId;
	set highlightQuoteLinkId(int? value) {
		_highlightQuoteLinkId = value;
		if (!disposed) {
			notifyListeners();
		}
	}

	PostSpanZoneData get _root;
}

class PostSpanChildZoneData extends PostSpanZoneData {
	final int postId;
	final PostSpanZoneData parent;
	final PostSpanZoneStyle? _style;
	final int? fakeHoistedRootId;

	PostSpanChildZoneData({
		required this.parent,
		required this.postId,
		PostSpanZoneStyle? style,
		this.fakeHoistedRootId
	}) : _style = style;

	@override
	String get board => parent.board;

	@override
	int get primaryThreadId => parent.primaryThreadId;

	@override
	Imageboard get imageboard => parent.imageboard;

	@override
	Thread? findThread(int threadId) => parent.findThread(threadId);

	@override
	Post? findPost(int postId) => parent.findPost(postId);

	@override
	ValueChanged<Post>? get onNeedScrollToPost => parent.onNeedScrollToPost;

	@override
	bool Function(int)? get isPostOnscreen => parent.isPostOnscreen;

	@override
	void Function(int, bool)? get glowOtherPost => parent.glowOtherPost;

	@override
	Future<void> Function(List<ParentAndChildIdentifier>)? get onNeedUpdateWithStubItems => parent.onNeedUpdateWithStubItems;

	@override
	Iterable<int> get stackIds {
		if (fakeHoistedRootId != null) {
			return [
				fakeHoistedRootId!,
				...parent.stackIds,
				postId
			];
		}
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
	Future<void> translatePost(Post post) async {
		try {
			final x = parent.translatePost(post);
			notifyListeners();
			await x;
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
	PostSpanZoneStyle get style => _style ?? parent.style;
	@override
	PostSpanZoneData get _root => parent._root;

	@override
	PostSpanZoneData hoistFakeRootZoneFor(int fakeHoistedRootId, {PostSpanZoneStyle? style, bool clearStack = false}) {
		return clearStack ?
			_root.childZoneFor(fakeHoistedRootId, style: style) :
			parent.childZoneFor(postId, fakeHoistedRootId: fakeHoistedRootId, style: style);
	}
}


class PostSpanRootZoneData extends PostSpanZoneData {
	@override
	String board;
	@override
	int primaryThreadId;
	@override
	final Imageboard imageboard;
	@override
	final ValueChanged<Post>? onNeedScrollToPost;
	@override
	final bool Function(int)? isPostOnscreen;
	@override
	final void Function(int, bool)? glowOtherPost;
	@override
	Future<void> Function(List<ParentAndChildIdentifier>)? onNeedUpdateWithStubItems;
	final Map<int, bool> _isLoadingPostFromArchive = {};
	final Map<int, Post> _postsFromArchive = {};
	final Map<int, String> _postFromArchiveErrors = {};
	final Iterable<int> semanticRootIds;
	final Map<int, AsyncSnapshot<Post>> _translatedPostSnapshots = {};
	@override
	List<Comparator<Post>> postSortingMethods;
	@override
	PostSpanZoneStyle style;
	final Map<int, Thread> _threads = {};
	final Map<int, Post> _postLookupTable = {};

	PostSpanRootZoneData({
		required Thread thread,
		required this.imageboard,
		this.onNeedScrollToPost,
		this.isPostOnscreen,
		this.glowOtherPost,
		this.onNeedUpdateWithStubItems,
		this.semanticRootIds = const [],
		this.postSortingMethods = const [],
		required this.style
	}) : board = thread.board, primaryThreadId = thread.id {
		addThread(thread);
	}

	PostSpanRootZoneData.multi({
		required ThreadIdentifier primaryThread,
		required List<Thread> threads,
		required this.imageboard,
		this.onNeedScrollToPost,
		this.isPostOnscreen,
		this.glowOtherPost,
		this.onNeedUpdateWithStubItems,
		this.semanticRootIds = const [],
		this.postSortingMethods = const [],
		required this.style
	}) : board = primaryThread.board, primaryThreadId = primaryThread.id {
		for (final thread in threads) {
			addThread(thread);
		}
	}

	void addThread(Thread thread) {
		assert(thread.board == board);
		if (!_threads.containsKey(thread.id)) {
			final threadState = imageboard.persistence.getThreadStateIfExists(thread.identifier);
			if (threadState != null) {
				_translatedPostSnapshots.addAll({
					for (final p in threadState.translatedPosts.values)
						p.id: AsyncSnapshot.withData(ConnectionState.done, p)
				});
			}
		}
		_threads[thread.id] = thread;
		for (final post in thread.posts) {
			_postLookupTable[post.id] = post;
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
		lightHapticFeedback();
		try {
			_postFromArchiveErrors.remove(id);
			_isLoadingPostFromArchive[id] = true;
			notifyListeners();
			final newPost = _postsFromArchive[id] = await imageboard.site.getPostFromArchive(board, id, interactive: true);
			_postsFromArchive[id]!.replyIds = findThread(newPost.threadId)?.posts.where((p) => p.repliedToIds.contains(id)).map((p) => p.id).toList() ?? [];
			notifyListeners();
		}
		catch (e, st) {
			print('Error getting post from archive');
			print(e);
			print(st);
			_postFromArchiveErrors[id] = e.toStringDio();
		}
		lightHapticFeedback();
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
	Future<void> translatePost(Post post) async {
		_translatedPostSnapshots[post.id] = const AsyncSnapshot.waiting();
		notifyListeners();
		final threadState = imageboard.persistence.getThreadStateIfExists(post.threadIdentifier);
		try {
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
			_translatedPostSnapshots[post.id] = AsyncSnapshot.withData(ConnectionState.done, translatedPost);
			threadState?.translatedPosts[post.id] = translatedPost;
			threadState?.save();
		}
		catch (e, st) {
			_translatedPostSnapshots[post.id] = AsyncSnapshot.withError(ConnectionState.done, e, st);
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

	@override
	PostSpanZoneData hoistFakeRootZoneFor(int fakeHoistedRootId, {PostSpanZoneStyle? style, bool clearStack = false}) {
		return childZoneFor(0, fakeHoistedRootId: fakeHoistedRootId, style: style);
	}

	@override
	Thread? findThread(int threadId) => _threads[threadId];

	@override
	Post? findPost(int postId) => _postLookupTable[postId];

	@override
	PostSpanZoneData get _root => this;
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
		final post = zone.findPost(id) ?? zone.postFromArchive(id);
		return zone.shouldExpandPost(id) ? TransformedMediaQuery(
			transformation: (context, mq) => mq.copyWith(textScaler: TextScaler.noScaling),
			child: (post == null) ? Center(
				child: Text('Could not find /${zone.board}/$id')
			) : Row(
				children: [
					Flexible(
						child: Padding(
							padding: const EdgeInsets.only(top: 8, bottom: 8),
							child: DecoratedBox(
								decoration: BoxDecoration(
									border: Border.all(color: ChanceTheme.primaryColorOf(context))
								),
								position: DecorationPosition.foreground,
								child: PostRow(
									post: post,
									onThumbnailTap: (attachment) {
										showGallery(
											context: context,
											attachments: [attachment],
											semanticParentIds: zone.stackIds,
											heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
										);
									},
									shrinkWrap: true,
									expandedInline: true
								)
							)
						)
					)
				]
			)
		) : const SizedBox.shrink();
	}
}

Iterable<TextSpan> _makeAttachmentInfo({
	required BuildContext context,
	required bool interactive,
	required Post post,
	required EffectiveSettings settings
}) sync* {
	for (final attachment in post.attachments) {
		if (settings.showFilenameOnPosts && attachment.filename.isNotEmpty) {
			final ellipsizedFilename = attachment.ellipsizedFilename;
			if (ellipsizedFilename != null) {
				yield TextSpan(
					text: '$ellipsizedFilename ',
					recognizer: interactive ? (TapGestureRecognizer()..onTap = () {
						alert(context, 'Full filename', attachment.filename);
					}) : null
				);
			}
			else {
				yield TextSpan(text: '${attachment.filename} ');
			}
		}
		if (settings.showFilesizeOnPosts || settings.showFileDimensionsOnPosts) {
			final bracketParts = <String>[];
			if (settings.showFilesizeOnPosts && attachment.sizeInBytes != null) {
				bracketParts.add(formatFilesize(attachment.sizeInBytes!));
			}
			if (settings.showFileDimensionsOnPosts && attachment.width != null && attachment.height != null) {
				bracketParts.add('${attachment.width}x${attachment.height}');
			}
			if (bracketParts.isNotEmpty) {
				yield TextSpan(text: '(${bracketParts.join(', ')}) ');
			}
		}
	}
}

TextSpan buildPostInfoRow({
	required Post post,
	required bool isYourPost,
	bool showSiteIcon = false,
	bool showBoardName = false,
	required EffectiveSettings settings,
	required SavedTheme theme,
	required ImageboardSite site,
	required BuildContext context,
	required PostSpanZoneData zone,
	bool interactive = true,
	bool showPostNumber = true
}) {
	final thread = zone.findThread(post.threadId);
	int repeatingDigits = 1;
	final digits = post.id.toString();
	if (settings.highlightRepeatingDigitsInPostIds && site.explicitIds) {
		for (; repeatingDigits < digits.length; repeatingDigits++) {
			if (digits[digits.length - 1 - repeatingDigits] != digits[digits.length - 1]) {
				break;
			}
		}
	}
	final String postIdNonRepeatingSegment;
	final String? postIdRepeatingSegment;
	if (repeatingDigits > 1) {
		postIdNonRepeatingSegment = digits.substring(0, digits.length - repeatingDigits);
		postIdRepeatingSegment = digits.substring(digits.length - repeatingDigits);
	}
	else {
		postIdNonRepeatingSegment = digits;
		postIdRepeatingSegment = null;
	}
	final isOP = site.supportsUserInfo && post.name == thread?.posts_.tryFirst?.name;
	final combineFlagNames = settings.postDisplayFieldOrder.indexOf(PostDisplayField.countryName) == settings.postDisplayFieldOrder.indexOf(PostDisplayField.flag) + 1;
	return TextSpan(
		style: const TextStyle(fontSize: 16),
		children: [
			if (post.isDeleted) ...[
				TextSpan(
					text: '[Deleted] ',
					style: TextStyle(
						color: theme.secondaryColor,
						fontWeight: FontWeight.w600
					)
				),
			],
			if (post.id == post.threadId && thread?.flair != null && !(thread?.title?.contains(thread.flair?.name ?? '') ?? false)) ...[
				makeFlagSpan(
					flag: thread!.flair!,
					includeTextOnlyContent: true,
					appendLabels: false,
					style: TextStyle(color: theme.primaryColor.withOpacity(0.75))
				),
				const TextSpan(text: ' '),
			],
			if (post.id == post.threadId && thread?.title != null) TextSpan(
				text: '${thread?.title}\n',
				style: TextStyle(fontWeight: FontWeight.w600, color: theme.titleColor, fontSize: 17)
			),
			for (final field in settings.postDisplayFieldOrder)
				if (thread != null && showPostNumber && field == PostDisplayField.postNumber && settings.showPostNumberOnPosts && site.explicitIds) TextSpan(
					text: post.id == post.threadId ? '#1 ' : '#${thread.replyCount - ((thread.posts.length - 1) - (thread.posts.binarySearchFirstIndexWhere((p) => p.id >= post.id) + 1))} ',
					style: TextStyle(color: theme.primaryColor.withOpacity(0.5))
				)
				else if (field == PostDisplayField.ipNumber && settings.showIPNumberOnPosts && post.ipNumber != null) ...[
					WidgetSpan(
						child: Icon(CupertinoIcons.person_fill, color: theme.secondaryColor, size: 15),
						alignment: PlaceholderAlignment.middle
					),
					TextSpan(
						text: '${post.ipNumber} ',
						style: TextStyle(
							color: theme.secondaryColor,
							fontWeight: FontWeight.w600
						)
					)
				]
				else if (field == PostDisplayField.name) ...[
					if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && post.name == site.defaultUsername)) TextSpan(
						text: settings.filterProfanity(post.name) + (isYourPost ? ' (You)' : '') + (isOP ? ' (OP)' : ''),
						style: TextStyle(fontWeight: FontWeight.w600, color: isYourPost ? theme.secondaryColor : (isOP ? theme.quoteColor.shiftHue(-200).shiftSaturation(-0.3) : null)),
						recognizer: (interactive && post.name != zone.imageboard.site.defaultUsername) ? (TapGestureRecognizer()..onTap = () {
							final postIdsToShow = zone.findThread(post.threadId)?.posts.where((p) => p.name == post.name).map((p) => p.id).toList() ?? [];
							if (postIdsToShow.isEmpty) {
								alertError(context, 'Could not find any posts with name "${post.name}". This is likely a problem with Chance...');
							}
							else {
								WeakNavigator.push(context, PostsPage(
									postsIdsToShow: postIdsToShow,
									zone: zone,
									clearStack: true,
									header: (zone.imageboard.site.supportsUserInfo || zone.imageboard.site.supportsSearch(post.board).options.name || zone.imageboard.site.supportsSearch(null).options.name) ? UserInfoPanel(
										username: post.name,
										board: post.board
									) : null
								));
							}
						}) : null
					)
					else if (isYourPost) TextSpan(
						text: '(You)',
						style: TextStyle(fontWeight: FontWeight.w600, color: theme.secondaryColor)
					),
					if (settings.showTripOnPosts && post.trip != null) TextSpan(
						text: '${settings.filterProfanity(post.trip!)} ',
						style: TextStyle(color: isYourPost ? theme.secondaryColor : null)
					)
					else if (settings.showNameOnPosts || isYourPost) const TextSpan(text: ' '),
					if (post.capcode != null) TextSpan(
						text: '## ${post.capcode} ',
						style: TextStyle(fontWeight: FontWeight.w600, color: theme.quoteColor.shiftHue(200).shiftSaturation(-0.3))
					)
				]
				else if (field == PostDisplayField.posterId && post.posterId != null) ...[
					IDSpan(
						id: post.posterId!,
						onPressed: interactive ? () {
							final postIdsToShow = zone.findThread(post.threadId)?.posts.where((p) => p.posterId == post.posterId).map((p) => p.id).toList() ?? [];
							if (postIdsToShow.isEmpty) {
								alertError(context, 'Could not find any posts with ID "${post.posterId}". This is likely a problem with Chance...');
							}
							else {
								WeakNavigator.push(context, PostsPage(
									postsIdsToShow: postIdsToShow,
									zone: zone
								));
							}
						} : null
					),
					const TextSpan(text: ' ')
				]
				else if (field == PostDisplayField.attachmentInfo && post.attachments.isNotEmpty) TextSpan(
					children: _makeAttachmentInfo(
						context: context,
						interactive: interactive,
						post: post,
						settings: settings
					).toList(),
					style: TextStyle(
						color: theme.primaryColorWithBrightness(0.8)
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
					makeFlagSpan(
						flag: post.flag!,
						includeTextOnlyContent: true,
						appendLabels: combineFlagNames && settings.showCountryNameOnPosts,
						style: TextStyle(color: theme.primaryColor.withOpacity(0.75), fontSize: 16)
					),
					const TextSpan(text: ' ')
				]
				else if (field == PostDisplayField.countryName && settings.showCountryNameOnPosts && post.flag != null && !combineFlagNames) TextSpan(
					text: '${post.flag!.name} ',
					style: TextStyle(color: theme.primaryColor.withOpacity(0.75))
				)
				else if (field == PostDisplayField.absoluteTime && settings.showAbsoluteTimeOnPosts) TextSpan(
					text: '${formatTime(post.time)} '
				)
				else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts) TextSpan(
					text: '${formatRelativeTime(post.time)} ago '
				)
				else if (field == PostDisplayField.postId && (site.explicitIds || zone.style != PostSpanZoneStyle.tree)) ...[
					if (showSiteIcon) WidgetSpan(
						alignment: PlaceholderAlignment.middle,
						child: Padding(
							padding: const EdgeInsets.only(right: 4),
							child: ImageboardIcon(
								boardName: post.board
							)
						)
					),
					TextSpan(
						text: '${settings.showNoBeforeIdOnPosts ? 'No. ' : ''}${showBoardName ? '${zone.imageboard.site.formatBoardName(zone.imageboard.site.persistence.getBoard(post.board)).replaceFirst(RegExp(r'\/$'), '')}/' : ''}$postIdNonRepeatingSegment',
						style: TextStyle(
							color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.primaryColor).withOpacity(0.5)
						),
						recognizer: interactive ? (TapGestureRecognizer()..onTap = () {
							context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
						}) : null
					),
					if (postIdRepeatingSegment != null) TextSpan(
						text: postIdRepeatingSegment,
						style: TextStyle(
							color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.secondaryColor)
						),
						recognizer: interactive ? (TapGestureRecognizer()..onTap = () {
							context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
						}) : null
					),
					const TextSpan(text: ' ')
				]
				else if (field == PostDisplayField.lineBreak && settings.showLineBreakInPostInfoRow) const TextSpan(text: '\n'),
			if (site.isReddit) ...[
				WidgetSpan(
					child: Icon(CupertinoIcons.arrow_up, size: 15, color: theme.primaryColorWithBrightness(0.5)),
					alignment: PlaceholderAlignment.middle
				),
				TextSpan(text: '${post.upvotes ?? '—'} ', style: TextStyle(color: theme.primaryColorWithBrightness(0.5)))
			]
		]
	);
}