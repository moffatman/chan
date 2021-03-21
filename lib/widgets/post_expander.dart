import 'package:chan/models/post.dart';
import 'package:chan/widgets/gallery_manager.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:extended_image/extended_image.dart';

class ExpandingPostZone extends ChangeNotifier {
	final Map<int, bool> _shouldExpandPost = Map();
	final List<int> parentIds;
	final Map<int, bool> _shouldShowSpoiler = Map();

	ExpandingPostZone(this.parentIds);

	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}

	bool shouldShowSpoiler(int id) {
		return _shouldShowSpoiler[id] ?? false;
	}

	void toggleShowingOfSpoiler(int id) {
		_shouldShowSpoiler[id] = !shouldShowSpoiler(id);
		notifyListeners();
	}
}

GlobalKey<ExtendedImageSlidePageState> slidePageKey = GlobalKey();

class ExpandingPost extends StatelessWidget {
	final int id;
	ExpandingPost(this.id);
	
	@override
	Widget build(BuildContext context) {
		final zone = context.watch<ExpandingPostZone>();
		return zone.shouldExpandPost(this.id) ? Provider.value(
			value: context.watch<List<Post>>().firstWhere((p) => p.id == this.id),
			child: MediaQuery(
				data: MediaQueryData(textScaleFactor: 1),
				child: PostRow(
					onThumbnailTap: (attachment, {Object? tag}) {
						showGallery(
							context: context,
							attachments: [attachment],
							semanticParentIds: zone.parentIds
						);
					}
				)
			)
		) : Container(width: 0, height: 0);
	}
}