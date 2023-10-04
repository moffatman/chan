import 'package:chan/models/board.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

class SiteLainchanOrg extends SiteLainchan {
	final String boardsPath;
	SiteLainchanOrg({
		required super.baseUrl,
		required super.name,
		super.archives = const [],
		super.faviconPath,
		super.defaultUsername,
		this.boardsPath = '/'
	});

	@override
	Future<List<ImageboardBoard>> getBoards({required bool interactive}) async {
		final response = await client.getUri(Uri.https(baseUrl, boardsPath), options: Options(
			responseType: ResponseType.plain,
			extra: {
				kInteractive: interactive
			},
			// Needed to allow multiple interception
			validateStatus: (_) => true
		));
		if (response.statusCode != 200) {
			throw HTTPStatusException(response.statusCode ?? 0);
		}
		final document = parse(response.data);
		return document.querySelectorAll('.boardlist a').where((e) => e.attributes['title'] != null && (e.attributes['href'] ?? '').contains('/')).map((e) => ImageboardBoard(
			name: e.attributes['href']!.split('/')[1],
			title: e.attributes['title']!,
			maxWebmSizeBytes: 25000000,
			maxImageSizeBytes: 25000000,
			isWorksafe: false,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	String get siteType => 'lainchan_org';
	@override
	String get siteData => baseUrl;

	@override
	bool operator ==(Object other) => (other is SiteLainchanOrg) && (other.baseUrl == baseUrl) && (other.name == name) && listEquals(other.archives, archives) && (other.faviconPath == faviconPath) && (other.defaultUsername == defaultUsername);

	@override
	int get hashCode => Object.hash(baseUrl, name, archives, faviconPath, defaultUsername);

	@override
	bool get supportsPushNotifications => false;
} 