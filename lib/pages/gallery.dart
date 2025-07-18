import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/overscroll_modal.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/services/audio.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/launch_url_externally.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/status_bar.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_inkwell.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/media_thumbnail.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:home_indicator/home_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

const double _thumbnailSize = 60;

class GalleryLeftIntent extends Intent {
	const GalleryLeftIntent();
}

class GalleryRightIntent extends Intent {
	const GalleryRightIntent();
}

class GalleryToggleChromeIntent extends Intent {
	const GalleryToggleChromeIntent();
}

class _FasterSnappingPageScrollPhysics extends ScrollPhysics {
  const _FasterSnappingPageScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  _FasterSnappingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FasterSnappingPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
		mass: 0.3,
		stiffness: 150,
		ratio: 1.1,
	);
}

class _VeryFastSnappingPageScrollPhysics extends ScrollPhysics {
  const _VeryFastSnappingPageScrollPhysics({ScrollPhysics? parent})
      : super(parent: parent);

  @override
  _VeryFastSnappingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _VeryFastSnappingPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
		mass: 80,
		stiffness: 100,
		damping: 2,
	);
}

class _PaddedRectClipper extends CustomClipper<Rect> {
	final EdgeInsets padding;

	const _PaddedRectClipper(this.padding);

	@override
	Rect getClip(Size size) => padding.inflateRect(Offset.zero & size);

	@override
	bool shouldReclip(_PaddedRectClipper oldClipper) => padding != oldClipper.padding;
}

class GalleryPage extends StatefulWidget {
	final List<TaggedAttachment> attachments;
	final Map<Attachment, Uri> initialGoodSources;
	final Map<Attachment, Uri> overrideSources;
	final PostSpanZoneData? zone;
	final Map<Attachment, ImageboardScoped<Thread>> threads;
	final Map<Attachment, ImageboardScoped<Post>> posts;
	final ValueChanged<ImageboardScoped<Thread>>? onThreadSelected;
	final ReplyBoxZone? replyBoxZone;
	final TaggedAttachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<TaggedAttachment>? onChange;
	final bool allowScroll;
	final bool allowPop;
	final bool allowContextMenu;
	final bool allowChrome;
	final bool updateOverlays;
	final bool useHeroDestinationWidget;
	final bool heroOtherEndIsBoxFitCover;
	final List<ContextMenuAction> Function(TaggedAttachment)? additionalContextMenuActionsBuilder;
	final bool initiallyShowGrid;
	final Axis axis;

	const GalleryPage({
		required this.attachments,
		this.overrideSources = const {},
		this.initialGoodSources = const {},
		this.zone,
		this.threads = const {},
		this.posts = const {},
		this.onThreadSelected,
		this.replyBoxZone,
		required this.initialAttachment,
		this.initiallyShowChrome = false,
		this.onChange,
		this.allowScroll = true,
		this.allowPop = true,
		this.allowChrome = true,
		this.allowContextMenu = true,
		this.updateOverlays = true,
		this.useHeroDestinationWidget = false,
		required this.heroOtherEndIsBoxFitCover,
		this.additionalContextMenuActionsBuilder,
		this.initiallyShowGrid = false,
		this.axis = Axis.horizontal,
		Key? key
	}) : super(key: key);

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
	late int currentIndex;
	TaggedAttachment get currentAttachment => widget.attachments[currentIndex];
	AttachmentViewerController get currentController => _getController(currentAttachment);
	late final ScrollController thumbnailScrollController;
	late final ScrollController _gridViewScrollController;
	late final ExtendedPageController pageController;
	late bool showChrome;
	bool showChromeOnce = false;
	bool showingOverlays = true;
	final Key _pageControllerKey = GlobalKey(debugLabel: 'GalleryPage._pageControllerKey');
	final Key _thumbnailsKey = GlobalKey(debugLabel: 'GalleryPage._thumbnailsKey');
	late final BufferedListenable _scrollCoalescer;
	double? _lastpageControllerPixels;
	bool _animatingNow = false;
	final _imageSearchButtonKey = GlobalKey(debugLabel: 'GalleryPage._imageSearchButtonKey');
	final _shareButtonKey = GlobalKey(debugLabel: 'GalleryPage._shareButtonKey');
	late final EasyListenable _slideListenable;
	bool _hideRotateButton = false;
	final Map<TaggedAttachment, AttachmentViewerController> _controllers = {};
	late final ValueNotifier<bool> _shouldShowPosition;
	late final EasyListenable _currentAttachmentChanged;
	late final DraggableScrollableController _scrollSheetController;
	final _draggableScrollableSheetKey = GlobalKey(debugLabel: 'GalleryPage._draggableScrollableSheetKey');
	bool _gridViewDesynced = false;
	bool _thumbnailsDesynced = false;
	/// To prevent Hero when entering with grid initially enabled
	bool _doneInitialTransition = false;
	bool _autoRotate = Settings.instance.autoRotateInGallery;
	final Map<Attachment, int> _replyCounts = {};
	/// To show when multiple attachments are on the same post/thread
	final Map<Attachment, (int, int)> _peers = {};
	/// Lazy way to prevent double download of ephemeral attachments, or SavedAttachments
	/// in the same app session.
	static final Set<Uri> _downloadedOverrideSources = {};

