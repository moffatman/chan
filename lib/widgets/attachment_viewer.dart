import 'dart:async';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/rotating_image_provider.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/rx_stream_builder.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

class AttachmentNotFoundException {
	final Attachment attachment;
	AttachmentNotFoundException(this.attachment);
	@override
	String toString() => 'Attachment not found: $attachment';
}

class AttachmentViewerController extends ChangeNotifier {
	// Parameters
	final Attachment attachment;
	final Stream<void> redrawGestureStream;
	final ImageboardSite site;
	final Uri? overrideSource;

	// Private usage
	Completer<void>? _rotationCompleter;
	bool _isFullResolution = false;
	String? _errorMessage;
	VideoPlayerController? _videoPlayerController;
	bool _hasAudio = false;
	Uri? _goodImageSource;
	File? _cachedFile;
	bool _isPrimary = false;
	MediaConversion? _ongoingConversion;
	int _quarterTurns = 0;
	bool _checkArchives = false;
	bool _showLoadingProgress = false;
	final _longPressFactorStream = BehaviorSubject<double>();
	int _millisecondsBeforeLongPress = 0;
	bool _currentlyWithinLongPress = false;
	bool _playingBeforeLongPress = false;
	bool _seeking = false;
	String? _overlayText;

	// Public API
	/// Whether loading of the full quality attachment has begun
	bool get isFullResolution => _isFullResolution;
	/// Error that occured while loading the full quality attachment
	String? get errorMessage => _errorMessage;
	/// Whether the loading spinner should be displayed
	bool get showLoadingProgress => _showLoadingProgress;
	/// Conversion process of a video attachment
	final videoLoadingProgress = ValueNotifier<double?>(null);
	/// A VideoPlayerController to enable playing back video attachments
	VideoPlayerController? get videoPlayerController => _videoPlayerController;
	/// Whether the attachment is a video that has an audio track
	bool get hasAudio => _hasAudio;
	/// The Uri to use to load the image, if needed
	Uri? get goodImageSource => _goodImageSource;
	/// The file which contains the local cache of this attachment
	File? get cachedFile => _cachedFile;
	/// Whether the attachment has been cached locally
	bool get cacheCompleted => cachedFile != null;
	/// Whether this attachment is currently the primary one being displayed to the user
	bool get isPrimary => _isPrimary;
	/// How many turns to rotate the image by
	int get quarterTurns => _quarterTurns;
	/// A key to use to with ExtendedImage (to help maintain gestures when the image widget is replaced)
	final gestureKey = GlobalKey<ExtendedImageGestureState>();
	/// Whether archive checking for this attachment is enabled
	bool get checkArchives => _checkArchives;
	/// Modal text which should be overlayed on the attachment
	String? get overlayText => _overlayText;


	AttachmentViewerController({
		required this.attachment,
		required this.redrawGestureStream,
		required this.site,
		this.overrideSource,
		bool isPrimary = false
	}) : _isPrimary = isPrimary {
		_longPressFactorStream.bufferTime(Duration(milliseconds: 50)).listen((x) {
			if (x.isNotEmpty) {
				_onCoalescedLongPressUpdate(x.last);
			}
		});
	}

	set isPrimary(bool val) {
		if (val) {
			videoPlayerController?.play();
		}
		else {
			videoPlayerController?.pause();
		}
		_isPrimary = val;
	}

	Future<Uri> _getGoodSource(Attachment attachment) async {
		if (overrideSource != null) {
			return overrideSource!;
		}
		Response result = await site.client.head(attachment.url.toString(), options: Options(
			validateStatus: (_) => true
		));
		if (result.statusCode == 200) {
			return attachment.url;
		}
		else {
			if (_checkArchives && attachment.threadId != null) {
				final archivedThread = await site.getThreadFromArchive(ThreadIdentifier(
					board: attachment.board,
					id: attachment.threadId!
				));
				for (final reply in archivedThread.posts) {
					if (reply.attachment?.id == attachment.id) {
						result = await site.client.head(reply.attachment!.url.toString(), options: Options(
							validateStatus: (_) => true
						));
						if (result.statusCode == 200) {
							return reply.attachment!.url;
						}
					}
				}
			}
		}
		if (result.statusCode == 404) {
			throw AttachmentNotFoundException(attachment);
		}
		throw HTTPStatusException(result.statusCode!);
	}

