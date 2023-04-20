import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
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
import 'package:chan/services/bytes.dart';
import 'package:chan/services/css.dart';
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
import 'package:chan/widgets/widget_decoration.dart';
import 'package:csslib/visitor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
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
	final bool shrinkWrap;
	final RegExp? highlightPattern;
	final bool imageShareMode;
	final bool revealYourPosts;
	final bool hiddenWithinSpoiler;
	final ValueChanged<TaggedAttachment>? onThumbnailTap;
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
		this.shrinkWrap = false,
		this.highlightPattern,
		this.imageShareMode = false,
		this.revealYourPosts = true,
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
		TextStyle? baseTextStyle,
		bool? showCrossThreadLabel,
		bool? shrinkWrap,
		bool? addExpandingPosts,
		PointerEnterEventListener? onEnter,
		PointerExitEventListener? onExit,
		bool? hiddenWithinSpoiler,
		ValueChanged<TaggedAttachment>? onThumbnailTap,
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
		highlightPattern: highlightPattern,
		imageShareMode: imageShareMode,
		revealYourPosts: revealYourPosts,
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

class PostSpanDumpException implements Exception {
	final String message;
	PostSpanDumpException(this.message);
	@override
	String toString() => 'PostSpanDumpException($message)';
}

class PostSpanReadException implements Exception {
	final String message;
	PostSpanReadException(this.message);
	@override
	String toString() => 'PostSpanReadException($message)';
}

abstract class _HeightEstimator {
	Post get post;
	PostSpanZoneData? get zone;
	Size get characterSize;
	double get maxWidth;
	// TODO: FloatingPlaceholder
	void addRect(Size size);
	/// Performance optimization
	void addRects(Size size, int count);
	void addHardLineBreak();
	void addCharacters(int chars) {
		addRects(characterSize, chars);
	}
	void addPlaintext(String text) {
		final codeUnits = text.codeUnits;
		int run = 0;
		for (final codeUnit in codeUnits) {
			if (codeUnit == 0x0A) {
				if (run > 0) {
					addCharacters(run);
					run = 0;
				}
				addHardLineBreak();
			}
			else {
				run++;
			}
		}
		if (run > 0) {
			addCharacters(run);
		}
	}

	_HorizontallyScrollingHeightEstimator noWordWrap() {
		return _HorizontallyScrollingHeightEstimator(this);
	}
	_ScaledHeightEstimator scale(Offset scale) {
		return _ScaledHeightEstimator(this, scale);
	}
}

class _HeightEstimatorImpl extends _HeightEstimator {
	@override
	final Post post;
	@override
	final PostSpanZoneData? zone;
	@override
	final Size characterSize;
	@override
	final double maxWidth;
	double lineHeight;
	double currentHeight = 0;
	double currentWidth = 0;
	double _longestLineWidth = 0;
	_HeightEstimatorImpl(this.post, this.zone, this.characterSize, this.maxWidth) : lineHeight = characterSize.height;
	@override
	void addRects(Size size, int count) {
		if (count == 0) {
			return;
		}
		final width = size.width * count;
		if ((currentWidth + width) <= maxWidth) {
			lineHeight = math.max(lineHeight, size.height);
			currentWidth += width;
		}
		else {
			while (count > 0) {
				lineHeight = math.max(lineHeight, size.height);
				final toAdd = math.min(count, (maxWidth - currentWidth) ~/ size.width);
				currentWidth += (size.width * toAdd);
				count -= toAdd;
				if (count > 0) {
					addHardLineBreak();
				}
			}
		}
	}
	@override
	void addHardLineBreak() {
		currentHeight += lineHeight;
		lineHeight = characterSize.height;
		_longestLineWidth = math.max(_longestLineWidth, currentWidth);
		currentWidth = 0;
	}
	@override
	void addRect(Size size) {
		if (size.width >= maxWidth) {
			addHardLineBreak();
			lineHeight = size.height;
			_longestLineWidth = maxWidth;
			addHardLineBreak();
		}
		else if ((currentWidth + size.width) > maxWidth) {
			addHardLineBreak();
			lineHeight = size.height;
			currentWidth = size.width;
		}
		else {
			lineHeight = math.max(lineHeight, size.height);
			currentWidth += size.width;
		}
	}
	double get height {
		if (currentWidth > 0) {
			return currentHeight + lineHeight;
		}
		return currentHeight;
	}
	double get width {
		return math.max(_longestLineWidth, currentWidth);
	}
}

class _HorizontallyScrollingHeightEstimator extends _HeightEstimator {
	final _HeightEstimator parent;
	_HorizontallyScrollingHeightEstimator(this.parent);

	@override
	Post get post => parent.post;
	@override
	PostSpanZoneData? get zone => parent.zone;
	@override
	Size get characterSize => parent.characterSize;
	@override
	double get maxWidth => parent.maxWidth;

	@override
	void addRects(Size size, int count) {
		parent.addRects(Size(0, size.height), count);
	}

	@override
	void addRect(Size size) {
		parent.addRect(Size(0, size.height));
	}
	
	@override
	void addHardLineBreak() {
		parent.addHardLineBreak();
	}
}

class _ScaledHeightEstimator extends _HeightEstimator {
	final _HeightEstimator parent;
	final Offset _scale;
	_ScaledHeightEstimator(this.parent, this._scale);

	@override
	Post get post => parent.post;
	@override
	PostSpanZoneData? get zone => parent.zone;
	@override
	Size get characterSize => Size(parent.characterSize.width * _scale.dx, parent.characterSize.height * _scale.dy);
	@override
	double get maxWidth => parent.maxWidth;

	@override
	void addRects(Size size, int count) {
		parent.addRects(size, count);
	}

	@override
	void addRect(Size size) {
		parent.addRect(size);
	}
	
	@override
	void addHardLineBreak() {
		parent.addHardLineBreak();
	}
}