	@override
	void initState() {
		super.initState();
		if (widget.initiallyShowGrid) {
			// Hard to mute if loud when grid is covering
			Settings.instance.setMuteAudio(true);
		}
		// Initialize _replyCounts
		for (final attachment in widget.attachments) {
			final thread = widget.threads[attachment.attachment];
			if (thread != null) {
				_replyCounts[attachment.attachment] = thread.item.replyCount;
				continue;
			}
			final post = widget.posts[attachment.attachment];
			if (post != null) {
				_replyCounts[attachment.attachment] = post.item.replyCount;
			}
		}
		// Initialize _peers
		if ((widget.threads.values.toSet().length + widget.posts.values.toSet().length) > 1) {
			for (final thread in widget.threads.values) {
				final length = thread.item.attachments.length;
				if (length > 1) {
					for (final (i, attachment) in thread.item.attachments.indexed) {
						_peers[attachment] = (i + 1, length);
					}
				}
			}
			for (final post in widget.posts.values) {
				final length = post.item.attachments.length;
				if (length > 1) {
					for (final (i, attachment) in post.item.attachments.indexed) {
						_peers[attachment] = (i + 1, length);
					}
				}
			}
		}
		_scrollCoalescer = BufferedListenable(const Duration(milliseconds: 10));
		_slideListenable = EasyListenable();
		_shouldShowPosition = ValueNotifier(false);
		_currentAttachmentChanged = EasyListenable();
		_scrollSheetController = DraggableScrollableController();
		showChrome = widget.initiallyShowGrid || widget.initiallyShowChrome;
		currentIndex = (widget.initialAttachment != null) ? max(0, widget.attachments.indexOf(widget.initialAttachment!)) : 0;
		pageController = ExtendedPageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_scrollCoalescer.didUpdate);
		_scrollCoalescer.addListener(__onPageControllerUpdate);
		final attachment = widget.attachments[currentIndex];
		if (Settings.instance.autoloadAttachments || Settings.instance.alwaysAutoloadTappedAttachment) {
			_getController(attachment).loadFullAttachment().then((x) {
				if (!mounted) return;
				_currentAttachmentChanged.didUpdate();
			});
		}
		_updateOverlays(showChrome);
		Future.delayed(const Duration(milliseconds: 500), () {
			if (mounted) {
				setState(() {
					_doneInitialTransition = true;
				});
			}
		});
	}

	void _initializeScrollSheetScrollControllers() {
		final mediaQueryData = context.findAncestorWidgetOfExactType<MediaQuery>()!.data;
		final screenWidth = mediaQueryData.size.width;
		final initialOffset = ((_thumbnailSize + 8) * (currentIndex + 0.5)) - (screenWidth / 2);
		final maxOffset = ((_thumbnailSize + 8) * widget.attachments.length) - screenWidth;
		if (maxOffset > 0) {
			thumbnailScrollController = ScrollController(initialScrollOffset: initialOffset.clamp(0, maxOffset));
			final screenHeight = mediaQueryData.size.height;
			final screenTopViewPadding = mediaQueryData.viewPadding.top;
			final screenBottomViewPadding = mediaQueryData.viewPadding.bottom;
			final gridViewHeight = screenHeight - (_thumbnailSize + 8 + kMinInteractiveDimensionCupertino + ((Settings.featureStatusBarWorkaround && (Persistence.settings.useStatusBarWorkaround ?? false)) ? 0 : screenTopViewPadding) + screenBottomViewPadding);
			final gridViewRowCount = (gridViewHeight / (Settings.instance.thumbnailSize * 1.5)).ceil();
			final gridViewSquareSize = gridViewHeight / gridViewRowCount;
			final gridViewWidthEstimate = ((widget.attachments.length + 1) / gridViewRowCount).ceil() * gridViewSquareSize;
			final gridviewMaxOffset = gridViewWidthEstimate - screenWidth;
			if (gridviewMaxOffset > 0) {
				_gridViewScrollController = ScrollController(
					initialScrollOffset: gridviewMaxOffset * (initialOffset.clamp(0, maxOffset) / maxOffset)
				);
			}
			else {
				_gridViewScrollController = ScrollController();
			}
		}
		else {
			// Not scrollable (not large enough to need to scroll)
			thumbnailScrollController = ScrollController();
			_gridViewScrollController = ScrollController();
		}
		thumbnailScrollController.addListener(_onThumbnailScrollControllerUpdate);
		_gridViewScrollController.addListener(_onGridViewScrollControllerUpdate);
	}

	@override
	void didUpdateWidget(GalleryPage old) {
		super.didUpdateWidget(old);
		if (widget.initialAttachment != old.initialAttachment) {
			if (currentAttachment == widget.initialAttachment) {
				// No need to update. This might be a recursive update.
				return;
			}
			if (old.initialAttachment != null) {
				_getController(old.initialAttachment!).isPrimary = false;
			}
			currentIndex = (widget.initialAttachment != null) ? max(0, widget.attachments.indexOf(widget.initialAttachment!)) : 0;
			pageController.jumpToPage(currentIndex);
			if (Settings.instance.autoloadAttachments) {
				final attachment = widget.attachments[currentIndex];
				_getController(attachment).loadFullAttachment().then((x) {
					if (!mounted) return;
					_currentAttachmentChanged.didUpdate();
				});
			}
		}
	}

	void _onThumbnailScrollControllerUpdate() {
				// ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
		_thumbnailsDesynced |= thumbnailScrollController.position.activity is DragScrollActivity;
		if (_gridViewDesynced) {
			return;
		}
		if (_gridViewScrollController.hasOnePosition && !_gridViewScrollController.position.isScrollingNotifier.value) {
			_gridViewScrollController.position.jumpTo(
				(_gridViewScrollController.position.maxScrollExtent * (thumbnailScrollController.position.pixels / thumbnailScrollController.position.maxScrollExtent))
					.clamp(_gridViewScrollController.position.minScrollExtent, _gridViewScrollController.position.maxScrollExtent)
			);
		}
	}

	void _onGridViewScrollControllerUpdate() {
		// ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
		_gridViewDesynced |= _gridViewScrollController.position.activity is DragScrollActivity;
	}

	bool _isAttachmentAlreadyDownloaded(Attachment attachment) {
		final overrideSource = widget.overrideSources[attachment];
		if (overrideSource != null) {
			return _downloadedOverrideSources.contains(overrideSource);
		}
		final thread = widget.threads[attachment];
		if (thread != null) {
			return thread.imageboard.persistence
							.getThreadStateIfExists(thread.item.identifier)
							?.isAttachmentDownloaded(attachment) ?? false;
		}
		final post = widget.posts[attachment];
		if (post != null) {
			return post.imageboard.persistence
							.getThreadStateIfExists(post.item.threadIdentifier)
							?.isAttachmentDownloaded(attachment) ?? false;
		}
		// Last resort
		final threadId = attachment.threadId;
		if (threadId == null) {
			return false;
		}
		final imageboard = widget.attachments.tryFirstWhere((a) => a.attachment == attachment)?.imageboard ?? context.read<Imageboard?>();
		return imageboard?.persistence
						.getThreadStateIfExists(ThreadIdentifier(attachment.board, threadId))
						?.isAttachmentDownloaded(attachment) ?? false;
	}

	void _onAttachmentDownload(Attachment attachment) {
		final overrideSource = widget.overrideSources[attachment];
		if (overrideSource != null) {
			_downloadedOverrideSources.add(overrideSource);
			return;
		}
		final thread = widget.threads[attachment];
		if (thread != null) {
			final ts = thread.imageboard.persistence
									.getThreadState(thread.item.identifier, initiallyHideFromHistory: true);
			ts.didDownloadAttachment(attachment);
			return;
		}
		final post = widget.posts[attachment];
		if (post != null) {
			final ts = post.imageboard.persistence
									.getThreadState(post.item.threadIdentifier, initiallyHideFromHistory: true);
			ts.didDownloadAttachment(attachment);
			return;
		}
		// Last resort
		final threadId = attachment.threadId;
		if (threadId == null) {
			return;
		}
		final imageboard = widget.attachments.tryFirstWhere((a) => a.attachment == attachment)?.imageboard ?? context.read<Imageboard?>();
		return imageboard?.persistence
						.getThreadState(ThreadIdentifier(attachment.board, threadId), initiallyHideFromHistory: true)
						.didDownloadAttachment(attachment);
	}

	AttachmentViewerController _getController(TaggedAttachment attachment) {
		if (_controllers[attachment] == null) {
			_controllers[attachment] = AttachmentViewerController(
				context: context,
				attachment: attachment.attachment,
				redrawGestureListenable: _slideListenable,
				imageboard: attachment.imageboard,
				isPrimary: attachment == currentAttachment,
				overrideSource: widget.overrideSources[attachment.attachment],
				initialGoodSource: widget.initialGoodSources[attachment.attachment],
				isDownloaded: _isAttachmentAlreadyDownloaded(attachment.attachment),
				onDownloaded: () => _onAttachmentDownload(attachment.attachment),
				thread: widget.threads[attachment.attachment]?.item
			);
		}
		return _controllers[attachment]!;
	}

	void _updateOverlays(bool show) async {
		if (!showChromeOnce && show) {
			_initializeScrollSheetScrollControllers();
		}
		showChromeOnce |= show;
		show |= currentAttachment.attachment.type == AttachmentType.url;
		if (!widget.updateOverlays) {
			return;
		}
		if (show && !showingOverlays) {
			try {
				await HomeIndicator.show();
			}
			on MissingPluginException {
				// Might be incompatible platform
			}
			await showStatusBar();
			showingOverlays = true;
		}
		else if (!show && showingOverlays) {
			try {
				await HomeIndicator.hide();
			}
			on MissingPluginException {
				// Might be incompatible platform
			}
			await hideStatusBar();
			showingOverlays = false;
		}
	}

	void __onPageControllerUpdate() {
		if (!mounted) return;
		if (_thumbnailsDesynced) return;
		if (showChromeOnce && pageController.hasClients && thumbnailScrollController.hasOnePosition && pageController.position.pixels != _lastpageControllerPixels) {
			_lastpageControllerPixels = pageController.position.pixels;
			final factor = pageController.position.pixels / pageController.position.maxScrollExtent;
			final idealLocation = (thumbnailScrollController.position.maxScrollExtent + thumbnailScrollController.position.viewportDimension - _thumbnailSize - 12) * factor - (thumbnailScrollController.position.viewportDimension / 2) + (_thumbnailSize / 2 + 6);
			thumbnailScrollController.jumpTo(idealLocation.clamp(0, thumbnailScrollController.position.maxScrollExtent));
		}
	}

	Future<void> _animateToPage(int index, {int milliseconds = 200, bool overrideRateLimit = false}) async {
		if (currentController.gestureKey.currentState?.extendedImageSlidePageState?.isSliding ?? false) {
			return;
		}
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		if (Settings.instance.autoloadAttachments && (overrideRateLimit || !attachment.attachment.isRateLimited)) {
			_getController(attachment).loadFullAttachment().then((x) {
				if (mounted) {
					_currentAttachmentChanged.didUpdate();
				}
			});
		}
		if (milliseconds == 0) {
			pageController.jumpToPage(index);
			_shouldShowPosition.value = true;
			_onPageChanged(index);
		}
		else {
			_animatingNow = true;
			_shouldShowPosition.value = true;
			await pageController.animateToPage(
				index,
				duration: Duration(milliseconds: milliseconds),
				curve: Curves.ease
			);
			_animatingNow = false;
			_onPageChanged(index);
		}
	}

	bool _rotationAppropriate(Attachment attachment) {
		if (attachment.type == AttachmentType.url || attachment.type == AttachmentType.pdf) {
			return false;
		}
		final displayIsLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
		return attachment.aspectRatio != 1 && displayIsLandscape != (attachment.aspectRatio > 1);
	}

	void _onPageChanged(int index) async {
		final attachment = widget.attachments[index];
		currentIndex = index;
		if (!_animatingNow) {
			widget.onChange?.call(attachment);
			final settings = Settings.instance;
			if (settings.autoloadAttachments && !attachment.attachment.isRateLimited) {
				_getController(attachment).loadFullAttachment().then((x) {
					if (!mounted) return;
					_currentAttachmentChanged.didUpdate();
				});
				if (index > 0) {
					final previousAttachment = widget.attachments[index - 1];
					_getController(previousAttachment).preloadFullAttachment();
				}
				if (index < (widget.attachments.length - 1)) {
					final nextAttachment = widget.attachments[index + 1];
					_getController(nextAttachment).preloadFullAttachment();
				}
			}
			for (final c in _controllers.entries) {
				c.value.isPrimary = c.key == currentAttachment;
			}
			_currentAttachmentChanged.didUpdate();
		}
		_hideRotateButton = false;
		_shouldShowPosition.value = true;
		await Future.delayed(const Duration(seconds: 3));
		if (mounted && currentIndex == index) {
			_shouldShowPosition.value = false;
		}
	}

	Future<void> _downloadAll({bool saveAs = false}) async {
		final List<TaggedAttachment> toDownload;
		final String? dir;
		bool force = false;
		if (saveAs) {
			dir = await pickDirectory();
			if (!mounted || dir == null) {
				return;
			}
			toDownload = widget.attachments.toList();
		}
		else {
			dir = null;
			toDownload = widget.attachments.where((a) => !_getController(a).isDownloaded).toList();
			if (toDownload.isEmpty) {
				force = await confirm(
					context,
					widget.attachments.length == 1
							? 'Redownload?'
							: 'Redownload all?',
					content:
						widget.attachments.length == 1
							? 'The attachment has already been saved'
							: 'All ${toDownload.length} attachments have already been saved'
				);
				if (!mounted || !force) {
					return;
				}
				toDownload.addAll(widget.attachments);
			}
		}
		final shouldDownload = force || await confirm(
			context,
			widget.attachments.length == 1
					? 'Download?' : 'Download all?',
			content: '${describeCount(toDownload.length, 'attachment')} will be saved to ${dir ?? 'your library'}',
			actionName: 'Download'
		);
		if (!mounted || !shouldDownload) {
			return;
		}
		await modalLoad(context, 'Bulk Download', (controller) async {
			int downloaded = 0;
			final failed = <Attachment, String>{};
			for (final attachment in toDownload) {
				if (controller.cancelToken.isCancelled) return failed;
				try {
					await _getController(attachment).preloadFullAttachment();
					await _getController(attachment).download(dir: dir, force: force);
					downloaded++;
				}
				catch (e, st) {
					Future.error(e, st);
					failed[attachment.attachment] = e.toStringDio();
				}
				controller.progress.value = ('$downloaded${failed.isEmpty ? '' : ' (${describeCount(failed.length, 'error')})'} / ${toDownload.length}', (downloaded + failed.length) / toDownload.length);
			}
			if (failed.isNotEmpty) {
				throw Exception('Some attachments failed: $failed');
			}
		}, cancellable: true);
	}

	void _toggleChrome() {
		if (!mounted) {
			return;
		}
		showChrome = !showChrome & widget.allowChrome;
		_gridViewDesynced = false;
		_thumbnailsDesynced = false;
		_updateOverlays(showChrome);
		setState(() {});
	}

	double _dragPopFactor(Offset offset, Size size) {
		final threshold = size.bottomRight(Offset.zero).distance / 3;
		return offset.distance / threshold;
	}

	double get _maxScrollSheetSize => ((_thumbnailSize + 8 + _gridViewHeight + kMinInteractiveDimensionCupertino + MediaQuery.paddingOf(context).bottom) / MediaQuery.sizeOf(context).height).clamp(0, 1);

	double get _minScrollSheetSize {
		if (Settings.instance.showThumbnailsInGallery) {
			return max(0.2, (kMinInteractiveDimensionCupertino + _thumbnailSize + 8 + MediaQuery.paddingOf(context).bottom) / MediaQuery.sizeOf(context).height);
		}
		if (currentController.videoPlayerController != null) {
			return (44 + MediaQuery.paddingOf(context).bottom) / MediaQuery.sizeOf(context).height;
		}
		return 0.0;
	}
	
	double get _gridViewHeight {
		final mediaQueryData = context.findAncestorWidgetOfExactType<MediaQuery>()!.data;
		final screenHeight = mediaQueryData.size.height;
		final screenWidth = mediaQueryData.size.width;
		final screenTopViewPadding = mediaQueryData.viewPadding.top;
		final screenBottomViewPadding = mediaQueryData.viewPadding.bottom;
		final maxHeight = screenHeight - (_thumbnailSize + 8 + kMinInteractiveDimensionCupertino + ((Settings.featureStatusBarWorkaround && (Persistence.settings.useStatusBarWorkaround ?? false)) ? 0 : screenTopViewPadding) + screenBottomViewPadding);
		final maxRowCount = (maxHeight / (Settings.instance.thumbnailSize * 1.5)).ceil();
		final squareSize = maxHeight / maxRowCount;
		final visibleSquaresPerRow = (screenWidth / squareSize).floor();
		if ((widget.attachments.length + 1) > (maxRowCount * visibleSquaresPerRow)) {
			return maxHeight;
		}
		return squareSize * ((widget.attachments.length + 1) / (visibleSquaresPerRow)).ceil();
	}

	Widget _buildScrollSheetChild(ScrollController controller) {
		final theme = Settings.instance.darkTheme;
		final showReplyCountsInGallery = Settings.instance.showReplyCountsInGallery;
		return AnimatedBuilder(
			animation: _currentAttachmentChanged,
			builder: (context, child) {
				final maxCrossAxisExtent = Settings.thumbnailSizeSetting.watch(context) * 1.5;
				final insideBackdropFilter = Container(
					color: Colors.black38,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (currentController.videoPlayerController != null) VideoControls(
								controller: currentController
							),
							SizedBox(
								height: _thumbnailSize + 8,
								child: KeyedSubtree(
									key: _thumbnailsKey,
									child: ListView.builder(
										controller: thumbnailScrollController,
										itemCount: widget.attachments.length,
										scrollDirection: Axis.horizontal,
										itemBuilder: (context, index) {
											final attachment = widget.attachments[index];
											final icon = attachment.attachment.icon;
											final isNormalAttachment = widget.overrideSources[attachment.attachment]?.scheme != 'file';
											return CupertinoInkwell(
												padding: EdgeInsets.zero,
												minSize: 0,
												onPressed: () {
													if (_scrollSheetController.size > 0.5) {
														_scrollSheetController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
													}
													_animateToPage(index, overrideRateLimit: true);
												},
												child: SizedBox(
													width: _thumbnailSize + 8,
													height: _thumbnailSize + 8,
													child: Center(
														child: Container(
															padding: const EdgeInsets.all(2),
															decoration: BoxDecoration(
																color: attachment == currentAttachment ? theme.primaryColor : null,
																borderRadius: const BorderRadius.all(Radius.circular(4)),
															),
															child: Stack(
																alignment: Alignment.center,
																children: [
																	ClipRRect(
																		borderRadius: BorderRadius.circular(4),
																		child: isNormalAttachment ? AttachmentThumbnail(
																			gaplessPlayback: true,
																			attachment: attachment.attachment,
																			site: attachment.imageboard.site,
																			width: _thumbnailSize,
																			height: _thumbnailSize,
																			fit: BoxFit.cover,
																			mayObscure: true
																		) : MediaThumbnail(
																			uri: widget.overrideSources[attachment.attachment]!,
																			fit: BoxFit.cover,
																			fontSize: 10
																		)
																	),
																	if (isNormalAttachment && icon != null) Positioned(
																		bottom: 0,
																		right: 0,
																		child: Container(
																			decoration: const BoxDecoration(
																				borderRadius: BorderRadius.only(
																					topLeft: Radius.circular(6),
																					bottomRight: Radius.circular(8)
																				),
																				color: Colors.black54
																			),
																			padding: const EdgeInsets.all(2),
																			child: Icon(icon, size: 15),
																		)
																	),
																	if (showReplyCountsInGallery && ((_replyCounts[widget.attachments[index].attachment] ?? 0) > 0)) Container(
																		decoration: BoxDecoration(
																			borderRadius: BorderRadius.circular(4),
																			color: Colors.black54
																		),
																		padding: const EdgeInsets.all(4),
																		child: Text(
																			_replyCounts[widget.attachments[index].attachment]!.toString(),
																			style: const TextStyle(
																				color: Colors.white70,
																				fontSize: 14,
																				fontWeight: FontWeight.bold,
																				fontVariations: CommonFontVariations.bold
																			)
																		)
																	)
																]
															)
														)
													)
												)
											);
										}
									)
								)
							),
							SizedBox(
								height: _gridViewHeight,
								child: GridView.builder(
									scrollDirection: Axis.horizontal,
									controller: _gridViewScrollController,
									gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
										maxCrossAxisExtent: maxCrossAxisExtent
									),
									itemBuilder: (context, index) {
										if (index == widget.attachments.length) {
											return Padding(
												padding: const EdgeInsets.all(6),
												child: GestureDetector(
													onLongPress: isSaveFileAsSupported ? () => _downloadAll(saveAs: true) : null,
													child: AdaptiveFilledButton(
														padding: const EdgeInsets.all(8),
														onPressed: _downloadAll,
														child: const FittedBox(
															fit: BoxFit.contain,
															child: Column(
																mainAxisSize: MainAxisSize.min,
																children: [
																	Icon(CupertinoIcons.cloud_download, size: 50),
																	Text('Download all')
																]
															)
														)
													)
												)
											);
										}
										final attachment = widget.attachments[index];
										final icon = attachment.attachment.icon;
										final isNormalAttachment = widget.overrideSources[attachment.attachment]?.scheme != 'file';
										return CupertinoInkwell(
											padding: EdgeInsets.zero,
											minSize: 0,
											onPressed: () {
												_scrollSheetController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
												Future.delayed(const Duration(milliseconds: 100), () => _animateToPage(index, overrideRateLimit: true));
											},
											child: Container(
												padding: const EdgeInsets.all(4),
												margin: const EdgeInsets.all(2),
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(8)),
													color: attachment == currentAttachment ? theme.primaryColor : null
												),
												child: Stack(
													fit: StackFit.expand,
													children: [
														ClipRRect(
															borderRadius: BorderRadius.circular(8),
															child: isNormalAttachment ? AttachmentThumbnail(
																gaplessPlayback: true,
																attachment: attachment.attachment,
																site: attachment.imageboard.site,
																hero: null,
																width: maxCrossAxisExtent,
																height: maxCrossAxisExtent,
																fit: BoxFit.cover,
																mayObscure: true
															) : MediaThumbnail(
																uri: widget.overrideSources[attachment.attachment]!,
																fit: BoxFit.cover
															)
														),
														if (isNormalAttachment && icon != null) Positioned(
															bottom: 0,
															right: 0,
															child: Container(
																decoration: const BoxDecoration(
																	borderRadius: BorderRadius.only(
																		topLeft: Radius.circular(6),
																		bottomRight: Radius.circular(8)
																	),
																	color: Colors.black54
																),
																padding: const EdgeInsets.all(2),
																child: Icon(icon, size: 19),
															)
														),
														if (showReplyCountsInGallery && ((_replyCounts[widget.attachments[index].attachment] ?? 0) > 0)) Center(
															child: Container(
																decoration: BoxDecoration(
																	borderRadius: BorderRadius.circular(8),
																	color: Colors.black54
																),
																padding: const EdgeInsets.all(8),
																child: Text(
																	_replyCounts[widget.attachments[index].attachment]!.toString(),
																	style: const TextStyle(
																		color: Colors.white70,
																		fontSize: 38,
																		fontWeight: FontWeight.bold,
																		fontVariations: CommonFontVariations.bold
																	)
																)
															)
														)
													]
												)
											)
										);
									},
									itemCount: widget.attachments.length + 1
								)
							),
							SizedBox(
								height: 0,
								child: OverflowBox(
									maxHeight: 100,
									alignment: Alignment.topCenter,
									child: Stack(
										alignment: Alignment.topCenter,
										clipBehavior: Clip.none,
										children: [
											Positioned(
												top: 0,
												left: 0,
												right: 0,
												child: Container(
												padding: const EdgeInsets.only(bottom: 800),
												alignment: Alignment.topCenter,
												color: Colors.black38,
												child: Visibility(
													visible: _gridViewScrollController.hasOnePosition &&
																	_gridViewScrollController.position.maxScrollExtent > _gridViewScrollController.position.viewportDimension,
													child: Container(
														margin: const EdgeInsets.only(top: 70),
														padding: const EdgeInsets.all(16),
														decoration: BoxDecoration(
															borderRadius: BorderRadius.circular(8),
															color: theme.backgroundColor.withOpacity(0.5)
														),
														child: const Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																Icon(CupertinoIcons.arrow_left),
																SizedBox(width: 8),
																Text('Scroll horizontally'),
																SizedBox(width: 8),
																Icon(CupertinoIcons.arrow_right)
															]
														)
													)
												)
											)
										)
									]
								)
							)
						)
					]
				)
			);
				return Padding(
					padding: currentController.videoPlayerController == null ? const EdgeInsets.only(top: 44) : EdgeInsets.zero,
					child: SingleChildScrollView(
						controller: controller,
						clipBehavior: Clip.none,
						child: ClipRect(
							clipper: const _PaddedRectClipper(EdgeInsets.only(bottom: 1000)),
							child: Persistence.settings.blurEffects ? BackdropFilter(
								filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
								child: insideBackdropFilter
							) : insideBackdropFilter
						)
					)
				);
			}
		);
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final layoutInsets = MediaQuery.paddingOf(context);
		final zone = widget.zone;
		final onThreadSelected = widget.onThreadSelected;
		return ExtendedImageSlidePage(
			resetPageDuration: const Duration(milliseconds: 100),
			slidePageBackgroundHandler: (offset, size) {
				Future.microtask(_slideListenable.didUpdate);
				final factor = _dragPopFactor(offset, size);
				if (!showChrome) {
					_updateOverlays(factor > 1);
				}
				return Colors.black.withOpacity(1 - factor.clamp(0, 1));
			},
			slideEndHandler: (offset, {ScaleEndDetails? details, ExtendedImageSlidePageState? state}) {
				final dragAngle = (details?.velocity ?? Velocity.zero).pixelsPerSecond.direction / pi;
				final imageAngle = switch (state?.imageGestureState?.gestureDetails?.slidePageOffset?.direction) {
					double a => a / pi,
					null => dragAngle
				};
				final a = dragAngle.abs();
				return ((details?.pointerCount ?? 0) == 0) && widget.allowPop && (a >= 0.25 && a <= 0.75) && (imageAngle.sign == dragAngle.sign);
			},
			child: ChanceTheme(
				themeKey: settings.darkThemeKey,
				child: AdaptiveScaffold(
					disableAutoBarHiding: true,
					backgroundColor: Colors.transparent,
					bar: showChrome ? AdaptiveBar(
						title: AnimatedBuilder(
							animation: _currentAttachmentChanged,
							builder: (context, _) {
								final metadataParts = [
									if (currentAttachment.attachment.width != null && currentAttachment.attachment.height != null) '${currentAttachment.attachment.width}x${currentAttachment.attachment.height}',
									if (currentAttachment.attachment.sizeInBytes != null) formatFilesize(currentAttachment.attachment.sizeInBytes!)
								];
								return Padding(
									padding: const EdgeInsets.only(bottom: 4),
									child: GestureDetector(
										onTap: currentAttachment.attachment.ellipsizedFilename == null ? null : () {
											alert(context, 'Full filename', currentAttachment.attachment.filename);
										},
										child: AutoSizeText(
											currentAttachment.attachment.type == AttachmentType.url ?
												currentAttachment.attachment.url.toString() :
												"${currentAttachment.attachment.ellipsizedFilename ?? currentAttachment.attachment.filename}${metadataParts.isEmpty ? '' : ' (${metadataParts.join(', ')})'}",
											minFontSize: 8,
											maxLines: 3
										)
									)
								);
							}
						),
						backgroundColor: Colors.black38,
						brightness: Brightness.dark,
						actions: [
							AnimatedBuilder(
								animation: _currentAttachmentChanged,
								builder: (context, _) => AnimatedBuilder(
									animation: currentController,
									builder: (context, _) {
										return Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												if (!settings.showThumbnailsInGallery) AdaptiveIconButton(
													onPressed: () {
														_scrollSheetController.animateTo(
															_scrollSheetController.size > 0.5 ? 0 : _maxScrollSheetSize,
															duration: const Duration(milliseconds: 250),
															curve: Curves.ease
														);
													},
													icon: const Icon(CupertinoIcons.rectangle_grid_2x2)
												),
												// image has these in the ContextMenu
												if (currentAttachment.attachment.type != AttachmentType.image) AdaptiveIconButton(
													key: _imageSearchButtonKey,
													onPressed: () async {
														final actions = [
															...buildImageSearchActions(context, currentAttachment.imageboard, [currentAttachment.attachment]),
															ContextMenuAction(
																child: const Text('Share link'),
																trailingIcon: CupertinoIcons.link,
																onPressed: () async {
																	final text = _getController(currentAttachment).goodImagePublicSource.toString();
																	await shareOne(
																		context: context,
																		text: text,
																		type: "text",
																		sharePositionOrigin: _imageSearchButtonKey.currentContext?.globalSemanticBounds
																	);
																}
															),
															...(widget.additionalContextMenuActionsBuilder?.call(currentAttachment) ?? const Iterable<ContextMenuAction>.empty())
														];
														await showAdaptiveModalPopup(
															context: context,
															builder: (context) => AdaptiveActionSheet(
																actions: actions.toActionSheetActions(context),
																cancelButton: AdaptiveActionSheetAction(
																	child: const Text('Cancel'),
																	onPressed: () => Navigator.of(context, rootNavigator: true).pop()
																)
															)
														);
													},
													icon: const Icon(Icons.image_search)
												),
												GestureDetector(
													onLongPress: isSaveFileAsSupported ? () async {
														final filename = await currentController.download(force: true, saveAs: true);
														if (filename != null && context.mounted) {
															showToast(context: context, message: 'Downloaded $filename', icon: Icons.folder);
														}
													} : null,
													child: AdaptiveIconButton(
														onPressed: currentController.canShare ? () async {
															final download = !currentController.isDownloaded || (await confirm(context, 'Redownload?'));
															if (!download) return;
															final filename = await currentController.download(force: true);
															if (!context.mounted || filename == null) return;
															showToast(context: context, message: 'Downloaded $filename', icon: CupertinoIcons.cloud_download);
														} : null,
														icon: currentController.isDownloaded ? const Icon(CupertinoIcons.cloud_download_fill) : const Icon(CupertinoIcons.cloud_download)
													)
												),
												AnimatedBuilder(
													animation: Listenable.merge(
														widget.attachments.map((a) => a.imageboard.persistence.savedAttachmentsListenable).toSet()
													),
													builder: (context, child) {
														final persistence = currentAttachment.imageboard.persistence;
														final currentlySaved = persistence.getSavedAttachment(currentAttachment.attachment) != null;
														return AdaptiveIconButton(
															onPressed: currentController.canShare ? () async {
																if (currentlySaved) {
																	persistence.deleteSavedAttachment(currentAttachment.attachment);
																}
																else {
																	persistence.saveAttachment(currentAttachment.attachment, currentController.getFile(), currentController.cacheExt);
																}
															} : null,
															icon: Icon(currentlySaved ? Adaptive.icons.bookmarkFilled : Adaptive.icons.bookmark)
														);
													}
												),
												AdaptiveIconButton(
													key: _shareButtonKey,
													onPressed: currentController.canShare ? () async {
														await currentController.share(_shareButtonKey.currentContext?.globalSemanticBounds);
													} : null,
													icon: Icon(Adaptive.icons.share)
												)
											]
										);
									}
								)
							)
						]
					) : null,
					body: Shortcuts(
						shortcuts: {
							LogicalKeySet(LogicalKeyboardKey.arrowLeft): const GalleryLeftIntent(),
							LogicalKeySet(LogicalKeyboardKey.arrowRight): const GalleryRightIntent(),
							LogicalKeySet(LogicalKeyboardKey.space): const GalleryToggleChromeIntent(),
							LogicalKeySet(LogicalKeyboardKey.keyG): const DismissIntent(),
							LogicalKeySet(LogicalKeyboardKey.tab): Intent.doNothing,
							LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.arrowLeft) : const DismissIntent()
						},
						child: Actions(
							actions: {
								GalleryLeftIntent: CallbackAction<GalleryLeftIntent>(
									onInvoke: (i) {
										if (currentIndex > 0) {
											_animateToPage(currentIndex - 1, milliseconds: 0);
										}
										return null;
									}
								),
								GalleryRightIntent: CallbackAction<GalleryRightIntent>(
									onInvoke: (i) {
										if (currentIndex < widget.attachments.length - 1) {
											_animateToPage(currentIndex + 1, milliseconds: 0);
										}
										return null;
									}
								),
								GalleryToggleChromeIntent: CallbackAction<GalleryToggleChromeIntent>(
									onInvoke: (i) => _toggleChrome()
								),
								DismissIntent: CallbackAction<DismissIntent>(
									onInvoke: (i) {
										if (Navigator.of(context).canPop()) {
											Navigator.of(context).pop();
										}
										return null;
									}
								)
							},
							child: Focus(
								autofocus: true,
								child: Stack(
									children: [
										KeyedSubtree(
											key: _pageControllerKey,
											child: ExtendedImageGesturePageView.builder(
												scrollDirection: widget.axis,
												physics: settings.showAnimations ? const _FasterSnappingPageScrollPhysics() : const _VeryFastSnappingPageScrollPhysics(),
												canScrollPage: (x) => settings.allowSwipingInGallery && widget.allowScroll && widget.attachments.length > 1,
												onPageChanged: _onPageChanged,
												controller: pageController,
												itemCount: widget.attachments.length,
												itemBuilder: (context, index) {
													final attachment = widget.attachments[index];
													return TransformedMediaQuery(
														transformation: (context, data) => data.copyWith(
															gestureSettings: DeviceGestureSettings(
																touchSlop: (data.gestureSettings.touchSlop ?? kTouchSlop) * 2
															)
														),
														child: AnimatedBuilder(
															animation: _getController(attachment),
															builder: (context, _) => GestureDetector(
																onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																	_getController(attachment).loadFullAttachment().then((x) {
																		if (!mounted) return;
																		_currentAttachmentChanged.didUpdate();
																	});
																},
																child: HeroMode(
																	enabled: !widget.initiallyShowGrid || _doneInitialTransition,
																	child: AttachmentViewer(
																		controller: _getController(attachment),
																		autoRotate: _autoRotate,
																		onScaleChanged: (scale) {
																			if (scale > 1 && !_hideRotateButton) {
																				setState(() {
																					_hideRotateButton = true;
																				});
																			}
																			else if (scale <= 1 && _hideRotateButton) {
																				setState(() {
																					_hideRotateButton = false;
																				});
																			}
																		},
																		semanticParentIds: attachment.semanticParentIds,
																		onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																			_getController(attachment).loadFullAttachment().then((x) {
																				if (!mounted) return;
																				_currentAttachmentChanged.didUpdate();
																			});
																		},
																		layoutInsets: layoutInsets,
																		allowContextMenu: widget.allowContextMenu,
																		useHeroDestinationWidget: widget.useHeroDestinationWidget,
																		heroOtherEndIsBoxFitCover: widget.heroOtherEndIsBoxFitCover,
																		additionalContextMenuActions: widget.additionalContextMenuActionsBuilder?.call(attachment) ?? []
																	)
																)
															)
														)
													);
												}
											)
										),
										Positioned.fill(
											child: GestureDetector(
												onTap: showChrome ? _toggleChrome : null
											)
										),
										Align(
											alignment: Alignment.bottomRight,
											child: AnimatedBuilder(
												animation: _currentAttachmentChanged,
												builder: (context, child) => Padding(
													padding: showChrome ? EdgeInsets.only(
														bottom: (settings.showThumbnailsInGallery ? MediaQuery.sizeOf(context).height * 0.2 : (44 + MediaQuery.paddingOf(context).bottom)) - (currentController.videoPlayerController == null ? 44 : 0) - 16,
														right: 8
													) : layoutInsets + const EdgeInsets.only(right: 8),
													child: child
												),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.end,
													children: [
														if (zone != null && showChrome) AdaptiveIconButton(
															padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
															onPressed: () {
																final post = zone.findThread(currentAttachment.attachment.threadId ?? zone.primaryThreadId)?.posts_.tryFirstWhere((p) => p.attachments.contains(currentAttachment.attachment));
																final navigator = Navigator.of(context);
																// Hack to pop until here
																Route? currentRoute;
																navigator.popUntil((r) {
																	currentRoute = r;
																	return true;
																});
																void onThumbnailTap(Attachment attachment) {
																	navigator.popUntil((r) => r == currentRoute);
																	final index = widget.attachments.indexWhere((a) => a.attachment == attachment);
																	if (index == -1) {
																		showToast(
																			context: context,
																			message: 'Attachment not found!',
																			icon: CupertinoIcons.exclamationmark_square
																		);
																		return;
																	}
																	_animateToPage(index, overrideRateLimit: true);
																}
																final onNeedScrollToPost = zone.onNeedScrollToPost == null ? null : (Post post) {
																	navigator.popUntil((r) => r == currentRoute);
																	navigator.pop(); // Pop the gallery too
																	zone.onNeedScrollToPost?.call(post);
																};
																final replyBoxZone = widget.replyBoxZone;
																final child = ImageboardScope(
																	imageboardKey: null,
																	imageboard: zone.imageboard,
																	child: PostsPage(
																		zone: zone.childZoneFor(post?.id, onNeedScrollToPost: onNeedScrollToPost),
																		header: PostRow(
																			post: post!,
																			isSelected: post.replyCount > 0,
																			onThumbnailTap: onThumbnailTap,
																			propagateOnThumbnailTap: true,
																			onDoubleTap: onNeedScrollToPost?.bind1(post)
																		),
																		postsIdsToShow: post.replyIds,
																		onThumbnailTap: onThumbnailTap
																	)
																);
																navigator.push(TransparentRoute(
																	builder: (context) => replyBoxZone == null ? child : Provider.value(
																		value: ReplyBoxZone(
																			onTapPostId: (int threadId, int id) {
																				navigator.popUntil((r) => r == currentRoute);
																				navigator.pop(); // Pop the gallery too
																				replyBoxZone.onTapPostId(threadId, id);
																			},
																			onQuoteText: (String text, {required PostIdentifier? backlink}) {
																				navigator.popUntil((r) => r == currentRoute);
																				navigator.pop(); // Pop the gallery too
																				replyBoxZone.onQuoteText(text, backlink: backlink);
																			}
																		),
																		child: child
																	),
																	settings: weakSettings
																));
															},
															icon: AnimatedBuilder(
																animation: _currentAttachmentChanged,
																builder: (context, _) => StationaryNotifyingIcon(
																	primary: 0,
																	secondary: _replyCounts[currentAttachment.attachment] ?? 0,
																	icon: const Icon(CupertinoIcons.reply)
																)
															)
														),
														if (onThreadSelected != null && showChrome) AnimatedBuilder(
															animation: _currentAttachmentChanged,
															builder: (context, _) => widget.threads.containsKey(currentAttachment.attachment) ? AdaptiveIconButton(
																padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
																onPressed: () async {
																	final thread = widget.threads[currentAttachment.attachment]!;
																	final pop = await Navigator.of(context).push<bool>(TransparentRoute(
																		builder: (context) => ImageboardScope(
																			imageboardKey: null,
																			imageboard: thread.imageboard,
																			child: OverscrollModalPage(
																				child: CupertinoButton(
																					padding: EdgeInsets.zero,
																					onPressed: () => Navigator.pop(context, true),
																					child: ThreadRow(
																						isSelected: false,
																						thread: thread.item
																					)
																				)
																			)
																		)
																	));
																	if ((pop ?? false) && context.mounted) {
																		Navigator.pop(context);
																		await Future.delayed(settings.showAnimations ? const Duration(milliseconds: 200) : Duration.zero);
																		onThreadSelected(thread);
																	}
																},
																icon: const Icon(CupertinoIcons.reply)
															) : const SizedBox.shrink()
														),
														ValueListenableBuilder<bool>(
															valueListenable: settings.muteAudio,
															builder: (context, muted, _) => AnimatedBuilder(
																animation: _currentAttachmentChanged,
																builder: (context, _) => AnimatedSwitcher(
																	duration: const Duration(milliseconds: 300),
																	child: (currentController.hasAudio && !showChrome && settings.showOverlaysInGallery) ? Align(
																		key: ValueKey<bool>(muted),
																		alignment: Alignment.bottomLeft,
																		child: AdaptiveIconButton(
																			padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
																			icon: muted ? const Icon(CupertinoIcons.volume_off) : const Icon(CupertinoIcons.volume_up),
																			onPressed: () {
																				if (muted) {
																					currentController.videoPlayerController?.player.setVolume(100);
																					settings.setMuteAudio(false);
																				}
																				else {
																					currentController.videoPlayerController?.player.setVolume(0);
																					settings.setMuteAudio(true);
																				}
																			}
																		)
																	) : const SizedBox.shrink()
																)
															)
														),
														AnimatedBuilder(
															animation: _currentAttachmentChanged,
															builder: (context, _) => AnimatedSwitcher(
																duration: const Duration(milliseconds: 300),
																child: (_rotationAppropriate(currentAttachment.attachment) && !_hideRotateButton && (showChrome || settings.showOverlaysInGallery)) ? GestureDetector(
																	onLongPress: () {
																		if (Settings.autoRotateInGallerySetting.value == _autoRotate) {
																			// nothing to do
																			return;
																		}
																		Settings.autoRotateInGallerySetting.value = _autoRotate;
																		showToast(
																			context: context,
																			icon: CupertinoIcons.rotate_left,
																			message: '${_autoRotate ? 'Enabled' : 'Disabled'} auto-rotation preference'
																		);
																	},
																	child: AdaptiveIconButton(
																		padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
																		icon: Transform(
																			alignment: Alignment.center,
																			transform: !_autoRotate ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
																			child: const Icon(CupertinoIcons.rotate_left)
																		),
																		onPressed: () {
																			_autoRotate = !_autoRotate;
																			setState(() {});
																		}
																	)
																) : const SizedBox.shrink()
															)
														)
													]
												)
											)
										),
										AnimatedBuilder(
											animation: Listenable.merge([_shouldShowPosition, _currentAttachmentChanged]),
											builder: (context, _) => Align(
												alignment: Alignment.bottomLeft,
												child: IgnorePointer(
													ignoring: !(showChrome || (_shouldShowPosition.value && settings.showOverlaysInGallery)),
													child: AnimatedOpacity(
														duration: const Duration(milliseconds: 300),
														opacity: showChrome || (_shouldShowPosition.value && settings.showOverlaysInGallery) ? 1 : 0,
														child: Column(
															mainAxisSize: MainAxisSize.min,
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																if (_peers[currentAttachment.attachment] case (int numer, int denom)) Container(
																	margin: const EdgeInsets.symmetric(horizontal: 16),
																	padding: const EdgeInsets.all(8),
																	decoration: const BoxDecoration(
																		borderRadius: BorderRadius.all(Radius.circular(8)),
																		color: Colors.black54
																	),
																	child: Row(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			const Icon(CupertinoIcons.photo_on_rectangle, size: 19),
																			const SizedBox(width: 8),
																			AnimatedBuilder(
																				animation: _currentAttachmentChanged,
																				builder: (context, _) => Text(
																					'$numer / $denom',
																					style: TextStyle(
																						color: settings.darkTheme.primaryColor,
																						fontFeatures: const [FontFeature.tabularFigures()]
																					),
																					textAlign: TextAlign.center
																				)
																			)
																		]
																	)
																),
																GestureDetector(
																	onTap: () async {
																		final controller = TextEditingController();
																		final str = await showAdaptiveDialog<String>(
																			barrierDismissible: true,
																			context: context,
																			builder: (context) => AdaptiveAlertDialog(
																				title: const Text('Jump to Attachment'),
																				content: AdaptiveTextField(
																					autofocus: true,
																					controller: controller,
																					keyboardType: TextInputType.number,
																					placeholder: 'Attachment #',
																					onSubmitted: (s) => Navigator.pop(context, s),
																				),
																				actions: [
																					AdaptiveDialogAction(
																						onPressed: () => Navigator.pop(context, controller.text),
																						child: const Text('Go')
																					),
																					AdaptiveDialogAction(
																						onPressed: () => Navigator.pop(context),
																						child: const Text('Cancel')
																					)
																				]
																			)
																		);
																		controller.dispose();
																		if (!context.mounted) {
																			return;
																		}
																		final index = int.tryParse(str ?? '');
																		if (index != null) {
																			_animateToPage((index - 1).clamp(0, widget.attachments.length - 1), milliseconds: 0, overrideRateLimit: true);
																		}
																	},
																	child: Container(
																		margin: const EdgeInsets.all(16),
																		padding: const EdgeInsets.all(8),
																		decoration: const BoxDecoration(
																			borderRadius: BorderRadius.all(Radius.circular(8)),
																			color: Colors.black54
																		),
																		child: AnimatedBuilder(
																			animation: _currentAttachmentChanged,
																			builder: (context, _) => Text(
																				'${currentIndex + 1} / ${widget.attachments.length}',
																				style: TextStyle(
																					color: settings.darkTheme.primaryColor,
																					fontFeatures: const [FontFeature.tabularFigures()]
																				),
																				textAlign: TextAlign.center
																			)
																		)
																	)
																),
																if (showChrome) SizedBox(
																	height: (settings.showThumbnailsInGallery ? MediaQuery.sizeOf(context).height * 0.2 : (44 + MediaQuery.paddingOf(context).bottom)) - (currentController.videoPlayerController == null ? 44 : 0),
																)
															]
														)
													)
												)
											)
										),
										Visibility(
											visible: showChrome,
											maintainState: showChromeOnce,
											maintainSize: showChromeOnce,
											maintainAnimation: showChromeOnce,
											child: AnimatedBuilder(
												animation: currentController,
												builder: (context, _) => DraggableScrollableSheet(
													key: _draggableScrollableSheetKey,
													snap: true,
													snapAnimationDuration: const Duration(milliseconds: 200),
													initialChildSize: widget.initiallyShowGrid ? _maxScrollSheetSize : _minScrollSheetSize,
													maxChildSize: _maxScrollSheetSize,
													minChildSize: _minScrollSheetSize,
													controller: _scrollSheetController,
													builder: (context, controller) => showChromeOnce ? _buildScrollSheetChild(controller) : const SizedBox.shrink()
												)
											)
										)
									]
								)
							)
						)
					)
				)
			)
		);
	}

	@override
	void dispose() {
		pageController.dispose();
		_scrollCoalescer.dispose();
		_currentAttachmentChanged.dispose();
		if (showChromeOnce) {
			thumbnailScrollController.dispose();
			_gridViewScrollController.dispose();
		}
		_slideListenable.dispose();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
		_shouldShowPosition.dispose();
		super.dispose();
	}
}

