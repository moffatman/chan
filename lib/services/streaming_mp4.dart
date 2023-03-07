import 'dart:async';
import 'dart:io';

import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

abstract class StreamingMP4ConversionResult {
	bool get hasAudio;
	Duration? get duration;
}

class StreamingMP4ConversionStream implements StreamingMP4ConversionResult {
	final Uri hlsStream;
	final Future<File> mp4File;
	final ValueListenable<double?> progress;
	@override
	final bool hasAudio;
	@override
	final Duration? duration;
	const StreamingMP4ConversionStream({
		required this.hlsStream,
		required this.mp4File,
		required this.progress,
		required this.hasAudio,
		required this.duration
	});
}

class StreamingMP4ConvertedFile implements StreamingMP4ConversionResult {
	final File mp4File;
	const StreamingMP4ConvertedFile(this.mp4File, this.hasAudio, this.isAudioOnly);
	@override
	final bool hasAudio;
	final bool isAudioOnly;
	@override
	Duration? get duration => null;
}

(HttpServer, StreamSubscription<HttpRequest>)? _server;

void _handleRequest(HttpRequest request) async {
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

Future<(HttpServer, StreamSubscription<HttpRequest>)> _startServer() async {
	final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
	print('started http server on port ${server.port}');
	final stream = server.listen(_handleRequest, cancelOnError: false);
	return (server, stream);
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
		_server ??= await _startServer();
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
			return StreamingMP4ConversionStream(
				hlsStream: Uri(
					scheme: 'http',
					host: 'localhost',
					port: _server!.$1.port,
					path: streamingConversion.getDestination().path.replaceFirst('${Persistence.temporaryDirectory.path}/webmcache/', '')
				),
				progress: streamingConversion.progress,
				mp4File: _joinedCompleter.future,
				hasAudio: streamingConversion.cachedScan?.hasAudio ?? false,
				duration: streamingConversion.cachedScan?.duration
			);
		}
		else {
			// Better to just wait and return the mp4
			final file = await _joinedCompleter.future;
			return StreamingMP4ConvertedFile(file, streamingConversion.cachedScan?.hasAudio ?? false, streamingConversion.cachedScan?.isAudioOnly ?? false);
		}
	}

	void dispose() {
		final junkFolder = _streamingConversion?.getDestination().parent;
		if (junkFolder != null) {
			junkFolder.delete(recursive: true);
		}
	}
}
