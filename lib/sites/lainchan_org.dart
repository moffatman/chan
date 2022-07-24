import 'package:chan/models/board.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

class SiteLainchanOrg extends SiteLainchan {
	SiteLainchanOrg({
		required String baseUrl,
		required String name,
		List<ImageboardSiteArchive> archives = const []
	}) : super(
		baseUrl: baseUrl,
		name: name,
		archives: archives
	);

	@override
	Future<List<ImageboardBoard>> getBoardsOnce() async {
		final response = await client.get(Uri.https(baseUrl, '/').toString(), options: Options(
			responseType: ResponseType.plain
		));
		final document = parse(response.data);
		return document.querySelectorAll('.boardlist a').where((e) => e.attributes['title'] != null).map((e) => ImageboardBoard(
			name: e.attributes['href']!.split('/')[1],
			title: e.attributes['title']!,
			maxWebmSizeBytes: 25000,
			maxImageSizeBytes: 25000,
			isWorksafe: false,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	String get siteType => 'lainchan_org';
	@override
	String get siteData => baseUrl;
} 