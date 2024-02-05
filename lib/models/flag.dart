import 'package:chan/models/intern.dart';
import 'package:hive/hive.dart';

part 'flag.g.dart';

abstract class Flag {
	String get name;
}

@HiveType(typeId: 14)
class ImageboardFlag implements Flag {
	@override
	@HiveField(0)
	final String name;
	@HiveField(1)
	final String imageUrl;
	@HiveField(2)
	final double imageWidth;
	@HiveField(3)
	final double imageHeight;

	ImageboardFlag({
		required String name,
		required String imageUrl,
		required this.imageWidth,
		required this.imageHeight
	}) : name = intern(name), imageUrl = intern(imageUrl);

	ImageboardFlag.text(String name) : name = intern(name), imageUrl = intern(''), imageWidth = 0, imageHeight = 0;

	@override
	String toString() => imageUrl.isEmpty ? 'ImageboardFlag.text($name)' : 'ImageboardFlag(name: $name, imageUrl: $imageUrl)';
}

@HiveType(typeId: 36)
class ImageboardMultiFlag implements Flag {
	@HiveField(0)
	final List<ImageboardFlag> parts;

	ImageboardMultiFlag({
		required this.parts
	});

	@override
	String get name => parts.map((p) => p.name).where((s) => s.trim().isNotEmpty).join(', ');

	@override
	String toString() => 'ImageboardMultiFlag(parts: $parts)';
}
