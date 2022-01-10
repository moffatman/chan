import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/widgets/post_row.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chan/models/post.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class OpenGalleryIntent extends Intent {
	const OpenGalleryIntent();
}

class ThreadPage extends StatefulWidget {
	final ThreadIdentifier thread;
	final int? initialPostId;
	final bool initiallyUseArchive;
	final int boardSemanticId;

	const ThreadPage({
		required this.thread,
		this.initialPostId,
		this.initiallyUseArchive = false,
		required this.boardSemanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
	late PersistentThreadState persistentState;
	final _shareButtonKey = GlobalKey();
	final _weakNavigatorKey = GlobalKey<WeakNavigatorState>();
	final _replyBoxKey = GlobalKey<ReplyBoxState>();

	final _listController = RefreshableListController<Post>();
	late PostSpanRootZoneData zone;
	bool blocked = false;
	bool _unnaturallyScrolling = false;
	late Listenable _threadStateListenable;
	Thread? lastThread;

	void _onThreadStateListenableUpdate() {
		if (persistentState.thread != lastThread) {
			setState(() {});
		}
		lastThread = persistentState.thread;
	}

	Thread get _nullThread => Thread(
		board: widget.thread.board,
		id: widget.thread.id,
		isDeleted: false,
		isArchived: false,
		title: '',
		isSticky: false,
		replyCount: -1,
		imageCount: -1,
		time: DateTime.fromMicrosecondsSinceEpoch(0),
		posts: [],
	);

	Future<void> _blockAndScrollToPostIfNeeded([Duration delayBeforeScroll = Duration.zero]) async {
		final int? scrollToId = widget.initialPostId ?? persistentState.lastSeenPostId;
		if (persistentState.thread != null && scrollToId != null) {
			setState(() {
				blocked = true;
				_unnaturallyScrolling = true;
			});
			await Future.delayed(delayBeforeScroll);
			final alignment = (scrollToId == widget.initialPostId) ? 0.0 : 1.0;
			try {
				await WidgetsBinding.instance!.endOfFrame;
				await _listController.animateTo((post) => post.id == scrollToId, orElseLast: (post) => post.id <= scrollToId, alignment: alignment, duration: const Duration(milliseconds: 1));
				await WidgetsBinding.instance!.endOfFrame;
			}
			catch (e, st) {
				print('${widget.thread} Error scrolling');
				print(e);
				print(st);
			}
			if (mounted) {
				setState(() {
					blocked = false;
				});
			}
			await Future.delayed(const Duration(milliseconds: 200));
			_unnaturallyScrolling = false;
		}
	}

	@override
	void initState() {
		super.initState();
		persistentState = context.read<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
		persistentState.useArchive |= widget.initiallyUseArchive;
		persistentState.save();
		zone = PostSpanRootZoneData(
			thread: persistentState.thread ?? _nullThread,
			site: context.read<ImageboardSite>(),
			threadState: persistentState,
			semanticRootIds: [widget.boardSemanticId, 0],
			onNeedScrollToPost: (post) {
				_weakNavigatorKey.currentState!.popAllExceptFirst();
				Future.delayed(const Duration(milliseconds: 150), () => _listController.animateTo((val) => val.id == post.id));
			}
		);
		Future.delayed(const Duration(milliseconds: 50), () {
			_threadStateListenable = context.read<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
		});
		_listController.slowScrollUpdates.listen((_) {
			if (persistentState.thread != null && !_unnaturallyScrolling && _listController.lastVisibleIndex >= 0) {
				final newLastSeen = persistentState.thread!.posts[_listController.lastVisibleIndex].id;
				if (newLastSeen > (persistentState.lastSeenPostId ?? 0)) {
					persistentState.lastSeenPostId = newLastSeen;
					persistentState.save();
				}
			}
		});
		_blockAndScrollToPostIfNeeded();
	}

	@override
	void didUpdateWidget(ThreadPage old) {
		super.didUpdateWidget(old);
		if (widget.thread != old.thread) {
			_threadStateListenable.removeListener(_onThreadStateListenableUpdate);
			_threadStateListenable = context.watch<Persistence>().listenForPersistentThreadStateChanges(widget.thread);
			_threadStateListenable.addListener(_onThreadStateListenableUpdate);
			_weakNavigatorKey.currentState!.popAllExceptFirst();
			persistentState.save(); // Save old state in case it had pending scroll update to save
			persistentState = context.watch<Persistence>().getThreadState(widget.thread, updateOpenedTime: true);
			persistentState.useArchive |= widget.initiallyUseArchive;
			final oldZone = zone;
			Future.delayed(const Duration(milliseconds: 100), () => oldZone.dispose());
			zone = PostSpanRootZoneData(
				thread: persistentState.thread ?? _nullThread,
				site: context.read<ImageboardSite>(),
				threadState: persistentState,
				onNeedScrollToPost: oldZone.onNeedScrollToPost,
				semanticRootIds: [widget.boardSemanticId, 0]
			);
			persistentState.save();
			_blockAndScrollToPostIfNeeded(const Duration(milliseconds: 100));
			setState(() {});
		}
		else if (widget.initialPostId != old.initialPostId && widget.initialPostId != null) {
			_listController.animateTo((post) => post.id == widget.initialPostId!, orElseLast: (post) => post.id <= widget.initialPostId!, alignment: 0.0, duration: const Duration(milliseconds: 500));
		}
	}

	void _showGallery({bool initiallyShowChrome = false, Attachment? initialAttachment}) {
		final attachments = persistentState.thread!.posts.where((_) => _.attachment != null).map((_) => _.attachment!).toList();
		showGallery(
			context: context,
			attachments: attachments,
			initiallyShowChrome: initiallyShowChrome,
			initialAttachment: (initialAttachment == null) ? null : attachments.firstWhere((a) => a.id == initialAttachment.id),
			onChange: (attachment) {
				_listController.animateTo((p) => p.attachment?.id == attachment.id);
			},
			semanticParentIds: [widget.boardSemanticId, 0]
		);
	}

	Widget _limitCounter(int value, int? maximum) {
		if (maximum != null && (value >= maximum * 0.8)) {
			return Text('$value / $maximum', style: TextStyle(
				color: value >= maximum ? Colors.red : null
			));
		}
		else {
			return Text('$value ');
		}
	}

	Future<void> _switchToArchive() async {
		persistentState.useArchive = true;
		await persistentState.save();
		setState(() {});
		await _listController.blockAndUpdate();
	}

	Future<void> _switchToLive() async {
		persistentState.useArchive = false;
		await persistentState.save();
		setState(() {});
		await _listController.blockAndUpdate();
	}

	@override
	Widget build(BuildContext context) {
		final properScrollController = PrimaryScrollController.of(context)!;
		String title = '/${widget.thread.board}/';
		if (persistentState.thread?.title != null) {
			title += ' - ' + context.read<EffectiveSettings>().filterProfanity(persistentState.thread!.title!);
		}
		else {
			title += widget.thread.id.toString();
		}
		if (persistentState.thread?.isArchived ?? false) {
			title += ' (Archived)';
		}
		return Provider.value(
			value: _replyBoxKey,
			child: CupertinoPageScaffold(
				resizeToAvoidBottomInset: false,
				navigationBar: CupertinoNavigationBar(
					transitionBetweenRoutes: false,
					middle: AutoSizeText(title),
					trailing: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: Icon(persistentState.savedTime == null ? Icons.bookmark_outline : Icons.bookmark),
								onPressed: () {
									if (persistentState.savedTime != null) {
										persistentState.savedTime = null;
									}
									else {
										persistentState.savedTime = DateTime.now();
									}
									persistentState.save();
									setState(() {});
								}
							),
							CupertinoButton(
								key: _shareButtonKey,
								padding: EdgeInsets.zero,
								child: const Icon(Icons.ios_share),
								onPressed: () {
									final offset = (_shareButtonKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
									final size = _shareButtonKey.currentContext?.findRenderObject()?.semanticBounds.size;
									Share.share(context.read<ImageboardSite>().getWebUrl(widget.thread.board, widget.thread.id), sharePositionOrigin: (offset != null && size != null) ? offset & size : null);
								}
							),
							CupertinoButton(
								padding: EdgeInsets.zero,
								child: (_replyBoxKey.currentState?.show ?? false) ? SizedBox(
									width: 25,
									height: 25,
									child: Stack(
										fit: StackFit.passthrough,
										children: const [
											Align(
												alignment: Alignment.bottomLeft,
												child: Icon(Icons.reply, size: 20)
											),
											Align(
												alignment: Alignment.topRight,
												child: Icon(Icons.close, size: 15)
											)
										]
									)
								) : const Icon(Icons.reply),
								onPressed: persistentState.thread?.isArchived == true ? null : () {
									_replyBoxKey.currentState?.toggleReplyBox();
									setState(() {});
								}
							)
						]
					)
				),
				child: Builder(
					builder: (context) => Column(
						children: [
							Flexible(
								flex: 1,
								child: Shortcuts(
									shortcuts: {
										LogicalKeySet(LogicalKeyboardKey.keyG): const OpenGalleryIntent()
									},
									child: Actions(
										actions: {
											OpenGalleryIntent: CallbackAction<OpenGalleryIntent>(
												onInvoke: (i) {
													if (context.read<EffectiveSettings>().showImages(context, widget.thread.board)) {
														final nextPostWithImage = persistentState.thread?.posts.skip(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null, orElse: () {
															return persistentState.thread!.posts.take(_listController.firstVisibleIndex).firstWhere((p) => p.attachment != null);
														});
														if (nextPostWithImage != null) {
															_showGallery(initialAttachment: nextPostWithImage.attachment);
														}
													}
													return null;
												}
											)
										},
										child: Focus(
											autofocus: true,
											child: WeakNavigator(
												key: _weakNavigatorKey,
												child: Stack(
													fit: StackFit.expand,
													children: [
														ChangeNotifierProvider<PostSpanZoneData>.value(
															value: zone,
															child: PrimaryScrollController(
																controller: properScrollController,
																child: RefreshableList<Post>(
																	id: '/${widget.thread.board}/${widget.thread.id}',
																	disableUpdates: persistentState.thread?.isArchived ?? false,
																	autoUpdateDuration: const Duration(seconds: 60),
																	initialList: persistentState.thread?.posts,
																	filters: [
																		context.watch<EffectiveSettings>().filter,
																		IDFilter(persistentState.hiddenPostIds)
																	],
																	footer: Container(
																		padding: const EdgeInsets.all(16),
																		child: (persistentState.thread == null) ? null : Row(
																			children: [
																				const Spacer(),
																				const Icon(Icons.reply_rounded),
																				const SizedBox(width: 4),
																				_limitCounter(persistentState.thread!.replyCount, context.watch<Persistence>().getBoard(widget.thread.board).threadCommentLimit),
																				const Spacer(),
																				const Icon(Icons.image),
																				const SizedBox(width: 4),
																				_limitCounter(persistentState.thread!.imageCount, context.watch<Persistence>().getBoard(widget.thread.board).threadImageLimit),
																				const Spacer(),
																				if (persistentState.thread!.uniqueIPCount != null) ...[
																					const Icon(Icons.person),
																					const SizedBox(width: 4),
																					Text('${persistentState.thread!.uniqueIPCount}'),
																					const Spacer(),
																				],
																				if (persistentState.thread!.currentPage != null) ...[
																					const Icon(Icons.insert_drive_file_rounded),
																					const SizedBox(width: 4),
																					_limitCounter(persistentState.thread!.currentPage!, context.watch<Persistence>().getBoard(widget.thread.board).pageCount),
																					const Spacer()
																				],
																				if (persistentState.thread!.isArchived) ...[
																					GestureDetector(
																						behavior: HitTestBehavior.opaque,
																						child: Row(
																							children: const [
																								Icon(Icons.archive, color: Colors.grey),
																								SizedBox(width: 4),
																								Text('Archived'),
																							]
																						),
																						onTap: _switchToLive
																					),
																					const Spacer()
																				]
																			]
																		)
																	),
																	remedies: {
																		ThreadNotFoundException: (context, updater) => CupertinoButton.filled(
																			child: const Text('Try archive'),
																			onPressed: () {
																				persistentState.useArchive = true;
																				persistentState.save();
																				updater();
																			}
																		)
																	},
																	listUpdater: () async {
																		final _persistentState = persistentState;
																		// The thread might switch in this interval
																		final _thread = _persistentState.useArchive ?
																			await context.read<ImageboardSite>().getThreadFromArchive(widget.thread) :
																			await context.read<ImageboardSite>().getThread(widget.thread);
																		final bool firstLoad = _persistentState.thread == null;
																		bool shouldScroll = false;
																		if (_thread != _persistentState.thread) {
																			_persistentState.thread = _thread;
																			if (persistentState == _persistentState) {
																				zone.thread = _thread;
																				if (firstLoad) shouldScroll = true;
																			}
																			await _persistentState.save();
																			setState(() {});
																			Future.delayed(const Duration(milliseconds: 100), () {
																				if (persistentState == _persistentState && !_unnaturallyScrolling) {
																					if (_listController.lastVisibleIndex != -1) {
																						_persistentState.lastSeenPostId = max(_persistentState.lastSeenPostId ?? 0, _persistentState.thread!.posts[_listController.lastVisibleIndex].id);
																						_persistentState.save();
																						setState(() {});
																					}
																					else {
																						print('Failed to find last visible post after an update in $_persistentState');
																					}
																				}
																			});
																		}
																		if (shouldScroll) _blockAndScrollToPostIfNeeded(const Duration(milliseconds: 500));
																		// Don't show data if the thread switched
																		if (persistentState == _persistentState) {
																			return _thread.posts;
																		}
																		return null;
																	},
																	controller: _listController,
																	itemBuilder: (context, post) {
																		return PostRow(
																			post: post,
																			onThumbnailTap: (attachment) {
																				_showGallery(initialAttachment: attachment);
																			},
																			onRequestArchive: _switchToArchive
																		);
																	},
																	filteredItemBuilder: (context, post, resetPage) {
																		return PostRow(
																			post: post,
																			onThumbnailTap: (attachment) {
																				_showGallery(initialAttachment: attachment);
																			},
																			onRequestArchive: _switchToArchive,
																			onTap: () {
																				resetPage();
																				Future.delayed(const Duration(milliseconds: 250), () => _listController.animateTo((val) => val.id == post.id));
																			}
																		);
																	},
																	filterHint: 'Search in thread'
																)
															)
														),
														StreamBuilder(
															stream: _listController.slowScrollUpdates,
															builder: (context, a) {
																final redCount = persistentState.unseenReplyIdsToYou?.length ?? 0;
																final whiteCount = persistentState.unseenReplyCount ?? 0;
																int greyCount = 0;
																if (persistentState.thread != null && persistentState.lastSeenPostId != -1 && _listController.lastVisibleIndex != -1) {
																	greyCount = persistentState.thread!.posts.length - whiteCount - (_listController.lastVisibleIndex + 2);
																}
																const radius = Radius.circular(8);
																const radiusAlone = BorderRadius.all(radius);
																scrollToBottom() => _listController.animateTo((post) => post.id == persistentState.thread!.posts.last.id, alignment: 1.0);
																if (redCount > 0 || whiteCount > 0 || greyCount > 0) {
																	return SafeArea(
																		child: Align(
																			alignment: Alignment.bottomRight,
																			child: GestureDetector(
																				child: Row(
																					mainAxisSize: MainAxisSize.min,
																					children: [
																						if (redCount > 0) Container(
																							decoration: BoxDecoration(
																								borderRadius: (whiteCount > 0 || greyCount > 0) ? const BorderRadius.only(topLeft: radius, bottomLeft: radius) : radiusAlone,
																								color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
																							),
																							padding: const EdgeInsets.all(8),
																							margin: EdgeInsets.only(bottom: 16, right: (whiteCount == 0 && greyCount == 0) ? 16 : 0),
																							child: Text(
																								redCount.toString(),
																								textAlign: TextAlign.center
																							)
																						),
																						if (greyCount > 0) Container(
																							decoration: BoxDecoration(
																								borderRadius: (redCount > 0) ? (whiteCount > 0 ? null : const BorderRadius.only(topRight: radius, bottomRight: radius)) : (whiteCount > 0 ? const BorderRadius.only(topLeft: radius, bottomLeft: radius) : radiusAlone),
																								color: CupertinoTheme.of(context).primaryColorWithBrightness(0.6)
																							),
																							padding: const EdgeInsets.all(8),
																							margin: EdgeInsets.only(bottom: 16, right: whiteCount > 0 ? 0 : 16),
																							child: Container(
																								constraints: BoxConstraints(
																									minWidth: 24 * MediaQuery.of(context).textScaleFactor
																								),
																								child: Text(
																									greyCount.toString(),
																									style: TextStyle(
																										color: CupertinoTheme.of(context).scaffoldBackgroundColor
																									),
																									textAlign: TextAlign.center
																								)
																							)
																						),
																						if (whiteCount > 0) Container(
																							decoration: BoxDecoration(
																								borderRadius: (greyCount > 0 || redCount > 0) ? const BorderRadius.only(topRight: radius, bottomRight: radius) : radiusAlone,
																								color: CupertinoTheme.of(context).primaryColor
																							),
																							padding: const EdgeInsets.all(8),
																							margin: const EdgeInsets.only(bottom: 16, right: 16),
																							child: Container(
																								constraints: BoxConstraints(
																									minWidth: 24 * MediaQuery.of(context).textScaleFactor
																								),
																								child: Text(
																									whiteCount.toString(),
																									style: TextStyle(
																										color: CupertinoTheme.of(context).scaffoldBackgroundColor
																									),
																									textAlign: TextAlign.center
																								)
																							)
																						)
																					]
																				),
																				onTap: () => _listController.animateTo((post) => post.id == persistentState.lastSeenPostId, alignment: 1.0),
																				onLongPress: scrollToBottom
																			)
																		)
																	);
																}
																else {
																	return Container();
																}
															}
														),
														if (blocked) Container(
															color: CupertinoTheme.of(context).scaffoldBackgroundColor,
															child: const Center(
																child: CupertinoActivityIndicator()
															)
														)
													]
												)
											)
										)
									)
								)
							),
							ReplyBox(
								key: _replyBoxKey,
								board: widget.thread.board,
								threadId: widget.thread.id,
								onReplyPosted: (receipt) {
									persistentState.savedTime = DateTime.now();
									persistentState.save();
									_listController.update();
								}
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_listController.dispose();
	}
}