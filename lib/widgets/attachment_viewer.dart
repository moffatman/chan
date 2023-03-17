import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/soundposts.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/cooperative_browser.dart';
import 'package:chan/widgets/cupertino_context_menu2.dart';
import 'package:chan/widgets/double_tap_drag_detector.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';

final _domainLoadTimes = <String, List<Duration>>{};

void _recordUrlTime(Uri url, Duration loadTime) {
	_domainLoadTimes.putIfAbsent(url.host, () => []).add(loadTime);
}

const _minUrlTime = Duration(milliseconds: 500);

// If the Hero endRect doesn't match up with the hero destination widget origin,
// flutter will keep trying to recalculate it.
// It's a lazy fix, but works, if we just cache the first result.
final Map <String, (DateTime, Rect, Rect)> _heroRectCache = {};

Duration _estimateUrlTime(Uri url) {
	final times = _domainLoadTimes[url.host] ?? <Duration>[];
	final time = (times.fold(Duration.zero, (Duration a, b) => a + b) * 1.5) ~/ max(times.length, 1);
	if (time < _minUrlTime) {
		return _minUrlTime;
	}
	return time;
}

const deviceGalleryAlbumName = 'Chance';

class AttachmentNotFoundException implements Exception {
	final Attachment attachment;
	AttachmentNotFoundException(this.attachment);
	@override
	String toString() => 'Attachment not found';
}

class AttachmentNotArchivedException implements Exception {
	final Attachment attachment;
	AttachmentNotArchivedException(this.attachment);
	@override
	String toString() => 'Attachment not archived';
}

const _maxVp9Controllers = 3;
final List<AttachmentViewerController> _vp9Controllers = [];

class AttachmentViewerController extends ChangeNotifier {
	// Parameters
	final BuildContext context;
	final Attachment attachment;
	final Listenable? redrawGestureListenable;
	final ImageboardSite site;
	final Uri? overrideSource;
	final VoidCallback? onDownloaded;

	// Private usage
	bool _isFullResolution = false;
	String? _errorMessage;
	VideoPlayerController? _videoPlayerController;
	bool _hasAudio = false;
	Uri? _goodImageSource;
	File? _cachedFile;
	bool _isPrimary = false;
	StreamingMP4Conversion? _ongoingConversion;
	final _conversionDisposers = <VoidCallback>[];
	bool _rotate90DegreesClockwise = false;
	bool _checkArchives = false;
	bool _showLoadingProgress = false;
	final _longPressFactorStream = BehaviorSubject<double>();
	int _millisecondsBeforeLongPress = 0;
	bool _currentlyWithinLongPress = false;
	bool _playingBeforeLongPress = false;
	bool _seeking = false;
	String? _overlayText;
	bool _isDisposed = false;
	bool _isDownloaded;
	GestureDetails? _gestureDetailsOnDoubleTapDragStart;
	StreamSubscription<List<double>>? _longPressFactorSubscription;
	bool _loadingProgressHideScheduled = false;
	bool _audioOnlyShowScheduled = false;
	bool _showAudioOnly = false;
	bool? _useRandomUserAgent;
	Duration? _duration;
	File? _videoFileToSwapIn;
	ValueListenable<double?> _videoLoadingProgress = ValueNotifier(null);
	bool _swapIncoming = false;
	bool _waitingOnSwap = false;
	Duration? _swapStartTime;

	// Public API
	/// Whether loading of the full quality attachment has begun
	bool get isFullResolution => _isFullResolution;
	/// Error that occured while loading the full quality attachment
	String? get errorMessage => _errorMessage;
	/// Whether the loading spinner should be displayed
	bool get showLoadingProgress => _showLoadingProgress;
	/// Conversion process of a video attachment
	ValueListenable<double?> get videoLoadingProgress => _videoLoadingProgress;
	/// A VideoPlayerController to enable playing back video attachments
	VideoPlayerController? get videoPlayerController => _videoPlayerController;
	/// Whether the attachment is a video that has an audio track
	bool get hasAudio => _hasAudio;
	/// The Uri to use to load the image, if needed
	Uri? get goodImageSource => _goodImageSource;
	/// Whether the attachment has been cached locally
	bool get cacheCompleted => _cachedFile != null;
	/// Whether this attachment is currently the primary one being displayed to the user
	bool get isPrimary => _isPrimary;
	/// Whether to rotate the image 90 degrees clockwise
	bool get rotate90DegreesClockwise => _rotate90DegreesClockwise;
	/// A key to use to with ExtendedImage (to help maintain gestures when the image widget is replaced)
	final gestureKey = GlobalKey<ExtendedImageGestureState>();
	/// A key to use with CupertinoContextMenu share button
	final contextMenuShareButtonKey = GlobalKey();
	/// Whether archive checking for this attachment is enabled
	bool get checkArchives => _checkArchives;
	/// Modal text which should be overlayed on the attachment
	String? get overlayText => _overlayText;
	// Whether the modal text should be dimmed
	bool get dimOverlayText => _swapIncoming;
	/// Whether the image has already been downloaded
	bool get isDownloaded => _isDownloaded;
	/// Key to use for loading spinner
	final loadingSpinnerKey = GlobalKey();
	/// The duration of the video, if known
	Duration? get duration => _duration;
	/// Whether a seekable version of the video is incoming
	bool get swapIncoming => _swapIncoming;
	/// Whether a seekable version of the file is ready to swap in
	bool get swapAvailable => _videoFileToSwapIn != null;


