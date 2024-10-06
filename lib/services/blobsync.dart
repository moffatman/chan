import 'dart:typed_data';

import 'package:chan/services/persistence.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _blobSyncApiRoot = 'http://localhost:3005';

class BlobSyncServerException implements Exception {
	final String path;
	final String error;
	const BlobSyncServerException(this.path, this.error);

	@override
	String toString() => 'BlobSyncException(path: $path, error: $error)';
}

class CurrentBlobOutOfDateException implements Exception {
	final String path;
	final int rev;
	const CurrentBlobOutOfDateException(this.path, this.rev);

	@override
	String toString() => 'CurrentBlobOutOfDateException(path: $path, rev: $rev)';
}

enum BlobType {
	/// File on disk it just gets overwritten
	file,
	/// We need to track ours/theirs/base separately
	managed
}

class BlobRevision extends HiveObject {
	int cloudVersion;
	Uint8List? theirVersion;
	
	BlobRevision({
		required this.cloudVersion,
		required this.theirVersion
	});
}

class BlobSync {
	Future<int> push({
		required String path,
		required Stream<List<int>> encryptedStream,
		required int length,
		required String mac,
		required int currentRev
	}) async {
		final userId = Persistence.settings.userId;
		final response = await Dio().post(
			'$_blobSyncApiRoot/blob/$userId/$path',
			data: FormData.fromMap({
				'data': MultipartFile(
					encryptedStream,
					length
				),
				'lastRev': currentRev
			}),
			options: Options(
				validateStatus: (_) => true
			)
		);
		if (response.statusCode == 409) {
			throw CurrentBlobOutOfDateException(path, response.data['lastRev'] as int);
		}
		if (response.statusCode != 200) {
			final error = (response.data as Map?)?['error'] as String?;
			if (error != null) {
				throw BlobSyncServerException(path, error);
			}
			else {
				throw BlobSyncServerException(path, 'HTTP Error ${response.statusCode}');
			}
		}
		return response.data['rev'] as int;
	}

	void listenToTheirVersion({
		required String path,
		required Future<void> Function(Uint8List theirOldBuffer, Uint8List theirNewBuffer) listener
	}) {
		
	}

	Future<int> pushBuffer({
		required String path,
		required Uint8List encryptedBuffer,
		required String mac,
		required int currentRev
	}) => push(
		path: path,
		encryptedStream: Stream.value(encryptedBuffer),
		length: encryptedBuffer.length,
		mac: mac,
		currentRev: currentRev
	);
}