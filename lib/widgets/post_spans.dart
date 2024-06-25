import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/intern.dart';
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
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/popup_attachment.dart';
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
import 'package:string_similarity/string_similarity.dart';

class PostSpanRenderOptions {
	final TapGestureRecognizer? recognizer;
	final bool overrideRecognizer;
	final Color? overrideTextColor;
	final bool showCrossThreadLabel;
	final bool addExpandingPosts;
	final TextStyle baseTextStyle;
	final bool showRawSource;
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
	final ValueChanged<Attachment>? onThumbnailTap;
	final bool propagateOnThumbnailTap;
	final void Function(Object?, StackTrace?)? onThumbnailLoadError;
	final bool revealSpoilerImages;
	final bool showEmbeds;
	const PostSpanRenderOptions({
		this.recognizer,
		this.overrideRecognizer = false,
		this.overrideTextColor,
		this.showCrossThreadLabel = true,
		this.addExpandingPosts = false,
		this.baseTextStyle = const TextStyle(),
		this.showRawSource = false,
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
		this.hiddenWithinSpoiler = false,
		this.onThumbnailTap,
		this.propagateOnThumbnailTap = false,
		this.onThumbnailLoadError,
		this.revealSpoilerImages = false,
		this.showEmbeds = true
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
		PointerEnterEventListener? onEnter,
		PointerExitEventListener? onExit,
		int? maxLines,
		int? charactersPerLine,
		InlineSpan? postInject,
		bool removePostInject = false,
		bool? ensureTrailingNewline,
		bool? hiddenWithinSpoiler,
		ValueChanged<Attachment>? onThumbnailTap,
		bool? propagateOnThumbnailTap,
		void Function(Object?, StackTrace?)? onThumbnailLoadError,
		bool? revealSpoilerImages,
		bool? showEmbeds
	}) => PostSpanRenderOptions(
		recognizer: recognizer ?? this.recognizer,
		overrideRecognizer: overrideRecognizer ?? this.overrideRecognizer,
		overrideTextColor: overrideTextColor ?? this.overrideTextColor,
		showCrossThreadLabel: showCrossThreadLabel ?? this.showCrossThreadLabel,
		addExpandingPosts: addExpandingPosts ?? this.addExpandingPosts,
		baseTextStyle: baseTextStyle ?? this.baseTextStyle,
		showRawSource: showRawSource,
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
		hiddenWithinSpoiler: hiddenWithinSpoiler ?? this.hiddenWithinSpoiler,
		onThumbnailTap: onThumbnailTap ?? this.onThumbnailTap,
		propagateOnThumbnailTap: propagateOnThumbnailTap ?? this.propagateOnThumbnailTap,
		onThumbnailLoadError: onThumbnailLoadError ?? this.onThumbnailLoadError,
		revealSpoilerImages: revealSpoilerImages ?? this.revealSpoilerImages,
		showEmbeds: showEmbeds ?? this.showEmbeds
	);
}

@immutable
abstract class PostSpan {
	const PostSpan();
	Iterable<int> referencedPostIds(String forBoard) => const Iterable.empty();
	Iterable<PostIdentifier> get referencedPostIdentifiers => const Iterable.empty();
	InlineSpan build(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options);
	String buildText({bool forQuoteComparison = false});
	double estimateLines(double charactersPerLine) => buildText().length / charactersPerLine;
	Iterable<Attachment> get inlineAttachments;
	bool get containsLink => false;
	@override
	String toString() {
		return '$runtimeType(${buildText()})';
	}
}

class _PostWrapperSpan extends PostSpan {
	final InlineSpan span;
	const _PostWrapperSpan(this.span);
	@override
	InlineSpan build(context, zone, settings, theme, options) => span;
	@override
	String buildText({bool forQuoteComparison = false}) => span.toPlainText();
	@override
	Iterable<Attachment> get inlineAttachments => [];
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
	Iterable<Attachment> get inlineAttachments => children.expand((c) => c.inlineAttachments);

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

	Widget buildWidget(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, {Widget? preInjectRow, InlineSpan? postInject}) {
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
	String buildText({bool forQuoteComparison = false}) {
		return children.map((x) => x.buildText(forQuoteComparison: forQuoteComparison)).join('');
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

	@override
	String toString() => 'PostNodeSpan($children)';
}

class PostAttachmentsSpan extends PostSpan {
	final List<Attachment> attachments;
	const PostAttachmentsSpan(this.attachments);

	@override
	Iterable<Attachment> get inlineAttachments => attachments;

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(text: buildText());
		}
		return WidgetSpan(
			child: Wrap(
				spacing: 16,
				runSpacing: 16,
				children: attachments.map((attachment) {
					final stackIds = zone.stackIds.toList();
					if (stackIds.isNotEmpty) {
						stackIds.removeLast();
					}
					return PopupAttachment(
						attachment: attachment,
						child: CupertinoButton(
							padding: EdgeInsets.zero,
							minSize: 0,
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minHeight: 75
								),
								child: AttachmentThumbnail(
									attachment: attachment,
									revealSpoilers: options.revealSpoilerImages,
									thread: zone.primaryThread,
									onLoadError: options.onThumbnailLoadError,
									hero: TaggedAttachment(
										attachment: attachment,
										semanticParentIds: stackIds
									),
									fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
									shrinkHeight: !settings.squareThumbnails,
									// On the website these are huge (full-width). Put them to a largeish size here.
									width: 250,
									height: 250,
									mayObscure: true,
									showIconInCorner: (
										backgroundColor: theme.backgroundColor,
										borderColor: theme.primaryColorWithBrightness(0.2),
										size: null
									)
								)
							),
							onPressed: () {
								options.onThumbnailTap?.call(attachment);
							}
						)
					);
				}).toList()
			)
		);
	}

	@override
	String buildText({bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Make it look like a SiteXenforo quote (the only use case)
			return '${attachments.map((a) => '[View Attachment ${a.id}](${a.url})').join('')}\n';
		}
		return '${attachments.map((a) => a.url).join(', ')}\n';
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	const PostTextSpan(this.text);

	static final _escapePattern = RegExp(r'[.*+?^${}()|[\]\\]');

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		final children = <TextSpan>[];
		final str = settings.filterProfanity(text);
		if (options.highlightString != null) {
			final escapedHighlight = options.highlightString!.replaceAllMapped(_escapePattern, (m) => '\\${m.group(0)}');
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
	String buildText({bool forQuoteComparison = false}) {
		return text;
	}

	@override
	Iterable<Attachment> get inlineAttachments => [];
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
	String buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);

	@override
	bool get containsLink => child.containsLink;

	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
}

