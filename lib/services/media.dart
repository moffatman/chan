import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';
import 'package:chan/services/html_error.dart';
import 'package:chan/services/md5.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http_parser/http_parser.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mutex/mutex.dart';
import 'package:pool/pool.dart';

part 'media.g.dart';

extension HandleSpacesInPath on Uri {
	String toStringFFMPEG() {
		if (scheme == 'file') {
			return Uri.decodeFull(path);
		}
		return toString();
	}
}

class MediaScanException extends ExtendedException {
	final Uri path;
	final int code;
	final String output;
	const MediaScanException(this.path, this.code, this.output, {super.additionalFiles});
	@override
	bool get isReportable => true;

	@override
	String toString() => 'MediaScanException(path: $path, code: $code, output: $output)';
}

class MediaConversionFFMpegException implements Exception {
	final int exitCode;
	final String output;
	const MediaConversionFFMpegException(this.exitCode, this.output);

	@override
	String toString() => 'MediaConversionFFMpegException(exitCode: $exitCode, output: $output)';
}

class MediaConversionCancelledException implements Exception {
	const MediaConversionCancelledException();

	@override
	String toString() => 'MediaConversionCancelledException()';
}

class MediaConversionResult {
	final File file;
	final bool hasAudio;
	final bool isAudioOnly;
	MediaConversionResult(this.file, this.hasAudio, this.isAudioOnly);
	@override
	String toString() => 'MediaConversionResult(file: ${file.path}, hasAudio: $hasAudio, isAudioOnly: $isAudioOnly)';
}

@HiveType(typeId: 38)
class MediaScan {
	static final Map<String, MediaScan> _fileScans = {};
	static final Map<Uri, MediaScan> _webScans = {};
	@HiveField(0)
	final bool hasAudio;
	@HiveField(1)
	final Duration? duration;
	@HiveField(2)
	final int? bitrate;
	@HiveField(3)
	final int? width;
	@HiveField(4)
	final int? height;
	@HiveField(5)
	final String? codec;
	@HiveField(6)
	final double? videoFramerate;
	@HiveField(7)
	final int? sizeInBytes;
	@HiveField(8, defaultValue: null, merger: MapEqualsMerger())
	final Map? metadata;
	static const kMetadataFieldRotation = '_rotation';
	@HiveField(9, defaultValue: null)
	final String? format;
	@HiveField(10, defaultValue: null)
	final String? pixFmt;
	@HiveField(11, defaultValue: null)
	final int? videoBitrate;
	@HiveField(12, defaultValue: null)
	final int? audioBitrate;

	MediaScan({
		required this.hasAudio,
		required this.duration,
		required this.bitrate,
		required this.width,
		required this.height,
		required this.codec,
		required this.videoFramerate,
		required this.sizeInBytes,
		required this.metadata,
		required this.format,
		required this.pixFmt,
		required this.videoBitrate,
		required this.audioBitrate
	});

	static final _ffprobeLock = Mutex();
	static LazyBox<MediaScan>? _mediaScanBox;
	static final _boxLock = Mutex();

