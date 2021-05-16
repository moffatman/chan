import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/media.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/rx_stream_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:chan/widgets/attachment_viewer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart';
import 'package:video_player/video_player.dart';
import 'package:hive_flutter/hive_flutter.dart';


const double _THUMBNAIL_SIZE = 60;

class AttachmentStatus {

}

class AttachmentUnloadedStatus extends AttachmentStatus {
	
}

class AttachmentLoadingStatus extends AttachmentStatus {
	final double? progress;
	AttachmentLoadingStatus({this.progress});
}

class AttachmentUnavailableStatus extends AttachmentStatus {
	String cause;
	AttachmentUnavailableStatus(this.cause);
}

class AttachmentImageUrlAvailableStatus extends AttachmentStatus {
	final Uri url;
	AttachmentImageUrlAvailableStatus(this.url);
}

class AttachmentVideoAvailableStatus extends AttachmentStatus {
	final VideoPlayerController controller;
	final bool hasAudio;
	AttachmentVideoAvailableStatus(this.controller, this.hasAudio);
}

enum _GalleryMenuSelection {
	ToggleAutorotate
}

class GalleryPage extends StatefulWidget {
	final List<Attachment> attachments;
	final Map<Attachment, Uri> overrideSources;
	final Attachment? initialAttachment;
	final bool initiallyShowChrome;
	final ValueChanged<Attachment>? onChange;
	final Iterable<int> semanticParentIds;

	GalleryPage({
		required this.attachments,
		this.overrideSources = const {},
		required this.initialAttachment,
		required this.semanticParentIds,
		this.initiallyShowChrome = false,
		this.onChange,
	});

	@override
	createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
	// Data
	late int currentIndex;
	Attachment get currentAttachment => widget.attachments[currentIndex];
	AttachmentStatus get currentAttachmentStatus => statuses[currentAttachment]!.value!;
	final Map<Attachment, BehaviorSubject<AttachmentStatus>> statuses = Map();
	final Map<Attachment, File> cachedFiles = Map();
	// View
	bool firstControllerMade = false;
	late final ScrollController thumbnailScrollController;
	late final PageController pageController;
	final FocusNode keyboardShortcutFocusNode = FocusNode();
	late bool showChrome;
	final Key _pageControllerKey = GlobalKey();
	final Key _thumbnailsKey = GlobalKey();
	AttachmentStatus lastDifferentCurrentStatus = AttachmentStatus();
	final BehaviorSubject<Null> _scrollCoalescer = BehaviorSubject();
	double? _lastpageControllerPixels;

