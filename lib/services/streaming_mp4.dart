import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
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
	int totalBytes;
	final int statusCode;
	int currentBytes;
	final completer = Completer<void>();
	final lock = Mutex();
	final Map<String, String> headers;

	_CachingFile({
		required this.file,
		required this.totalBytes,
		required this.statusCode,
		this.headers = const {}
	}) : currentBytes = 0;

	@override
	String toString() => '_CachingFile(file: $file, statusCode: $statusCode, currentBytes: $currentBytes, totalBytes: $totalBytes, completer: $completer, lock: $lock, headers: $headers)';
}

typedef _RawRange = ({int start, int? inclusiveEnd});
typedef _Range = ({int start, int inclusiveEnd});

extension _Normalize on _RawRange {
	_Range normalize(int fileLength) => (
		start: start,
		inclusiveEnd: inclusiveEnd ?? (fileLength - 1)
	);
}

class VideoServer {
	final client = HttpClient();
	static VideoServer? _server;
	final Directory webmRoot;
	final Directory httpRoot;
	final Map<String, _CachingFile> _caches = {};
	final Map<String, Set<_CachingFile>> _children = {};
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

	static _RawRange? _parseRange(HttpHeaders headers) {
		final match = RegExp(r'^bytes=(\d+)-(\d+)?$').firstMatch(headers[HttpHeaders.rangeHeader]?.first ?? '');
		if (match != null) {
			return (start: int.parse(match.group(1)!), inclusiveEnd: int.tryParse(match.group(2) ?? ''));
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
		final range = _parseRange(request.headers)?.normalize(fileLength);
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

	Future<void> _serveProxy(HttpRequest request, String digest) async {
		final uri = _decodeDigest(digest);
		try {
			final upstream = await client.getUrl(uri);
			final headers = _caches[digest]?.headers ?? {};
			for (final header in headers.entries) {
				upstream.headers.set(header.key, header.value);
			}
			final range = request.headers[HttpHeaders.rangeHeader]?.tryFirst;
			if (range != null) {
				upstream.headers.set(HttpHeaders.rangeHeader, range);
			}
			final upstreamResponse = await upstream.close();
			request.response.contentLength = upstreamResponse.contentLength;
			if (request.response.contentLength > (1024*50)) {
				// This is not the intent of _serveProxy, it needs to be adjusted
				// Report it to Crashlytics
				Future.error(Exception('Too large proxy serve (${formatFilesize(request.response.contentLength)}) of $uri'), StackTrace.current);
			}
			request.response.statusCode = upstreamResponse.statusCode;
			upstreamResponse.headers.forEach((key, values) {
				request.response.headers.set(key, values.first);
			});
			await request.response.addStream(upstreamResponse);
			await request.response.close();
		}
		on HttpException {
			await request.response.close();
		}
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
		final range = (_parseRange(request.headers) ?? (start: 0, inclusiveEnd: null)).normalize(file.totalBytes);
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
				});
				try {
					await request.response.flush();
					await request.response.close();
				}
				on HttpException {
					// We might be closing the stream prematurely
				}
			});
		}
	}

	File getFile(String digest) => File('${httpRoot.path}/${base64Url.encode(md5.convert(base64Url.decode(digest)).bytes)}');

	File optimisticallyGetFile(Uri uri) => getFile(_encodeDigest(uri));

	Future<void> _handleRequest(HttpRequest request) async {
		request.response.persistentConnection = request.persistentConnection;
		request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
		if (request.method != 'HEAD' && request.method != 'GET') {
			request.response.statusCode = 405;
			await request.response.close();
			return;
		}
		if (request.uri.pathSegments.length > 1 && request.uri.pathSegments.tryFirst == 'digest') {
			if (request.uri.pathSegments.length < 3) {
				request.response.statusCode = 404;
				await request.response.close();
				return;
			}
			final rootDigest = request.uri.pathSegments[1];
			final subpath = request.uri.pathSegments.sublist(2).join('/');
			final String digest;
			if (subpath.startsWith(_kRootUriName)) {
				// This is the root file
				digest = rootDigest;
			}
			else {
				// The subpath is a sibling file to the root
				final rootUri = _decodeDigest(rootDigest);
				final subUri = rootUri.resolve('./$subpath');
				digest = _encodeDigest(subUri);
				try {
					await runEphemerallyLocked(digest, () async {
						_caches[digest] ??= await _startCaching(subUri, _caches[rootDigest]?.headers ?? {});
					});
				}
				on HttpException {
					// Something went wrong starting the download
					request.response.statusCode = 502;
					await request.response.close();
					return;
				}
				_children.putIfAbsent(rootDigest, () => {}).add(_caches[digest]!);
			}
			final file = getFile(digest);
			final currentlyDownloading = _caches[digest];
			if (currentlyDownloading?.completer.isCompleted == false) {
				// File is still downloading
				final range = _parseRange(request.headers);
				if (range != null && range.start > (currentlyDownloading!.currentBytes + 102400) && range.inclusiveEnd == null) {
					// This is likely a request for the end of the file
					// Serve it in parallel to allow playback to start
					_serveProxy(request, digest);
				}
				else {
					// Join and wait for the main download
					_serveDownloadingFile(request, currentlyDownloading!);
				}
			}
			else if (await file.exists()) {
				// File exists, just stream it
				await _serveFile(request, file);
			}
			else {
				// Unrecognized digest
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

	static String _encodeDigest(Uri uri) {
		return base64Url.encode(utf8.encode(uri.toString()));
	}

	static Uri _decodeDigest(String digest) {
		return Uri.parse(utf8.decode(base64Url.decode(digest)));
	}

	Future<_CachingFile> _startCaching(Uri uri, Map<String, String> headers) async {
		final digest = _encodeDigest(uri);
		final httpRequest = await client.getUrl(uri);
		for (final header in headers.entries) {
			httpRequest.headers.set(header.key, header.value);
		}
		final response = await httpRequest.close();
		final file = getFile(digest);
		final cachingFile = _CachingFile(
			file: file,
			totalBytes: response.contentLength,
			statusCode: response.statusCode,
			headers: headers
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
		if (uri.path.endsWith('m3u8')) {
			// contentLength is not trustworthy for some reason...
			await cachingFile.completer.future;
			cachingFile.totalBytes = cachingFile.currentBytes;
		}
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
		final digest = _encodeDigest(uri);
		final existing = _caches[digest]?.completer.isCompleted;
		await runEphemerallyLocked(digest, () async {
			if (existing == null || (existing == true && (force || !getFile(digest).existsSync()))) {
				_caches[digest]?.dispose();
				final cachingFile = await _startCaching(uri, headers);
				void listener() {
					onProgressChanged?.call(cachingFile.currentBytes, cachingFile.totalBytes);
				}
				cachingFile.addListener(listener);
				_caches[digest] = cachingFile;
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
			else {
				final cachingFile = _caches[digest];
				if (cachingFile != null) {
					void listener() {
						onProgressChanged?.call(cachingFile.currentBytes, cachingFile.totalBytes);
					}
					cachingFile.addListener(listener);
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
			}
		});
		return digest;
	}

	Future<void> cleanupCachedDownloadTree(String digest) async {
		for (final item in [
			_caches.remove(digest),
			..._children.remove(digest) ?? <_CachingFile>[]
		]) {
			if (item != null) {
				try {
					await item.file.delete();
				}
				on PathNotFoundException {
					print('Unable to delete ${item.file}');
				}
			}
		}
	}

	static const _kRootUriName = '__chanceroot';

	Uri getUri(String digest) {
		final extensionParts = _decodeDigest(digest).pathSegments.tryLast?.split('.');
		return Uri.http('${InternetAddress.loopbackIPv4.address}:$port', '/digest/$digest/$_kRootUriName${(extensionParts?.isEmpty ?? true) ? '' : '.${extensionParts?.last}'}');
	}

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
	MediaConversion? _joinedConversion;
	MediaConversion? _directConversion;
	final _joinedCompleter = Completer<File>();
	String? _cachingServerDigest;

	StreamingMP4Conversion(this.inputFile, {
		this.headers = const {},
		this.soundSource
	});

	ValueNotifier<double?> _handleJoining(Uri hlsUri) {
		final joinedConversion = _joinedConversion = MediaConversion.toMp4(hlsUri, copyStreams: true);
		joinedConversion.start();
		() async {
			final joined = await joinedConversion.result;
			final expected = MediaConversion.toMp4(inputFile, headers: headers, soundSource: soundSource).getDestination();
			await expected.parent.create(recursive: true);
			await joined.file.rename(expected.path);
			_joinedCompleter.complete(expected);
		}().catchError((e, st) {
			_joinedCompleter.completeError(e, st);
		});
		return joinedConversion.progress;
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

	Future<StreamingMP4ConversionResult> start({bool force = false}) async {
		final inputExtension = inputFile.path.split('.').last.toLowerCase();
		final surelyAudioOnly = ['jpg', 'jpeg', 'png'].contains(inputExtension);
		if (Platform.isAndroid && inputExtension == 'webm') {
			final scan = await MediaScan.scan(inputFile, headers: headers);
			final conversion = _directConversion = MediaConversion.toWebm(inputFile, headers: headers, soundSource: soundSource, stripAudio: false);
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
		if (inputExtension == 'm3u8' && soundSource == null) {
			await VideoServer.instance.ensureRunning();
			final digest = _cachingServerDigest = await VideoServer.instance.startCachingDownload(
				uri: inputFile,
				headers: headers,
				force: force
			);
			final bouncedUri = VideoServer.instance.getUri(digest);
			final joinProgress = _handleJoining(bouncedUri);
			return StreamingMP4ConversionStream(
				hlsStream: bouncedUri,
				mp4File: _joinedCompleter.future,
				progress: joinProgress,
				hasAudio: true, // assumption
				duration: null,
				isAudioOnly: false
			);
		}
		final streamingConversion = _streamingConversion = MediaConversion.toHLS(inputFile, headers: headers, soundSource: soundSource);
		streamingConversion.start();
		streamingConversion.result.then((result) => _handleJoining(result.file.uri));
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
		if (_cachingServerDigest != null) {
			await VideoServer.instance.cleanupCachedDownloadTree(_cachingServerDigest!);
		}
	}

	void cancelIfActive() {
		_streamingConversion?.cancel();
		_directConversion?.cancel();
		_joinedConversion?.cancel();
	}

	void dispose() {
		_waitAndCleanup();
	}
}
