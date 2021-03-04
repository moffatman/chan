import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/services/util.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';

class WEBMStatus {

}

class WEBMLoadingStatus extends WEBMStatus {
	final double? progress;
	WEBMLoadingStatus([this.progress]);
	@override
	String toString() {
		return 'WEBMLoadingStatus (progress: $progress)';
	}
}

class WEBMReadyStatus extends WEBMStatus {
	final File file;
	WEBMReadyStatus(this.file);
	@override
	String toString() {
		return 'WEBMReadyStatus (file: ${file.path})';
	}
}

class WEBMErrorStatus extends WEBMStatus {
	String errorMessage;
	WEBMErrorStatus(this.errorMessage);
	@override
	String toString() {
		return 'WEBMErrorStatus (errorMessage: $errorMessage)';
	}
}

class WEBM {
	late Stream<WEBMStatus> status;
	http.Client client;
	StreamController<WEBMStatus> _statusController = StreamController<WEBMStatus>.broadcast();

	Uri url;

	WEBM({
		required this.url,
		required this.client
	}) {
		status = _statusController.stream;
	}

	void startProcessing() async {
		try {
			// Assuming only 4Chan urls used
			final filename = url.pathSegments.last;
			final systemTempDirectory = await getTemporaryDirectory();
			final cacheDirectory = await (new Directory(systemTempDirectory.path + '/webmcache/' + url.host)).create(recursive: true);
			final convertedFile = File(cacheDirectory.path + '/' + filename.replaceFirst('.webm', '.mp4'));
			if (await convertedFile.exists()) {
				_statusController.add(WEBMReadyStatus(convertedFile));
			}
			else {
				_statusController.add(WEBMLoadingStatus());
				int ffmpegReturnCode;
				if (isDesktop()) {
					print('Using Process.start');
					final ffmpeg = await Process.start('ffmpeg', ['-hwaccel', 'auto', '-i', url.toString(), '-crf', '18', convertedFile.path]);
					print('Process started');
					ffmpeg.stdout.transform(Utf8Decoder()).transform(LineSplitter()).listen((line) {
						print(line);
					});
					ffmpeg.stderr.transform(Utf8Decoder()).transform(LineSplitter()).listen((line) {
						print(line);
					});
					ffmpegReturnCode = await ffmpeg.exitCode;
				}
				else {
					print('Using FlutterFFmpeg');
					final ffconfig = FlutterFFmpegConfig();
					final ffprobe = FlutterFFprobe();
					final ffmpeg = FlutterFFmpeg();
					final mediaInfo = (await ffprobe.getMediaInformation(url.toString())).getAllProperties();
					final duration = double.tryParse(mediaInfo['format']?['duration'] ?? '');
					final bitrate = int.tryParse(mediaInfo['format']?['bit_rate'] ?? '') ?? (2e6 as int);
					ffconfig.enableStatisticsCallback((stats) {
						if (duration != null) {
							_statusController.add(WEBMLoadingStatus(0.001 * (stats.time / duration)));
						}
					});
					String options = '';
					if (Platform.isAndroid) {
						options = '-c:v libx264 -preset ultrafast';
					}
					else if (Platform.isIOS) {
						options = '-vcodec h264_videotoolbox';
					}
					ffmpegReturnCode = await ffmpeg.execute('-hwaccel auto -i ${url.toString()} $options -b:v $bitrate ${convertedFile.path}');
				}
				if (ffmpegReturnCode == 0) {
					_statusController.add(WEBMReadyStatus(convertedFile));
				}
				else {
					if (await convertedFile.exists()) {
						await convertedFile.delete();
					}
					_statusController.add(WEBMErrorStatus('FFmpeg error $ffmpegReturnCode'));
				}
			}
			_statusController.close();
		}
		catch (error, stackTrace) {
			print(stackTrace);
			_statusController.add(WEBMErrorStatus('Unknown error $error'));
			_statusController.close();
		}
	}

	static cleanupCache() {

	}
}