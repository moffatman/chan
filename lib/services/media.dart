import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

class MediaConversionFFMpegException implements Exception {
	int exitCode;
	MediaConversionFFMpegException(this.exitCode);

	@override
	String toString() => 'MediaConversionFFMpegException(exitCode: $exitCode)';
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

	MediaScan({
		required this.hasAudio,
		required this.duration,
		required this.bitrate,
		required this.width,
		required this.height,
		required this.codec,
		required this.videoFramerate,
		required this.sizeInBytes
	});

	static final _ffprobeLock = Mutex();

	static Future<MediaScan> _scan(Uri file, {
		Map<String, String> headers = const {}
	}) async {
		return await _ffprobeLock.protect<MediaScan>(() async {
			final completer = Completer<MediaScan>();
			FFprobeKit.getMediaInformationFromCommandArgumentsAsync([
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
			], (session) async {
				try {
					final output = await session.getOutput();
					if (output == null) {
						completer.completeError(Exception('No output from ffprobe'));
						return;
					}
					final data = jsonDecode(output);
					final seconds = double.tryParse(data['format']?['duration'] ?? '');
					int width = 0;
					int height = 0;
					double? videoFramerate;
					for (final stream in (data['streams'] as List<dynamic>)) {
						width = max(width, stream['width'] ?? 0);
						height = max(height, stream['height'] ?? 0);
						if (stream['codec_type'] == 'video') {
							final avgFramerateFractionString = stream['avg_frame_rate'] as String?;
							final match = RegExp(r'^(\d+)\/(\d+)$').firstMatch(avgFramerateFractionString ?? '');
							if (match != null) {
								videoFramerate = int.parse(match.group(1)!) / int.parse(match.group(2)!);
							}
						}
					}
					completer.complete(MediaScan(
						hasAudio: (data['streams'] as List<dynamic>).any((s) => s['codec_type'] == 'audio'),
						duration: seconds == null ? null : Duration(milliseconds: (1000 * seconds).round()),
						bitrate: int.tryParse(data['format']?['bit_rate'] ?? ''),
						width: width == 0 ? null : width,
						height: height == 0 ? null : height,
						codec: ((data['streams'] as List<dynamic>).tryFirstWhere((s) => s['codec_type'] == 'video') as Map<String, dynamic>?)?['codec_name'],
						videoFramerate: videoFramerate,
						sizeInBytes: int.tryParse(data['format']?['size'] ?? '')
					));
				}
				catch (e, st) {
					completer.completeError(e, st);
				}
			});
			return completer.future;
		});
	}

	static Future<MediaScan> scan(Uri file, {
		Map<String, String> headers = const {}
	}) async {
		if (file.scheme == 'file') {
			final size = (await File(file.path).stat()).size;
			final cachedScan = await Persistence.mediaScanBox.get(file.path);
			if (cachedScan?.sizeInBytes == size) {
				return cachedScan!;
			}
			final scan = await _scan(file);
			Persistence.mediaScanBox.put(file.path, scan);
			return scan;
		}
		else {
			return _scan(file, headers: headers);
		}
	}

	bool get isAudioOnly => videoFramerate?.isNaN ?? true;

	@override
	String toString() => 'MediaScan(hasAudio: $hasAudio, duration: $duration, bitrate: $bitrate, width: $width, height: $height, codec: $codec, videoFramerate: $videoFramerate)';
}

class MediaConversion {
	final progress = ValueNotifier<double?>(null);
	Completer<MediaConversionResult>? _completer;
	Future<MediaConversionResult> get result => _completer!.future;
	final Uri inputFile;
	String outputFileExtension;
	List<String> extraOptions;
	int? maximumSizeInBytes;
	int? maximumDurationInSeconds;
	bool stripAudio;
	int? maximumDimension;
	final String cacheKey;
	final Map<String, String> headers;
	int _additionalScaleDownFactor = 1;
	final Uri? soundSource;
	final bool requiresSubdirectory;
	final bool copyStreams;

	FFmpegSession? _session;
	MediaScan? cachedScan;

	static final pool = Pool(sqrt(Platform.numberOfProcessors).ceil());

