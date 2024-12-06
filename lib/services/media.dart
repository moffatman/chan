import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:async/async.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html/parser.dart';
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
		required this.format
	});

	static final _ffprobeLock = Mutex();
	static LazyBox<MediaScan>? _mediaScanBox;
	static final _boxLock = Mutex();

	static Future<MediaScan> _scan(Uri file, {
		Map<String, String> headers = const {},
		int tries = 0
	}) async {
		try {
			return await _ffprobeLock.protect<MediaScan>(() async {
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
								if (string.contains('<body>')) {
									final document = parse(string);
									if (document.querySelector('title')?.text.nonEmptyOrNull case String title) {
										throw MediaScanException(file, 1, title);
									}
									for (int i = 1; i < 6; i++) {
										final headers = document.querySelectorAll('h$i');
										if (headers.trySingle?.text.nonEmptyOrNull case String header) {
											throw MediaScanException(file, 1, header);
										}
										if (headers.length > 1) {
											// Can't pick between multiple
											break;
										}
									}
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
							files[file.pathSegments.last] = await File(file.path).readAsBytes();
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
				final data = jsonDecode(result.output);
				final seconds = double.tryParse(data['format']?['duration'] as String? ?? '');
				int width = 0;
				int height = 0;
				double? videoFramerate;
				Map? metadata = data['format']?['tags'] as Map?;
				for (final stream in (data['streams'] as List<dynamic>)) {
					width = max(width, stream['width'] as int? ?? 0);
					height = max(height, stream['height'] as int? ?? 0);
					if (stream['codec_type'] == 'video') {
						final avgFramerateFractionString = stream['avg_frame_rate'] as String?;
						final match = RegExp(r'^(\d+)\/(\d+)$').firstMatch(avgFramerateFractionString ?? '');
						if (match != null) {
							videoFramerate = int.parse(match.group(1)!) / int.parse(match.group(2)!);
						}
						final rotation = (((stream['side_data_list'] as List?)?.tryFirst as Map?)?['rotation'] as num?)?.toDouble();
						if (rotation != null) {
							(metadata ??= {})[kMetadataFieldRotation] = rotation;
						}
					}
				}
				return MediaScan(
					hasAudio: (data['streams'] as List<dynamic>).any((s) => s['codec_type'] == 'audio'),
					duration: seconds == null ? null : Duration(milliseconds: (1000 * seconds).round()),
					bitrate: int.tryParse(data['format']?['bit_rate'] as String? ?? ''),
					width: width == 0 ? null : width,
					height: height == 0 ? null : height,
					codec: ((data['streams'] as List<dynamic>).tryFirstWhere((s) => s['codec_type'] == 'video') as Map<String, dynamic>?)?['codec_name'] as String?,
					videoFramerate: videoFramerate,
					sizeInBytes: int.tryParse(data['format']?['size'] as String? ?? ''),
					metadata: metadata,
					format: (data['format'] as Map?)?['format_name'] as String?
				);
			});
		}
		on FormatException {
			if (tries < 3) {
				return _scan(file, headers: headers, tries: tries + 1);
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
		Map<String, String> headers = const {}
	}) async {
		if (file.scheme == 'file') {
			final peeked = peekCachedFileScan(file.path);
			if (peeked != null) {
				return peeked;
			}
			// Not cached or file size doesn't match
			return _boxLock.protect(() async {
				runWhenIdle(const Duration(seconds: 1), _closeBox);
				final mediaScanBox = _mediaScanBox ??= await Hive.openLazyBox<MediaScan>('mediaScans');
				final scan = await _scan(file);
				final key = _makeKey(file.path);
				_fileScans[key] = scan;
				await mediaScanBox.put(key, scan);
				return scan;
			});
		}
		else {
			return _scan(file, headers: headers);
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
		       map.keys.any((k) => !_kUnremoveableMetadataFields.contains(k.toLowerCase()));
	}

	@override
	String toString() => 'MediaScan(hasAudio: $hasAudio, duration: $duration, bitrate: $bitrate, width: $width, height: $height, codec: $codec, videoFramerate: $videoFramerate)';
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
	int _additionalScaleDownFactor = 1;
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

	static final _badVideoToolboxIosVersionPattern = RegExp(r'Version 15\.[01]');
	static bool get _isVideoToolboxSupported => Platform.isIOS && !_badVideoToolboxIosVersionPattern.hasMatch(Platform.operatingSystemVersion);
	bool _hasVideoToolboxFailed = false;

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
	});

	static MediaConversion toMp4(Uri inputFile, {
		Map<String, String> headers = const {},
		Uri? soundSource,
		bool copyStreams = false,
		bool stripAudio = false,
		int? maximumSizeInBytes,
		double? maximumDurationInSeconds,
		int? maximumDimension,
		bool removeMetadata = false,
		bool randomizeChecksum = false,
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
		Uri? soundSource
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'm3u8',
			headers: headers,
			soundSource: soundSource,
			requiresSubdirectory: true,
			copyStreams: inputFile.path.endsWith('.m3u8')
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
		bool randomizeChecksum = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'gif',
			randomizeChecksum: randomizeChecksum
		);
	}

	static MediaConversion extractThumbnail(Uri inputFile) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'jpg',
			maximumDimension: 250,
			extraOptions: ['-frames:v', '1'],
			cacheKey: 'thumb'
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
		else if (!filename.split('.').first.contains(_digitPattern)) {
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
			Directory('${Persistence.webmCacheDirectory.path}/$subdir').createSync(recursive: true);
		}
		return File('${Persistence.webmCacheDirectory.path}/$subdir/$filenameWithoutExtension$cacheKey.$outputFileExtension');
	}

	Future<MediaConversionResult?> getDestinationIfSatisfiesConstraints() async {
		bool isOriginalFile = false;
		File file = getDestination();
		if (!(await file.exists())) {
			if (inputFile.scheme == 'file' && inputFile.path.split('.').last == outputFileExtension) {
				isOriginalFile = true;
				file = File(inputFile.toStringFFMPEG());
			}
			else {
				return null;
			}
		}
		final stat = await file.stat();
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
		if (randomizeChecksum) {
			return null;
		}
		return MediaConversionResult(file, soundSource != null || scan.hasAudio, scan.isAudioOnly);
	}

	Future<MediaConversionResult> start() async {
		try {
			cancel();
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
				final scan = cachedScan = await MediaScan.scan(inputFile, headers: headers);
				int outputBitrate = targetBitrate ?? scan.bitrate ?? 2000000;
				int? outputDurationInMilliseconds = scan.duration?.inMilliseconds;
				if (outputFileExtension == 'webm' || outputFileExtension == 'mp4') {
					if (maximumDurationInSeconds != null) {
						outputDurationInMilliseconds = min((maximumDurationInSeconds! * 1000).round(), outputDurationInMilliseconds!);
					}
					if (maximumSizeInBytes != null) {
						outputBitrate = min(outputBitrate, ((7.2 - (_additionalScaleDownFactor / 6)) * (maximumSizeInBytes! / (outputDurationInMilliseconds! / 1000))).round());
					}
				}
				(int, int)? newSize;
				if (scan.width != null && scan.height != null) {
					if (outputFileExtension != 'jpg' && outputFileExtension != 'png' && maximumSizeInBytes != null) {
						double scaleDownFactorSq = (outputBitrate/(2 * scan.width! * scan.height!)) / _additionalScaleDownFactor;
						if (scaleDownFactorSq < 1) {
							final newWidth = (scan.width! * (sqrt(scaleDownFactorSq) / 2)).round() * 2;
							final newHeight = (scan.height! * (sqrt(scaleDownFactorSq) / 2)).round() * 2;
							newSize = (newWidth, newHeight);
						}
					}
					else if (maximumSizeInBytes != null) {
						double scaleDownFactor = ((scan.width! * scan.height!) / (maximumSizeInBytes! * (outputFileExtension == 'jpg' ? 6 : 3))) + _additionalScaleDownFactor;
						if (scaleDownFactor > 1) {
							final newWidth = ((scan.width! / scaleDownFactor) / 2).round() * 2;
							final newHeight = ((scan.height! / scaleDownFactor) / 2).round() * 2;
							newSize = (newWidth, newHeight);
						}
					}
					if (maximumDimension != null) {
						final fittedSize = applyBoxFit(BoxFit.contain, Size(scan.width!.toDouble(), scan.height!.toDouble()), Size.square(maximumDimension!.toDouble())).destination;
						if (newSize == null || fittedSize.width < newSize.$1) {
							newSize = (fittedSize.width.round(), fittedSize.height.round());
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
				final results = await pool.withResource(() async {
					final vfs = <String>[];
					if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8') && !copyStreams && (!_isVideoToolboxSupported || _hasVideoToolboxFailed)) {
						vfs.add('crop=trunc(iw/2)*2:trunc(ih/2)*2');
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
							vfs.add('scale=${newSize.$2}:${newSize.$1}');
						}
						else {
							vfs.add('scale=${newSize.$1}:${newSize.$2}');
						}
					}
					if (randomizeChecksum) {
						vfs.add('noise=alls=10:allf=t+u:all_seed=${random.nextInt(1 << 30)}');
					}
					Uri inputUri = inputFile;
					Map<String, String> inputHeaders = headers;
					if (soundSource != null && inputFile.toStringFFMPEG().startsWith('http')) {
						// Proxy cache the video file, FFMPEG will try to read it repeatedly if looping
						final digest = await VideoServer.instance.startCachingDownload(uri: inputUri);
						inputUri = VideoServer.instance.getUri(digest);
						inputHeaders = {};
					}
					final bitrateString = '${(outputBitrate / 1000).floor()}K';
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
						else if (outputFileExtension != 'png') ...['-b:v', bitrateString],
						if (outputFileExtension == 'webm' || outputFileExtension == 'mp4') ...[
							'-minrate', bitrateString,
							'-maxrate', bitrateString,
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
						if (outputFileExtension == 'jpg' || outputFileExtension == 'png') ...['-pix_fmt', 'rgba'],
						if (outputFileExtension == 'png') ...['-pred', 'mixed'],
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
							else if (_isVideoToolboxSupported && !_hasVideoToolboxFailed)
								...['-vcodec', 'h264_videotoolbox']
							else
								...['-c:v', 'libx264', '-preset', 'medium']
						],
						if (copyStreams && outputFileExtension != 'webm' && outputFileExtension != 'mp4') ...[
							'-acodec', 'copy',
							'-vcodec', 'copy',
							'-c', 'copy'
						],
						if (maximumDurationInSeconds != null) ...['-t', (maximumDurationInSeconds! * _durationArgumentFactor).toString()],
						if (removeMetadata) ...['-map_metadata', '-1'],
						if (vfs.isNotEmpty) ...['-vf', vfs.join(',')],
						convertedFile.path
					];
					print(args);
					final operation = _session = FFTools.ffmpeg(
						arguments: args,
						statisticsCallback: (packet) {
							if (passedFirstEvent && outputDurationInMilliseconds != null) {
								progress.value = (packet.time / outputDurationInMilliseconds).clamp(0, 1);
							}
							passedFirstEvent = true;
						}
					);
					return operation.value;
				});
				_session = null;
				if (results.returnCode != 0) {
					if (await convertedFile.exists()) {
						await convertedFile.delete();
					}
					if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8') &&
							_isVideoToolboxSupported &&
							!_hasVideoToolboxFailed &&
							results.output.contains('Error while opening encoder')) {
						_hasVideoToolboxFailed = true;
						return await start();
					}
					throw MediaConversionFFMpegException(results.returnCode, results.output);
				}
				else {
					if (maximumSizeInBytes != null) {
						final outputSize = (await convertedFile.stat()).size;
						if (outputSize > maximumSizeInBytes!) {
							_additionalScaleDownFactor += 2;
							if (_additionalScaleDownFactor > 32) {
								throw Exception('Failed to shrink image to fit in ${formatFilesize(maximumSizeInBytes!)}');
							}
							print('Too big (${formatFilesize(outputSize)} > ${formatFilesize(maximumSizeInBytes!)}), retrying with factor $_additionalScaleDownFactor');
							return await start();
						}
					}
					else if (soundSource != null && (outputDurationInMilliseconds ?? 0) > 0) {
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

	Future<void> cancel() async {
		await _session?.cancel();
		try {
			// Delete partially converted file
			await getDestination().delete();
		}
		on PathNotFoundException {
			// Fine, it must not have started
		}
	}
}
