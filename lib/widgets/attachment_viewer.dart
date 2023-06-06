import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/soundposts.dart';
import 'package:chan/services/storage.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/text_recognition.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/translation.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mutex/mutex.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Quaternion;

final _domainLoadTimes = <String, List<Duration>>{};

void _recordUrlTime(Uri url, Duration loadTime) {
	_domainLoadTimes.putIfAbsent(url.host, () => []).add(loadTime);
}

const _minUrlTime = Duration(milliseconds: 500);

// If the Hero endRect doesn't match up with the hero destination widget origin,
// flutter will keep trying to recalculate it.
// It's a lazy fix, but works, if we just cache the first result.
final Map <String, (DateTime, Rect, Rect)> _heroRectCache = {};

final Set<Uri> _problematicVideos = {};

Duration _estimateUrlTime(Uri url) {
	final times = _domainLoadTimes[url.host] ?? <Duration>[];
	final time = (times.fold(Duration.zero, (Duration a, b) => a + b) * 1.5) ~/ max(times.length, 1);
	if (time < _minUrlTime) {
		return _minUrlTime;
	}
	return time;
}

const deviceGalleryAlbumName = 'Chance';

class CurvedRectTween extends Tween<Rect?> {
	final Curve curve;
	CurvedRectTween({
		this.curve = Curves.linear,
		super.begin,
		super.end
	});

	@override
  Rect? lerp(double t) => Rect.lerp(begin, end, curve.transform(t));
}

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

const _maxVideoControllers = 3;
final List<AttachmentViewerController> _videoControllers = [];

extension on AndroidGallerySavePathOrganizing {
	List<String> subfoldersFor(Attachment attachment) {
		switch (this) {
			case AndroidGallerySavePathOrganizing.noSubfolders:
				return [];
			case AndroidGallerySavePathOrganizing.boardSubfolders:
				return [attachment.board];
			case AndroidGallerySavePathOrganizing.boardAndThreadSubfolders:
				return [attachment.board, attachment.threadId.toString()];
		}
	}
}

