import 'package:chan/sites/lainchan_org.dart';
import 'package:flutter/foundation.dart';

class SiteWizchan extends SiteLainchanOrg {
	SiteWizchan({
		required super.baseUrl,
		required super.name,
		required super.overrideUserAgent,
		required super.archives,
		super.faviconPath,
		super.defaultUsername = 'Anonymage'
	});

	@override
	String? get imageThumbnailExtension => null;

	@override
	String get siteType => 'wizchan';

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		(other is SiteWizchan) &&
		(other.baseUrl == baseUrl) &&
		(other.name == name) &&
		(other.faviconPath == faviconPath) &&
		(other.defaultUsername == defaultUsername) &&
		(other.overrideUserAgent == overrideUserAgent) &&
		listEquals(other.archives, archives);

	@override
	int get hashCode => Object.hash(baseUrl, name, faviconPath, defaultUsername, overrideUserAgent, Object.hashAll(archives));
}