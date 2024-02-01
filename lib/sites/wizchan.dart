import 'package:chan/sites/lainchan_org.dart';
import 'package:flutter/foundation.dart';

class SiteWizchan extends SiteLainchanOrg {
	SiteWizchan({
		required super.baseUrl,
		required super.name,
		super.platformUserAgents,
		super.archives,
		super.faviconPath,
		super.defaultUsername = 'Anonymage'
	});

	@override
	String? get imageThumbnailExtension => null;

	@override
	String get siteType => 'wizchan';

	@override
	bool operator ==(Object other) => (other is SiteWizchan) && (other.baseUrl == baseUrl) && (other.name == name) && listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, archives);
}