class PostLineBreakSpan extends PostSpan {
	const PostLineBreakSpan();

	@override
	InlineSpan build(context, zone, settings, theme, options) =>  const TextSpan(text: '\n');

	@override
	String buildText({bool forQuoteComparison = false}) => '\n';

	@override
	String toString() => 'PostLineBreakSpan()';

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	const PostQuoteSpan(this.child);

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.quoteColor),
			showEmbeds: false
		));
	}

	@override
	String buildText({bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Nested quotes not used
			return '';
		}
		return child.buildText();
	}

	@override
	bool get containsLink => child.containsLink;

	@override
	Iterable<int> referencedPostIds(String forBoard) => child.referencedPostIds(forBoard);
	@override
	Iterable<PostIdentifier> get referencedPostIdentifiers => child.referencedPostIdentifiers;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;

	@override
	String toString() => 'PostQuoteSpan($child)';
}

class PostPinkQuoteSpan extends PostQuoteSpan {
	const PostPinkQuoteSpan(super.child);

	@override
	InlineSpan build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.quoteColor.shiftHue(-90))
		));
	}

	@override
	String toString() => 'PostPinkQuoteSpan($child)';
}

class PostQuoteLinkSpan extends PostSpan {
	final String board;
	final int? threadId;
	final int postId;
	final Key? key;

	PostQuoteLinkSpan({
		required String board,
		required int this.threadId,
		required this.postId,
		this.key
	}) : board = intern(board);

	PostQuoteLinkSpan.dead({
		required String board,
		required this.postId,
		this.key
	}) : board = intern(board), threadId = null;

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