	@override
	void initState() {
		super.initState();
		showChrome = widget.initiallyShowChrome;
		currentIndex = (widget.initialAttachment != null) ? widget.attachments.indexOf(widget.initialAttachment!) : 0;
		pageController = PageController(keepPage: true, initialPage: currentIndex);
		pageController.addListener(_onPageControllerUpdate);
		_scrollCoalescer.bufferTime(Duration(milliseconds: 10)).listen((_) => __onPageControllerUpdate());
		statuses.addEntries(widget.attachments.map((attachment) => MapEntry(attachment, BehaviorSubject()..add(AttachmentUnloadedStatus()))));
		statuses.entries.forEach((entry) {
			entry.value.listen((newStatus) {
				// Don't need to rebuild layout if its just a status value change (mainly for loading spinner)
				if (currentAttachment == entry.key && newStatus.runtimeType != lastDifferentCurrentStatus.runtimeType) {
					setState(() {
						lastDifferentCurrentStatus = newStatus;
					});
				}
			});
		});
		if (context.read<EffectiveSettings>().autoloadAttachments) {
			requestRealViewer(widget.attachments[currentIndex]);
		}
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
		}
	}

	Future<Uri> _getGoodUrl(Attachment attachment) async {
		if (widget.overrideSources[attachment] != null) {
			return widget.overrideSources[attachment]!;
		}
		// Should check archives and send scaffold messages here
		final site = context.read<ImageboardSite>();
		final result = await site.client.head(attachment.url);
		if (result.statusCode == 200) {
			return attachment.url;
		}
		else {
			throw HTTPStatusException(result.statusCode);
		}
	}

	Future<void> requestRealViewer(Attachment attachment) async {
		try {
			if (attachment.type == AttachmentType.Image) {
				final provisionalStatus = AttachmentLoadingStatus(progress: 0);
				statuses[attachment]!.add(provisionalStatus);
				Future.delayed(const Duration(milliseconds: 500), () {
					if (statuses[attachment]!.value == provisionalStatus && mounted) {
						statuses[attachment]!.add(AttachmentLoadingStatus());
					}
				});
				final url = await _getGoodUrl(attachment);
				statuses[attachment]!.add(AttachmentImageUrlAvailableStatus(url));
			}
			else if (attachment.type == AttachmentType.WEBM) {
				statuses[attachment]!.add(AttachmentLoadingStatus());
				final url = await _getGoodUrl(attachment);
				final webm = MediaConversion.toMp4(url);
				webm.progress.addListener(() {
					statuses[attachment]!.add(AttachmentLoadingStatus(progress: webm.progress.value));
				});
				webm.start();
				try {
					final result = await webm.result;
					final controller = VideoPlayerController.file(result.file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
					await controller.initialize();
					await controller.setLooping(true);
					await controller.play();
					cachedFiles[attachment] = result.file;
					statuses[attachment]!.add(AttachmentVideoAvailableStatus(controller, result.hasAudio));
				}
				catch (e) {
					statuses[attachment]!.add(AttachmentUnavailableStatus(e.toString()));
				}
			}
		}
		catch (e) {
			statuses[attachment]!.add(AttachmentUnavailableStatus(e.toString()));
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

	void _animateToPage(int index, {int milliseconds = 200}) {
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		if (context.read<EffectiveSettings>().autoloadAttachments && statuses[attachment]!.value is AttachmentUnloadedStatus) {
			requestRealViewer(widget.attachments[index]);
		}
		setState(() {
			if (milliseconds == 0) {
				pageController.jumpToPage(index);
			}
			else {
				pageController.animateToPage(
					index,
					duration: Duration(milliseconds: milliseconds),
					curve: Curves.ease
				);
			}
		});
	}

	void _onPageChanged(int index) {
		final attachment = widget.attachments[index];
		widget.onChange?.call(attachment);
		if (context.read<EffectiveSettings>().autoloadAttachments && statuses[attachment]!.value is AttachmentUnloadedStatus) {
			requestRealViewer(widget.attachments[index]);
		}
		currentIndex = index;
		for (final status in statuses.entries) {
			if (status.value.value is AttachmentVideoAvailableStatus) {
				if (status.key == currentAttachment) {
					(status.value.value! as AttachmentVideoAvailableStatus).controller.play();
				}
				else {
					(status.value.value! as AttachmentVideoAvailableStatus).controller.pause();
				}
			}
		}
		setState(() {});
	}

	bool canShare(Attachment attachment) {
		return (widget.overrideSources[attachment] ?? cachedFiles[attachment]) != null;
	}

	Future<void> share(Attachment attachment) async {
		final systemTempDirectory = Persistence.temporaryDirectory;
		final shareDirectory = await (Directory(systemTempDirectory.path + '/sharecache')).create(recursive: true);
		final newFilename = currentAttachment.id.toString() + currentAttachment.ext.replaceFirst('webm', 'mp4');
		File? originalFile = cachedFiles[currentAttachment];
		if (widget.overrideSources[attachment] != null) {
			originalFile = File(widget.overrideSources[attachment]!.path);
		}
		final renamedFile = await originalFile!.copy(shareDirectory.path.toString() + '/' + newFilename);
		await Share.shareFiles([renamedFile.path], subject: currentAttachment.filename);
	}

	void _toggleChrome() {
		setState(() {
			showChrome = !showChrome;
		});
	}

	double _dragPopFactor(Offset offset, Size size) {
		final threshold = math.sqrt(size.width * size.height) / 15;
		return (offset.distance - threshold) / threshold;
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		return ExtendedImageSlidePage(
			resetPageDuration: const Duration(milliseconds: 100),
			slidePageBackgroundHandler: (offset, size) {
				return Colors.black.withOpacity(0.38 * (1 - _dragPopFactor(offset, size).clamp(0, 1)));
			},
			slideEndHandler: (offset, {ScaleEndDetails? details, ExtendedImageSlidePageState? state}) {
				return _dragPopFactor(offset, state!.pageSize) > 1;
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
													Persistence.saveAttachment(currentAttachment, cachedFiles[currentAttachment]!);
												}
											} : null
										);
									}
								),
								CupertinoButton(
									padding: EdgeInsets.zero,
									child: Icon(Icons.ios_share),
									onPressed: canShare(currentAttachment) ? () => share(currentAttachment) : null
								),
								Material(
									type: MaterialType.transparency,
									color: Colors.transparent,
									child: PopupMenuButton<_GalleryMenuSelection>(
										onSelected: (selected) {
											if (selected == _GalleryMenuSelection.ToggleAutorotate) {
												settings.autoRotateInGallery = !settings.autoRotateInGallery;
											}
										},
										itemBuilder: (context) => [
											CheckedPopupMenuItem(
												checked: settings.autoRotateInGallery,
												value: _GalleryMenuSelection.ToggleAutorotate,
												child: Text('Autorotate')
											)
										]
									)
								)
							]
						)
					) : null,
					child: Container(
							height: double.infinity,
							color: Colors.transparent,
							child: RawKeyboardListener(
								autofocus: true,
								focusNode: keyboardShortcutFocusNode,
								onKey: (event) {
									if (event is RawKeyDownEvent) {
										if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
											if (currentIndex > 0) {
												_animateToPage(currentIndex - 1, milliseconds: 0);
											}
										}
										else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
											if (currentIndex < widget.attachments.length - 1) {
												_animateToPage(currentIndex + 1, milliseconds: 0);
											}
										}
										else if (event.logicalKey == LogicalKeyboardKey.keyG) {
											Navigator.of(context).pop();
										}
										else if (event.logicalKey == LogicalKeyboardKey.space) {
											_toggleChrome();
										}
									}
								},
								child: Stack(
									children: [
										KeyedSubtree(
											key: _pageControllerKey,
											child: ExtendedImageGesturePageView.builder(
												onPageChanged: _onPageChanged,
												controller: pageController,
												itemCount: widget.attachments.length,
												itemBuilder: (context, index) {
													final attachment = widget.attachments[index];
													return RxStreamBuilder<AttachmentStatus>(
														stream: statuses[attachment]!,
														builder: (context, snapshot) {
															final status = snapshot.data!;
															return GestureDetector(
																child: AttachmentViewer(
																	autoRotate: settings.autoRotateInGallery,
																	attachment: attachment,
																	status: status,
																	backgroundColor: Colors.transparent,
																	tag: AttachmentSemanticLocation(
																		attachment: attachment,
																		semanticParents: widget.semanticParentIds
																	),
																	onCacheCompleted: (file) {
																		if (cachedFiles[attachment]?.path != file.path) {
																			setState(() {
																				cachedFiles[attachment] = file;
																			});
																		}
																	}
																),
																onTap: (status is AttachmentUnloadedStatus) ? () {
																	if (status is AttachmentUnloadedStatus) {
																		requestRealViewer(attachment);
																	}
																} : _toggleChrome
															);
														}
													);
												}
											)
										),
										Visibility(
											visible: showChrome,
											maintainState: true,
											maintainSize: true,
											maintainAnimation: true,
											child: SafeArea(
												child: Column(
													mainAxisAlignment: MainAxisAlignment.end,
													crossAxisAlignment: CrossAxisAlignment.center,
													children: [
														if (currentAttachmentStatus is AttachmentVideoAvailableStatus) Container(
															decoration: BoxDecoration(
																color: Colors.black38
															),
															child: VideoControls(
																controller: (currentAttachmentStatus as AttachmentVideoAvailableStatus).controller,
																hasAudio: (currentAttachmentStatus as AttachmentVideoAvailableStatus).hasAudio
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
									]
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
		for (final status in statuses.values) {
			if (status.value is AttachmentVideoAvailableStatus) {
				(status.value as AttachmentVideoAvailableStatus).controller.dispose();
			}
			status.close();
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
}) {
	return Navigator.of(context, rootNavigator: true).push(TransparentRoute<Attachment>(
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
}