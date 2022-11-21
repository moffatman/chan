import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/audio.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/status_bar.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/saved_attachment_thumbnail.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:home_indicator/home_indicator.dart';

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
	final Map<Attachment, int> replyCounts;
	final Map<Attachment, Uri> initialGoodSources;
	final Map<Attachment, Uri> overrideSources;
	final bool Function(Attachment)? isAttachmentAlreadyDownloaded;
	final ValueChanged<Attachment>? onAttachmentDownload;
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

	const GalleryPage({
		required this.attachments,
		this.replyCounts = const {},
		this.overrideSources = const {},
		this.initialGoodSources = const {},
		this.isAttachmentAlreadyDownloaded,
		this.onAttachmentDownload,
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
	late final BehaviorSubject<void> _scrollCoalescer;
	double? _lastpageControllerPixels;
	bool _animatingNow = false;
	final _shareButtonKey = GlobalKey(debugLabel: 'GalleryPage._shareButtonKey');
	late final EasyListenable _slideListenable;
	bool _hideRotateButton = false;
	final Map<TaggedAttachment, AttachmentViewerController> _controllers = {};
	late final ValueNotifier<bool> _shouldShowPosition;
	late final EasyListenable _currentAttachmentChanged;
	late final DraggableScrollableController _scrollSheetController;
	final _draggableScrollableSheetKey = GlobalKey(debugLabel: 'GalleryPage._draggableScrollableSheetKey');
	late StreamSubscription<List<void>> __onPageControllerUpdateSubscription;
	bool _gridViewDesynced = false;
	bool _thumbnailsDesynced = false;
	/// To prevent Hero when entering with grid initially enabled
	bool _doneInitialTransition = false;
	bool _autoRotate = Settings.instance.autoRotateInGallery;

	@override
	void initState() {
		super.initState();
		if (widget.initiallyShowGrid) {
			// Hard to mute if loud when grid is covering
			Settings.instance.setMuteAudio(true);
		}
		_scrollCoalescer = BehaviorSubject();
		_slideListenable = EasyListenable();
		_shouldShowPosition = ValueNotifier(false);
		_currentAttachmentChanged = EasyListenable();
		_scrollSheetController = DraggableScrollableController();
		showChrome = widget.initiallyShowGrid || widget.initiallyShowChrome;
		currentIndex = (widget.initialAttachment != null) ? max(0, widget.attachments.indexOf(widget.initialAttachment!)) : 0;
		pageController = ExtendedPageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_onPageControllerUpdate);
		__onPageControllerUpdateSubscription = _scrollCoalescer.bufferTime(const Duration(milliseconds: 10)).listen((_) => __onPageControllerUpdate());
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

	AttachmentViewerController _getController(TaggedAttachment attachment) {
		if (_controllers[attachment] == null) {
			_controllers[attachment] = AttachmentViewerController(
				context: context,
				attachment: attachment.attachment,
				redrawGestureListenable: _slideListenable,
				imageboard: context.read<Imageboard>(),
				isPrimary: attachment == currentAttachment,
				overrideSource: widget.overrideSources[attachment.attachment],
				initialGoodSource: widget.initialGoodSources[attachment.attachment],
				isDownloaded: widget.isAttachmentAlreadyDownloaded?.call(attachment.attachment) ?? false,
				onDownloaded: () => widget.onAttachmentDownload?.call(attachment.attachment)
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

	void _onPageControllerUpdate() {
		_scrollCoalescer.add(null);
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

	Future<void> _animateToPage(int index, {int milliseconds = 200}) async {
		if (currentController.gestureKey.currentState?.extendedImageSlidePageState?.isSliding ?? false) {
			return;
		}
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		if (Settings.instance.autoloadAttachments && !attachment.attachment.isRateLimited) {
			_getController(attachment).loadFullAttachment().then((x) {
				if (mounted) {
					_currentAttachmentChanged.didUpdate();
				}
			});
		}
		if (milliseconds == 0) {
			pageController.jumpToPage(index);
			_shouldShowPosition.value = true;
			await Future.delayed(const Duration(seconds: 1));
			if (currentIndex == index) {
				_shouldShowPosition.value = false;
			}
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
			_shouldShowPosition.value = false;
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
		widget.onChange?.call(attachment);
		currentIndex = index;
		if (!_animatingNow) {
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
		await Future.delayed(const Duration(seconds: 1));
		if (mounted && currentIndex == index) {
			//_shouldShowPosition.value = false;
		}
	}

	void _downloadAll() async {
		final toDownload = widget.attachments.where((a) => !_getController(a).isDownloaded).toList();
		final shouldDownload = await showAdaptiveDialog<bool>(
			context: context,
			barrierDismissible: true,
			builder: (context) => AdaptiveAlertDialog(
				title: const Text('Download all?'),
				content: Text("${describeCount(toDownload.length, 'attachment')} will be saved to your library"),
				actions: [
					AdaptiveDialogAction(
						isDefaultAction: true,
						child: const Text('Download'),
						onPressed: () {
							Navigator.of(context).pop(true);
						},
					),
					AdaptiveDialogAction(
						child: const Text('Cancel'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					)
				]
			)
		);
		if (shouldDownload == true && mounted) {
			final loadingStream = ValueNotifier<int>(0);
			bool cancel = false;
			showAdaptiveDialog(
				context: context,
				barrierDismissible: false,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Bulk Download'),
					content: ValueListenableBuilder<int>(
						valueListenable: loadingStream,
						builder: (context, completedCount, child) => Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('${loadingStream.value} / ${toDownload.length} complete'),
								const SizedBox(height: 8),
								LinearProgressIndicator(
									value: completedCount / toDownload.length
								)
							]	
						)
					),
					actions: [
						AdaptiveDialogAction(
							isDestructiveAction: true,
							child: const Text('Cancel'),
							onPressed: () {
								cancel = true;
								Navigator.of(context).pop();
							}
						)
					]
				)
			);
			for (final attachment in toDownload) {
				if (cancel) return;
				await _getController(attachment).preloadFullAttachment();
				await _getController(attachment).download();
				loadingStream.value = loadingStream.value + 1;
			}
			if (!cancel && mounted) Navigator.of(context, rootNavigator: true).pop();
		}
	}

	void _toggleChrome() {
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

	double get _maxScrollSheetSize => (_thumbnailSize + 8 + _gridViewHeight + kMinInteractiveDimensionCupertino + MediaQuery.paddingOf(context).bottom) / MediaQuery.sizeOf(context).height;

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
											return AdaptiveIconButton(
												minSize: 0,
												onPressed: () {
													if (_scrollSheetController.size > 0.5) {
														_scrollSheetController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
													}
													_animateToPage(index);
												},
												icon: SizedBox(
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
																			width: _thumbnailSize,
																			height: _thumbnailSize,
																			fit: BoxFit.cover,
																			mayObscure: true
																		) : SavedAttachmentThumbnail(
																			file: File(widget.overrideSources[attachment.attachment]!.toFilePath()),
																			fit: BoxFit.cover
																		)
																	),
																	if (isNormalAttachment) Positioned(
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
																	if (showReplyCountsInGallery && ((widget.replyCounts[widget.attachments[index].attachment] ?? 0) > 0)) Container(
																		decoration: BoxDecoration(
																			borderRadius: BorderRadius.circular(4),
																			color: Colors.black54
																		),
																		padding: const EdgeInsets.all(4),
																		child: Text(
																			widget.replyCounts[widget.attachments[index].attachment]!.toString(),
																			style: const TextStyle(
																				color: Colors.white70,
																				fontSize: 14,
																				fontWeight: FontWeight.bold
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
										maxCrossAxisExtent: Settings.thumbnailSizeSetting.watch(context) * 1.5
									),
									itemBuilder: (context, index) {
										if (index == widget.attachments.length) {
											return Padding(
												padding: const EdgeInsets.all(6),
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
											);
										}
										final attachment = widget.attachments[index];
										final icon = attachment.attachment.icon;
										final isNormalAttachment = widget.overrideSources[attachment.attachment]?.scheme != 'file';
										return AdaptiveIconButton(
											minSize: 0,
											onPressed: () {
												_scrollSheetController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
												Future.delayed(const Duration(milliseconds: 100), () => _animateToPage(index));
											},
											icon: Container(
												padding: const EdgeInsets.all(4),
												margin: const EdgeInsets.all(2),
												decoration: BoxDecoration(
													borderRadius: const BorderRadius.all(Radius.circular(8)),
													color: attachment == currentAttachment ? theme.primaryColor : null
												),
												child: Stack(
													children: [
														ClipRRect(
															borderRadius: BorderRadius.circular(8),
															child: isNormalAttachment ? AttachmentThumbnail(
																gaplessPlayback: true,
																attachment: attachment.attachment,
																hero: null,
																width: 9999,
																height: 9999,
																fit: BoxFit.cover,
																mayObscure: true
															) : SavedAttachmentThumbnail(
																file: File(widget.overrideSources[attachment.attachment]!.toFilePath()),
																fit: BoxFit.cover
															)
														),
														if (isNormalAttachment) Positioned(
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
														if (showReplyCountsInGallery && ((widget.replyCounts[widget.attachments[index].attachment] ?? 0) > 0)) Center(
															child: Container(
																decoration: BoxDecoration(
																	borderRadius: BorderRadius.circular(8),
																	color: Colors.black54
																),
																padding: const EdgeInsets.all(8),
																child: Text(
																	widget.replyCounts[widget.attachments[index].attachment]!.toString(),
																	style: const TextStyle(
																		color: Colors.white70,
																		fontSize: 38,
																		fontWeight: FontWeight.bold
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
		return ExtendedImageSlidePage(
			resetPageDuration: const Duration(milliseconds: 100),
			slidePageBackgroundHandler: (offset, size) {
				_slideListenable.didUpdate();
				final factor = _dragPopFactor(offset, size);
				if (!showChrome) {
					_updateOverlays(factor > 1);
				}
				return Colors.black.withOpacity(1 - factor.clamp(0, 1));
			},
			slideEndHandler: (offset, {ScaleEndDetails? details, ExtendedImageSlidePageState? state}) {
				final a = ((details?.velocity ?? Velocity.zero).pixelsPerSecond.direction / pi).abs();
				return ((details?.pointerCount ?? 0) == 0) && widget.allowPop && (a >= 0.25 && a <= 0.75) && (state?.imageGestureState?.gestureDetails?.totalScale ?? 1) <= 1;
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
												if (currentAttachment.attachment.type.isVideo) AdaptiveIconButton(
													onPressed: () async {
														final actions = [
															...buildImageSearchActions(context, () => Future.value(currentAttachment.attachment)),
															...(widget.additionalContextMenuActionsBuilder?.call(currentAttachment) ?? const Iterable<ContextMenuAction>.empty())
														];
														await showAdaptiveModalPopup(
															context: context,
															builder: (context) => AdaptiveActionSheet(
																actions: actions.map((action) => AdaptiveActionSheetAction(
																	onPressed: () async {
																		Navigator.of(context).pop();
																		try {
																			await action.onPressed();
																		}
																		catch (e) {
																			if (context.mounted) {
																				alertError(context, e.toStringDio());
																			}
																		}
																	},
																	key: action.key,
																	isDestructiveAction: action.isDestructiveAction,
																	trailing: Icon(action.trailingIcon),
																	child: action.child
																)).toList(),
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
															if (!mounted || filename == null) return;
															showToast(context: context, message: 'Downloaded $filename', icon: CupertinoIcons.cloud_download);
														} : null,
														icon: currentController.isDownloaded ? const Icon(CupertinoIcons.cloud_download_fill) : const Icon(CupertinoIcons.cloud_download)
													)
												),
												AnimatedBuilder(
													animation: context.watch<Persistence>().savedAttachmentsListenable,
													builder: (context, child) {
														final currentlySaved = context.watch<Persistence>().getSavedAttachment(currentAttachment.attachment) != null;
														return AdaptiveIconButton(
															onPressed: currentController.canShare ? () async {
																if (currentlySaved) {
																	context.read<Persistence>().deleteSavedAttachment(currentAttachment.attachment);
																}
																else {
																	context.read<Persistence>().saveAttachment(currentAttachment.attachment, currentController.getFile(), currentController.cacheExt);
																}
															} : null,
															icon: Icon(currentlySaved ? Adaptive.icons.bookmarkFilled : Adaptive.icons.bookmark)
														);
													}
												),
												AdaptiveIconButton(
													key: _shareButtonKey,
													onPressed: currentController.canShare ? () {
														final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
														final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
														currentController.share((offset != null && size != null) ? offset & size : null);
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
											child: Padding(
												padding: showChrome ? EdgeInsets.only(
													bottom: (settings.showThumbnailsInGallery ? MediaQuery.sizeOf(context).height * 0.2 : (44 + MediaQuery.paddingOf(context).bottom)) - (currentController.videoPlayerController == null ? 44 : 0) - 16,
													right: 8
												) : const EdgeInsets.only(right: 8),
												child: Row(
													mainAxisSize: MainAxisSize.min,
													crossAxisAlignment: CrossAxisAlignment.end,
													children: [
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
											animation: _shouldShowPosition,
											child: Align(
												alignment: Alignment.bottomLeft,
												child: Container(
													margin: showChrome ? EdgeInsets.only(
														bottom: (settings.showThumbnailsInGallery ? MediaQuery.sizeOf(context).height * 0.2 : (44 + MediaQuery.paddingOf(context).bottom)) + 16 - (currentController.videoPlayerController == null ? 44 : 0),
														left: 16
													) : const EdgeInsets.all(16),
													padding: const EdgeInsets.all(8),
													decoration: const BoxDecoration(
														borderRadius: BorderRadius.all(Radius.circular(8)),
														color: Colors.black54
													),
													child: AnimatedBuilder(
														animation: _currentAttachmentChanged,
														builder: (context, _) => Text("${currentIndex + 1} / ${widget.attachments.length}", style: TextStyle(
															color: settings.darkTheme.primaryColor
														))
													)
												)
											),
											builder: (context, child) => AnimatedSwitcher(
												duration: const Duration(milliseconds: 300),
												child: _shouldShowPosition.value && (showChrome || settings.showOverlaysInGallery) ? child : const SizedBox.shrink()
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
													shouldIgnorePointer: false,
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
		_scrollCoalescer.close();
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
		__onPageControllerUpdateSubscription.cancel();
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
	Map<Attachment, int> replyCounts = const {},
	bool Function(Attachment)? isAttachmentAlreadyDownloaded,
	ValueChanged<Attachment>? onAttachmentDownload,
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
	final imageboard = context.read<Imageboard>();
	final navigator = fullscreen ? Navigator.of(context, rootNavigator: true) : context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context);
	await handleMutingBeforeShowingGallery();
	final lastSelected = await navigator.push(TransparentRoute<Attachment>(
		builder: (ctx) => ImageboardScope(
			imageboardKey: null,
			imageboard: imageboard,
			child: GalleryPage(
				attachments: attachments,
				replyCounts: replyCounts,
				overrideSources: overrideSources,
				initialGoodSources: initialGoodSources,
				isAttachmentAlreadyDownloaded: isAttachmentAlreadyDownloaded,
				onAttachmentDownload: onAttachmentDownload,
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
	Map<Attachment, int> replyCounts = const {},
	bool Function(Attachment)? isAttachmentAlreadyDownloaded,
	ValueChanged<Attachment>? onAttachmentDownload,
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
		semanticParentIds: semanticParentIds
	)).toList(),
	overrideSources: overrideSources,
	initialGoodSources: initialGoodSources,
	replyCounts: replyCounts,
	isAttachmentAlreadyDownloaded: isAttachmentAlreadyDownloaded,
	onAttachmentDownload: onAttachmentDownload,
	initialAttachment: initialAttachment == null ? null : TaggedAttachment(
		attachment: initialAttachment,
		semanticParentIds: semanticParentIds
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