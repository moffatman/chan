import 'package:chan/models/post.dart';
import 'package:chan/sites/imageboard_site.dart';

mixin ForumSite on ImageboardSite {
	@override
	int placeOrphanPost(List<Post> posts, Post post) {
		if (post.parentId == null) {
			return super.placeOrphanPost(posts, post);
		}
		// Find last sibling
		int index = posts.lastIndexWhere((p) => p.parentId == post.parentId);
		if (index == -1) {
			// No last sibling, find parent page
			index = posts.indexWhere((p) => p.id == post.parentId);
			if (index != -1) {
				// After parent
				index++;
			}
		}
		else {
			// Walk back to find proper sequence within siblings
			while (
				index >= 0 &&
				post.parentId == posts[index].parentId &&
				post.id < posts[index].id
			) {
				// The sibling comes before us
				index--;
			}
			// After sibling
			index++;
		}
		if (index == -1) {
			// No sibling or parent
			posts.add(post);
			return posts.length - 1;
		}
		else {
			posts.insert(index, post);
			return index;
		}
	}
}