Future<File?> optimisticallyFindCachedFile(Attachment attachment) async {
	if (attachment.type == AttachmentType.pdf || attachment.type == AttachmentType.url) {
		// Not cacheable
		return null;
	}
	if (attachment.type == AttachmentType.image) {
		return await getCachedImageFile(attachment.url);
	}
	if (attachment.type == AttachmentType.webm) {
		final conversion = MediaConversion.toMp4(Uri.parse(attachment.url));
		final file = conversion.getDestination();
		if (await file.exists()) {
			return file;
		}
		// Fall through in case WEBM is directly playing
	}
	final file = VideoServer.instance.optimisticallyGetFile(Uri.parse(attachment.url));
	if (await file.exists()) {
		return file;
	}
	return null;
}

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
	final _lock = Mutex();
	bool _hideVideoPlayerController = false;
	List<RecognizedTextBlock> _textBlocks = [];

	// Public API
	/// Whether loading of the full quality attachment has begun
	bool get isFullResolution => _isFullResolution || overrideSource != null;
	/// Error that occured while loading the full quality attachment
	String? get errorMessage => _errorMessage;
	/// Whether the loading spinner should be displayed
	bool get showLoadingProgress => _showLoadingProgress;
	/// Conversion process of a video attachment
	ValueListenable<double?> get videoLoadingProgress => _videoLoadingProgress;
	/// A VideoPlayerController to enable playing back video attachments
	VideoPlayerController? get videoPlayerController => _hideVideoPlayerController ? null : _videoPlayerController;
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
	final gestureKey = GlobalKey<ExtendedImageGestureState>(debugLabel: 'AttachmentViewerController.gestureKey');
	/// A key to use with CupertinoContextMenu share button
	final contextMenuShareButtonKey = GlobalKey(debugLabel: 'AttachmentViewerController.contextMenuShareButtonKey');
	/// Whether archive checking is possible for this attachment
	bool get canCheckArchives => site.archives.isNotEmpty;
	/// Whether archive checking for this attachment is enabled
	bool get checkArchives => _checkArchives;
	/// Modal text which should be overlayed on the attachment
	String? get overlayText => _overlayText;
	// Whether the modal text should be dimmed
	bool get dimOverlayText => _swapIncoming;
	/// Whether the image has already been downloaded
	bool get isDownloaded => _isDownloaded;
	/// Key to use for loading spinner
	final loadingSpinnerKey = GlobalKey(debugLabel: 'AttachmentViewerController.loadingSpinnerKey');
	/// The duration of the video, if known
	Duration? get duration => _duration;
	/// Whether a seekable version of the video is incoming
	bool get swapIncoming => _swapIncoming;
	/// Whether a seekable version of the file is ready to swap in
	bool get swapAvailable => _videoFileToSwapIn != null;
	/// Blocks of text to draw on top of image
	List<RecognizedTextBlock> get textBlocks => _textBlocks;


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
				if (file != null && _cachedFile == null && !_isDisposed) {
					_cachedFile = file;
					attachment.sizeInBytes ??= file.statSync().size;
					_goodImageSource = Uri.parse(attachment.url);
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

	Map<String, String> getHeaders(Uri url) {
		return {
			...site.getHeaders(url) ?? {},
			if (_useRandomUserAgent ?? attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
		};
	}

	Future<Uri> _getGoodSource({required bool interactive}) async {
		if (overrideSource != null) {
			return overrideSource!;
		}
		final attachmentUrl = Uri.parse(attachment.url);
		Response result = await site.client.headUri(attachmentUrl, options: Options(
			validateStatus: (_) => true,
			headers: getHeaders(attachmentUrl),
			extra: {
				kInteractive: interactive
			}
		));
		if (result.statusCode == 200) {
			return attachmentUrl;
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
				headers: getHeaders(Uri.parse(correctedUrl)),
				extra: {
					kInteractive: interactive
				}
			));
			if (result.statusCode == 200) {
				return Uri.parse(correctedUrl);
			}
		}
		if (_checkArchives && attachment.threadId != null) {
			final archivedThread = await site.getThreadFromArchive(ThreadIdentifier(
				attachment.board,
				attachment.threadId!
			), customValidator: (thread) async {
				final newAttachment = thread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.id == attachment.id)
					?? thread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.filename == attachment.filename && a.id.contains(attachment.id));
				if (newAttachment == null) {
					throw AttachmentNotFoundException(attachment);
				}
				_useRandomUserAgent = newAttachment.useRandomUseragent;
				final check = await site.client.head(newAttachment.url.toString(), options: Options(
					validateStatus: (_) => true,
					headers: getHeaders(Uri.parse(newAttachment.url)),
					extra: {
						kInteractive: interactive
					}
				));
				if (check.statusCode != 200) {
					throw AttachmentNotArchivedException(attachment);
				}
			}, interactive: interactive);
			final goodAttachment = archivedThread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.id == attachment.id)
				?? archivedThread.posts.expand((p) => p.attachments).tryFirstWhere((a) => a.filename == attachment.filename && a.id.contains(attachment.id))!;
			_useRandomUserAgent = goodAttachment.useRandomUseragent;
			return Uri.parse(goodAttachment.url);
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
		final controller = videoPlayerController;
		_videoPlayerController = null;
		if (controller != null) {
			controller.pause().then((_) => controller.dispose());
		}
		_goodImageSource = null;
		_longPressFactorSubscription?.cancel();
		_longPressFactorStream.close();
		notifyListeners();
	}

	Future<void> _loadFullAttachment(bool background, {bool force = false}) => _lock.protect(() async {
		if (_isDisposed) {
			return;
		}
		if (attachment.type == AttachmentType.image && goodImageSource != null && !force) {
			final file = await getCachedImageFile(goodImageSource.toString());
			if (file != null && _cachedFile?.path != file.path) {
				onCacheCompleted(file);
			}
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
		_hideVideoPlayerController = true;
		_cachedFile = null;
		_isFullResolution = true;
		_showLoadingProgress = false;
		_showAudioOnly = false;
		_loadingProgressHideScheduled = false;
		notifyListeners();
		final startTime = DateTime.now();
		Future.delayed(_estimateUrlTime(Uri.parse(attachment.thumbnailUrl)), () {
			if (_loadingProgressHideScheduled) return;
			_showLoadingProgress = true;
			if (_isDisposed) return;
			notifyListeners();
		});
		try {
			final soundSource = attachment.soundSource;
			if (soundSource == null && (attachment.type == AttachmentType.image || attachment.type == AttachmentType.pdf)) {
				_goodImageSource = await _getGoodSource(interactive: !background);
				_recordUrlTime(_goodImageSource!, DateTime.now().difference(startTime));
				if (_goodImageSource?.scheme == 'file') {
					_cachedFile = File(_goodImageSource!.path);
					attachment.sizeInBytes ??= _cachedFile!.statSync().size;
				}
				if (_isDisposed) return;
				notifyListeners();
				if (background && attachment.type == AttachmentType.image) {
					await ExtendedNetworkImageProvider(
						goodImageSource.toString(),
						cache: true,
						headers: getHeaders(goodImageSource!)
					).getNetworkImageData();
					final file = await getCachedImageFile(goodImageSource.toString());
					if (file != null && _cachedFile?.path != file.path) {
						_cachedFile = file;
						attachment.sizeInBytes ??= file.statSync().size;
					}
				}
			}
			else if (soundSource != null || attachment.type == AttachmentType.webm || attachment.type == AttachmentType.mp4 || attachment.type == AttachmentType.mp3) {
				final url = await _getGoodSource(interactive: !background);
				_recordUrlTime(url, DateTime.now().difference(startTime));
				bool transcode = _problematicVideos.contains(url);
				if (attachment.type == AttachmentType.webm) {
					transcode |= settings.webmTranscoding == WebmTranscodingSetting.always;
				}
				transcode |= url.path.endsWith('.m3u8');
				transcode |= soundSource != null;
				if (!transcode) {
					final scan = await MediaScan.scan(url, headers: getHeaders(url));
					if (_isDisposed) {
						return;
					}
					_hasAudio = scan.hasAudio;
					if (scan.codec == 'vp9' && settings.webmTranscoding == WebmTranscodingSetting.vp9) {
						transcode = true;
					}
				}
				_videoControllers.add(this);
				if (_videoControllers.length > _maxVideoControllers) {
					AttachmentViewerController removed = _videoControllers.removeAt(0);
					if (!removed._isDisposed && removed != this) {
						if (removed.isPrimary) {
							// Unlucky order, should be able to fix it by cycling
							_videoControllers.add(removed);
							removed = _videoControllers.removeAt(0);
						}
						removed.goToThumbnail();
					}
				}
				bool isAudioOnly = false;
				if (!transcode) {
					if (url.scheme == 'file') {
						final file = File(url.toStringFFMPEG());
						_videoPlayerController = VideoPlayerController.file(
							file,
							videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
						);
						onCacheCompleted(file);
					}
					else {
						final progressNotifier = ValueNotifier<double?>(null);
						final hash = await VideoServer.instance.startCachingDownload(
							uri: url,
							headers: getHeaders(url),
							onCached: onCacheCompleted,
							onProgressChanged: (currentBytes, totalBytes) {
								progressNotifier.value = currentBytes / totalBytes;
							},
							force: force
						);
						if (_isDisposed) return;
						_videoLoadingProgress = progressNotifier;
						notifyListeners();
						if (!background) {
							_videoPlayerController = VideoPlayerController.network(
								VideoServer.instance.getUri(hash).toString(),
								videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
							);
						}
					}
				}
				else {
					_ongoingConversion?.cancelIfActive();
					_ongoingConversion = StreamingMP4Conversion(url, headers: getHeaders(url), soundSource: soundSource);
					final result = await _ongoingConversion!.start(force: force);
					if (_isDisposed) return;
					_conversionDisposers.add(_ongoingConversion!.dispose);
					_ongoingConversion = null;
					_hasAudio = result.hasAudio;
					isAudioOnly = result.isAudioOnly;
					if (result is StreamingMP4ConvertedFile) {
						if (isPrimary || !background) {
							_videoPlayerController = VideoPlayerController.file(result.mp4File, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
						}
						_cachedFile = result.mp4File;
						attachment.sizeInBytes ??= result.mp4File.statSync().size;
					}
					else if (result is StreamingMP4ConversionStream) {
						_duration = result.duration;
						if (isPrimary || !background) {
							_videoPlayerController = VideoPlayerController.network(result.hlsStream.toString(), formatHint: VideoFormat.hls, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
						}
						_videoLoadingProgress = result.progress;
						_swapIncoming = true;
						result.mp4File.then((mp4File) async {
							if (_isDisposed) {
								return;
							}
							_cachedFile = mp4File;
							attachment.sizeInBytes ??= mp4File.statSync().size;
							_videoFileToSwapIn = mp4File;
							if (_waitingOnSwap && !background) {
								await potentiallySwapVideo();
							}
							_videoLoadingProgress = ValueNotifier(null);
							_swapIncoming = false;
							notifyListeners();
						});
						if (!isPrimary && background) {
							// Wait for full conversion during preload
							await result.mp4File;
						}
					}
					else if (result is StreamingMP4ConvertingFile) {
						_duration = result.duration;
						_videoLoadingProgress = result.progress;
						result.mp4File.then((mp4File) async {
							if (_isDisposed) {
								return;
							}
							_cachedFile = mp4File;
							attachment.sizeInBytes ??= mp4File.statSync().size;
							_videoFileToSwapIn = mp4File;
							if (isPrimary && !background) {
								await potentiallySwapVideo(play: true);
							}
							_videoLoadingProgress = ValueNotifier(null);
							notifyListeners();
						});
					}
				}
				if (_isDisposed) return;
				if (_videoPlayerController != null) {
					try {
						await _videoPlayerController!.initialize();
						_hideVideoPlayerController = false;
					}
					catch (e) {
						if (!transcode &&
						    e is PlatformException &&
								((e.message?.contains('ExoPlaybackException') ?? false) ||
								 (e.message?.contains('MediaCodecVideoRenderer error') ?? false))) {
							_videoPlayerController?.dispose();
							_videoPlayerController = null;
							_problematicVideos.add(url);
							Future.microtask(() => _loadFullAttachment(background, force: force));
							if (context.mounted) {
								showToast(
									context: context,
									message: 'Problem with playback, running fallback conversion...',
									icon: CupertinoIcons.ant
								);
							}
							return;
						}
						rethrow;
					}
					if (_isDisposed) return;
					if (settings.muteAudio.value || settings.alwaysStartVideosMuted) {
						if (!settings.muteAudio.value) {
							settings.setMuteAudio(true);
						}
						await _videoPlayerController?.setVolume(0);
						if (_isDisposed) return;
					}
					await _videoPlayerController?.setLooping(true);
					if (_isDisposed) return;
					if (isPrimary) {
						await _videoPlayerController?.seekTo(Duration.zero);
						await _videoPlayerController?.play();
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
	});

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
		attachment.sizeInBytes ??= file.statSync().size;
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
		if (_isDisposed) {
			return;
		}
		_longPressFactorStream.add(factor);
	}

	void _onCoalescedLongPressUpdate(double factor) async {
		if (_isDisposed) {
			return;
		}
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

	bool get canShare => (overrideSource ?? _cachedFile) != null;

	Future<File> getFile() async {
		if (overrideSource != null) {
			return File(overrideSource!.path);
		}
		else if (_cachedFile != null) {
			return _cachedFile!;
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

	Future<void> translate() async {
		final rawBlocks = await recognizeText(_cachedFile!);
		final translated = await batchTranslate(rawBlocks.map((r) => r.text).toList());
		_textBlocks = rawBlocks.asMap().entries.map((e) => (
			text: e.key >= translated.length ? 'Nothing for ${e.key} (${translated.length}' : translated[e.key],
			rect: e.value.rect
		)).toList();
		notifyListeners();
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
					try {
						await saveFile(
							sourcePath: source.path,
							destinationDir: settings.androidGallerySavePath!,
							destinationSubfolders: settings.androidGallerySavePathOrganizing.subfoldersFor(attachment),
							destinationName: attachment.id.toString() + attachment.ext
						);
						_isDownloaded = true;
					}
					on DirectoryNotFoundException {
						settings.androidGallerySavePath = null;
						rethrow;
					}
					on InsufficientPermissionException {
						settings.androidGallerySavePath = null;
						rethrow;
					}
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

	Future<void> potentiallySwapVideo({bool play = false}) async {
		if (_videoFileToSwapIn != null) {
			final settings = context.read<EffectiveSettings>();
			final newFile = _videoFileToSwapIn!;
			_videoFileToSwapIn = null;
			final oldController = _videoPlayerController;
			_videoPlayerController = VideoPlayerController.file(newFile, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
			await _videoPlayerController!.initialize();
			if (_isDisposed) return;
			final mute = oldController?.value.volume.isZero ?? settings.muteAudio.value || settings.alwaysStartVideosMuted;
			if (mute) {
				if (!settings.muteAudio.value) {
					settings.setMuteAudio(true);
				}
				await _videoPlayerController?.setVolume(0);
				if (_isDisposed) return;
			}
			if (_isDisposed) return;
			await _videoPlayerController?.setLooping(true);
			if (_isDisposed) return;
			final newPosition = _swapStartTime ?? oldController?.value.position;
			if (newPosition != null) {
				await _videoPlayerController?.seekTo(newPosition);
				if (_isDisposed) return;
			}
			await _videoPlayerController?.play();
			if (_isDisposed) return;
			if (!play) {
				await _videoPlayerController?.pause();
				if (_isDisposed) return;
			}
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
		_videoControllers.remove(this);
		_ongoingConversion?.cancelIfActive();
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
	final double? maxWidth;
	final BoxFit fit;

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
		this.maxWidth,
		this.fit = BoxFit.contain,
		Key? key
	}) : super(key: key);

	Attachment get attachment => controller.attachment;

	Object get _tag => TaggedAttachment(
		attachment: attachment,
		semanticParentIds: semanticParentIds
	);

	Widget _centeredLoader({
		required bool active,
		required double? value,
		required bool useRealKey
	}) => Builder(
		builder: (context) => Center(
			child: AnimatedSwitcher(
				duration: const Duration(milliseconds: 300),
				child: active ? TweenAnimationBuilder<double>(
					tween: Tween(begin: 0, end: controller.cacheCompleted ? 0 : 1),
					duration: const Duration(milliseconds: 250),
					curve: Curves.ease,
					builder: (context, v, child) => Transform.scale(
						scale: v,
						child: child
					),
					child: CircularLoadingIndicator(
						key: useRealKey ? controller.loadingSpinnerKey : null,
						value: value
					)
				) : (controller.cacheCompleted ? const SizedBox.shrink() : Icon(
					CupertinoIcons.arrow_down_circle,
					size: 60,
					color: ChanceTheme.primaryColorOf(context)
				))
			)
		)
	);

	Tween<Rect?> _createRectTween(Rect? startRect, Rect? endRect) {
		if (startRect != null &&
				endRect != null &&
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
			if ((useHeroDestinationWidget ? fit == BoxFit.cover : heroOtherEndIsBoxFitCover) &&
					attachment.width != null &&
					attachment.height != null) {
				// The flight child will try to cover its rect. Need to restrict it based on the image aspect ratio.
				final fittedEndSize = applyBoxFit(BoxFit.contain, Size(attachment.width!.toDouble(), attachment.height!.toDouble()), endRect.size).destination;
				endRect = Alignment.center.inscribe(fittedEndSize, endRect);
			}
			_heroRectCache[attachment.globalId] = (DateTime.now(), startRect, endRect);
		}
		return CurvedRectTween(
			curve: Curves.ease,
			begin: _heroRectCache[attachment.globalId]?.$2 ?? startRect,
			end: _heroRectCache[attachment.globalId]?.$3 ?? endRect
		);
	}

	Widget _buildImage(BuildContext context, Size? size, bool passedFirstBuild) {
		Uri source = controller.overrideSource ?? Uri.parse(attachment.thumbnailUrl);
		final goodSource = controller.goodImageSource;
		if (goodSource != null && ((!goodSource.path.endsWith('.gif') || passedFirstBuild) || source.toString().length < 6)) {
			source = goodSource;
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			source.toString(),
			cache: true,
			headers: controller.getHeaders(source)
		);
		if (source.scheme == 'file') {
			image = ExtendedFileImageProvider(
				File(source.toStringFFMPEG()),
				imageCacheName: 'asdf'
			);
		}
		if (maxWidth != null) {
			image = ExtendedResizeImage(
				image,
				width: maxWidth!.ceil()
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
				fit: fit,
				mode: ExtendedImageMode.gesture,
				width: size?.width ?? double.infinity,
				height: size?.height ?? double.infinity,
				enableLoadState: true,
				handleLoadingProgress: true,
				layoutInsets: layoutInsets,
				afterPaintImage: (canvas, rect, image, paint) {
					final transform = Matrix4.identity();
					transform.setFromTranslationRotationScale(Vector3(rect.left, rect.top, 0), Quaternion.identity(), Vector3(rect.width / image.width, rect.height / image.height, 0));
					for (final block in controller.textBlocks) {
						// Assume the text is always one line
						final transformedRect = MatrixUtils.transformRect(transform, block.rect);
						double fontSize = 14;
						final builder1 = ui.ParagraphBuilder(ui.ParagraphStyle())..pushStyle(ui.TextStyle(fontSize: fontSize))..addText(block.text)..pop();
						final paragraph1 = builder1.build();
						paragraph1.layout(const ui.ParagraphConstraints(width: double.infinity));
						fontSize *= min(transformedRect.width / paragraph1.maxIntrinsicWidth, transformedRect.height / paragraph1.height);
						final builder2 = ui.ParagraphBuilder(ui.ParagraphStyle())..pushStyle(ui.TextStyle(fontSize: fontSize, color: Colors.black))..addText(block.text)..pop();
						final paragraph2 = builder2.build();
						paragraph2.layout(const ui.ParagraphConstraints(width: double.infinity));
						canvas.drawRect(transformedRect, Paint()..color = Colors.white.withOpacity(1));
						canvas.drawParagraph(paragraph2, transformedRect.topLeft + Offset(0, max(0, (paragraph2.height - transformedRect.height) / 2)));
					}
				},
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
							if ((source != Uri.parse(attachment.thumbnailUrl)) && loadingValue == 1) {
								getCachedImageFile(source.toString()).then((file) {
									if (file != null) {
										controller.onCacheCompleted(file);
									}
								});
							}
						}
						else if (loadstate.extendedImageInfo?.image.width == attachment.width && (source != Uri.parse(attachment.thumbnailUrl))) {
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
											if (controller.canCheckArchives && !controller.checkArchives) 'Try archives': () => controller.tryArchives()
										}
									)
								);
							}
							else if (controller.gestureKey.currentState?.extendedImageSlidePageState?.popping != true && (controller.showLoadingProgress || !controller.isFullResolution)) {
								child = _centeredLoader(
									active: controller.isFullResolution,
									value: loadingValue,
									useRealKey: useRealGestureKey
								);
							}
							final Rect? rect = controller.gestureKey.currentState?.gestureDetails?.destinationRect?.shift(
								controller.gestureKey.currentState?.extendedImageSlidePageState?.backOffsetAnimation?.value ?? Offset.zero
							);
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
				heroBuilderForSlidingPage: controller.isPrimary ? (Widget result) {
					return Hero(
						tag: _tag,
						flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
						createRectTween: _createRectTween,
						child: result
					);
				} : null
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
					if (isTextRecognitionSupported) CupertinoContextMenuAction2(
						trailingIcon: Icons.translate,
						onPressed: () async {
							try {
								await modalLoad(context, 'Translating...', (c) => controller.translate().timeout(const Duration(seconds: 10)));
							}
							catch (e) {
								alertError(context, e.toStringDio());
							}
							if (context.mounted) {
								Navigator.pop(context);
							}
						},
						child: const Text('Translate')
					),
					...buildImageSearchActions(context, () async => attachment).map((a) => CupertinoContextMenuAction2(
						isDestructiveAction: a.isDestructiveAction,
						onPressed: a.onPressed,
						trailingIcon: a.trailingIcon,
						child: a.child,
					)),
					if (context.select<EffectiveSettings, bool>((p) => p.areMD5sHidden([attachment.md5]))) CupertinoContextMenuAction2(
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<EffectiveSettings>().unHideByMD5s([attachment.md5]);
							context.read<EffectiveSettings>().didUpdateHiddenMD5s();
							Navigator.pop(context);
						},
						child: const Text('Unhide by image')
					)
					else CupertinoContextMenuAction2(
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () async {
							context.read<EffectiveSettings>().hideByMD5(attachment.md5);
							context.read<EffectiveSettings>().didUpdateHiddenMD5s();
							Navigator.pop(context);
						},
						child: const Text('Hide by image')
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
			heroBuilderForSlidingPage: controller.isPrimary ? (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			} : null,
			child: SizedBox.fromSize(
				size: size,
				child: GestureDetector(
					behavior: HitTestBehavior.translucent,
					onLongPressStart: (x) => controller._onLongPressStart(),
					onLongPressMoveUpdate: (x) => controller._onLongPressUpdate(x.offsetFromOrigin.dx / (MediaQuery.sizeOf(context).width / 2)),
					onLongPressEnd: (x) => controller._onLongPressEnd(),
					child: Stack(
						children: [
							const Positioned.fill(
								// Needed to enable tapping to reveal chrome via an ancestor GestureDetector
								child: AbsorbPointer()
							),
							if (controller.overrideSource == null) Positioned.fill(
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
									value: loadingProgress,
									useRealKey: true
								)
							),
							if (controller.errorMessage != null) Center(
								child: ErrorMessageCard(controller.errorMessage!, remedies: {
									'Retry': () => controller.reloadFullAttachment(),
									if (controller.canCheckArchives && !controller.checkArchives) 'Try archives': () => controller.tryArchives()
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
			heroBuilderForSlidingPage: controller.isPrimary ? (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			} : null,
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
			heroBuilderForSlidingPage: controller.isPrimary ? (Widget result) {
				return Hero(
					tag: _tag,
					flightShuttleBuilder: (ctx, animation, direction, from, to) => useHeroDestinationWidget ? to.widget : from.widget,
					createRectTween: _createRectTween,
					child: result
				);
			} : null,
			child: SizedBox.fromSize(
				size: size,
				child: CooperativeInAppBrowser(
					initialUrlRequest: URLRequest(url: WebUri.uri(Uri.parse(controller.attachment.url)))
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