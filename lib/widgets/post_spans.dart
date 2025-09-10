import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/board.dart';
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
import 'package:chan/services/network_image_provider.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/hover_popup.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/network_image.dart';
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
	final GestureRecognizer? recognizer2;
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
	final RegExp? highlightPattern;
	final InlineSpan? postInject;
	final bool imageShareMode;
	final bool revealYourPosts;
	final bool ensureTrailingNewline;
	final bool hiddenWithinSpoiler;
	final ValueChanged<Attachment>? onThumbnailTap;
	final bool propagateOnThumbnailTap;
	final void Function(Object?, StackTrace?)? onThumbnailLoadError;
	final bool revealSpoilerImages;
	final bool hideThumbnails;
	final bool showEmbeds;
	final bool ignorePointer;
	const PostSpanRenderOptions({
		this.recognizer,
		this.recognizer2,
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
		this.highlightPattern,
		this.postInject,
		this.imageShareMode = false,
		this.revealYourPosts = true,
		this.ensureTrailingNewline = false,
		this.hiddenWithinSpoiler = false,
		this.onThumbnailTap,
		this.propagateOnThumbnailTap = false,
		this.onThumbnailLoadError,
		this.revealSpoilerImages = false,
		this.hideThumbnails = false,
		this.showEmbeds = true,
		this.ignorePointer = false
	});
	TapGestureRecognizer? get overridingRecognizer => overrideRecognizer ? recognizer : null;

	PostSpanRenderOptions copyWith({
		TapGestureRecognizer? recognizer,
		GestureRecognizer? recognizer2,
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
		bool? hideThumbnails,
		bool? showEmbeds,
		bool? ignorePointer
	}) => PostSpanRenderOptions(
		recognizer: recognizer ?? this.recognizer,
		recognizer2: recognizer2 ?? this.recognizer2,
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
		highlightPattern: highlightPattern,
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
		hideThumbnails: hideThumbnails ?? this.hideThumbnails,
		showEmbeds: showEmbeds ?? this.showEmbeds,
		ignorePointer: ignorePointer ?? this.ignorePointer
	);
}

@immutable
sealed class PostSpan {
	const PostSpan();
	InlineSpan build(BuildContext context, Post? post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options);
	String buildText(Post? post, {bool forQuoteComparison = false});
	double estimateLines(Post? post, double charactersPerLine) => buildText(post).length / charactersPerLine;
	@override
	String toString() {
		return '$runtimeType(${buildText(null)})';
	}
	Iterable<PostSpan> traverse(Post post);
}

abstract class PostTerminalSpan extends PostSpan {
	const PostTerminalSpan();
	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
	}
}

abstract class PostSpanWithChild extends PostSpan {
	final PostSpan child;
	const PostSpanWithChild(this.child);
	@override
	buildText(Post? post, {bool forQuoteComparison = false}) => child.buildText(post, forQuoteComparison: forQuoteComparison);
	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
		yield child;
	}
}

class _PostWrapperSpan extends PostTerminalSpan {
	final InlineSpan span;
	const _PostWrapperSpan(this.span);
	@override
	InlineSpan build(context, post, zone, settings, theme, options) => span;
	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) => span.toPlainText();
}

class PostNodeSpan extends PostSpan {
	final List<PostSpan> children;
	const PostNodeSpan(this.children);

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
		yield* children;
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
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
				renderChildren.add(effectiveChildren[i].build(context, post, zone, settings, theme, ownLineOptions));
			}
			else {
				renderChildren.add(effectiveChildren[i].build(context, post, zone, settings, theme, effectiveOptions));
			}
			if (effectiveChildren[i] is PostLineBreakSpan) {
				lines += lineGuess.ceil();
				lineGuess = 0;
			}
			else {
				lineGuess += effectiveChildren[i].buildText(post).length / options.charactersPerLine;
			}
		}
		if (lineGuess != 0 && options.ensureTrailingNewline) {
			renderChildren.add(const TextSpan(text: '\n'));
		}
		return TextSpan(
			children: renderChildren
		);
	}

	Widget buildWidget(BuildContext context, Post post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, {Widget? preInjectRow, InlineSpan? postInject}) {
		final rows = <List<InlineSpan>>[[]];
		int lines = preInjectRow != null ? 2 : 1;
		for (int i = 0; i < children.length && lines < options.maxLines; i++) {
			if (children[i] is PostLineBreakSpan) {
				rows.add([]);
				lines++;
			}
			else if ((i == 0 || children[i - 1] is PostLineBreakSpan) && (i == children.length - 1 || children[i + 1] is PostLineBreakSpan)) {
				rows.last.add(children[i].build(context, post, zone, settings, theme, options.copyWith(ownLine: true)));
			}
			else {
				rows.last.add(children[i].build(context, post, zone, settings, theme, options));
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
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return children.map((x) => x.buildText(post, forQuoteComparison: forQuoteComparison)).join('');
	}

	@override
	double estimateLines(Post? post, double charactersPerLine) {
		double lines = 0;
		double lineGuess = 0;
		for (final child in children) {
			if (child is PostLineBreakSpan) {
				lines += lineGuess.ceil();
				lineGuess = 0;
			}
			else {
				lineGuess += child.estimateLines(post, charactersPerLine);
			}
		}
		lines += lineGuess.ceil();
		return lines;
	}

	@override
	String toString() => 'PostNodeSpan($children)';
}

class PostAttachmentsSpan extends PostTerminalSpan {
	final List<Attachment> attachments;
	const PostAttachmentsSpan(this.attachments);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(text: buildText(post));
		}
		final stackIds = zone.stackIds.toList();
		if (stackIds.isNotEmpty) {
			stackIds.removeLast();
		}
		return WidgetSpan(
			child: Wrap(
				spacing: 16,
				runSpacing: 16,
				children: attachments.map((attachment) {
					return PopupAttachment(
						attachment: attachment,
						child: CupertinoButton(
							padding: EdgeInsets.zero,
							minSize: 0,
							onPressed: options.onThumbnailTap?.bind1(attachment),
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minHeight: 75
								),
								child: AttachmentThumbnail(
									attachment: attachment,
									revealSpoilers: options.revealSpoilerImages,
									onLoadError: options.onThumbnailLoadError,
									hero: TaggedAttachment(
										attachment: attachment,
										semanticParentIds: stackIds,
										imageboard: zone.imageboard
									),
									fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
									shrinkHeight: !settings.squareThumbnails,
									width: zone.imageboard.site.hasLargeInlineAttachments ? 250 : null,
									height: zone.imageboard.site.hasLargeInlineAttachments ? 250 : null,
									mayObscure: true,
									hide: options.hideThumbnails,
									cornerIcon: AttachmentThumbnailCornerIcon(
										backgroundColor: theme.backgroundColor,
										borderColor: theme.primaryColorWithBrightness(0.2),
										size: null
									)
								)
							)
						)
					);
				}).toList()
			)
		);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Make it look like a SiteXenforo quote (the only use case)
			return '${attachments.map((a) => '[View Attachment ${a.id}](${a.url})').join('')}\n';
		}
		return '${attachments.map((a) => a.url).join(', ')}\n';
	}
}