	static Future<MediaScan> _scan(Uri file, {
		Map<String, String> headers = const {},
		int tries = 0,
		bool force = false
	}) async {
		try {
			if (_webScans[file] case MediaScan scan when !force) {
				return scan;
			}
			return await _ffprobeLock.protect<MediaScan>(() async {
				// May be two simultaneous scans, so recheck after getting the lock
				if (_webScans[file] case MediaScan scan when !force) {
					return scan;
				}
				final result = await FFTools.ffprobe(
					arguments: [
						"-v",
						"error",
						"-hide_banner",
						"-print_format",
						"json",
						"-show_format",
						"-show_streams",
						"-show_chapters",
						if (headers.isNotEmpty) ...[
							"-headers",
							headers.entries.map((h) => "${h.key}: ${h.value}").join('\r\n')
						],
						"-i",
						file.toStringFFMPEG(),
					],
					logLevel: 8 // AV_LOG_FATAL
				);
				if (result.returnCode != 0) {
					final files = <String, Uint8List>{};
					if (result.returnCode == 1 && file.isScheme('file')) {
						final stat = await File(file.path).stat();
						if (stat.size == 0) {
							throw MediaScanException(file, 1, 'File is empty');
						}
						if (stat.size < 50e3) {
							// Try to get a message out of it. Maybe it's HTML or something
							try {
								final string = await File(file.path).readAsString();
								if (extractHtmlError(string) case String error) {
									throw MediaScanException(file, 1, error);
								}
								else if (string.length < 100) {
									throw MediaScanException(file, 1, string);
								}
							}
							catch (e) {
								if (e is MediaScanException) {
									rethrow;
								}
								// Else do nothing, this is sketchy code
							}
						}
						if (stat.size < 5e6 /* 5 MB */) {
							try {
								files[file.pathSegments.last] = await File(file.path).readAsBytes();
							}
							catch (e, st) {
								// The file may not be accessible. just give up.
								Future.error(e, st);
							}
						}
					}
					throw MediaScanException(
						file,
						result.returnCode,
						// Below regexes are to cleanup some JSON junk in the output, trimming all leading and trailing non-word characters
						result.output.replaceFirst(RegExp(r'^[^\w]*'), '').replaceFirst(RegExp(r'[^\w]*$'), ''),
						additionalFiles: files
					);
				}
				if (result.output.isEmpty) {
					throw MediaScanException(file, 0, 'No output from ffprobe');
				}
				final data = jsonDecode(result.output) as Map;
				final format = data['format'] as Map? ?? {};
				final seconds = (format['duration'] as String?)?.tryParseDouble;
				int width = 0;
				int height = 0;
				double? videoFramerate;
				Map? metadata = format['tags'] as Map?;
				final streams = (data['streams'] as List).cast<Map>();
				Map? videoStream;
				Map? audioStream;
				for (final stream in streams) {
					width = max(width, stream['width'] as int? ?? 0);
					height = max(height, stream['height'] as int? ?? 0);
					if (stream['codec_type'] == 'video') {
						videoStream ??= stream;
						final avgFramerateFractionString = stream['avg_frame_rate'] as String?;
						final match = RegExp(r'^(\d+)\/(\d+)$').firstMatch(avgFramerateFractionString ?? '');
						if (match != null) {
							videoFramerate = match.group(1)!.parseInt / match.group(2)!.parseInt;
						}
						if (stream case {'side_data_list': [{'rotation': num rotation}, ...]}) {
							(metadata ??= {})[kMetadataFieldRotation] = rotation.toDouble();
						}
					}
					else if (stream['codec_type'] == 'audio') {
						audioStream ??= stream;
					}
				}
				final scan = MediaScan(
					hasAudio: audioStream != null,
					duration: seconds == null ? null : Duration(milliseconds: (1000 * seconds).round()),
					bitrate: (format['bit_rate'] as String?)?.tryParseInt,
					videoBitrate: (videoStream?['bit_rate'] as String?)?.tryParseInt,
					audioBitrate: (audioStream?['bit_rate'] as String?)?.tryParseInt,
					width: width == 0 ? null : width,
					height: height == 0 ? null : height,
					codec: videoStream?['codec_name'] as String?,
					videoFramerate: videoFramerate,
					pixFmt: videoStream?['pix_fmt'] as String?,
					sizeInBytes: (format['size'] as String?)?.tryParseInt,
					metadata: metadata,
					format: format['format_name'] as String?
				);
				if (file.scheme != 'file') {
					_webScans[file] = scan;
				}
				return scan;
			});
		}
		on FormatException {
			if (tries < 3) {
				return _scan(file, headers: headers, tries: tries + 1, force: force);
			}
			else {
				rethrow;
			}
		}
	}

	static Future<void> _closeBox() async {
		await _boxLock.protect(() async {
			final box = _mediaScanBox;
			_mediaScanBox = null;
			await box?.close();
		});
	}

	static String _makeKey(String path) {
		if (path.length <= 255) {
			return path;
		}
		return base64.encode(md5.convert(utf8.encode(path)).bytes);
	}

	static MediaScan? peekCachedFileScan(String path) {
		final result = _fileScans[_makeKey(path)];
		if (result == null) {
			return null;
		}
		final size = File(path).statSync().size;
		if (size != result.sizeInBytes) {
			return null;
		}
		return result;
	}