@immutable
sealed class PostSpan {
	const PostSpan();
	InlineSpan build(BuildContext context, Post post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options);
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true});
	void _estimateHeight(_HeightEstimator estimator);
	@override
	String toString() {
		final buffer = StringBuffer();
		buildText(buffer, null);
		return '$runtimeType(${buffer.toString()})';
	}
	Iterable<PostSpan> traverse(Post post);
	void dump(BytesBuilder builder, {bool writeTypeId = true});
	static PostSpan read(ByteReader buffer) {
		return switch (buffer.takeUint8()) {
			PostNodeSpan.kTypeId => PostNodeSpan.read(buffer),
			PostNodeSpan.kTypeId0 => PostNodeSpan.readN(buffer, 0),
			PostNodeSpan.kTypeId1 => PostNodeSpan.readN(buffer, 1),
			PostNodeSpan.kTypeId2 => PostNodeSpan.readN(buffer, 2),
			PostNodeSpan.kTypeId3 => PostNodeSpan.readN(buffer, 3),
			PostNodeSpan.kTypeId4 => PostNodeSpan.readN(buffer, 4),
			PostAttachmentsSpan.kTypeId => PostAttachmentsSpan.read(buffer),
			PostTextSpan.kTypeId => PostTextSpan.read(buffer),
			PostUnderlinedSpan.kTypeId => PostUnderlinedSpan.read(buffer),
			PostOverlinedSpan.kTypeId => PostOverlinedSpan.read(buffer),
			PostLineBreakSpan.kTypeId => PostLineBreakSpan.read(buffer),
			PostWeakQuoteLinkSpan.kTypeId => PostWeakQuoteLinkSpan.read(buffer),
			PostQuoteSpan.kTypeId => PostQuoteSpan.read(buffer),
			PostPinkQuoteSpan.kTypeId => PostPinkQuoteSpan.read(buffer),
			PostBlueQuoteSpan.kTypeId => PostBlueQuoteSpan.read(buffer),
			PostQuoteLinkSpan.kTypeId => PostQuoteLinkSpan.read(buffer),
			PostQuoteLinkWithContextSpan.kTypeId => PostQuoteLinkWithContextSpan.read(buffer),
			PostBoardLinkSpan.kTypeId => PostBoardLinkSpan.read(buffer),
			PostCodeSpan.kTypeId => PostCodeSpan.read(buffer),
			PostSpoilerSpan.kTypeId => PostSpoilerSpan.read(buffer),
			PostLinkSpan.kTypeId => PostLinkSpan.read(buffer),
			PostCatalogSearchSpan.kTypeId => PostCatalogSearchSpan.read(buffer),
			PostTeXSpan.kTypeId => PostTeXSpan.read(buffer),
			PostInlineImageSpan.kTypeId => PostInlineImageSpan.read(buffer),
			PostColorSpan.kTypeId => PostColorSpan.read(buffer),
			PostSecondaryColorSpan.kTypeId => PostSecondaryColorSpan.read(buffer),
			PostBoldSpan.kTypeId => PostBoldSpan.read(buffer),
			PostItalicSpan.kTypeId => PostItalicSpan.read(buffer),
			PostSuperscriptSpan.kTypeId => PostSuperscriptSpan.read(buffer),
			PostSubscriptSpan.kTypeId => PostSubscriptSpan.read(buffer),
			PostStrikethroughSpan.kTypeId => PostStrikethroughSpan.read(buffer),
			PostMonospaceSpan.kTypeId => PostMonospaceSpan.read(buffer),
			PostPopupSpan.kTypeId => PostPopupSpan.read(buffer),
			PostTableSpan.kTypeId => PostTableSpan.read(buffer),
			PostDividerSpan.kTypeId => PostDividerSpan.read(buffer),
			PostShiftJISSpan.kTypeId => PostShiftJISSpan.read(buffer),
			PostUserLinkSpan.kTypeId => PostUserLinkSpan.read(buffer),
			PostCssSpan.kTypeId => PostCssSpan.read(buffer),
			PostSmallTextSpan.kTypeId => PostSmallTextSpan.read(buffer),
			PostBigTextSpan.kTypeId => PostBigTextSpan.read(buffer),
			int other => throw PostSpanReadException('Unrecognized type id $other')
		};
	}
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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) => child.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
	@override
	void _estimateHeight(_HeightEstimator estimator) {
		child._estimateHeight(estimator);
	}
	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
		yield* child.traverse(post);
	}
}

class _PostWrapperSpan extends PostTerminalSpan {
	final InlineSpan span;
	const _PostWrapperSpan(this.span);
	@override
	InlineSpan build(context, post, zone, settings, theme, options) => span;
	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) => buffer.write(span.toPlainText());
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) => throw PostSpanDumpException('Can\'t encode _PostWrapperSpan($span)');
	@override
	void _estimateHeight(_HeightEstimator estimator) {
		switch (span) {
			case WidgetSpan(child: SizedBox(width: final width?, height: final height?)):
				estimator.addRect(Size(width, height));
			default:
				estimator.addPlaintext(span.toPlainText());
		}
	}
}

typedef PostNodeSpanConstraints = ({
	double maxHeight,
	double width,
	Size characterSize
});

class PostNodeSpan extends PostSpan {
	final List<PostSpan> children;
	const PostNodeSpan(this.children);

	static const kTypeId = 1;
	static const kTypeId0 = 36;
	static const kTypeId1 = 37;
	static const kTypeId2 = 38;
	static const kTypeId3 = 39;
	static const kTypeId4 = 40;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) {
			switch (children.length) {
				case 0:
					builder.addByte(kTypeId0);
				case 1:
					builder.addByte(kTypeId1);
				case 2:
					builder.addByte(kTypeId2);
				case 3:
					builder.addByte(kTypeId3);
				case 4:
					builder.addByte(kTypeId4);
				default:
					builder.addByte(kTypeId);
					builder.addIntVar(children.length);
			}
		}
		else {
			builder.addIntVar(children.length);
		}
		for (final child in children) {
			child.dump(builder);
		}
	}
	static PostNodeSpan read(ByteReader buffer) {
		final length = buffer.takeIntVar();
		return readN(buffer, length);
	}
	static PostNodeSpan readN(ByteReader buffer, int length) {
		return PostNodeSpan(List.generate(length, (_) => PostSpan.read(buffer), growable: false));
	}

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
		for (final child in children) {
			yield* child.traverse(post);
		}
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options, {
		InlineSpan? postInject,
		PostNodeSpanConstraints? constraints,
		bool stripTrailingNewline = false
	}) {
		final renderChildren = <InlineSpan>[];
		List<PostSpan> effectiveChildren = children;
		_PostWrapperSpan? postInjected;
		if (postInject != null) {
			postInjected = _PostWrapperSpan(postInject);
			effectiveChildren = children.toList()..add(postInjected);
		}
		_HeightEstimatorImpl? estimator;
		if (constraints != null) {
			estimator = _HeightEstimatorImpl(post, zone, constraints.characterSize, constraints.width);
		}
		for (int i = 0; i < effectiveChildren.length; i++) {
			renderChildren.add(effectiveChildren[i].build(context, post, zone, settings, theme, options));
			if (constraints != null && estimator != null) {
				effectiveChildren[i]._estimateHeight(estimator);
				if (estimator.currentHeight > constraints.maxHeight) {
					break;
				}
			}
		}
		if (stripTrailingNewline && renderChildren.isNotEmpty) {
			InlineSpan doStrip(InlineSpan span) {
				switch (span) {
					case TextSpan(children: final children?) when children.isNotEmpty:
						final newLast = doStrip(children.last);
						if (identical(newLast, children.last)) {
							return span;
						}
						final newChildren = children.toList(growable: false);
						newChildren.last = newLast;
						return span.copyWith(
							children: Wrapper(newChildren)
						);
					case TextSpan(text: final text?) when text.isNotEmpty:
						if (text.codeUnitAt(text.length - 1) != 0x0A) {
							return span;
						}
						return span.copyWith(
							text: Wrapper(text.substring(0, text.length - 1))
						);
					default:
						return span;
				}
			}
			renderChildren.last = doStrip(renderChildren.last);
		}
		return TextSpan(
			children: renderChildren
		);
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		for (final child in children) {
			child.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		for (final child in children) {
			child._estimateHeight(estimator);
		}
	}

	double estimateHeight(Post post, PostSpanZoneData? zone, Size characterSize, double maxWidth, {
		Size? postInject
	}) {
		final estimator = _HeightEstimatorImpl(post, zone, characterSize, maxWidth);
		_estimateHeight(estimator);
		if (postInject != null) {
			estimator.addRect(postInject);
		}
		return estimator.height;
	}

	@override
	String toString() => 'PostNodeSpan($children)';
}

