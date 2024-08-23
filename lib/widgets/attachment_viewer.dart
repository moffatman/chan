import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/attachment_cache.dart';
import 'package:chan/services/imageboard.dart';
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
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/circular_loading_indicator.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cooperative_browser.dart';
import 'package:chan/widgets/double_tap_drag_detector.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/video_controls.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide ContextMenu;
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import 'package:mutex/mutex.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart'; 
import 'package:vector_math/vector_math_64.dart' show Vector3, Quaternion;

final _domainLoadTimes = <(String, AttachmentType), List<Duration>>{};

void _recordUrlTime(Uri url, AttachmentType type, Duration loadTime) {
	_domainLoadTimes.putIfAbsent((url.host, type), () => []).add(loadTime);
}

const _minUrlTime = Duration(milliseconds: 500);
const _maxUrlTime = Duration(milliseconds: 1250);

// If the Hero endRect doesn't match up with the hero destination widget origin,
// flutter will keep trying to recalculate it.
// It's a lazy fix, but works, if we just cache the first result.
final Map <String, (DateTime, Rect, Rect)> _heroRectCache = {};

Duration _estimateUrlTime(Uri url, AttachmentType type) {
	final times = _domainLoadTimes[(url.host, type)] ?? <Duration>[];
	final time = (times.fold(Duration.zero, (Duration a, b) => a + b) * 1.5) ~/ max(times.length, 1);
	return time.clamp(_minUrlTime, _maxUrlTime);
}

const _kDeviceGalleryAlbumName = 'Chance';

extension _Current on Playlist {
	Media? get current {
		if (index > medias.length - 1) {
			return null;
		}
		return medias[index];
	}
}

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

class MediaPlayerException implements Exception {
	final String error;
	final Media? media;

	const MediaPlayerException(this.error, this.media);
	@override
	String toString() => 'Playback failed: $error\nFile: $media';
}

const _maxVideoControllers = 3;
final List<AttachmentViewerController> _videoControllers = [];

extension on GallerySavePathOrganizing {
	List<String> subfoldersFor(AttachmentViewerController controller) {
		final attachment = controller.attachment;
		switch (this) {
			case GallerySavePathOrganizing.noFolder:
			case GallerySavePathOrganizing.noSubfolders:
				return [];
			case GallerySavePathOrganizing.boardSubfolders:
				return [attachment.board];
			case GallerySavePathOrganizing.boardAndThreadSubfolders:
				return [attachment.board, attachment.threadId.toString()];
			case GallerySavePathOrganizing.boardAndThreadNameSubfolders:
				final title = controller.thread?.title;
				if (title == null) {
					return [attachment.board, attachment.threadId.toString()];
				}
				return [attachment.board, '${attachment.threadId} - ${title.length > 30 ? '${title.substring(0, 27)}...' : title}'];
			case GallerySavePathOrganizing.threadNameSubfolders:
				final title = controller.thread?.title;
				if (title == null) {
					return ['${attachment.board} - ${attachment.threadId}'];
				}
				return ['${attachment.board} - ${attachment.threadId} - ${title.length > 30 ? '${title.substring(0, 27)}...' : title}'];
		}
	}
	String? albumNameFor(Attachment attachment) => switch (this) {
		GallerySavePathOrganizing.noFolder => null,
		GallerySavePathOrganizing.noSubfolders => _kDeviceGalleryAlbumName,
		_ => '$_kDeviceGalleryAlbumName - /${attachment.board}/'
	};
}

extension _AspectRatio on PlayerState {
	double? get aspectRatio {
		if (width == null || height == null) {
			return null;
		}
		return width! / height!;
	}
}

class AttachmentViewerController extends ChangeNotifier {
	// Parameters
	final BuildContext context;
	final Attachment attachment;
	final Listenable? redrawGestureListenable;
	final Imageboard imageboard;
	ImageboardSite get site => imageboard.site;
	final Uri? overrideSource;
	final VoidCallback? onDownloaded;

	// Private usage
	bool _isFullResolution = false;
	String? _errorMessage;
	VideoController? _videoPlayerController;
	bool _hasAudio = false;
	Uri? _goodImageSource;
	File? _cachedFile;
	bool _isPrimary = false;
	StreamingMP4Conversion? _ongoingConversion;
	final _conversionDisposers = <VoidCallback>[];
	bool _checkArchives = false;
	final _showLoadingProgress = ValueNotifier<bool>(false);
	final _longPressFactor = BufferedValueNotifier<double>(const Duration(milliseconds: 50), 0);
	int _millisecondsBeforeLongPress = 0;
	bool _currentlyWithinLongPress = false;
	bool _playingBeforeLongPress = false;
	bool _seeking = false;
	String? _overlayText;
	bool _isDisposed = false;
	bool _isDownloaded;
	Offset? _doubleTapDragAnchor;
	bool _loadingProgressHideScheduled = false;
	bool? _useRandomUserAgent;
	ValueListenable<double?> _videoLoadingProgress = ValueNotifier(null);
	final _lock = Mutex();
	bool _hideVideoPlayerController = false;
	List<RecognizedTextBlock> _textBlocks = [];
	bool _soundSourceFailed = false;
	final _playerErrorStream = StreamController<String>.broadcast();
	({
		ValueNotifier<int> currentBytes,
		int totalBytes,
		Uri uri
	})? _soundSourceDownload;

