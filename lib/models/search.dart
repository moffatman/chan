import 'package:chan/services/imageboard.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'search.g.dart';

@HiveType(typeId: 6)
enum PostTypeFilter {
	@HiveField(0)
	none,
	@HiveField(1)
	onlyOPs,
	@HiveField(2)
	onlyReplies,
	@HiveField(3)
	onlyStickies
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

@HiveType(typeId: 26)
enum PostDeletionStatusFilter {
	@HiveField(0)
	none,
	@HiveField(1)
	onlyDeleted,
	@HiveField(2)
	onlyNonDeleted
}

@HiveType(typeId: 5)
class ImageboardArchiveSearchQuery {
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
	@HiveField(7, defaultValue: PostDeletionStatusFilter.none)
	PostDeletionStatusFilter deletionStatusFilter;
	@HiveField(8)
	String? imageboardKey;
	@HiveField(9)
	String? name;
	@HiveField(10)
	String? trip;
	@HiveField(11)
	String? subject;
	ImageboardArchiveSearchQuery({
		this.query = '',
		this.mediaFilter = MediaFilter.none,
		this.postTypeFilter = PostTypeFilter.none,
		this.startDate,
		this.endDate,
		List<String>? boards,
		this.md5,
		this.deletionStatusFilter = PostDeletionStatusFilter.none,
		required this.imageboardKey,
		this.name,
		this.trip,
		this.subject
	}) : boards = boards ?? [];

	Imageboard? get imageboard => ImageboardRegistry.instance.getImageboard(imageboardKey ?? '');

	ImageboardArchiveSearchQuery clone() {
		return ImageboardArchiveSearchQuery(
			query: query.toString(),
			mediaFilter: mediaFilter,
			postTypeFilter: postTypeFilter,
			startDate: (startDate != null) ? DateTime.fromMillisecondsSinceEpoch(startDate!.millisecondsSinceEpoch) : null,
			endDate: (endDate != null) ? DateTime.fromMillisecondsSinceEpoch(endDate!.millisecondsSinceEpoch) : null,
			boards: [...boards],
			md5: md5,
			deletionStatusFilter: deletionStatusFilter,
			imageboardKey: imageboardKey,
			name: name,
			trip: trip,
			subject: subject
		);
	}

	@override
	bool operator==(Object other) => (other is ImageboardArchiveSearchQuery)
																	 && (other.query == query)
																	 && (other.mediaFilter == mediaFilter)
																	 && (other.postTypeFilter == postTypeFilter)
																	 && (other.startDate == startDate)
																	 && (other.endDate == endDate)
																	 && (listEquals(other.boards, boards))
																	 && (other.md5 == md5)
																	 && (other.deletionStatusFilter == deletionStatusFilter)
																	 && (other.imageboardKey == imageboardKey)
																	 && (other.name == name)
																	 && (other.trip == trip)
																	 && (other.subject == subject);

	@override
	int get hashCode => Object.hash(query, mediaFilter, postTypeFilter, startDate, endDate, boards, md5, deletionStatusFilter, imageboardKey, name, trip, subject);
}