	Future<void> _loadFullAttachment(bool startImageDownload) async {
		if (attachment.type == AttachmentType.Image && goodImageSource != null) {
			return;
		}
		if (attachment.type == AttachmentType.WEBM && videoPlayerController != null) {
			return;
		}
		_errorMessage = null;
		videoLoadingProgress.value = null;
		_goodImageSource = null;
		_videoPlayerController?.dispose();
		_videoPlayerController = null;
		_cachedFile = null;
		_isFullResolution = true;
		_showLoadingProgress = false;
		notifyListeners();
		Future.delayed(Duration(milliseconds: 300), () {
			_showLoadingProgress = true;
			notifyListeners();
		});
		try {
			if (attachment.type == AttachmentType.Image) {
				_goodImageSource = await _getGoodSource(attachment);
				if (_goodImageSource?.scheme == 'file') {
					_cachedFile = File(_goodImageSource!.path);
				}
				notifyListeners();
				if (startImageDownload) {
					await ExtendedNetworkImageProvider(
						goodImageSource.toString(),
						cache: true
					).getNetworkImageData();
					final file = await getCachedImageFile(goodImageSource.toString());
					if (file != null && _cachedFile?.path != file.path) {
						_cachedFile = file;
					}
				}
			}
			else if (attachment.type == AttachmentType.WEBM) {
				final url = await _getGoodSource(attachment);
				_ongoingConversion = MediaConversion.toMp4(url);
				_ongoingConversion!.progress.addListener(() {
					videoLoadingProgress.value = _ongoingConversion!.progress.value;
					notifyListeners();
				});
				_ongoingConversion!.start();
				final result = await _ongoingConversion!.result;
				_videoPlayerController = VideoPlayerController.file(result.file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
				await _videoPlayerController!.initialize();
				await _videoPlayerController!.setLooping(true);
				if (isPrimary) {
					await _videoPlayerController!.play();
				}
				_cachedFile = result.file;
				_hasAudio = result.hasAudio;
			}
			notifyListeners();
		}
		catch (e, st) {
			_errorMessage = e.toString();
			print(st);
			notifyListeners();
		}
		finally {
			_ongoingConversion = null;
		}
	}

	Future<void> loadFullAttachment() => _loadFullAttachment(false);

	void preloadFullAttachment() => _loadFullAttachment(true);

	Future<void> rotate() async {
		_quarterTurns = 1;
		notifyListeners();
		if (attachment.type == AttachmentType.Image) {
			_rotationCompleter ??= Completer<void>();
			await _rotationCompleter!.future;
		}
	}

	void unrotate() {
		_quarterTurns = 0;
		notifyListeners();
	}

	void onRotationCompleted() {
		_rotationCompleter?.complete();
	}

	void onCacheCompleted(File file) {
		_cachedFile = file;
		notifyListeners();
	}

	void tryArchives() {
		_checkArchives = true;
		loadFullAttachment();
	}

	String _formatPosition(Duration position, Duration duration) {
		return '${position.inMinutes.toString()}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / ${duration.inMinutes.toString()}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
	}

	void _onLongPressStart() {
		_playingBeforeLongPress = videoPlayerController!.value.isPlaying;
		_millisecondsBeforeLongPress = videoPlayerController!.value.position.inMilliseconds;
		_currentlyWithinLongPress = true;
		_overlayText = _formatPosition(videoPlayerController!.value.position, videoPlayerController!.value.duration);
		notifyListeners();
		videoPlayerController!.pause();
	}

	void _onLongPressUpdate(double factor) {
		_longPressFactorStream.add(factor);
	}

	void _onCoalescedLongPressUpdate(double factor) async {
		if (_currentlyWithinLongPress) {
			final duration = videoPlayerController!.value.duration.inMilliseconds;
			final newPosition = Duration(milliseconds: ((_millisecondsBeforeLongPress + (duration * factor)) % duration).round());
			_overlayText = _formatPosition(newPosition, videoPlayerController!.value.duration);
			notifyListeners();
			if (!_seeking) {
				_seeking = true;
				await videoPlayerController!.seekTo(newPosition);
				await videoPlayerController!.play();
				await videoPlayerController!.pause();
				_seeking = false;
			}
		}
	}

	void _onLongPressEnd() {
		if (_playingBeforeLongPress) {
			videoPlayerController!.play();
		}
		_currentlyWithinLongPress = false;
		_overlayText = null;
		notifyListeners();
	}

	@override
	void dispose() {
		super.dispose();
		_ongoingConversion?.cancel();
		videoPlayerController?.dispose();
		_longPressFactorStream.close();
	}
}

class AttachmentViewer extends StatelessWidget {
	final Attachment attachment;
	final AttachmentViewerController controller;
	final Iterable<int> semanticParentIds;
	final ValueChanged<double>? onScaleChanged;