	// Public API
	/// Whether loading of the full quality attachment has begun
	bool get isFullResolution => _isFullResolution || overrideSource != null;
	/// Error that occured while loading the full quality attachment
	String? get errorMessage => _errorMessage;
	/// Whether the loading spinner should be displayed
	ValueListenable<bool> get showLoadingProgress => _showLoadingProgress;
	/// Conversion process of a video attachment
	ValueListenable<double?> get videoLoadingProgress => _videoLoadingProgress;
	/// A VideoPlayerController to enable playing back video attachments
	VideoController? get videoPlayerController => _hideVideoPlayerController ? null : _videoPlayerController;
	/// Whether the attachment is a video that has an audio track
	bool get hasAudio => _hasAudio;
	/// The Uri to use to load the image, if needed
	Uri? get goodImageSource => _goodImageSource;
	/// Whether the attachment has been cached locally
	bool get cacheCompleted => _cachedFile != null;
	/// Whether this attachment is currently the primary one being displayed to the user
	bool get isPrimary => _isPrimary;
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
	/// Whether the image has already been downloaded
	bool get isDownloaded => _isDownloaded;
	/// Key to use for loading spinner
	final loadingSpinnerKey = GlobalKey(debugLabel: 'AttachmentViewerController.loadingSpinnerKey');
	/// Blocks of text to draw on top of image
	List<RecognizedTextBlock> get textBlocks => _textBlocks;

	Thread? get thread {
		final threadId = attachment.threadId;
		if (threadId == null) {
			return null;
		}
		final threadIdentifier = ThreadIdentifier(attachment.board, threadId);
		return imageboard.persistence.getThreadStateIfExists(threadIdentifier)?.thread ?? imageboard.site.getThreadFromCatalogCache(threadIdentifier);
	}

	bool get _isReallyImage {
		return (attachment.type == AttachmentType.image) &&
		       (attachment.soundSource == null || _soundSourceFailed);
	}


	AttachmentViewerController({
		required this.context,
		required this.attachment,
		this.redrawGestureListenable,
		required this.imageboard,
		this.overrideSource,
		Uri? initialGoodSource,
		this.onDownloaded,
		bool isPrimary = false,
		bool isDownloaded = false,
	}) : _isPrimary = isPrimary, _isDownloaded = isDownloaded {
		_longPressFactor.addListener(_onCoalescedLongPressUpdate);
		// optimistic
		_goodImageSource = initialGoodSource;
		_isFullResolution = initialGoodSource != null;
		if (attachment.type == AttachmentType.image && attachment.soundSource == null) {
			getCachedImageFile(attachment.url.toString()).then((file) {
				if (file != null && _cachedFile == null && !_isDisposed) {
					_goodImageSource = Uri.parse(attachment.url);
					_isFullResolution = true;
					_onCacheCompleted(file);
				}
			});
		}
	}

	Future<VideoController> _ensureController() async {
		final existing = _videoPlayerController;
		if (existing != null) {
			return existing;
		}
		_videoControllers.add(this);
		if (_videoControllers.length > _maxVideoControllers) {
			AttachmentViewerController removed = _videoControllers.removeAt(0);
			if (removed.isPrimary) {
				// Unlucky order, should be able to fix it by cycling
				_videoControllers.add(removed);
				removed = _videoControllers.removeAt(0);
			}
			if (!removed._isDisposed && removed != this) {
				await removed._goToThumbnail();
			}
		}
		final player = Player();
		final controller = VideoController(player, configuration: Platform.isIOS ? VideoControllerConfiguration(
			// Try to avoid bad size-getting thread lock in VideoOutput.swift
			width: attachment.width,
			height: attachment.height
		) : const VideoControllerConfiguration());
		controller.player.stream.error.listen(_onPlayerError);
		controller.player.stream.log.listen(_onPlayerLog);
		controller.player.stream.videoParams.listen(_onPlayerVideoParams);
		final platformPlayer = player.platform;
		if (platformPlayer is NativePlayer) {
			for (final option in Settings.instance.mpvOptions.entries) {
				await platformPlayer.setProperty(option.key, option.value);
			}
		}
		_videoPlayerController = controller;
		return controller;
	}

	void _onPlayerError(String error) {
		if (_isDisposed) {
			return;
		}
		_playerErrorStream.add(error);
	}

	void _onPlayerLog(PlayerLog log) {
		print('$log [${attachment.filename}]');
	}

	void _onPlayerVideoParams(VideoParams params) async {
		final dw = params.dw ?? 0;
		final dh = params.dh ?? 0;
		if (dw == 0 || dh == 0) {
			// Not valid
			return;
		}
		try {
			attachment.width ??= dw;
			attachment.height ??= dh;
			await _videoPlayerController?.setSize(height: dh, width: dw);
		}
		on UnsupportedError {
			// Not supported on all platforms
		}
	}

	set isPrimary(bool val) {
		if (isPrimary == val) {
			return;
		}
		if (val && _videoControllers.remove(this)) {
			// Bump to bottom of stack
			_videoControllers.add(this);
		}
		_lock.protect(() async {
			if (val) {
				await videoPlayerController?.player.play();
			}
			else {
				await videoPlayerController?.player.pause();
			}
		});
		_isPrimary = val;
		notifyListeners();
	}

	Map<String, String> getHeaders(Uri url) {
		return {
			...site.getHeaders(url),
			if (_useRandomUserAgent ?? attachment.useRandomUseragent) 'user-agent': makeRandomUserAgent()
		};
	}

