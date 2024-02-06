
import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
part 'shareable_posts.g.dart';

List<Post> findAncestors(PostSpanZoneData zone, Post post) {
	final List<Post> posts = [];
	if (zone.stackIds.length > 1) {
		posts.addAll(zone.stackIds.tryMap(zone.findPost));
	}
	if (posts.tryFirst?.id != post.threadId) {
		// Haven't found OP yet
		// Just go through repliedToIds, tie break by using first parent
		Post? target = (posts.tryFirst ?? post).repliedToIds.tryMapOnce(zone.findPost);
		while (target != null) {
			posts.insert(0, target);
			target = target.repliedToIds.tryMapOnce(zone.findPost);
		}
	}
	return posts;
}

@HiveType(typeId: 42)
class ShareablePostsStyle {
	@HiveField(0)
	final bool useTree;
	@HiveField(1)
	/// 1 means one-level up only, anything higher means all ancestors
	final int parentDepth;
	@HiveField(2)
	/// 1 means one-level down only, anything higher means all descendants
	final int childDepth;
	@HiveField(3)
	final double width;
	@HiveField(4)
	final String? overrideThemeKey;
	@HiveField(5)
	final bool expandPrimaryImage;
	@HiveField(6, defaultValue: true)
	final bool revealYourPosts;
	@HiveField(7, defaultValue: true)
	final bool includeFooter;

	const ShareablePostsStyle({
		this.useTree = false,
		this.parentDepth = 0,
		this.childDepth = 0,
		this.width = 700,
		this.overrideThemeKey,
		this.expandPrimaryImage = false,
		this.revealYourPosts = true,
		this.includeFooter = true
	});
}

class ShareablePosts extends StatefulWidget {
	final int primaryPostId;
	final ShareablePostsStyle style;

	const ShareablePosts({
		required this.primaryPostId,
		required this.style,
		super.key
	});

	@override
	createState() => _ShareablePostsState();
}

class _ShareablePostsState extends State<ShareablePosts> {
	late final RefreshableListController<Post> controller;

	@override
	void initState() {
		super.initState();
		controller = RefreshableListController();
	}