class PostAttachmentsSpan extends PostTerminalSpan {
	final List<Attachment> attachments;
	const PostAttachmentsSpan(this.attachments);

	static const kTypeId = 2;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addIntVar(attachments.length);
		for (final attachment in attachments) {
			final bytes = Hive.encode(attachment);
			builder.addIntVar(bytes.length);
			builder.add(bytes);
		}
	}
	static PostAttachmentsSpan read(ByteReader buffer) {
		final length = buffer.takeIntVar();
		return PostAttachmentsSpan(List.generate(length, (_) {
			final length = buffer.takeIntVar();
			final object = Hive.decode(buffer.takeBytes(length));
			if (object is! Attachment) {
				throw PostSpanReadException('Did not get Attachment as expected: $object');
			}
			return object;
		}, growable: false));
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		if (options.showRawSource) {
			final buffer = StringBuffer();
			buildText(buffer, post);
			return TextSpan(text: buffer.toString());
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
					final taggedAttachment = TaggedAttachment(
						attachment: attachment,
						semanticParentIds: stackIds,
						imageboard: zone.imageboard,
						postId: post.id
					);
					return PopupAttachment(
						attachment: attachment,
						child: CupertinoButton(
							padding: EdgeInsets.zero,
							minimumSize: Size.zero,
							onPressed: options.onThumbnailTap?.bind1(taggedAttachment),
							child: ConstrainedBox(
								constraints: const BoxConstraints(
									minHeight: 75
								),
								child: AttachmentThumbnail(
									attachment: attachment,
									revealSpoilers: options.revealSpoilerImages,
									onLoadError: options.onThumbnailLoadError,
									hero: taggedAttachment,
									fit: settings.squareThumbnails ? BoxFit.cover : BoxFit.contain,
									shrinkHeight: !settings.squareThumbnails,
									width: post.spanFormat.hasLargeInlineAttachments ? 250 : null,
									height: post.spanFormat.hasLargeInlineAttachments ? 250 : null,
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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		for (final a in attachments) {
			if (forQuoteComparison) {
				// Make it look like a SiteXenforo quote (the only use case)
				buffer.write('[View Attachment ');
				buffer.write(a.id);
				buffer.write('](');
				buffer.write(a.url);
				buffer.write(')');
			}
			else {
				buffer.write(a.url);
			}
		}
		buffer.writeln();
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		final outputSize = Size.square(estimator.post.spanFormat.hasLargeInlineAttachments ? 250 : Settings.instance.thumbnailSize);
		final rects = attachments.map((attachment) {
			if (Settings.instance.squareThumbnails || attachment.aspectRatio <= 1) {
				return outputSize;
			}
			// shrinkHeight
			return Size(outputSize.width, math.max(75, outputSize.height / attachment.aspectRatio));
		}).toList();
		estimator.addRect(estimateWrapSize(
			maxWidth: estimator.maxWidth,
			rects: rects,
			spacing: 16,
			runSpacing: 16
		));
	}
}

class PostTextSpan extends PostTerminalSpan {
	final String text;
	const PostTextSpan(this.text);

	static const kTypeId = 3;

	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(text);
	}
	static PostTextSpan read(ByteReader buffer) {
		return PostTextSpan(buffer.takeString());
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		final children = <InlineSpan>[];
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
				color: options.overrideTextColor,
				decorationColor: options.overrideTextColor
			),
			recognizer: options.ignorePointer ? null : options.recognizer,
			recognizer2: options.ignorePointer ? null : options.recognizer2,
			onEnter: options.onEnter,
			onExit: options.onExit
		);
	}
	
	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addCharacters(text.length);
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write(text);
	}

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		yield this;
	}
}

class PostUnderlinedSpan extends PostSpanWithChild {
	const PostUnderlinedSpan(super.child);

	static const kTypeId = 4;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostUnderlinedSpan read(ByteReader buffer) {
		return PostUnderlinedSpan(PostSpan.read(buffer));
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.underline,
				decorationColor: options.baseTextStyle.color
			)
		));
	}
}

class PostOverlinedSpan extends PostSpanWithChild {
	const PostOverlinedSpan(super.child);

	static const kTypeId = 5;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostOverlinedSpan read(ByteReader buffer) {
		return PostOverlinedSpan(PostSpan.read(buffer));
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(
				decoration: TextDecoration.overline,
				decorationColor: options.baseTextStyle.color
			)
		));
	}
}

class PostLineBreakSpan extends PostTerminalSpan {
	const PostLineBreakSpan();

	static const kTypeId = 6;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
	}
	static PostLineBreakSpan read(ByteReader buffer) {
		return const PostLineBreakSpan();
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) =>  const TextSpan(text: '\n');

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.writeln();
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addHardLineBreak();
	}

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

	static const kTypeId = 7;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addIntVar(id);
		quote.dump(builder, writeTypeId: false);
		builder.addStringNullable(author);
	}
	static PostWeakQuoteLinkSpan read(ByteReader buffer) {
		final id = buffer.takeIntVar();
		final quote = PostQuoteSpan.read(buffer);
		final author = buffer.takeStringNullable();
		return PostWeakQuoteLinkSpan(
			id: id,
			quote: quote,
			author: author
		);
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		_getSpan(post).buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		_getSpan(estimator.post)._estimateHeight(estimator);
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

	static const kTypeId = 8;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostQuoteSpan read(ByteReader buffer) {
		return PostQuoteSpan(PostSpan.read(buffer));
	}

	@override
	InlineSpan build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.quoteColor),
			showEmbeds: false
		));
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (forQuoteComparison) {
			// Nested quotes not used
			return;
		}
		child.buildText(buffer, post, includeMarkup: includeMarkup);
	}

	@override
	String toString() => 'PostQuoteSpan($child)';
}

