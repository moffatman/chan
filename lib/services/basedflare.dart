import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';
import 'package:chan/services/cookies.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';

/// Check leading half-bytes are zero
bool _checkHash(List<int> hash, int nibbles) {
	for (int i = 0; i < (nibbles ~/ 2); i++) {
		if (hash[i] != 0) {
			return false;
		}
	}
	if (nibbles % 2 == 1 && (hash[nibbles ~/ 2] & 0xF0) != 0) {
		return false;
	}
	return true;
}

class _ChallengeWorkerParam<T> {
	final T config;
	final int workerNumber;
	final int numberOfWorkers;
	final SendPort sendPort;

	const _ChallengeWorkerParam({
		required this.config,
		required this.workerNumber,
		required this.numberOfWorkers,
		required this.sendPort
	});
}

Future<int> _solvePooledChallenge<T>(Future<void> Function(_ChallengeWorkerParam<T>) entryPoint, T config, {CancelToken? cancelToken}) async {
	final numberOfWorkers = sqrt(Platform.numberOfProcessors).ceil();
	final isolates = <(Isolate, ReceivePort)>[];
	for (int i = 0; i < numberOfWorkers; i++) {
		final receivePort = ReceivePort();
		final isolate = await Isolate.spawn(entryPoint, _ChallengeWorkerParam(
			config: config,
			workerNumber: i,
			numberOfWorkers: numberOfWorkers,
			sendPort: receivePort.sendPort
		));
		isolates.add((isolate, receivePort));
	}
	final value = await Future.any([
		...isolates.map((i) => i.$2.first),
		if (cancelToken case final ct?) ct.whenCancel
	]);
	for (final isolate in isolates) {
		isolate.$1.kill();
	}
	if (cancelToken?.isCancelled ?? false) {
		throw value as Object;
	}
	return value as int;
}

typedef _Argon2ChallengeParam = ({
	Uint8List userKey,
	Uint8List challenge,
	int difficulty,
	int time,
	int kb
});

Future<void> _argon2EntryPoint(_ChallengeWorkerParam<_Argon2ChallengeParam> param) async {
	final out = Uint8List(32);
	final generator = Argon2BytesGenerator();
	generator.init(Argon2Parameters(
		Argon2Parameters.ARGON2_id,
		param.config.userKey,
		iterations: param.config.time,
		memory: param.config.kb
	));
	final nibbles = param.config.difficulty ~/ 8;
	for (int i = param.workerNumber;; i += param.numberOfWorkers) {
		final bb = BytesBuilder(copy: false);
		bb.add(param.config.challenge);
		bb.add(latin1.encode(i.toString()));
		generator.generateBytes(bb.takeBytes(), out, 0, 32);
		if (_checkHash(out, nibbles)) {
			param.sendPort.send(i);
			return;
		}
		if (i % 10 == 0) {
			await Future.delayed(Duration.zero); // Yield event loop
		}
	}
}

typedef _Sha256ChallengeParam = ({
	Uint8List salt,
	int difficulty
});

Future<void> _sha256EntryPoint(_ChallengeWorkerParam<_Sha256ChallengeParam> param) async {
	final nibbles = param.config.difficulty ~/ 8;
	for (int i = param.workerNumber;; i += param.numberOfWorkers) {
		final bb = BytesBuilder(copy: false);
		bb.add(param.config.salt);
		bb.add(latin1.encode(i.toString()));
		final out = sha256.convert(bb.takeBytes()).bytes;
		if (_checkHash(out, nibbles)) {
			param.sendPort.send(i);
			return;
		}
		if (i % 10 == 0) {
			await Future.delayed(Duration.zero); // Yield event loop
		}
	}
}

class BasedFlareInterceptor extends Interceptor {
	final Dio client;

	BasedFlareInterceptor(this.client);

	static bool _responseMatches(Response response) {
		if ([403, 503].contains(response.statusCode) && (response.headers.value(Headers.contentTypeHeader)?.contains('text/html') ?? false)) {
			if (response.data is ResponseBody) {
				// Can't really inspect it
				return false;
			}
			if (response.data case String data) {
				return data.contains('basedflare');
			}
			if (response.data case List<int> bytes) {
				final needle = utf8.encode('basedflare');
				outer:
				for (int i = 0; i < bytes.length - needle.length; i++) {
					for (int j = 0; j < needle.length; j++) {
						if (bytes[i + j] != needle[j]) continue outer;
					}
					return true;
				}
			}
		}
		return false;
	}

	Future<Response?> _resolve(Response response) async {
		final location = response.redirects.tryLast?.location ?? response.realUri;
		final document = parse(response.data);
		if (ImageboardRegistry.instance.context case final context?) {
			showToast(
				context: context,
				message: 'Authorizing BasedFlare\n${location.host}',
				icon: CupertinoIcons.cloud
			);
		}
		String? powResponse;
		if (document.body?.attributes case {
			'data-mode': 'argon2',
			'data-kb': String kbStr,
			'data-time': String timeStr,
			'data-diff': String diffStr,
			'data-pow': String powStr
		}) {
			final [userKey, challenge, ...] = powStr.split('#');
			final answer = await _solvePooledChallenge(_argon2EntryPoint, (
				userKey: latin1.encode(userKey),
				challenge: latin1.encode(challenge),
				difficulty: diffStr.parseInt,
				kb: kbStr.parseInt,
				time: timeStr.parseInt,
			));
			powResponse = '$powStr#$answer';
		}
		else if (document.body?.attributes case {
			'data-pow': String powStr,
			'data-diff': String diffStr
		}) {
			final [userKey, challenge, ...] = powStr.split('#');
			final bb = BytesBuilder(copy: false);
			bb.add(latin1.encode(userKey));
			bb.add(latin1.encode(challenge));
			final answer = await _solvePooledChallenge(_sha256EntryPoint, (
				salt: bb.takeBytes(),
				difficulty: diffStr.parseInt
			));
			powResponse = '$powStr#$answer';
		}
		else {
			return null;
		}
		// Submit PoW
		await client.postUri(location, data: {
			'pow_response': powResponse
		}, options: Options(
			followRedirects: false, // dio loses the cookies in the first 303 response
			validateStatus: (status) => (status ?? 0) < 400,
			contentType: Headers.formUrlEncodedContentType,
			extra: {
				kPriority: response.requestOptions.extra[kPriority],
				kExcludeCookies: response.requestOptions.extra[kExcludeCookies]
			}
		), cancelToken: response.requestOptions.cancelToken);
		// Retry the original request
		return await client.fetch(response.requestOptions);
	}

	@override
	void onResponse(Response response, ResponseInterceptorHandler handler) async {
		if (_responseMatches(response)) {
			try {
				final response2 = await _resolve(response);
				if (response2 != null) {
					handler.next(response2);
					return;
				}
			}
			catch (e, st) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: e
				)..stackTrace = st, true);
				return;
			}
		}
		handler.next(response);
	}

	@override
	void onError(DioError err, ErrorInterceptorHandler handler) async {
		if (err.response case final response? when _responseMatches(response)) {
			try {
				final response2 = await _resolve(response);
				if (response2 != null) {
					handler.resolve(response2, true);
					return;
				}
			}
			catch (e, st) {
				handler.reject(DioError(
					requestOptions: response.requestOptions,
					response: response,
					error: e
				)..stackTrace = st, true);
				return;
			}
		}
		handler.next(err);
	}
}