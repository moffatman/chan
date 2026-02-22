import 'package:chan/sites/lainchan_org.dart';

class SiteWizchan extends SiteLainchanOrg {
	SiteWizchan({
		required super.baseUrl,
		required super.name,
		required super.imageUrl,
		required super.overrideUserAgent,
		required super.addIntrospectedHeaders,
		required super.archives,
		required super.imageHeaders,
		required super.videoHeaders,
		required super.turnstileSiteKey,
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
		super==(other);

	@override
	int get hashCode => baseUrl.hashCode;
}