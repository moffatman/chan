import 'package:chan/models/post.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:provider/provider.dart';

abstract class PostSpan {
	List<int> get referencedPostIds {
		return [];
	}
	InlineSpan build(BuildContext context);
}

class PostNodeSpan extends PostSpan {
	List<PostSpan> children;

	PostNodeSpan(this.children);

	List<int> get referencedPostIds {
		return children.expand((child) => child.referencedPostIds).toList();
	}

	build(context) {
		return TextSpan(
			children: children.map((child) => child.build(context)).toList()
		);
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	PostTextSpan(this.text);
	InlineSpan build(BuildContext context) {
		return TextSpan(
			text: this.text
		);
	}
}

class PostLineBreakSpan extends PostSpan {
	PostLineBreakSpan();
	build(context) {
		return WidgetSpan(
			child: Row(
				children: [Text('')]
			)
		);
	}
}

class PostQuoteSpan extends PostSpan {
	final String text;
	PostQuoteSpan(this.text);
	build(context) {
		return TextSpan(
			text: this.text,
			style: TextStyle(color: Colors.green)
		);
	}
}

class PostQuoteLinkSpan extends PostSpan {
	final int id;
	PostQuoteLinkSpan(this.id);
	@override
	List<int> get referencedPostIds {
		return [id];
	}
	build(context) {
		final zone = context.watchOrNull<ExpandingPostZone>();
		final sameAsParent = zone?.parentId == id;
		return TextSpan(
			text: '>>' + this.id.toString(),
			style: TextStyle(
				color: (zone?.shouldExpandPost(id) ?? false || sameAsParent) ? Colors.pink : Colors.red,
				decoration: TextDecoration.underline,
				decorationStyle: sameAsParent ? TextDecorationStyle.dashed : null
			),
			recognizer: TapGestureRecognizer()..onTap = () {
				if (!sameAsParent && zone != null) {
					zone.toggleExpansionOfPost(this.id);
				}
			}
		);
	}
}

class PostWidgetSpan extends PostSpan {
	final Widget Function(BuildContext context) builder;
	PostWidgetSpan(this.builder);

	build(context) => WidgetSpan(child: this.builder(context));
}

class PostExpandingQuoteLinkSpan extends PostNodeSpan {
	PostExpandingQuoteLinkSpan(int id) : super([
		PostQuoteLinkSpan(id),
		PostWidgetSpan((ctx) => ExpandingPost(id))
	]);
}

class PostDeadQuoteLinkSpan extends PostSpan {
	final int id;
	PostDeadQuoteLinkSpan(this.id);
	build(context) {
		return TextSpan(
			text: '>>' + this.id.toString(),
			style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red)
		);
	}
}

class PostCrossThreadQuoteLinkSpan extends PostSpan {
	final String board;
	final int postId;
	final int threadId;
	PostCrossThreadQuoteLinkSpan(this.board, this.threadId, this.postId);
	build(context) {
		final showBoard = context.watch<Post>().board != board;
		return TextSpan(
			text: (showBoard ? '>>/$board/' : '>>') + this.postId.toString() + ' (Cross-thread)',
			style: TextStyle(
				color: Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: TapGestureRecognizer()..onTap = () {
				Navigator.of(context).push(CupertinoPageRoute(builder: (ctx) => ThreadPage(board: this.board, id: this.threadId, initialPostId: this.postId)));
			}
		);
	}
}

class PostNewLineSpan extends PostSpan {
	PostNewLineSpan();
	build(context) {
		return WidgetSpan(
			child: Row()
		);
	}
}