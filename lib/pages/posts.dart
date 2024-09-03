import 'dart:math';

import 'package:chan/models/attachment.dart';
import 'package:chan/models/parent_and_child.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/draft_post.dart';
import 'package:chan/widgets/outbox.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chan/pages/overscroll_modal.dart';

class _PostsPageItem {
	final ParentAndChildIdentifier? stubId;
	final Post? post;
	final PostReceipt? spamFiltered;
	final List<ParentAndChildIdentifier>? stubIds;
	bool get stub => stubId != null || stubIds != null;
	bool loading = false;

	_PostsPageItem.post(Post this.post) : stubIds = null, stubId = null, spamFiltered = null;
	_PostsPageItem.primaryStub(List<ParentAndChildIdentifier> this.stubIds) : post = null, stubId = null, spamFiltered = null;
	_PostsPageItem.secondaryStub(ParentAndChildIdentifier this.stubId) : stubIds = null, post = null, spamFiltered = null;
	_PostsPageItem.spamFiltered(PostReceipt this.spamFiltered) : post = null, stubIds = null, stubId = null;

	@override
	String toString() => '_PostsPageItem(post: $post, stub: $stub, stubIds: $stubIds, spamFiltered: $spamFiltered)';
}

class PostsPage extends StatefulWidget {
	final PostSpanZoneData zone;
	final int? postIdForBackground;
	final List<int> postsIdsToShow;
	final ValueChanged<Post>? onTap;
	final ValueChanged<Attachment>? onThumbnailTap;
	final int? isRepliesForPostId;
	final bool clearStack;
	final Widget? header;

