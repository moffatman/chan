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
		required this.name,
		required this.imageUrl,
		required this.imageWidth,
		required this.imageHeight
	});

	ImageboardFlag.text(this.name) : imageUrl = '', imageWidth = 0, imageHeight = 0;
}

@HiveType(typeId: 36)
class ImageboardMultiFlag implements Flag {
	@HiveField(0)
	final List<ImageboardFlag> parts;

	ImageboardMultiFlag({
		required this.parts
	});

	@override
	String get name => parts.map((p) => p.name).where((s) => s.isNotEmpty).join(', ');
}