class PostTextSpan extends PostTerminalSpan {
	final String text;
	const PostTextSpan(this.text);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		final children = <TextSpan>[];
		final str = settings.filterProfanity(text);
		final highlightPattern = options.highlightPattern;
		if (highlightPattern != null) {
			int lastEnd = 0;
			for (final match in highlightPattern.allMatches(str)) {
				if (match.start != lastEnd) {
					children.add(TextSpan(
						text: str.substring(lastEnd, match.start),
						recognizer: options.ignorePointer ? null : options.recognizer,
						recognizer2: options.ignorePointer ? null : options.recognizer2
					));
				}
				children.add(TextSpan(
					text: match.group(0)!,
					style: const TextStyle(
						color: Colors.black,
						backgroundColor: Colors.yellow
					),
					recognizer: options.ignorePointer ? null : options.recognizer,
					recognizer2: options.ignorePointer ? null : options.recognizer2
				));
				lastEnd = match.end;
			}
			if (lastEnd < str.length) {
				children.add(TextSpan(
					text: str.substring(lastEnd),
					recognizer: options.ignorePointer ? null : options.recognizer,
					recognizer2: options.ignorePointer ? null : options.recognizer2
				));
			}
		}
		else {
			children.add(TextSpan(
				text: str,
				recognizer: options.ignorePointer ? null : options.recognizer,
				recognizer2: options.ignorePointer ? null : options.recognizer2
			));
		}
		return TextSpan(
			children: children,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor
			),
			recognizer: options.ignorePointer ? null : options.recognizer,
			recognizer2: options.ignorePointer ? null : options.recognizer2,
			onEnter: options.onEnter,
			onExit: options.onExit
		);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return text;
	}
}

class PostUnderlinedSpan extends PostSpanWithChild {
	const PostUnderlinedSpan(super.child);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? options.baseTextStyle.color
			)
		));
	}
}

class PostOverlinedSpan extends PostSpanWithChild {
	const PostOverlinedSpan(super.child);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.overline,
				decorationColor: options.overrideTextColor ?? options.baseTextStyle.color
			)
		));
	}
}

class PostLineBreakSpan extends PostTerminalSpan {
	const PostLineBreakSpan();

	@override
	InlineSpan build(context, post, zone, settings, theme, options) =>  const TextSpan(text: '\n');

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) => '\n';

	@override
	String toString() => 'PostLineBreakSpan()';
}

class PostWeakQuoteLinkSpan extends PostSpan {
	final int id;
	final PostQuoteSpan quote;
	final String? author;
	const PostWeakQuoteLinkSpan({
		required this.id,
		required this.quote,
		this.author
	});

	/// Positive = exact quote (hide [this.quote])
	/// Negative = partial quote (still show [this.quote])
	int? findQuoteTarget(Post? post) {
		if (post == null) {
			return null;
		}
		final key = '${post.id}/$id';
		return post.extraMetadata?[key];
	}

	void setQuoteTarget(Post post, int targetPostId, bool isExactQuote) {
		final key = '${post.id}/$id';
		(post.extraMetadata ??= {})[key] = isExactQuote ? targetPostId : -targetPostId;
	}

	PostSpan _getSpan(Post? post) {
		final target = findQuoteTarget(post);
		if (post != null && target != null) {
			final quoteLink = PostQuoteLinkSpan(
				board: post.board,
				threadId: post.threadId,
				postId: target.abs(),
				key: ValueKey('${post.id}/$id')
			);
			if (target.isNegative) {
				// Show the context
				return PostNodeSpan([
					quoteLink,
					const PostLineBreakSpan(),
					quote
				]);
			}
			return quoteLink;
		}
		return quote;
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return _getSpan(post).build(context, post, zone, settings, theme, options);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return _getSpan(post).buildText(post, forQuoteComparison: forQuoteComparison);
	}

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield _getSpan(post);
	}

	@override
	String toString() => 'PostQuoteWeakLinkSpan(id: $id, author: $author, quote: $quote)';
}

class PostQuoteSpan extends PostSpanWithChild {
	const PostQuoteSpan(super.child);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.quoteColor),
			showEmbeds: false
		));
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Nested quotes not used
			return '';
		}
		return child.buildText(post);
	}

	@override
	String toString() => 'PostQuoteSpan($child)';
}

class PostPinkQuoteSpan extends PostQuoteSpan {
	const PostPinkQuoteSpan(super.child);

	static Color getColor(SavedTheme theme) => theme.quoteColor.shiftHue(-90);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: getColor(theme))
		));
	}

	@override
	String toString() => 'PostPinkQuoteSpan($child)';
}

class PostBlueQuoteSpan extends PostQuoteSpan {
	const PostBlueQuoteSpan(super.child);

	static Color getColor(SavedTheme theme) => theme.quoteColor.shiftHue(135);

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: getColor(theme))
		));
	}

	@override
	String toString() => 'PostBlueQuoteSpan($child)';
}

