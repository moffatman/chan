import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/status_bar.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/imageboard_scope.dart';
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
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 2,
      );
}

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Map<Attachment, int> replyCounts;
	final Map<Attachment, Uri> overrideSources;
	final Attachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<Attachment>? onChange;
	final Iterable<int> semanticParentIds;
	final bool allowScroll;
	final bool allowContextMenu;
	final bool allowChrome;
	final bool updateOverlays;

	const GalleryPage({
		required this.attachments,
		this.replyCounts = const {},
		this.overrideSources = const {},
		required this.initialAttachment,
		required this.semanticParentIds,
		this.initiallyShowChrome = false,
		this.onChange,
		this.allowScroll = true,
		this.allowChrome = true,
		this.allowContextMenu = true,
		this.updateOverlays = true,
		Key? key
	}) : super(key: key);

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> with TickerProviderStateMixin {
	late int currentIndex;
	Attachment get currentAttachment => widget.attachments[currentIndex];
	AttachmentViewerController get currentController => _getController(currentAttachment);
	bool firstControllerMade = false;
	late final ScrollController thumbnailScrollController;
	late final ScrollController _gridViewScrollController;
	late final ExtendedPageController pageController;
	late bool showChrome;
	bool showingOverlays = true;
	final Key _pageControllerKey = GlobalKey();
	final Key _thumbnailsKey = GlobalKey();
	late final BehaviorSubject<void> _scrollCoalescer;
	double? _lastpageControllerPixels;
	bool _animatingNow = false;
	final _shareButtonKey = GlobalKey();
	late final BehaviorSubject<void> _slideStream;
	bool _hideRotateButton = false;
	final Set<Attachment> _rotationsInProgress = {};
	late final AnimationController _rotateButtonAnimationController;
	final Map<Attachment, AttachmentViewerController> _controllers = {};
	late final ValueNotifier<bool> _shouldShowPosition;
	late final BehaviorSubject<void> _currentAttachmentChanged;
	late final BehaviorSubject<void> _rotationsChanged;
	late final DraggableScrollableController _scrollSheetController;
	final _draggableScrollableSheetKey = GlobalKey();
	late StreamSubscription<List<void>> __onPageControllerUpdateSubscription;

	@override
	void initState() {
		super.initState();
		_scrollCoalescer = BehaviorSubject();
		_slideStream = BehaviorSubject();
		_shouldShowPosition = ValueNotifier(false);
		_currentAttachmentChanged = BehaviorSubject();
		_rotationsChanged = BehaviorSubject();
		_scrollSheetController = DraggableScrollableController();
		_gridViewScrollController = ScrollController()..addListener(_onGridViewScrollControllerUpdate);
		_rotateButtonAnimationController = AnimationController(duration: const Duration(milliseconds: 5000), vsync: this, upperBound: pi * 2);
		showChrome = widget.initiallyShowChrome;
		_updateOverlays(showChrome);
		currentIndex = (widget.initialAttachment != null) ? max(0, widget.attachments.indexOf(widget.initialAttachment!)) : 0;
		pageController = ExtendedPageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_onPageControllerUpdate);
		__onPageControllerUpdateSubscription = _scrollCoalescer.bufferTime(const Duration(milliseconds: 10)).listen((_) => __onPageControllerUpdate());
		final attachment = widget.attachments[currentIndex];
		if (context.read<EffectiveSettings>().autoloadAttachments || context.read<EffectiveSettings>().alwaysAutoloadTappedAttachment) {
			_getController(attachment).loadFullAttachment().then((x) => _currentAttachmentChanged.add(null));
		}
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (!firstControllerMade) {
			final initialOffset = ((_thumbnailSize + 12) * (currentIndex + 0.5)) - (MediaQuery.of(context).size.width / 2);
			final maxOffset = ((_thumbnailSize + 12) * widget.attachments.length) - MediaQuery.of(context).size.width;
			if (maxOffset > 0) {
				thumbnailScrollController = ScrollController(initialScrollOffset: initialOffset.clamp(0, maxOffset));
			}
			else {
				// Not scrollable (not large enough to need to scroll)
				thumbnailScrollController = ScrollController();
			}
			thumbnailScrollController.addListener(_onThumbnailScrollControllerUpdate);
			Future.delayed(const Duration(milliseconds: 100), _onThumbnailScrollControllerUpdate);
			firstControllerMade = true;
		}
	}

	@override
	void didUpdateWidget(GalleryPage old) {
		super.didUpdateWidget(old);
		if (widget.initialAttachment != old.initialAttachment) {
			currentIndex = (widget.initialAttachment != null) ? max(0, widget.attachments.indexOf(widget.initialAttachment!)) : 0;
			if (context.read<EffectiveSettings>().autoloadAttachments) {
				final attachment = widget.attachments[currentIndex];
				_getController(attachment).loadFullAttachment().then((x) => _currentAttachmentChanged.add(null));
			}
		}
	}

	void _onThumbnailScrollControllerUpdate() {
		if (_gridViewScrollController.hasOnePosition && !_gridViewScrollController.position.isScrollingNotifier.value) {
			_gridViewScrollController.position.jumpTo(
				(_gridViewScrollController.position.maxScrollExtent * (thumbnailScrollController.position.pixels / thumbnailScrollController.position.maxScrollExtent))
					.clamp(_gridViewScrollController.position.minScrollExtent, _gridViewScrollController.position.maxScrollExtent)
			);
		}
	}

	void _onGridViewScrollControllerUpdate() {
		if (thumbnailScrollController.hasOnePosition && !thumbnailScrollController.position.isScrollingNotifier.value) {
			thumbnailScrollController.position.jumpTo(
				(thumbnailScrollController.position.maxScrollExtent * (_gridViewScrollController.position.pixels / _gridViewScrollController.position.maxScrollExtent))
					.clamp(thumbnailScrollController.position.minScrollExtent, thumbnailScrollController.position.maxScrollExtent)
			);
		}
	}

	AttachmentViewerController _getController(Attachment attachment) {
		if (_controllers[attachment] == null) {
			_controllers[attachment] = AttachmentViewerController(
				context: context,
				attachment: attachment,
				redrawGestureStream: _slideStream,
				site: context.read<ImageboardSite>(),
				isPrimary: attachment == currentAttachment,
				overrideSource: widget.overrideSources[attachment]
			);
		}
		return _controllers[attachment]!;
	}

	void _updateOverlays(bool show) async {
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
		if (pageController.hasClients && pageController.position.pixels != _lastpageControllerPixels) {
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
		if (context.read<EffectiveSettings>().autoloadAttachments) {
			_getController(attachment).loadFullAttachment().then((x) {
				if (mounted) {
					_currentAttachmentChanged.add(null);
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
		final displayIsLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
		return attachment.isLandscape != null && displayIsLandscape != attachment.isLandscape;
	}

	void _rotate(Attachment attachment) async {
		if (attachment == currentAttachment) {
			_rotateButtonAnimationController.repeat();
		}
		_rotationsInProgress.add(attachment);
		_rotationsChanged.add(null);
		await _getController(attachment).rotate();
		_rotationsInProgress.remove(attachment);
		_rotationsChanged.add(null);
		if (attachment == currentAttachment) {
			_rotateButtonAnimationController.reset();
		}
	}

	void _onPageChanged(int index) async {
		_rotateButtonAnimationController.reset();
		if (_rotationsInProgress.contains(widget.attachments[index])) {
			_rotateButtonAnimationController.repeat();
		}
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		currentIndex = index;
		if (!_animatingNow) {
			final settings = context.read<EffectiveSettings>();
			if (settings.autoloadAttachments) {
				_getController(attachment).loadFullAttachment().then((x) {
					if (!mounted) return;
					_currentAttachmentChanged.add(null);
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
			if (settings.autoRotateInGallery && _rotationAppropriate(attachment) && _getController(attachment).quarterTurns == 0) {
				_getController(attachment).rotate();
			}
			for (final c in _controllers.entries) {
				c.value.isPrimary = c.key == currentAttachment;
			}
			_currentAttachmentChanged.add(null);
		}
		_hideRotateButton = false;
		_shouldShowPosition.value = true;
		await Future.delayed(const Duration(seconds: 1));
		if (currentIndex == index) {
			_shouldShowPosition.value = false;
		}
	}

	void _downloadAll() async {
		final toDownload = widget.attachments.where((a) => !_getController(a).isDownloaded).toList();
		final shouldDownload = await showCupertinoDialog<bool>(
			context: context,
			barrierDismissible: true,
			builder: (context) => CupertinoAlertDialog(
				title: const Text('Download all?'),
				content: Text("${describeCount(toDownload.length, 'attachment')} will be saved to your library"),
				actions: [
					CupertinoDialogAction(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction(
						isDefaultAction: true,
						child: const Text('Yes'),
						onPressed: () {
							Navigator.of(context).pop(true);
						},
					)
				]
			)
		);
		if (shouldDownload == true) {
			final loadingStream = ValueNotifier<int>(0);
			bool cancel = false;
			showCupertinoDialog(
				context: context,
				barrierDismissible: false,
				builder: (context) => CupertinoAlertDialog(
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
						CupertinoDialogAction(
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
		_updateOverlays(showChrome);
		setState(() {});
	}

	double _dragPopFactor(Offset offset, Size size) {
		final threshold = size.bottomRight(Offset.zero).distance / 3;
		return offset.distance / threshold;
	}

	double get _maxScrollSheetSize => 1 - (((currentController.videoPlayerController == null ? -44 : -44) + kMinInteractiveDimensionCupertino + MediaQuery.of(context).viewPadding.top) / MediaQuery.of(context).size.height);

	double get _minScrollSheetSize {
		if (context.read<EffectiveSettings>().showThumbnailsInGallery) {
			return 0.2;
		}
		if (currentController.videoPlayerController != null) {
			return (44 + MediaQuery.of(context).padding.bottom) / MediaQuery.of(context).size.height;
		}
		return 0.0;
	}

	Widget _buildScrollSheetChild(ScrollController controller) {
		return StreamBuilder(
			stream: _currentAttachmentChanged,
			builder: (context, child) {
				return Padding(
					padding: currentController.videoPlayerController == null ? const EdgeInsets.only(top: 44) : EdgeInsets.zero,
					child: SingleChildScrollView(
						controller: controller,
						physics: const BouncingScrollPhysics(),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								ClipRect(
									child: BackdropFilter(
										filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
										child: Container(
											color: Colors.black38,
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													if (currentController.videoPlayerController != null) VideoControls(
														controller: currentController.videoPlayerController!,
														hasAudio: currentController.hasAudio
													),
													SizedBox(
														height: _thumbnailSize + 8,
														child: KeyedSubtree(
															key: _thumbnailsKey,
															child: ListView.builder(
																cacheExtent: 99999,
																controller: thumbnailScrollController,
																itemCount: widget.attachments.length,
																scrollDirection: Axis.horizontal,
																itemBuilder: (context, index) {
																	final attachment = widget.attachments[index];
																	return CupertinoButton(
																		padding: EdgeInsets.zero,
																		minSize: 0,
																		onPressed: () => _animateToPage(index),
																		child: SizedBox(
																			width: _thumbnailSize + 8,
																			height: _thumbnailSize + 8,
																			child: Center(
																				child: Container(
																					decoration: BoxDecoration(
																						color: Colors.transparent,
																						borderRadius: const BorderRadius.all(Radius.circular(4)),
																						border: Border.all(color: attachment == currentAttachment ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
																					),
																					margin: const EdgeInsets.all(4),
																					child: Stack(
																						children: [
																							ClipRRect(
																								borderRadius: BorderRadius.circular(4),
																								child: AttachmentThumbnail(
																									gaplessPlayback: true,
																									attachment: widget.attachments[index],
																									width: _thumbnailSize,
																									height: _thumbnailSize,
																									fit: BoxFit.cover
																								)
																							),
																							if (context.watch<EffectiveSettings>().showReplyCountsInGallery && ((widget.replyCounts[widget.attachments[index]] ?? 0) > 0)) SizedBox(
																								width: _thumbnailSize,
																								child: Center(
																									child: Container(
																										decoration: BoxDecoration(
																											borderRadius: BorderRadius.circular(4),
																											color: Colors.black54
																										),
																										padding: const EdgeInsets.all(4),
																										child: Text(
																											widget.replyCounts[widget.attachments[index]]!.toString(),
																											style: const TextStyle(
																												color: Colors.white70,
																												fontSize: 14,
																												fontWeight: FontWeight.bold
																											)
																										)
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
														height: MediaQuery.of(context).size.height - (_thumbnailSize + 8 + kMinInteractiveDimensionCupertino + MediaQuery.of(context).viewPadding.top),
														child: GridView.builder(
															scrollDirection: Axis.horizontal,
															cacheExtent: 99999,
															controller: _gridViewScrollController,
															gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
																maxCrossAxisExtent: context.select<EffectiveSettings, double>((s) => s.thumbnailSize) * 1.5
															),
															itemBuilder: (context, index) {
																if (index == widget.attachments.length) {
																	return Padding(
																		padding: const EdgeInsets.all(4),
																		child: CupertinoButton.filled(
																			padding: const EdgeInsets.all(8),
																			onPressed: _downloadAll,
																			child: FittedBox(
																				fit: BoxFit.contain,
																				child: Column(
																					mainAxisSize: MainAxisSize.min,
																					children: const [
																						Icon(CupertinoIcons.cloud_download, size: 50),
																						Text('Download all')
																					]
																				)
																			)
																		)
																	);
																}
																final attachment = widget.attachments[index];
																return CupertinoButton(
																	padding: EdgeInsets.zero,
																	minSize: 0,
																	onPressed: () {
																		_scrollSheetController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
																		Future.delayed(const Duration(milliseconds: 100), () => _animateToPage(index));
																	},
																	child: Container(
																		decoration: BoxDecoration(
																			borderRadius: const BorderRadius.all(Radius.circular(8)),
																			border: Border.all(color: attachment == currentAttachment ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 4)
																		),
																		child: Stack(
																			children: [
																				ClipRRect(
																					borderRadius: BorderRadius.circular(8),
																					child: AttachmentThumbnail(
																						gaplessPlayback: true,
																						attachment: widget.attachments[index],
																						hero: null,
																						width: 9999,
																						height: 9999,
																						fit: BoxFit.cover,
																					)
																				),
																				if (context.watch<EffectiveSettings>().showReplyCountsInGallery && ((widget.replyCounts[widget.attachments[index]] ?? 0) > 0)) Center(
																					child: Container(
																						decoration: BoxDecoration(
																							borderRadius: BorderRadius.circular(8),
																							color: Colors.black54
																						),
																						padding: const EdgeInsets.all(8),
																						child: Text(
																							widget.replyCounts[widget.attachments[index]]!.toString(),
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
													)
												]
											)
										)
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
													child: ClipRect(
														child: BackdropFilter(
															filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
															child:Container(
																padding: const EdgeInsets.only(bottom: 800),
																alignment: Alignment.topCenter,
																child: Container(
																	margin: const EdgeInsets.only(top: 70),
																	padding: const EdgeInsets.all(16),
																	decoration: BoxDecoration(
																		borderRadius: BorderRadius.circular(8),
																		color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.5)
																	),
																	child: Row(
																		mainAxisSize: MainAxisSize.min,
																		children: const [
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
												)
											]
										)
									)
								)
							]
						)
					)
				);
			}
		);
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		final layoutInsets = MediaQuery.of(context).padding;
		return ExtendedImageSlidePage(
			resetPageDuration: const Duration(milliseconds: 100),
			slidePageBackgroundHandler: (offset, size) {
				_slideStream.add(null);
				final factor = _dragPopFactor(offset, size);
				if (!showChrome) {
					_updateOverlays(factor > 1);
				}
				return Colors.black.withOpacity(1 - factor.clamp(0, 1));
			},
			slideEndHandler: (offset, {ScaleEndDetails? details, ExtendedImageSlidePageState? state}) {
				final a = ((details?.velocity ?? Velocity.zero).pixelsPerSecond.direction / pi).abs();
				return ((details?.pointerCount ?? 0) == 0) && widget.allowScroll && (a >= 0.25 && a <= 0.75) && (state?.imageGestureState?.gestureDetails?.totalScale ?? 1) <= 1;
			},
			child: CupertinoTheme(
				data: settings.makeDarkTheme(context),
				child: CupertinoPageScaffold(
					backgroundColor: Colors.transparent,
					navigationBar: showChrome ? CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: StreamBuilder(
							stream: _currentAttachmentChanged,
							builder: (context, _) => Padding(
								padding: const EdgeInsets.only(bottom: 4),
								child: AutoSizeText(
									"${currentAttachment.filename} (${currentAttachment.width}x${currentAttachment.height}${currentAttachment.sizeInBytes == null ? ')' : ', ${(currentAttachment.sizeInBytes! / 1024).round()} KB)'}",
									minFontSize: 8
								)
							)
						),
						backgroundColor: Colors.black38,
						trailing: StreamBuilder(
							stream: _currentAttachmentChanged,
							builder: (context, _) => AnimatedBuilder(
								animation: currentController,
								builder: (context, _) {
									return Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											if (!settings.showThumbnailsInGallery) CupertinoButton(
												padding: EdgeInsets.zero,
												onPressed: () {
													_scrollSheetController.animateTo(
														_scrollSheetController.size > 0.5 ? 0 : _maxScrollSheetSize,
														duration: const Duration(milliseconds: 250),
														curve: Curves.ease
													);
												},
												child: const Icon(CupertinoIcons.rectangle_grid_2x2)
											),
											CupertinoButton(
												padding: EdgeInsets.zero,
												onPressed: currentController.canShare && !currentController.isDownloaded ? () async {
													await currentController.download();
													if (!mounted) return;
													showToast(context: context, message: 'Downloaded ${currentAttachment.filename}', icon: CupertinoIcons.cloud_download);
												} : null,
												child: const Icon(CupertinoIcons.cloud_download)
											),
											StreamBuilder(
												stream: context.watch<Persistence>().savedAttachmentsNotifier,
												builder: (context, child) {
													final currentlySaved = context.watch<Persistence>().getSavedAttachment(currentAttachment) != null;
													return CupertinoButton(
														padding: EdgeInsets.zero,
														onPressed: currentController.canShare ? () async {
															if (currentlySaved) {
																context.read<Persistence>().deleteSavedAttachment(currentAttachment);
															}
															else {
																context.read<Persistence>().saveAttachment(currentAttachment, await currentController.getFile());
															}
														} : null,
														child: Icon(currentlySaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark)
													);
												}
											),
											CupertinoButton(
												key: _shareButtonKey,
												padding: EdgeInsets.zero,
												onPressed: currentController.canShare ? () {
													final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
													final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
													currentController.share((offset != null && size != null) ? offset & size : null);
												} : null,
												child: const Icon(CupertinoIcons.share)
											)
										]
									);
								}
							)
						)
					) : null,
					child: Shortcuts(
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
												physics: settings.showAnimations ? null : const _FasterSnappingPageScrollPhysics(),
												canScrollPage: (x) => settings.allowSwipingInGallery && widget.allowScroll,
												onPageChanged: _onPageChanged,
												controller: pageController,
												itemCount: widget.attachments.length,
												itemBuilder: (context, index) {
													final attachment = widget.attachments[index];
													return TransformedMediaQuery(
														transformation: (data) => data.copyWith(
															gestureSettings: DeviceGestureSettings(
																touchSlop: (data.gestureSettings.touchSlop ?? kTouchSlop) * 2
															)
														),
														child: AnimatedBuilder(
															animation: _getController(attachment),
															builder: (context, _) => GestureDetector(
																onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																	_getController(attachment).loadFullAttachment().then((x) => _currentAttachmentChanged.add(null));
																},
																child: AttachmentViewer(
																	controller: _getController(attachment),
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
																	semanticParentIds: widget.semanticParentIds,
																	onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																		_getController(attachment).loadFullAttachment().then((x) => _currentAttachmentChanged.add(null));
																	},
																	layoutInsets: layoutInsets,
																	allowContextMenu: widget.allowContextMenu,
																)
															)
														)
													);
												}
											)
										),
										StreamBuilder(
											stream: _rotationsChanged.mergeWith([_currentAttachmentChanged]),
											builder: (context, _) {
												return Align(
													alignment: Alignment.bottomRight,
													child: Row(
														mainAxisSize: MainAxisSize.min,
														crossAxisAlignment: CrossAxisAlignment.end,
														children: [
															ValueListenableBuilder<bool>(
																valueListenable: settings.muteAudio,
																builder: (context, muted, _) => AnimatedSwitcher(
																	duration: const Duration(milliseconds: 300),
																	child: currentController.hasAudio ? Align(
																		key: ValueKey<bool>(muted),
																		alignment: Alignment.bottomLeft,
																		child: CupertinoButton(
																			padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
																			child: muted ? const Icon(CupertinoIcons.volume_off) : const Icon(CupertinoIcons.volume_up),
																			onPressed: () {
																				if (muted) {
																					currentController.videoPlayerController?.setVolume(1);
																					settings.setMuteAudio(false);
																				}
																				else {
																					currentController.videoPlayerController?.setVolume(0);
																					settings.setMuteAudio(true);
																				}
																			}
																		)
																	) : const SizedBox.shrink()
																)																		
															),
															AnimatedSwitcher(
																duration: const Duration(milliseconds: 300),
																child: (_rotationAppropriate(currentAttachment) && !_hideRotateButton) ? RotationTransition(
																		key: ValueKey<bool>(_rotationsInProgress.contains(currentAttachment) || currentController.quarterTurns == 0),
																		turns: _rotationsInProgress.contains(currentAttachment) ? Tween(begin: 0.0, end: 1.0).animate(_rotateButtonAnimationController) : const AlwaysStoppedAnimation(0.0),
																		child: CupertinoButton(
																			padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
																			child: Transform(
																				alignment: Alignment.center,
																				transform: _rotationsInProgress.contains(currentAttachment) || currentController.quarterTurns == 0 ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
																				child: const Icon(CupertinoIcons.rotate_left)
																			),
																			onPressed: () {
																				if (currentController.quarterTurns == 1) {
																					currentController.unrotate();
																				}
																				else {
																					_rotate(currentAttachment);
																				}
																				_rotationsChanged.add(null);
																			}
																		)
																	) : const SizedBox.shrink()
															),
															const SizedBox(width: 8)
														]
													)
												);
											}
										),
										AnimatedBuilder(
											animation: _shouldShowPosition,
											child: Align(
												alignment: Alignment.bottomLeft,
												child: Container(
													margin: showChrome ? EdgeInsets.only(
														bottom: (settings.showThumbnailsInGallery ? MediaQuery.of(context).size.height * 0.2 : (44 + MediaQuery.of(context).padding.bottom)) + 16 - (currentController.videoPlayerController == null ? 44 : 0),
														left: 16
													) : const EdgeInsets.all(16),
													padding: const EdgeInsets.all(8),
													decoration: const BoxDecoration(
														borderRadius: BorderRadius.all(Radius.circular(8)),
														color: Colors.black54
													),
													child: StreamBuilder(
														stream: _currentAttachmentChanged,
														builder: (context, _) => Text("${currentIndex + 1} / ${widget.attachments.length}", style: TextStyle(
															color: CupertinoTheme.of(context).primaryColor
														))
													)
												)
											),
											builder: (context, child) => AnimatedSwitcher(
												duration: const Duration(milliseconds: 300),
												child: _shouldShowPosition.value ? child : Container()
											)
										),
										Visibility(
											visible: showChrome,
											maintainState: true,
											maintainSize: true,
											maintainAnimation: true,
											child: AnimatedBuilder(
												animation: currentController,
												builder: (context, _) => DraggableScrollableSheet(
													key: _draggableScrollableSheetKey,
													snap: true,
													snapAnimationDuration: const Duration(milliseconds: 200),
													initialChildSize: _minScrollSheetSize,
													maxChildSize: _maxScrollSheetSize,
													minChildSize: _minScrollSheetSize,
													controller: _scrollSheetController,
													builder: (context, controller) => _buildScrollSheetChild(controller)
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
		super.dispose();
		pageController.dispose();
		_scrollCoalescer.close();
		_currentAttachmentChanged.close();
		_rotationsChanged.close();
		thumbnailScrollController.dispose();
		_slideStream.close();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
		_shouldShowPosition.dispose();
		_rotateButtonAnimationController.dispose();
		__onPageControllerUpdateSubscription.cancel();
		_gridViewScrollController.dispose();
	}
}

Future<Attachment?> showGallery({
	required BuildContext context,
	required List<Attachment> attachments,
	Map<Attachment, Uri> overrideSources = const {},
	Map<Attachment, int> replyCounts = const {},
	required Iterable<int> semanticParentIds,
	Attachment? initialAttachment,
	bool initiallyShowChrome = false,
	bool allowChrome = true,
	bool allowContextMenu = true,
	ValueChanged<Attachment>? onChange,
}) async {
	final imageboard = context.read<Imageboard>();
	final showAnimations = context.read<EffectiveSettings>().showAnimations;
	final lastSelected = await Navigator.of(context, rootNavigator: true).push(TransparentRoute<Attachment>(
		builder: (ctx) => ImageboardScope(
			imageboardKey: null,
			imageboard: imageboard,
			child: GalleryPage(
				attachments: attachments,
				replyCounts: replyCounts,
				overrideSources: overrideSources,
				initialAttachment: initialAttachment,
				initiallyShowChrome: initiallyShowChrome,
				onChange: onChange,
				semanticParentIds: semanticParentIds,
				allowChrome: allowChrome,
				allowContextMenu: allowContextMenu,
			)
		),
		showAnimations: showAnimations
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