	Future<Uri> _getGoodSource({required RequestPriority priority}) async {
		if (overrideSource != null) {
			return overrideSource!;
		}
		final alreadyCached = await AttachmentCache.optimisticallyFindFile(attachment);
		if (alreadyCached != null) {
			return alreadyCached.uri;
		}
		final attachmentUrl = Uri.parse(attachment.url);
		Response result = await site.client.requestUri(attachmentUrl, options: Options(
			method: attachmentUrl.path.endsWith('.m3u8') ? 'GET' : 'HEAD',
			validateStatus: (_) => true,
			headers: getHeaders(attachmentUrl),
			extra: {
				kPriority: priority
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
					kPriority: priority
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
						kPriority: priority
					}
				));
				if (check.statusCode != 200) {
					throw AttachmentNotArchivedException(attachment);
				}
			}, priority: priority);
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
		_showLoadingProgress.value = false;
	}

	Future<void> _goToThumbnail() async {
		_isFullResolution = false;
		_showLoadingProgress.value = false;
		final controller = videoPlayerController;
		_videoPlayerController = null;
		_goodImageSource = null;
		notifyListeners();
		await controller?.player.dispose();
	}

	Future<void> _loadFullAttachment(bool background, {bool force = false}) => _lock.protect(() async {
		if (_isDisposed) {
			return;
		}
		if (attachment.type == AttachmentType.image && goodImageSource != null && !force) {
			final file = await getCachedImageFile(goodImageSource.toString());
			if (file != null && _cachedFile?.path != file.path) {
				_onCacheCompleted(file);
			}
			return;
		}
		if (attachment.type.isVideo && ((videoPlayerController != null && !force) || _ongoingConversion != null)) {
			return;
		}
		final settings = Settings.instance;
		_errorMessage = null;
		_goodImageSource = null;
		_videoPlayerController?.player.dispose();
		_videoPlayerController = null;
		_hideVideoPlayerController = true;
		_cachedFile = null;
		_isFullResolution = true;
		_showLoadingProgress.value = false;
		_loadingProgressHideScheduled = false;
		notifyListeners();
		Future.delayed(_estimateUrlTime(Uri.parse(attachment.thumbnailUrl), attachment.type), () {
			if (_loadingProgressHideScheduled || _isDisposed) return;
			_showLoadingProgress.value = true;
		});
		try {
			Uri? soundSource = attachment.soundSource;
			if (soundSource != null) {
				try {
					final currentBytes = ValueNotifier<int>(0);
					final soundFile = await VideoServer.instance.cachingDownload(
						uri: soundSource,
						interruptible: true,
						force: force,
						onProgressChanged: (current, total) {
							currentBytes.value = current;
							if (_soundSourceDownload == null && !_isDisposed) {
								_soundSourceDownload = (
									currentBytes: currentBytes,
									totalBytes: total,
									uri: soundSource!
								);
								notifyListeners();
							}
						}
					);
					if (_isDisposed) return;
					await MediaScan.scan(soundFile.uri); // Validate file
					soundSource = soundFile.uri;
				}
				catch (e) {
					if (context.mounted) {
						showToast(
							context: context,
							message: 'Soundpost not working: ${e.toStringDio()}',
							icon: CupertinoIcons.volume_off
						);
					}
					_soundSourceFailed = true;
					soundSource = null;
				}
				finally {
					_soundSourceDownload?.currentBytes.dispose();
					_soundSourceDownload = null;
					if (!_isDisposed) {
						notifyListeners();
					}
				}
			}
			final startTime = DateTime.now();
			if (soundSource == null && (attachment.type == AttachmentType.image || attachment.type == AttachmentType.pdf)) {
				_goodImageSource = await _getGoodSource(priority: background ? RequestPriority.functional : RequestPriority.interactive);
				_recordUrlTime(_goodImageSource!, attachment.type, DateTime.now().difference(startTime));
				if (_goodImageSource?.scheme == 'file') {
					_onCacheCompleted(File(_goodImageSource!.toFilePath()));
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
						_onCacheCompleted(file);
					}
				}
			}
			else if (soundSource != null || attachment.type == AttachmentType.webm || attachment.type == AttachmentType.mp4 || attachment.type == AttachmentType.mp3) {
				final url = await _getGoodSource(priority: background ? RequestPriority.functional : RequestPriority.interactive);
				bool transcode = false;
				if (attachment.type == AttachmentType.webm && url.path.endsWith('.webm')) {
					transcode |= Settings.featureWebmTranscodingForPlayback && settings.webmTranscoding == WebmTranscodingSetting.always;
				}
				transcode |= url.path.endsWith('.m3u8');
				transcode |= soundSource != null;
				if (!transcode) {
					final scan = await MediaScan.scan(url, headers: getHeaders(url));
					if (_isDisposed) {
						return;
					}
					_hasAudio = scan.hasAudio;
					if (scan.codec == 'vp9' && Settings.featureWebmTranscodingForPlayback && settings.webmTranscoding == WebmTranscodingSetting.vp9) {
						transcode = true;
					}
				}
				if (!transcode) {
					if (url.scheme == 'file') {
						final file = File(url.toStringFFMPEG());
						if (isPrimary || !background) {
							await (await _ensureController()).player.open(Media(file.path), play: false);
						}
						_onCacheCompleted(file, notify: false);
					}
					else {
						final progressNotifier = ValueNotifier<double?>(null);
						final hash = await VideoServer.instance.startCachingDownload(
							uri: url,
							headers: getHeaders(url),
							onCached: _onCacheCompleted,
							onProgressChanged: (currentBytes, totalBytes) {
								progressNotifier.value = currentBytes / totalBytes;
							},
							force: force,
							interruptible: attachment.thumbnailUrl.isEmpty
						);
						_conversionDisposers.add(() {
							VideoServer.instance.interruptOngoingDownload(hash);
						});
						if (_isDisposed) return;
						_videoLoadingProgress = progressNotifier;
						notifyListeners();
						if (isPrimary || !background) {
							await (await _ensureController()).player.open(Media(VideoServer.instance.getUri(hash).toString()), play: false);
						}
						else {
							// This is a preload or something, wait for the download to finish
							await VideoServer.instance.getFutureFile(hash);
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
					if (result is StreamingMP4ConvertedFile) {
						if (isPrimary || !background) {
							await (await _ensureController()).player.open(Media(result.mp4File.path), play: false);
						}
						_onCacheCompleted(result.mp4File, notify: false);
					}
					else if (result is StreamingMP4ConversionStream) {
						if (isPrimary || !background) {
							await (await _ensureController()).player.open(Media(result.hlsStream.toString()), play: false);
						}
						_videoLoadingProgress = result.progress;
						result.mp4File.then((mp4File) async {
							if (_isDisposed) {
								return;
							}
							_videoLoadingProgress = ValueNotifier(null);
							_onCacheCompleted(mp4File);
							notifyListeners();
						});
						if (!isPrimary && background) {
							// Wait for full conversion during preload
							await result.mp4File;
						}
					}
					else if (result is StreamingMP4ConvertingFile) {
						_videoLoadingProgress = result.progress;
						notifyListeners();
						final mp4File = await result.mp4File;
						if (_isDisposed) {
							return;
						}
						if (isPrimary || !background) {
							await (await _ensureController()).player.open(Media(mp4File.path), play: false);
						}
						if (_isDisposed) {
							return;
						}
						_videoLoadingProgress = ValueNotifier(null);
						_onCacheCompleted(mp4File);
						notifyListeners();
					}
				}
				if (_isDisposed) return;
				final controller = _videoPlayerController;
				if (controller != null) {
					final firstFrameFuture = controller.waitUntilFirstFrameRendered;
					_hideVideoPlayerController = false;
					if (_isDisposed) return;
					if (settings.muteAudio.value) {
						await controller.player.setVolume(0);
						if (_isDisposed) return;
					}
					await controller.player.setPlaylistMode(PlaylistMode.single);
					if (_isDisposed) return;
					if (isPrimary) {
						if (Platform.isAndroid) {
							// Seems to be necessary to prevent brief freeze near beginning of video
							await Future.delayed(const Duration(milliseconds: 100));
						}
						await controller.player.seek(Duration.zero);
						if (attachment.type.isVideo) {
							final error = await Future.any<String?>([
								firstFrameFuture.then((_) => null),
								_playerErrorStream.stream.firstOrNull.then((error) async {
									if (error != null) {
										// Sometimes MPV sends bogus errors when trying different decoders
										await Future.delayed(const Duration(seconds: 10));
									}
									return error;
								})
							]);
							if (error != null) {
								throw MediaPlayerException(error, controller.player.state.playlist.current);
							}
						}
						else {
							_playerErrorStream.stream.firstOrNull.then((error) async {
								if (error == null) {
									return;
								}
								// Sometimes MPV sends bogus errors when trying different decoders
								await Future.delayed(const Duration(seconds: 10));
								if (controller.player.state.position == Duration.zero && context.mounted) {
									showToast(
										context: context,
										message: error,
										icon: CupertinoIcons.exclamationmark_triangle
									);
								}
							});
						}
						if (_isDisposed) return;
						await controller.player.play();
					}
					if (_isDisposed) return;
					_scheduleHidingOfLoadingProgress();
				}
				_recordUrlTime(url, attachment.type, DateTime.now().difference(startTime));
				notifyListeners();
			}
		}
		catch (e, st) {
			_errorMessage = e.toStringDio();
			print(e);
			print(st);
			Future.error(e, st); // Crashlytics
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

	void _onCacheCompleted(File file, {bool notify = true}) {
		_cachedFile = file;
		attachment.sizeInBytes ??= file.statSync().size;
		AttachmentCache.onCached(attachment);
		if (_isDisposed) return;
		_scheduleHidingOfLoadingProgress();
		if (notify) {
			notifyListeners();
		}
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
		_playingBeforeLongPress = videoPlayerController!.player.state.playing;
		_millisecondsBeforeLongPress = videoPlayerController!.player.state.position.inMilliseconds;
		_currentlyWithinLongPress = true;
		_overlayText = _formatPosition(videoPlayerController!.player.state.position, videoPlayerController!.player.state.duration);
		notifyListeners();
		videoPlayerController!.player.pause();
	}

	void _onLongPressUpdate(double factor) {
		if (_isDisposed) {
			return;
		}
		_longPressFactor.value = factor;
	}

	void _onCoalescedLongPressUpdate() async {
		if (_isDisposed) {
			return;
		}
		final factor = _longPressFactor.value;
		if (_currentlyWithinLongPress) {
			final duration = videoPlayerController!.player.state.duration.inMilliseconds;
			final newPosition = Duration(milliseconds: ((_millisecondsBeforeLongPress + (duration * factor)).clamp(0, duration)).round());
			_overlayText = _formatPosition(newPosition, videoPlayerController!.player.state.duration);
			notifyListeners();
			if (!_seeking) {
				_seeking = true;
				await videoPlayerController!.player.seek(newPosition);
				_seeking = false;
			}
		}
	}

	Future<void> _onLongPressEnd() async {
		if (_playingBeforeLongPress) {
			videoPlayerController!.player.play();
		}
		_currentlyWithinLongPress = false;
		_overlayText = null;
		notifyListeners();
	}

	bool get canShare => (overrideSource ?? _cachedFile) != null;

	File getFile() {
		if (overrideSource?.isScheme('file') ?? false) {
			return File(overrideSource!.toFilePath());
		}
		else if (_cachedFile != null) {
			return _cachedFile!;
		}
		else {
			throw Exception('No file available');
		}
	}

	String get cacheExt {
		final cached = _cachedFile;
		if (cached != null) {
			final basename = cached.path.split('/').last;
			final parts = basename.split('.');
			if (parts.length > 1) {
				return '.${parts.last}';
			}
		}
		return attachment.ext;
	}

	String _downloadExt(bool convertForCompatibility) {
		if ((convertForCompatibility || cacheExt == '.mp4') && attachment.type == AttachmentType.webm) {
			return '.mp4';
		}
		if (attachment.soundSource != null && !_soundSourceFailed) {
			// Whatever the input type, it is combined with sound now
			if (convertForCompatibility) {
				return '.mp4';
			}
			return Platform.isAndroid ? '.webm': '.mp4';
		}
		return attachment.ext;
	}

	String _downloadFilename(bool convertForCompatibility) {
		String filename;
		if (Settings.instance.downloadUsingServerSideFilenames) {
			filename = attachment.id.split('/').last;
		}
		else {
			filename = attachment.filename;
		}
		if (filename.startsWith('.')) {
			// Not able to save hidden files
			filename = ' $filename';
		}
		return filename.replaceFirst(RegExp(r'\.[^.]+$'), '') + _downloadExt(convertForCompatibility);
	}

	Future<File> _moveToShareCache({required bool convertForCompatibility}) async {
		final newFilename = _downloadFilename(convertForCompatibility);
		File file = getFile();
		if (convertForCompatibility && cacheExt == '.webm') {
			file = await modalLoad(context, 'Converting...', (c) async {
				final conversion = MediaConversion.toMp4(file.uri);
				c.onCancel = conversion.cancel;
				return (await conversion.start()).file;
			}, cancellable: true);
		}
		return await file.copy('${Persistence.shareCacheDirectory.path}/$newFilename');
	}

	Future<void> share(Rect? sharePosition) async {
		final bool convertForCompatibility;
		if (cacheExt == '.webm') {
			final choice = await showAdaptiveDialog<bool>(
				barrierDismissible: true,
				context: context,
				builder: (context) => AdaptiveAlertDialog(
					title: const Text('Which format?'),
					content: const Padding(
						padding: EdgeInsets.only(top: 16),
						child: Text('Share the video in its original WEBM form, or convert it to MP4 for compatibility with other apps and services?')
					),
					actions: [
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, false),
							child: const Text('WEBM')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context, true),
							child: const Text('MP4')
						),
						AdaptiveDialogAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					]
				)
			);
			if (!context.mounted || choice == null) {
				return;
			}
			convertForCompatibility = choice;
		}
		else {
			convertForCompatibility = false;
		}
		await shareOne(
			context: context,
			text: (await _moveToShareCache(convertForCompatibility: convertForCompatibility)).path,
			subject: _downloadFilename(convertForCompatibility),
			type: "file",
			sharePositionOrigin: sharePosition
		);
	}

	Future<void> translate() async {
		final rawBlocks = await recognizeText(_cachedFile!);
		final translated = await batchTranslate(rawBlocks.map((r) => r.text).toList(), toLanguage: Settings.instance.translationTargetLanguage);
		_textBlocks = rawBlocks.asMap().entries.map((e) => (
			text: e.key >= translated.length ? 'Nothing for ${e.key} (${translated.length}' : translated[e.key],
			rect: e.value.rect
		)).toList();
		notifyListeners();
	}

	Future<String?> download({bool force = false, bool saveAs = false, String? dir}) async {
		if (_isDownloaded && !force && dir == null) return null;
		final settings = Settings.instance;
		String filename;
		bool successful = false;
		if (Platform.isIOS) {
			final existingAlbums = await PhotoManager.getAssetPathList(type: RequestType.common);
			AssetPathEntity? album;
			final albumName = settings.gallerySavePathOrganizing.albumNameFor(attachment);
			if (albumName != null) {
				album = existingAlbums.tryFirstWhere((album) => album.name == albumName);
				album ??= await PhotoManager.editor.darwin.createAlbum(albumName);
			}
			final convertForCompatibility = !_isReallyImage;
			filename = _downloadFilename(convertForCompatibility);
			final shareCachedFile = await _moveToShareCache(convertForCompatibility: convertForCompatibility);
			final asAsset = _isReallyImage ? 
				await PhotoManager.editor.saveImageWithPath(shareCachedFile.path, title: filename) :
				await PhotoManager.editor.saveVideo(shareCachedFile, title: filename);
			if (asAsset == null) {
				throw Exception('Failed to save to gallery');
			}
			if (album != null) {
				await PhotoManager.editor.copyAssetToPath(asset: asAsset, pathEntity: album);
			}
			_isDownloaded = true;
			successful = true;
		}
		else if (Platform.isAndroid) {
			filename = _downloadFilename(false);
			if (saveAs) {
				final path = await saveFileAs(
					sourcePath: getFile().path,
					destinationName: filename
				);
				successful = path != null;
			}
			else {
				final destination = dir ?? (Settings.androidGallerySavePathSetting.value ??= await pickDirectory());
				if (destination != null) {
					File source = getFile();
					try {
						// saveFile may modify name if there is a collision
						filename = await saveFile(
							sourcePath: source.path,
							destinationDir: destination,
							destinationSubfolders: dir != null ? [] : settings.gallerySavePathOrganizing.subfoldersFor(this),
							destinationName: filename
						);
						_isDownloaded = true;
						successful = true;
					}
					on DirectoryNotFoundException {
						if (dir == null) {
							Settings.androidGallerySavePathSetting.value = null;
						}
						rethrow;
					}
					on InsufficientPermissionException {
						if (dir == null) {
							Settings.androidGallerySavePathSetting.value = null;
						}
						rethrow;
					}
				}
			}
		}
		else {
			throw UnsupportedError("Downloading not supported on this platform");
		}
		onDownloaded?.call();
		notifyListeners();
		return successful ? filename : null;
	}

	Future<void> _seekRelative(double factor) async {
		final controller = _videoPlayerController;
		if (controller == null) {
			return;
		}
		final totalDuration = controller.player.state.duration;
		final seekDuration = (totalDuration * factor).clamp(const Duration(seconds: -5), const Duration(seconds: 5));
		final newPosition = (controller.player.state.position + seekDuration).clamp(Duration.zero, totalDuration);
		await controller.player.seek(newPosition);
		if (_isDisposed) {
			return;
		}
		final overlayText = _overlayText = _formatPosition(newPosition, totalDuration);
		notifyListeners();
		await Future.delayed(const Duration(seconds: 1));
		if (!_isDisposed && _overlayText == overlayText) {
			_overlayText = null;
			notifyListeners();
		}
	}

	Future<void> seekForward() => _seekRelative(0.2);

	Future<void> seekBackward() => _seekRelative(-0.2);

	@override
	void dispose() {
		_isDisposed = true;
		super.dispose();
		for (final disposer in _conversionDisposers) {
			disposer();
		}
		_showLoadingProgress.dispose();
		_videoPlayerController?.player.pause().then((_) => videoPlayerController?.player.dispose());
		_longPressFactor.dispose();
		_videoControllers.remove(this);
		_ongoingConversion?.cancelIfActive();
		_playerErrorStream.close();
		final downloadingSoundUri = _soundSourceDownload?.uri;
		if (downloadingSoundUri != null) {
			VideoServer.instance.interruptOngoingDownloadFromUri(downloadingSoundUri);
		}
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
	final List<ContextMenuAction> additionalContextMenuActions;
	final double? maxWidth;
	final BoxFit fit;
	final bool autoRotate;

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
		this.autoRotate = false,
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
			else if (attachment.type == AttachmentType.image && attachment.soundSource == null) {
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

	bool _rotate90DegreesClockwise(BuildContext context) {
		if (!autoRotate || attachment.type == AttachmentType.url || attachment.type == AttachmentType.pdf) {
			return false;
		}
		final displayIsLandscape = MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
		return attachment.aspectRatio != 1 && displayIsLandscape != (attachment.aspectRatio > 1);
	}

	Widget _buildImage(BuildContext context, Size? size, bool passedFirstBuild) {
		Uri source = controller.overrideSource ?? Uri.parse(attachment.thumbnailUrl);
		final goodSource = controller.goodImageSource;
		if (goodSource != null && ((!goodSource.path.endsWith('.gif') || passedFirstBuild) || source.toString().length < 6)) {
			source = goodSource;
		}
		if (source.toString().isEmpty) {
			return const Center(
				child: CircularProgressIndicator.adaptive()
			);
		}
		ImageProvider image = ExtendedNetworkImageProvider(
			source.toString(),
			cache: true,
			headers: controller.getHeaders(source)
		);
		if (source.scheme == 'file') {
			image = ExtendedFileImageProvider(
				File(source.toStringFFMPEG()),
				imageCacheName: attachment.id
			);
		}
		if (maxWidth != null) {
			image = ExtendedResizeImage(
				image,
				maxBytes: 800 << 10,
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
		buildChild({required bool inContextMenu}) => AbsorbPointer(
			absorbing: !allowGestures,
			child: ExtendedImage(
				image: image,
				extendedImageGestureKey: inContextMenu ? null : controller.gestureKey,
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
				layoutInsets: inContextMenu ? EdgeInsets.zero : layoutInsets,
				afterPaintImage: (
					key: controller.textBlocks.toString(),
					fn: (canvas, rect, image, paint) {
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
					}
				),
				rotate90DegreesClockwise: _rotate90DegreesClockwise(context),
				loadStateChanged: (loadstate) {
					// We can't rely on loadstate.extendedImageLoadState because of using gaplessPlayback
					if (!controller.cacheCompleted || controller.showLoadingProgress.value) {
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
										controller._onCacheCompleted(file);
									}
								});
							}
						}
						else if ((loadstate.extendedImageInfo?.image.width ?? 0) >= (attachment.width ?? 1) && (source != Uri.parse(attachment.thumbnailUrl))) {
							// If the displayed image looks like the full image, we can check cache
							getCachedImageFile(source.toString()).then((file) {
								if (file != null) {
									controller._onCacheCompleted(file);
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
							else if (controller.gestureKey.currentState?.extendedImageSlidePageState?.popping != true && (controller.showLoadingProgress.value || !controller.isFullResolution)) {
								child = _centeredLoader(
									active: controller.isFullResolution,
									value: loadingValue,
									useRealKey: !inContextMenu
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
				final scaleBefore = state.gestureDetails!.totalScale!;
				final offsetBefore = state.gestureDetails!.offset!;
				final logicalAnchor = controller._doubleTapDragAnchor ??= ((details.localPosition - offsetBefore) / scaleBefore);
				final anchorBefore = (logicalAnchor * scaleBefore) + offsetBefore;
				final scaleAfter = (state.gestureDetails!.totalScale! * (1 + (0.005 * details.localDelta.dy))).clamp(1.0, 5.0);
				final offsetAfter = anchorBefore - (logicalAnchor * scaleAfter);
				state.gestureDetails = GestureDetails(
					offset: offsetAfter,
					totalScale: scaleAfter,
					actionType: ActionType.zoom
				);
			},
			onDoubleTapDragEnd: (details) {
				if (details.localOffsetFromOrigin.distance < 1) {
					onDoubleTap(controller.gestureKey.currentState!);
				}
				controller._doubleTapDragAnchor = null;
			},
			child: !allowContextMenu ? buildChild(inContextMenu: false) : ContextMenu(
				actions: [
					ContextMenuAction(
						trailingIcon: CupertinoIcons.cloud_download,
						onPressed: () async {
							final download = !controller.isDownloaded || (await confirm(context, 'Redownload?'));
							if (!download) return;
							final filename = await controller.download(force: true);
							if (filename != null && context.mounted) {
								showToast(context: context, message: 'Downloaded $filename', icon: CupertinoIcons.cloud_download);
							}
						},
						child: const Text('Download')
					),
					if (isSaveFileAsSupported) ContextMenuAction(
						trailingIcon: Icons.folder,
						onPressed: () async {
							final filename = await controller.download(force: true, saveAs: true);
							if (filename != null && context.mounted) {
								showToast(context: context, message: 'Downloaded $filename', icon: Icons.folder);
							}
						},
						child: const Text('Download to...')
					),
					ContextMenuAction(
						trailingIcon: Adaptive.icons.share,
						onPressed: () async {
							final offset = (controller.contextMenuShareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
							final size = controller.contextMenuShareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
							await controller.share((offset != null && size != null) ? offset & size : null);
						},
						key: controller.contextMenuShareButtonKey,
						child: const Text('Share')
					),
					ContextMenuAction(
						child: const Text('Copy link'),
						trailingIcon: CupertinoIcons.link,
						onPressed: () async {
							final text = controller.goodImageSource?.toString() ?? controller.attachment.url;
							Clipboard.setData(ClipboardData(
								text: text
							));
							showToast(
								context: context,
								message: 'Copied "$text" to clipboard',
								icon: CupertinoIcons.doc_on_clipboard
							);
						}
					),
					if (isTextRecognitionSupported) ContextMenuAction(
						trailingIcon: Icons.translate,
						onPressed: () async {
							try {
								await modalLoad(context, 'Translating...', (c) => controller.translate().timeout(const Duration(seconds: 10)));
							}
							catch (e) {
								if (context.mounted) {
									alertError(context, e.toStringDio());
								}
							}
						},
						child: const Text('Translate')
					),
					...buildImageSearchActions(context, () async => attachment).map((a) => ContextMenuAction(
						isDestructiveAction: a.isDestructiveAction,
						onPressed: a.onPressed,
						trailingIcon: a.trailingIcon,
						child: a.child,
					)),
					if (context.select<Settings, bool>((p) => p.isMD5Hidden(attachment.md5))) ContextMenuAction(
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							Settings.instance.unHideByMD5s([attachment.md5]);
							Settings.instance.didEdit();
						},
						child: const Text('Unhide by image')
					)
					else ContextMenuAction(
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () async {
							Settings.instance.hideByMD5(attachment.md5);
							Settings.instance.didEdit();
						},
						child: const Text('Hide by image')
					),
					...additionalContextMenuActions
				],
				child: buildChild(inContextMenu: false),
				trimStartRect: (rect) {
					// Remove the layoutInsets
					final laidOut = layoutInsets.deflateRect(rect);
					// Clip to aspectRatio
					final size = RenderAspectRatio(aspectRatio: attachment.aspectRatio).getDryLayout(BoxConstraints.loose(laidOut.size));
					return Rect.fromCenter(
						center: laidOut.center,
						width: size.width,
						height: size.height
					);
				},
				previewBuilder: (context, child) => AspectRatio(
					aspectRatio: attachment.aspectRatio,
					child: buildChild(inContextMenu: true)
				)
			)
		);
	}

	double get aspectRatio {
		final videoPlayerAspectRatio = controller.videoPlayerController?.player.state.aspectRatio;
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
		final rotate90DegreesClockwise = _rotate90DegreesClockwise(context);
		final soundSourceDownload = controller._soundSourceDownload;
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
					onLongPressMoveUpdate: (details) {
						final double factor;
						if (rotate90DegreesClockwise) {
							factor = details.offsetFromOrigin.dy / (MediaQuery.sizeOf(context).height / 2);
						}
						else {
							factor = details.offsetFromOrigin.dx / (MediaQuery.sizeOf(context).width / 2);
						}
						controller._onLongPressUpdate(factor);
					},
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
											rotate90DegreesClockwise: rotate90DegreesClockwise,
											gaplessPlayback: true,
											revealSpoilers: true,
											site: controller.site,
											mayObscure: false
										)
									)
								)
							),
							if (attachment.type == AttachmentType.mp3) Positioned.fill(
								child: Center(
									child: RotatedBox(
										quarterTurns: rotate90DegreesClockwise ? 1 : 0,
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
										quarterTurns: rotate90DegreesClockwise ? 1 : 0,
										child: AspectRatio(
											aspectRatio: aspectRatio,
											child: Video(
												controller: controller.videoPlayerController!,
												fill: Colors.transparent,
												controls: null
											)
										)
									)
								)
							),
							if (controller.videoPlayerController != null && allowGestures) Positioned.fill(
								child: Flex(
									direction: rotate90DegreesClockwise ? Axis.vertical : Axis.horizontal,
									children: [
										Expanded(
											child: GestureDetector(
												onDoubleTap: controller.seekBackward
											)
										),
										Expanded(
											child: GestureDetector(
												onDoubleTap: controller.seekForward
											)
										)
									],
								)
							),
							ValueListenableBuilder(
								valueListenable: controller.showLoadingProgress,
								builder: (context, showLoadingProgress, _) => (showLoadingProgress && controller._soundSourceDownload == null) ? ValueListenableBuilder(
									valueListenable: controller.videoLoadingProgress,
									builder: (context, double? loadingProgress, child) => _centeredLoader(
										active: controller.isFullResolution,
										value: loadingProgress,
										useRealKey: true
									)
								) : const SizedBox.shrink()
							),
							if (soundSourceDownload != null) Positioned.fill(
								child: Center(
									child: RotatedBox(
										quarterTurns: rotate90DegreesClockwise ? 1 : 0,
										child: Container(
											margin: const EdgeInsets.all(16),
											padding: const EdgeInsets.all(24),
											decoration: const BoxDecoration(
												color: Colors.black87,
												borderRadius: BorderRadius.all(Radius.circular(10))
											),
											child: IntrinsicWidth(
												child: Column(
													mainAxisSize: MainAxisSize.min,
													children: [
														const SizedBox(height: 10),
														const Row(
															mainAxisSize: MainAxisSize.min,
															children: [
																Icon(CupertinoIcons.waveform, size: 32, color: Colors.white),
																SizedBox(width: 8),
																Text(
																	'Downloading sound',
																	style: TextStyle(
																		fontSize: 32,
																		color: Colors.white
																	)
																)
															]
														),
														Text('from ${soundSourceDownload.uri.host}', style: const TextStyle(
															fontSize: 24
														)),
														const SizedBox(height: 16),
														ValueListenableBuilder(
															valueListenable: soundSourceDownload.currentBytes,
															builder: (context, currentBytes, _) => SizedBox(
																width: 350,
																child: Column(
																	mainAxisSize: MainAxisSize.min,
																	children: [
																		LinearProgressIndicator(
																			value: currentBytes / soundSourceDownload.totalBytes,
																			backgroundColor: ChanceTheme.primaryColorWithBrightness20Of(context)
																		),
																		const SizedBox(height: 16),
																		Row(
																			mainAxisSize: MainAxisSize.min,
																			crossAxisAlignment: CrossAxisAlignment.start,
																			children: [
																				AdaptiveFilledButton(
																					onPressed: () => VideoServer.instance.interruptOngoingDownloadFromUri(soundSourceDownload.uri),
																					child: const Text('Cancel')
																				),
																				const Spacer(),
																				Text('${formatFilesize(currentBytes)} / ${formatFilesize(soundSourceDownload.totalBytes)}')
																			]
																		)
																	]
																)
															)
														),
														const SizedBox(height: 10)
													]
												)
											)
										)
									)
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
										quarterTurns: rotate90DegreesClockwise ? 1 : 0,
										child: Container(
											padding: const EdgeInsets.all(8),
											margin: const EdgeInsets.only(
												top: 12,
												bottom: 12
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
															style: const TextStyle(
																fontSize: 32,
																color: Colors.white
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
							rotate90DegreesClockwise: _rotate90DegreesClockwise(context),
							gaplessPlayback: true,
							revealSpoilers: true,
							site: controller.site,
							mayObscure: false
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
							targetSize = applyBoxFit(BoxFit.scaleDown, Size(attachment.width!.toDouble(), attachment.height!.toDouble()), layoutInsets.deflateSize(constraints.biggest)).destination;
						}
						if (attachment.type == AttachmentType.image && (attachment.soundSource == null || controller._soundSourceFailed)) {
							return _buildImage(context, targetSize, passedFirstBuild);
						}
						else if (attachment.type == AttachmentType.pdf) {
							return Padding(
								padding: layoutInsets,
								child: _buildPdf(context, targetSize)
							);
						}
						else if (attachment.type == AttachmentType.url) {
							return _buildBrowser(context, targetSize);
						}
						else {
							return Padding(
								padding: layoutInsets,
								child: _buildVideo(context, targetSize)
							);
						}
					}
				);
			}
		);
	}
}