import 'package:hive/hive.dart';

part 'flag.g.dart';

@HiveType(typeId: 14)
class ImageboardFlag {
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
}