// ignore_for_file: file_names

import 'dart:convert';

import 'package:chan/models/board.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class Site8Kun extends SiteLainchan2 {
	@override
	final String sysUrl;
	final String imageUrl;

	Site8Kun({
		required super.baseUrl,
		required super.basePath,
		required this.sysUrl,
		required this.imageUrl,
		required super.name,
		required super.formBypass,
		required super.imageThumbnailExtension,
		required super.overrideUserAgent,
		required super.archives,
		super.faviconPath,
		super.boardsPath,
		super.boards,
		super.defaultUsername
	});

	@override
	Uri getAttachmentUrl(String board, String filename) => Uri.https(imageUrl, '/file_store/$filename');

	@override
	Uri getThumbnailUrl(String board, String filename) => Uri.https(imageUrl, '/file_store/thumb/$filename');

	/// 8kun reuses same image ID for reports. So need to make it unique within thread
	@override
	String getAttachmentId(int postId, String imageId) => '${postId}_$imageId';

	@override
	Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) async {
		final response = await client.getUri(Uri.https(sysUrl, '/board-search.php'), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: priority
			},
			// Needed to allow multiple interception
			validateStatus: (_) => true
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		return (jsonDecode(response.data)['boards'] as Map).cast<String, Map>().entries.map((board) => ImageboardBoard(
			name: board.key,
			title: board.value['title'],
			isWorksafe: board.value['sfw'] == 1,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	Future<List<ImageboardBoard>> getBoardsForQuery(String query) async {
		final response = await client.getUri(Uri.https(sysUrl, '/board-search.php', {
			'lang': '',
			'tags': '',
			'title': query,
			'sfw': '0'
		}), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kPriority: RequestPriority.interactive
			},
			// Needed to allow multiple interception
			validateStatus: (_) => true
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		return (jsonDecode(response.data)['boards'] as Map).cast<String, Map>().entries.map((board) => ImageboardBoard(
			name: board.key,
			title: board.value['title'],
			isWorksafe: board.value['sfw'] == 1,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	Future<void> updatePostingFields(DraftPost post, Map<String, dynamic> fields) async {
		fields['domain_name_post'] = baseUrl;
		fields['tor'] = 'null';
	}

	@override
	String get siteType => '8kun';
	@override
	String get siteData => baseUrl;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		(other is Site8Kun) &&
		(other.baseUrl == baseUrl) &&
		(other.basePath == basePath) &&
		(other.sysUrl == sysUrl) &&
		(other.imageUrl == imageUrl) &&
		(other.name == name) &&
		(other.overrideUserAgent == overrideUserAgent) &&
		listEquals(other.archives, archives) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		(other.boardsPath == boardsPath) &&
		mapEquals(other.formBypass, formBypass) &&
		(other.imageThumbnailExtension == imageThumbnailExtension) &&
		(other.boardsPath == boardsPath) &&
		(other.faviconPath == faviconPath) &&
		listEquals(other.boards, boards);

	@override
	int get hashCode => Object.hash(baseUrl, basePath, sysUrl, imageUrl, name, overrideUserAgent, Object.hashAll(archives), faviconPath, defaultUsername, Object.hashAll(formBypass.keys), imageThumbnailExtension, boardsPath, faviconPath, Object.hashAll(boards ?? []));
}