	AttachmentViewerController({
		required this.context,
		required this.attachment,
		this.redrawGestureListenable,
		required this.site,
		this.overrideSource,
		Uri? initialGoodSource,
		this.onDownloaded,
		bool isPrimary = false,
		bool isDownloaded = false,
	}) : _isPrimary = isPrimary, _isDownloaded = isDownloaded {
		_longPressFactorSubscription = _longPressFactorStream.bufferTime(const Duration(milliseconds: 50)).listen((x) {
			if (x.isNotEmpty) {
				_onCoalescedLongPressUpdate(x.last);
			}
		});
		// optimistic
		_goodImageSource = initialGoodSource;
		_isFullResolution = initialGoodSource != null;
		if (attachment.type == AttachmentType.image) {
			getCachedImageFile(attachment.url.toString()).then((file) {
				if (file != null && _cachedFile == null) {
					_cachedFile = file;
					_goodImageSource = attachment.url;
					_isFullResolution = true;
					notifyListeners();
				}
			});
		}
	}

	set isPrimary(bool val) {
		if (val) {
			videoPlayerController?.play();
		}
		else {
			videoPlayerController?.pause();
		}
		_isPrimary = val;
		notifyListeners();
	}

	Map<String, String> _getHeaders(Uri url) {
		return {
			...site.getHeaders(url) ?? {},
			if (_useRandomUserAgent ?? attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
		};
	}

	Future<Uri> _getGoodSource() async {
		if (overrideSource != null) {
			return overrideSource!;
		}
		Response result = await site.client.headUri(attachment.url, options: Options(
			validateStatus: (_) => true,
			headers: _getHeaders(attachment.url)
		));
		if (result.statusCode == 200) {
			return attachment.url;
		}
		// handle issue with timestamps in url
		bool corrected = false;
		final correctedUrl = attachment.url.toString().replaceAllMapped(RegExp(r'^(.*\/\d+)\d{3}(.*)$'), (match) {
			corrected = true;
			return '${match.group(1)}${match.group(2)}';
		});
		if (corrected) {
			result = await site.client.head(correctedUrl, options: Options(
				validateStatus: (_) => true,
				headers: _getHeaders(Uri.parse(correctedUrl))
			));
			if (result.statusCode == 200) {
				return Uri.parse(correctedUrl);
			}
		}
		if (_checkArchives && attachment.threadId != null) {
			final archivedThread = await site.getThreadFromArchive(ThreadIdentifier(
				attachment.board,
				attachment.threadId!
			), validate: (thread) async {
				final newAttachment = thread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.id == attachment.id);
				if (newAttachment == null) {
					throw AttachmentNotFoundException(attachment);
				}
				_useRandomUserAgent = newAttachment.useRandomUseragent;
				final check = await site.client.head(newAttachment.url.toString(), options: Options(
					validateStatus: (_) => true,
					headers: _getHeaders(newAttachment.url)
				));
				if (check.statusCode != 200) {
					throw AttachmentNotArchivedException(attachment);
				}
			});
			final goodAttachment = archivedThread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.id == attachment.id)!;
			_useRandomUserAgent = goodAttachment.useRandomUseragent;
			return goodAttachment.url;
		}
		else {
			_useRandomUserAgent = null;
		}
		if (result.statusCode == 404) {
			throw AttachmentNotFoundException(attachment);
		}
		throw HTTPStatusException(result.statusCode!);
	}

	void _scheduleHidingOfLoadingProgress() async {
		if (_loadingProgressHideScheduled) return;
		_loadingProgressHideScheduled = true;
		await Future.delayed(const Duration(milliseconds: 500));
		if (_isDisposed) return;
		_showLoadingProgress = false;
		_loadingProgressHideScheduled = false;
		notifyListeners();
	}

	void _scheduleShowingOfAudioOnly() async {
		if (_audioOnlyShowScheduled) return;
		_audioOnlyShowScheduled = true;
		await Future.delayed(const Duration(milliseconds: 100));
		if (_isDisposed) return;
		_showAudioOnly = true;
		notifyListeners();
	}

	void goToThumbnail() {
		_isFullResolution = false;
		_showLoadingProgress = false;
		_showAudioOnly = false;
		_videoPlayerController?.dispose();
		_videoPlayerController = null;
		_goodImageSource = null;
		_longPressFactorSubscription?.cancel();
		_longPressFactorStream.close();
		notifyListeners();
	}

	Future<void> _loadFullAttachment(bool background, {bool force = false}) async {
		if (attachment.type == AttachmentType.image && goodImageSource != null && !force) {
			return;
		}
		if (attachment.type.isVideo && ((videoPlayerController != null && !force) || _ongoingConversion != null)) {
			return;
		}
		final settings = context.read<EffectiveSettings>();
		_errorMessage = null;
		_goodImageSource = null;
		_videoPlayerController?.dispose();
		_videoPlayerController = null;
		_cachedFile = null;
		_isFullResolution = true;
		_showLoadingProgress = false;
		_showAudioOnly = false;
		notifyListeners();
		final startTime = DateTime.now();
		Future.delayed(_estimateUrlTime(attachment.thumbnailUrl), () {
			if (_loadingProgressHideScheduled) return;
			_showLoadingProgress = true;
			if (_isDisposed) return;
			notifyListeners();
		});
		try {
			final soundSource = attachment.soundSource;
			if (soundSource == null && (attachment.type == AttachmentType.image || attachment.type == AttachmentType.pdf)) {
				_goodImageSource = await _getGoodSource();
				_recordUrlTime(_goodImageSource!, DateTime.now().difference(startTime));
				if (_goodImageSource?.scheme == 'file') {
					_cachedFile = File(_goodImageSource!.path);
				}
				if (_isDisposed) return;
				notifyListeners();
				if (background && attachment.type == AttachmentType.image) {
					await ExtendedNetworkImageProvider(
						goodImageSource.toString(),
						cache: true,
						headers: _getHeaders(goodImageSource!)
					).getNetworkImageData();
					final file = await getCachedImageFile(goodImageSource.toString());
					if (file != null && _cachedFile?.path != file.path) {
						_cachedFile = file;
					}
				}
			}
			else if (soundSource != null || attachment.type == AttachmentType.webm || attachment.type == AttachmentType.mp4 || attachment.type == AttachmentType.mp3) {
				final url = await _getGoodSource();
				_recordUrlTime(url, DateTime.now().difference(startTime));
				bool transcode = false;
				if (attachment.type == AttachmentType.webm) {
					transcode = settings.webmTranscoding == WebmTranscodingSetting.always;
				}
				transcode |= soundSource != null;
				if (!transcode) {
					final scan = await MediaScan.scan(url, headers: _getHeaders(url));
					if (_isDisposed) {
						return;
					}
					_hasAudio = scan.hasAudio;
					if (scan.codec == 'vp9') {
						if (settings.webmTranscoding == WebmTranscodingSetting.vp9) {
							transcode = true;
						}
						else {
							_vp9Controllers.add(this);
							if (_vp9Controllers.length > _maxVp9Controllers) {
								_vp9Controllers.removeAt(0).goToThumbnail();
							}
						}
					}
				}
				bool isAudioOnly = false;
				if (!transcode) {
					_videoPlayerController = VideoPlayerController.network(
						url.toString(),
						httpHeaders: _getHeaders(url),
						videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
					);
				}
				else {
					_ongoingConversion = StreamingMP4Conversion(url, headers: _getHeaders(url), soundSource: soundSource);
					final result = await _ongoingConversion!.start();
					_conversionDisposers.add(_ongoingConversion!.dispose);
					_ongoingConversion = null;
					if (result is StreamingMP4ConvertedFile) {
						if (!background) {
							_videoPlayerController = VideoPlayerController.file(result.mp4File, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
						}
						_cachedFile = result.mp4File;
						isAudioOnly = result.isAudioOnly;
					}
					else if (result is StreamingMP4ConversionStream) {
						_duration = result.duration;
						if (!background) {
							_videoPlayerController = VideoPlayerController.network(result.hlsStream.toString(), formatHint: VideoFormat.hls, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
						}
						_videoLoadingProgress = result.progress;
						isAudioOnly = result.isAudioOnly;
						_swapIncoming = true;
						result.mp4File.then((mp4File) async {
							_cachedFile = mp4File;
							_videoFileToSwapIn = mp4File;
							if (_waitingOnSwap && !background) {
								await potentiallySwapVideo();
							}
							_videoLoadingProgress = ValueNotifier(null);
							_swapIncoming = false;
							notifyListeners();
						});
						_hasAudio = result.hasAudio;
					}
				}
				if (_isDisposed) return;
				if (_videoPlayerController != null) {
					await _videoPlayerController!.initialize();
					if (_isDisposed) return;
					if (settings.muteAudio.value || settings.alwaysStartVideosMuted) {
						if (!settings.muteAudio.value) {
							settings.setMuteAudio(true);
						}
						await _videoPlayerController?.setVolume(0);
						if (_isDisposed) return;
					}
					await _videoPlayerController!.setLooping(true);
					if (_isDisposed) return;
					if (isPrimary) {
						await _videoPlayerController!.seekTo(Duration.zero);
						await _videoPlayerController!.play();
					}
					if (_isDisposed) return;
					_scheduleHidingOfLoadingProgress();
					if (isAudioOnly) {
						_scheduleShowingOfAudioOnly();
					}
				}
				notifyListeners();
			}
		}
		catch (e, st) {
			_errorMessage = e.toStringDio();
			print(e);
			print(st);
			if (_isDisposed) return;
			_scheduleHidingOfLoadingProgress();
			notifyListeners();
		}
		finally {
			_ongoingConversion = null;
		}
	}

	Future<void> loadFullAttachment() => _loadFullAttachment(false);

	Future<void> reloadFullAttachment() => _loadFullAttachment(false, force: true);

	Future<void> preloadFullAttachment() => _loadFullAttachment(true);

	void rotate() {
		_rotate90DegreesClockwise = true;
		notifyListeners();
	}

	void unrotate() {
		_rotate90DegreesClockwise = false;
		notifyListeners();
	}

	void onCacheCompleted(File file) {
		_cachedFile = file;
		if (_isDisposed) return;
		_scheduleHidingOfLoadingProgress();
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
		if (videoPlayerController == null) {
			 return;
		}
		mediumHapticFeedback();
		_playingBeforeLongPress = videoPlayerController!.value.isPlaying;
		_millisecondsBeforeLongPress = videoPlayerController!.value.position.inMilliseconds;
		_currentlyWithinLongPress = true;
		_overlayText = _formatPosition(videoPlayerController!.value.position, duration ?? videoPlayerController!.value.duration);
		_waitingOnSwap = _swapIncoming;
		notifyListeners();
		videoPlayerController!.pause();
		potentiallySwapVideo();
	}

	void _onLongPressUpdate(double factor) {
		_longPressFactorStream.add(factor);
	}

	void _onCoalescedLongPressUpdate(double factor) async {
		if (_currentlyWithinLongPress) {
			final duration = (this.duration ?? videoPlayerController!.value.duration).inMilliseconds;
			final newPosition = Duration(milliseconds: ((_millisecondsBeforeLongPress + (duration * factor)).clamp(0, duration)).round());
			_overlayText = _formatPosition(newPosition, this.duration ?? videoPlayerController!.value.duration);
			notifyListeners();
			if (_waitingOnSwap) {
				_swapStartTime = newPosition;
			}
			else if (!_seeking) {
				_seeking = true;
				await videoPlayerController!.seekTo(newPosition);
				await videoPlayerController!.play();
				await videoPlayerController!.pause();
				_seeking = false;
			}
		}
	}

	Future<void> _onLongPressEnd() async {
		await potentiallySwapVideo();
		if (_playingBeforeLongPress) {
			videoPlayerController!.play();
		}
		_currentlyWithinLongPress = false;
		_overlayText = null;
		_waitingOnSwap = false;
		notifyListeners();
	}

	bool get _playsDirectlyWithoutCaching =>
		(attachment.type == AttachmentType.webm && Platform.isAndroid) ||
		(attachment.type == AttachmentType.mp4) ||
		(attachment.type == AttachmentType.mp3);

	bool get canShare => _playsDirectlyWithoutCaching || (overrideSource ?? _cachedFile) != null;

	Future<File> getFile() async {
		if (overrideSource != null) {
			return File(overrideSource!.path);
		}
		else if (_cachedFile != null) {
			return _cachedFile!;
		}
		else if (_playsDirectlyWithoutCaching) {
			final source = await _getGoodSource();
			if (source.isScheme('file')) {
				return File(source.path);
			}
			final response = await site.client.getUri(source, options: Options(
				responseType: ResponseType.bytes,
				headers: _getHeaders(source)
			));
			final systemTempDirectory = Persistence.temporaryDirectory;
			final directory = await (Directory('${systemTempDirectory.path}/webmcache')).create(recursive: true);
			return await File('${directory.path}${attachment.id}${attachment.ext}').writeAsBytes(response.data);
		}
		else {
			throw Exception('No file available');
		}
	}

	Future<File> _moveToShareCache() async {
		final systemTempDirectory = Persistence.temporaryDirectory;
		final shareDirectory = await (Directory('${systemTempDirectory.path}/sharecache')).create(recursive: true);
		final newFilename = attachment.id.toString() + attachment.ext.replaceFirst('webm', Platform.isAndroid ? 'webm' : 'mp4');
		File? originalFile = await getFile();
		return await originalFile.copy('${shareDirectory.path}/$newFilename');
	}

	Future<void> share(Rect? sharePosition) async {
		await shareOne(
			context: context,
			text: (await _moveToShareCache()).path,
			subject: attachment.filename,
			type: "file",
			sharePositionOrigin: sharePosition
		);
	}

	Future<void> download() async {
		if (_isDownloaded) return;
		final settings = context.read<EffectiveSettings>();
		try {
			if (Platform.isIOS) {
				final existingAlbums = await PhotoManager.getAssetPathList(type: RequestType.common);
				AssetPathEntity? album = existingAlbums.tryFirstWhere((album) => album.name == deviceGalleryAlbumName);
				album ??= await PhotoManager.editor.darwin.createAlbum('Chance');
				final shareCachedFile = await _moveToShareCache();
				final asAsset = attachment.type == AttachmentType.image ? 
					await PhotoManager.editor.saveImageWithPath(shareCachedFile.path, title: attachment.filename) :
					await PhotoManager.editor.saveVideo(shareCachedFile, title: attachment.filename);
				await PhotoManager.editor.copyAssetToPath(asset: asAsset!, pathEntity: album!);
				_isDownloaded = true;
			}
			else if (Platform.isAndroid) {
				settings.androidGallerySavePath ??= await pickDirectory();
				if (settings.androidGallerySavePath != null) {
					File source = (await getFile());
					await saveFile(
						sourcePath: source.path,
						destinationDir: settings.androidGallerySavePath!,
						destinationName: attachment.id.toString() + attachment.ext
					);
					_isDownloaded = true;
				}
			}
			else {
				throw UnsupportedError("Downloading not supported on this platform");
			}
			onDownloaded?.call();
		}
		catch (e) {
			alertError(context, e.toStringDio());
			rethrow;
		}
		notifyListeners();
	}

	Future<void> potentiallySwapVideo() async {
		if (_videoFileToSwapIn != null) {
			final newFile = _videoFileToSwapIn!;
			_videoFileToSwapIn = null;
			final oldController = _videoPlayerController;
			_videoPlayerController = VideoPlayerController.file(newFile, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
			await _videoPlayerController!.initialize();
			if (_isDisposed) return;
			await _videoPlayerController!.setLooping(true);
			if (_isDisposed) return;
			final newPosition = _swapStartTime ?? oldController?.value.position;
			if (newPosition != null) {
				await _videoPlayerController!.seekTo(newPosition);
				if (_isDisposed) return;
			}
			await _videoPlayerController!.play();
			if (_isDisposed) return;
			await _videoPlayerController!.pause();
			if (_isDisposed) return;
			notifyListeners();
			WidgetsBinding.instance.addPostFrameCallback((_) {
				oldController?.dispose();
			});
		}
	}

	@override
	void dispose() {
		_isDisposed = true;
		super.dispose();
		for (final disposer in _conversionDisposers) {
			disposer();
		}
		videoPlayerController?.pause().then((_) => videoPlayerController?.dispose());
		_longPressFactorStream.close();
		_vp9Controllers.remove(this);
	}

	@override
	String toString() => 'AttachmentViewerController(attachment: $attachment)';
}

class AttachmentViewer extends StatelessWidget {
	final AttachmentViewerController controller;
	final Iterable<int> semanticParentIds;
	final ValueChanged<double>? onScaleChanged;
	final bool fill;
	final VoidCallback? onTap;
	final bool allowContextMenu;
	final EdgeInsets layoutInsets;
	final bool useHeroDestinationWidget;
	final bool allowGestures;
	final bool heroOtherEndIsBoxFitCover;
	final bool videoThumbnailMicroPadding;
	final bool onlyRenderVideoWhenPrimary;
	final List<CupertinoContextMenuAction2> additionalContextMenuActions;

	const AttachmentViewer({
		required this.controller,
		required this.semanticParentIds,
		this.onScaleChanged,
		this.onTap,
		this.fill = true,
		this.allowContextMenu = true,
		this.layoutInsets = EdgeInsets.zero,
		this.useHeroDestinationWidget = false,
		this.allowGestures = true,
		required this.heroOtherEndIsBoxFitCover,
		this.videoThumbnailMicroPadding = true,
		this.onlyRenderVideoWhenPrimary = false,
		this.additionalContextMenuActions = const [],
		Key? key
	}) : super(key: key);

	Attachment get attachment => controller.attachment;

	Object get _tag => TaggedAttachment(
		attachment: attachment,
		semanticParentIds: semanticParentIds
	);

	Widget _centeredLoader({
		required bool active,
		required double? value
	}) => Builder(
		builder: (context) => Center(
			child: AnimatedSwitcher(
				duration: const Duration(milliseconds: 300),
				child: active ? TweenAnimationBuilder<double>(
					tween: Tween(begin: 0, end: (controller.cacheCompleted || controller.videoPlayerController != null) ? 0 : 1),
					duration: const Duration(milliseconds: 250),
					curve: Curves.ease,
					builder: (context, v, child) => Transform.scale(
						scale: v,
						child: child
					),
					child: CircularLoadingIndicator(
						key: controller.loadingSpinnerKey,
						value: value
					)
				) : Icon(
					CupertinoIcons.arrow_down_circle,
					size: 60,
					color: CupertinoTheme.of(context).primaryColor
				)
			)
		)
	);

	Tween<Rect?> _createRectTween(Rect? startRect, Rect? endRect) {
		if (startRect != null &&
				endRect != null &&
				attachment.width != null &&
				attachment.height != null &&
				DateTime.now().difference(_heroRectCache[attachment.globalId]?.$1 ?? DateTime(2000)) > const Duration(milliseconds: 300)) {
			if (useHeroDestinationWidget) {
				// This is AttachmentViewer -> AttachmentViewer
				if (startRect.topLeft == Offset.zero) {
					// This is a pop, need to shrink the startRect as the child does not have layoutInsets
					startRect = layoutInsets.deflateRect(startRect);
				}
				else {
					// This is a push, need to grow the startRect as the child has LayoutInsets
					startRect = layoutInsets.inflateRect(startRect);
				}
			}
			else if (attachment.type == AttachmentType.image) {
				// This is AttachmentThumbnail -> AttachmentViewer
				// Need to deflate the rect as AttachmentThumbnail does not know about the layoutInsets
				endRect = layoutInsets.deflateRect(endRect);
			}
			if (heroOtherEndIsBoxFitCover) {
				// The flight child will try to cover its rect. Need to restrict it based on the image aspect ratio.
				final fittedEndSize = applyBoxFit(BoxFit.contain, Size(attachment.width!.toDouble(), attachment.height!.toDouble()), endRect.size).destination;
				endRect = Alignment.center.inscribe(fittedEndSize, endRect);
			}
			_heroRectCache[attachment.globalId] = (DateTime.now(), startRect, endRect);
		}
		return RectTween(begin: _heroRectCache[attachment.globalId]?.$2 ?? startRect, end: _heroRectCache[attachment.globalId]?.$3 ?? endRect);
	}

	Widget _buildImage(BuildContext context, Size? size, bool passedFirstBuild) {
		Uri source = attachment.thumbnailUrl;
		final goodSource = controller.goodImageSource;
		if (goodSource != null && ((!goodSource.path.endsWith('.gif') || passedFirstBuild) || source.toString().length < 6)) {
			source = goodSource;
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			source.toString(),
			cache: true,
			headers: controller._getHeaders(source)
		);
		if (source.scheme == 'file') {
			image = ExtendedFileImageProvider(
				File(source.toStringFFMPEG()),
				imageCacheName: 'asdf'
			);
		}
		void onDoubleTap(ExtendedImageGestureState state) {
			final old = state.gestureDetails!;
			if ((old.totalScale ?? 1) > 1) {
				state.gestureDetails = GestureDetails(
					offset: Offset.zero,
					totalScale: 1,
					actionType: ActionType.zoom
				);
			}
			else {
				double autozoomScale = 2.0;
				if (attachment.width != null && attachment.height != null) {
					double screenAspectRatio = MediaQuery.sizeOf(context).width / MediaQuery.sizeOf(context).height;
					double attachmentAspectRatio = attachment.width! / attachment.height!;
					double fillZoomScale = screenAspectRatio / attachmentAspectRatio;
					autozoomScale = max(autozoomScale, max(fillZoomScale, 1 / fillZoomScale));
				}
				autozoomScale = min(autozoomScale, 5);
				final center = Offset(MediaQuery.sizeOf(context).width / 2, MediaQuery.sizeOf(context).height / 2);
				state.gestureDetails = GestureDetails(
					offset: (state.pointerDownPosition! * autozoomScale - center).scale(-1, -1),
					totalScale: autozoomScale,
					actionType: ActionType.zoom
				);
			}
		}
		buildChild(bool useRealGestureKey) => AbsorbPointer(
			absorbing: !allowGestures,
			child: ExtendedImage(
				image: image,
				extendedImageGestureKey: useRealGestureKey ? controller.gestureKey : null,
				color: const Color.fromRGBO(238, 242, 255, 1),
				colorBlendMode: BlendMode.dstOver,
				enableSlideOutPage: true,
				gaplessPlayback: true,
				fit: BoxFit.contain,
				mode: ExtendedImageMode.gesture,
				width: size?.width ?? double.infinity,
				height: size?.height ?? double.infinity,
				enableLoadState: true,
				handleLoadingProgress: true,
				layoutInsets: layoutInsets,
				rotate90DegreesClockwise: controller.rotate90DegreesClockwise,
				loadStateChanged: (loadstate) {
					// We can't rely on loadstate.extendedImageLoadState because of using gaplessPlayback
					if (!controller.cacheCompleted || controller.showLoadingProgress) {
						double? loadingValue;
						if (controller.cacheCompleted) {
							loadingValue = 1;
						}
						if (loadstate.loadingProgress?.cumulativeBytesLoaded != null && loadstate.loadingProgress?.expectedTotalBytes != null) {
							// If we got image download completion, we can check if it's cached
							loadingValue = loadstate.loadingProgress!.cumulativeBytesLoaded / loadstate.loadingProgress!.expectedTotalBytes!;
							if ((source != attachment.thumbnailUrl) && loadingValue == 1) {
								getCachedImageFile(source.toString()).then((file) {
									if (file != null) {
										controller.onCacheCompleted(file);
									}
								});
							}
						}
						else if (loadstate.extendedImageInfo?.image.width == attachment.width && (source != attachment.thumbnailUrl)) {
							// If the displayed image looks like the full image, we can check cache
							getCachedImageFile(source.toString()).then((file) {
								if (file != null) {
									controller.onCacheCompleted(file);
								}
							});
						}
						loadstate.returnLoadStateChangedWidget = true;
						buildContent(context, _) {
							Widget child = const SizedBox.shrink();
							if (controller.errorMessage != null) {
								child = Center(
									child: ErrorMessageCard(controller.errorMessage!, remedies: {
											'Retry': () => controller.reloadFullAttachment(),
											if (!controller.checkArchives) 'Try archives': () => controller.tryArchives()
										}
									)
								);
							}
							else if (controller.showLoadingProgress || !controller.isFullResolution) {
								child = _centeredLoader(
									active: controller.isFullResolution,
									value: loadingValue
								);
							}
							final Rect? rect = controller.gestureKey.currentState?.gestureDetails?.destinationRect;
							child = Transform.scale(
								scale: (controller.gestureKey.currentState?.extendedImageSlidePageState?.scale ?? 1) * (controller.gestureKey.currentState?.gestureDetails?.totalScale ?? 1),
								child: child
							);
							if (rect == null) {
								return Positioned.fill(
									child: child
								);
							}
							else {
								return Positioned.fromRect(
									rect: rect,
									child: child
								);
							}
						}
						return Stack(
							children: [
								loadstate.completedWidget,
								if (controller.redrawGestureListenable != null) AnimatedBuilder(
									animation: controller.redrawGestureListenable!,
									builder: buildContent
								)
								else buildContent(context, null)
							]
						);
					}
					return null;
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
						flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
						createRectTween: _createRectTween,
						child: result
					);
				}
			)
		);
		return DoubleTapDragDetector(
			shouldStart: () => controller.isFullResolution && allowGestures,
			onSingleTap: onTap,
			onDoubleTapDrag: (details) {
				final state = controller.gestureKey.currentState!;
				controller._gestureDetailsOnDoubleTapDragStart ??= state.gestureDetails;
				final screenCenter = Offset(MediaQuery.sizeOf(context).width / 2, MediaQuery.sizeOf(context).height / 2);
				Offset centerTarget = screenCenter;
				centerTarget = (centerTarget - controller._gestureDetailsOnDoubleTapDragStart!.offset!) / controller._gestureDetailsOnDoubleTapDragStart!.totalScale!;
				final scale = max(1.0, min(5.0, state.gestureDetails!.totalScale! * (1 +  (0.005 * details.localDelta.dy))));
				state.gestureDetails = GestureDetails(
					offset: (centerTarget * scale - screenCenter).scale(-1, -1),
					totalScale: scale,
					actionType: ActionType.zoom
				);
			},
			onDoubleTapDragEnd: (details) {
				if (details.localOffsetFromOrigin.distance < 1) {
					onDoubleTap(controller.gestureKey.currentState!);
				}
				controller._gestureDetailsOnDoubleTapDragStart = null;
			},
			child: !allowContextMenu ? buildChild(true) : CupertinoContextMenu2(
				actions: [
					CupertinoContextMenuAction2(
						trailingIcon: CupertinoIcons.cloud_download,
						onPressed: () async {
							Navigator.of(context, rootNavigator: true).pop();
							await controller.download();
							// ignore: use_build_context_synchronously
							showToast(context: context, message: 'Downloaded ${controller.attachment.filename}', icon: CupertinoIcons.cloud_download);
						},
						child: const Text('Download')
					),
					CupertinoContextMenuAction2(
						trailingIcon: CupertinoIcons.share,
						onPressed: () async {
							final offset = (controller.contextMenuShareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
							final size = controller.contextMenuShareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
							await controller.share((offset != null && size != null) ? offset & size : null);
							// ignore: use_build_context_synchronously
							Navigator.of(context, rootNavigator: true).pop();
						},
						key: controller.contextMenuShareButtonKey,
						child: const Text('Share')
					),
					if (context.watch<ImageboardSite?>()?.supportsSearch ?? false) CupertinoContextMenuAction2(
						trailingIcon: Icons.image_search,
						onPressed: () {
							openSearch(context: context, query: ImageboardArchiveSearchQuery(
								imageboardKey: context.read<Imageboard>().key,
								boards: [attachment.board],
								md5: attachment.md5)
							);
						},
						child: const Text('Search archives')
					),
					CupertinoContextMenuAction2(
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('www.google.com', '/searchbyimage', {
							'image_url': attachment.url.toString(),
							'safe': 'off',
							'sbisrc': 'is'
						})),
						child: const Text('Search Google')
					),
					CupertinoContextMenuAction2(
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('yandex.com', '/images/search', {
							'rpt': 'imageview',
							'url': attachment.url.toString()
						})),
						child: const Text('Search Yandex')
					),
					CupertinoContextMenuAction2(
						trailingIcon: Icons.image_search,
						onPressed: () => openBrowser(context, Uri.https('saucenao.com', '/search.php', {
							'url': attachment.url.toString()
						})),
						child: const Text('Search SauceNAO')
					),
					...additionalContextMenuActions
				],
				child: buildChild(true),
				previewBuilder: (context, animation, child) => IgnorePointer(
					child: AspectRatio(
						aspectRatio: (attachment.width != null && attachment.height != null) ? (attachment.width! / attachment.height!) : 1,
						child: buildChild(false)
					)
				)
			)
		);
	}

	double get aspectRatio {
		final videoPlayerAspectRatio = controller.videoPlayerController?.value.aspectRatio;
		if (videoPlayerAspectRatio != null && videoPlayerAspectRatio != 1) {
			// Sometimes 1.00 is returned when player is not yet loaded
			return videoPlayerAspectRatio;
		}
		if (attachment.width != null && attachment.height != null) {
			return attachment.width! / attachment.height!;
		}
		return 1;
	}

	Widget _buildVideo(BuildContext context, Size? size) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			},
			child: SizedBox.fromSize(
				size: size,
				child: GestureDetector(
					behavior: HitTestBehavior.translucent,
					onLongPressStart: (x) => controller._onLongPressStart(),
					onLongPressMoveUpdate: (x) => controller._onLongPressUpdate(x.offsetFromOrigin.dx / (MediaQuery.sizeOf(context).width / 2)),
					onLongPressEnd: (x) => controller._onLongPressEnd(),
					child: Stack(
						children: [
							Positioned.fill(
								child: FittedBox(
									child: Padding(
										// Sometimes it's very slightly off from the video.
										// This errs to have it too small rather than too large.
										padding: videoThumbnailMicroPadding ? const EdgeInsets.all(1) : EdgeInsets.zero,
										child: AttachmentThumbnail(
											attachment: attachment,
											width: attachment.width?.toDouble() ?? double.infinity,
											height: attachment.height?.toDouble() ?? double.infinity,
											rotate90DegreesClockwise: controller.rotate90DegreesClockwise,
											gaplessPlayback: true,
											revealSpoilers: true,
											site: controller.site
										)
									)
								)
							),
							if (controller._showAudioOnly) Positioned.fill(
								child: Center(
									child: RotatedBox(
										quarterTurns: controller.rotate90DegreesClockwise ? 1 : 0,
										child: Container(
											padding: const EdgeInsets.all(8),
											decoration: const BoxDecoration(
												color: Colors.black54,
												borderRadius: BorderRadius.all(Radius.circular(8))
											),
											child: IntrinsicWidth(
												child: Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														const SizedBox(height: 10),
														const Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																SizedBox(width: 64),
																Icon(CupertinoIcons.waveform, size: 32, color: Colors.white),
																Text(
																	'Audio only',
																	style: TextStyle(
																		fontSize: 32,
																		color: Colors.white
																	)
																),
																SizedBox(width: 64)
															]
														),
														const SizedBox(height: 10),
														VideoControls(controller: controller, showMuteButton: false),
														const SizedBox(height: 10)
													]
												)
											)
										)
									)
								)
							),
							if (controller.videoPlayerController != null && (controller.isPrimary || !onlyRenderVideoWhenPrimary)) IgnorePointer(
								child: Center(
									child: RotatedBox(
										quarterTurns: controller.rotate90DegreesClockwise ? 1 : 0,
										child: AspectRatio(
											aspectRatio: aspectRatio,
											child: VideoPlayer(controller.videoPlayerController!)
										)
									)
								)
							),
							if (controller.showLoadingProgress) ValueListenableBuilder(
								valueListenable: controller.videoLoadingProgress,
								builder: (context, double? loadingProgress, child) => _centeredLoader(
									active: controller.isFullResolution,
									value: loadingProgress
								)
							),
							if (controller.errorMessage != null) Center(
								child: ErrorMessageCard(controller.errorMessage!, remedies: {
									'Retry': () => controller.reloadFullAttachment(),
									if (!controller.checkArchives) 'Try archives': () => controller.tryArchives()
								})
							),
							AnimatedSwitcher(
								duration: const Duration(milliseconds: 250),
								child: (controller.overlayText != null) ? Center(
									child: RotatedBox(
										quarterTurns: controller.rotate90DegreesClockwise ? 1 : 0,
										child: Container(
											padding: const EdgeInsets.all(8),
											margin: EdgeInsets.only(
												top: 12,
												bottom: controller.swapIncoming ? 0 : 12
											),
											decoration: const BoxDecoration(
												color: Colors.black54,
												borderRadius: BorderRadius.all(Radius.circular(8))
											),
											child: IntrinsicWidth(
												child: Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														Text(
															controller.overlayText!,
															style: TextStyle(
																fontSize: 32,
																color: Colors.white.withOpacity(controller.dimOverlayText ? 0.5 : 1)
															)
														),
														if (controller.swapIncoming) Padding(
															padding: const EdgeInsets.symmetric(vertical: 4),
															child: ValueListenableBuilder(
																valueListenable: controller.videoLoadingProgress,
																builder: (context, double? value, _) => LinearProgressIndicator(
																	color: Colors.white,
																	backgroundColor: Colors.black,
																	value: value
																)
															)
														)
													]
												)
											)
										)
									)
								) : const SizedBox.shrink()
							)
						]
					)
				)
			)
		);
	}

	Widget _buildPdf(BuildContext context, Size? size) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			},
			child: SizedBox.fromSize(
				size: size,
				child: Stack(
					children: [
						AttachmentThumbnail(
							attachment: attachment,
							width: double.infinity,
							height: double.infinity,
							rotate90DegreesClockwise: controller.rotate90DegreesClockwise,
							gaplessPlayback: true,
							revealSpoilers: true,
							site: controller.site
						),
						Center(
							child: ErrorMessageCard(
								'PDFs not viewable in-app',
								remedies: {
									'Open externally': () => shareOne(
										context: context,
										text: controller.goodImageSource.toString(),
										type: 'text',
										sharePositionOrigin: null
									)
								}
							)
						)
					]
				)
			)
		);
	}

	Widget _buildBrowser(BuildContext context, Size? size) {
		return ExtendedImageSlidePageHandler(
			heroBuilderForSlidingPage: (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			},
			child: SizedBox.fromSize(
				size: size,
				child: CooperativeInAppBrowser(
					initialUrlRequest: URLRequest(url: WebUri.uri(controller.attachment.url))
				)
			)
		);
	}

	@override
	Widget build(BuildContext context) {
		return FirstBuildDetector(
			identifier: _tag,
			builder: (context, passedFirstBuild) {
				return LayoutBuilder(
					builder: (context, constraints) {
						Size? targetSize;
						if (!fill && attachment.width != null && attachment.height != null && constraints.hasBoundedHeight && constraints.hasBoundedWidth) {
							targetSize = applyBoxFit(BoxFit.scaleDown, Size(attachment.width!.toDouble(), attachment.height!.toDouble()), constraints.biggest).destination;
						}
						if (attachment.type == AttachmentType.image && attachment.soundSource == null) {
							return _buildImage(context, targetSize, passedFirstBuild);
						}
						else if (attachment.type == AttachmentType.pdf) {
							return _buildPdf(context, targetSize);
						}
						else if (attachment.type == AttachmentType.url) {
							return _buildBrowser(context, targetSize);
						}
						else {
							return _buildVideo(context, targetSize);
						}
					}
				);
			}
		);
	}
}