class PostPinkQuoteSpan extends PostQuoteSpan {
	const PostPinkQuoteSpan(super.child);

	static const kTypeId = 9;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostPinkQuoteSpan read(ByteReader buffer) {
		return PostPinkQuoteSpan(PostSpan.read(buffer));
	}

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

	static const kTypeId = 10;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostBlueQuoteSpan read(ByteReader buffer) {
		return PostBlueQuoteSpan(PostSpan.read(buffer));
	}

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

	static const kTypeId = 11;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (key != null) {
			throw PostSpanDumpException('Encoding PostQuoteLinkSpan.key is not supported: $key');
		}
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(board);
		builder.addIntVarNullable(threadId);
		builder.addIntVar(postId);
	}
	static PostQuoteLinkSpan read(ByteReader buffer) {
		final board = buffer.takeString();
		final threadId = buffer.takeIntVarNullable();
		final postId = buffer.takeIntVar();
		if (threadId == null) {
			return PostQuoteLinkSpan.dead(board: board, postId: postId);
		}
		return PostQuoteLinkSpan(board: board, threadId: threadId, postId: postId);
	}

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
		if (postId == actualThreadId) {
			text += ' (OP)';
		}
		final isOldThread = actualThreadId != zone.primaryThreadId && zone.findThread(actualThreadId) != null;
		if (isOldThread) {
			text += ' (Old thread)';
		}
		else if (options.showCrossThreadLabel) {
			text += ' (Cross-thread)';
		}
		final Color color;
		if (isOldThread) {
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
	(TextSpan, TapGestureRecognizer, bool) _buildNormalLink(BuildContext context, Post post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options, int? threadId) {
		String text = '>>$postId';
		Color color = theme.secondaryColor;
		if (postId == threadId) {
			text += ' (OP)';
		}
		if (threadId != zone.primaryThreadId) {
			color = theme.secondaryColor.shiftHue(-20);
			if (post.threadId != threadId) {
				text += ' (Old thread)';
			}
		}
		if (options.revealYourPosts &&
			(
				(threadId == zone.primaryThreadId && (zone.primaryThreadState?.youIds.contains(postId) ?? false))
				|| (threadId != null && (zone.imageboard.persistence.getThreadStateIfExists(ThreadIdentifier(board, threadId))?.youIds.contains(postId) ?? false))
			)
		) {
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
			_ => !expandedImmediatelyAbove ||
			     zone.shouldExpandPost(this) // Always allow re-collapsing
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
	(InlineSpan, TapGestureRecognizer) _build(BuildContext context, Post post, PostSpanZoneData zone, Settings settings, SavedTheme theme, PostSpanRenderOptions options) {
		int? actualThreadId = threadId;
		Post? thisPostLoaded = zone.crossThreadPostFromArchive(board, postId);
		if (board == zone.board) {
			thisPostLoaded ??= zone.findPost(postId);
		}
		if (thisPostLoaded != null) {
			actualThreadId = thisPostLoaded.threadId;
		}
		if (
			// Dead links do not know their thread
			actualThreadId == null ||
			// We think the post should be in this (or cross-loaded) thread, but we can't find it
			(thisPostLoaded == null && zone.findThread(actualThreadId) != null)
		) {
			return _buildDeadLink(context, zone, settings, theme, options);
		}

		if (ImageboardBoard.getKey(board) != ImageboardBoard.getKey(zone.board) || zone.findThread(actualThreadId) == null || (actualThreadId != zone.primaryThreadId && actualThreadId == postId)) {
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
					!enableInteraction ||
					options.showRawSource) {
				return (span.$1, span.$2);
			}
			final Widget child;
			if (zone.shouldExpandPost(this) == true) {
				child = KeyedSubtree(
					key: key ?? ValueKey(this),
					child: Text.rich(
						span.$1,
						textScaler: TextScaler.noScaling
					)
				);
			}
			else {
				child = HoverPopup(
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
			}
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
						builder: (context, c, _) => c == Colors.transparent ? child : ColorFiltered(
							colorFilter: ColorFilter.mode(c ?? Colors.transparent, BlendMode.srcATop),
							child: child
						)
					)
				)
			), span.$2);
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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return;
		}
		buffer.write('>>');
		buffer.write(postId.toString());
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		int characters = 2 + postId.numberOfDigits;
		if (threadId == null) {
			// Treated like normal text
			estimator.addCharacters(characters + 7); // ' (Dead)'
		}
		else {
			if (threadId == postId) {
				characters += 5; // ' (OP)'
			}
			if (threadId != estimator.zone?.primaryThreadId) {
				// Treated like normal text
				estimator.addCharacters(characters + 15); // ' (Cross-thread)'
			}
			else {
				// Doesn't line break
				estimator.addRect(Size(estimator.characterSize.width * characters, estimator.characterSize.height));
			}
		}
		if (estimator.zone case final zone? when board == zone.board && zone.shouldExpandPost(this)) {
			estimator.addHardLineBreak();
			zone.findPost(postId)?.span._estimateHeight(estimator);
			estimator.addHardLineBreak();
			estimator.addHardLineBreak();
		}
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

	static const kTypeId = 12;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		quoteLink.dump(builder, writeTypeId: false);
		context.dump(builder, writeTypeId: false);
	}
	static PostQuoteLinkWithContextSpan read(ByteReader buffer) {
		final quoteLink = PostQuoteLinkSpan.read(buffer);
		final context = PostQuoteSpan.read(buffer);
		return PostQuoteLinkWithContextSpan(quoteLink: quoteLink, context: context);
	}

	static const _kMaxSimilarityToShow = 0.85;

	@override
	build(context, post, zone, settings, theme, options) {
		final thePost = zone.findPost(quoteLink.postId);
		final theBuffer = StringBuffer();
		thePost?.span.buildText(theBuffer, thePost, forQuoteComparison: true);
		final theText = theBuffer.toString();
		final contextBuffer = StringBuffer();
		this.context.child.buildText(contextBuffer, post, forQuoteComparison: true);
		final contextText = contextBuffer.toString();
		final similarity = theText.similarityTo(contextText);
		return TextSpan(
			children: [
				quoteLink.build(context, post, zone, settings, theme, options),
				const TextSpan(text: '\n'),
				if (similarity < _kMaxSimilarityToShow) ...[
					// Partial quote, include the snippet
					this.context.build(context, post, zone, settings, theme, options),
					const TextSpan(text: '\n'),
				]
			]
		);
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (forQuoteComparison) {
			// Xenforo does not nest quotes
			return;
		}
		quoteLink.buildText(buffer, post, includeMarkup: includeMarkup);
		buffer.writeln();
		context.buildText(buffer, post, includeMarkup: includeMarkup);
		buffer.writeln();
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		quoteLink._estimateHeight(estimator);
		estimator.addHardLineBreak();
		final thePost = estimator.zone?.findPost(quoteLink.postId);
		final theBuffer = StringBuffer();
		thePost?.span.buildText(theBuffer, thePost, forQuoteComparison: true);
		final theText = theBuffer.toString();
		final contextBuffer = StringBuffer();
		context.child.buildText(contextBuffer, estimator.post, forQuoteComparison: true);
		final contextText = contextBuffer.toString();
		final similarity = theText.similarityTo(contextText);
		if (similarity < _kMaxSimilarityToShow) {
			context._estimateHeight(estimator);
			estimator.addHardLineBreak();
		}
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

	static const kTypeId = 13;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(board);
	}
	static PostBoardLinkSpan read(ByteReader buffer) {
		return PostBoardLinkSpan(buffer.takeString());
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write('>>/');
		buffer.write(board);
		buffer.write('/');
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addCharacters(board.length + 4);
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

	static const kTypeId = 14;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(text);
	}
	static PostCodeSpan read(ByteReader buffer) {
		return PostCodeSpan(buffer.takeString());
	}

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
		final lineCountFieldWidth = lineCount.numberOfDigitsLinear;
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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write('[code]');
		}
		buffer.write(text);
		if (includeMarkup) {
			buffer.write('[/code]');
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addHardLineBreak();
		estimator.noWordWrap().addPlaintext(text);
		estimator.addHardLineBreak();
	}
}

