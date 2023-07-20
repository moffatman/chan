import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';

class _PostsPageItem {
	final bool stub;
	final Post? post;
	final List<ParentAndChildIdentifier>? stubIds;
	bool loading = false;

	_PostsPageItem.post(this.post) : stubIds = null, stub = false;
	_PostsPageItem.primaryStub(List<ParentAndChildIdentifier> this.stubIds) : post = null, stub = true;
	_PostsPageItem.secondaryStub(this.post) : stubIds = null, stub = true;

	@override
	String toString() => '_PostsPageItem(post: $post, stub: $stub, stubIds: $stubIds)';
}

class PostsPage extends StatefulWidget {
	final PostSpanZoneData zone;
	final int? postIdForBackground;
	final List<int> postsIdsToShow;
	final ValueChanged<Post>? onTap;
	final int? isRepliesForPostId;
	final bool clearStack;
	final Widget? header;

	const PostsPage({
		required this.postsIdsToShow,
		this.postIdForBackground,
		required this.zone,
		this.onTap,
		this.isRepliesForPostId,
		this.clearStack = false,
		this.header,
		Key? key
	}) : super(key: key);

	@override
	createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
	int _forceRebuildId = 0;
	final List<_PostsPageItem> replies = [];

	@override
	void initState() {
		super.initState();
		_setReplies();
		if (replies.tryLast?.stub ?? false) {
			// If there are only stubs, load them upon opening
			_onTapStub(replies.last);
		}
	}

	Future<void> _onTapStub(_PostsPageItem reply) async {
		reply.loading = true;
		setState(() {});
		try {
			await widget.zone.onNeedUpdateWithStubItems?.call(reply.stubIds!);
			_setReplies();
		}
		catch (e) {
			alertError(context, e.toStringDio());
		}
		reply.loading = false;
		_forceRebuildId++; // We are mutating [replies], so need to force sliver delegate to rebuild
		setState(() {});
	}

	void _setReplies() {
		replies.clear();
		for (final id in widget.postsIdsToShow) {
			final matchingPost = widget.zone.findPost(id);
			if (matchingPost != null) {
				if (matchingPost.isStub) {
					replies.add(_PostsPageItem.secondaryStub(matchingPost));
				}
				else {
					replies.add(_PostsPageItem.post(matchingPost));
				}
			}
			else {
				final archivedPost = widget.zone.postFromArchive(id);
				if (archivedPost != null) {
					replies.add(_PostsPageItem.post(archivedPost));
				}
			}
		}
		for (final method in widget.zone.postSortingMethods) {
			mergeSort<_PostsPageItem>(replies, compare: (a, b) => method(a.post!, b.post!));
		}
		final stubPosts = replies.where((p) => p.stub).map((p) => p.post);
		if (stubPosts.isNotEmpty) {
			replies.add(_PostsPageItem.primaryStub(stubPosts.map((p) => ParentAndChildIdentifier(
				parentId: p!.parentId ?? p.threadId,
				childId: p.id
			)).toList()));
		}
	}