Future<void> handleMutingBeforeShowingGallery() async {
	if (Persistence.settings.deprecatedAlwaysStartVideosMuted ?? false) {
		// User previously had "Always start videos muted", but now unmuting once
		// will keep it unmuted while the gallery is open. Should let them know to
		// be safe.
		Future.delayed(const Duration(seconds: 1), () {
			alert(
				ImageboardRegistry.instance.context!,
				'Muting behaviour has changed',
				'You had the "always start videos muted" settings enabled, but now that only will apply once when opening the gallery. Swiping between images will not re-mute. Just letting you know to be safe...'
			);
		});
		Persistence.settings.deprecatedAlwaysStartVideosMuted = false;
		Persistence.settings.save();
	}
	if (Settings.instance.muteAudio.value) {
		// Already muted
		return;
	}
	final shouldMute = Settings.instance.muteAudioWhenOpeningGallery;
	if (shouldMute == TristateSystemSetting.a) {
		// Don't auto-mute
		return;
	}
	if (shouldMute == TristateSystemSetting.b) {
		// Always auto-mte
		Settings.instance.setMuteAudio(true);
		return;
	}
	// TristateSystemSetting.system
	// Mute if on speakers
	if (await areHeadphonesPluggedIn()) {
		return;
	}
	Settings.instance.setMuteAudio(true);
}

