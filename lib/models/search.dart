import 'package:hive/hive.dart';

part 'search.g.dart';

@HiveType(typeId: 6)
enum PostTypeFilter {
	@HiveField(0)
	None,
	@HiveField(1)
	OnlyOPs,
	@HiveField(2)
	OnlyReplies
}

@HiveType(typeId: 7)
enum MediaFilter {
	@HiveField(0)
	None,
	@HiveField(1)
	OnlyWithMedia,
	@HiveField(2)
	OnlyWithNoMedia
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
		this.mediaFilter = MediaFilter.None,
		this.postTypeFilter = PostTypeFilter.None,
		this.startDate,
		this.endDate,
		List<String>? boards,
		this.md5
	}) : this.boards = boards ?? [];

	ImageboardArchiveSearchQuery clone() {
		return ImageboardArchiveSearchQuery(
			query: this.query.toString(),
			mediaFilter: this.mediaFilter,
			postTypeFilter: this.postTypeFilter,
			startDate: (this.startDate != null) ? DateTime.fromMillisecondsSinceEpoch(this.startDate!.millisecondsSinceEpoch) : null,
			endDate: (this.endDate != null) ? DateTime.fromMillisecondsSinceEpoch(this.endDate!.millisecondsSinceEpoch) : null,
			boards: [...this.boards]
		);
	}
}