class PostSpoilerSpan extends PostSpanWithChild {
	final int id;
	final bool forceReveal;
	const PostSpoilerSpan(super.child, this.id, {this.forceReveal = false});

	static const kTypeId = 15;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
		builder.addIntVar(id);
		builder.addBool(forceReveal);
	}
	static PostSpoilerSpan read(ByteReader buffer) {
		final child = PostSpan.read(buffer);
		final id = buffer.takeIntVar();
		final forceReveal = buffer.takeBool();
		return PostSpoilerSpan(child, id, forceReveal: forceReveal);
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write('[spoiler]');
		}
		child.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
		if (includeMarkup) {
			buffer.write('[/spoiler]');
		}
	}
}

class PostLinkSpan extends PostTerminalSpan {
	final String url;
	final String? name;
	final EmbedData? embedData;
	const PostLinkSpan(this.url, {this.name, this.embedData});

	static const kTypeId = 16;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (embedData?.thumbnailWidget != null) {
			throw PostSpanDumpException('embedData.thumbnailWidget ${embedData?.thumbnailWidget} not supported');
		}
		if (embedData?.imageboardTarget != null) {
			throw PostSpanDumpException('embedData.imageboardTarget ${embedData?.imageboardTarget} not supported');
		}
		if (embedData?.attachments != null) {
			throw PostSpanDumpException('embedData.attachments ${embedData?.attachments} not supported');
		}
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(url);
		builder.addStringNullable(name);
		builder.addBool(embedData != null);
		if (embedData != null) {
			builder.addStringNullable(embedData?.title);
			builder.addStringNullable(embedData?.provider);
			builder.addStringNullable(embedData?.author);
			builder.addStringNullable(embedData?.thumbnailUrl);
		}
	}
	static PostLinkSpan read(ByteReader buffer) {
		final url = buffer.takeString();
		final name = buffer.takeStringNullable();
		EmbedData? embedData;
		if (buffer.takeBool()) {
			final title = buffer.takeStringNullable();
			final provider = buffer.takeStringNullable();
			final author = buffer.takeStringNullable();
			final thumbnailUrl = buffer.takeStringNullable();
			embedData = EmbedData(
				title: title,
				provider: provider,
				author: author,
				thumbnailUrl: thumbnailUrl
			);
		}
		return PostLinkSpan(url, name: name, embedData: embedData);
	}

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
						},
					'Open archived': () => openBrowser(
						context,
						Uri.https('archive.today', '/', {
							'run': '1',
							'url': cleanedUrl.toString()
						}),
						fromShareOne: true
					)
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
				EmbedData? data = snapshot.data;
				if (data?.attachments?.imageboard.key == zone.imageboard.key && (data?.attachments?.item.every((a) => post.attachments.any((b) => b.url == a.url)) ?? false)) {
					// Don't re-embed same attachments twice next to the real thumbnail
					// Just show the URL
					data = null;
				}
				imageboardTarget = data?.imageboardTarget;
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
				final attachments = data?.attachments;
				if (attachments != null && name == null) {
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
									semanticParentIds: stackIds,
									postId: post.id
								)).toList(),
								initialAttachment: attachment,
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
				String? byline = data?.provider;
				if (data?.author != null && !(data?.title != null && data!.title!.contains(data.author!))) {
					byline = byline == null ? data?.author : '${data?.author} - $byline';
				}
				if (data?.thumbnailWidget != null || data?.thumbnailUrl != null || data?.imageboardTarget != null) {
					final lines = [
						if (name != null && !url.contains(name!) && (data?.title?.contains(name!) != true)) name!,
						if (data?.title?.isNotEmpty ?? false) data!.title!
						else if (name == null || url.contains(name!)) url
					];
					Widget? tapChildChild = data?.thumbnailWidget;
					if (tapChildChild == null && data?.thumbnailUrl != null) {
						ImageProvider image = CNetworkImageProvider(
							data!.thumbnailUrl!,
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
						tapChildChild = WidgetDecoration(
							position: DecorationPosition.foreground,
							decoration: switch (data.attachments?.item.length) {
								int count when count > 1 => Align(
									alignment: Alignment.bottomRight,
									child: Container(
										decoration: BoxDecoration(
											color: theme.backgroundColor,
											border: BoxBorder.all(
												color: theme.primaryColorWithBrightness(0.2)
											),
											borderRadius: const BorderRadius.only(
												topLeft: Radius.circular(6)
											)
										),
										padding: const EdgeInsets.all(2),
										child: Text.rich(TextSpan(
											children: [
												TextSpan(text: '$count '),
												TextSpan(
													text: String.fromCharCode(Adaptive.icons.photos.codePoint),
													style: TextStyle(
														height: kTextHeightNone,
														fontFamily: Adaptive.icons.photos.fontFamily,
														package: Adaptive.icons.photos.fontPackage
													)
												),
												const TextSpan(text: ' ')
											],
											style: TextStyle(color: theme.primaryColor, fontSize: 16)
										))
									)
								),
								_ => null
							},
							child: ExtendedImage(
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
							),
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
					if (tapChildChild == null && data?.imageboardTarget != null) {
						tapChildChild = ImageboardIcon(
							imageboardKey: data?.imageboardTarget?.$1.key,
							boardName: data?.imageboardTarget?.$2.board
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
						else if (snapshot?.data?.attachments case final attachments?) {
							final stackIds = zone.stackIds.toList();
							if (stackIds.isNotEmpty) {
								stackIds.removeLast();
							}
							showGalleryPretagged(
								context: context,
								attachments: attachments.item.map((a) => TaggedAttachment(
									attachment: a,
									imageboard: attachments.imageboard,
									semanticParentIds: stackIds,
									postId: post.id
								)).toList(),
								heroOtherEndIsBoxFitCover: true
							);
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
				decorationColor: theme.linkColor,
				decoration: TextDecoration.underline,
				color: theme.linkColor
			)
		));
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write(name ?? url);
		}
		else if (name != null && !url.endsWith(name!)) {
			buffer.write('[');
			buffer.write(name);
			buffer.write('](');
			buffer.write(url);
			buffer.write(')');
		}
		else {
			buffer.write(url);
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		// Complete hack
		final id = 'noembed $url';
		if ((estimator.zone?._futures[id]?.data ?? PostSpanZoneData._globalFutures[id]?.data) case EmbedData data when data.thumbnailUrl != null || data.thumbnailWidget != null || data.imageboardTarget != null) {
			final Size imageSize;
			if (data.thumbnailUrl != null) {
				imageSize = const Size(75, 75);
			}
			else if (data.thumbnailWidget case SizedBox(width: final width?, height: final height?)) {
				imageSize = Size(width, height);
			}
			else {
				imageSize = const Size(16, 16);
			}
			final otherWidth = 32 + imageSize.width;
			final estimator2 = _HeightEstimatorImpl(estimator.post, estimator.zone, estimator.characterSize, estimator.maxWidth - otherWidth);
			if (name case final name? when !url.contains(name) && (data.title?.contains(name) != true)) {
				estimator2.addPlaintext(name);
				estimator2.addHardLineBreak();
			}
			if (data.title case final title? when title.isNotEmpty) {
				estimator2.addPlaintext(title);
				estimator2.addHardLineBreak();
			}
			else if (name == null || url.contains(name!)) {
				estimator2.addCharacters(url.length);
				estimator2.addHardLineBreak();
			}
			estimator.addRect(Size(otherWidth + estimator2.width, 32 + math.max(imageSize.height, estimator2.height)));
		}
		else {
			if (name != null && !url.endsWith(name!)) {
				estimator.addCharacters(name!.length + url.length + 4);
			}
			else {
				estimator.addCharacters(url.length);
			}
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

	static const kTypeId = 17;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(board);
		builder.addString(query);
	}
	static PostCatalogSearchSpan read(ByteReader buffer) {
		final board = buffer.takeString();
		final query = buffer.takeString();
		return PostCatalogSearchSpan(board: board, query: query);
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write('>>>/');
		buffer.write(board);
		buffer.write('/');
		buffer.write(query);
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addCharacters(board.length + 5 + query.length);
	}
}

class PostTeXSpan extends PostTerminalSpan {
	final String tex;
	const PostTeXSpan(this.tex);

	static const kTypeId = 18;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(tex);
	}
	static PostTeXSpan read(ByteReader buffer) {
		return PostTeXSpan(buffer.takeString());
	}

	@override
	build(context, post, zone, settings, theme, options) {
		final child = TexWidget(
			tex: tex,
			color: options.overrideTextColor ?? options.baseTextStyle.color
		);
		if (options.showRawSource) {
			final buffer = StringBuffer();
			buildText(buffer, post);
			return TextSpan(text: buffer.toString());
		}
		return WidgetSpan(
			alignment: PlaceholderAlignment.middle,
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				child: child
			)
		);
	}
	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write('[math]');
		}
		buffer.write(tex);
		if (includeMarkup) {
			buffer.write('[/math]');
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.scale(const Offset(1.25, 2)).addCharacters(tex.length);
	}
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

	static const kTypeId = 19;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(src);
		builder.addIntVar(width);
		builder.addIntVar(height);
	}
	static PostInlineImageSpan read(ByteReader buffer) {
		final src = buffer.takeString();
		final width = buffer.takeIntVar();
		final height = buffer.takeIntVar();
		return PostInlineImageSpan(src: src, width: width, height: height);
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write(src);
	}
	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addRect(Size(width.toDouble(), height.toDouble()));
	}
}

