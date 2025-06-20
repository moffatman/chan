import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/services/cloudflare.dart';
import 'package:chan/services/media.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
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
}

class StreamingMP4ConversionStream implements StreamingMP4ConversionResult {
	final Uri hlsStream;
	final Future<File> mp4File;
	final ValueListenable<double?> progress;
	@override
	final bool hasAudio;
	const StreamingMP4ConversionStream({
		required this.hlsStream,
		required this.mp4File,
		required this.progress,
		required this.hasAudio
	});
}

class StreamingMP4ConvertedFile implements StreamingMP4ConversionResult {
	final File mp4File;
	const StreamingMP4ConvertedFile(this.mp4File, this.hasAudio);
	@override
	final bool hasAudio;
}

class StreamingMP4ConvertingFile implements StreamingMP4ConversionResult {
	final Future<File> mp4File;
	final ValueListenable<double?> progress;
	@override
	final bool hasAudio;
	const StreamingMP4ConvertingFile({
		required this.mp4File,
		required this.progress,
		required this.hasAudio
	});
}

class _CachingFile extends EasyListenable {
	final Dio client;
	final File file;
	int totalBytes;
	final int statusCode;
	int currentBytes = 0;
	final completer = Completer<void>();
	final lock = Mutex();
	final Map<String, String> headers;
	CancelToken? _cancelToken;
	bool _interrupted = false;
	final RequestPriority? priority;

	_CachingFile({
		required this.client,
		required this.file,
		required this.totalBytes,
		required this.statusCode,
		this.headers = const {},
		this.priority
	});

	@override
	String toString() => '_CachingFile(file: $file, statusCode: $statusCode, currentBytes: $currentBytes, totalBytes: $totalBytes, completer: $completer, lock: $lock, headers: $headers, priority: $priority)';
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
	static VideoServer? _server;
	final Directory webmRoot;
	final Directory httpRoot;
	final Map<String, CancelToken?> _earlyTokens = {};
	final Map<String, _CachingFile> _caches = {};
	final Map<String, Set<_CachingFile>> _children = {};
	final Map<Uri, DateTime> _earlyGiveUp = {};
	HttpServer? _httpServer;
	bool _stopped = false;
	final bool bufferOutput;
	final int port;
	final int insignificantByteThreshold;
	final _lock = Mutex();

	static void initializeStatic(Directory webmRoot, Directory httpRoot, {
		bool bufferOutput = true,
		int port = 4070,
		int insignificantByteThreshold = 80 << 10 // 80 KB
	}) {
		_server = VideoServer(
			webmRoot: webmRoot,
			httpRoot: httpRoot,
			bufferOutput: bufferOutput,
			port: port,
			insignificantByteThreshold: insignificantByteThreshold
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
		required this.insignificantByteThreshold
	});

	static final _bytesRangePattern = RegExp(r'^bytes=(\d+)-(\d+)?$');

	static _RawRange? _parseRange(HttpHeaders headers) {
		final match = _bytesRangePattern.firstMatch(headers[HttpHeaders.rangeHeader]?.first ?? '');
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
		final fd = file.openRead(range?.start, range?.inclusiveEnd.plus(1));
		await request.response.addStream(fd);
		await request.response.flush();
		await request.response.close();
		try {
			await Future.delayed(const Duration(seconds: 1));
			await fd.drain();
		}
		on FileSystemException {
			// Closed properly, drain wasn't needed
		}
	}

