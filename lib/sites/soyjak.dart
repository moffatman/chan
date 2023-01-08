import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/sites/lainchan_org.dart';
import 'package:flutter/foundation.dart';

class SiteSoyjak extends SiteLainchanOrg {
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
	String? get imageThumbnailExtension => null;

	@override
	Uri get iconUrl => Uri.https(baseUrl, '/static/favicon.png');

	@override
	String get siteType => 'soyjak';

	@override
	bool operator ==(Object other) => (other is SiteSoyjak) && (other.baseUrl == baseUrl) && (other.name == name) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, archives);

	@override
	String get defaultUsername => 'Chud';
}