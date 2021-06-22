import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_ffmpeg/completed_ffmpeg_execution.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:mutex/mutex.dart';

class MediaConversionFFMpegException implements Exception {
	int exitCode;
	MediaConversionFFMpegException(this.exitCode);

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

	MediaScan({
		required this.hasAudio,
		required this.duration,
		required this.bitrate
	});

	static final _mediaScanCache = Map<_MediaScanCacheEntry, MediaScan>();
	static final _ffprobeLock = Mutex();

	static Future<MediaScan> _scan(Uri file) async {
		return await _ffprobeLock.protect<MediaScan>(() async {
			final mediaInfo = (await FlutterFFprobe().getMediaInformation(file.toString())).getAllProperties();
			final seconds = double.tryParse(mediaInfo['format']?['duration'] ?? '');
			return MediaScan(
				hasAudio: mediaInfo['streams']?.any((stream) => stream['codec_type'] == 'audio') ?? true,
				duration: seconds == null ? null : Duration(milliseconds: (seconds * 1000).round()),
				bitrate: int.tryParse(mediaInfo['format']?['bit_rate'] ?? '')
			);
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

	int? _executionId;

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
		if (Platform.isAndroid) {
			extraOptions = ['-c:v', 'libx264', '-preset', 'ultrafast', '-vf', 'crop=trunc(iw/2)*2:trunc(ih/2)*2'];
		}
		else if (Platform.isIOS) {
			extraOptions = ['-vcodec', 'h264_videotoolbox'];
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
			extraOptions: ['-c:v', 'libvpx', '-c:a', 'libvorbis']
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
					final ffconfig = FlutterFFmpegConfig();
					final ffmpeg = FlutterFFmpeg();
					final scan = await MediaScan.scan(inputFile);
					int outputBitrate = scan.bitrate ?? 2000000;
					int? outputDurationInMilliseconds = scan.duration?.inMilliseconds;
					if (outputFileExtension == 'webm' || outputFileExtension == 'mp4') {
						if (maximumDurationInSeconds != null) {
							outputDurationInMilliseconds = min(maximumDurationInSeconds! * 1000, outputDurationInMilliseconds!);
						}
						if (maximumSizeInBytes != null) {
							outputBitrate = min(outputBitrate, (6 * (maximumSizeInBytes! / (outputDurationInMilliseconds! / 1000))).round());
						}
					}
					bool passedFirstEvent = false;
					ffconfig.enableStatisticsCallback((stats) {
						if (stats.executionId == _executionId) {
							if (scan.duration != null && passedFirstEvent && outputDurationInMilliseconds != null) {
								progress.value = stats.time / outputDurationInMilliseconds;
							}
							passedFirstEvent = true;
						}
					});
					final ffmpegCompleter = Completer<CompletedFFmpegExecution>();
					_executionId = await ffmpeg.executeAsyncWithArguments([
						'-hwaccel', 'auto',
						'-i', inputFile.toString(),
						...extraOptions,
						if (stripAudio) '-an',
						if (outputFileExtension == 'jpg') ...['-qscale:v', '5']
						else ...['-b:v', outputBitrate.toString()],
						if (maximumDurationInSeconds != null) ...['-t', maximumDurationInSeconds.toString()],
						convertedFile.path
					], (c) => ffmpegCompleter.complete(c));
					final results = await ffmpegCompleter.future;
					if (results.returnCode != 0) {
						if (await convertedFile.exists()) {
							await convertedFile.delete();
						}
						throw MediaConversionFFMpegException(results.returnCode);
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
		progress.dispose();
	}

	Future<void> cancel() async {
		if (_executionId != null) {
			FlutterFFmpeg().cancelExecution(_executionId!);
		}
	}
}