	static Future<MediaScan> scan(Uri file, {
		Map<String, String> headers = const {},
		bool force = false
	}) async {
		if (file.scheme == 'file') {
			final peeked = peekCachedFileScan(file.path);
			if (!force && peeked != null) {
				return peeked;
			}
			// Not cached or file size doesn't match
			return _boxLock.protect(() async {
				runWhenIdle(const Duration(seconds: 1), _closeBox);
				final mediaScanBox = _mediaScanBox ??= await Hive.openLazyBox<MediaScan>('mediaScans');
				final scan = await _scan(file, force: force);
				final key = _makeKey(file.path);
				_fileScans[key] = scan;
				await mediaScanBox.put(key, scan);
				return scan;
			});
		}
		else {
			return _scan(file, headers: headers, force: force);
		}
	}

	static MediaType guessMimeTypeFromPath(String path) {
		if (path.endsWith(".png")) {
			return MediaType('image', 'png');
		}
		else if (path.endsWith(".jpg") || path.endsWith(".jpeg")) {
			return MediaType('image', 'jpeg');
		}
		else if (path.endsWith(".gif")) {
			return MediaType('image', 'gif');
		}
		else if (path.endsWith(".mp4")) {
			return MediaType('video', 'mp4');
		}
		else if (path.endsWith(".webm")) {
			return MediaType('video', 'webm');
		}
		else if (path.endsWith(".mp3")) {
			return MediaType('audio', 'mp3');
		}
		// No idea
		return MediaType('application', 'x-octet-stream');
	}

	static Future<void> initializeStatic() async {
		try {
			// Fill up _fileScans from disk
			await _boxLock.protect(() async {
				runWhenIdle(const Duration(seconds: 1), _closeBox);
				final mediaScanBox = _mediaScanBox ??= await Hive.openLazyBox<MediaScan>('mediaScans');
				for (final key in mediaScanBox.keys) {
					if (key is! String) {
						continue;
					}
					final value = await mediaScanBox.get(key);
					if (value != null) {
						_fileScans[key] = value;
					}
				}
			});
		}
		catch (e, st) {
			// Must be a corrupt box, delete it
			_boxLock.protect(() async {
				_mediaScanBox = null;
				await Hive.deleteBoxFromDisk('mediaScans');
			});
			// Don't block app startup
			Future.error(e, st); // crashlytics
		}
	}

	bool get isAudioOnly => videoFramerate?.isNaN ?? true;
	bool get hasVideo {
		final framerate = videoFramerate;
		if (framerate == null || framerate.isNaN) {
			return false;
		}
		final microseconds = duration?.inMicroseconds;
		if (microseconds == null) {
			return false;
		}
		final frames = (microseconds * framerate) / Duration.microsecondsPerSecond;
		return frames.round() > 1;
	}

	static const _kUnremoveableMetadataFields = {
		'major_brand',
		'minor_version',
		'compatible_brands',
		'encoder'
	};
	bool get hasMetadata {
		final map = metadata;
		return map != null &&
		       map.keys.any((k) => k is! String || !_kUnremoveableMetadataFields.contains(k.toLowerCase()));
	}

	@override
	String toString() => 'MediaScan(hasAudio: $hasAudio, duration: $duration, bitrate: $bitrate, width: $width, height: $height, codec: $codec, videoFramerate: $videoFramerate, sizeInBytes: $sizeInBytes, metadata: $metadata, format: $format, pixFmt: $pixFmt, videoBitrate: $videoBitrate, audioBitrate: $audioBitrate)';
}

class MediaConversion {
	final progress = ValueNotifier<double?>(null);
	bool _disposedProgress = false;
	final Uri inputFile;
	String outputFileExtension;
	List<String> extraOptions;
	int? maximumSizeInBytes;
	double? maximumDurationInSeconds;
	bool stripAudio;
	int? maximumDimension;
	final String cacheKey;
	final Map<String, String> headers;
	({int attempts, double factor}) _scaleDownRetry = (attempts: 0, factor: 1);
	int _randomizeChecksumNoiseFactor = 1;
	int _durationArgumentFactor = 1;
	final Uri? soundSource;
	final bool requiresSubdirectory;
	bool copyStreams;
	final bool removeMetadata;
	final bool randomizeChecksum;
	bool requireAudio;
	int? targetBitrate;