	(TextSpan, TapGestureRecognizer) _buildCrossThreadLink(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, int actualThreadId) {
		String text = '>>';
		if (zone.board != board) {
			text += '>';
			text += zone.imageboard.site.formatBoardNameWithoutTrailingSlash(board);
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
  (TextSpan, TapGestureRecognizer) _buildDeadLink(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options) {
		final boardPrefix = board == zone.board ? '' : '${zone.imageboard.site.formatBoardNameWithoutTrailingSlash(board)}/';
		String text = '>>$boardPrefix$postId';
		if (zone.postFromArchiveError(board, postId) != null) {
			text += ' (Error: ${zone.postFromArchiveError(board, postId)})';
		}
		else if (zone.isLoadingPostFromArchive(board, postId)) {
			text += ' (Loading...)';
		}
		else {
			text += ' (Dead)';
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () {
			if (zone.isLoadingPostFromArchive(board, postId) == false) zone.loadPostFromArchive(board, postId);
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
	(TextSpan, TapGestureRecognizer, bool) _buildNormalLink(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, int? threadId) {
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
			_ => !expandedImmediatelyAbove ||
			     zone.shouldExpandPost(postId) // Always allow re-collapsing
		};
		final enableUnconditionalInteraction = switch(zone.style) {
			PostSpanZoneStyle.tree => stackCount == 0,
			_ => !expandedImmediatelyAbove
		};
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
			if (enableInteraction) {
				if (!settings.mouseSettings.supportMouse || settings.mouseModeQuoteLinkBehavior == MouseModeQuoteLinkBehavior.popupPostsPage) {
					zone.highlightQuoteLinkId = postId;
					await WeakNavigator.push(context, PostsPage(
						zone: zone.childZoneFor(postId),
						postsIdsToShow: [postId],
						postIdForBackground: zone.stackIds.last,
						onThumbnailTap: options.propagateOnThumbnailTap ? options.onThumbnailTap : null,
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
		), recognizer, enableUnconditionalInteraction);
	}
	(InlineSpan, TapGestureRecognizer) _build(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options) {
		int? actualThreadId = threadId;
		if (threadId == null) {
			// Dead links do not know their thread
			final thisPostLoaded = zone.postFromArchive(board, postId);
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
			final span = _buildNormalLink(context, zone, settings, theme, options, actualThreadId);
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
									zone.registerLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context, span.$2.onTap ?? () {});
								}
								else if (zone.style == PostSpanZoneStyle.tree) {
									zone.registerConditionalLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context, () {
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
	String buildText({bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return '';
		}
		return '>>$postId';
	}

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostQuoteLinkWithContextSpan extends PostSpan {
	final PostQuoteLinkSpan quoteLink;
	final PostQuoteSpan context;

	const PostQuoteLinkWithContextSpan({
		required this.quoteLink,
		required this.context
	});

	@override
	build(context, zone, settings, theme, options) {
		final thePost = zone.findPost(quoteLink.postId);
		final theText = thePost?.span.buildText(forQuoteComparison: true);
		final contextText = this.context.child.buildText(forQuoteComparison: true);
		final similarity = theText?.similarityTo(contextText) ?? 0;
		return TextSpan(
			children: [
				quoteLink.build(context, zone, settings, theme, options),
				const TextSpan(text: '\n'),
				if (similarity < 0.85) ...[
					// Partial quote, include the snippet
					this.context.build(context, zone, settings, theme, options),
					const TextSpan(text: '\n'),
				]
			]
		);
	}

	@override
	String buildText({bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return '';
		}
		return '${quoteLink.buildText()}\n${context.buildText()}';
	}

	@override
	Iterable<int> referencedPostIds(String forBoard) => quoteLink.referencedPostIds(forBoard);

	@override
	Iterable<PostIdentifier> get referencedPostIdentifiers => quoteLink.referencedPostIdentifiers;

	@override
	Iterable<Attachment> get inlineAttachments => context.inlineAttachments;

	@override
	String toString() => 'PostQuoteLinkWithContextSpan($quoteLink, $context)';
}

class PostBoardLinkSpan extends PostSpan {
	final String board;
	PostBoardLinkSpan(String board) : board = intern(board);
	@override
	build(context, zone, settings, theme, options) {
		return TextSpan(
			text: zone.imageboard.site.formatBoardLink(board),
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
	String buildText({bool forQuoteComparison = false}) {
		return '>>/$board/';
	}

	@override
	Iterable<Attachment> get inlineAttachments => [];
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

	static final _newlinePattern = RegExp(r'\n');
	static final _startsWithCapitalLetterPattern = RegExp(r'^[A-Z]');

	@override
	build(context, zone, settings, theme, options) {
		final lineCount = _newlinePattern.allMatches(text).length + 1;
		final result = zone.getFutureForComputation(
			id: 'languagedetect ${identityHashCode(text)} ${text.substring(0, math.min(10, text.length - 1))}',
			work: () async {
				if (lineCount == 1 || lineCount < 10 && _startsWithCapitalLetterPattern.hasMatch(text)) {
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
		final span = TextSpan(
			style: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle),
			children: result.data ?? [
				TextSpan(text: text)
			]
		);
		if (lineCount == 1) {
			return TextSpan(
				children: [span],
				style: const TextStyle(
					backgroundColor: Colors.black,
					color: Colors.white,
					fontSize: 15
				)
			);
		}
		final content = RichText(
			text: span,
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
				child: SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: child
				)
			)
		);
	}

	@override
	String buildText({bool forQuoteComparison = false}) {
		return '[code]$text[/code]';
	}

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostSpoilerSpan extends PostSpan {
	final PostSpan child;
	final int id;
	final bool forceReveal;
	const PostSpoilerSpan(this.child, this.id, {this.forceReveal = false});
	@override
	build(context, zone, settings, theme, options) {
		final showSpoiler = options.imageShareMode || options.showRawSource || zone.shouldShowSpoiler(id) || forceReveal;
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
	String buildText({bool forQuoteComparison = false}) {
		return '[spoiler]${child.buildText(forQuoteComparison: forQuoteComparison)}[/spoiler]';
	}

	@override
	bool get containsLink => child.containsLink;

	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
}

class PostLinkSpan extends PostSpan {
	final String url;
	final String? name;
	final EmbedData? embedData;
	const PostLinkSpan(this.url, {this.name, this.embedData});

	static final _trailingJunkPattern = RegExp(r'(\.[A-Za-z0-9\-._~]+)[^A-Za-z0-9\-._~\.\/?]+$');

	@override
	build(context, zone, settings, theme, options) {
		// Remove trailing bracket or other punctuation
		final cleanedUrl = url.replaceAllMapped(
			_trailingJunkPattern,
			(m) => m.group(1)!
		);
		final cleanedUri = Uri.tryParse(cleanedUrl);
		if (!options.showRawSource && settings.useEmbeds) {
			final AsyncSnapshot<EmbedData?>? snapshot;
			if (embedData != null) {
				snapshot = AsyncSnapshot.withData(ConnectionState.done, embedData);
			}
			else if (options.showEmbeds) {
				final check = zone.getFutureForComputation(
					id: 'embedcheck $url',
					work: () => embedPossible(url)
				);
				if (check.data == true) {
					snapshot = zone.getFutureForComputation(
						id: 'noembed $url',
						work: () => loadEmbedData(url)
					);
				}
				else {
					snapshot = null;
				}
			}
			else {
				snapshot = null;
			}
			if (snapshot != null) {
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
						if (name != null && !url.contains(name!) && (snapshot.data?.title?.contains(name!) != true)) name!,
						if (snapshot.data?.title?.isNotEmpty ?? false) snapshot.data!.title!
						else if (name == null || url.contains(name!)) url
					];
					Widget? tapChildChild = snapshot.data?.thumbnailWidget;
					if (tapChildChild == null) {
						ImageProvider image = ExtendedNetworkImageProvider(
							snapshot.data!.thumbnailUrl!,
							cache: true,
						);
						final FilterQuality filterQuality;
						if (settings.thumbnailPixelation > 0) {
							filterQuality = FilterQuality.none;
							// Aim for consistent "pixel" size, adjust because this thumbnail is constant size
							final numPixels = (settings.thumbnailPixelation * (75 / settings.thumbnailSize)).ceil();
							image = ExtendedResizeImage(
								image,
								maxBytes: null,
								width: numPixels,
								height: numPixels
							);
						}
						else {
							filterQuality = FilterQuality.low;
						}
						tapChildChild = ExtendedImage(
							image: image,
							width: 75,
							height: 75,
							fit: BoxFit.cover,
							filterQuality: filterQuality,
							loadStateChanged: (loadstate) {
								if (loadstate.extendedImageLoadState == LoadState.failed) {
									return const Icon(CupertinoIcons.question);
								}
								return null;
							}
						);
						if (settings.blurThumbnails) {
							// No need for ClipRect, we will ClipRRect below
							tapChildChild = ImageFiltered(
								imageFilter: ui.ImageFilter.blur(
									sigmaX: 7.0,
									sigmaY: 7.0,
									tileMode: TileMode.decal
								),
								child: tapChildChild
							);
						}
					}
					tapChild = buildEmbed(
						left: ClipRRect(
							borderRadius: const BorderRadius.all(Radius.circular(8)),
							child: tapChildChild
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
						child: CupertinoButton(
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
	String buildText({bool forQuoteComparison = false}) {
		if (name != null && !url.endsWith(name!)) {
			return '[$name]($url)';
		}
		else {
			return url;
		}
	}

	@override
	bool get containsLink => true;

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostCatalogSearchSpan extends PostSpan {
	final String board;
	final String query;
	PostCatalogSearchSpan({
		required String board,
		required this.query
	}) : board = intern(board);
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
	String buildText({bool forQuoteComparison = false}) {
		return '>>/$board/$query';
	}

	@override
	Iterable<Attachment> get inlineAttachments => [];
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
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				child: child
			)
		);
	}
	@override
	String buildText({bool forQuoteComparison = false}) => '[math]$tex[/math]';
	@override
	Iterable<Attachment> get inlineAttachments => [];
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
					headers: zone.imageboard.site.getHeaders(Uri.parse(src)),
					cache: true,
					enableLoadState: false
				)
			),
			alignment: PlaceholderAlignment.bottom
		);
	}
	@override
	String buildText({bool forQuoteComparison = false}) => src;
	@override
	Iterable<Attachment> get inlineAttachments => [];
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
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
}

class PostSecondaryColorSpan extends PostSpan {
	final PostSpan child;
	
	const PostSecondaryColorSpan(this.child);
	@override
	build(context, zone, settings, theme, options) {
		return child.build(context, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.secondaryColor)
		));
	}
	@override
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	buildText({bool forQuoteComparison = false}) => child.buildText(forQuoteComparison: forQuoteComparison);
	@override
	bool get containsLink => child.containsLink;
	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	buildText({bool forQuoteComparison = false}) => '$title\n${popup.buildText(forQuoteComparison: forQuoteComparison)}';
	@override
	Iterable<Attachment> get inlineAttachments => popup.inlineAttachments;
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
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				physics: const BouncingScrollPhysics(),
				child: Table(
					defaultColumnWidth: const IntrinsicColumnWidth(flex: null),
					border: TableBorder.all(
						color: theme.primaryColor
					),
					children: rows.map((row) => TableRow(
						children: row.map((col) => TableCell(
							child: Padding(
								padding: const EdgeInsets.all(4),
								child: Text.rich(
									col.build(context, zone, settings, theme, options),
									textAlign: TextAlign.left,
									textScaler: TextScaler.noScaling
								)
							)
						)).toList()
					)).toList()
				)
			)
		);
	}
	@override
	buildText({bool forQuoteComparison = false}) => rows.map((r) => r.map((r) => r.buildText(forQuoteComparison: forQuoteComparison)).join(', ')).join('\n');

	@override
	Iterable<int> referencedPostIds(String forBoard) sync* {
		for (final row in rows) {
			for (final child in row) {
				yield* child.referencedPostIds(forBoard);
			}
		}
	}

	@override
	Iterable<PostIdentifier> get referencedPostIdentifiers sync* {
		for (final row in rows) {
			for (final child in row) {
				yield* child.referencedPostIdentifiers;
			}
		}
	}

	@override
	Iterable<Attachment> get inlineAttachments => rows.expand((r) => r.expand((c) => c.inlineAttachments));
}

class PostDividerSpan extends PostSpan {
	const PostDividerSpan();
	@override
	build(context, zone, settings, theme, options) => const WidgetSpan(
		child: ChanceDivider()
	);

	@override
	buildText({bool forQuoteComparison = false}) => '\n';

	@override
	Iterable<Attachment> get inlineAttachments => [];
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
				child: SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: child1
				)
			)
		);
	}

	@override
	buildText({bool forQuoteComparison = false}) => '[sjis]$text[/sjis]';

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostUserLinkSpan extends PostSpan {
	final String username;

	const PostUserLinkSpan(this.username);

	@override
	build(context, zone, settings, theme, options) {
		return TextSpan(
			text: '/u/${zone.imageboard.site.formatUsername(username)}',
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer()..onTap = () async {
				final postIdsToShow = zone.findThread(zone.primaryThreadId)?.posts.where((p) => p.name == username).map((p) => p.id).toList() ?? [];
				WeakNavigator.push(context, PostsPage(
					postsIdsToShow: postIdsToShow,
					zone: zone,
					onThumbnailTap: options.propagateOnThumbnailTap ? options.onThumbnailTap : null,
					clearStack: true,
					header: (zone.imageboard.site.supportsUserInfo || zone.imageboard.site.supportsSearch(zone.board).options.name || zone.imageboard.site.supportsSearch(null).options.name) ? UserInfoPanel(
						username: username,
						board: zone.board
					) : null
				));
			}),
			onEnter: options.onEnter,
			onExit: options.onExit
		);
	}

	@override
	buildText({bool forQuoteComparison = false}) => '/u/$username';

	@override
	Iterable<Attachment> get inlineAttachments => [];
}

class PostCssSpan extends PostSpan {
	final PostSpan child;
	final String css;

	const PostCssSpan(this.child, this.css);

	@override
	build(context, zone, settings, theme, options) {
		final unrecognizedParts = <String>[];
		TextStyle style = options.baseTextStyle;
		for (final part in css.split(';')) {
			if (part.trim().isEmpty) {
				continue;
			}
			final kv = part.split(':');
			if (kv.length != 2) {
				unrecognizedParts.add(part);
				continue;
			}
			final key = kv[0].trim();
			final value = kv[1].trim();
			if (key == 'background-color' && value.startsWith('#')) {
				style = style.copyWith(backgroundColor: colorToHex(value));
			}
			else if (key == 'color' && value.startsWith('#')) {
				style = style.copyWith(color: colorToHex(value));
			}
			else if (key == 'font-weight' && value == 'bold') {
				style = style.copyWith(fontWeight: FontWeight.bold);
			}
			else if (key == 'font-family') {
				style = style.copyWith(fontFamily: value);
			}
			else if (key == 'animation' || key == 'padding' || key == 'border-radius') {
				// Ignore
			}
			else {
				unrecognizedParts.add(part);
			}
		}

		if (unrecognizedParts.isEmpty) {
			return child.build(context, zone, settings, theme, options.copyWith(
				baseTextStyle: style
			));
		}
		else {
			return TextSpan(
				children: [
					TextSpan(text: '<span style="${unrecognizedParts.join('; ')}">'),
					child.build(context, zone, settings, theme, options.copyWith(
						baseTextStyle: style
					)),
					const TextSpan(text: '</span>')
				]
			);
		}
	}

	@override
	String buildText({bool forQuoteComparison = false}) => '<span style="$css">${child.buildText(forQuoteComparison: forQuoteComparison)}</span>';

	@override
	bool get containsLink => child.containsLink;

	@override
	Iterable<Attachment> get inlineAttachments => child.inlineAttachments;
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
	final Map<(int?, PostSpanZoneStyle?, int?, ValueChanged<Post>?), PostSpanZoneData> _children = {};
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
	bool isLoadingPostFromArchive(String board, int id) => false;
	Future<void> loadPostFromArchive(String board, int id) => throw UnimplementedError();
	Post? postFromArchive(String board, int id) => null;
	String? postFromArchiveError(String board, int id) => null;
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

	PostSpanZoneData childZoneFor(int? postId, {
		PostSpanZoneStyle? style,
		int? fakeHoistedRootId,
		ValueChanged<Post>? onNeedScrollToPost
	}) {
		// Assuming that when a new childZone is requested, there will be some old one to cleanup
		for (final child in _children.values) {
			child._lineTapCallbacks.removeWhere((k, v) => !v.$1.mounted);
			child._conditionalLineTapCallbacks.removeWhere((k, v) => !v.$1.mounted);
		}
		final key = (postId, style, fakeHoistedRootId, onNeedScrollToPost);
		final existingZone = _children[key];
		if (existingZone != null) {
			return existingZone;
		}
		final newZone = _PostSpanChildZoneData(
			parent: this,
			postId: postId,
			style: style,
			fakeHoistedRootId: fakeHoistedRootId,
			onNeedScrollToPost: onNeedScrollToPost
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

class _PostSpanChildZoneData extends PostSpanZoneData {
	final int? postId;
	final PostSpanZoneData parent;
	final PostSpanZoneStyle? _style;
	final int? fakeHoistedRootId;
	final ValueChanged<Post>? _onNeedScrollToPost;

	_PostSpanChildZoneData({
		required this.parent,
		required this.postId,
		PostSpanZoneStyle? style,
		ValueChanged<Post>? onNeedScrollToPost,
		this.fakeHoistedRootId
	}) : _style = style, _onNeedScrollToPost = onNeedScrollToPost;

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
	ValueChanged<Post>? get onNeedScrollToPost => _onNeedScrollToPost ?? parent.onNeedScrollToPost;

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
				if (postId != null) postId!
			];
		}
		if (postId == null) {
			return parent.stackIds;
		}
		return parent.stackIds.followedBy([postId!]);
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
	bool isLoadingPostFromArchive(String board, int id) => parent.isLoadingPostFromArchive(board, id);
	@override
	Future<void> loadPostFromArchive(String board, int id) => parent.loadPostFromArchive(board, id);
	@override
	Post? postFromArchive(String board, int id) => parent.postFromArchive(board, id);
	@override
	String? postFromArchiveError(String board, int id) => parent.postFromArchiveError(board, id);
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
	final Map<(String, int), bool> _isLoadingPostFromArchive = {};
	final Map<(String, int), Post> _postsFromArchive = {};
	final Map<(String, int), String> _postFromArchiveErrors = {};
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
		// Use posts_ to avoid looking repliedToIds. Mainly for catalog here.
		for (final post in thread.posts_) {
			_postLookupTable[post.id] = post;
		}
	}

	@override
	Iterable<int> get stackIds => semanticRootIds;

	@override
	bool isLoadingPostFromArchive(String board, int id) {
		return _isLoadingPostFromArchive[(board, id)] ?? false;
	}

	@override
	Future<void> loadPostFromArchive(String board, int id) async {
		lightHapticFeedback();
		try {
			_postFromArchiveErrors.remove(id);
			_isLoadingPostFromArchive[(board, id)] = true;
			notifyListeners();
			final newPost = _postsFromArchive[(board, id)] = await imageboard.site.getPostFromArchive(board, id, priority: RequestPriority.interactive);
			if (board == this.board) {
				_postsFromArchive[(board, id)]!.replyIds = findThread(newPost.threadId)?.posts.where((p) => p.repliedToIds.contains(id)).map((p) => p.id).toList() ?? [];
			}
			notifyListeners();
		}
		catch (e, st) {
			print('Error getting post from archive');
			print(e);
			print(st);
			_postFromArchiveErrors[(board, id)] = e.toStringDio();
		}
		lightHapticFeedback();
		_isLoadingPostFromArchive[(board, id)] = false;
		notifyAllListeners();
	}

	@override
	Post? postFromArchive(String board, int id) {
		return _postsFromArchive[(board, id)];
	}

	@override
	String? postFromArchiveError(String board, int id) {
		return _postFromArchiveErrors[(board, id)];
	}

	@override
	AsyncSnapshot<Post>? translatedPost(int postId) => _translatedPostSnapshots[postId];
	@override
	Future<void> translatePost(Post post) async {
		_translatedPostSnapshots[post.id] = const AsyncSnapshot.waiting();
		notifyListeners();
		final threadState = imageboard.persistence.getThreadStateIfExists(post.threadIdentifier);
		try {
			final translated = await translateHtml(post.text, toLanguage: Settings.instance.translationTargetLanguage);
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
				attachments_: post.attachments_,
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
		final post = zone.findPost(id) ?? zone.postFromArchive(zone.board,id);
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
											heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
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

typedef _AttachmentMetadata = ({
	String filename,
	int? sizeInBytes,
	int? width,
	int? height
});

extension _EllipsizedFilename on _AttachmentMetadata {
	String? get ellipsizedFilename {
		if (filename.length <= 53) {
			return null;
		}
		return '${filename.substring(0, 25)}...${filename.substring(filename.length - 25)}';
	}
}

Iterable<TextSpan> _makeAttachmentInfo({
	required BuildContext? context,
	required Iterable<_AttachmentMetadata> metadata,
	required Settings settings
}) sync* {
	for (final attachment in metadata) {
		if (settings.showFilenameOnPosts && attachment.filename.isNotEmpty) {
			final ellipsizedFilename = attachment.ellipsizedFilename;
			if (ellipsizedFilename != null && settings.ellipsizeLongFilenamesOnPosts) {
				yield TextSpan(
					text: '$ellipsizedFilename ',
					recognizer: context != null ? (TapGestureRecognizer()..onTap = () {
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

int _calculatePostNumber(ImageboardSite site, Thread thread, Post post) {
	final postsPerPage = site.postsPerPage;
	if (postsPerPage == null) {
		// "Simple" algorithm
		return thread.replyCount - ((thread.posts.length - 1) - (thread.posts.binarySearchFirstIndexWhere((p) => p.id >= post.id) + 1));
	}
	final parentPage = post.parentId;
	if (parentPage == null) {
		return 1; // No idea
	}
	// First find the post in the list
	final postIndex = thread.posts.binarySearchFirstIndexWhere((p) {
		if (p.id.isNegative) {
			// Page
			if (-p.id > -parentPage) {
				// This page comes after our page and therefore our post
				return true;
			}
			else {
				// This page comes before our post
				return false;
			}
		}
		else {
			return p.id >= post.id;
		}
	});
	if (postIndex == -1) {
		return 1; // No idea
	}
	// Then find how far down the post is on the page
	for (int i = postIndex; i >= 0; i--) {
		if (thread.posts[i].id == parentPage) {
			final postOnPageNumber = postIndex - i;
			return (postsPerPage * (-parentPage - 1)) + postOnPageNumber;
		}
	}
	return 1; // No idea
}

(String nonRepeating, String? repeating) splitPostId(int? id, ImageboardSite site) {
	if (id == null) {
		return ('', null);
	}
	int repeatingDigits = 1;
	final digits = id.toString();
	if (Settings.instance.highlightRepeatingDigitsInPostIds && site.explicitIds) {
		for (; repeatingDigits < digits.length; repeatingDigits++) {
			if (digits[digits.length - 1 - repeatingDigits] != digits[digits.length - 1]) {
				break;
			}
		}
	}
	if (repeatingDigits > 1) {
		return (digits.substring(0, digits.length - repeatingDigits), digits.substring(digits.length - repeatingDigits));
	}
	else {
		return (digits, null);
	}
}

TextSpan buildPostInfoRow({
	required Post post,
	required bool isYourPost,
	bool showSiteIcon = false,
	bool showBoardName = false,
	required Settings settings,
	required SavedTheme theme,
	required ImageboardSite site,
	required BuildContext context,
	required PostSpanZoneData zone,
	bool interactive = true,
	bool showPostNumber = true,
	ValueChanged<Attachment>? propagatedOnThumbnailTap
}) {
	final thread = zone.findThread(post.threadId);
	final (postIdNonRepeatingSegment, postIdRepeatingSegment) = splitPostId(post.id, site);
	final op = site.isPaged ? thread?.posts_.tryFirstWhere((p) => !p.isPageStub) : thread?.posts_.tryFirst;
	// During catalog-peek the post == op equality won't hold. Just use simple check.
	final thisPostIsOP = site.isPaged ? post == op : post.id == post.threadId;
	final thisPostIsPostedByOP = site.supportsUserInfo && post.name == op?.name;
	final combineFlagNames = settings.postDisplayFieldOrder.indexOf(PostDisplayField.countryName) == settings.postDisplayFieldOrder.indexOf(PostDisplayField.flag) + 1;
	const lineBreak = TextSpan(text: '\n');
	final children = [
		if (post.isDeleted) ...[
			TextSpan(
				text: '[Deleted] ',
				style: TextStyle(
					color: theme.secondaryColor,
					fontWeight: FontWeight.w600
				)
			),
		],
		if (thisPostIsOP && thread?.flair != null && !(thread?.title?.contains(thread.flair?.name ?? '') ?? false)) ...[
			makeFlagSpan(
				context: context,
				zone: zone,
				flag: thread!.flair!,
				includeTextOnlyContent: true,
				appendLabels: false,
				style: TextStyle(color: theme.primaryColor.withOpacity(0.75))
			),
			const TextSpan(text: ' '),
		],
		if (thisPostIsOP && thread?.title != null) TextSpan(
			text: '${thread?.title}\n',
			style: TextStyle(fontWeight: FontWeight.w600, color: theme.titleColor, fontSize: 17)
		),
		for (final field in settings.postDisplayFieldOrder)
			if (thread != null && showPostNumber && field == PostDisplayField.postNumber && settings.showPostNumberOnPosts && site.explicitIds) TextSpan(
				text: post.id == post.threadId ? '#1 ' : '#${_calculatePostNumber(site, thread, post)} ',
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
				if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && post.name == site.defaultUsername && post.trip == null)) TextSpan(
					text: settings.filterProfanity(site.formatUsername(post.name)) + ((isYourPost && post.trip == null) ? ' (You)' : '') + (thisPostIsPostedByOP ? ' (OP)' : ''),
					style: TextStyle(fontWeight: FontWeight.w600, color: isYourPost ? theme.secondaryColor : (thisPostIsPostedByOP ? theme.quoteColor.shiftHue(-200).shiftSaturation(-0.3) : null)),
					recognizer: (interactive && post.name != zone.imageboard.site.defaultUsername) ? (TapGestureRecognizer()..onTap = () {
						final postIdsToShow = zone.findThread(post.threadId)?.posts.where((p) => p.name == post.name).map((p) => p.id).toList() ?? [];
						if (postIdsToShow.isEmpty) {
							alertError(context, 'Could not find any posts with name "${site.formatUsername(post.name)}". This is likely a problem with Chance...');
						}
						else {
							WeakNavigator.push(context, PostsPage(
								postsIdsToShow: postIdsToShow,
								zone: zone,
								onThumbnailTap: propagatedOnThumbnailTap,
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
								onThumbnailTap: propagatedOnThumbnailTap,
								zone: zone
							));
						}
					} : null
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.attachmentInfo && post.attachments.isNotEmpty) TextSpan(
				children: _makeAttachmentInfo(
					context: interactive ? context : null,
					metadata: post.attachments.map((a) => (
						filename: a.filename,
						sizeInBytes: a.sizeInBytes,
						width: a.width,
						height: a.height
					)),
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
					context: context,
					zone: zone,
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
					text: '${settings.showNoBeforeIdOnPosts ? 'No. ' : ''}${showBoardName ? '${zone.imageboard.site.formatBoardNameWithoutTrailingSlash(post.board)}/' : ''}$postIdNonRepeatingSegment',
					style: TextStyle(
						color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.primaryColor).withOpacity(0.5)
					),
					recognizer: (interactive && settings.tapPostIdToReply) ? (TapGestureRecognizer()..onTap = () {
						context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
					}) : null
				),
				if (postIdRepeatingSegment != null) TextSpan(
					text: postIdRepeatingSegment,
					style: TextStyle(
						color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.secondaryColor)
					),
					recognizer: (interactive && settings.tapPostIdToReply) ? (TapGestureRecognizer()..onTap = () {
						context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
					}) : null
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.lineBreak && settings.showLineBreakInPostInfoRow) lineBreak,
	];
	if (children.last == lineBreak &&
	    settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak) {
		// "Optional line-break" use case
		// The line-break is positioned before some optional fields
		// If the optional fields aren't there, get rid of the blank line by removing
		// the line break.
		children.removeLast();
	}
	if (site.supportsPostUpvotes) {
		children.addAll([
			WidgetSpan(
				child: Icon(CupertinoIcons.arrow_up, size: 15, color: theme.primaryColorWithBrightness(0.5)),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(text: '${post.upvotes ?? '—'} ', style: TextStyle(color: theme.primaryColorWithBrightness(0.5)))
		]);
	}
	return TextSpan(
		style: const TextStyle(fontSize: 16),
		children: children
	);
}

TextSpan buildDraftInfoRow({
	required DraftPost post,
	required Settings settings,
	required SavedTheme theme,
	required Imageboard imageboard,
	DateTime? time,
	int? id
}) {
	final thread = imageboard.persistence.getThreadStateIfExists(post.thread)?.thread;
	final (postIdNonRepeatingSegment, postIdRepeatingSegment) = splitPostId(id, imageboard.site);
	final isOP = imageboard.site.supportsUserInfo && post.name == thread?.posts_.tryFirst?.name;
	final uniqueIPCount = thread?.uniqueIPCount;
	final combineFlagNames = settings.postDisplayFieldOrder.indexOf(PostDisplayField.countryName) == settings.postDisplayFieldOrder.indexOf(PostDisplayField.flag) + 1;
	const lineBreak = TextSpan(text: '\n');
	final name = post.name ?? imageboard.site.defaultUsername;
	final file = post.file;
	final scan = file == null ? null : MediaScan.peekCachedFileScan(file);
	final children = [
		if (post.threadId == null && (post.subject?.isNotEmpty ?? false)) TextSpan(
			text: '${post.subject}\n',
			style: TextStyle(fontWeight: FontWeight.w600, color: theme.titleColor, fontSize: 17)
		),
		for (final field in settings.postDisplayFieldOrder)
			if (field == PostDisplayField.postNumber && settings.showPostNumberOnPosts && imageboard.site.explicitIds) TextSpan(
				text: '#${thread?.replyCount ?? 1} ',
				style: TextStyle(color: theme.primaryColor.withOpacity(0.5))
			)
			else if (field == PostDisplayField.ipNumber && settings.showIPNumberOnPosts && uniqueIPCount != null) ...[
				WidgetSpan(
					child: Icon(CupertinoIcons.person_fill, color: theme.secondaryColor, size: 15),
					alignment: PlaceholderAlignment.middle
				),
				TextSpan(
					text: '${uniqueIPCount + 1} ',
					style: TextStyle(
						color: theme.secondaryColor,
						fontWeight: FontWeight.w600
					)
				)
			]
			else if (field == PostDisplayField.name) ...[
				if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && name == imageboard.site.defaultUsername)) TextSpan(
					text: '${settings.filterProfanity(name)} (You)${isOP ? ' (OP)' : ''}',
					style: TextStyle(fontWeight: FontWeight.w600, color: theme.secondaryColor)
				)
				else TextSpan(
					text: '(You)',
					style: TextStyle(fontWeight: FontWeight.w600, color: theme.secondaryColor)
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.attachmentInfo && file != null) TextSpan(
				children: _makeAttachmentInfo(
					context: null,
					metadata: [
						(
							filename: post.overrideFilename ?? file.split('/').last,
							sizeInBytes: scan?.sizeInBytes,
							width: scan?.width,
							height: scan?.height
						)
					],
					settings: settings
				).toList(),
				style: TextStyle(
					color: theme.primaryColorWithBrightness(0.8)
				)
			)
			else if (field == PostDisplayField.flag && settings.showFlagOnPosts && post.flag != null) ...[
				makeFlagSpan(
					context: null,
					zone: null,
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
			else if (field == PostDisplayField.absoluteTime && settings.showAbsoluteTimeOnPosts && time != null) TextSpan(
				text: '${formatTime(time)} '
			)
			else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts && time != null) TextSpan(
				text: '${formatRelativeTime(time)} ago '
			)
			else if (field == PostDisplayField.postId && postIdNonRepeatingSegment.isNotEmpty) ...[
				TextSpan(
					text: '${settings.showNoBeforeIdOnPosts ? 'No. ' : ''}$postIdNonRepeatingSegment',
					style: TextStyle(
						color: theme.primaryColor.withOpacity(0.5)
					)
				),
				if (postIdRepeatingSegment != null) TextSpan(
					text: postIdRepeatingSegment,
					style: TextStyle(
						color: theme.secondaryColor
					)
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.lineBreak && settings.showLineBreakInPostInfoRow) lineBreak,
	];
	if (children.last == lineBreak &&
	    settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak) {
		// "Optional line-break" use case
		// The line-break is positioned before some optional fields
		// If the optional fields aren't there, get rid of the blank line by removing
		// the line break.
		children.removeLast();
	}
	if (post.threadId == null
				? imageboard.site.supportsThreadUpvotes :
				  imageboard.site.supportsPostUpvotes) {
		children.addAll([
			WidgetSpan(
				child: Icon(CupertinoIcons.arrow_up, size: 15, color: theme.primaryColorWithBrightness(0.5)),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(text: '— ', style: TextStyle(color: theme.primaryColorWithBrightness(0.5)))
		]);
	}
	return TextSpan(
		style: const TextStyle(fontSize: 16),
		children: children
	);
}