	static bool get _isVideoToolboxSupported => Platform.isIOS && !RegExp(r'Version 15\.[01]').hasMatch(Platform.operatingSystemVersion);
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
		this.copyStreams = false
	});

	static MediaConversion toMp4(Uri inputFile, {
		Map<String, String> headers = const {},
		Uri? soundSource,
		bool copyStreams = false
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'mp4',
			headers: headers,
			soundSource: soundSource,
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
		int? maximumDurationInSeconds,
		required bool stripAudio,
		int? maximumDimension,
		Map<String, String> headers = const {},
		Uri? soundSource
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'webm',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDurationInSeconds: maximumDurationInSeconds,
			maximumDimension: maximumDimension,
			stripAudio: stripAudio,
			extraOptions: ['-c:a', 'libvorbis', '-c:v', 'libvpx', '-cpu-used', '2'],
			headers: headers,
			soundSource: soundSource
		);
	}

	static MediaConversion toJpg(Uri inputFile, {int? maximumSizeInBytes, int? maximumDimension}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'jpg',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDimension: maximumDimension
		);
	}

	static MediaConversion toPng(Uri inputFile, {int? maximumSizeInBytes, int? maximumDimension}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'png',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDimension: maximumDimension
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

	File getDestination() {
		String subdir = inputFile.host;
		if (subdir.isEmpty) {
			subdir = base64.encode(md5.convert(utf8.encode(inputFile.pathSegments.take(inputFile.pathSegments.length - 1).join('_'))).bytes);
		}
		String filename = inputFile.pathSegments.last;
		if (!filename.split('.').first.contains(RegExp(r'\d'))) {
			// No numbers in the filename
			// Probably the other pathSegments are the unique parts
			filename = inputFile.pathSegments.join('_');
		}
		final fileExtension = inputFile.pathSegments.last.split('.').last;
		if (requiresSubdirectory) {
			subdir += '/${filename.replaceFirst('.$fileExtension', '')}';
			Directory('${Persistence.temporaryDirectory.path}/webmcache/$subdir').createSync(recursive: true);
		}
		return File('${Persistence.temporaryDirectory.path}/webmcache/$subdir/${filename.replaceFirst('.$fileExtension', '$cacheKey.$outputFileExtension')}');
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
		if (outputFileExtension != 'jpg' && outputFileExtension != 'png') {
			try {
				scan = await MediaScan.scan(file.uri, headers: headers);
			}
			catch (e, st) {
				print('Error scanning existing file: $e');
				print(st);
				return null;
			}
		}
		if (stripAudio && scan!.hasAudio) {
			return null;
		}
		if (maximumSizeInBytes != null && stat.size > maximumSizeInBytes!) {
			return null;
		}
		if ((maximumDurationInSeconds != null) && (scan!.duration != null) && (scan.duration!.inSeconds > maximumDurationInSeconds!)) {
			return null;
		}
		final maxDimension = maximumDimension ?? 9999999;
		final width = scan?.width ?? 0;
		final height = scan?.height ?? 0;
		if (width > maxDimension || height > maxDimension) {
			return null;
		}
		if (soundSource != null && isOriginalFile) {
			return null;
		}
		return MediaConversionResult(file, soundSource != null || (scan?.hasAudio ?? false), scan?.isAudioOnly ?? false);
	}

	Future<void> start() async {
		try {
			cancel();
			_completer ??= Completer<MediaConversionResult>();
			progress.value = null;
			final existingResult = await getDestinationIfSatisfiesConstraints();
			if (existingResult != null) {
				_completer!.complete(existingResult);
			}
			else {
				final convertedFile = getDestination();
				await convertedFile.parent.create(recursive: true);
				if (await convertedFile.exists()) {
					await convertedFile.delete();
				}
				if (isDesktop()) {
					throw Exception('Media conversions disabled on desktop');
				}
				else {
					final scan = cachedScan = await MediaScan.scan(inputFile, headers: headers);
					int outputBitrate = scan.bitrate ?? 2000000;
					int? outputDurationInMilliseconds = scan.duration?.inMilliseconds;
					if (outputFileExtension == 'webm' || outputFileExtension == 'mp4') {
						if (maximumDurationInSeconds != null) {
							outputDurationInMilliseconds = min(maximumDurationInSeconds! * 1000, outputDurationInMilliseconds!);
						}
						if (maximumSizeInBytes != null) {
							outputBitrate = min(outputBitrate, (8 * (maximumSizeInBytes! / (outputDurationInMilliseconds! / 1000))).round());
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
					FFmpegKitConfig.enableStatisticsCallback((stats) {
						if (stats.getSessionId() == _session?.getSessionId()) {
							if (passedFirstEvent && outputDurationInMilliseconds != null) {
								progress.value = (stats.getTime() / outputDurationInMilliseconds).clamp(0, 1);
							}
							passedFirstEvent = true;
						}
					});
					final bitrateString = '${(outputBitrate / 1000).floor()}K';
					final ffmpegCompleter = Completer<Session>();
					_session = await pool.withResource(() async {
						final args = [
							'-hwaccel', 'auto',
							if (headers.isNotEmpty && inputFile.scheme != 'file') ...[
								"-headers",
								headers.entries.map((h) => "${h.key}: ${h.value}").join('\r\n')
							],
							'-i', inputFile.toStringFFMPEG(),
							if (soundSource != null && !copyStreams) ...[
								'-i', soundSource!.toStringFFMPEG(),
								'-map', '0:v:0',
								'-map', '1:a:0',
								'-c:a', 'aac',
								'-b:a', '192k'
							],
							'-max_muxing_queue_size', '9999',
							...extraOptions,
							if (stripAudio) '-an',
							if (outputFileExtension == 'jpg') ...['-qscale:v', '5']
							else if (outputFileExtension != 'png') ...['-b:v', bitrateString],
							if (outputFileExtension == 'jpg' || outputFileExtension == 'png') ...['-pix_fmt', 'rgba'],
							if (outputFileExtension == 'png') ...['-pred', 'mixed'],
							if (outputFileExtension == 'webm') ...['-crf', '10'],
							if (outputFileExtension == 'm3u8') ...[
								'-f', 'hls',
								'-hls_playlist_type', 'event',
								'-hls_init_time', '3',
								'-hls_time', '3',
								'-hls_flags', 'split_by_time'
							],
							if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8') && !copyStreams)
								if (_isVideoToolboxSupported && !_hasVideoToolboxFailed)
									...['-vcodec', 'h264_videotoolbox']
								else
									...['-c:v', 'libx264', '-preset', 'medium', '-vf', 'crop=trunc(iw/2)*2:trunc(ih/2)*2'],
							if (copyStreams) ...['-acodec', 'copy', '-vcodec', 'copy', '-c', 'copy']
							else if (newSize != null) ...['-vf', 'scale=${newSize.$1}:${newSize.$2}'],
							if (maximumDurationInSeconds != null) ...['-t', maximumDurationInSeconds.toString()],
							convertedFile.path
						];
						print(args);
						return FFmpegKit.executeWithArgumentsAsync(args, (c) => ffmpegCompleter.complete(c));
					});
					final results = await ffmpegCompleter.future;
					final returnCode = await results.getReturnCode();
					if (!(returnCode?.isValueSuccess() ?? false)) {
						if (await convertedFile.exists()) {
							await convertedFile.delete();
						}
						if ((outputFileExtension == 'mp4' || outputFileExtension == 'm3u8') &&
								_isVideoToolboxSupported &&
								!_hasVideoToolboxFailed &&
								((await results.getAllLogsAsString())?.contains('Error while opening encoder') ?? false)) {
							_hasVideoToolboxFailed = true;
							await start();
							return;
						}
						throw MediaConversionFFMpegException(returnCode?.getValue() ?? -1);
					}
					else {
						if (maximumSizeInBytes != null && (await convertedFile.stat()).size > maximumSizeInBytes!) {
							_additionalScaleDownFactor += 2;
							print('Too big, retrying with factor $_additionalScaleDownFactor');
							await start();
							return;
						}
						else {
							_completer!.complete(MediaConversionResult(convertedFile, soundSource != null || scan.hasAudio, scan.isAudioOnly));
						}
					}
				}
			}
		}
		catch (error, st) {
			_completer!.completeError(error, st);
		}
		Future.delayed(const Duration(milliseconds: 2500), () => progress.dispose());
	}

	void cancel() => _session?.cancel();
}