class PostQuoteLinkSpan extends PostTerminalSpan {
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
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () {
			if (settings.openCrossThreadLinksInNewTab) {
				final newTabZone = context.read<OpenInNewTabZone?>();
				final imageboardKey = context.read<Imageboard>().key;
				if (newTabZone != null && ImageboardRegistry.instance.getImageboard(imageboardKey) != null) {
					// Checking ImageboardRegistry to rule-out dev board
					newTabZone.onWantOpenThreadInNewTab(imageboardKey, ThreadIdentifier(board, actualThreadId), initialPostId: postId);
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
						initiallyUseArchive: threadId == null ? '' : null,
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
			recognizer: options.ignorePointer ? null : recognizer
		), recognizer);
	}
  (TextSpan, TapGestureRecognizer) _buildDeadLink(BuildContext context, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options) {
		final boardPrefix = board == zone.board ? '' : '${zone.imageboard.site.formatBoardNameWithoutTrailingSlash(board)}/';
		String text = '>>$boardPrefix$postId';
		if (zone.postFromArchiveError(board, postId)?.$1 case Object error) {
			text += ' (Error: ${error.toStringDio()})';
		}
		else if (zone.isLoadingPostFromArchive(board, postId)) {
			text += ' (Loading...)';
		}
		else {
			text += ' (Dead)';
		}
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () {
			if (zone.isLoadingPostFromArchive(board, postId) == false) zone.loadPostFromArchive(board, postId);
		});
		return (TextSpan(
			text: text,
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor
			),
			recognizer: options.ignorePointer ? null : recognizer
		), recognizer);
	}
	(TextSpan, TapGestureRecognizer, bool) _buildNormalLink(BuildContext context, Post? post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, int? threadId) {
		String text = '>>$postId';
		Color color = theme.secondaryColor;
		if (postId == threadId) {
			text += ' (OP)';
		}
		if (threadId != zone.primaryThreadId) {
			color = theme.secondaryColor.shiftHue(-20);
			if (post?.threadId != threadId) {
				text += ' (Old thread)';
			}
		}
		if (threadId != null && (zone.imageboard.persistence.getThreadStateIfExists(ThreadIdentifier(board, threadId))?.youIds.contains(postId) ?? false) && options.revealYourPosts) {
			text += ' (You)';
		}
		final linkedPost = zone.findPost(postId);
		if (linkedPost != null && Filter.of(context).filter(zone.imageboard.key, linkedPost)?.type.hide == true && !options.imageShareMode) {
			text += ' (Hidden)';
		}
		final bool expandedImmediatelyAbove = zone.shouldExpandPost(this) || zone.stackIds.length > 1 && zone.stackIds.elementAt(zone.stackIds.length - 2) == postId;
		final bool expandedSomewhereAbove = expandedImmediatelyAbove || zone.stackIds.contains(postId);
		final stackCount = zone.stackIds.countOf(postId);
		final enableInteraction = switch(zone.style) {
			PostSpanZoneStyle.tree => stackCount <= 1,
			_ => !expandedImmediatelyAbove ||
			     zone.shouldExpandPost(this) // Always allow re-collapsing
		};
		final enableUnconditionalInteraction = switch(zone.style) {
			PostSpanZoneStyle.tree => stackCount == 0,
			_ => !expandedImmediatelyAbove
		};
		final recognizer = options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () async {
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
				else if (zone.shouldExpandPost(this) || settings.mouseModeQuoteLinkBehavior == MouseModeQuoteLinkBehavior.expandInline || zone.onNeedScrollToPost == null) {
					zone.toggleExpansionOfPost(this);
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
			recognizer: options.ignorePointer ? null : recognizer,
			onEnter: options.onEnter,
			onExit: options.onExit
		), recognizer, enableUnconditionalInteraction);
	}
	(InlineSpan, TapGestureRecognizer) _build(BuildContext context, Post? post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options) {
		int? actualThreadId = threadId;
		if (threadId == null) {
			// Dead links do not know their thread
			Post? thisPostLoaded = zone.crossThreadPostFromArchive(board, postId);
			if (board == zone.board) {
				thisPostLoaded ??= zone.findPost(postId);
			}
			if (thisPostLoaded != null) {
				actualThreadId = thisPostLoaded.threadId;
			}
			else {
				return _buildDeadLink(context, zone, settings, theme, options);
			}
		}

		if (actualThreadId != null && (ImageboardBoard.getKey(board) != ImageboardBoard.getKey(zone.board) || zone.findThread(actualThreadId) == null || (actualThreadId != zone.primaryThreadId && actualThreadId == postId))) {
			return _buildCrossThreadLink(context, zone, settings, theme, options, actualThreadId);
		}
		else {
			// Normal link
			final span = _buildNormalLink(context, post, zone, settings, theme, options, actualThreadId);
			final thisPostInThread = zone.findPost(postId);
			final stackCount = zone.stackIds.countOf(postId);
			final enableInteraction = switch(zone.style) {
				PostSpanZoneStyle.tree => stackCount <= 1,
				_ => stackCount == 0
			};
			if (thisPostInThread == null ||
			    zone.shouldExpandPost(this) == true ||
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
					child: BuildContextRegistrant(
						onBuild: (context) {
							if (span.$3) {
								zone._registerLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context, span.$2.onTap ?? () {});
							}
							else if (zone.style == PostSpanZoneStyle.tree) {
								zone._registerConditionalLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context, () {
									return zone.isPostOnscreen?.call(postId) != true;
								}, span.$2.onTap ?? () {});
							}
						},
						onDispose: (context) {
							zone._unregisterLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context);
							zone._unregisterConditionalLineTapTarget('$board/$threadId/$postId/${identityHashCode(this)}', context);
						},
						child: TweenAnimationBuilder(
							tween: ColorTween(begin: null, end: zone.highlightQuoteLinkId == postId ? Colors.white54 : Colors.transparent),
							duration: zone.highlightQuoteLinkId != postId ? const Duration(milliseconds: 750) : const Duration(milliseconds: 250),
							curve: Curves.ease,
							builder: (context, c, child) => c == Colors.transparent ? popup : ColorFiltered(
								colorFilter: ColorFilter.mode(c ?? Colors.transparent, BlendMode.srcATop),
								child: popup
							)
						)
					)
				), span.$2);
			}
		}
	}
	@override
	build(context, post, zone, settings, theme, options) {
		final pair = _build(context, post, zone, settings, theme, options);
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
					WidgetSpan(child: ExpandingPost(link: this))
				]
			);
		}
		else {
			return span;
		}
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return '';
		}
		return '>>$postId';
	}

	@override
	bool operator == (Object other) {
		if (identical(this, other)) {
			return true;
		}
		// This is on purpose so that generic (constructed in makeSpan) links are compared for identity,
		// but dynamic (constructed for replyIds) are compared by properties
		if (key == null) {
			return false;
		}
		return
			other is PostQuoteLinkSpan &&
			other.board == board &&
			other.threadId == threadId &&
			other.postId == postId &&
			other.key == key;
	}

	@override
	int get hashCode => Object.hash(board, threadId, postId, key);
}

class PostQuoteLinkWithContextSpan extends PostSpan {
	final PostQuoteLinkSpan quoteLink;
	final PostQuoteSpan context;

	const PostQuoteLinkWithContextSpan({
		required this.quoteLink,
		required this.context
	});

	@override
	build(context, post, zone, settings, theme, options) {
		final thePost = zone.findPost(quoteLink.postId);
		final theText = thePost?.span.buildText(thePost, forQuoteComparison: true);
		final contextText = this.context.child.buildText(post, forQuoteComparison: true);
		final similarity = theText?.similarityTo(contextText) ?? 0;
		return TextSpan(
			children: [
				quoteLink.build(context, post, zone, settings, theme, options),
				const TextSpan(text: '\n'),
				if (similarity < 0.85) ...[
					// Partial quote, include the snippet
					this.context.build(context, post, zone, settings, theme, options),
					const TextSpan(text: '\n'),
				]
			]
		);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return '';
		}
		return '${quoteLink.buildText(post)}\n${context.buildText(post)}';
	}

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		// Can't figure out whether to show the quote or not here. Assume it's not shown
		yield quoteLink;
	}

	@override
	String toString() => 'PostQuoteLinkWithContextSpan($quoteLink, $context)';
}

