import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:mutex/mutex.dart';

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
	int get hashCode => hashValues(file, size);
}

class MediaScan {
	final bool hasAudio;
	final Duration? duration;
	final int? bitrate;
	final int? width;
	final int? height;

	MediaScan({
		required this.hasAudio,
		required this.duration,
		required this.bitrate,
		required this.width,
		required this.height
	});

	static final Map<_MediaScanCacheEntry, MediaScan> _mediaScanCache = {};
	static final _ffprobeLock = Mutex();

	static Future<MediaScan> _scan(Uri file) async {
		return await _ffprobeLock.protect<MediaScan>(() async {
			final completer = Completer<MediaScan>();
			FFprobeKit.getMediaInformationAsync(file.toString(), (session) async {
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
					bitrate: int.tryParse(data['format']?['bit_rate']),
					width: width == 0 ? null : width,
					height: height == 0 ? null : height
				));
			});
			return completer.future;
		});
	}

	static Future<MediaScan> scan(Uri file) async {
		if (file.scheme == 'file') {
			final size = (await File(file.path).stat()).size;
			final entry = _MediaScanCacheEntry(file: file, size: size);
			if (_mediaScanCache[entry] == null) {
				_mediaScanCache[entry] = await _scan(file);
			}
			return _mediaScanCache[entry]!;
		}
		else {
			return _scan(file);
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

	FFmpegSession? _session;

	MediaConversion({
		required this.inputFile,
		required this.outputFileExtension,
		this.maximumSizeInBytes,
		this.maximumDurationInSeconds,
		this.stripAudio = false,
		this.extraOptions = const []
	});

	static MediaConversion toMp4(Uri inputFile) {
		List<String> extraOptions = [];
		if (Platform.isIOS && !RegExp(r'Version 15\.[01]').hasMatch(Platform.operatingSystemVersion)) {
			extraOptions = ['-vcodec', 'h264_videotoolbox'];
		}
		else if (Platform.isAndroid || Platform.isIOS) {
			extraOptions = ['-c:v', 'libx264', '-preset', 'medium', '-vf', 'crop=trunc(iw/2)*2:trunc(ih/2)*2'];
		}
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'mp4',
			extraOptions: extraOptions
		);
	}

	static MediaConversion toWebm(Uri inputFile, {int? maximumSizeInBytes, int? maximumDurationInSeconds, required bool stripAudio}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'webm',
			maximumSizeInBytes: maximumSizeInBytes,
			maximumDurationInSeconds: maximumDurationInSeconds,
			stripAudio: stripAudio,
			extraOptions: ['-c:a', 'libvorbis', '-c:v', 'libvpx', '-cpu-used', '2']
		);
	}

	static MediaConversion toJpg(Uri inputFile, {int? maximumSizeInBytes}) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'jpg',
			maximumSizeInBytes: maximumSizeInBytes
		);
	}

	static MediaConversion extractThumbnail(Uri inputFile) {
		return MediaConversion(
			inputFile: inputFile,
			outputFileExtension: 'jpg',
			extraOptions: ['-frames:v', '1']
		);
	}

	File getDestination() {
		String subdir = inputFile.host;
		if (subdir.isEmpty) {
			subdir = inputFile.pathSegments.take(inputFile.pathSegments.length - 1).join('_');
		}
		final filename = inputFile.pathSegments.last;
		final fileExtension = inputFile.pathSegments.last.split('.').last;
		return File(Persistence.temporaryDirectory.path + '/webmcache/' + subdir + '/' + filename.replaceFirst('.$fileExtension', '.$outputFileExtension'));
	}

	Future<MediaConversionResult?> getDestinationIfSatisfiesConstraints() async {
		final file = getDestination();
		if (!(await file.exists())) {
			return null;
		}
		final stat = await file.stat();
		MediaScan? scan;
		if (outputFileExtension != 'jpg') {
			scan = await MediaScan.scan(file.uri);
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

	void start() async {
		try {
			cancel();
			_completer = Completer<MediaConversionResult>();
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
					final scan = await MediaScan.scan(inputFile);
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
					String? filter;
					if (scan.width != null && scan.height != null) {
						double scaleDownFactorSq = outputBitrate/(2 * scan.width! * scan.height!);
						if (scaleDownFactorSq < 1) {
							final newWidth = (scan.width! * (sqrt(scaleDownFactorSq) / 2)).round() * 2;
							final newHeight = (scan.height! * (sqrt(scaleDownFactorSq) / 2)).round() * 2;
							filter = 'scale=$newWidth:$newHeight';
						}
					}
					bool passedFirstEvent = false;
					FFmpegKitConfig.enableStatisticsCallback((stats) {
						if (stats.getSessionId() == _session?.getSessionId()) {
							if (scan.duration != null && passedFirstEvent && outputDurationInMilliseconds != null) {
								progress.value = stats.getTime() / outputDurationInMilliseconds;
							}
							passedFirstEvent = true;
						}
					});
					final bitrateString = (outputBitrate / 1000).floor().toString() + 'K';
					final ffmpegCompleter = Completer<Session>();
					 _session = await FFmpegKit.executeWithArgumentsAsync([
						'-hwaccel', 'auto',
						'-i', inputFile.toString(),
						'-max_muxing_queue_size', '9999',
						...extraOptions,
						if (stripAudio) '-an',
						if (outputFileExtension == 'jpg') ...['-qscale:v', '5']
						else ...['-b:v', bitrateString],
						if (outputFileExtension == 'webm') ...['-crf', '10'],
						if (filter != null) ...['-vf', filter],
						if (maximumDurationInSeconds != null) ...['-t', maximumDurationInSeconds.toString()],
						convertedFile.path
					], (c) => ffmpegCompleter.complete(c));
					final results = await ffmpegCompleter.future;
					final returnCode = await results.getReturnCode();
					if (!(returnCode?.isValueSuccess() ?? false)) {
						if (await convertedFile.exists()) {
							await convertedFile.delete();
						}
						throw MediaConversionFFMpegException(returnCode?.getValue() ?? -1);
					}
					else {
						_completer!.complete(MediaConversionResult(convertedFile, scan.hasAudio));
					}
				}
			}
		}
		catch (error, st) {
			_completer!.completeError(error, st);
		}
		Future.delayed(const Duration(milliseconds: 500), () => progress.dispose());
	}

	void cancel() => _session?.cancel();
}