class PostColorSpan extends PostSpanWithChild {
	final Color? color;
	
	const PostColorSpan(super.child, this.color);

	static const kTypeId = 20;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
		builder.addIntVarNullable(color?.toARGB32());
	}
	static PostColorSpan read(ByteReader buffer) {
		final child = PostSpan.read(buffer);
		final argb32 = buffer.takeIntVarNullable();
		return PostColorSpan(child, argb32 == null ? null : Color(argb32));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: color)
		));
	}
}

class PostSecondaryColorSpan extends PostSpanWithChild {
	const PostSecondaryColorSpan(super.child);

	static const kTypeId = 21;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostSecondaryColorSpan read(ByteReader buffer) {
		return PostSecondaryColorSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(color: theme.secondaryColor)
		));
	}
}

class PostBoldSpan extends PostSpanWithChild {
	const PostBoldSpan(super.child);

	static const kTypeId = 22;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostBoldSpan read(ByteReader buffer) {
		return PostBoldSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold)
		));
	}
}

class PostItalicSpan extends PostSpanWithChild {
	const PostItalicSpan(super.child);

	static const kTypeId = 23;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostItalicSpan read(ByteReader buffer) {
		return PostItalicSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontStyle: FontStyle.italic)
		));
	}
}

class PostSuperscriptSpan extends PostSpanWithChild {
	const PostSuperscriptSpan(super.child);

	static const kTypeId = 24;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostSuperscriptSpan read(ByteReader buffer) {
		return PostSuperscriptSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontFeatures: const [FontFeature.superscripts()])
		));
	}
}

class PostSubscriptSpan extends PostSpanWithChild {
	const PostSubscriptSpan(super.child);

	static const kTypeId = 25;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostSubscriptSpan read(ByteReader buffer) {
		return PostSubscriptSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontFeatures: const [FontFeature.subscripts()])
		));
	}
}

class PostStrikethroughSpan extends PostSpanWithChild {
	const PostStrikethroughSpan(super.child);

	static const kTypeId = 26;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostStrikethroughSpan read(ByteReader buffer) {
		return PostStrikethroughSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(decoration: TextDecoration.lineThrough, decorationColor: options.baseTextStyle.color)
		));
	}
}

class PostMonospaceSpan extends PostSpanWithChild {
	const PostMonospaceSpan(super.child);

	static const kTypeId = 27;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostMonospaceSpan read(ByteReader buffer) {
		return PostMonospaceSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: GoogleFonts.ibmPlexMono(textStyle: options.baseTextStyle)
		));
	}
}


