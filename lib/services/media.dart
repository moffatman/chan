import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart';
import 'package:mutex/mutex.dart';
import 'package:pool/pool.dart';

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
	MediaConversionResult(this.file, this.hasAudio);
	@override
	String toString() => 'MediaConversionResult(file: ${file.path}, hasAudio: $hasAudio)';
}

class _MediaScanCacheEntry {
	final Uri file;
	final int size;
	_MediaScanCacheEntry({
		required this.file,
		required this.size
	});

	@override
	bool operator == (dynamic o) => (o is _MediaScanCacheEntry) && (o.file == file) && (o.size == size);

	@override
	int get hashCode => Object.hash(file, size);
}

class MediaScan {
	final bool hasAudio;
	final Duration? duration;
	final int? bitrate;
	final int? width;
	final int? height;
	final String? codec;

	MediaScan({
		required this.hasAudio,
		required this.duration,
		required this.bitrate,
		required this.width,
		required this.height,
		required this.codec
	});

	static final Map<_MediaScanCacheEntry, MediaScan> _mediaScanCache = {};
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
					for (final stream in (data['streams'] as List<dynamic>)) {
						width = max(width, stream['width'] ?? 0);
						height = max(height, stream['height'] ?? 0);
					}
					completer.complete(MediaScan(
						hasAudio: (data['streams'] as List<dynamic>).any((s) => s['codec_type'] == 'audio'),
						duration: seconds == null ? null : Duration(milliseconds: (1000 * seconds).round()),
						bitrate: int.tryParse(data['format']?['bit_rate'] ?? ''),
						width: width == 0 ? null : width,
						height: height == 0 ? null : height,
						codec: ((data['streams'] as List<dynamic>).tryFirstWhere((s) => s['codec_type'] == 'video') as Map<String, dynamic>?)?['codec_name']
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
			final entry = _MediaScanCacheEntry(file: file, size: size);
			if (_mediaScanCache[entry] == null) {
				_mediaScanCache[entry] = await _scan(file);
			}
			return _mediaScanCache[entry]!;
		}
		else {
			return _scan(file, headers: headers);
		}
	}

	@override
	String toString() => 'MediaScan(hasAudio: $hasAudio, duration: $duration, bitrate: $bitrate)';
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

	FFmpegSession? _session;

	static final pool = Pool(Platform.numberOfProcessors);

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
		this.soundSource
	});

	static MediaConversion toMp4(Uri inputFile, {
		Map<String, String> headers = const {},
		Uri? soundSource
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'mp4',
			headers: headers,
			soundSource: soundSource
		);
	}

	static MediaConversion toWebm(Uri inputFile, {
		int? maximumSizeInBytes,
		int? maximumDurationInSeconds,
		required bool stripAudio,
		int? maximumDimension
	}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'webm',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDurationInSeconds: maximumDurationInSeconds,
			maximumDimension: maximumDimension,
			stripAudio: stripAudio,
			extraOptions: ['-c:a', 'libvorbis', '-c:v', 'libvpx', '-cpu-used', '2']
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
			subdir = inputFile.pathSegments.take(inputFile.pathSegments.length - 1).join('_');
		}
		final filename = inputFile.pathSegments.last;
		final fileExtension = inputFile.pathSegments.last.split('.').last;
		return File('${Persistence.temporaryDirectory.path}/webmcache/$subdir/${filename.replaceFirst('.$fileExtension', '$cacheKey.$outputFileExtension')}');
	}

	Future<MediaConversionResult?> getDestinationIfSatisfiesConstraints() async {
		File file = getDestination();
		if (!(await file.exists())) {
			if (inputFile.scheme == 'file') {
				file = File(inputFile.path);
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
		return MediaConversionResult(file, scan?.hasAudio ?? false);
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
					final scan = await MediaScan.scan(inputFile, headers: headers);
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
						if (outputFileExtension != 'jpg' && outputFileExtension != 'png') {
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
							if (newSize == null || fittedSize.width < newSize.$0) {
								newSize = (fittedSize.width.round(), fittedSize.height.round());
							}
						}
					}
					bool passedFirstEvent = false;
					FFmpegKitConfig.enableStatisticsCallback((stats) {
						if (stats.getSessionId() == _session?.getSessionId()) {
							if (scan.duration != null && passedFirstEvent && outputDurationInMilliseconds != null) {
								progress.value = (stats.getTime() / outputDurationInMilliseconds).clamp(0, 1);
							}
							passedFirstEvent = true;
						}
					});
					final bitrateString = '${(outputBitrate / 1000).floor()}K';
					final ffmpegCompleter = Completer<Session>();
					_session = await pool.withResource(() {
						final args = [
							'-hwaccel', 'auto',
							if (headers.isNotEmpty && inputFile.scheme != 'file') ...[
								"-headers",
								headers.entries.map((h) => "${h.key}: ${h.value}").join('\r\n')
							],
							'-i', inputFile.toStringFFMPEG(),
							if (soundSource != null) ...[
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
							if (outputFileExtension == 'mp4')
								if (_isVideoToolboxSupported && !_hasVideoToolboxFailed)
									...['-vcodec', 'h264_videotoolbox']
								else
									...['-c:v', 'libx264', '-preset', 'medium', '-vf', 'crop=trunc(iw/2)*2:trunc(ih/2)*2'],
							if (newSize != null) ...['-vf', 'scale=${newSize.$0}:${newSize.$1}'],
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
						if (outputFileExtension == 'mp4' &&
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
							_completer!.complete(MediaConversionResult(convertedFile, soundSource != null || scan.hasAudio));
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

class _ConvertParam {
	final String inputPath;
	final String temporaryDirectoryPath;
	const _ConvertParam({
		required this.inputPath,
		required this.temporaryDirectoryPath
	});
}

Future<File> convertToJpg(File input) async {
	return File(await compute<_ConvertParam, String>((param) async {
		final image = decodeImage(await File(param.inputPath).readAsBytes());
		if (image == null) {
			throw Exception('Failed to decode image');
		}
		final outputFile = File('${param.temporaryDirectoryPath}/${param.inputPath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '.jpg')}');
		await outputFile.writeAsBytes(encodeJpg(image));
		return outputFile.path;
	}, _ConvertParam(
		inputPath: input.path,
		temporaryDirectoryPath: Persistence.temporaryDirectory.path
	)));
}