Future<Attachment?> showGalleryPretagged({
	required BuildContext context,
	required List<TaggedAttachment> attachments,
	Map<Attachment, Uri> overrideSources = const {},
	Map<Attachment, Uri> initialGoodSources = const {},
	PostSpanZoneData? zone,
	Map<Attachment, ImageboardScoped<Thread>> threads = const {},
	Map<Attachment, ImageboardScoped<Post>> posts = const {},
	ValueChanged<ImageboardScoped<Thread>>? onThreadSelected,
	ReplyBoxZone? replyBoxZone,
	TaggedAttachment? initialAttachment,
	bool initiallyShowChrome = false,
	bool initiallyShowGrid = false,
	bool allowChrome = true,
	bool allowContextMenu = true,
	ValueChanged<TaggedAttachment>? onChange,
	bool fullscreen = true,
	bool allowScroll = true,
	bool useHeroDestinationWidget = false,
	required bool heroOtherEndIsBoxFitCover,
	List<ContextMenuAction> Function(TaggedAttachment)? additionalContextMenuActionsBuilder,
}) async {
	if (initialAttachment != null && initialAttachment.attachment.shouldOpenExternally) {
		final url = Uri.parse(initialAttachment.attachment.url);
		if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
			await launchUrlExternally(url);
		}
		return null;
	}
	final navigator = fullscreen ? Navigator.of(context, rootNavigator: true) : context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context);
	await handleMutingBeforeShowingGallery();
	final lastSelected = await navigator.push(TransparentRoute<Attachment>(
		builder: (ctx) => GalleryPage(
			attachments: attachments,
			overrideSources: overrideSources,
			initialGoodSources: initialGoodSources,
			zone: zone,
			threads: threads,
			posts: posts,
			onThreadSelected: onThreadSelected,
			replyBoxZone: replyBoxZone,
			initialAttachment: initialAttachment,
			initiallyShowChrome: initiallyShowChrome,
			initiallyShowGrid: initiallyShowGrid,
			onChange: onChange,
			allowChrome: allowChrome,
			allowContextMenu: allowContextMenu,
			allowScroll: allowScroll,
			useHeroDestinationWidget: useHeroDestinationWidget,
			heroOtherEndIsBoxFitCover: heroOtherEndIsBoxFitCover,
			additionalContextMenuActionsBuilder: additionalContextMenuActionsBuilder,
		)
	));
	try {
		await HomeIndicator.show();
	}
	on MissingPluginException {
		// Might be incompatible platform
	}
	await showStatusBar();
	return lastSelected;
}