class PostPopupSpan extends PostSpanWithChild {
	final String title;
	const PostPopupSpan({
		required PostSpan popup,
		required this.title
	}) : super(popup);

	static const kTypeId = 28;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
		builder.addString(title);
	}
	static PostPopupSpan read(ByteReader buffer) {
		final popup = PostSpan.read(buffer);
		final title = buffer.takeString();
		return PostPopupSpan(popup: popup, title: title);
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write(title);
		if (includeMarkup) {
			buffer.writeln();
			child.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addCharacters(title.length);
	}
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

	static const kTypeId = 29;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addIntVar(rows.length);
		for (final row in rows) {
			builder.addIntVar(row.length);
			for (final col in row) {
				col.dump(builder);
			}
		}
	}
	static PostTableSpan read(ByteReader buffer) {
		final length = buffer.takeIntVar();
		return PostTableSpan(List.generate(length, (_) {
			final length = buffer.takeIntVar();
			return List.generate(length, (_) {
				return PostSpan.read(buffer);
			});
		}));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		if (options.showRawSource) {
			final buffer = StringBuffer();
			buildText(buffer, post);
			return TextSpan(text: buffer.toString());
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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		for (final row in rows) {
			for (int i = 0; i < row.length; i++) {
				final col = row[i];
				col.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
				if (i < row.length - 1) {
					buffer.write(', ');
				}
			}
			buffer.writeln();
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		// Horizontally scrolling
		for (final _ in rows) {
			estimator.addHardLineBreak();
		}
	}

	@override
	Iterable<PostSpan> traverse(Post post) sync* {
		for (final row in rows) {
			for (final child in row) {
				yield* child.traverse(post);
			}
		}
	}
}

class PostDividerSpan extends PostTerminalSpan {
	const PostDividerSpan();

	static const kTypeId = 30;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
	}
	static PostDividerSpan read(ByteReader buffer) {
		return const PostDividerSpan();
	}

	@override
	build(context, post, zone, settings, theme, options) => const WidgetSpan(
		child: ChanceDivider(height: 16)
	);

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.writeln();
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addHardLineBreak();
	}
}

class PostShiftJISSpan extends PostTerminalSpan {
	final String text;

	const PostShiftJISSpan(this.text);

	static const kTypeId = 31;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(text);
	}
	static PostShiftJISSpan read(ByteReader buffer) {
		return PostShiftJISSpan(buffer.takeString());
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write('[sjis]');
		}
		buffer.write(text);
		if (includeMarkup) {
			buffer.write('[/sjis]');
		}
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		// Submona font is smaller than usual
		estimator.scale(const Offset(0.91, 0.91)).noWordWrap().addPlaintext(text);
	}
}

class PostUserLinkSpan extends PostTerminalSpan {
	final String username;

	const PostUserLinkSpan(this.username);

	static const kTypeId = 32;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		builder.addString(username);
	}
	static PostUserLinkSpan read(ByteReader buffer) {
		return PostUserLinkSpan(buffer.takeString());
	}

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
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		buffer.write('/u/');
		buffer.write(username);
	}

	@override
	void _estimateHeight(_HeightEstimator estimator) {
		estimator.addCharacters(username.length + 3);
	}
}

class PostCssSpan extends PostSpanWithChild {
	final String css;

	const PostCssSpan(super.child, this.css);

	static const kTypeId = 33;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
		builder.addString(css);
	}
	static PostCssSpan read(ByteReader buffer) {
		final child = PostSpan.read(buffer);
		final css = buffer.takeString();
		return PostCssSpan(child, css);
	}

	@override
	build(context, post, zone, settings, theme, options) {
		final unrecognizedParts = <MapEntry<String, Expression>>[];
		TextStyle style = options.baseTextStyle;
		bool foundBackgroundClipText = false;
		bool foundTextFillColorTransparent = false;
		for (final part in resolveInlineCss(css).entries) {
			final key = part.key;
			final value = part.value;
			if ((key == 'background-color' || key == 'background')) {
				final color = value.color;
				if (color != null) {
					style = style.copyWith(backgroundColor: color);
					continue;
				}
			}
			if (key == 'color') {
				final color = value.color;
				if (color != null) {
					style = style.copyWith(color: color);
					continue;
				}
			}
			if (value case Expressions(expressions: [FunctionTerm(text: 'linear-gradient')]) when key == 'background') {
				// Not really possible to construct the proper rect. we don't know where we are
				// Just do a reasonable few words one and loop it
				// Smaller children should have tighter loop to make sure all colors seen in uncertain offset intersection
				final buffer = StringBuffer();
				child.buildText(buffer, post, includeMarkup: false);
				final rect = Rect.fromLTWH(0, 0, buffer.length * 5, 17);
				final gradient = value.linearGradient(rect, tileMode: ui.TileMode.mirror);
				if (gradient == null) {
					unrecognizedParts.add(part);
					continue;
				}
				style = style.copyWith(background: Paint()..shader = gradient);
			}
			else if (key == 'font-weight' && value.string == 'bold') {
				style = style.copyWith(fontWeight: FontWeight.bold, fontVariations: CommonFontVariations.bold);
			}
			else if (key == 'font-family') {
				style = style.copyWith(fontFamily: value.string);
			}
			else if (key == 'text-shadow') {
				final shadows = value.shadows;
				if (shadows == null) {
					unrecognizedParts.add(part);
					continue;
				}
				style = style.copyWith(shadows: shadows);
			}
			else if (key == '-webkit-background-clip' && value.string == 'text') {
				foundBackgroundClipText = true;
			}
			else if (key == '-webkit-text-fill-color' && value.string == 'transparent') {
				foundTextFillColorTransparent = true;
			}
			else if (key == 'animation' || key == 'padding' || key == 'border-radius') {
				// Ignore
			}
			else {
				unrecognizedParts.add(part);
			}
		}

		if (foundBackgroundClipText && foundTextFillColorTransparent) {
			style = style.copyWith(background: Paint()..color = Colors.transparent, foreground: style.background);
		}

		if (unrecognizedParts.isEmpty) {
			return child.build(context, post, zone, settings, theme, options.copyWith(
				baseTextStyle: style
			));
		}
		else {
			return TextSpan(
				children: [
					TextSpan(text: '<span style="${unrecognizedParts.map((p) => '${p.key}: ${p.value.string}').join('; ')}">'),
					child.build(context, post, zone, settings, theme, options.copyWith(
						baseTextStyle: style
					)),
					const TextSpan(text: '</span>')
				]
			);
		}
	}

	@override
	void buildText(StringBuffer buffer, Post? post, {bool forQuoteComparison = false, bool includeMarkup = true}) {
		if (includeMarkup) {
			buffer.write('<span style="');
			buffer.write(css);
			buffer.write('">');
		}
		child.buildText(buffer, post, forQuoteComparison: forQuoteComparison, includeMarkup: includeMarkup);
		if (includeMarkup) {
			buffer.write('</span>');
		}
	}
}

