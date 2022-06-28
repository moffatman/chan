import 'package:chan/models/board.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

class SiteSoyjak extends SiteLainchan {
	SiteSoyjak({
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
		final response = await client.get(Uri.https(baseUrl).toString(), options: Options(
			responseType: ResponseType.plain
		));
		final document = parse(response.data);
		return document.querySelectorAll('fieldset a').map((elem) => ImageboardBoard(
			name: elem.attributes['href']!.split('/').lastWhere((s) => s.isNotEmpty),
			title: elem.text,
			isWorksafe: false,
			webmAudioAllowed: true
		)).toList();
	}

	@override
	String? get imageThumbnailExtension => null;

	@override
	Uri get iconUrl => Uri.https(baseUrl, '/static/favicon.png');

	@override
	String get siteType => 'soyjak';

	@override
	bool operator ==(Object other) => (other is SiteSoyjak) && (other.name == name) && (other.baseUrl == baseUrl);

	@override
	int get hashCode => Object.hash(name, baseUrl);
}