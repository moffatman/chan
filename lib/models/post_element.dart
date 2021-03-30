import 'package:chan/models/post.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/posts.dart';
import 'package:chan/pages/tab.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/post_expander.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:cupertino_back_gesture/src/cupertino_page_route.dart' as cpr;

abstract class PostSpan {
	List<int> get referencedPostIds {
		return [];
	}
	InlineSpan build(BuildContext context, {GestureRecognizer? recognizer, bool overrideRecognizer = false});
}

class PostNodeSpan extends PostSpan {
	List<PostSpan> children;

	PostNodeSpan(this.children);

	List<int> get referencedPostIds {
		return children.expand((child) => child.referencedPostIds).toList();
	}

	build(context, {recognizer, overrideRecognizer = false}) {
		return TextSpan(
			children: children.map((child) => child.build(context, recognizer: recognizer, overrideRecognizer: overrideRecognizer)).toList()
		);
	}
}

class PostTextSpan extends PostSpan {
	final String text;
	PostTextSpan(this.text);
	build(context, {recognizer, overrideRecognizer = false}) {
		return TextSpan(
			text: this.text,
			recognizer: recognizer
		);
	}
}

class PostLineBreakSpan extends PostSpan {
	PostLineBreakSpan();
	build(context, {recognizer, overrideRecognizer = false}) {
		return WidgetSpan(
			child: Row(
				children: [Text('')],
			)
		);
	}
}