class PostSmallTextSpan extends PostSpanWithChild {
	const PostSmallTextSpan(super.child);

	static const kTypeId = 34;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostSmallTextSpan read(ByteReader buffer) {
		return PostSmallTextSpan(PostSpan.read(buffer));
	}

	@override
	build(context, post, zone, settings, theme, options) {
		return child.build(context, post, zone, settings, theme, options.copyWith(
			baseTextStyle: options.baseTextStyle.copyWith(fontSize: 14)
		));
	}
}

class PostBigTextSpan extends PostSpanWithChild {
	const PostBigTextSpan(super.child);

	static const kTypeId = 35;
	@override
	void dump(BytesBuilder builder, {bool writeTypeId = true}) {
		if (writeTypeId) builder.addByte(kTypeId);
		child.dump(builder);
	}
	static PostBigTextSpan read(ByteReader buffer) {
		return PostBigTextSpan(PostSpan.read(buffer));
	}

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
	PostSpanZoneData? peekChildZoneFor(int? postId, {
		PostSpanZoneStyle? style,
		int? fakeHoistedRootId,
		ValueChanged<Post>? onNeedScrollToPost,
		PostQuoteLinkSpan? link
	}) {
		final key = (postId, style, fakeHoistedRootId, onNeedScrollToPost, link);
		return _children[key];
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
	Future<void> translatePost(Post post, {required bool interactive});
	void clearTranslatedPosts([int? postId]);

	Thread? findThread(int threadId);
	Post? findPost(int? postId);

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
	Post? findPost(int? postId) => parent.findPost(postId);

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
	Future<void> translatePost(Post post, {required bool interactive}) async {
		try {
			final x = parent.translatePost(post, interactive: interactive);
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

	void insertCrossThreadPost(Post post) {
		_crossThreadPostsFromArchive[(post.board, post.id)] = post;
		notifyListeners();
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
	Future<void> translatePost(Post post, {required bool interactive}) async {
		final originalMissingLanguageSnapshot = switch (_translatedPostSnapshots[post.id]) {
			AsyncSnapshot<Post> s when s.error is NativeTranslationNeedsInteractionException => s,
			_ => null
		};
		_translatedPostSnapshots[post.id] = const AsyncSnapshot.waiting();
		final title = findThread(post.threadId)?.title?.nonEmptyOrNull;
		if (post.id == post.threadId && title != null) {
			_translatedPostSnapshots[post.threadId] = const AsyncSnapshot.waiting();
		}
		notifyListeners();
		final threadState = imageboard.persistence.getThreadStateIfExists(post.threadIdentifier);
		try {
			final translated = await translateHtml(post.text, toLanguage: Settings.instance.translationTargetLanguage, interactive: interactive);
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
					final translatedTitle = await translateHtml(title, toLanguage: Settings.instance.translationTargetLanguage, interactive: interactive);
					_translatedTitleSnapshots[post.threadId] = AsyncSnapshot.withData(ConnectionState.done, translatedTitle);
					threadState?.translatedTitle = translatedTitle;
				}
			}
			threadState?.save();
		}
		on NativeTranslationCancelledException catch (e, st) {
			_translatedPostSnapshots[post.id] = originalMissingLanguageSnapshot ?? AsyncSnapshot.withError(ConnectionState.done, e, st);
			rethrow;
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
	Post? findPost(int? postId) => _postLookupTable[postId];

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
											showGalleryPretagged(
												context: context,
												attachments: [attachment],
												posts: {
													attachment.attachment: zone.imageboard.scope(post)
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
	final lastIndex = digits.length - 1;
	final lastDigit = digits.codeUnitAt(lastIndex);
	if (Settings.instance.highlightRepeatingDigitsInPostIds && site.explicitIds) {
		for (; repeatingDigits < digits.length; repeatingDigits++) {
			if (digits.codeUnitAt(lastIndex - repeatingDigits) != lastDigit) {
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
	ValueChanged<TaggedAttachment>? propagatedOnThumbnailTap,
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
				child: Icon(CupertinoIcons.archivebox, color: theme.primaryColor.withValues(alpha: 0.75), size: 15),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(
				text: ' ${post.archiveName} ',
				style: TextStyle(
					color: theme.primaryColor.withValues(alpha: 0.75),
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
				style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.75))
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
				style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.5))
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
					style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.75), fontSize: 16)
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.countryName && settings.showCountryNameOnPosts && post.flag != null && !combineFlagNames) TextSpan(
				text: '${post.flag!.name} ',
				style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.75))
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
						color: (post.threadId != zone.primaryThreadId ? theme.secondaryColor.shiftHue(-20) : theme.primaryColor).withValues(alpha: 0.5)
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
		final hot = settings.showHotPostsInScrollbar && switch((post.upvotes, zone.findPost(post.parentId)?.upvotes)) {
			(int upv, int parentUpv) => parentUpv > 0 && upv > (parentUpv + math.min(parentUpv * 1.4, 15)),
			_ => false
		};
		children.addAll([
			WidgetSpan(
				child: Icon(CupertinoIcons.arrow_up, size: 15, color: hot ? theme.secondaryColor.shiftHue(90) : theme.primaryColorWithBrightness(0.5)),
				alignment: PlaceholderAlignment.middle
			),
			TextSpan(text: '${post.upvotes ?? '—'} ', style: TextStyle(color: hot ? theme.secondaryColor.shiftHue(90) : theme.primaryColorWithBrightness(0.5)))
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
				style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.5))
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
					style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.75), fontSize: 16)
				),
				const TextSpan(text: ' ')
			]
			else if (field == PostDisplayField.countryName && settings.showCountryNameOnPosts && post.flag != null && !combineFlagNames) TextSpan(
				text: '${post.flag!.name} ',
				style: TextStyle(color: theme.primaryColor.withValues(alpha: 0.75))
			)
			else if (field == PostDisplayField.absoluteTime && settings.showAbsoluteTimeOnPosts && time != null) TextSpan(
				text: '${formatTime(time, withSecondsPrecision: imageboard.site.hasSecondsPrecision)} '
			)
			else if (field == PostDisplayField.relativeTime && settings.showRelativeTimeOnPosts && time != null) RelativeTimeSpan(time, suffix: ' ago ')
			else if (field == PostDisplayField.postId && postIdNonRepeatingSegment.isNotEmpty) ...[
				TextSpan(
					text: '${settings.showNoBeforeIdOnPosts ? 'No. ' : ''}$postIdNonRepeatingSegment',
					style: TextStyle(
						color: theme.primaryColor.withValues(alpha: 0.5)
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