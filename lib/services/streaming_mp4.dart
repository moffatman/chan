import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/util.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:mutex/mutex.dart';

extension _NullMath on int? {
	int? plus(int other) => this == null ? null : this! + other;
}

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

class StreamingMP4ConvertingFile implements StreamingMP4ConversionResult {
	final Future<File> mp4File;
	final ValueListenable<double?> progress;
	@override
	final bool hasAudio;
	@override
	final Duration? duration;
	@override
	final bool isAudioOnly;
	const StreamingMP4ConvertingFile({
		required this.mp4File,
		required this.progress,
		required this.hasAudio,
		required this.duration,
		required this.isAudioOnly
	});
}

class _CachingFile extends EasyListenable {
	final File file;
	final int totalBytes;
	final int statusCode;
	int currentBytes;
	final completer = Completer<void>();
	final lock = Mutex();

	_CachingFile({
		required this.file,
		required this.totalBytes,
		required this.statusCode
	}) : currentBytes = 0;
}

class VideoServer {
	final client = HttpClient();
	static VideoServer? _server;
	final Directory webmRoot;
	final Directory httpRoot;
	final Map<String, _CachingFile> _caches = {};
	HttpServer? _httpServer;
	bool _stopped = false;
	final bool bufferOutput;
	final int port;

	static void initializeStatic(Directory webmRoot, Directory httpRoot, {bool bufferOutput = true, int port = 4070}) {
		_server = VideoServer(
			webmRoot: webmRoot,
			httpRoot: httpRoot,
			bufferOutput: bufferOutput,
			port: port
		);
	}

	static void teardownStatic() {
		_server?.dispose();
		_server = null;
	}

	static VideoServer get instance => _server!;

	VideoServer({
		required this.webmRoot,
		required this.httpRoot,
		required this.bufferOutput,
		required this.port,
	});

	static ({int start, int inclusiveEnd})? _parseRange(HttpHeaders headers) {
		final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(headers[HttpHeaders.rangeHeader]?.first ?? '');
		if (match != null) {
			return (start: int.parse(match.group(1)!), inclusiveEnd: int.parse(match.group(2)!));
		}
		return null;
	}

	Future<void> _serveFile(HttpRequest request, File file) async {
		final fileLength = await file.length();
		request.response.headers.set(HttpHeaders.contentTypeHeader, lookupMimeType(file.path) ?? 'video/mp4');
		request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
		if (request.method == 'HEAD') {
			request.response.contentLength = fileLength;
			await request.response.close();
			return;
		}
		final range = _parseRange(request.headers);
		if (range != null) {
			request.response.statusCode = HttpStatus.partialContent;
			request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes ${range.start}-${range.inclusiveEnd}/$fileLength');
			request.response.contentLength = (range.inclusiveEnd - range.start) + 1;
		}
		else {
			request.response.contentLength = fileLength;
		}
		await request.response.addStream(file.openRead(range?.start, range?.inclusiveEnd.plus(1)));
		await request.response.close();
	}

	Future<void> _serveDownloadingFile(HttpRequest request, _CachingFile file) async {
		request.response.bufferOutput = bufferOutput;
		request.response.headers.set(HttpHeaders.contentTypeHeader, lookupMimeType(file.file.path) ?? 'video/mp4');
		request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
		request.response.statusCode = file.statusCode;
		if (request.method == 'HEAD') {
			request.response.contentLength = file.totalBytes;
			await request.response.close();
			return;
		}
		final range = _parseRange(request.headers) ?? (start: 0, inclusiveEnd: file.totalBytes - 1);
		if ((1 + range.inclusiveEnd - range.start) != file.totalBytes) {
			request.response.statusCode = HttpStatus.partialContent;
			request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes ${range.start}-${range.inclusiveEnd}/${file.totalBytes}');
		}
		request.response.contentLength = 1 + range.inclusiveEnd - range.start;
		await request.response.flush();
		final handle = await file.file.open();
		int lastBytes = 0;
		final completer = Completer<void>();
		final lock = Mutex();
		void listener() {
			lock.protect(() async {
				final currentBytes = file.currentBytes;
				if (lastBytes == currentBytes) {
					return;
				}
				if (currentBytes < range.start) {
					lastBytes = currentBytes;
					return;
				}
				if (lastBytes >= range.inclusiveEnd) {
					return;
				}
				final chunkStart = max(lastBytes, range.start);
				final chunkEnd = min(currentBytes, range.inclusiveEnd + 1);
				final chunk = await file.lock.protect(() async {
					await handle.setPosition(chunkStart);
					return await handle.read(chunkEnd - chunkStart);
				});
				request.response.add(chunk);
				//await request.response.flush();
				lastBytes = currentBytes;
				if (currentBytes >= range.inclusiveEnd) {
					completer.complete();
				}
			});
		}
		file.addListener(listener);
		listener();
		try {
			await Future.any([completer.future, file.completer.future]);
		}
		on HttpException {
			// Something went wrong
		}
		finally {
			await lock.protect(() async {
				await file.lock.protect(() async {
					file.removeListener(listener);
					await handle.close();
					try {
						await request.response.close();
					}
					on HttpException {
						// We might be closing the stream prematurely
					}
				});
			});
		}
	}

	File getFile(String hash) => File('${httpRoot.path}/$hash');

	File optimisticallyGetFile(Uri uri) => getFile(_makeHash(uri));