	CancelableOperation<FFToolsOutput>? _session;
	MediaScan? cachedScan;

	static final pool = Pool(2);

	MediaConversion({
		required this.inputFile,
		required this.outputFileExtension,
		this.maximumSizeInBytes,
		this.maximumDurationInSeconds,
		this.maximumDimension,
		this.stripAudio = false,
		this.extraOptions = const [],
		this.cacheKey = '',
		this.headers = const {},
		this.soundSource,
		this.requiresSubdirectory = false,
		this.copyStreams = false,
		this.removeMetadata = false,
		this.randomizeChecksum = false,
		this.requireAudio = false,
		this.targetBitrate
	}) : assert(!(targetBitrate == 0 && maximumSizeInBytes != null), 'maximumSizeInBytes requires bitrate targeting');

	static MediaConversion toMp4(Uri inputFile, {
		Map<String, String> headers = const {},
		Uri? soundSource,
		bool copyStreams = false,
		bool stripAudio = false,
		int? maximumSizeInBytes,
		double? maximumDurationInSeconds,
		int? maximumDimension,
		bool removeMetadata = false,
		bool randomizeChecksum = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'mp4',
			headers: headers,
			soundSource: soundSource,
			stripAudio: stripAudio,
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDurationInSeconds: maximumDurationInSeconds,
			maximumDimension: maximumDimension,
			removeMetadata: removeMetadata,
			randomizeChecksum: randomizeChecksum,
			copyStreams: copyStreams || inputFile.path.endsWith('.m3u8')
		);
	}

	static MediaConversion toHLS(Uri inputFile, {
		Map<String, String> headers = const {},
		Uri? soundSource,
		required bool copyStreams
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'm3u8',
			headers: headers,
			soundSource: soundSource,
			requiresSubdirectory: true,
			copyStreams: copyStreams
		);
	}

	static MediaConversion toWebm(Uri inputFile, {
		int? maximumSizeInBytes,
		double? maximumDurationInSeconds,
		required bool stripAudio,
		int? maximumDimension,
		Map<String, String> headers = const {},
		Uri? soundSource,
		bool removeMetadata = false,
		bool randomizeChecksum = false,
		bool copyStreams = false,
		int? targetBitrate
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'webm',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDurationInSeconds: maximumDurationInSeconds,
			maximumDimension: maximumDimension,
			stripAudio: stripAudio,
			copyStreams: copyStreams,
			headers: headers,
			soundSource: soundSource,
			removeMetadata: removeMetadata,
			randomizeChecksum: randomizeChecksum,
			targetBitrate: targetBitrate
		);
	}

	static MediaConversion toJpg(Uri inputFile, {
		int? maximumSizeInBytes,
		int? maximumDimension,
		bool removeMetadata = false,
		bool randomizeChecksum = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'jpg',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDimension: maximumDimension,
			removeMetadata: removeMetadata,
			randomizeChecksum: randomizeChecksum
		);
	}

	static MediaConversion toPng(Uri inputFile, {
		int? maximumSizeInBytes,
		int? maximumDimension,
		bool removeMetadata = false,
		bool randomizeChecksum = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'png',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDimension: maximumDimension,
			removeMetadata: removeMetadata,
			randomizeChecksum: randomizeChecksum
		);
	}

	static MediaConversion toGif(Uri inputFile, {
		int? maximumSizeInBytes,
		int? maximumDimension,
		bool removeMetadata = false,
		bool randomizeChecksum = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'gif',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDimension: maximumDimension,
			removeMetadata: removeMetadata,
			randomizeChecksum: randomizeChecksum
		);
	}