	@override
	Widget build(BuildContext context) {
		final attachments = replies.expand<Attachment>((a) => a.post?.attachments ?? []).toList();
		final subzone = widget.zone.hoistFakeRootZoneFor(0, tree: false, clearStack: widget.clearStack); // To avoid conflict with same semanticIds in tree
		final postForBackground = widget.postIdForBackground == null ? null : widget.zone.findPost(widget.postIdForBackground!);
		final doubleTapScrollToReplies = context.select<EffectiveSettings, bool>((s) => s.doubleTapScrollToReplies);
		final isRepliesForPostId = widget.isRepliesForPostId;
		bool reverse = false;
		PersistentThreadState? isRepliesForPostThreadState;
		if (isRepliesForPostId != null) {
			final isRepliesForPost = widget.zone.findPost(isRepliesForPostId);
			if (isRepliesForPost != null) {
				isRepliesForPostThreadState = widget.zone.imageboard.persistence.getThreadStateIfExists(isRepliesForPost.threadIdentifier);
				reverse = isRepliesForPostThreadState?.postIdsToStartRepliesAtBottom.data.contains(isRepliesForPostId) ?? false;
			}
		}
		final effectiveReplies = reverse ? replies.reversed.toList() : replies;
		final theme = context.watch<SavedTheme>();
		final dividerColor = theme.primaryColorWithBrightness(0.2);
		return ChangeNotifierProvider.value(
			value: subzone,
			child: OverscrollModalPage.sliver(
				reverse: reverse,
				background: postForBackground == null ? null : PostRow(
					post: postForBackground,
					isSelected: true
				),
				heightEstimate: 100.0 * (widget.postsIdsToShow.length - 1),
				onPop: (direction) {
					if (isRepliesForPostId == null) {
						return;
					}
					if (direction == AxisDirection.down) {
						isRepliesForPostThreadState?.postIdsToStartRepliesAtBottom.data.add(isRepliesForPostId);
					}
					else {
						isRepliesForPostThreadState?.postIdsToStartRepliesAtBottom.data.remove(isRepliesForPostId);
					}
				},
				sliver: SliverList(
					delegate: SliverDontRebuildChildBuilderDelegate(
						addRepaintBoundaries: false,
						list: effectiveReplies,
						id: _forceRebuildId.toString(),
						childCount: max(0, ((replies.length + (widget.header != null ? 1 : 0)) * 2) - 1),
						(context, i) {
							if (widget.header != null && i == 0) {
								return widget.header;
							}
							final reply = effectiveReplies[widget.header == null ? i : (i - 1)];
							return Container(
								color: theme.backgroundColor,
								key: ValueKey(reply.post?.id ?? 0),
								child: AnimatedCrossFade(
									crossFadeState: reply.stub ? CrossFadeState.showFirst : CrossFadeState.showSecond,
									duration: const Duration(milliseconds: 350),
									sizeCurve: Curves.ease,
									firstCurve: Curves.ease,
									firstChild: reply.stubIds == null ? const SizedBox(
										height: 0,
										width: double.infinity,
									) : GestureDetector(
										onTap: () => _onTapStub(reply),
										child: Container(
											width: double.infinity,
											height: 50,
											padding: const EdgeInsets.all(8),
											color: theme.backgroundColor,
											child: Row(
												children: [
													const Spacer(),
													if (reply.loading) ...[
														const CircularProgressIndicator.adaptive(),
														const Text(' ')
													],
													Text(
														'${reply.stubIds?.length} '
													),
													const Icon(CupertinoIcons.chevron_down, size: 20)
												]
											)
										)
									),
									secondChild: reply.post == null ? const SizedBox(
										height: 0,
										width: double.infinity
									) : PostRow(
										post: reply.post!,
										onTap: widget.onTap == null ? null : () => widget.onTap!(reply.post!),
										onDoubleTap: !doubleTapScrollToReplies || widget.zone.onNeedScrollToPost == null
																	? null : () => widget.zone.onNeedScrollToPost!(reply.post!),
										onThumbnailTap: (attachment) {
											final threadState = widget.zone.imageboard.persistence.getThreadStateIfExists(reply.post!.threadIdentifier);
											showGallery(
												context: context,
												attachments: attachments,
												replyCounts: {
													for (final reply in replies)
														for (final attachment in reply.post!.attachments)
															attachment: reply.post!.replyIds.length
												},
												isAttachmentAlreadyDownloaded: threadState?.isAttachmentDownloaded,
												onAttachmentDownload: threadState?.didDownloadAttachment,
												initialAttachment: attachment,
												semanticParentIds: subzone.stackIds,
												onChange: (attachment) {
													Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 200));
												},
												heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
											);
										}
									)
								)
							);
						},
						separatorBuilder: (context, i) => Divider(
							thickness: 1,
							height: 0,
							color: dividerColor
						),
						separatorSentinel: dividerColor
					)
				)
			)
		);
	}
}