class PostQuoteSpan extends PostSpan {
	final PostSpan child;
	PostQuoteSpan(this.child);
	build(context, {recognizer, overrideRecognizer = false}) {
		return TextSpan(
			children: [child.build(context)],
			style: TextStyle(color: Colors.green),
			recognizer: recognizer
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
				if (childBox == null || !childBox.attached) {
					return;
				}
				final childTop = childBox.localToGlobal(Offset.zero).dy;
				final childBottom = childBox.localToGlobal(Offset(0, childBox.size.height)).dy;
				final childCenterHorizontal = childBox.localToGlobal(Offset(childBox.size.width / 2, 0)).dx;
				final topOfUsableSpace = MediaQuery.of(context).size.height / 2;
				final hoverWidth = MediaQuery.of(context).size.width / 2;
				final showOnRight = childCenterHorizontal > (MediaQuery.of(context).size.width / 2);
				final left = childBox.localToGlobal(Offset.zero).dx;
				final right = (MediaQuery.of(context).size.width - childBox.localToGlobal(Offset(childBox.size.width, 0)).dx);
				_entry = OverlayEntry(
					builder: (context) {
						return Positioned(
							right: showOnRight ? right : null,
							left: showOnRight ? null : left,
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
	build(context, {recognizer, overrideRecognizer = false}) {
		final zone = context.watchOrNull<ExpandingPostZone>();
		final sameAsParent = zone?.parentIds.contains(id) ?? false;
		final postList = context.watch<List<Post>>();
		final post = postList.firstWhere((p) => p.id == this.id);
		final settings = context.watch<Settings>();
		final newParentIds = (zone?.parentIds ?? []).followedBy([post.id]).toList();
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
						recognizer: (recognizer != null && overrideRecognizer) ? recognizer : (TapGestureRecognizer()..onTap = () {
							if (!sameAsParent && zone != null) {
								if (settings.useTouchLayout) {
									Navigator.of(context).push(
										TransparentRoute(
											builder: (ctx) => PostsPage(
												threadPosts: postList,
												postsIdsToShow: [post.id],
												parentIds: newParentIds
											)
										)
									);
								}
								else {
									zone.toggleExpansionOfPost(this.id);
								}
							}
						})
					),
					textScaleFactor: 1
				),
				popup: MultiProvider(
					providers: [
						Provider.value(value: post),
						Provider.value(value: postList),
						ChangeNotifierProvider(create: (_) => ExpandingPostZone(newParentIds))
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

	build(context, {recognizer, overrideRecognizer = false}) => WidgetSpan(child: this.builder(context));
}

class PostExpandingQuoteLinkSpan extends PostNodeSpan {
	PostExpandingQuoteLinkSpan(int id) : super([
		PostQuoteLinkSpan(id),
		PostWidgetSpan((ctx) => ExpandingPost(id))
	]);
}

class PostDeadQuoteLinkSpan extends PostSpan {
	final int id;
	final String? board;
	PostDeadQuoteLinkSpan(this.id, {this.board});
	build(context, {recognizer, overrideRecognizer = false}) {
		final showBoard = context.watch<Post>().board != board && board != null;
		return TextSpan(
			text: (showBoard ? '>>/$board/' : '>>') + this.id.toString(),
			style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red),
			recognizer: recognizer
		);
	}
}

class PostCrossThreadQuoteLinkSpan extends PostSpan {
	final String board;
	final int postId;
	final int threadId;
	PostCrossThreadQuoteLinkSpan(this.board, this.threadId, this.postId);
	build(context, {recognizer, overrideRecognizer = false}) {
		final showBoard = context.watch<Post>().board != board;
		final site = context.watch<ImageboardSite>();
		return TextSpan(
			text: (showBoard ? '>>/$board/' : '>>') + this.postId.toString() + ' (Cross-thread)',
			style: TextStyle(
				color: Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: (recognizer != null && overrideRecognizer) ? recognizer : (TapGestureRecognizer()..onTap = () async {
				final boards = await site.getBoards();
				(rightPaneNavigatorKey.currentState ?? Navigator.of(context, rootNavigator: true)).push(cpr.CupertinoPageRoute(builder: (ctx) => ThreadPage(board: boards.firstWhere((b) => b.name == board), id: this.threadId, initialPostId: this.postId)));
			})
		);
	}
}

class PostBoardLink extends PostSpan {
	final String board;
	PostBoardLink(this.board);
	build(context, {recognizer, overrideRecognizer = false}) {
		final site = context.watch<ImageboardSite>();
		return TextSpan(
			text: '>>/$board/',
			style: TextStyle(
				color: Colors.red,
				decoration: TextDecoration.underline
			),
			recognizer: (recognizer != null && overrideRecognizer) ? recognizer : (TapGestureRecognizer()..onTap = () async {
				final boards = await site.getBoards();
				(rightPaneNavigatorKey.currentState ?? Navigator.of(context, rootNavigator: true)).push(cpr.CupertinoPageRoute(builder: (ctx) => BoardPage(board: boards.firstWhere((b) => b.name == board))));
			})
		);
	}
}

class PostNewLineSpan extends PostSpan {
	PostNewLineSpan();
	build(context, {recognizer, overrideRecognizer = false}) {
		return WidgetSpan(
			child: Row()
		);
	}
}

class PostSpoilerSpan extends PostSpan {
	final PostSpan child;
	final int id;
	PostSpoilerSpan(this.child, this.id);
	build(context, {recognizer, overrideRecognizer = false}) {
		final zone = context.watchOrNull<ExpandingPostZone>();
		final showSpoiler = zone?.shouldShowSpoiler(id) ?? false;
		final toggleRecognizer = TapGestureRecognizer()..onTap = () {
			zone?.toggleShowingOfSpoiler(id);
		};
		return TextSpan(
			children: [child.build(context, recognizer: toggleRecognizer, overrideRecognizer: !showSpoiler)],
			style: TextStyle(
				backgroundColor: DefaultTextStyle.of(context).style.color,
				color: showSpoiler ? CupertinoTheme.of(context).scaffoldBackgroundColor : null
			),
			recognizer: toggleRecognizer
		);
	}
}

class PostLinkSpan extends PostSpan {
	final String url;
	PostLinkSpan(this.url);
	build(context, {recognizer, overrideRecognizer = false}) {
		return TextSpan(
			text: url,
			style: TextStyle(
				decoration: TextDecoration.underline
			),
			recognizer: TapGestureRecognizer()..onTap = () {
				ChromeSafariBrowser().open(url: Uri.parse(url), options: ChromeSafariBrowserClassOptions(
					android: AndroidChromeCustomTabsOptions(
						toolbarBackgroundColor: CupertinoTheme.of(context).barBackgroundColor
					),
					ios: IOSSafariOptions(
						preferredBarTintColor: CupertinoTheme.of(context).barBackgroundColor,
						preferredControlTintColor: CupertinoTheme.of(context).primaryColor
					)
				));
			}
		);
	}
}