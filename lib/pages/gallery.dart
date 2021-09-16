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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_indicator/home_indicator.dart';

const double _THUMBNAIL_SIZE = 60;

enum _GalleryMenuSelection {
	ToggleAutorotate
}

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

	GalleryPage({
		required this.attachments,
		this.overrideSources = const {},
		required this.initialAttachment,
		required this.semanticParentIds,
		this.initiallyShowChrome = false,
		this.onChange,
		this.allowScroll = true
	});

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> with TickerProviderStateMixin {
	late int currentIndex;
	Attachment get currentAttachment => widget.attachments[currentIndex];
	AttachmentViewerController get currentController => _getController(currentAttachment);
	bool firstControllerMade = false;
	late final ScrollController thumbnailScrollController;
	late final PageController pageController;
	late bool showChrome;
	bool showingOverlays = true;
	final Key _pageControllerKey = GlobalKey();
	final Key _thumbnailsKey = GlobalKey();
	final BehaviorSubject<Null> _scrollCoalescer = BehaviorSubject();
	double? _lastpageControllerPixels;
	bool _animatingNow = false;
	final _shareButtonKey = GlobalKey();
	final _slideStream = BehaviorSubject<void>();
	bool _hideRotateButton = false;
	final _rotationsInProgress = Set<Attachment>();
	late final AnimationController _rotateButtonAnimationController;
	final Map<Attachment, AttachmentViewerController> _controllers = {};

	@override
	void initState() {
		super.initState();
		_rotateButtonAnimationController = AnimationController(duration: Duration(milliseconds: 5000), vsync: this, upperBound: pi * 2);
		showChrome = widget.initiallyShowChrome;
		_updateOverlays(showChrome);
		currentIndex = (widget.initialAttachment != null) ? widget.attachments.indexOf(widget.initialAttachment!) : 0;
		pageController = PageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_onPageControllerUpdate);
		_scrollCoalescer.bufferTime(Duration(milliseconds: 10)).listen((_) => __onPageControllerUpdate());
		_getController(widget.attachments[currentIndex]).loadFullAttachment();
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (!firstControllerMade) {
			final initialOffset = ((_THUMBNAIL_SIZE + 12) * (currentIndex + 0.5)) - (MediaQuery.of(context).size.width / 2);
			final maxOffset = ((_THUMBNAIL_SIZE + 12) * widget.attachments.length) - MediaQuery.of(context).size.width;
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

			}
			await showStatusBar();
			showingOverlays = true;
		}
		else if (!show && showingOverlays) {
			try {
				await HomeIndicator.hide();
			}
			on MissingPluginException {

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
			final idealLocation = (thumbnailScrollController.position.maxScrollExtent + thumbnailScrollController.position.viewportDimension - _THUMBNAIL_SIZE - 12) * factor - (thumbnailScrollController.position.viewportDimension / 2) + (_THUMBNAIL_SIZE / 2 + 6);
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
		}
		else {
			_animatingNow = true;
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
		if (_rotationsInProgress.contains(index)) {
			_rotateButtonAnimationController.repeat();
		}
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
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
		currentIndex = index;
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

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
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
				data: CupertinoThemeData(brightness: Brightness.dark, primaryColor: Colors.white),
				child: CupertinoPageScaffold(
					backgroundColor: Colors.transparent,
					navigationBar: showChrome ? CupertinoNavigationBar(
						transitionBetweenRoutes: false,
						middle: AutoSizeText(currentAttachment.filename),
						backgroundColor: Colors.black38,
						trailing: Row(
							mainAxisSize: MainAxisSize.min,
							children: [
								ValueListenableBuilder(
									valueListenable: Persistence.savedAttachmentBox.listenable(keys: [currentAttachment.globalId]),
									builder: (context, box, child) {
										final currentlySaved = Persistence.getSavedAttachment(currentAttachment) != null;
										return CupertinoButton(
											padding: EdgeInsets.zero,
											child: Icon(currentlySaved ? Icons.bookmark : Icons.bookmark_outline),
											onPressed: canShare(currentAttachment) ? () {
												if (currentlySaved) {
													Persistence.getSavedAttachment(currentAttachment)?.delete();
												}
												else {
													Persistence.saveAttachment(currentAttachment, currentController.cachedFile!);
												}
											} : null
										);
									}
								),
								CupertinoButton(
									key: _shareButtonKey,
									padding: EdgeInsets.zero,
									child: Icon(Icons.ios_share),
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
											}
										),
										GalleryRightIntent: CallbackAction<GalleryRightIntent>(
											onInvoke: (i) {
												if (currentIndex < widget.attachments.length - 1) {
													_animateToPage(currentIndex + 1, milliseconds: 0);
												}
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
														canMovePage: (x) => widget.allowScroll,
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
															turns: _rotationsInProgress.contains(currentAttachment) ? Tween(begin: 0.0, end: 1.0).animate(_rotateButtonAnimationController) : AlwaysStoppedAnimation(0.0),
															child: CupertinoButton(
																padding: EdgeInsets.all(24),
																child: Transform(
																	alignment: Alignment.center,
																	transform: _rotationsInProgress.contains(currentAttachment) || currentController.quarterTurns == 0 ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
																	child: Icon(Icons.rotate_90_degrees_ccw)
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
												Visibility(
													visible: showChrome,
													maintainState: true,
													maintainSize: true,
													maintainAnimation: true,
													child: Align(
														alignment: Alignment.bottomCenter,
														child: SafeArea(
															top: false,
															child: ClipRect(
																child: BackdropFilter(
																	filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
																	child: Column(
																		mainAxisSize: MainAxisSize.min,
																		crossAxisAlignment: CrossAxisAlignment.center,
																		children: [
																			if (currentController.videoPlayerController != null) Container(
																				decoration: BoxDecoration(
																					color: Colors.black38
																				),
																				child: VideoControls(
																					controller: currentController.videoPlayerController!,
																					hasAudio: currentController.hasAudio
																				)
																			),
																			Container(
																				decoration: BoxDecoration(
																					color: Colors.black38
																				),
																				height: _THUMBNAIL_SIZE + 8,
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
																										borderRadius: BorderRadius.all(Radius.circular(4)),
																										border: Border.all(color: attachment == currentAttachment ? Colors.blue : Colors.transparent, width: 2)
																									),
																									margin: const EdgeInsets.all(4),
																									child: AttachmentThumbnail(
																										attachment: widget.attachments[index],
																										width: _THUMBNAIL_SIZE,
																										height: _THUMBNAIL_SIZE
																									)
																								)
																							);
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

	}
	await showStatusBar();
	return lastSelected;
}