	AttachmentViewer({
		required this.attachment,
		required this.controller,
		required this.semanticParentIds,
		this.onScaleChanged,
		Key? key
	}) : super(key: key);

	Object get _tag => AttachmentSemanticLocation(
		attachment: attachment,
		semanticParents: semanticParentIds
	);

	Widget _centeredLoader({
		required bool active,
		required double? value
	}) => Builder(
		builder: (context) => Center(
			child: AnimatedSwitcher(
				duration: const Duration(milliseconds: 300),
				child: active ? CircularLoadingIndicator(
					value: value
				) : Icon(
					Icons.download_for_offline,
					size: 60,
					color: CupertinoTheme.of(context).primaryColor
				)
			)
		)
	);

	Widget _buildImage(context, bool passedFirstBuild) {
		Uri url = attachment.thumbnailUrl;
		if (controller.goodImageSource != null && passedFirstBuild) {
			url = controller.goodImageSource!;
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			url.toString(),
			cache: true
		);
		if (url.scheme == 'file') {
			image = ExtendedFileImageProvider(
				File(url.path),
				imageCacheName: 'asdf'
			);
		}
		if (controller.quarterTurns != 0) {
			image = RotatingImageProvider(
				parent: image,
				quarterTurns: controller.quarterTurns,
				onLoaded: controller.onRotationCompleted
			);
		}
		return ExtendedImage(
			image: image,
			extendedImageGestureKey: controller.gestureKey,
			color: const Color.fromRGBO(238, 242, 255, 1),
			colorBlendMode: BlendMode.dstOver,
			enableSlideOutPage: true,
			gaplessPlayback: true,
			fit: BoxFit.contain,
			mode: ExtendedImageMode.gesture,
			width: double.infinity,
			height: double.infinity,
			enableLoadState: true,
			handleLoadingProgress: true,
			onDoubleTap: (state) {
				final old = state.gestureDetails!;
				state.gestureDetails = GestureDetails(
					offset: state.pointerDownPosition!.scale(old.layoutRect!.width / MediaQuery.of(context).size.width, old.layoutRect!.height / MediaQuery.of(context).size.height) * -1,
					totalScale: (old.totalScale ?? 1) > 1 ? 1 : 2,
					actionType: ActionType.zoom
				);
			},
			loadStateChanged: (loadstate) {
				// We can't rely on loadstate.extendedImageLoadState because of using gaplessPlayback
				if (!controller.cacheCompleted) {
					double? loadingValue;
					if (loadstate.loadingProgress?.cumulativeBytesLoaded != null && loadstate.loadingProgress?.expectedTotalBytes != null) {
						// If we got image download completion, we can check if it's cached
						loadingValue = loadstate.loadingProgress!.cumulativeBytesLoaded / loadstate.loadingProgress!.expectedTotalBytes!;
						if ((url != attachment.thumbnailUrl) && loadingValue == 1) {
							getCachedImageFile(url.toString()).then((file) {
								if (file != null) {
									controller.onCacheCompleted(file);
								}
							});
						}
					}
					else if (loadstate.extendedImageInfo?.image.width == attachment.width) {
						// If the displayed image looks like the full image, we can check cache
						getCachedImageFile(url.toString()).then((file) {
							if (file != null) {
								controller.onCacheCompleted(file);
							}
						});
					}
					loadstate.returnLoadStateChangedWidget = true;
					return Stack(
						children: [
							loadstate.completedWidget,
							RxStreamBuilder(
								stream: controller.redrawGestureStream,
								builder: (context, _) {
									Widget _child = Container();
									if (controller.errorMessage != null) {
										_child = Center(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													IgnorePointer(
														child: ErrorMessageCard(controller.errorMessage!)
													),
													CupertinoButton(
														child: Text('Retry'),
														onPressed: controller.loadFullAttachment
													),
													if (!controller.checkArchives) CupertinoButton(
														child: Text('Try archives'),
														onPressed: controller.tryArchives
													)
												]
											)
										);
									}
									else if (controller.showLoadingProgress) {
										_child = _centeredLoader(
											active: controller.isFullResolution,
											value: loadingValue
										);
									}
									final Rect? rect = controller.gestureKey.currentState?.gestureDetails?.destinationRect?.shift(controller.gestureKey.currentState?.extendedImageSlidePageState?.offset ?? Offset.zero);
									final Widget __child = Transform.scale(
										scale: (controller.gestureKey.currentState?.extendedImageSlidePageState?.scale ?? 1) * (controller.gestureKey.currentState?.gestureDetails?.totalScale ?? 1),
										child: _child
									);
								  if (rect == null) {
										return Positioned.fill(
											child: __child
										);
									}
									else {
										return Positioned.fromRect(
											rect: rect,
											child: __child
										);
									}
								}
							)
						]
					);
				}
			},
			initGestureConfigHandler: (state) {
				return GestureConfig(
					inPageView: true,
					gestureDetailsIsChanged: (details) {
						if (details?.totalScale != null) {
							onScaleChanged?.call(details!.totalScale!);
						}
					}
				);
			},
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: _tag,
					child: result,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => from.widget
				);
			}
		);
	}

	Widget _buildVideo(context) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: _tag,
					child: result,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => from.widget
				);
			},
			child: Stack(
				children: [
					AttachmentThumbnail(
						attachment: attachment,
						width: double.infinity,
						height: double.infinity,
						quarterTurns: controller.quarterTurns,
						gaplessPlayback: true
					),
					if (controller.errorMessage != null) Center(
						child: ErrorMessageCard(controller.errorMessage!)
					)
					else if (controller.videoPlayerController != null) Center(
						child: RotatedBox(
							quarterTurns: controller.quarterTurns,
							child: AspectRatio(
								aspectRatio: controller.videoPlayerController!.value.aspectRatio,
								child: GestureDetector(
									child: VideoPlayer(controller.videoPlayerController!),
									onLongPressStart: (x) => controller._onLongPressStart(),
									onLongPressMoveUpdate: (x) => controller._onLongPressUpdate(x.offsetFromOrigin.dx / 400),
									onLongPressEnd: (x) => controller._onLongPressEnd()
								)
							)
						)
					)
					else if (controller.showLoadingProgress) ValueListenableBuilder(
						valueListenable: controller.videoLoadingProgress,
						builder: (context, double? loadingProgress, child) => _centeredLoader(
							active: controller.isFullResolution,
							value: loadingProgress
						)
					),
					AnimatedSwitcher(
						duration: const Duration(milliseconds: 250),
						child: (controller.overlayText != null) ? Center(
							child: RotatedBox(
								quarterTurns: controller.quarterTurns,
								child: Container(
									padding: EdgeInsets.all(8),
									decoration: BoxDecoration(
										color: Colors.black54,
										borderRadius: BorderRadius.all(Radius.circular(8))
									),
									child: Text(
										controller.overlayText!,
										style: TextStyle(
											fontSize: 32,
											color: Colors.white
										)
									)
								)
							)
						) : Container()
					)
				]
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return FirstBuildDetector(
			identifier: _tag,
			builder: (context, passedFirstBuild) {
				if (attachment.type == AttachmentType.Image) {
					return _buildImage(context, passedFirstBuild);
				}
				else {
					return _buildVideo(context);
				}
			}
		);
	}
}