	const PostsPage({
		required this.postsIdsToShow,
		this.postIdForBackground,
		required this.zone,
		this.onTap,
		this.onThumbnailTap,
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
	Map<Post, BuildContext> postContexts = {};

	@override
	void initState() {
		super.initState();
		widget.zone.addListener(_onZoneUpdate);
		_setReplies();
		if (replies.tryLast?.stub ?? false) {
			// If there are only stubs, load them upon opening
			_onTapStub(replies.last);
		}
	}

	void _onZoneUpdate() {
		_setReplies();
		_forceRebuildId++; // We may mutate [replies], so need to force sliver delegate to rebuild
		setState(() {});
	}

	Future<void> _onTapStub(_PostsPageItem reply) async {
		reply.loading = true;
		setState(() {});
		try {
			await widget.zone.onNeedUpdateWithStubItems?.call(reply.stubIds!);
			_setReplies();
		}
		catch (e, st) {
			if (mounted) {
				alertError(context, e, st);
			}
		}
		reply.loading = false;
		_forceRebuildId++; // We are mutating [replies], so need to force sliver delegate to rebuild
		setState(() {});
	}

	void _setReplies() {
		replies.clear();
		for (final id in widget.postsIdsToShow) {
			final matchingPost = widget.zone.findPost(id);
			final matchingDraft = widget.zone.primaryThreadState?.receipts.tryFirstWhere((r) => r.id == id);
			if (matchingPost != null) {
				if (matchingPost.isStub) {
					replies.add(_PostsPageItem.secondaryStub(ParentAndChildIdentifier(
						parentId: matchingPost.parentId ?? matchingPost.threadId,
						childId: matchingPost.id
					)));
				}
				else {
					replies.add(_PostsPageItem.post(matchingPost));
				}
			}
			else if (matchingDraft != null) {
				replies.add(_PostsPageItem.spamFiltered(matchingDraft));
			}
			else if (context.read<ImageboardSite?>()?.isPaged ?? false) {
				// It must be on another page
				replies.add(_PostsPageItem.secondaryStub(ParentAndChildIdentifier(
					parentId: widget.zone.primaryThreadId,
					childId: id
				)));
			}
			else {
				final archivedPost = widget.zone.postFromArchive(widget.zone.board, id);
				if (archivedPost != null) {
					replies.add(_PostsPageItem.post(archivedPost));
				}
			}
		}
		for (final method in widget.zone.postSortingMethods) {
			mergeSort<_PostsPageItem>(replies, compare: (a, b) => method(a.post!, b.post!));
		}
		final stubIds = replies.tryMap((r) => r.stubId).toList();
		if (stubIds.isNotEmpty) {
			replies.add(_PostsPageItem.primaryStub(stubIds));
		}
	}

	@override
	Widget build(BuildContext context) {
		final outerContext = context;
		final attachments = replies.expand<Attachment>((a) => a.post?.attachments ?? []).toList();
		final subzone = widget.zone.hoistFakeRootZoneFor(0, style: PostSpanZoneStyle.linear, clearStack: widget.clearStack); // To avoid conflict with same semanticIds in tree
		final postForBackground = widget.postIdForBackground == null ? null : widget.zone.findPost(widget.postIdForBackground!);
		final doubleTapScrollToReplies = Settings.doubleTapScrollToRepliesSetting.watch(context);
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
									secondChild: reply.post == null ? (reply.spamFiltered != null ? TimedRebuilder<Duration>(
										interval: const Duration(seconds: 1),
										function: () {
											final enoughTime = reply.spamFiltered?.time?.add(const Duration(seconds: 15));
											if (enoughTime == null) {
												return Duration.zero;
											}
											return enoughTime.difference(DateTime.now());
										},
										builder: (context, countdown) {
											if (countdown > Duration.zero) {
												return Padding(
													padding: const EdgeInsets.all(8),
													child: Text('Recently submitted post (${formatDuration(countdown)})')
												);
											}
											final post = reply.spamFiltered?.post;
											if (post == null) {
												return Padding(
													padding: const EdgeInsets.all(8),
													child: Text('Submitted post ${reply.spamFiltered?.id} is missing! This post must have been spam-filtered by ${widget.zone.imageboard.site.name}. Since it was submitted before the Chance v1.2.2 update, it wasn\'t saved for resubmission (😞).')
												);
											}
											return ContextMenu(
												backgroundColor: theme.backgroundColor,
												actions: [
													ContextMenuAction(
														onPressed: () {
															Clipboard.setData(ClipboardData(
																text: post.text
															));
															showToast(
																context: context,
																message: 'Copied "${post.text}" to clipboard',
																icon: CupertinoIcons.doc_on_clipboard
															);
														},
														child: const Text('Copy'),
														trailingIcon: CupertinoIcons.doc_on_clipboard
													),
													ContextMenuAction(
														onPressed: () {
															Outbox.instance.submitPost(widget.zone.imageboard.key, post, QueueStateNeedsCaptcha(outerContext));
															showToast(
																context: context,
																icon: CupertinoIcons.paperplane,
																message: 'Posting...',
																easyButton: ('Outbox', () => showOutboxModalForThread(
																	context: outerContext,
																	imageboardKey: widget.zone.imageboard.key,
																	board: post.board,
																	threadId: post.threadId,
																	canPopWithDraft: false
																))
															);
														},
														child: const Text('Resubmit'),
														trailingIcon: CupertinoIcons.paperplane
													)
												],
												child: Container(
													decoration: const BoxDecoration(
														border: Border(
															left: BorderSide(color: Colors.red, width: 10)
														)
													),
													// Left-padding needs to be a little higher to account for border
													padding: const EdgeInsets.only(left: 10, right: 8, top: 8, bottom: 8),
													child: Column(
														mainAxisSize: MainAxisSize.min,
														crossAxisAlignment: CrossAxisAlignment.end,
														children: [
															DraftPostWidget(
																imageboard: widget.zone.imageboard,
																post: post,
																time: reply.spamFiltered?.time,
																id: reply.spamFiltered?.id,
																origin: DraftPostWidgetOrigin.none
															),
															const Text(
																'Post submitted, but never showed up!\nIt was probably spam-filtered.',
																textAlign: TextAlign.right,
																style: TextStyle(color: Colors.red)
															)
														]
													)
												)
											);
										}
									) : const Text('Missing post')) : BuildContextMapRegistrant(
										value: reply.post!,
										map: postContexts,
										child: PostRow(
											post: reply.post!,
											propagateOnThumbnailTap: widget.onThumbnailTap != null,
											onTap: widget.onTap == null ? null : () => widget.onTap!(reply.post!),
											onDoubleTap: !doubleTapScrollToReplies || widget.zone.onNeedScrollToPost == null
																		? null : () => widget.zone.onNeedScrollToPost!(reply.post!),
											onThumbnailTap: widget.onThumbnailTap ?? (attachment) {
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
														final match = postContexts.entries.tryFirstWhere((p) => p.key.attachments.contains(attachment));
														if (match != null) {
															Scrollable.ensureVisible(match.value, alignment: 0.5, duration: const Duration(milliseconds: 200));
														}
													},
													heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
												);
											}
										)
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

	@override
	void dispose() {
		super.dispose();
		widget.zone.removeListener(_onZoneUpdate);
	}
}