import 'dart:async';
import 'dart:io';

import 'package:chan/services/util.dart';
import 'package:http/http.dart' as http;

import 'package:meta/meta.dart';

import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';

enum WEBMStatusType {
	Idle,
	Converted,
	Downloading,
	Converting,
	Error
}

class WEBMStatus {
	double progress;
	WEBMStatusType type;
	File file;
	String message;
	WEBMStatus({
		this.progress,
		@required this.type,
		this.file,
		this.message
	});
	@override
	String toString() {
		return 'WEBMStatus $type (progress: $progress, message: $message, file: $file)';
	}
}

class WEBM {
	Stream<WEBMStatus> status;
	http.Client client;
	StreamController<WEBMStatus> _statusController = StreamController<WEBMStatus>.broadcast();

	Uri url;

	WEBM({
		@required this.url,
		@required this.client
	}) {
		status = _statusController.stream;
		_statusController.add(WEBMStatus(progress: 0, type: WEBMStatusType.Idle));
	}

	void startProcessing() async {
		try {
			// Assuming only 4Chan urls used
			final filename = url.pathSegments.last;
			final systemTempDirectory = isDesktop() ? Directory('../tmp') : (await getTemporaryDirectory());
			final cacheDirectory = await (new Directory(systemTempDirectory.path + '/webmcache/' + url.host)).create(recursive: true);
			final convertedFile = File(cacheDirectory.path + '/' + filename.replaceFirst('.webm', '.mp4'));
			if (await convertedFile.exists()) {
				_statusController.add(WEBMStatus(type: WEBMStatusType.Converted, file: convertedFile));
			}
			else {
				final webmFile = File(cacheDirectory.path + '/' + filename);
				final response = await client.send(http.Request('GET', url));
				final sink = webmFile.openWrite();
				int received = 0;
				await response.stream.map((packet) {
					received += packet.length;
					_statusController.add(WEBMStatus(type: WEBMStatusType.Downloading, progress: received / response.contentLength));
					return packet;
				}).pipe(sink);
				if (response.statusCode == 200) {
					_statusController.add(WEBMStatus(type: WEBMStatusType.Converting));
					int ffmpegReturnCode;
					if (isDesktop()) {
						final ffmpegResults = await Process.run('ffmpeg', ['-i', webmFile.path, convertedFile.path]);
						ffmpegReturnCode = ffmpegResults.exitCode;
					}
					else {
						final ffmpeg = FlutterFFmpeg();
						final mediaInfo = await ffmpeg.getMediaInformation(webmFile.path);
						final duration = mediaInfo['duration'];
						print('WEBM duration: $duration');
						ffmpeg.enableStatisticsCallback((int time, int size, double bitrate, double speed, int videoFrameNumber, double videoQuality, double videoFps) {
     						print('WEBM time: $time');
							 _statusController.add(WEBMStatus(type: WEBMStatusType.Converting, progress: time / duration));
 						});
						ffmpegReturnCode = await ffmpeg.execute('-i ${webmFile.path} ${convertedFile.path}');
					}
					if (ffmpegReturnCode == 0) {
						await webmFile.delete();
						_statusController.add(WEBMStatus(type: WEBMStatusType.Converted, file: convertedFile));
					}
					else {
						_statusController.add(WEBMStatus(type: WEBMStatusType.Error, message: 'FFmpeg error $ffmpegReturnCode'));
					}
				}
				else {
					_statusController.add(WEBMStatus(type: WEBMStatusType.Error, message: 'HTTP error ${response.statusCode}'));
				}
			}
			_statusController.close();
		}
		catch (error) {
			_statusController.add(WEBMStatus(type: WEBMStatusType.Error, message: 'Unknown error $error'));
			_statusController.close();
		}
	}

	static cleanupCache() {

	}
}