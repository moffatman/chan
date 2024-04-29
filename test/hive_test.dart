import 'package:chan/models/attachment.dart';
import 'package:chan/models/post.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
	group('Merging SavedSettings', () {
    Persistence.initializeHive(forTesting: true);
    test('Simple', () {
      final base = SavedSettings();
			final newPostDisplayFieldOrder = [
				PostDisplayField.postId,
				PostDisplayField.postNumber,
				PostDisplayField.ipNumber,
				PostDisplayField.name,
				PostDisplayField.posterId,
				PostDisplayField.attachmentInfo,
				PostDisplayField.pass,
				PostDisplayField.lineBreak,
				PostDisplayField.flag,
				PostDisplayField.countryName,
				PostDisplayField.absoluteTime,
				PostDisplayField.relativeTime
			];
			// Needed because tabs have inbuilt uuids
			final tabs = [PersistentBrowserTab()];
      final yours = SavedSettings(
        hackerNewsCatalogVariant: CatalogVariant.hackerNewsJobs,
				postDisplayFieldOrder: newPostDisplayFieldOrder,
				tabs: tabs
      );
      final theirs = SavedSettings(
        hackerNewsCatalogVariant: CatalogVariant.hackerNewsBest,
				tabs: tabs
      );
      final results = Hive.merge(
        merger: const ResolvedAdaptedMerger(SavedSettingsAdapter()),
        yours: yours,
        theirs: theirs,
        base: base
      );
			expect(results.conflicts.map((c) => c.path), containsAll([
				SavedSettingsFields.hackerNewsCatalogVariant.fieldName
			]));
			expect(theirs.postDisplayFieldOrder, equals(newPostDisplayFieldOrder));
			expect(results.wroteYours, isFalse);
			expect(results.wroteTheirs, isTrue);
    });
		test('No base', () {
			final newPostDisplayFieldOrder = [
				PostDisplayField.postId,
				PostDisplayField.postNumber,
				PostDisplayField.ipNumber,
				PostDisplayField.name,
				PostDisplayField.posterId,
				PostDisplayField.attachmentInfo,
				PostDisplayField.pass,
				PostDisplayField.lineBreak,
				PostDisplayField.flag,
				PostDisplayField.countryName,
				PostDisplayField.absoluteTime,
				PostDisplayField.relativeTime
			];
			// Needed because tabs have inbuilt uuids
			final tabs = [PersistentBrowserTab()];
      final yours = SavedSettings(
        hackerNewsCatalogVariant: CatalogVariant.hackerNewsJobs,
				postDisplayFieldOrder: newPostDisplayFieldOrder,
				tabs: tabs
      );
      final theirs = SavedSettings(
        hackerNewsCatalogVariant: CatalogVariant.hackerNewsBest,
				tabs: tabs
      );
      final results = Hive.merge(
        merger: const ResolvedAdaptedMerger(SavedSettingsAdapter()),
        yours: yours,
        theirs: theirs
      );
			expect(results.conflicts.map((c) => c.path), containsAll([
				SavedSettingsFields.hackerNewsCatalogVariant.fieldName
			]));
			expect(theirs.postDisplayFieldOrder, equals(newPostDisplayFieldOrder));
			expect(results.wroteYours, isFalse);
			expect(results.wroteTheirs, isTrue);
    });
  });

	group('Merging Post', () {
		test('Post.attachments', () {
			final yours = Post(
				board: '',
				text: '',
				name: '',
				time: DateTime(0),
				threadId: 0,
				id: 0,
				spanFormat: PostSpanFormat.stub,
				attachments_: const []
			);
			final attachment = Attachment(
				type: AttachmentType.url,
				board: '',
				id: '',
				ext: '',
				filename: '',
				url: '',
				thumbnailUrl: '',
				md5: '',
				width: null,
				height: null,
				threadId: null,
				sizeInBytes: null
			);
			final theirs = Post(
				board: '',
				text: '',
				name: '',
				time: DateTime(0),
				threadId: 0,
				id: 0,
				spanFormat: PostSpanFormat.stub,
				attachments_: [attachment].toList(growable: false)
			);
			final results = Hive.merge(
        merger: const ResolvedAdaptedMerger(PostAdapter()),
        yours: yours,
        theirs: theirs
      );
			expect(results.conflicts, isEmpty);
			expect(yours.attachments, equals([attachment]));
			expect(results.wroteYours, isTrue);
			expect(results.wroteTheirs, isFalse);
		});
	});
}