class PostBoardLinkSpan extends PostTerminalSpan {
	final String board;
	PostBoardLinkSpan(String board) : board = intern(board);
	@override
	build(context, post, zone, settings, theme, options) {
		return TextSpan(
			text: zone.imageboard.site.formatBoardLink(board),
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: options.ignorePointer ? null : options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () async {
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
	String buildText(Post? post, {bool forQuoteComparison = false}) {
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

class PostCodeSpan extends PostTerminalSpan {
	final String text;

	const PostCodeSpan(this.text);

	static final _startsWithCapitalLetterPattern = RegExp(r'^[A-Z]');

	@override
	build(context, post, zone, settings, theme, options) {
		if (text.isEmpty) {
			// New troll strategy with empty [code][/code]
			// Make it look like something instead of zero-width
			return const TextSpan(
				text: ' ',
				style: TextStyle(
					backgroundColor: Colors.black
				)
			);
		}
		final lineCount = lineSeparatorPattern.allMatches(text).length + 1;
		final result = zone.getFutureForComputation(
			id: 'languagedetect ${identityHashCode(text)} ${text.substring(0, (text.length - 1).clamp(0, 10))}',
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
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return '[code]$text[/code]';
	}
}

class PostSpoilerSpan extends PostSpanWithChild {
	final int id;
	final bool forceReveal;
	const PostSpoilerSpan(super.child, this.id, {this.forceReveal = false});
	@override
	build(context, post, zone, settings, theme, options) {
		final showSpoiler = options.imageShareMode || options.showRawSource || zone.shouldShowSpoiler(id) || forceReveal;
		final toggleRecognizer = TapGestureRecognizer(debugOwner: this)..onTap = () {
			zone.toggleShowingOfSpoiler(id);
		};
		final hiddenColor = theme.primaryColor;
		final visibleColor = theme.backgroundColor;
		onEnter(_) => zone.showSpoiler(id);
		onExit(_) => zone.hideSpoiler(id);
		return TextSpan(
			children: [child.build(context, post, zone, settings, theme, options.copyWith(
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
			recognizer: options.ignorePointer ? null : toggleRecognizer,
			onEnter: onEnter,
			onExit: onExit
		);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return '[spoiler]${child.buildText(post, forQuoteComparison: forQuoteComparison)}[/spoiler]';
	}
}

class PostLinkSpan extends PostTerminalSpan {
	final String url;
	final String? name;
	final EmbedData? embedData;
	const PostLinkSpan(this.url, {this.name, this.embedData});

	static final _trailingJunkPattern = RegExp(r'(\.[A-Za-z0-9\-._~]+)[^A-Za-z0-9\-._~\.\/?]+$');

	@override
	build(context, post, zone, settings, theme, options) {
		// Remove trailing bracket or other punctuation
		final cleanedUrl = url.replaceAllMapped(
			_trailingJunkPattern,
			(m) => m.group(1)!
		);
		(Imageboard, BoardThreadOrPostIdentifier, String?)? imageboardTarget;
		Future<void> onLongPress() async {
			await shareOne(
				context: context,
				text: cleanedUrl,
				type: "text",
				sharePositionOrigin: null,
				additionalOptions: {
					if (imageboardTarget != null)
						'Open in new tab': () async {
							context.read<ChanTabs>().addNewTab(
								withImageboardKey: imageboardTarget?.$1.key,
								withBoard: imageboardTarget?.$2.board,
								withThread: imageboardTarget?.$2.threadIdentifier,
								withInitialPostId: imageboardTarget?.$2.postId,
								initiallyUseArchive: imageboardTarget?.$3,
								activate: true
							);
						}
				}
			);
		}
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
						work: () => loadEmbedData(url, highQuality: false)
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
				imageboardTarget = snapshot.data?.imageboardTarget;
				if (imageboardTarget != null && imageboardTarget.$1.key == zone.imageboard.key) {
					final thread = imageboardTarget.$2.threadIdentifier;
					if (thread != null) {
						if (zone.imageboard.site.explicitIds) {
							return PostQuoteLinkSpan(
								board: imageboardTarget.$2.board,
								threadId: thread.id,
								postId: imageboardTarget.$2.postId ?? thread.id,
								key: ObjectKey(this)
							).build(context, post, zone, settings, theme, options);
						}
					}
					else {
						return PostBoardLinkSpan(imageboardTarget.$2.board).build(context, post, zone, settings, theme, options);
					}
				}
				final attachments = snapshot.data?.attachments;
				if (attachments != null) {
					final stackIds = zone.stackIds.toList();
					if (stackIds.isNotEmpty) {
						stackIds.removeLast();
					}
					return PostAttachmentsSpan(
						attachments.item
					).build(context, post, zone, settings, theme, options.copyWith(
						onThumbnailTap: (attachment) async {
							await showGalleryPretagged(
								context: context,
								attachments: attachments.item.map((a) => TaggedAttachment(
									attachment: a,
									imageboard: attachments.imageboard,
									semanticParentIds: stackIds
								)).toList(),
								initialAttachment: TaggedAttachment(
									attachment: attachment,
									imageboard: attachments.imageboard,
									semanticParentIds: stackIds
								),
								heroOtherEndIsBoxFitCover: settings.squareThumbnails
							);
						}
					));
				}
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
				if (snapshot.data?.thumbnailWidget != null || snapshot.data?.thumbnailUrl != null || snapshot.data?.imageboardTarget != null) {
					final lines = [
						if (name != null && !url.contains(name!) && (snapshot.data?.title?.contains(name!) != true)) name!,
						if (snapshot.data?.title?.isNotEmpty ?? false) snapshot.data!.title!
						else if (name == null || url.contains(name!)) url
					];
					Widget? tapChildChild = snapshot.data?.thumbnailWidget;
					if (tapChildChild == null && snapshot.data?.thumbnailUrl != null) {
						ImageProvider image = CNetworkImageProvider(
							snapshot.data!.thumbnailUrl!,
							client: zone.imageboard.site.client,
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
					if (tapChildChild == null && snapshot.data?.imageboardTarget != null) {
						tapChildChild = ImageboardIcon(
							imageboardKey: snapshot.data?.imageboardTarget?.$1.key,
							boardName: snapshot.data?.imageboardTarget?.$2.board
						);
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
						if (imageboardTarget != null) {
							openImageboardTarget(context, imageboardTarget);
						}
						else {
							openBrowser(context, cleanedUri!);
						}
					}
					return WidgetSpan(
						alignment: PlaceholderAlignment.middle,
						child: GestureDetector(
							onLongPress: onLongPress,
							// To win against CupertinoContextMenu2
							longPressDuration: kLongPressTimeout ~/ 2,
							child: CupertinoButton(
								padding: EdgeInsets.zero,
								onPressed: onTap,
								child: tapChild
							)
						)
					);
				}
			}
		}
		return PostTextSpan(name ?? url).build(context, post, zone, settings, theme, options.copyWith(
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () => openBrowser(context, cleanedUri!)),
			recognizer2: options.overridingRecognizer != null ? null : (LongPressGestureRecognizer(debugOwner: this, duration: kLongPressTimeout ~/ 2)..onLongPress = onLongPress),
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline
			)
		));
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		if (name != null && !url.endsWith(name!)) {
			return '[$name]($url)';
		}
		else {
			return url;
		}
	}
}

class PostCatalogSearchSpan extends PostTerminalSpan {
	final String board;
	final String query;
	PostCatalogSearchSpan({
		required String board,
		required this.query
	}) : board = intern(board);
	@override
	build(context, post, zone, settings, theme, options) {
		return TextSpan(
			text: zone.imageboard.site.formatBoardSearchLink(board, query),
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: theme.secondaryColor,
				color: theme.secondaryColor
			),
			recognizer: options.ignorePointer ? null : (TapGestureRecognizer(debugOwner: this)..onTap = () => (context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
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
			))),
			onEnter: options.onEnter,
			onExit: options.onExit
		);
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) {
		return '>>>/$board/$query';
	}
}

class PostTeXSpan extends PostTerminalSpan {
	final String tex;
	const PostTeXSpan(this.tex);
	@override
	build(context, post, zone, settings, theme, options) {
		final child = TexWidget(
			tex: tex,
			color: options.overrideTextColor ?? options.baseTextStyle.color
		);
		return options.showRawSource ? TextSpan(
			text: buildText(post)
		) : WidgetSpan(
			alignment: PlaceholderAlignment.middle,
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				child: child
			)
		);
	}
	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) => '[math]$tex[/math]';
}

class PostInlineImageSpan extends PostTerminalSpan {
	final String src;
	final int width;
	final int height;
	const PostInlineImageSpan({
		required this.src,
		required this.width,
		required this.height
	});
	@override
	build(context, post, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(
				text: '<img src="$src">'
			);
		}
		return WidgetSpan(
			child: SizedBox(
				width: width.toDouble(),
				height: height.toDouble(),
				child: CNetworkImage(
					url: Uri.parse(zone.imageboard.site.getWebUrl(
						board: zone.board,
						threadId: zone.primaryThreadId
					)).resolve(src).toString(),
					client: zone.imageboard.site.client,
					cache: true,
					enableLoadState: false
				)
			),
			alignment: PlaceholderAlignment.bottom
		);
	}
	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) => src;
}

class PostColorSpan extends PostSpanWithChild {
	final Color? color;
	
	const PostColorSpan(super.child, this.color);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: color)
		));
	}
}

class PostSecondaryColorSpan extends PostSpanWithChild {
	const PostSecondaryColorSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.secondaryColor)
		));
	}
}

