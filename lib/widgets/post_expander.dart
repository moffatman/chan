import 'package:chan/models/post.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class ExpandingPostZone extends ChangeNotifier {
	final Map<int, bool> _shouldExpandPost = Map();
	final int parentId;

	ExpandingPostZone(this.parentId);

	bool shouldExpandPost(int id) {
		return _shouldExpandPost[id] ?? false;
	}

	void toggleExpansionOfPost(int id) {
		_shouldExpandPost[id] = !shouldExpandPost(id);
		notifyListeners();
	}
}

class ExpandingPost extends StatelessWidget {
	final int id;
	ExpandingPost(this.id);
	
	@override
	Widget build(BuildContext context) {
		return context.watch<ExpandingPostZone>().shouldExpandPost(this.id) ? Provider.value(
			value: context.watch<List<Post>>().firstWhere((p) => p.id == this.id),
			child: PostRow()
		) : Container(width: 0, height: 0);
	}
}