	static MediaConversion extractThumbnail(Uri inputFile, {Map<String, String>? headers}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: switch (inputFile.path.afterLast('.')) {
				// Due to transparency, better to map png to png
				'png' => 'png',
				_ => 'jpg'
			},
			maximumDimension: 250,
			extraOptions: ['-frames:v', '1'],
			cacheKey: 'thumb',
			headers: headers ?? const {}
		);
	}

	static final _digitPattern = RegExp(r'\d');

	File getDestination() {
		String subdir = inputFile.host;
		String filename = inputFile.pathSegments.last;
		if (subdir.isEmpty) {
			// This is a local file
			subdir = base64.encode(md5.convert(utf8.encode(inputFile.pathSegments.take(inputFile.pathSegments.length - 1).join('_'))).bytes);
		}
		else if (!filename.beforeFirst('.').contains(_digitPattern)) {
			// This is a remote file
			// No numbers in the filename
			// Probably the other pathSegments are the unique parts
			filename = inputFile.pathSegments.join('_');
		}
		final filenameParts = filename.split('.');
		if (filenameParts.length > 1) {
			filenameParts.removeLast();
		}
		final filenameWithoutExtension = filenameParts.join('.');
		if (requiresSubdirectory) {
			subdir += '/$filenameWithoutExtension';
			Persistence.webmCacheDirectory.dir(subdir).createSync(recursive: true);
		}
		return Persistence.webmCacheDirectory.file('$subdir/$filenameWithoutExtension$cacheKey.$outputFileExtension');
	}

	Future<MediaConversionResult?> getDestinationIfSatisfiesConstraints({bool tryOriginalFile = true}) async {
		bool isOriginalFile = false;
		File file = getDestination();
		FileStat stat = await file.stat();
		if (stat.type == FileSystemEntityType.notFound) {
			if (tryOriginalFile && inputFile.scheme == 'file' && inputFile.path.afterLast('.') == outputFileExtension) {
				isOriginalFile = true;
				file = File(inputFile.toStringFFMPEG());
				stat = await file.stat();
				if (stat.type == FileSystemEntityType.notFound) {
					return null;
				}
			}
			else {
				return null;
			}
		}
		MediaScan? scan;
		try {
			scan = await MediaScan.scan(file.uri, headers: headers);
		}
		catch (e, st) {
			print('Error scanning existing file: $e');
			print(st);
			return null;
		}
		if (stripAudio && scan.hasAudio) {
			return null;
		}
		if (requireAudio && !scan.hasAudio) {
			return null;
		}
		if (maximumSizeInBytes != null && stat.size > maximumSizeInBytes!) {
			return null;
		}
		if ((maximumDurationInSeconds != null) && (scan.duration != null) && (scan.duration!.inSeconds > maximumDurationInSeconds!)) {
			return null;
		}
		final maxDimension = maximumDimension ?? 9999999;
		final width = scan.width ?? 0;
		final height = scan.height ?? 0;
		if (width > maxDimension || height > maxDimension) {
			return null;
		}
		if (soundSource != null && isOriginalFile) {
			return null;
		}
		if (scan.hasMetadata && removeMetadata) {
			return null;
		}
		if (outputFileExtension == 'mp4' && scan.codec != 'h264') {
			// Lazy fix. but so far we only need h264 mp4 on all sites
			return null;
		}
		if (randomizeChecksum) {
			return null;
		}
		return MediaConversionResult(file, soundSource != null || scan.hasAudio, scan.isAudioOnly);
	}

	Future<MediaConversionResult> start() async {
		try {
			await cancel();
			progress.value = null;
			final existingResult = await getDestinationIfSatisfiesConstraints();
			if (existingResult != null) {
				return existingResult;
			}
			else {
				final convertedFile = getDestination();
				await convertedFile.parent.create(recursive: true);
				if (await convertedFile.exists()) {
					await convertedFile.delete();
				}
				final scan = cachedScan = await MediaScan.scan(inputFile, headers: headers, force: true);
				final isVideoOutput = {'mp4', 'webm', 'm3u8'}.contains(outputFileExtension);
				int outputBitrate = targetBitrate ?? switch(scan.bitrate) {
					int inputBitrate => switch ((scan.codec, outputFileExtension)) {
						// Higher efficiency formats down to h264, increase target bitrate
						('vp9' || 'hevc', 'mp4') => (1.5 * inputBitrate).round(),
						// GIFs are ultra trash efficiency
						(String codec, 'gif') when codec != 'gif' => (10 * inputBitrate).round(),
						_ => inputBitrate
					},
					null => 2000000
				};
				int? outputDurationInMilliseconds = scan.duration?.inMilliseconds;
				if (isVideoOutput && maximumDurationInSeconds != null) {
					outputDurationInMilliseconds = min((maximumDurationInSeconds! * 1000).round(), outputDurationInMilliseconds!);
				}
				(int, int)? newSize;
				if ((scan.width, scan.height) case (int width, int height)) {
					if (maximumDimension case final maximumDimension?) {
						// Apply this first, because the _scaleDownRetry.factor applies from the
						// first conversion. Which means the shrunken width/height
						final fittedSize = applyBoxFit(BoxFit.contain, Size(width.toDouble(), height.toDouble()), Size.square(maximumDimension.toDouble())).destination;
						newSize = (fittedSize.width.roundToEven, fittedSize.height.roundToEven);
					}
					if (maximumSizeInBytes case final maximumSizeInBytes?) {
						if (outputDurationInMilliseconds case final ms? when isVideoOutput) {
							// Just a way to try and not get stuck, slowly reduce bitrate target over attempts
							final bitsPerByte = 8 - (_scaleDownRetry.attempts / 6);
							final maximumBitrate = (bitsPerByte * (maximumSizeInBytes / (ms / 1000))).round();
							if (maximumBitrate < outputBitrate) {
								// Limit bitrate
								outputBitrate = maximumBitrate;
							}
						}
						if (_scaleDownRetry.factor > 1) {
							// Further scaledown with retries
							final newWidth = ((newSize?.$1 ?? width) / _scaleDownRetry.factor).roundToEven;
							final newHeight = ((newSize?.$2 ?? height) / _scaleDownRetry.factor).roundToEven;
							newSize = (newWidth, newHeight);
						}
					}
				}
				bool passedFirstEvent = false;
				if (soundSource != null) {
					// Ideally this could be smarter, but it looks ok
					// and works well enough to avoid huge file due to looping
					// a high-res source with long audio.
					outputBitrate = 400000;
					final soundScan = await MediaScan.scan(soundSource!);
					final soundDuration = soundScan.duration;
					if (soundDuration != null) {
						final ms = outputDurationInMilliseconds = max(outputDurationInMilliseconds ?? soundDuration.inMilliseconds, soundDuration.inMilliseconds);
						// Use params for it to loop forever then cut off at the right time
						maximumDurationInSeconds = ms / 1000;
					}
				}
				double? earlyDetectionEstimatedNormalizedSize;
				final results = await pool.withResource(() async {
					final contentFilters = <String>[];
					final sizeFilters = <String>[];
					if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8') && !copyStreams) {
						sizeFilters.add('crop=trunc(iw/2)*2:trunc(ih/2)*2');
					}
					if (!copyStreams && newSize != null) {
						final rotation = scan.metadata?[MediaScan.kMetadataFieldRotation] as double?;
						final bool invertSize;
						if (rotation != null) {
							// rotation is closer to 90, -90, 270... than 0, 180, 360, etc
							invertSize = (rotation / 90).round() % 2 != 0;
						}
						else {
							invertSize = false;
						}
						if (invertSize) {
							sizeFilters.add('scale=${newSize.$2}:${newSize.$1}');
						}
						else {
							sizeFilters.add('scale=${newSize.$1}:${newSize.$2}');
						}
					}
					if (randomizeChecksum) {
						contentFilters.add('noise=alls=$_randomizeChecksumNoiseFactor:allf=t+u:all_seed=${random.nextInt(1 << 30)}');
					}
					Uri inputUri = inputFile;
					Map<String, String> inputHeaders = headers;
					if (soundSource != null && inputFile.toStringFFMPEG().startsWith('http')) {
						// Proxy cache the video file, FFMPEG will try to read it repeatedly if looping
						final digest = await VideoServer.instance.startCachingDownload(uri: inputUri, headers: headers);
						inputUri = VideoServer.instance.getUri(digest);
						inputHeaders = {};
					}
					final bitrateString = copyStreams || outputBitrate == 0 ? null : '${(outputBitrate / 1000).floor()}K';
					final args = [
						'-hwaccel', 'auto',
						if (inputHeaders.isNotEmpty && inputFile.scheme != 'file') ...[
							"-headers",
							inputHeaders.entries.map((h) => "${h.key}: ${h.value}").join('\r\n')
						],
						if (soundSource != null)
							if (scan.hasVideo) ...[
								'-stream_loop', '-1',
							]
							else ...[
								'-loop', '1',
								'-framerate', '1'
							],
						'-i', inputUri.toStringFFMPEG(),
						if (soundSource != null) ...[
							'-i', soundSource!.toStringFFMPEG(),
							if (maximumDurationInSeconds == null) ...[
								'-shortest',
								'-fflags', '+shortest',
							],
							'-map', '0:v:0',
							'-map', '1:a:0',
						],
						'-max_muxing_queue_size', '9999',
						...extraOptions,
						if (stripAudio) '-an',
						if (outputFileExtension == 'jpg') ...['-qscale:v', '5']
						else if (outputFileExtension != 'png' && bitrateString != null) ...['-b:v', bitrateString],
						if (bitrateString != null && isVideoOutput) ...[
							'-minrate', bitrateString,
							'-maxrate', bitrateString,
							'-bufsize', '${(outputBitrate / 500).floor()}K'
						],
						if (outputFileExtension == 'webm') ...[
							if (copyStreams && soundSource == null) ...[
								'-acodec', 'copy'
							]
							else ...[
								'-c:a', 'libvorbis',
							],
							if (copyStreams) ...[
								'-vcodec', 'copy'
							]
							else if (Platform.isAndroid) ...[
								// Android phones are not fast enough for VP9 encoding, use VP8
								'-c:v', 'libvpx',
								'-cpu-used', '2',
								'-auto-alt-ref', '0'
							]
							else ...[
								'-c:v', 'libvpx-vp9',
								'-cpu-used', '3',
								'-row-mt', '1',
								'-threads', sqrt(Platform.numberOfProcessors).ceil().toString()
							]
						],
						if (outputFileExtension == 'png') ...[
							'-pix_fmt', 'rgba',
							'-pred', 'mixed'
						],
						if (outputFileExtension == 'm3u8') ...[
							'-f', 'hls',
							'-hls_playlist_type', 'event',
							'-hls_init_time', '3',
							'-hls_time', '3',
							'-hls_flags', 'split_by_time'
						],
						if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8')) ...[
							if (copyStreams && soundSource == null)
								...['-acodec', 'copy']
							else
								...['-c:a', 'aac'],
							if (copyStreams)
								...['-vcodec', 'copy']
							else
								...[
									'-c:v', 'libx264',
									'-preset', 'medium',
									'-profile:v', 'high',
									'-level', '4.1',
									'-pix_fmt', 'yuv420p'
								]
						],
						if (copyStreams && !isVideoOutput) ...[
							'-acodec', 'copy',
							'-vcodec', 'copy',
							'-c', 'copy'
						],
						if (maximumDurationInSeconds != null) ...['-t', (maximumDurationInSeconds! * _durationArgumentFactor).toString()],
						if (removeMetadata) ...['-map_metadata', '-1'],
						if (sizeFilters.isNotEmpty || contentFilters.isNotEmpty)
							// For some reason Android png output with transparency is broken
							if (Platform.isAndroid && outputFileExtension == 'png' && (scan.pixFmt?.contains('a') ?? false) && scan.pixFmt != 'pal8') ...[
								'-filter_complex',
								'[0:v]${['alphaextract', ...sizeFilters].join(',')}[mask];\n'
								'[0:v]${[...contentFilters, ...sizeFilters].join(',')}[image];\n'
								'[image][mask]alphamerge'
							]
							else ...[
								'-vf', [...contentFilters, ...sizeFilters].join(',')
							],
						convertedFile.path
					];
					print(args);
					CancelableOperation<FFToolsOutput>? operation;
					operation = _session = FFTools.ffmpeg(
						arguments: args,
						statisticsCallback: (packet) {
							if (passedFirstEvent && outputDurationInMilliseconds != null) {
								final completion = progress.value = (packet.time / outputDurationInMilliseconds).clamp(0, 1);
								if (maximumSizeInBytes case final maxBytes? when packet.size > maxBytes) {
									// We don't need to wait for full conversion
									// Cancel it as soon as we exceed size limit
									earlyDetectionEstimatedNormalizedSize = (1 / completion) * (packet.size / maxBytes);
									operation?.cancel();
								}
							}
							passedFirstEvent = true;
						}
					);
					return operation.valueOrCancellation();
				});
				_session = null;
				if (results == null) {
					if (earlyDetectionEstimatedNormalizedSize case final normalizedSize?) {
						await convertedFile.delete();
						return await _retryWithAdditionalScaleDownFactor(normalizedSize);
					}
					throw const MediaConversionCancelledException();
				}
 				if (results.returnCode != 0) {
					if (await convertedFile.exists()) {
						await convertedFile.delete();
					}
					throw MediaConversionFFMpegException(results.returnCode, results.output);
				}
				else {
					if (maximumSizeInBytes case final maxSize?) {
						final outputSize = (await convertedFile.stat()).size;
						if (outputSize > maxSize) {
							await convertedFile.delete();
							return await _retryWithAdditionalScaleDownFactor(outputSize / maxSize);
						}
					}
					if (soundSource != null && (outputDurationInMilliseconds ?? 0) > 0) {
						// Sometimes soundpost is cut off short for some unknown reason
						final duration = (await MediaScan.scan(convertedFile.uri)).duration;
						if (duration != null && (duration.inMilliseconds / outputDurationInMilliseconds!) < 0.3) {
							// Video is much shorter, try again with larger target duration
							_durationArgumentFactor += 2;
							if (_durationArgumentFactor < 8) {
								print('Too short (${duration.inMilliseconds}ms < ${outputDurationInMilliseconds}ms)');
								await convertedFile.delete();
								return await start();
							}
							else {
								// Give up, just return it
							}
						}
					}
					if (randomizeChecksum && inputFile.isScheme('file')) {
						final originalMD5 = await calculateMD5(File.fromUri(inputFile));
						final newMD5 = await calculateMD5(convertedFile);
						if (newMD5 == originalMD5 && _randomizeChecksumNoiseFactor <= 32) {
							_randomizeChecksumNoiseFactor *= 2;
							await convertedFile.delete();
							return await start();
						}
						else {
							// Give up, just return it
						}
					}
					return MediaConversionResult(convertedFile, soundSource != null || scan.hasAudio, scan.isAudioOnly);
				}
			}
		}
		finally {
			Future.delayed(const Duration(milliseconds: 2500), () {
				if (!_disposedProgress) {
					_disposedProgress = true;
					progress.dispose();
				}
			});
		}
	}

	Future<MediaConversionResult> _retryWithAdditionalScaleDownFactor(double normalizedSize) async {
		if (_scaleDownRetry.attempts > 10) {
			throw Exception('Failed to shrink media to fit in ${formatFilesize(maximumSizeInBytes ?? -1)}');
		}
		final minimumStep = switch ((cachedScan?.width, cachedScan?.height)) {
			// Because of roundToEven
			(int width, int height) => 2.0 / min(max(width, height), maximumDimension ?? double.infinity),
			_ => 0.05
		};
		final additionalScaleDownFactor = pow(sqrt(normalizedSize) * 1.02, _scaleDownRetry.attempts + 1);
		_scaleDownRetry = (
			attempts: _scaleDownRetry.attempts + 1,
			factor: _scaleDownRetry.factor * max(1/(1 - minimumStep), additionalScaleDownFactor)
		);
		print('Too big (normalizedSize=$normalizedSize), retrying with additional factor $additionalScaleDownFactor (total=$_scaleDownRetry)');
		return await start();
	}

	Future<void> cancel() async {
		if (_session case final session?) {
			_session = null;
			await session.cancel();
			try {
				// Delete partially converted file
				await getDestination().delete();
			}
			on PathNotFoundException {
				// Fine, it must not have started
			}
		}
	}
}