class PostBoldSpan extends PostSpanWithChild {
	const PostBoldSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold)
		));
	}
}

class PostItalicSpan extends PostSpanWithChild {
	const PostItalicSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontStyle: FontStyle.italic)
		));
	}
}

class PostSuperscriptSpan extends PostSpanWithChild {
	const PostSuperscriptSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontFeatures: const [FontFeature.superscripts()])
		));
	}
}

class PostSubscriptSpan extends PostSpanWithChild {
	const PostSubscriptSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontFeatures: const [FontFeature.subscripts()])
		));
	}
}

class PostStrikethroughSpan extends PostSpanWithChild {
	const PostStrikethroughSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(decoration: TextDecoration.lineThrough, decorationColor: options.overrideTextColor ?? options.baseTextStyle.color)
		));
	}
}


class PostPopupSpan extends PostSpanWithChild {
	final String title;
	const PostPopupSpan({
		required PostSpan popup,
		required this.title
	}) : super(popup);
	@override
	build(context, post, zone, settings, theme, options) {
		return TextSpan(
			text: 'Show $title',
			style: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: options.overrideTextColor ?? options.baseTextStyle.color
			),
			recognizer: options.ignorePointer ? null : (options.overridingRecognizer ?? TapGestureRecognizer(debugOwner: this)..onTap = () {
				showAdaptiveModalPopup(
					context: context,
					builder: (context) => AdaptiveActionSheet(
						title: Text(title),
						message: Text.rich(
							child.build(context, post, zone, settings, theme, options),
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
		));
	}

	@override
	buildText(Post? post, {bool forQuoteComparison = false}) => '$title\n${child.buildText(post, forQuoteComparison: forQuoteComparison)}';
}

class IntrinsicColumnWidthWithMaxWidth extends IntrinsicColumnWidth {
	final double maxWidth;

  const IntrinsicColumnWidthWithMaxWidth({
		this.maxWidth = double.infinity,
		double? flex
	}) : super(flex: flex);

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      result = math.max(result, cell.getMinIntrinsicWidth(double.infinity));
    }
    return result;
  }

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double result = 0.0;
    for (final RenderBox cell in cells) {
      result = math.max(result, math.min(maxWidth, cell.getMaxIntrinsicWidth(double.infinity)));
    }
    return result;
  }

  @override
  String toString() => 'IntrinsicColumnWidthWithMaxWidth(maxWidth: $maxWidth)';
}