	Future<void> _handleRequest(HttpRequest request) async {
		request.response.persistentConnection = request.persistentConnection;
		request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
		if (request.method != 'HEAD' && request.method != 'GET') {
			request.response.statusCode = 405;
			await request.response.close();
			return;
		}
		if (request.uri.path == '/') {
			final String hash = request.uri.queryParameters['hash']!;
			final file = getFile(hash);
			final currentlyDownloading = _caches[hash];
			if (currentlyDownloading?.completer.isCompleted == false) {
				// File is still downloading
				_serveDownloadingFile(request, currentlyDownloading!);
			}
			else if (await file.exists()) {
				// File exists, just stream it
				await _serveFile(request, file);
			}
			else {
				// Unrecognized hash
				request.response.statusCode = 404;
				await request.response.close();
			}
		}
		else {
			final file = File('${webmRoot.path}${Uri.decodeFull(request.uri.path)}');
			if (!await file.exists() || !file.parent.path.startsWith(webmRoot.path)) {
				request.response.statusCode = 404;
				await request.response.close();
				return;
			}
			await _serveFile(request, file);
		}
	}

	static String _makeHash(Uri uri) {
		final hash = base64UrlEncode(md5.convert(utf8.encode(uri.toString())).bytes);
		return '$hash.${uri.path.split('.').last}';
	}

	Future<_CachingFile> _startCaching(Uri uri, Map<String, String> headers) async {
		final hash = _makeHash(uri);
		final httpRequest = await client.getUrl(uri);
		for (final header in headers.entries) {
			httpRequest.headers.set(header.key, header.value);
		}
		final response = await httpRequest.close();
		final file = getFile(hash);
		final cachingFile = _CachingFile(
			file: file,
			totalBytes: response.contentLength,
			statusCode: response.statusCode
		);
		final handle = await file.open(mode: FileMode.writeOnly);
		() async {
			try {
				await for (final chunk in response) {
					await cachingFile.lock.protect(() async {
						await handle.writeFrom(chunk);
						await handle.flush();
						cachingFile.currentBytes += chunk.length;
						cachingFile.didUpdate();
					});
				}
				cachingFile.completer.complete();
			}
			catch (e, st) {
				cachingFile.completer.completeError(e, st);
				await file.delete();
			}
		}();
		return cachingFile;
	}

	Future<String> startCachingDownload({
		required Uri uri,
		Map<String, String> headers = const {},
		void Function(File file)? onCached,
		void Function(int currentBytes, int totalBytes)? onProgressChanged,
		bool force = false
	}) async {
		await ensureRunning();
		final hash = _makeHash(uri);
		final existing = _caches[hash]?.completer.isCompleted;
		if (existing == null || (existing == true && (force || !getFile(hash).existsSync()))) {
			_caches[hash]?.dispose();
			final cachingFile = await _startCaching(uri, headers);
			void listener() {
				onProgressChanged?.call(cachingFile.currentBytes, cachingFile.totalBytes);
			}
			cachingFile.addListener(listener);
			_caches[hash] = cachingFile;
			() async {
				try {
					await cachingFile.completer.future;
					onCached?.call(cachingFile.file);
				}
				on HttpException {
					// Something went wrong
				}
				finally {
					cachingFile.removeListener(listener);
				}
			}();
		}
		return hash;
	}

	Uri getUri(String hash) => Uri.http('${InternetAddress.loopbackIPv4.address}:$port', '/', {
		'hash': hash
	});

	Future<void> ensureRunning() async {
		if (_httpServer == null) {
			_httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
			_httpServer!.listen(_handleRequest, cancelOnError: false, onDone: () {
				_httpServer = null;
				if (!_stopped) {
					ensureRunning();
				}
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

	void dispose() {
		_stopped = true;
		_httpServer?.close();
	}
}

Uri getCachingURL(Response x) {
	throw UnimplementedError();
}

Future<String> getCachedPath(String uri) async {
	throw UnimplementedError();
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
		if (Platform.isAndroid) {
			final scan = await MediaScan.scan(inputFile, headers: headers);
			final conversion = MediaConversion.toWebm(inputFile, headers: headers, soundSource: soundSource, stripAudio: false);
			conversion.start();
			return StreamingMP4ConvertingFile(
				mp4File: conversion.result.then((r) => r.file),
				hasAudio: scan.hasAudio,
				progress: conversion.progress,
				duration: scan.duration,
				isAudioOnly: surelyAudioOnly || scan.isAudioOnly
			);
		}
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
			await VideoServer.instance.ensureRunning();
			return StreamingMP4ConversionStream(
				hlsStream: Uri(
					scheme: 'http',
					host: 'localhost',
					port: VideoServer.instance.port,
					path: streamingConversion.getDestination().path.replaceFirst('${Persistence.temporaryDirectory.path}/webmcache/', '')
				),
				progress: streamingConversion.progress,
				mp4File: _joinedCompleter.future,
				hasAudio: soundSource != null || (streamingConversion.cachedScan?.hasAudio ?? false),
				duration: streamingConversion.cachedScan?.duration,
				isAudioOnly: surelyAudioOnly || (streamingConversion.cachedScan?.isAudioOnly ?? false)
			);
		}
		else {
			// Better to just wait and return the mp4
			final file = await _joinedCompleter.future;
			return StreamingMP4ConvertedFile(file, soundSource != null || (streamingConversion.cachedScan?.hasAudio ?? false), surelyAudioOnly || (streamingConversion.cachedScan?.isAudioOnly ?? false));
		}
	}

	Future<void> _waitAndCleanup() async {
		await _joinedCompleter.future;
		final junkFolder = _streamingConversion?.getDestination().parent;
		if (junkFolder != null) {
			junkFolder.delete(recursive: true);
		}
	}

	void dispose() {
		_waitAndCleanup();
	}
}
