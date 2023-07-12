import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract class AdaptiveIconSet {
	IconData get bookmark;
	IconData get bookmarkFilled;
	IconData get photo;
	IconData get photos;
	IconData get share;
}

class AdaptiveIconSetMaterial implements AdaptiveIconSet {
	const AdaptiveIconSetMaterial();

	@override
	IconData get bookmark => Icons.bookmark_outline;
	@override
	IconData get bookmarkFilled => Icons.bookmark;
	@override
	IconData get photo => Icons.photo;
	@override
	IconData get photos => Icons.photo_library;
	@override
	IconData get share => Icons.share;
} 

class AdaptiveIconSetCupertino implements AdaptiveIconSet {
	const AdaptiveIconSetCupertino();

	@override
	IconData get bookmark => CupertinoIcons.bookmark;
	@override
	IconData get bookmarkFilled => CupertinoIcons.bookmark_fill;
	@override
	IconData get photo => CupertinoIcons.photo;
	@override
	IconData get photos => CupertinoIcons.photo_on_rectangle;
	@override
	IconData get share => CupertinoIcons.share;
}
