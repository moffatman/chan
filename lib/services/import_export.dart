
import 'dart:convert';
import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:archive/archive_io.dart';

Future<File> export({
	required bool includeSavedAttachments,
	required bool includeFullHistory
}) async {
	final encoder = ZipFileEncoder();
	encoder.create('${Persistence.temporaryDirectory.path}/${DateTime.now().millisecondsSinceEpoch ~/ 1000}.backup.zip');
	for (final filename in [
		'${Persistence.settingsBoxName}.hive',
		'${Persistence.sharedBoardsBoxName}.hive',
		'${Persistence.sharedThreadStatesBoxName}.hive',
		if (includeFullHistory) '${Persistence.sharedThreadsBoxName}.hive',
	]) {
		final file = File('${Persistence.documentsDirectory.path}/$filename');
		if (await file.exists()) {
			await encoder.addFile(file);
		}
	}
	LazyBox<Thread>? temporaryThreadsBox;
	if (!includeFullHistory) {
		final deadline = DateTime.now().subtract(const Duration(days: 5)); // reasonable
		final toPreserve = ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.savedPosts.values.map((v) => '${i.key}/${v.post.board}/${v.post.threadId}')).toSet();
		toPreserve.addAll(ImageboardRegistry.instance.imageboards.expand((i) => i.persistence.browserState.threadWatches.keys.map((v) => '${i.key}/${v.board}/${v.id}')));
		final box = temporaryThreadsBox = await Hive.openLazyBox<Thread>('_temporaryThreads');
		for (final key in Persistence.sharedThreadStateBox.keys) {
			final ts = Persistence.sharedThreadStateBox.get(key);
			if (ts == null) {
				continue;
			}
			if (ts.youIds.isNotEmpty || // has replies
				  ts.lastOpenedTime.isAfter(deadline) || // opened recently
					ts.savedTime != null || // saved
					// connects to a saved post or thread watch
				  toPreserve.contains(key)) {
				final thread = await Persistence.sharedThreadsBox.get(key);
				if (thread != null) {
					await box.put(key, Hive.decode(Hive.encode(thread)));
				}
			}
		}
		await encoder.addFile(File(temporaryThreadsBox.path!), '${Persistence.sharedThreadsBoxName}.hive');
	}
	for (final dirname in [
		if (includeSavedAttachments) Persistence.savedAttachmentsDir,
		if (includeSavedAttachments) Persistence.savedAttachmentThumbnailsDir,
		Persistence.fontsDir
	]) {
		final dir = Directory('${Persistence.documentsDirectory.path}/$dirname');
		if (await dir.exists()) {
			// These folders probably can't be compressed
			await encoder.addDirectory(dir, level: ZipFileEncoder.STORE);
		}
	}
	encoder.close();
	await temporaryThreadsBox?.deleteFromDisk();
	return File(encoder.zipPath);
}

Future<File> exportJson() async {
	final encoder = ZipFileEncoder();
	encoder.create('${Persistence.temporaryDirectory.path}/${DateTime.now().millisecondsSinceEpoch ~/ 1000}.json.zip');
	void dumpOne(String path, dynamic object) {
		// ArchiveFile.file only works for ascii
		final buffer = utf8.encode(Hive.encodeJson(object));
		encoder.addArchiveFile(ArchiveFile(path, buffer.length, buffer));
	}
	void dumpAll<T>(String dir, Box<T> box) {
		for (final key in box.keys) {
			final value = box.get(key);
			if (value == null) {
				continue;
			}
			dumpOne('$dir/$key.json', value);
		}
	}
	Future<void> dumpAllLazy<T>(String dir, LazyBox<T> box) async {
		for (final key in box.keys) {
			final value = await box.get(key);
			if (value == null) {
				continue;
			}
			dumpOne('$dir/$key.json', value);
		}
	}
	dumpOne('settings.json', Persistence.settings);
	dumpAll('boards', Persistence.sharedBoardsBox);
	dumpAll('threadStates', Persistence.sharedThreadStateBox);
	await dumpAllLazy('threads', Persistence.sharedThreadsBox);
	encoder.close();
	return File(encoder.zipPath);
}

sealed class ImportLog {
	final String type;
	final String filename;

	const ImportLog({
		required this.type,
		required this.filename
	});
}

class ImportLogConflict<Ancestor extends HiveObjectMixin, T> extends ImportLog {
	final MergeConflict<Ancestor, T> conflict;
	final Ancestor yours;
	final Ancestor theirs;

	const ImportLogConflict({
		required super.type,
		required super.filename,
		required this.conflict,
		required this.yours,
		required this.theirs
	});

	@override
	String toString() => 'ImportLogConflict(type: $type, filename: $filename, conflict: ${conflict.path}, yours: ${conflict.get(yours)}, theirs: ${conflict.get(theirs)})';
}