	@override
	Widget build(BuildContext context) {
		final style = widget.style;
		final primaryPostId = widget.primaryPostId;
		final imageboard = context.read<Imageboard>();
		final zone = context.read<PostSpanZoneData>();
		final theme = context.read<SavedTheme>();
		final options = PostSpanRenderOptions(
			imageShareMode: true,
			revealYourPosts: style.revealYourPosts
		);
		Widget child;
		if (style.useTree) {
			child = Container(
				width: style.width,
				color: theme.backgroundColor,
				child: RefreshableList<Post>(
					shrinkWrap: true,
					disableUpdates: true,
					listUpdater: () => throw UnimplementedError(),
					initialList: zone.findThread(zone.primaryThreadId)!.posts,
					id: 'shareable',
					filterableAdapter: (p) => p,
					itemBuilder: (context, p) => PostRow(
						post: p,
						largeImageWidth: (p.id == primaryPostId && style.expandPrimaryImage) ? style.width : null,
						highlight: p.id == primaryPostId && ((style.childDepth > 0 && p.replyIds.isNotEmpty) || (style.parentDepth > 0 && p.repliedToIds.isNotEmpty)),
						baseOptions: options,
						showBoardName: p.id == primaryPostId,
						showSiteIcon: p.id == primaryPostId,
						revealYourPosts: style.revealYourPosts,
						revealSpoilerImages: true
					),
					collapsedItemBuilder: ({
						required BuildContext context,
						required Post? value,
						required Set<int> collapsedChildIds,
						required bool loading,
						required double? peekContentHeight,
						required List<ParentAndChildIdentifier>? stubChildIds
					}) {
						final settings = context.watch<EffectiveSettings>();
						if (peekContentHeight != null && value != null) {
							final post = Builder(
								builder: (context) => PostRow(
									post: value,
									dim: peekContentHeight.isFinite,
									baseOptions: options,
									showBoardName: value.id == primaryPostId,
									showSiteIcon: value.id == primaryPostId,
									revealYourPosts: style.revealYourPosts,
									revealSpoilerImages: true,
									overrideReplyCount: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											RotatedBox(
												quarterTurns: 1,
												child: Icon(CupertinoIcons.chevron_right_2, size: 14, color: theme.secondaryColor)
											),
											if (collapsedChildIds.isNotEmpty) Text(
												' ${collapsedChildIds.length}${collapsedChildIds.contains(-1) ? '+' : ''}',
												style: TextStyle(
													color: theme.secondaryColor,
													fontWeight: FontWeight.bold
												)
											)
										]
									)
								)
							);
							return IgnorePointer(
								ignoring: peekContentHeight.isFinite,
								child: ConstrainedBox(
									constraints: BoxConstraints(
										maxHeight: peekContentHeight
									),
									child: post
								)
							);
						}
						return IgnorePointer(
							child: Container(
								width: double.infinity,
								padding: const EdgeInsets.all(8),
								child: Row(
									children: [
										if (value != null) Expanded(
											child: Text.rich(
												buildPostInfoRow(
													post: value,
													isYourPost: zone.primaryThreadState?.youIds.contains(value.id) ?? false,
													settings: settings,
													theme: theme,
													site: imageboard.site,
													context: context,
													zone: zone
												)
											)
										)
										else const Spacer(),
										if (loading) ...[
											const CircularProgressIndicator.adaptive(),
											const Text(' ')
										],
										if (collapsedChildIds.isNotEmpty) Text(
											'${collapsedChildIds.length}${collapsedChildIds.contains(-1) ? '+' : ''} '
										),
										const Icon(CupertinoIcons.chevron_down, size: 20)
									]
								)
							)
						);
					},
					useTree: true,
					initialPrimarySubtreeParents: zone.primaryThreadState?.primarySubtreeParents,
					controller: controller,
					treeAdapter: RefreshableTreeAdapter(
						filter: (item) {
							if (item.id == primaryPostId) {
								return true;
							}
							if (style.parentDepth == 1 && item.item.replyIds.contains(primaryPostId) && !controller.isItemHidden(item).isDuplicate) {
								return true;
							}
							else if (style.parentDepth > 1 && item.treeDescendantIds.contains(primaryPostId)) {
								return true;
							}
							if (style.childDepth == 1 && item.item.repliedToIds.contains(primaryPostId)) {
								return true;
							}
							else if (style.childDepth > 1 && item.parentIds.contains(primaryPostId)) {
								return true;
							}
							return false;
						},
						getId: (p) => p.id,
						getParentIds: (p) => p.repliedToIds,
						getIsStub: (p) => p.isStub,
						getHasOmittedReplies: (p) => p.hasOmittedReplies,
						updateWithStubItems: (_, ids) => throw UnimplementedError(),
						opId: zone.primaryThreadId,
						wrapTreeChild: (child, parentIds) {
							PostSpanZoneData childZone = zone;
							for (final id in parentIds) {
								childZone = childZone.childZoneFor(id, style: PostSpanZoneStyle.tree);
							}
							return ChangeNotifierProvider.value(
								value: childZone,
								child: child
							);
						},
						estimateHeight: (post, width) {
							final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 17;
							return post.span.estimateLines(
								(width / (0.55 * fontSize * (DefaultTextStyle.of(context).style.height ?? 1.2))).lazyCeil().toDouble()
							).ceil() * fontSize;
						},
						initiallyCollapseSecondLevelReplies: false,
						collapsedItemsShowBody: false,
						repliesToOPAreTopLevel: imageboard.persistence.browserState.treeModeRepliesToOPAreTopLevel,
						newRepliesAreLinear: false
					)
				)
			);
		}
		else {
			final post = zone.findPost(primaryPostId)!;
			final List<Post> parentPosts = [];
			if (style.parentDepth == 1) {
				final parent = zone.findPost(zone.stackIds.tryLast ?? -1) ?? zone.findPost(post.repliedToIds.tryFirst ?? -1);
				if (parent != null) {
					parentPosts.add(parent);
				}
			}
			else if (style.parentDepth > 1) {
				parentPosts.addAll(findAncestors(zone, post));
			}
			final parents = <(Post, int)>[];
			if (parentPosts.isNotEmpty) {
				parents.add((parentPosts.first, -1));
				for (int i = 1; i < parentPosts.length; i++) {
					parents.add((parentPosts[i], parentPosts[i - 1].id));
				}
			}
			final List<Post> children = style.childDepth > 0 ? post.replyIds.tryMap(zone.findPost).toList() : [];
			final primaryPost = PostSpanZone(
				postId: parents.tryLast?.$1.id ?? -1,
				builder: (context) => PostRow(
					post: post,
					revealSpoilerImages: true,
					highlight: parents.isNotEmpty || children.isNotEmpty,
					largeImageWidth: style.expandPrimaryImage ? style.width : null,
					shrinkWrap: true,
					showBoardName: true,
					showSiteIcon: true,
					baseOptions: options,
					revealYourPosts: style.revealYourPosts
				)
			);
			child = (parents.isEmpty && children.isEmpty) ? ConstrainedBox(
				constraints: BoxConstraints(
					maxWidth: style.width
				),
				child: primaryPost
			) : Container(
				color: theme.barColor,
				width: style.width,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const SizedBox(height: 8),
						for (final parent in parents) Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
							child: PostSpanZone(
								postId: parent.$2,
								builder: (context) => PostRow(
									post: parent.$1,
									revealSpoilerImages: true,
									shrinkWrap: true,
									baseOptions: options,
									revealYourPosts: style.revealYourPosts
								)
							)
						),
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
							child: primaryPost
						),
						for (final child in children) Padding(
							padding: EdgeInsets.only(left: 16 + (style.width / 10), right: 16, top: 8, bottom: 8),
							child: PostSpanZone(
								postId: primaryPostId,
								builder: (contxt) => PostRow(
									post: child,
									revealSpoilerImages: true,
									shrinkWrap: true,
									baseOptions: options,
									revealYourPosts: style.revealYourPosts
								)
							)
						),
						const SizedBox(height: 8)
					]
				)
			);
		}
		if (style.includeFooter) {
			String footer = zone.imageboard.site.formatBoardName(zone.board);
			if (zone.imageboard.site.explicitIds) {
				footer += ' Thread ${zone.primaryThreadId}';
			}
			final title = zone.findThread(zone.primaryThreadId)?.title;
			if (title != null) {
				footer += ': $title';
			}
			footer += '\n';
			footer += zone.imageboard.site.getWebUrl(
				board: zone.board,
				threadId: zone.primaryThreadId,
				postId: primaryPostId == zone.primaryThreadId ? null : primaryPostId,
				archiveName: zone.findThread(zone.primaryThreadId)?.archiveName
			);
			return Container(
				color: (!style.useTree && style.childDepth == 0 && style.parentDepth == 0) ? theme.barColor : theme.backgroundColor,
				width: style.width,
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						child,
						Padding(
							padding: const EdgeInsets.all(10),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Flexible(
										child: AutoSizeText(
											footer,
											maxLines: 2
										)
									)
								]
							)
						)
					]
				)
			);
		}
		return child;
	}

	@override
	void dispose() {
		super.dispose();
		controller.dispose();
	}
}
