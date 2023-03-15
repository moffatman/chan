import 'dart:async';
import 'dart:io';

import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

abstract class StreamingMP4ConversionResult {
	bool get hasAudio;
	Duration? get duration;
	bool get isAudioOnly;
}

class StreamingMP4ConversionStream implements StreamingMP4ConversionResult {
	final Uri hlsStream;
	final Future<File> mp4File;
	final ValueListenable<double?> progress;
	@override
	final bool hasAudio;
	@override
	final Duration? duration;
	@override
	final bool isAudioOnly;
	const StreamingMP4ConversionStream({
		required this.hlsStream,
		required this.mp4File,
		required this.progress,
		required this.hasAudio,
		required this.duration,
		required this.isAudioOnly
	});
}

class StreamingMP4ConvertedFile implements StreamingMP4ConversionResult {
	final File mp4File;
	const StreamingMP4ConvertedFile(this.mp4File, this.hasAudio, this.isAudioOnly);
	@override
	final bool hasAudio;
	@override
	final bool isAudioOnly;
	@override
	Duration? get duration => null;
}

final _server = _Server();

class _Server {
	HttpServer? _httpServer;

	Future<void> _handleRequest(HttpRequest request) async {
		final root = '${Persistence.temporaryDirectory.path}/webmcache';
		final file = File('$root${Uri.decodeFull(request.uri.path)}');
		if (!await file.exists() || !file.parent.path.startsWith(root)) {
			request.response.statusCode = 404;
			await request.response.close();
			return;
		}
		request.response.contentLength = await file.length();
		request.response.headers.set(HttpHeaders.contentTypeHeader, lookupMimeType(file.path) ?? 'video/mp4');
		await request.response.addStream(file.openRead());
		await request.response.close();
	}

	Future<void> ensureRunning() async {
		if (_httpServer == null) {
			_httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
			_httpServer!.listen(_handleRequest, cancelOnError: false, onDone: () {
				_httpServer = null;
				ensureRunning();
			});
		}
	}

	Future<void> restartIfRunning() async {
		if (_httpServer != null) {
			await () async {
				await _httpServer?.close();
			}().timeout(const Duration(seconds: 1), onTimeout: () async {
				await _httpServer?.close(force: true);
			});
		}
	}

	static const port = 4070;
}

Future<void> restartServerIfRunning() async {
	await _server.restartIfRunning();
}

class StreamingMP4Conversion {
	final Uri inputFile;
	final Map<String, String> headers;
	final Uri? soundSource;

	MediaConversion? _streamingConversion;
	final _joinedCompleter = Completer<File>();

	StreamingMP4Conversion(this.inputFile, {
		this.headers = const {},
		this.soundSource
	});

	Future<void> _handleJoining(MediaConversion streamingConversion) async {
		try {
			final joinedConversion = MediaConversion.toMp4((await streamingConversion.result).file.uri, copyStreams: true);
			joinedConversion.start();
			final joined = await joinedConversion.result;
			final expected = MediaConversion.toMp4(inputFile, headers: headers, soundSource: soundSource).getDestination();
			await joined.file.rename(expected.path);
			_joinedCompleter.complete(expected);
		}
		catch (e, st) {
			_joinedCompleter.completeError(e, st);
		}
	}

	Future<bool> _areThereTwoTSFiles(Directory parent) async {
		return await parent.list().where((c) => c.path.endsWith('.ts')).length > 2;
	}

	Future<void> _waitForTwoTSFiles(Directory parent) async {
		int times = 0;
		while (times < 100) {
			if (await _areThereTwoTSFiles(parent)) {
				// At least two ts files created
				break;
			}
			await Future.delayed(const Duration(milliseconds: 150));
			times++;
		}
	}

	Future<StreamingMP4ConversionResult> start() async {
		final surelyAudioOnly = ['jpg', 'jpeg', 'png'].contains(inputFile.path.split('.').last.toLowerCase());
		final mp4Conversion = MediaConversion.toMp4(inputFile, headers: headers, soundSource: soundSource);
		final existingResult = await mp4Conversion.getDestinationIfSatisfiesConstraints();
		if (existingResult != null) {
			return StreamingMP4ConvertedFile(existingResult.file, existingResult.hasAudio, existingResult.isAudioOnly);
		}
		final streamingConversion = _streamingConversion = MediaConversion.toHLS(inputFile, headers: headers, soundSource: soundSource);
		streamingConversion.start();
		_handleJoining(streamingConversion);
		await Future.any([_waitForTwoTSFiles(streamingConversion.getDestination().parent), streamingConversion.result]);
		if (await _areThereTwoTSFiles(streamingConversion.getDestination().parent)) {
			await Future.delayed(const Duration(milliseconds: 50));
			await _server.ensureRunning();
			return StreamingMP4ConversionStream(
				hlsStream: Uri(
					scheme: 'http',
					host: 'localhost',
					port: _Server.port,
					path: streamingConversion.getDestination().path.replaceFirst('${Persistence.temporaryDirectory.path}/webmcache/', '')
				),
				progress: streamingConversion.progress,
				mp4File: _joinedCompleter.future,
				hasAudio: streamingConversion.cachedScan?.hasAudio ?? false,
				duration: streamingConversion.cachedScan?.duration,
				isAudioOnly: surelyAudioOnly || (streamingConversion.cachedScan?.isAudioOnly ?? false)
			);
		}
		else {
			// Better to just wait and return the mp4
			final file = await _joinedCompleter.future;
			return StreamingMP4ConvertedFile(file, streamingConversion.cachedScan?.hasAudio ?? false, surelyAudioOnly || (streamingConversion.cachedScan?.isAudioOnly ?? false));
		}
	}

	void dispose() {
		final junkFolder = _streamingConversion?.getDestination().parent;
		if (junkFolder != null) {
			junkFolder.delete(recursive: true);
		}
	}
}
