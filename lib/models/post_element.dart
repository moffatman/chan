import 'package:chan/models/post.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

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

class HoverPopup extends StatefulWidget {
	final Widget child;
	final Widget popup;
	HoverPopup({
		required this.child,
		required this.popup
	});
	createState() => _HoverPopupState();
}

class _HoverPopupState extends State<HoverPopup> {
	OverlayEntry? _entry;
	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (event) {
				final RenderBox? childBox = context.findRenderObject() as RenderBox;
				if (childBox == null) {
					return;
				}
				final childTop = childBox.localToGlobal(Offset.zero).dy;
				final childBottom = childBox.localToGlobal(Offset(0, childBox.size.height)).dy;
				final childCenterHorizontal = childBox.localToGlobal(Offset(childBox.size.width / 2, 0)).dx;
				final topOfUsableSpace = MediaQuery.of(context).size.height / 2;
				final hoverWidth = MediaQuery.of(context).size.width / 2;
				final showOnRight = childCenterHorizontal > (MediaQuery.of(context).size.width / 2);
				_entry = OverlayEntry(
					builder: (context) {
						return Positioned(
							right: showOnRight ? (MediaQuery.of(context).size.width - childBox.localToGlobal(Offset(childBox.size.width, 0)).dx) : null,
							left: showOnRight ? null : childBox.localToGlobal(Offset.zero).dx,
							bottom: (childTop > topOfUsableSpace) ? MediaQuery.of(context).size.height - childTop : null,
							top: (childTop > topOfUsableSpace) ? null : childBottom,
							width: hoverWidth,
							child: widget.popup
						);
					}
				);
				Overlay.of(context, rootOverlay: true)!.insert(_entry!);
			},
			onExit: (event) {
				_entry?.remove();
			},
			child: widget.child
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
		final sameAsParent = zone?.parentIds.contains(id) ?? false;
		final postList = context.watch<List<Post>>();
		final post = postList.firstWhere((p) => p.id == this.id);
		return WidgetSpan(
			child: HoverPopup(
				child: Text.rich(
					TextSpan(
						text: '>>' + this.id.toString() + ((postList[0].id == this.id) ? ' (OP)' : ''),
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
					)
				),
				popup: MultiProvider(
					providers: [
						Provider.value(value: post),
						Provider.value(value: postList),
						ChangeNotifierProvider(create: (_) => ExpandingPostZone((zone?.parentIds ?? []).followedBy([post.id]).toList()))
					],
					child: PostRow()
				)
			)
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
				Navigator.of(context).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: this.board, id: this.threadId, initialPostId: this.postId)));
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