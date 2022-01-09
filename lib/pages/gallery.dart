import 'dart:async';
import 'dart:io';
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
import 'package:share_plus/share_plus.dart';
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
		_getController(widget.attachments[currentIndex]).loadFullAttachment();
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
				_getController(widget.attachments[currentIndex]).loadFullAttachment();
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
			_controllers[attachment]!.addListener(() => setState(() => {}));
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
			_getController(attachment).loadFullAttachment();
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
		setState(() {});
		await _getController(attachment).rotate();
		_rotationsInProgress.remove(attachment);
		setState(() {});
		if (attachment == currentAttachment) {
			_rotateButtonAnimationController.reset();
		}
	}

	void _onPageChanged(int index) {
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
				_getController(attachment).loadFullAttachment();
				if (index > 0 ) {
					_getController(widget.attachments[index - 1]).preloadFullAttachment();
				}
				if (index < (widget.attachments.length - 1)) {
					_getController(widget.attachments[index + 1]).preloadFullAttachment();
				}
			}
			if (settings.autoRotateInGallery && _rotationAppropriate(attachment) && _getController(attachment).quarterTurns == 0) {
				_getController(attachment).rotate();
			}
			for (final c in _controllers.entries) {
				c.value.isPrimary = c.key == currentAttachment;
			}
		}
		_hideRotateButton = false;
		setState(() {});
	}

	bool canShare(Attachment attachment) {
		return (widget.overrideSources[attachment] ?? _getController(attachment).cachedFile) != null;
	}

	Future<void> share(Attachment attachment) async {
		final systemTempDirectory = Persistence.temporaryDirectory;
		final shareDirectory = await (Directory(systemTempDirectory.path + '/sharecache')).create(recursive: true);
		final newFilename = currentAttachment.id.toString() + currentAttachment.ext.replaceFirst('webm', 'mp4');
		File? originalFile = _getController(attachment).cachedFile;
		if (widget.overrideSources[attachment] != null) {
			originalFile = File(widget.overrideSources[attachment]!.path);
		}
		final renamedFile = await originalFile!.copy(shareDirectory.path.toString() + '/' + newFilename);
		final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
		final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
		await Share.shareFiles([renamedFile.path], subject: currentAttachment.filename, sharePositionOrigin: (offset != null && size != null) ? offset & size : null);
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
		return ClipRect(
			child: BackdropFilter(
				filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
				child: Container(
					color: Colors.black38,
					child: AnimatedBuilder(
						animation: pageController,
						builder: (context, child) => CustomScrollView(
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
										childCount: widget.attachments.length
									)
								)
							]
						)
					)
				)
			)
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
				return Colors.black.withOpacity((1 - factor.clamp(0, 1)));
			},
			slideEndHandler: (offset, {ScaleEndDetails? details, ExtendedImageSlidePageState? state}) {
				return widget.allowScroll && ((details?.velocity ?? Velocity.zero) != Velocity.zero);
			},
			child: CupertinoTheme(
				data: const CupertinoThemeData(brightness: Brightness.dark, primaryColor: Colors.white),
				child: CupertinoPageScaffold(
					backgroundColor: Colors.transparent,
					navigationBar: showChrome ? CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: AutoSizeText("${currentAttachment.filename} (${currentAttachment.width}x${currentAttachment.height})"),
						backgroundColor: Colors.black38,
						trailing: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								AnimatedBuilder(
									animation: context.watch<Persistence>().savedAttachmentsNotifier,
									builder: (context, child) {
										final currentlySaved = context.watch<Persistence>().getSavedAttachment(currentAttachment) != null;
										return CupertinoButton(
											padding: EdgeInsets.zero,
											child: Icon(currentlySaved ? Icons.bookmark : Icons.bookmark_outline),
											onPressed: canShare(currentAttachment) ? () {
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
									child: const Icon(Icons.ios_share),
									onPressed: canShare(currentAttachment) ? () => share(currentAttachment) : null
								)
							]
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
															return GestureDetector(
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
																	attachment: attachment,
																	semanticParentIds: widget.semanticParentIds
																),
																onTap: _getController(attachment).isFullResolution ? _toggleChrome : () {
																	_getController(attachment).loadFullAttachment();
																}
															);
														}
													)
												),
												AnimatedSwitcher(
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
																	child: const Icon(Icons.rotate_90_degrees_ccw)
																),
																onPressed: () {
																	if (currentController.quarterTurns == 1) {
																		currentController.unrotate();
																	}
																	else {
																		_rotate(currentAttachment);
																	}
																	setState(() {});
																}
															)
														)
													) : Container()
												),
												AnimatedBuilder(
													animation: pageController,
													builder: (context, child) => (pageController.positions.length != 1 ) ? Container() : AnimatedBuilder(
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
																child: Text("${currentIndex + 1} / ${widget.attachments.length}")
															)
														),
														builder: (context, child) => AnimatedSwitcher(
															duration: const Duration(milliseconds: 300),
															child: _shouldShowPosition.value ? child : Container()
														)
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
															initialChildSize: 0.15,
															maxChildSize: 1 - ((kMinInteractiveDimensionCupertino + MediaQuery.of(context).viewPadding.top) / MediaQuery.of(context).size.height),
															minChildSize: 0.15,
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