	Future<void> _serveProxy(_CachingFile file, HttpRequest request, String digest) async {
		final uri = _decodeDigest(digest);
		try {
			final range = request.headers[HttpHeaders.rangeHeader]?.tryFirst;
			final upstream = await file.client.getUri(uri, options: Options(
				headers: {
					..._caches[digest]?.headers ?? {},
					if (range != null)
						HttpHeaders.rangeHeader: range
				},
				extra: {
					// Probably image/video bytes won't work
					kRetryIfCloudflare: true,
					kPriority: file.priority
				},
				responseType: ResponseType.stream
			), cancelToken: file._cancelToken);
			final upstreamResponse = upstream.data as ResponseBody;
			request.response.contentLength = upstream.headers.value(Headers.contentLengthHeader)?.tryParseInt ?? -1;
			if (request.response.contentLength > insignificantByteThreshold) {
				// This is not the intent of _serveProxy, it needs to be adjusted
				// Report it to Crashlytics
				Future.error(Exception('Too large proxy serve (${formatFilesize(request.response.contentLength)}) of $uri'), StackTrace.current);
			}
			request.response.statusCode = upstream.statusCode ?? -1;
			upstreamResponse.headers.forEach((key, values) {
				request.response.headers.set(key, values.first);
			});
			await request.response.addStream(upstreamResponse.stream);
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

	// TODO: Maybe switch to base36?
	// Because a lot of filesystems are case-insensitive, the odds of collision here
	// are much higher. My estimate about 99x more likely.
	File getFile(String digest) => httpRoot.file(base64Url.encode(md5.convert(base64Url.decode(digest)).bytes));
	Future<File>? getFutureFile(String digest) => _caches[digest]?.completer.future.then((_) {
		return getFile(digest);
	});

	File? optimisticallyGetFile(Uri uri) {
		final digest = _encodeDigest(uri);
		if (_caches[digest]?.completer.isCompleted == false) {
			return null;
		}
		if (_caches[digest] == null && _earlyTokens.containsKey(digest)) {
			return null;
		}
		return getFile(digest);
	}

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
				final sibling = _caches[rootDigest];
				final subUri = rootUri.resolve('./$subpath');
				digest = _encodeDigest(subUri);
				try {
					await runEphemerallyLocked(digest, () async {
						_caches[digest] ??= await _startCaching(
							sibling?.client ?? Settings.instance.client,
							subUri,
							sibling?.headers ?? {},
							force: false,
							interruptible: false,
							priority: sibling?.priority
						);
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
					_serveProxy(currentlyDownloading, request, digest);
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

	Future<_CachingFile> _startCaching(Dio client, Uri uri, Map<String, String> headers, {
		required bool force,
		required bool interruptible,
		RequestPriority? priority
	}) async {
		final digest = _encodeDigest(uri);
		final file = getFile(digest);
		final stat = await file.stat();
		_CachingFile? cachingFile0;
		CancelToken? interruptibleToken = interruptible ? CancelToken() : null;
		_earlyTokens[digest] = interruptibleToken;
		try {
			if (stat.type == FileSystemEntityType.file) {
				// First HEAD, to see if we have the right size file cached
				final headResponse = await client.headUri(uri, options: Options(
					headers: headers
				), cancelToken: interruptibleToken);
				if ((headResponse.statusCode ?? 500) >= 400) {
					throw HTTPStatusException.fromResponse(headResponse);
				}
				cachingFile0= _CachingFile(
					client: client,
					file: file,
					totalBytes: headResponse.headers.value(Headers.contentLengthHeader)?.tryParseInt ?? -1,
					statusCode: headResponse.statusCode ?? -1,
					headers: headers,
					priority: priority
				);
				if (!force && stat.size == cachingFile0.totalBytes && !uri.path.endsWith('m3u8')) {
					// File is already downloaded and filesize matches
					cachingFile0.currentBytes = cachingFile0.totalBytes;
					cachingFile0.completer.complete();
					return cachingFile0;
				}
				if (interruptible && !force && !uri.path.endsWith('m3u8')) {
					cachingFile0.currentBytes = stat.size;
				}
				else {
					// Corrupt file
					await file.delete();
				}
			}
			// Now GET the file for real
			final response = await client.getUri(uri, options: Options(
				headers: {
					...headers,
					if ((cachingFile0?.currentBytes ?? 0) != 0)
						'Range': 'bytes=${cachingFile0?.currentBytes}-'
				},
				extra: {
					// Probably image/video bytes won't work
					kRetryIfCloudflare: true,
					kPriority: priority
				},
				responseType: ResponseType.stream
			), cancelToken: interruptibleToken);
			if ((response.statusCode ?? 500) >= 400) {
				(response.data as ResponseBody).stream.drain(); // throw it away
				throw HTTPStatusException.fromResponse(response);
			}
			final cachingFile = cachingFile0 ?? _CachingFile(
				client: client,
				file: file,
				totalBytes: response.headers.value(Headers.contentLengthHeader)?.tryParseInt ?? -1,
				statusCode: response.statusCode ?? -1,
				headers: headers,
				priority: priority
			);
			cachingFile._cancelToken = interruptibleToken;
			if (!file.existsSync()) {
				await file.create(recursive: true);
			}
			final handle = await file.open(mode:cachingFile.currentBytes == 0 ? FileMode.writeOnly : FileMode.writeOnlyAppend);
			() async {
				try {
					await for (final chunk in (response.data as ResponseBody).stream) {
						await cachingFile.lock.protect(() async {
							await handle.writeFrom(chunk);
							await handle.flush();
							cachingFile.currentBytes += chunk.length;
							cachingFile.didUpdate();
						});
					}
					await handle.close();
					cachingFile._cancelToken = null;
					cachingFile.completer.complete();
				}
				catch (e, st) {
					handle.close(); // Don't await
					cachingFile._cancelToken = null;
					cachingFile.completer.completeError(e, st);
					if (!(cachingFile._interrupted && e is HttpException)) {
						print('Deleting file');
						await file.delete();
					}
					else {
						print('Not deleting file');
					}
				}
			}();
			if (uri.path.endsWith('m3u8')) {
				// contentLength is not trustworthy for some reason...
				await cachingFile.completer.future;
				cachingFile.totalBytes = cachingFile.currentBytes;
			}
			return cachingFile;
		}
		finally {
			_earlyTokens.remove(digest);
		}
	}

	Future<String> startCachingDownload({
		Dio? client,
		RequestPriority? priority,
		required Uri uri,
		Map<String, String> headers = const {},
		void Function(File file)? onCached,
		void Function(int currentBytes, int totalBytes)? onProgressChanged,
		bool force = false,
		bool interruptible = false
	}) async {
		await ensureRunning();
		final digest = _encodeDigest(uri);
		final existing = _caches[digest]?.completer.isCompleted;
		await runEphemerallyLocked(digest, () async {
			if (existing == null || (existing == true && (force || !getFile(digest).existsSync()))) {
				_caches[digest]?.dispose();
				final cachingFile = await _startCaching(
					client ?? Settings.instance.client,
					uri,
					headers,
					force: force,
					interruptible: interruptible,
					priority: priority
				);
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

	Future<File> cachingDownload({
		required Dio client,
		required Uri uri,
		Map<String, String> headers = const {},
		void Function(int currentBytes, int totalBytes)? onProgressChanged,
		bool force = false,
		bool interruptible = false
	}) async {
		final digest = await startCachingDownload(
			client: client,
			uri: uri,
			headers: headers,
			onProgressChanged: onProgressChanged,
			force: force,
			interruptible: interruptible
		);
		await _caches[digest]?.completer.future;
		return getFile(digest);
	}

	Future<void> interruptEarlyDownloadFromUri(Uri? uri) async {
		if (uri == null) {
			return;
		}
		_earlyGiveUp[uri] = DateTime.now();
	}

	Future<void> interruptOngoingDownloadFromUri(Uri url) async {
		final digest = _encodeDigest(url);
		interruptEarlyDownloadFromUri(url);
		final cachingFile = _caches[digest];
		if (cachingFile == null) {
			_earlyTokens[digest]?.cancel();
			return;
		}
		if (cachingFile._cancelToken == null) {
			// Not interruptible
			return;
		}
		if ((cachingFile.totalBytes - cachingFile.currentBytes) < insignificantByteThreshold) {
			// Just let it finish
			return;
		}
		cachingFile._interrupted = true;
		cachingFile._cancelToken?.cancel();
		_caches.remove(digest);
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

	Future<void> cleanupCachedDownloadTreeFromUri(Uri uri) async {
		await cleanupCachedDownloadTree(_encodeDigest(uri));
	}

	static const _kRootUriName = '__chanceroot';

	Uri getUri(String digest) {
		final extensionParts = _decodeDigest(digest).pathSegments.tryLast?.split('.');
		return Uri.http('${InternetAddress.loopbackIPv4.address}:$port', '/digest/$digest/$_kRootUriName${(extensionParts?.isEmpty ?? true) ? '' : '.${extensionParts?.last}'}');
	}

	Future<void> ensureRunning() => _lock.protect(() async {
		if (_httpServer == null) {
			final h = _httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);
			h.listen(_handleRequest, cancelOnError: false, onDone: () => _lock.protect(() async {
				if (h == _httpServer) {
					_httpServer = null;
					if (!_stopped) {
						Future.microtask(ensureRunning);
					}
				}
			}));
		}
	});

	Future<void> restartIfRunning() => _lock.protect(() async {
		final h = _httpServer;
		if (h != null) {
			try {
				await h.close().timeout(const Duration(seconds: 1));
			}
			on TimeoutException {
				await h.close(force: true);
			}
		}
	});

	void dispose() {
		_stopped = true;
		_httpServer?.close();
		_httpServer = null;
	}
}

Uri getCachingURL(Response x) {
	throw UnimplementedError();
}

Future<String> getCachedPath(String uri) async {
	throw UnimplementedError();
}

class StreamingMP4Conversion {
	final Dio client;
	final Uri inputFile;
	final Map<String, String> headers;
	final Uri? soundSource;

	MediaConversion? _streamingConversion;
	MediaConversion? _joinedConversion;
	MediaConversion? _directConversion;
	final _joinedCompleter = Completer<File>();
	String? _cachingServerDigest;

	StreamingMP4Conversion(this.client, this.inputFile, {
		this.headers = const {},
		this.soundSource
	});

	ValueNotifier<double?> _handleJoining(Uri hlsUri) {
		final joinedConversion = _joinedConversion = MediaConversion.toMp4(hlsUri, copyStreams: true);
		() async {
			final joined = await joinedConversion.start();
			final expected = MediaConversion.toMp4(inputFile, headers: headers, soundSource: soundSource).getDestination();
			await expected.parent.create(recursive: true);
			await joined.file.rename(expected.path);
			_joinedCompleter.complete(expected);
		}().catchError((Object e, StackTrace st) {
			_joinedCompleter.completeError(e, st);
		});
		return joinedConversion.progress;
	}

	Future<bool> _areThereTwoTSFiles(Directory parent) async {
		return await parent.list().where((c) => c.path.endsWith('.ts')).length > 2;
	}

	Future<void> _waitForTwoTSFiles(Directory parent) async {
		int times = 0;
		while (times < 300) {
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
		if (inputExtension == 'gif' && soundSource != null) {
			// Two stages, to avoid network + performance hit of ffmpeg looping unconvered input gif
			final conversion1 = _streamingConversion = MediaConversion.toWebm(inputFile, headers: headers, stripAudio: false, targetBitrate: 400000);
			final conversion2 = _joinedConversion = MediaConversion.toWebm(conversion1.getDestination().uri, soundSource: soundSource, stripAudio: false, copyStreams: true);
			return StreamingMP4ConvertingFile(
				mp4File: conversion1.start().then((r) async {
					final file = (await conversion2.start()).file;
					_joinedCompleter.complete(file); // To allow cleanup in _waitAndCleanup
					return file;
				}),
				hasAudio: true,
				progress: CombiningValueListenable(
					children: [conversion1.progress, conversion2.progress],
					combine: (progresses) {
						if (progresses.every((p) => p == null)) {
							return null;
						}
						return progresses.fold<double>(0, (t, v) => t + ((v ?? 0) / progresses.length));
					}
				)
			);
		}
		else if (['jpg', 'jpeg', 'png', 'webm'].contains(inputExtension) && (soundSource != null || Platform.isAndroid)) {
			final scan = await MediaScan.scan(inputFile, headers: headers);
			final conversion = _directConversion = MediaConversion.toWebm(inputFile, headers: headers, soundSource: soundSource, stripAudio: false, copyStreams: soundSource != null && inputExtension == 'webm');
			return StreamingMP4ConvertingFile(
				mp4File: conversion.start().then((r) => r.file),
				hasAudio: scan.hasAudio || soundSource != null,
				progress: conversion.progress
			);
		}
		final mp4Conversion = MediaConversion.toMp4(inputFile, headers: headers, soundSource: soundSource);
		final existingResult = await mp4Conversion.getDestinationIfSatisfiesConstraints();
		if (existingResult != null) {
			return StreamingMP4ConvertedFile(existingResult.file, existingResult.hasAudio);
		}
		if (inputExtension == 'm3u8' && soundSource == null) {
			await VideoServer.instance.ensureRunning();
			final digest = _cachingServerDigest = await VideoServer.instance.startCachingDownload(
				client: client,
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
			);
		}
		final streamingConversion = _streamingConversion = MediaConversion.toHLS(
			inputFile,
			headers: headers,
			soundSource: soundSource,
			copyStreams: inputExtension == 'm3u8' || (soundSource != null && inputExtension == 'mp4')
		);
		final streamingConversionFuture = streamingConversion.start();
		streamingConversionFuture.then((result) => _handleJoining(result.file.uri));
		await Future.any([_waitForTwoTSFiles(streamingConversion.getDestination().parent), streamingConversionFuture]);
		if (await _areThereTwoTSFiles(streamingConversion.getDestination().parent)) {
			await Future.delayed(const Duration(milliseconds: 50));
			await VideoServer.instance.ensureRunning();
			return StreamingMP4ConversionStream(
				hlsStream: Uri(
					scheme: 'http',
					host: 'localhost',
					port: VideoServer.instance.port,
					path: streamingConversion.getDestination().path.replaceFirst('${Persistence.webmCacheDirectory.path}/', '')
				),
				progress: streamingConversion.progress,
				mp4File: _joinedCompleter.future,
				hasAudio: soundSource != null || (streamingConversion.cachedScan?.hasAudio ?? false)
			);
		}
		else {
			// Better to just wait and return the mp4
			final file = await _joinedCompleter.future;
			return StreamingMP4ConvertedFile(file, soundSource != null || (streamingConversion.cachedScan?.hasAudio ?? false));
		}
	}

	Future<void> _waitAndCleanup() async {
		await _joinedCompleter.future;
		FileSystemEntity? tmp = _streamingConversion?.getDestination();
		if (_streamingConversion?.requiresSubdirectory ?? false) {
			tmp = tmp?.parent;
		}
		if (tmp != null) {
			tmp.delete(recursive: true);
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