class ImportLogFailure extends ImportLog {
	final String message;

	const ImportLogFailure({
		required super.filename,
		required super.type,
		required this.message
	});

	@override
	String toString() => 'ImportLogFailure(type: $type, filename: $filename, message: $message)';
}

class ImportLogSummary extends ImportLog {
	final int newCount;
	final int modifiedCount;
	final int identicalCount;

	const ImportLogSummary({
		required super.type,
		required super.filename,
		required this.newCount,
		required this.modifiedCount,
		required this.identicalCount
	});

	@override
	String toString() => 'ImportLogSummary(type: $type, filename: $filename, identicalCount: $identicalCount, modifiedCount: $modifiedCount, newCount: $newCount)';
}

Future<List<ImportLog>> import(File archive) async {
	final log = <ImportLog>[];
	try {
		final dir = Directory('${Persistence.temporaryDirectory.path}/import-${DateTime.now().millisecondsSinceEpoch}');
		await dir.create(recursive: true);
		await extractFileToDisk(archive.path, dir.path);
		Future<void> hiveImportSingleton<T extends HiveObject>({
			required String type,
			required FieldMerger<T> merger,
			required T? base,
			required T yours,
			List<String> skipPaths = const []
		}) async {
			final name = yours.box!.name;
			if (!(await Hive.boxExists(name, path: dir.path))) {
				log.add(ImportLogFailure(filename: '$name.hive', type: type, message: 'File missing'));
				return;
			}
			final Box<T> box;
			try {
				// collection usage is a hack to open two boxes with same name
				box = await Hive.openBox<T>(name, path: dir.path, crashRecovery: false, collection: '');
			}
			catch (e) {
				log.add(ImportLogFailure(filename: '$name.hive', type: type, message: 'Could not open file: $e'));
				return;
			}
			print(box.keys);
			final theirs = box.get(yours.key);
			if (theirs == null) {
				log.add(ImportLogFailure(filename: '$name.hive', type: type, message: 'Missing value for key "${yours.key}"'));
				return;
			}
			final results = Hive.merge(
				merger: merger,
				yours: yours,
				theirs: theirs,
				base: base,
				skipPaths: skipPaths
			);
			for (final conflict in results.conflicts) {
				log.add(ImportLogConflict(
					type: type,
					filename: '$name.hive',
					conflict: conflict,
					yours: yours,
					theirs: theirs
				));
			}
			if (results.wroteYours) {
				await yours.save();
				log.add(ImportLogSummary(
					newCount: 0,
					modifiedCount: 1,
					identicalCount: 0,
					filename: '$name.hive',
					type: type
				));
				return;
			}
			else if (results.conflicts.isNotEmpty) {
				log.add(ImportLogSummary(
					newCount: 0,
					modifiedCount: 1,
					identicalCount: 0,
					filename: '$name.hive',
					type: type
				));
				return;
			}
			log.add(ImportLogSummary(
				newCount: 0,
				modifiedCount: 0,
				identicalCount: 1,
				filename: '$name.hive',
				type: type
			));
		}
		Future<void> hiveImportMap<T extends HiveObjectMixin>({
			required String type,
			required FieldMerger<T> merger,
			required Box<T> yourBox
		}) async {
			if (!(await Hive.boxExists(yourBox.name, path: dir.path))) {
				log.add(ImportLogFailure(filename: '${yourBox.name}.hive', type: type, message: 'File missing'));
				return;
			}
			final Box<T> box;
			try {
				box = await Hive.openBox<T>(yourBox.name, path: dir.path, crashRecovery: false, collection: '');
			}
			catch (e) {
				log.add(ImportLogFailure(filename: '${yourBox.name}.hive', type: type, message: 'Could not open file: $e'));
				return;
			}
			int newCount = 0;
			int modifiedCount = 0;
			int identicalCount = 0;
			for (final key in box.keys) {
				final theirs = box.get(key);
				if (theirs == null) {
					// Unlikely... just doing this for type safety
					continue;
				}
				final yours = yourBox.get(key);
				if (yours == null) {
					newCount++;
					await yourBox.put(key, Hive.decode(Hive.encode(theirs)));
					return;
				}
				final results = Hive.merge(
					merger: merger,
					yours: yours,
					theirs: theirs
				);
				for (final conflict in results.conflicts) {
					log.add(ImportLogConflict(
						type: type,
						filename: '${yourBox.name}.hive',
						conflict: conflict,
						yours: yours,
						theirs: theirs
					));
				}
				if (results.wroteYours) {
					modifiedCount++;
					await yours.save();
				}
				else {
					identicalCount++;
				}
			}
			log.add(ImportLogSummary(
				newCount: newCount,
				modifiedCount: modifiedCount,
				identicalCount: identicalCount,
				filename: '${yourBox.name}.hive',
				type: type
			));
		}
		Future<void> hiveImportLazyMap<T extends HiveObjectMixin>({
			required String type,
			required FieldMerger<T> merger,
			required LazyBox<T> yourBox
		}) async {
			if (!(await Hive.boxExists(yourBox.name, path: dir.path))) {
				log.add(ImportLogFailure(filename: '${yourBox.name}.hive', type: type, message: 'File missing'));
				return;
			}
			final LazyBox<T> box;
			try {
				box = await Hive.openLazyBox<T>(yourBox.name, path: dir.path, crashRecovery: false, collection: '');
			}
			catch (e) {
				log.add(ImportLogFailure(filename: '${yourBox.name}.hive', type: type, message: 'Could not open file: $e'));
				return;
			}
			int newCount = 0;
			int modifiedCount = 0;
			int identicalCount = 0;
			for (final key in box.keys) {
				final theirs = await box.get(key);
				if (theirs == null) {
					// Unlikely... just doing this for type safety
					continue;
				}
				final yours = await yourBox.get(key);
				if (yours == null) {
					newCount++;
					await yourBox.put(key, Hive.decode(Hive.encode(theirs)));
					continue;
				}
				final results = Hive.merge(
					merger: merger,
					yours: yours,
					theirs: theirs
				);
				for (final conflict in results.conflicts) {
					log.add(ImportLogConflict(
						type: type,
						filename: '${yourBox.name}.hive',
						conflict: conflict,
						yours: yours,
						theirs: theirs
					));
				}
				if (results.wroteYours) {
					modifiedCount++;
					await yours.save();
				}
				else {
					identicalCount++;
				}
			}
			log.add(ImportLogSummary(
				newCount: newCount,
				modifiedCount: modifiedCount,
				identicalCount: identicalCount,
				filename: '${yourBox.name}.hive',
				type: type
			));
			await box.close();
		}

		Future<void> importSubdir({
			required String subdir,
			required String type
		}) async {
			final folder = Directory('${dir.path}/$subdir');
			if (!(await folder.exists())) {
				log.add(ImportLogFailure(filename: subdir, type: type, message: 'Missing subdirectory'));
				return;
			}
			int newCount = 0;
			int modifiedCount = 0;
			int identicalCount = 0;
			await for (final child in folder.list(recursive: true)) {
				final srcStat = await child.stat();
				final relative = child.path.replaceFirst('${folder.path}/', '');
				final destPath = '${Persistence.documentsDirectory.path}/$subdir/$relative';
				if (srcStat.type == FileSystemEntityType.directory) {
					Directory(destPath).create(recursive: true);
					return;
				}
				final dest = File(destPath);
				if (await dest.exists()) {
					final destStat = await dest.stat();
					if (srcStat.size == destStat.size) {
						identicalCount++;
					}
					else {
						modifiedCount++;
					}
				}
				else {
					newCount++;
				}
				await File(child.path).copy(dest.path);
			}
			log.add(ImportLogSummary(
				newCount: newCount,
				modifiedCount: modifiedCount,
				identicalCount: identicalCount,
				filename: subdir,
				type: type
			));
		}

		await hiveImportSingleton<SavedSettings>(
			type: 'Settings',
			merger: const ResolvedAdaptedMerger(SavedSettingsAdapter()),
			yours: Persistence.settings,
			base: SavedSettings(),
			skipPaths: [
				SavedSettingsFields.userId.fieldName
			]
		);
		await hiveImportMap<ImageboardBoard>(
			type: 'Boards',
			merger: const ResolvedAdaptedMerger(ImageboardBoardAdapter()),
			yourBox: Persistence.sharedBoardsBox
		);
		await hiveImportMap<PersistentThreadState>(
			type: 'Thread States',
			merger: const ResolvedAdaptedMerger(PersistentThreadStateAdapter()),
			yourBox: Persistence.sharedThreadStateBox
		);
		await hiveImportLazyMap<Thread>(
			type: 'Threads',
			merger: const ResolvedAdaptedMerger(ThreadAdapter()),
			yourBox: Persistence.sharedThreadsBox
		);

		await importSubdir(
			subdir: Persistence.savedAttachmentsDir,
			type: 'Saved Attachments'
		);
		await importSubdir(
			subdir: Persistence.savedAttachmentThumbnailsDir,
			type: 'Saved Attachment Thumbnails'
		);
		await importSubdir(
			subdir: Persistence.fontsDir,
			type: 'Fonts'
		);
		await dir.delete(recursive: true);
	}
	catch (e, st) {
		Future.error(e, st); // crashlytics
		log.add(ImportLogFailure(filename: archive.path, type: 'Archive', message: 'Fatal error: $e'));
	}
	return log;
}