class PostTableSpan extends PostSpan {
	final List<List<PostSpan>> rows;
	const PostTableSpan(this.rows);
	@override
	build(context, post, zone, settings, theme, options) {
		if (options.showRawSource) {
			return TextSpan(text: buildText(post));
		}
		// We want cell to fill width (subtract PostRow padding)
		final maxWidth = estimateWidth(context) - 32;
		return WidgetSpan(
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				physics: const BouncingScrollPhysics(),
				child: Table(
					defaultColumnWidth: IntrinsicColumnWidthWithMaxWidth(
						flex: null,
						maxWidth: maxWidth
					),
					border: TableBorder.all(
						color: theme.primaryColor
					),
					children: rows.map((row) => TableRow(
						children: row.map((col) => TableCell(
							child: Padding(
								padding: const EdgeInsets.all(4),
								child: Text.rich(
									col.build(context, post, zone, settings, theme, options),
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
	buildText(Post? post, {bool forQuoteComparison = false}) => rows.map((r) => r.map((r) => r.buildText(post, forQuoteComparison: forQuoteComparison)).join(', ')).join('\n');

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		for (final row in rows) {
			yield* row;
		}
	}
}

class PostDividerSpan extends PostTerminalSpan {
	const PostDividerSpan();
	@override
	build(context, post, zone, settings, theme, options) => const WidgetSpan(
		child: ChanceDivider(height: 16)
	);

	@override
	buildText(Post? post, {bool forQuoteComparison = false}) => '\n';
}

class PostShiftJISSpan extends PostTerminalSpan {
	final String text;

	const PostShiftJISSpan(this.text);

	@override
	build(context, post, zone, settings, theme, options) {
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
	buildText(Post? post, {bool forQuoteComparison = false}) => '[sjis]$text[/sjis]';
}

class PostUserLinkSpan extends PostTerminalSpan {
	final String username;

	const PostUserLinkSpan(this.username);

	@override
	build(context, post, zone, settings, theme, options) {
		return TextSpan(
			text: '/u/${zone.imageboard.site.formatUsername(username)}',
			style: options.baseTextStyle.copyWith(
				color: options.overrideTextColor ?? theme.secondaryColor,
				decorationColor: options.overrideTextColor ?? theme.secondaryColor,
				decoration: TextDecoration.underline
			),
			recognizer: options.overridingRecognizer ?? (TapGestureRecognizer(debugOwner: this)..onTap = () async {
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
	buildText(Post? post, {bool forQuoteComparison = false}) => '/u/$username';
}

class PostCssSpan extends PostSpanWithChild {
	final String css;

	const PostCssSpan(super.child, this.css);

	@override
	build(context, post, zone, settings, theme, options) {
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
				style = style.copyWith(fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold);
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
			return child.build(context, post, zone, settings, theme, options.copyWith(
				baseTextStyle: style
			));
		}
		else {
			return TextSpan(
				children: [
					TextSpan(text: '<span style="${unrecognizedParts.join('; ')}">'),
					child.build(context, post, zone, settings, theme, options.copyWith(
						baseTextStyle: style
					)),
					const TextSpan(text: '</span>')
				]
			);
		}
	}

	@override
	String buildText(Post? post, {bool forQuoteComparison = false}) => '<span style="$css">${child.buildText(post, forQuoteComparison: forQuoteComparison)}</span>';
}

class PostSmallTextSpan extends PostSpanWithChild {
	const PostSmallTextSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontSize: 14)
		));
	}
}

class PostBigTextSpan extends PostSpanWithChild {
	const PostBigTextSpan(super.child);
	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontSize: 23)
		));
	}
}

class PostSpanZone extends StatelessWidget {
	final int postId;
	final Widget child;
	final PostSpanZoneStyle? style;
	final PostQuoteLinkSpan? link;

	const PostSpanZone({
		required this.postId,
		required this.child,
		this.style,
		this.link,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider<PostSpanZoneData>.value(
			value: context.read<PostSpanZoneData>().childZoneFor(postId, style: style, link: link),
			child: child
		);
	}
}

enum PostSpanZoneStyle {
	linear,
	tree,
	expandedInline
}

abstract class PostSpanZoneData extends ChangeNotifier {
	final Map<(int?, PostSpanZoneStyle?, int?, ValueChanged<Post>?, PostQuoteLinkSpan?), _PostSpanChildZoneData> _children = {};
	String get board;
	int get primaryThreadId;
	ThreadIdentifier get primaryThread => ThreadIdentifier(board, primaryThreadId);
	PersistentThreadState? get primaryThreadState => imageboard.persistence.getThreadStateIfExists(primaryThread);
	Imageboard get imageboard;
	Iterable<int> get stackIds;
	ValueChanged<Post>? get onNeedScrollToPost;
	ValueChanged<int>? get onPostSeen;
	double Function(int postId)? get shouldHighlightPost;
	bool Function(int postId)? get isPostOnscreen;
	void Function(int postId, bool glow)? get glowOtherPost;
	Future<void> Function(List<ParentAndChildIdentifier>)? get onNeedUpdateWithStubItems;
	bool disposed = false;
	List<Comparator<Post>> get postSortingMethods;
	PostSpanZoneStyle get style;

	final Map<PostQuoteLinkSpan, BuildContext> _expandedPostContexts = {};
	Iterable<MapEntry<PostQuoteLinkSpan, BuildContext>> get expandedPostContexts sync* {
		// Yielding children first on purpose. Deepest match should win.
		for (final child in _children.values) {
			yield* child.expandedPostContexts;
		}
		yield* _expandedPostContexts.entries;
	}

	final Map<PostQuoteLinkSpan, bool> _shouldExpandPost = {};
	bool shouldExpandPost(PostQuoteLinkSpan link) {
		return _shouldExpandPost[link] ?? false;
	}
	void toggleExpansionOfPost(PostQuoteLinkSpan link) {
		_shouldExpandPost[link] = !shouldExpandPost(link);
		if (!_shouldExpandPost[link]!) {
			_expandedPostContexts.remove(link);
			_children.entries.where((c) => c.key.$5 == link).forEach((c) => c.value.unExpandAllPosts());
		}
		notifyListeners();
	}
	void unExpandAllPosts() => throw UnimplementedError();
	bool isLoadingPostFromArchive(String board, int id);
	Future<void> loadPostFromArchive(String board, int id);
	Post? crossThreadPostFromArchive(String board, int id);
	(Object, StackTrace)? postFromArchiveError(String board, int id);
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
		ValueChanged<Post>? onNeedScrollToPost,
		PostQuoteLinkSpan? link
	}) {
		final key = (postId, style, fakeHoistedRootId, onNeedScrollToPost, link);
		return _children[key] ??= _PostSpanChildZoneData(
			parent: this,
			postId: postId,
			style: style,
			fakeHoistedRootId: fakeHoistedRootId,
			onNeedScrollToPost: onNeedScrollToPost
		);
	}

	PostSpanZoneData hoistFakeRootZoneFor(int fakeHoistedRootId, {PostSpanZoneStyle? style, bool clearStack = false});

	void notifyAllListeners() {
		notifyListeners();
		for (final child in _children.values) {
			child.notifyAllListeners();
		}
	}

	final Map<String, Map<BuildContext, VoidCallback>> _lineTapCallbacks = {};
	void _registerLineTapTarget(String id, BuildContext context, VoidCallback callback) {
		(_lineTapCallbacks[id] ??= {})[context] = callback;
	}
	void _unregisterLineTapTarget(String id, BuildContext context) {
		_lineTapCallbacks[id]?.remove(context);
	}
	final Map<String, Map<BuildContext, (bool Function(), VoidCallback)>> _conditionalLineTapCallbacks = {};
	void _registerConditionalLineTapTarget(String id, BuildContext context, bool Function() condition, VoidCallback callback) {
		(_conditionalLineTapCallbacks[id] ??= {})[context] = (condition, callback);
	}
	void _unregisterConditionalLineTapTarget(String id, BuildContext? context) {
		_conditionalLineTapCallbacks[id]?.remove(context);
	}

	bool _onTap(Offset position, bool runCallback) {
		(double, bool Function(), VoidCallback)? closest;
		bool yes() => true;
		void checkClosest(double deltaY, bool Function() condition, VoidCallback f) {
			if (closest == null || closest!.$1 > deltaY) {
				closest = (deltaY, condition, f);
			}
		}
		for (final map in _lineTapCallbacks.values) {
			for (final entry in map.entries) {
				final RenderBox? box;
				try {
					box = entry.key.findRenderObject() as RenderBox?;
				}
				catch (e) {
					continue;
				}
				if (box != null) {
					final y0 = box.localToGlobal(box.paintBounds.topLeft).dy;
					if (y0 > position.dy) {
						checkClosest(y0 - position.dy, yes, entry.value);
						continue;
					}
					final y1 = box.localToGlobal(box.paintBounds.bottomRight).dy;
					if (position.dy < y1) {
						if (runCallback) {
							entry.value();
						}
						return true;
					}
					else {
						checkClosest(position.dy - y1, yes, entry.value);
					}
				}
			}
		}
		for (final map in _conditionalLineTapCallbacks.values) {
			for (final entry in map.entries) {
				final RenderBox? box;
				try {
					box = entry.key.findRenderObject() as RenderBox?;
				}
				catch (e) {
					continue;
				}
				if (box != null) {
					final y0 = box.localToGlobal(box.paintBounds.topLeft).dy;
					if (y0 > position.dy) {
						checkClosest(y0 - position.dy, entry.value.$1, entry.value.$2);
						continue;
					}
					final y1 = box.localToGlobal(box.paintBounds.bottomRight).dy;
					if (position.dy < y1 && entry.value.$1()) {
						if (runCallback) {
							entry.value.$2();
						}
						return true;
					}
					else {
						checkClosest(position.dy - y1, entry.value.$1, entry.value.$2);
					}
				}
			}
		}
		final finalClosest = closest;
		if (finalClosest != null && finalClosest.$1 <= 10) {
			// Less than 10px slop
			if (finalClosest.$2()) {
				if (runCallback) {
					finalClosest.$3();
				}
				return true;
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
		_lineTapCallbacks.clear();
		_expandedPostContexts.clear();
		super.dispose();
		disposed = true;
	}

	AsyncSnapshot<Post>? translatedPost(int postId);
	AsyncSnapshot<String>? translatedTitle(int threadId);
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

	@override
	String toString() => '$runtimeType(stackIds: $stackIds)';
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
	ValueChanged<int>? get onPostSeen => parent.onPostSeen;

	@override
	double Function(int)? get shouldHighlightPost => parent.shouldHighlightPost;

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
		_expandedPostContexts.clear();
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
	Post? crossThreadPostFromArchive(String board, int id) => parent.crossThreadPostFromArchive(board, id);
	@override
	(Object, StackTrace)? postFromArchiveError(String board, int id) => parent.postFromArchiveError(board, id);
	@override
	AsyncSnapshot<Post>? translatedPost(int postId) => parent.translatedPost(postId);
	@override
	AsyncSnapshot<String>? translatedTitle(int threadId) => parent.translatedTitle(threadId);
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
	final String board;
	@override
	final int primaryThreadId;
	@override
	final Imageboard imageboard;
	@override
	final ValueChanged<Post>? onNeedScrollToPost;
	@override
	final bool Function(int)? isPostOnscreen;
	@override
	final ValueChanged<int>? onPostSeen;
	@override
	final double Function(int)? shouldHighlightPost;
	@override
	final void Function(int, bool)? glowOtherPost;
	@override
	Future<void> Function(List<ParentAndChildIdentifier>)? onNeedUpdateWithStubItems;
	final Map<(String, int), bool> _isLoadingPostFromArchive = {};
	final Map<(String, int), Post> _crossThreadPostsFromArchive = {};
	final Map<(String, int), (Object, StackTrace)> _postFromArchiveErrors = {};
	final Iterable<int> semanticRootIds;
	final Map<int, AsyncSnapshot<String>> _translatedTitleSnapshots = {};
	final Map<int, AsyncSnapshot<Post>> _translatedPostSnapshots = {};
	@override
	List<Comparator<Post>> postSortingMethods;
	@override
	PostSpanZoneStyle style;
	final Map<int, Thread> _threads = {};
	final Map<int, Post> _postLookupTable = {};
	final Future<void> Function(Post)? onPostLoadedFromArchive;

	PostSpanRootZoneData({
		required Thread thread,
		required this.imageboard,
		this.onNeedScrollToPost,
		this.onPostLoadedFromArchive,
		this.isPostOnscreen,
		this.onPostSeen,
		this.shouldHighlightPost,
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
		this.onPostLoadedFromArchive,
		this.isPostOnscreen,
		this.onPostSeen,
		this.shouldHighlightPost,
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
		assert(thread.board.toLowerCase() == board.toLowerCase());
		if (!_threads.containsKey(thread.id)) {
			final threadState = imageboard.persistence.getThreadStateIfExists(thread.identifier);
			if (threadState != null) {
				_translatedPostSnapshots.addAll({
					for (final p in threadState.translatedPosts.values)
						p.id: AsyncSnapshot.withData(ConnectionState.done, p)
				});
				if (threadState.translatedTitle case String title) {
					_translatedTitleSnapshots[thread.id] ??= AsyncSnapshot.withData(ConnectionState.done, title);
				}
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
			_postFromArchiveErrors.remove((board, id));
			_isLoadingPostFromArchive[(board, id)] = true;
			notifyAllListeners();
			final newPost = await imageboard.site.getPostFromArchive(board, id, priority: RequestPriority.interactive);
			final cb = onPostLoadedFromArchive;
			if (board == this.board && newPost.threadId == primaryThreadId && cb != null) {
				await cb(newPost);
			}
			else {
				_crossThreadPostsFromArchive[(board, id)] = newPost;
				if (board == this.board) {
					newPost.replyIds = findThread(newPost.threadId)?.posts.where((p) => p.repliedToIds.contains(id)).map((p) => p.id).toList() ?? [];
				}
			}
			notifyAllListeners();
		}
		catch (e, st) {
			_postFromArchiveErrors[(board, id)] = (e, st);
		}
		lightHapticFeedback();
		_isLoadingPostFromArchive[(board, id)] = false;
		notifyAllListeners();
	}

	@override
	Post? crossThreadPostFromArchive(String board, int id) {
		return _crossThreadPostsFromArchive[(board, id)];
	}

	@override
	(Object, StackTrace)? postFromArchiveError(String board, int id) {
		return _postFromArchiveErrors[(board, id)];
	}

	@override
	AsyncSnapshot<Post>? translatedPost(int postId) => _translatedPostSnapshots[postId];
	@override
	AsyncSnapshot<String>? translatedTitle(int threadId) => _translatedTitleSnapshots[threadId];
	@override
	Future<void> translatePost(Post post) async {
		_translatedPostSnapshots[post.id] = const AsyncSnapshot.waiting();
		final title = findThread(post.threadId)?.title?.nonEmptyOrNull;
		if (post.id == post.threadId && title != null) {
			_translatedPostSnapshots[post.threadId] = const AsyncSnapshot.waiting();
		}
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
				extraMetadata: post.extraMetadata,
				passSinceYear: post.passSinceYear,
				capcode: post.capcode
			);
			_translatedPostSnapshots[post.id] = AsyncSnapshot.withData(ConnectionState.done, translatedPost);
			threadState?.translatedPosts[post.id] = translatedPost;
			if (post.id == post.threadId) {
				if (title != null) {
					final translatedTitle = await translateHtml(title, toLanguage: Settings.instance.translationTargetLanguage);
					_translatedTitleSnapshots[post.threadId] = AsyncSnapshot.withData(ConnectionState.done, translatedTitle);
					threadState?.translatedTitle = translatedTitle;
				}
			}
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
			_translatedTitleSnapshots.clear();
		}
		else {
			_translatedPostSnapshots.remove(postId);
			_translatedTitleSnapshots.remove(postId);
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
	final PostQuoteLinkSpan link;
	const ExpandingPost({
		required this.link,
		Key? key
	}) : super(key: key);
	
	@override
	Widget build(BuildContext context) {
		final zone = context.watch<PostSpanZoneData>();
		final post = zone.findPost(link.postId) ?? zone.crossThreadPostFromArchive(zone.board, link.postId);
		return zone.shouldExpandPost(link) ? TransformedMediaQuery(
			transformation: (context, mq) => mq.copyWith(textScaler: TextScaler.noScaling),
			child: (post == null) ? Center(
				child: Text('Could not find /${zone.board}/${link.postId}')
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
								child: BuildContextMapRegistrant(
									value: link,
									map: zone._expandedPostContexts,
									child: PostRow(
										post: post,
										onThumbnailTap: (attachment) {
											showGallery(
												context: context,
												attachments: [attachment],
												semanticParentIds: zone.stackIds,
												posts: {
													attachment: zone.imageboard.scope(post)
												},
												heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
											);
										},
										shrinkWrap: true,
										expandedInlineWithin: link
									)
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
	String? getEllipsizedFilename(int totalFiles) {
		final allowedLength = switch (totalFiles) {
			<= 1 => 50,
			2 => 40,
			3 => 30,
			4 => 20,
			int _ => 16
		};
		return filename.ellipsizeIfLonger(allowedLength);
	}
}

Iterable<TextSpan> _makeAttachmentInfo({
	required BuildContext? context,
	required Iterable<_AttachmentMetadata> metadata,
	required Settings settings
}) sync* {
	for (final attachment in metadata) {
		if (settings.showFilenameOnPosts && attachment.filename.isNotEmpty) {
			final ellipsizedFilename = attachment.getEllipsizedFilename(metadata.length);
			if (ellipsizedFilename != null && settings.ellipsizeLongFilenamesOnPosts) {
				yield TextSpan(
					text: '$ellipsizedFilename ',
					recognizer: context != null ? (TapGestureRecognizer(debugOwner: metadata)..onTap = () {
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
		// thread.replyCount may undercount in case of deleted posts
		return math.max(thread.posts.length - 1, thread.replyCount) - ((thread.posts.length - 1) - (thread.posts.binarySearchFirstIndexWhere((p) => p.id >= post.id) + 1));
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
	bool forceAbsoluteTime = false,
	ValueChanged<Attachment>? propagatedOnThumbnailTap,
	RegExp? highlightPattern
}) {
	final thread = zone.findThread(post.threadId);
	final (postIdNonRepeatingSegment, postIdRepeatingSegment) = splitPostId(post.id, site);
	final op = site.isPaged ? thread?.posts_.tryFirstWhere((p) => !p.isPageStub) : thread?.posts_.tryFirst;
	// During catalog-peek the post == op equality won't hold. Just use simple check.
	final thisPostIsOP = site.isPaged ? post == op : post.id == post.threadId;
	final thisPostIsPostedByOP = site.supportsUserInfo && post.name == op?.name || switch (thread?.posts_.tryFirst?.posterId) {
		String posterId => posterId == post.posterId,
		// This thread doesn't use posterId
		null => false
	};
	final combineFlagNames = settings.postDisplayFieldOrder.indexOf(PostDisplayField.countryName) == settings.postDisplayFieldOrder.indexOf(PostDisplayField.flag) + 1;
	const lineBreak = TextSpan(text: '\n');
	final isDeletedStub = post.isDeleted && post.text.isEmpty && post.attachments.isEmpty;
	final children = [
		if (post.archiveName != null) ...[
			WidgetSpan(
				child: Icon(CupertinoIcons.archivebox, color: theme.primaryColor.withOpacity(0.75), size: 15),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(
				text: ' ${post.archiveName} ',
				style: TextStyle(
					color: theme.primaryColor.withOpacity(0.75),
					fontWeight: FontWeight.w600,
					fontVariations: CommonFontVariations.w600
				)
			)
		],
		if (post.isDeleted) ...[
			TextSpan(
				text: '[Deleted] ',
				style: TextStyle(
					color: isDeletedStub ? null : theme.secondaryColor,
					fontWeight: FontWeight.w600,
					fontVariations: CommonFontVariations.w600
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
		if (thisPostIsOP && (thread?.title?.isNotEmpty ?? false)) PostTextSpan(
			'${(zone.translatedTitle(post.threadId)?.data ?? thread?.title)}\n',
		).build(context, post, zone, settings, theme, PostSpanRenderOptions(
			baseTextStyle: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.titleColor, fontSize: 17),
			highlightPattern: highlightPattern
		)),
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
						fontWeight: FontWeight.w600,
						fontVariations: CommonFontVariations.w600
					)
				)
			]
			else if (field == PostDisplayField.name) ...[
				if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && post.name == site.defaultUsername && post.trip == null)) TextSpan(
					text: settings.filterProfanity(site.formatUsername(post.name)) + ((isYourPost && post.trip == null) ? ' (You)' : '') + (thisPostIsPostedByOP ? ' (OP)' : ''),
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: isYourPost ? theme.secondaryColor : (thisPostIsPostedByOP ? theme.secondaryColor.shiftHue(20).shiftSaturation(-0.3) : null)),
					recognizer: (interactive && (post.name != zone.imageboard.site.defaultUsername || post.trip != null)) ? (TapGestureRecognizer(debugOwner: post)..onTap = () {
						final postIdsToShow = zone.findThread(post.threadId)?.posts.where((p) => p.name == post.name && p.trip == post.trip).map((p) => p.id).toList() ?? [];
						if (postIdsToShow.isEmpty) {
							alertError(context, 'Could not find any posts with name "${site.formatUsername(post.name)}". This is likely a problem with Chance...', null);
						}
						else {
							WeakNavigator.push(context, PostsPage(
								postsIdsToShow: postIdsToShow,
								zone: zone,
								onThumbnailTap: propagatedOnThumbnailTap,
								clearStack: true,
								header: (
									zone.imageboard.site.supportsUserInfo ||
									(
										post.name != zone.imageboard.site.defaultUsername &&
										(
											zone.imageboard.site.supportsSearch(post.board).options.name ||
											zone.imageboard.site.supportsSearch(null).options.name
										)
									) ||
									(
										post.trip != null &&
										(
											zone.imageboard.site.supportsSearch(post.board).options.trip ||
											zone.imageboard.site.supportsSearch(null).options.trip
										)
									)
								) ? UserInfoPanel(
									username: post.name,
									trip: post.trip,
									board: post.board
								) : null
							));
						}
					}) : null
				)
				else if (isYourPost) TextSpan(
					text: '(You)',
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.secondaryColor)
				),
				if (settings.showTripOnPosts && post.trip != null) TextSpan(
					text: '${settings.filterProfanity(post.trip!)} ',
					style: TextStyle(color: isYourPost ? theme.secondaryColor : null)
				)
				else if (settings.showNameOnPosts || isYourPost) const TextSpan(text: ' '),
				if (post.capcode != null) TextSpan(
					text: '## ${post.capcode} ',
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.secondaryColor.shiftHue(20).shiftSaturation(-0.3))
				),
				if (post.email != null) TextSpan(
					text: '${post.email} ',
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.secondaryColor.shiftHue(90).shiftSaturation(-0.3))
				)
			]
			else if (field == PostDisplayField.posterId && post.posterId != null) ...[
				IDSpan(
					id: post.posterId!,
					onPressed: interactive ? () {
						final postIdsToShow = zone.findThread(post.threadId)?.posts.where((p) => p.posterId == post.posterId).map((p) => p.id).toList() ?? [];
						if (postIdsToShow.isEmpty) {
							alertError(context, 'Could not find any posts with ID "${post.posterId}". This is likely a problem with Chance...', null);
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
				text: '${formatTime(post.time.toLocal(), forceFullDate: forceAbsoluteTime, withSecondsPrecision: site.hasSecondsPrecision)} '
			)
			else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts)
			 	if (!settings.showAbsoluteTimeOnPosts && forceAbsoluteTime) TextSpan(
					text: '${formatTime(post.time.toLocal(), forceFullDate: true, withSecondsPrecision: site.hasSecondsPrecision)} '
				)
				else RelativeTimeSpan(post.time.toLocal(), suffix: ' ago ')
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
					recognizer: (interactive && settings.tapPostIdToReply) ? (TapGestureRecognizer(debugOwner: post)..onTap = () {
						context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
					}) : null
				),
				if (postIdRepeatingSegment != null) TextSpan(
					text: postIdRepeatingSegment,
					style: TextStyle(
						color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.secondaryColor)
					),
					recognizer: (interactive && settings.tapPostIdToReply) ? (TapGestureRecognizer(debugOwner: post)..onTap = () {
						context.read<ReplyBoxZone>().onTapPostId(post.threadId, post.id);
					}) : null
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.lineBreak1 && settings.showLineBreak1InPostInfoRow) lineBreak
			else if (field == PostDisplayField.lineBreak2 && settings.showLineBreak2InPostInfoRow) lineBreak,
	];
	if (children.last == lineBreak &&
	    settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak1 &&
			settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak2) {
		// "Optional line-break" use case
		// The line-break is positioned before some optional fields
		// If the optional fields aren't there, get rid of the blank line by removing
		// the line break.
		children.removeLast();
	}
	if (site.supportsPostUpvotes || post.upvotes != null) {
		children.addAll([
			WidgetSpan(
				child: Icon(CupertinoIcons.arrow_up, size: 15, color: theme.primaryColorWithBrightness(0.5)),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(text: '${post.upvotes ?? '—'} ', style: TextStyle(color: theme.primaryColorWithBrightness(0.5)))
		]);
	}
	return TextSpan(
		style: isDeletedStub ? TextStyle(
			color: theme.primaryColorWithBrightness(0.5),
			fontSize: 16
		) : const TextStyle(fontSize: 16),
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
			style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.titleColor, fontSize: 17)
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
						fontWeight: FontWeight.w600,
						fontVariations: CommonFontVariations.w600
					)
				)
			]
			else if (field == PostDisplayField.name) ...[
				if (settings.showNameOnPosts && !(settings.hideDefaultNamesOnPosts && name == imageboard.site.defaultUsername)) TextSpan(
					text: '${settings.filterProfanity(name)} (You)${isOP ? ' (OP)' : ''}',
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.secondaryColor)
				)
				else TextSpan(
					text: '(You)',
					style: TextStyle(fontWeight: FontWeight.w600, fontVariations: CommonFontVariations.w600, color: theme.secondaryColor)
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.attachmentInfo && file != null) TextSpan(
				children: _makeAttachmentInfo(
					context: null,
					metadata: [
						(
							filename: post.overrideFilename ?? FileBasename.get(file),
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
				text: '${formatTime(time, withSecondsPrecision: imageboard.site.hasSecondsPrecision)} '
			)
			else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts && time != null) RelativeTimeSpan(time, suffix: ' ago ')
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
			else if (field == PostDisplayField.lineBreak1 && settings.showLineBreak1InPostInfoRow) lineBreak
			else if (field == PostDisplayField.lineBreak2 && settings.showLineBreak2InPostInfoRow) lineBreak,
	];
	if (children.last == lineBreak &&
	    settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak1 &&
			settings.postDisplayFieldOrder.last != PostDisplayField.lineBreak2) {
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