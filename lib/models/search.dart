import 'package:hive/hive.dart';

part 'search.g.dart';

@HiveType(typeId: 6)
enum PostTypeFilter {
	@HiveField(0)
	none,
	@HiveField(1)
	onlyOPs,
	@HiveField(2)
	onlyReplies
}

@HiveType(typeId: 7)
enum MediaFilter {
	@HiveField(0)
	none,
	@HiveField(1)
	onlyWithMedia,
	@HiveField(2)
	onlyWithNoMedia
}

@HiveType(typeId: 5)
class ImageboardArchiveSearchQuery extends HiveObject {
	@HiveField(0)
	String query;
	@HiveField(1)
	MediaFilter mediaFilter;
	@HiveField(2)
	PostTypeFilter postTypeFilter;
	@HiveField(3)
	DateTime? startDate;
	@HiveField(4)
	DateTime? endDate;
	@HiveField(5)
	List<String> boards;
	@HiveField(6)
	String? md5;
	ImageboardArchiveSearchQuery({
		this.query = '',
		this.mediaFilter = MediaFilter.none,
		this.postTypeFilter = PostTypeFilter.none,
		this.startDate,
		this.endDate,
		List<String>? boards,
		this.md5
	}) : boards = boards ?? [];

	ImageboardArchiveSearchQuery clone() {
		return ImageboardArchiveSearchQuery(
			query: query.toString(),
			mediaFilter: mediaFilter,
			postTypeFilter: postTypeFilter,
			startDate: (startDate != null) ? DateTime.fromMillisecondsSinceEpoch(startDate!.millisecondsSinceEpoch) : null,
			endDate: (endDate != null) ? DateTime.fromMillisecondsSinceEpoch(endDate!.millisecondsSinceEpoch) : null,
			boards: [...boards]
		);
	}
}