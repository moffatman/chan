
import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/util.dart';
import 'package:chan/version.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:mutex/mutex.dart';

class LoggingInterceptor extends Interceptor {
	final path = '${Persistence.temporaryDirectory.path}/network.log';
	late final IOSink file = File(path).openWrite();
	final lock = Mutex();
	static final instance = LoggingInterceptor._();

	Future<void> reportViaShareSheet(BuildContext context) async => lock.protect(() async {
		final gzippedPath = '$path.gz';
		await copyGzipped(path, gzippedPath);
		if (!context.mounted) return;
		await shareOne(
			context: context,
			text: gzippedPath,
			subject: FileBasename.get(gzippedPath),
			type: 'file',
			sharePositionOrigin: null
		);
	});

	Future<void> reportViaEmail() async => lock.protect(() async {
		final gzippedPath = '$path.gz';
		await copyGzipped(path, gzippedPath);
		FlutterEmailSender.send(Email(
			subject: 'Chance Network Logs',
			recipients: ['callum@moffatman.com'],
			attachmentPaths: [gzippedPath],
			body: '''Hi Callum,
							Chance v$kChanceVersion is giving me a problem:
							'''
		));
	});

	LoggingInterceptor._();

	@override
	void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
		lock.protect(() async {
			file.writeln('== onRequest(${identityHashCode(options)}) ${DateTime.now()} ${options.uri} ${options.method} ==');
			file.writeln(options.headers);
			final data = options.data;
			if (data != null) {
				if (data is FormData) {
					file.writeln(data.fields);
					file.writeln(data.files);
				}
				else {
					file.writeln(data);
				}
			}
			await file.flush();
		});
		handler.next(options);
	}

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
		lock.protect(() async {
			file.writeln('== onResponse(${identityHashCode(response.requestOptions)}) ${DateTime.now()} ${response.requestOptions.uri} ${response.requestOptions.method} ${response.statusCode} ==');
			file.writeln(response.headers);
			if (response.requestOptions.method != 'GET') {
				file.writeln(response.data);
			}
			else {
				final resp = response.data.toString();
				if (resp.length > 1500) {
					file.write(resp.substring(0, 750));
					file.writeln('...');
					file.writeln(resp.substring(resp.length - 750));
				}
				else {
					file.writeln(resp);
				}
			}
			await file.flush();
		});
		handler.next(response);
	}

	@override
  void onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) {
		lock.protect(() async {
			file.writeln('== onError(${identityHashCode(err.requestOptions)}) ${DateTime.now()} ${err.requestOptions.uri} ${err.response?.statusCode} ==');
			file.writeln(err.response?.headers);
			file.writeln(err.response?.data);
			file.writeln(err.error);
			await file.flush();
		});
		handler.next(err);
	}
}
