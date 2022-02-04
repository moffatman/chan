import 'dart:async';
import 'dart:math' as math;
import 'dart:math';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/status_bar.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/cupertino.dart';
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

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Map<Attachment, Uri> overrideSources;
	final Attachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<Attachment>? onChange;
	final Iterable<int> semanticParentIds;
	final bool allowScroll;

	const GalleryPage({
		required this.attachments,
		this.overrideSources = const {},
		required this.initialAttachment,
		required this.semanticParentIds,
		this.initiallyShowChrome = false,
		this.onChange,
		this.allowScroll = true,
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
	late final ExtendedPageController pageController;
	late bool showChrome;
	bool showingOverlays = true;
	final Key _pageControllerKey = GlobalKey();
	final Key _thumbnailsKey = GlobalKey();
	final BehaviorSubject<void> _scrollCoalescer = BehaviorSubject();
	double? _lastpageControllerPixels;
	bool _animatingNow = false;
	final _shareButtonKey = GlobalKey();
	final _slideStream = BehaviorSubject<void>();
	bool _hideRotateButton = false;
	final Set<Attachment> _rotationsInProgress = {};
	late final AnimationController _rotateButtonAnimationController;
	final Map<Attachment, AttachmentViewerController> _controllers = {};
	final _shouldShowPosition = ValueNotifier<bool>(false);
	Widget? scrollSheetChild;
	ScrollController? scrollSheetController;
	final _currentAttachmentChanged = BehaviorSubject<void>();
	final _rotationsChanged = BehaviorSubject<void>();

	@override
	void initState() {
		super.initState();
		_rotateButtonAnimationController = AnimationController(duration: const Duration(milliseconds: 5000), vsync: this, upperBound: pi * 2);
		showChrome = widget.initiallyShowChrome;
		_updateOverlays(showChrome);
		currentIndex = (widget.initialAttachment != null) ? widget.attachments.indexOf(widget.initialAttachment!) : 0;
		pageController = ExtendedPageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_onPageControllerUpdate);
		_scrollCoalescer.bufferTime(const Duration(milliseconds: 10)).listen((_) => __onPageControllerUpdate());
		final attachment = widget.attachments[currentIndex];
		_getController(attachment).loadFullAttachment(context);
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
			firstControllerMade = true;
		}
	}

	@override
	void didUpdateWidget(GalleryPage old) {
		super.didUpdateWidget(old);
		if (widget.initialAttachment != old.initialAttachment) {
			currentIndex = (widget.initialAttachment != null) ? widget.attachments.indexOf(widget.initialAttachment!) : 0;
			if (context.read<EffectiveSettings>().autoloadAttachments) {
				final attachment = widget.attachments[currentIndex];
				_getController(attachment).loadFullAttachment(context);
			}
		}
	}

	AttachmentViewerController _getController(Attachment attachment) {
		if (_controllers[attachment] == null) {
			_controllers[attachment] = AttachmentViewerController(
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
		if (pageController.hasClients && pageController.position.pixels != _lastpageControllerPixels) {
			_lastpageControllerPixels = pageController.position.pixels;
			final factor = pageController.position.pixels / pageController.position.maxScrollExtent;
			final idealLocation = (thumbnailScrollController.position.maxScrollExtent + thumbnailScrollController.position.viewportDimension - _thumbnailSize - 12) * factor - (thumbnailScrollController.position.viewportDimension / 2) + (_thumbnailSize / 2 + 6);
			thumbnailScrollController.jumpTo(idealLocation.clamp(0, thumbnailScrollController.position.maxScrollExtent));
		}
	}

	Future<void> _animateToPage(int index, {int milliseconds = 200}) async {
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		if (context.read<EffectiveSettings>().autoloadAttachments) {
			_getController(attachment).loadFullAttachment(context);
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
				_getController(attachment).loadFullAttachment(context);
				if (index > 0) {
					final previousAttachment = widget.attachments[index - 1];
					_getController(previousAttachment).preloadFullAttachment(context);
				}
				if (index < (widget.attachments.length - 1)) {
					final nextAttachment = widget.attachments[index + 1];
					_getController(nextAttachment).preloadFullAttachment(context);
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
				content: Text("${toDownload.length} attachment${toDownload.length == 1 ? '' : 's'} will be saved to your library"),
				actions: [
					CupertinoDialogAction(
						child: const Text('No'),
						onPressed: () {
							Navigator.of(context).pop(false);
						}
					),
					CupertinoDialogAction(
						child: const Text('Yes'),
						isDefaultAction: true,
						onPressed: () {
							Navigator.of(context).pop(true);
						}
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
							child: const Text('Cancel'),
							isDestructiveAction: true,
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
				await _getController(attachment).preloadFullAttachment(context);
				await _getController(attachment).download();
				loadingStream.value = loadingStream.value + 1;
			}
			if (!cancel) Navigator.of(context, rootNavigator: true).pop();
		}
	}

	void _toggleChrome() {
		showChrome = !showChrome;
		_updateOverlays(showChrome);
		setState(() {});
	}

	double _dragPopFactor(Offset offset, Size size) {
		final threshold = size.bottomRight(Offset.zero).distance / 3;
		return offset.distance / threshold;
	}

	Widget _buildScrollSheetChild(ScrollController controller) {
		return StreamBuilder(
			stream: _currentAttachmentChanged,
			builder: (context, child) {
				return Padding(
					padding: currentController.videoPlayerController == null ? const EdgeInsets.only(top: 44) : EdgeInsets.zero,
					child: ClipRect(
						child: BackdropFilter(
							filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
							child: Container(
								color: Colors.black38,
								child: CustomScrollView(
									cacheExtent: 500,
									controller: controller,
									slivers: [
										if (currentController.videoPlayerController != null) SliverToBoxAdapter(
											child: VideoControls(
												controller: currentController.videoPlayerController!,
												hasAudio: currentController.hasAudio
											)
										),
										SliverToBoxAdapter(
											child: SizedBox(
												height: _thumbnailSize + 8,
												child: KeyedSubtree(
													key: _thumbnailsKey,
													child: ListView.builder(
														controller: thumbnailScrollController,
														itemCount: widget.attachments.length,
														scrollDirection: Axis.horizontal,
														itemBuilder: (context, index) {
															final attachment = widget.attachments[index];
															return GestureDetector(
																onTap: () => _animateToPage(index),
																child: Container(
																	decoration: BoxDecoration(
																		color: Colors.transparent,
																		borderRadius: const BorderRadius.all(Radius.circular(4)),
																		border: Border.all(color: attachment == currentAttachment ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
																	),
																	margin: const EdgeInsets.all(4),
																	child: AttachmentThumbnail(
																		gaplessPlayback: true,
																		attachment: widget.attachments[index],
																		width: _thumbnailSize,
																		height: _thumbnailSize
																	)
																)
															);
														}
													)
												)
											)
										),
										SliverGrid(
											gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
												maxCrossAxisExtent: 200
											),
											delegate: SliverChildBuilderDelegate(
												(context, index) {
													if (index == widget.attachments.length) {
														return Center(
															child: CupertinoButton.filled(
																padding: const EdgeInsets.all(8),
																child: Column(
																	mainAxisSize: MainAxisSize.min,
																	children: const [
																		Icon(CupertinoIcons.cloud_download, size: 50),
																		Text('Download all')
																	]
																),
																onPressed: _downloadAll
															)
														);
													}
													final attachment = widget.attachments[index];
													return GestureDetector(
														onTap: () {
															DraggableScrollableActuator.reset(context);
															Future.delayed(const Duration(milliseconds: 100), () => _animateToPage(index));
														},
														child: Container(
															decoration: BoxDecoration(
																color: Colors.transparent,
																borderRadius: const BorderRadius.all(Radius.circular(4)),
																border: Border.all(color: attachment == currentAttachment ? CupertinoTheme.of(context).primaryColor : Colors.transparent, width: 2)
															),
															margin: const EdgeInsets.all(4),
															child: AttachmentThumbnail(
																gaplessPlayback: true,
																attachment: widget.attachments[index],
																width: 200,
																height: 200,
																hero: null
															)
														)
													);
												},
												childCount: widget.attachments.length + 1
											)
										)
									]
								)
							)
						)
					)
				);
			}
		);
	}

	@override
	Widget build(BuildContext context) {
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
				return widget.allowScroll && (a >= 0.25 && a <= 0.75);
			},
			child: CupertinoTheme(
				data: const CupertinoThemeData(brightness: Brightness.dark, primaryColor: Colors.white),
				child: CupertinoPageScaffold(
					backgroundColor: Colors.transparent,
					navigationBar: showChrome ? CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: StreamBuilder(
							stream: _currentAttachmentChanged,
							builder: (context, _) => AutoSizeText("${currentAttachment.filename} (${currentAttachment.width}x${currentAttachment.height})")
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
											CupertinoButton(
												padding: EdgeInsets.zero,
												child: const Icon(CupertinoIcons.cloud_download),
												onPressed: currentController.canShare && !currentController.isDownloaded ? currentController.download : null
											),
											StreamBuilder(
												stream: context.watch<Persistence>().savedAttachmentsNotifier,
												builder: (context, child) {
													final currentlySaved = context.watch<Persistence>().getSavedAttachment(currentAttachment) != null;
													return CupertinoButton(
														padding: EdgeInsets.zero,
														child: Icon(currentlySaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark),
														onPressed: currentController.canShare ? () {
															if (currentlySaved) {
																context.read<Persistence>().deleteSavedAttachment(currentAttachment);
															}
															else {
																context.read<Persistence>().saveAttachment(currentAttachment, currentController.cachedFile!);
															}
														} : null
													);
												}
											),
											CupertinoButton(
												key: _shareButtonKey,
												padding: EdgeInsets.zero,
												child: const Icon(CupertinoIcons.share),
												onPressed: currentController.canShare ? () {
													final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
													final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
													currentController.share((offset != null && size != null) ? offset & size : null);
												} : null
											)
										]
									);
								}
							)
						)
					) : null,
					child: Container(
							height: double.infinity,
							color: Colors.transparent,
							child: Shortcuts(
								shortcuts: {
									LogicalKeySet(LogicalKeyboardKey.arrowLeft): const GalleryLeftIntent(),
									LogicalKeySet(LogicalKeyboardKey.arrowRight): const GalleryRightIntent(),
									LogicalKeySet(LogicalKeyboardKey.space): const GalleryToggleChromeIntent(),
									LogicalKeySet(LogicalKeyboardKey.keyG): const DismissIntent(),
									LogicalKeySet(LogicalKeyboardKey.tab): Intent.doNothing
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
														canScrollPage: (x) => widget.allowScroll,
														onPageChanged: _onPageChanged,
														controller: pageController,
														itemCount: widget.attachments.length,
														itemBuilder: (context, index) {
															final attachment = widget.attachments[index];
															return AnimatedBuilder(
																animation: _getController(attachment),
																builder: (context, _) => GestureDetector(
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
																		semanticParentIds: widget.semanticParentIds
																	),
																	onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																		_getController(attachment).loadFullAttachment(context);
																	}
																)
															);
														}
													)
												),
												StreamBuilder(
													stream: _rotationsChanged.mergeWith([_currentAttachmentChanged]),
													builder: (context, _) => AnimatedSwitcher(
														duration: const Duration(milliseconds: 300),
														child: (_rotationAppropriate(currentAttachment) && !_hideRotateButton) ? Align(
															key: ValueKey<bool>(_rotationsInProgress.contains(currentAttachment) || currentController.quarterTurns == 0),
															alignment: Alignment.bottomRight,
															child: RotationTransition(
																turns: _rotationsInProgress.contains(currentAttachment) ? Tween(begin: 0.0, end: 1.0).animate(_rotateButtonAnimationController) : const AlwaysStoppedAnimation(0.0),
																child: CupertinoButton(
																	padding: const EdgeInsets.all(24),
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
															)
														) : Container()
													)
												),
												AnimatedBuilder(
													animation: _shouldShowPosition,
													child: Align(
														alignment: Alignment.bottomLeft,
														child: Container(
															margin: const EdgeInsets.all(16),
															padding: const EdgeInsets.all(8),
															decoration: const BoxDecoration(
																borderRadius: BorderRadius.all(Radius.circular(8)),
																color: Colors.black54
															),
															child: StreamBuilder(
																stream: _currentAttachmentChanged,
																builder: (context, _) => Text("${currentIndex + 1} / ${widget.attachments.length}")
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
													child: DraggableScrollableActuator(
														child: DraggableScrollableSheet(
															snap: true,
															initialChildSize: 0.20,
															maxChildSize: 1 - ((kMinInteractiveDimensionCupertino + MediaQuery.of(context).viewPadding.top) / MediaQuery.of(context).size.height),
															minChildSize: 0.20,
															builder: (context, controller) {
																if (scrollSheetChild == null || controller != scrollSheetController) {
																	scrollSheetController = controller;
																	scrollSheetChild = _buildScrollSheetChild(controller);
																}
																return scrollSheetChild!;
															}
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
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		thumbnailScrollController.dispose();
		_slideStream.close();
		for (final controller in _controllers.values) {
			controller.dispose();
		}
	}
}

Future<Attachment?> showGallery({
	required BuildContext context,
	required List<Attachment> attachments,
	Map<Attachment, Uri> overrideSources = const {},
	required Iterable<int> semanticParentIds,
	Attachment? initialAttachment,
	bool initiallyShowChrome = false,
	ValueChanged<Attachment>? onChange,
}) async {
	final lastSelected = await Navigator.of(context, rootNavigator: true).push(TransparentRoute<Attachment>(
		builder: (BuildContext _context) {
			return GalleryPage(
				attachments: attachments,
				overrideSources: overrideSources,
				initialAttachment: initialAttachment,
				initiallyShowChrome: initiallyShowChrome,
				onChange: onChange,
				semanticParentIds: semanticParentIds
			);
		}
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