Future<Attachment?> showGallery({
	required BuildContext context,
	required List<Attachment> attachments,
	Map<Attachment, Uri> overrideSources = const {},
	Map<Attachment, Uri> initialGoodSources = const {},
	PostSpanZoneData? zone,
	Map<Attachment, ImageboardScoped<Thread>> threads = const {},
	Map<Attachment, ImageboardScoped<Post>> posts = const {},
	ValueChanged<ImageboardScoped<Thread>>? onThreadSelected,
	ReplyBoxZone? replyBoxZone,
	required Iterable<int> semanticParentIds,
	Attachment? initialAttachment,
	bool initiallyShowChrome = false,
	bool initiallyShowGrid = false,
	bool allowChrome = true,
	bool allowContextMenu = true,
	ValueChanged<Attachment>? onChange,
	bool fullscreen = true,
	bool allowScroll = true,
	required bool heroOtherEndIsBoxFitCover,
	List<ContextMenuAction> Function(TaggedAttachment)? additionalContextMenuActionsBuilder,
}) => showGalleryPretagged(
	context: context,
	attachments: attachments.map((attachment) => TaggedAttachment(
		attachment: attachment,
		semanticParentIds: semanticParentIds,
		imageboard: context.read<Imageboard>()
	)).toList(),
	overrideSources: overrideSources,
	initialGoodSources: initialGoodSources,
	zone: zone,
	threads: threads,
	posts: posts,
	onThreadSelected: onThreadSelected,
	replyBoxZone: replyBoxZone,
	initialAttachment: initialAttachment == null ? null : TaggedAttachment(
		attachment: initialAttachment,
		semanticParentIds: semanticParentIds,
		imageboard: context.read<Imageboard>()
	),
	initiallyShowChrome: initiallyShowChrome,
	initiallyShowGrid: initiallyShowGrid,
	allowChrome: allowChrome,
	allowContextMenu: allowContextMenu,
	onChange: onChange == null ? null : (x) => onChange(x.attachment),
	fullscreen: fullscreen,
	allowScroll: allowScroll,
	heroOtherEndIsBoxFitCover: heroOtherEndIsBoxFitCover,
	additionalContextMenuActionsBuilder: additionalContextMenuActionsBuilder
);