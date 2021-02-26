import 'package:chan/models/post.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ExpandingPostZone extends ChangeNotifier {
	final Map<int, bool> _shouldExpandPost = Map();

	ExpandingPostZone();

	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}
}

class ParentPost {
	final int id;
	ParentPost(this.id);
}

class ExpandingPost extends StatelessWidget {
	final ParentPost parent;
	final Post post;
	ExpandingPost({
		required this.post,
		required int parentId
	}) : parent = ParentPost(parentId);
	
	@override
	Widget build(BuildContext context) {
		return context.watch<ExpandingPostZone>().shouldExpandPost(this.post.id) ? MultiProvider(
			providers: [
				Provider.value(value: post),
				Provider.value(value: parent)
			],
			child: PostRow()
		) : Container();
	}
}