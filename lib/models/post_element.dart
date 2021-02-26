import 'package:chan/pages/thread.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/util.dart';

abstract class PostElement extends StatelessWidget {
	PostElement();
}

class TextElement extends PostElement {
	final String text;
	TextElement(this.text);
	Widget build(BuildContext context) {
		return Text(this.text, style: TextStyle(color: Theme.of(context).colorScheme.onBackground));
	}
}

class LineBreakElement extends PostElement {
	LineBreakElement();
	Widget build(BuildContext context) {
		return Row(
			children: [
				Text('')
			]
		);
	}
}

class QuoteElement extends PostElement {
	final String text;
	QuoteElement(this.text);
	Widget build(BuildContext context) {
		return Text(this.text, style: TextStyle(color: Colors.green));
	}
}

class QuoteLinkElement extends PostElement {
	final int id;
	QuoteLinkElement(this.id);
	Widget build(BuildContext context) {
		final sameAsParent = context.watchOrNull<ParentPost>()?.id == id;
		return CupertinoButton(
			minSize: 0,
			padding: EdgeInsets.zero,
			child: Text('>>' + this.id.toString(), style: TextStyle(
				color: (context.watchOrNull<ExpandingPostZone>()?.shouldExpandPost(id) ?? false || sameAsParent) ? Colors.pink : Colors.red,
				decoration: TextDecoration.underline,
				decorationStyle: sameAsParent ? TextDecorationStyle.dashed : null
			)),
			onPressed: (sameAsParent || context.watchOrNull<ExpandingPostZone>() == null) ? null : () {
				context.read<ExpandingPostZone>().toggleExpansionOfPost(this.id);
			}
		);
	}
}

class DeadQuoteLinkElement extends PostElement {
	final int id;
	DeadQuoteLinkElement(this.id);
	Widget build(BuildContext context) {
		return Text('>>' + this.id.toString(), style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red));
	}
}

class CrossThreadQuoteLinkElement extends PostElement {
	final String board;
	final int postId;
	final int threadId;
	CrossThreadQuoteLinkElement(this.board, this.threadId, this.postId);
	Widget build(BuildContext context) {
		return CupertinoButton(
			minSize: 0,
			padding: EdgeInsets.zero,
			child: Text('>>' + this.postId.toString() + ' (Cross-thread)', style: TextStyle(
				color: Colors.red,
				decoration: TextDecoration.underline
			)),
			onPressed: () {
				Navigator.of(context).push(CupertinoPageRoute(builder: (ctx) => ThreadPage(board: this.board, id: this.threadId, initialPostId: this.postId)));
			}
		);
	}
}

class NewLineElement extends PostElement {
	NewLineElement();
	Widget build(BuildContext context) {
		return Row();
	}
}