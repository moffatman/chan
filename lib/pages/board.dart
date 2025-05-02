import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/main.dart';
import 'package:chan/models/board.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/board_settings.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/outbox.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/post_selection.dart';
import 'package:chan/services/posts_image.dart';
import 'package:chan/services/report_post.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/pull_tab.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/sliver_staggered_grid.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_gesture_recognizer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:chan/pages/gallery.dart';

const _oldThreadThreshold = Duration(days: 7);

enum _ThreadSortingMethodScope {
	global,
	board,
	tab
}

class _ThreadHidingDialog extends StatefulWidget {
	final Thread thread;
	final RefreshableListFilterReason? listFilterReason;

	const _ThreadHidingDialog({
		required this.thread,
		required this.listFilterReason
	});

	@override
	createState() => _ThreadHidingDialogState();
}

class _ThreadHidingDialogState extends State<_ThreadHidingDialog> {
	@override
	Widget build(BuildContext context) {
		final imageboard = context.watch<Imageboard>();
		return AdaptiveAlertDialog(
			title: const Text('Thread Hiding'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const SizedBox(height: 16),
					if (widget.listFilterReason != null) ...[
						Text('This thread has been filtered by another source:\n${widget.listFilterReason?.reason}\n\nYou can override that by setting "manual control" to "Show" below.'),
						const SizedBox(height: 16)
					],
					const Text('Manual control', style: TextStyle(fontSize: 17)),
					const SizedBox(height: 8),
					AdaptiveChoiceControl<NullSafeOptional>(
						knownWidth: 100,
						children: const {
							NullSafeOptional.null_: (null, 'None'),
							NullSafeOptional.false_: (null, 'Show'),
							NullSafeOptional.true_: (null, 'Hide'),
						},
						groupValue: imageboard.persistence.browserState.getThreadHiding(widget.thread.identifier).value,
						onValueChanged: (newState) {
							imageboard.persistence.browserState.setThreadHiding(widget.thread.identifier, newState.value);
							imageboard.persistence.didUpdateBrowserState();
							setState(() {});
						},
					),
					if (widget.thread.attachments.isNotEmpty)
						if (!Settings.applyImageFilterToThreadsSetting.watch(context)) ...[
							const SizedBox(height: 16),
							const Text('Hiding by image in the catalog is disabled'),
							const SizedBox(height: 8),
							AdaptiveFilledButton(
								padding: const EdgeInsets.all(16),
								child: const Text('Enable'),
								onPressed: () {
									Settings.applyImageFilterToThreadsSetting.value = true;
								}
							)
						]
						else ...[
							const SizedBox(height: 16),
							const Text('Hide by image', style: TextStyle(fontSize: 17)),
							for (final attachment in widget.thread.attachments) Padding(
								padding: const EdgeInsets.all(8),
								child: Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										AttachmentThumbnail(
											attachment: attachment,
											width: 75,
											height: 75,
											mayObscure: false
										),
										Checkbox.adaptive(
											value: context.select<Settings, bool>((p) => p.isMD5Hidden(attachment.md5)),
											onChanged: attachment.md5.isEmpty ? null : (value) {
												if (value!) {
													Settings.instance.hideByMD5(attachment.md5);
												}
												else {
													Settings.instance.unHideByMD5(attachment.md5);
												}
												Settings.instance.didEdit();
												setState(() {});
											}
										)
									]
								)
							)
						]
				]
			),
			actions: [
				AdaptiveDialogAction(
					child: const Text('Close'),
					onPressed: () => Navigator.pop(context)
				)
			],
		);
	}
}

class BoardPage extends StatefulWidget {
	final int semanticId;
	final PersistentBrowserTab? tab;
	final ImageboardBoard? initialBoard;
	final bool allowChangingBoard;
	final ValueChanged<ImageboardScoped<ImageboardBoard>>? onBoardChanged;
	final ValueChanged<ThreadIdentifier>? onThreadSelected;
	final bool Function(BuildContext, ThreadIdentifier)? isThreadSelected;
	final String? initialSearch;
	final void Function(String, String, String)? onWantArchiveSearch;
	const BoardPage({
		required this.initialBoard,
		this.tab,
		this.allowChangingBoard = true,
		this.onBoardChanged,
		this.onThreadSelected,
		this.isThreadSelected,
		this.initialSearch,
		this.onWantArchiveSearch,
		required this.semanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => BoardPageState();
}

class BoardPageState extends State<BoardPage> {
	late ImageboardBoard? board;
	late final RefreshableListController<Thread> _listController;
	final _replyBoxKey = GlobalKey<ReplyBoxState>();
	Completer<void>? _loadCompleter;
	CatalogVariant? _variant;
	final _boardsPullTabKey = GlobalKey(debugLabel: '_BoardPageState._boardsPullTabKey');
	final _threadPullTabHandlerKey = GlobalKey<_BoardPageThreadPullTabHandlerState>(debugLabel: '_BoardPageState._threadPullTabHandlerKey');
	int _page = 1;
	DateTime? _lastCatalogUpdateTime;
	bool _searching = false;
	bool _skipNextIndicatorSwipe = false;

	CatalogVariant? get _defaultBoardVariant => context.read<Persistence?>()?.browserState.catalogVariants[board?.boardKey];
	CatalogVariant? get _defaultGlobalVariant => context.read<ImageboardSite?>()?.defaultCatalogVariant;

	@override
	void initState() {
		super.initState();
		_listController = RefreshableListController();
		_variant = widget.tab?.catalogVariant;
		board = widget.initialBoard;
		if (board == null) {
			SchedulerBinding.instance.addPostFrameCallback((_) => _selectBoard());
		}
		ThreadIdentifier? selectedThread;
		final hint = context.read<MasterDetailHint?>();
		final location = context.read<MasterDetailLocation?>();
		dynamic possibleThread = hint?.currentValue;
		if (possibleThread is ThreadIdentifier) {
			selectedThread = possibleThread;
		}
		else if (possibleThread is ImageboardScoped<ThreadIdentifier>) {
			selectedThread = possibleThread.item;
		}
		if (selectedThread != null) {
			if (location?.twoPane ?? false) {
				_loadCompleter = Completer<void>()
					..future.then((_) async {
						try {
							await _listController.animateTo((t) => t.identifier == selectedThread, alignment: 1.0);
						}
						on ItemNotFoundException {
							// Ignore, the thread must not be in catalog
						}
						_loadCompleter = null;
					});
			}
		}
		_searching = (widget.initialSearch ?? widget.tab?.initialSearch)?.isNotEmpty ?? false;
	}

	Future<void> _selectBoard() async {
		final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
			builder: (ctx) => BoardSwitcherPage(
				initialImageboardKey: context.read<Imageboard?>()?.key
			)
		));
		if (newBoard != null) {
			swapBoard(newBoard);
		}
	}
	
	void swapBoard(ImageboardScoped<ImageboardBoard> newBoard) {
		_page = 1;
		widget.onBoardChanged?.call(newBoard);
		setState(() {
			board = newBoard.item;
			if (_listController.scrollControllerPositionLooksGood) {
				_listController.scrollController?.jumpTo(0);
			}
			_variant = null;
			if (!newBoard.imageboard.site.supportsPosting && (_replyBoxKey.currentState?.show ?? false)) {
				_replyBoxKey.currentState?.hideReplyBox();
			}
			widget.tab?.mutate((tab) => tab.catalogVariant = _variant);
		});
	}

	void _onThreadSelected(ThreadIdentifier identifier) {
		_threadPullTabHandlerKey.currentState?.onThreadSelected(identifier);
		_listController.unfocusSearch();
		if (widget.onThreadSelected != null) {
			widget.onThreadSelected!(identifier);
		}
		else {
			Navigator.of(context).push(adaptivePageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					overridePersistence: context.read<Persistence>(),
					child: ThreadPage(
						thread: identifier,
						boardSemanticId: widget.semanticId,
					)
				)
			));
		}
	}

	Future<(CatalogVariant?, _ThreadSortingMethodScope)?> _variantDetailsMenu({
		required BuildContext context,
		required CatalogVariant variant,
		required List<CatalogVariant> others,
		required CatalogVariant currentVariant
	}) => showAdaptiveModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
		context: context,
		useRootNavigator: false,
		builder: (context) => AdaptiveActionSheet(
			title: Text(variant.name),
			actions: [
				if (context.read<ImageboardSite>().supportsMultipleBoards) AdaptiveActionSheetAction(
					isSelected: _defaultBoardVariant == variant,
					trailing: _defaultBoardVariant == variant ? AdaptiveIconButton(
						minSize: 0,
						icon: const SizedBox(
							width: 40,
							child: Icon(CupertinoIcons.xmark)
						),
						onPressed: () => Navigator.pop(context, const (null, _ThreadSortingMethodScope.board))
					) : null,
					child: Text('Set as default for /${board?.name}/', textAlign: TextAlign.left),
					onPressed: () {
						if (_defaultBoardVariant == variant) return;
						Navigator.pop(context, (variant, _ThreadSortingMethodScope.board));
					}
				),
				AdaptiveActionSheetAction(
					isSelected: _defaultGlobalVariant == variant,
					child: const Text('Set as global default', textAlign: TextAlign.left),
					onPressed: () {
						if (_defaultGlobalVariant == variant) return;
						Navigator.pop(context, (variant, _ThreadSortingMethodScope.global));
					}
				),
				...others.map((other) => _buildVariantDetails(
					context: context,
					v: CatalogVariantGroup(
						name: other.name,
						variants: [other]
					),
					currentVariant: currentVariant
				))
			],
			cancelButton: AdaptiveActionSheetAction(
				child: const Text('Cancel'),
				onPressed: () => Navigator.pop(context)
			)
		)
	);

	AdaptiveActionSheetAction _buildVariantDetails({
		required BuildContext context,
		required CatalogVariantGroup v,
		required CatalogVariant currentVariant,
	}) => AdaptiveActionSheetAction(
		isSelected: v.variants.contains(currentVariant),
		trailing: Row(
			mainAxisSize: MainAxisSize.min,
			children: [
				if (v.variants.contains(_variant)) AdaptiveIconButton(
					minSize: 0,
					icon: const SizedBox(
						width: 40,
						child: Icon(CupertinoIcons.xmark)
					),
					onPressed: () => Navigator.pop(context, const (null, _ThreadSortingMethodScope.tab))
				),
				if ((v.hasPrimary || v.variants.length == 1) && !v.variants.first.temporary) AdaptiveIconButton(
					minSize: 0,
					icon: const SizedBox(
						width: 40,
						child: Icon(CupertinoIcons.ellipsis)
					),
					onPressed: () async {
						final innerChoice = await _variantDetailsMenu(
							context: context,
							variant: v.variants.first,
							others: v.variants.skip(1).toList(),
							currentVariant: currentVariant
						);
						if (innerChoice != null && context.mounted) {
							Navigator.pop(context, innerChoice);
						}
					}
				)
				else if (v.variants.length > 1) const SizedBox(
					width: 40,
					child: Icon(CupertinoIcons.chevron_right)
				)
			]
		),
		child: Row(
			children: [
				SizedBox(
					width: 40,
					child: Center(
						child: Icon(
							v.variants.tryFirst?.icon ?? ((v.variants.tryFirst?.reverseAfterSorting ?? false) ? CupertinoIcons.sort_up : CupertinoIcons.sort_down)
						)
					)
				),
				Expanded(
					child: Text(v.name, textAlign: TextAlign.left)
				)
			]
		),
		onPressed: () async {
			if (((v.variants.length == 1 || v.hasPrimary) && v.variants.first == currentVariant)) {
				return;
			}
			if (v.hasPrimary || v.variants.length == 1) {
				Navigator.pop(context, (v.variants.first, _ThreadSortingMethodScope.tab));
			}
			else {
				final choice = await showAdaptiveModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
					context: context,
					useRootNavigator: false,
					builder: (context) => AdaptiveActionSheet(
						title: Text(v.name),
						actions: v.variants.map((subvariant) => AdaptiveActionSheetAction(
							child: Row(
								children: [
									SizedBox(
										width: 40,
										child: Center(
											child: Icon(subvariant.icon ?? (subvariant.reverseAfterSorting ? CupertinoIcons.sort_up : CupertinoIcons.sort_down)),
										)
									),
									Expanded(
										child: Text(subvariant.name, style: TextStyle(
											fontWeight: subvariant == currentVariant ? FontWeight.bold : null,
											fontVariations: subvariant == currentVariant ? CommonFontVariations.bold : null
										))
									),
									AdaptiveIconButton(
										minSize: 0,
										icon: const SizedBox(
											width: 40,
											child: Icon(CupertinoIcons.ellipsis)
										),
										onPressed: () async {
											final innerChoice = await _variantDetailsMenu(
												context: context,
												variant: subvariant,
												others: [],
												currentVariant: currentVariant
											);
											if (innerChoice != null && context.mounted) {
												Navigator.pop(context, innerChoice);
											}
										}
									)
								]
							),
							onPressed: () async {
								Navigator.pop(context, (subvariant, _ThreadSortingMethodScope.tab));
							}
						)).toList(),
						cancelButton: AdaptiveActionSheetAction(
							child: const Text('Cancel'),
							onPressed: () => Navigator.pop(context)
						)
					)
				);
				if (choice != null && context.mounted) {
					Navigator.pop(context, choice);
				}
			}
		}
	);

	void _showGalleryFromNextImage({bool initiallyShowGrid = false}) {
		final board = this.board;
		if (board != null && Settings.instance.showImages(context, board.name)) {
			final nextThreadWithImage = _listController.items.skip(max(0, _listController.firstVisibleIndex)).firstWhere((t) => t.item.attachments.isNotEmpty, orElse: () {
				return _listController.items.firstWhere((t) => t.item.attachments.isNotEmpty);
			});
			final imageboard = context.read<Imageboard>();
			final attachments = _listController.items.expand((_) => _.item.attachments).toList();
			showGallery(
				context: context,
				attachments: attachments,
				threads: {
					for (final thread in _listController.items)
						for (final attachment in thread.item.attachments)
							attachment: imageboard.scope(thread.item)
				},
				onThreadSelected: (t) => _onThreadSelected(t.item.identifier),
				initialAttachment: attachments.firstWhere((a) => nextThreadWithImage.item.attachments.any((a2) => a2.id == a.id)),
				onChange: (attachment) {
					if (_listController.state?.searching ?? false) {
						return;
					}
					_listController.animateToIfOffscreen((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
				},
				semanticParentIds: [widget.semanticId],
				initiallyShowGrid: initiallyShowGrid,
				heroOtherEndIsBoxFitCover: true//settings.useCatalogGrid
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final imageboard = context.watch<Imageboard?>();
		final site = context.watch<ImageboardSite?>();
		final settings = context.watch<Settings>();
		final mouseSettings = context.watch<MouseSettings>();
		final persistence = context.watch<Persistence?>();
		final variant = _variant ?? (_defaultBoardVariant ?? _defaultGlobalVariant) ?? CatalogVariant.unsorted;
		final openInNewTabZone = context.read<OpenInNewTabZone?>();
		final useCatalogGrid = persistence?.browserState.useCatalogGridPerBoard[board?.boardKey] ?? persistence?.browserState.useCatalogGrid ?? settings.useCatalogGrid;
		Widget itemBuilder(BuildContext context, Thread thread, {RegExp? highlightPattern}) {
			final isSaved = context.select<Persistence, bool>((p) => p.getThreadStateIfExists(thread.identifier)?.savedTime != null);
			final isYou = context.select<Persistence, bool>((p) => p.getThreadStateIfExists(thread.identifier)?.youIds.contains(thread.id) ?? false);
			final watch = context.select<Persistence, ThreadWatch?>((p) => p.getThreadStateIfExists(thread.identifier)?.threadWatch);
			final isThreadHidden = context.select<Persistence, bool?>((p) => p.browserState.getThreadHiding(thread.identifier));
			final isImageHidden = context.select<Settings, bool>((p) => p.areMD5sHidden(thread.md5s));
			final isSelected = widget.isThreadSelected?.call(context, thread.identifier) ?? false;
			final listFilterReason = context.watch<RefreshableListFilterReason?>();
			final isThreadHiddenByIdOrMD5s = isThreadHidden ?? isImageHidden;
			final isHidden = isThreadHiddenByIdOrMD5s || listFilterReason != null;
			return ContextMenu(
				actions: [
					if (openInNewTabZone != null) ...[
						ContextMenuAction(
							child: const Text('Open in new tab'),
							trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
							onPressed: () {
								openInNewTabZone.onWantOpenThreadInNewTab(imageboard!.key, thread.identifier, activate: false);
							}
						),
						ContextMenuAction(
							child: const Text('Open in new private tab'),
							trailingIcon: CupertinoIcons.eyeglasses,
							onPressed: () {
								openInNewTabZone.onWantOpenThreadInNewTab(imageboard!.key, thread.identifier, incognito: true, activate: false);
							}
						),
					],
					if (isSaved) ContextMenuAction(
						child: const Text('Un-save thread'),
						trailingIcon: Adaptive.icons.bookmarkFilled,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							final savedTime = threadState.savedTime;
							threadState.savedTime = null;
							threadState.save();
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
							showUndoToast(
								context: context,
								message: 'Thread unsaved',
								onUndo: () {
									threadState.savedTime = savedTime ?? DateTime.now();
									threadState.save();
									context.read<Persistence>().didUpdateBrowserState();
									setState(() {});
								}
							);
						}
					)
					else ContextMenuAction(
						child: const Text('Save thread'),
						trailingIcon: Adaptive.icons.bookmark,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							threadState.thread ??= thread;
							threadState.savedTime = DateTime.now();
							threadState.save();
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
							showUndoToast(
								context: context,
								message: 'Thread saved',
								onUndo: () {
									threadState.savedTime = null;
									threadState.save();
									context.read<Persistence>().didUpdateBrowserState();
									setState(() {});
								}
							);
						}
					),
					if (isYou) ContextMenuAction(
						child: const Text('Unmark as You'),
						trailingIcon: CupertinoIcons.person_badge_minus,
						onPressed: () async {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							for (final r in threadState.receipts) {
								if (r.id == thread.id) {
									r.markAsYou = false;
								}
							}
							threadState.postsMarkedAsYou.remove(thread.id);
							threadState.didUpdateYourPosts();
							threadState.save();
						}
					)
					else ContextMenuAction(
						child: const Text('Mark as You'),
						trailingIcon: CupertinoIcons.person_badge_plus,
						onPressed: () async {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							bool markedReceipt = false;
							for (final r in threadState.receipts) {
								if (r.id == thread.id) {
									r.markAsYou = true;
									markedReceipt = true;
								}
							}
							if (!markedReceipt) {
								threadState.postsMarkedAsYou.add(thread.id);
							}
							threadState.thread ??= thread;
							threadState.didUpdateYourPosts();
							threadState.save();
							if (settings.watchThreadAutomaticallyWhenReplying) {
								if ((site?.supportsPushNotifications ?? false) && context.mounted) {
									await promptForPushNotificationsIfNeeded(context);
								}
								imageboard?.notifications.subscribeToThread(
									thread: thread.identifier,
									lastSeenId: thread.posts.tryLast?.id ?? thread.id,
									localYousOnly: (threadState.threadWatch ?? settings.defaultThreadWatch)?.localYousOnly ?? true,
									pushYousOnly: (threadState.threadWatch ?? settings.defaultThreadWatch)?.pushYousOnly ?? true,
									foregroundMuted: (threadState.threadWatch ?? settings.defaultThreadWatch)?.foregroundMuted ?? false,
									push: (threadState.threadWatch ?? settings.defaultThreadWatch)?.push ?? true,
									youIds: threadState.freshYouIds(),
									notifyOnSecondLastPage: (threadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnSecondLastPage ?? false,
									notifyOnLastPage: (threadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnLastPage ?? true,
									notifyOnDead: (threadState.threadWatch ?? settings.defaultThreadWatch)?.notifyOnDead ?? false
								);
							}
							threadState.save();
						}
					),
					if (watch != null) ContextMenuAction(
						child: const Text('Unwatch thread'),
						trailingIcon: CupertinoIcons.bell_slash,
						onPressed: () async {
							if (imageboard == null) {
								return;
							}
							await imageboard.notifications.removeWatch(watch);
							setState(() {});
							if (context.mounted) {
								showUndoToast(
									context: context,
									message: 'Thread unwatched',
									onUndo: () async {
										await imageboard.notifications.insertWatch(watch);
										setState(() {});
									}
								);
							}
						}
					)
					else ContextMenuAction(
						child: const Text('Watch thread'),
						trailingIcon: CupertinoIcons.bell,
						onPressed: () async {
							if (imageboard == null) {
								return;
							}
							final threadState = imageboard.persistence.getThreadState(thread.identifier);
							// Need this to be populated for initial showing before first watcher update
							await threadState.ensureThreadLoaded();
							threadState.thread ??= thread;
							imageboard.notifications.subscribeToThread(
								thread: thread.identifier,
								lastSeenId: threadState.lastSeenPostId ?? thread.id,
								localYousOnly: false,
								pushYousOnly: true,
								// So if you do a subsequent reply, notifications still work as expected
								push: true,
								youIds: threadState.youIds,
								notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
								notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
								notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
							);
							setState(() {});
							if (context.mounted) {
								showUndoToast(
									context: context,
									message: 'Thread watched',
									onUndo: () {
										imageboard.notifications.unsubscribeFromThread(thread.identifier);
										setState(() {});
									}
								);
							}
						}
					),
					if (isThreadHidden ?? false) ContextMenuAction(
						child: const Text('Unhide thread'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.setThreadHiding(thread.identifier, null);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					)
					else ContextMenuAction(
						child: const Text('Hide thread'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							context.read<Persistence>().browserState.setThreadHiding(thread.identifier, true);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					),
					ContextMenuAction(
						child: isHidden ? const Text('Unhide...') : const Text('Hide...'),
						trailingIcon: isHidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
						onPressed: () {
							final imageboard = context.read<Imageboard>();
							showAdaptiveDialog(
								barrierDismissible: true,
								context: context,
								builder: (context) => ImageboardScope(
									imageboardKey: null,
									imageboard: imageboard,
									child: _ThreadHidingDialog(
										thread: thread,
										listFilterReason: isThreadHiddenByIdOrMD5s ? null : listFilterReason
									)
								)
							);
						}
					),
					if (thread.attachments.isNotEmpty) ContextMenuAction(
						child: Text('Copy ${thread.attachments.first.type.noun} link'),
						trailingIcon: CupertinoIcons.link,
						onPressed: () async {
							final which = await whichAttachment(context, thread.attachments);
							if (which == null) {
								return;
							}
							Clipboard.setData(ClipboardData(
								text: which.url
							));
							if (context.mounted) {
								showToast(
									context: context,
									message: 'Copied "${which.url}" to clipboard',
									icon: CupertinoIcons.doc_on_clipboard
								);
							}
						}
					),
					...buildImageSearchActions(context, thread.attachments),
					ContextMenuAction(
						trailingIcon: Adaptive.icons.share,
						child: const Text('Share...'),
						onPressed: () {
							final site = context.read<ImageboardSite>();
							shareOne(
								context: context,
								text: site.getWebUrl(
									board: thread.board,
									threadId: thread.id,
									archiveName: thread.archiveName
								),
								type: "text",
								sharePositionOrigin: null,
								additionalOptions: {
									'Share as image': () async {
										try {
											final zone = PostSpanRootZoneData(
												thread: thread,
												imageboard: imageboard!,
												style: PostSpanZoneStyle.linear
											);
											final file = await modalLoad(context, 'Rendering...', (c) => sharePostsAsImage(
												context: context,
												primaryPostId: thread.id,
												style: const ShareablePostsStyle(
													expandPrimaryImage: true,
													width: 400
												),
												zone: zone
											));
											zone.dispose();
											if (context.mounted) {
												shareOne(
													context: context,
													text: file.path,
													type: 'file',
													sharePositionOrigin: null
												);
											}
										}
										catch (e, st) {
											Future.error(e, st); // Report to crashlytics
											if (context.mounted) {
												alertError(context, e, st);
											}
										}
									}
								}
							);
						}
					),
					ContextMenuAction(
						child: const Text('Report thread'),
						trailingIcon: CupertinoIcons.exclamationmark_octagon,
						onPressed: () => reportPost(
							context: context,
							site: context.read<ImageboardSite>(),
							post: PostIdentifier.thread(thread.identifier)
						)
					)
				],
				contextMenuBuilderBuilder: makeGeneralContextMenuBuilder,
				maxHeight: useCatalogGrid ? settings.catalogGridHeight : settings.maxCatalogRowHeight,
				child: GestureDetector(
					onDoubleTap: settings.doubleTapToHideThreads ? () {
						if (persistence == null) {
							return;
						}
						final hiding = persistence.browserState.getThreadHiding(thread.identifier);
						// Don't use null (cleared flag) because can never really be sure
						// So to unhide use force-show
						// Probably the user won't hide manually, then apply a new filter that would also apply.
						persistence.browserState.setThreadHiding(thread.identifier, !(hiding ?? isHidden));
						persistence.didUpdateBrowserState();
						setState(() {});
						if (context.mounted) {
							showUndoToast(
								context: context,
								message: 'Thread ${isHidden ? 'unhidden': 'hidden'}',
								onUndo: () {
									persistence.browserState.setThreadHiding(thread.identifier, hiding);
									persistence.didUpdateBrowserState();
									setState(() {});
								}
							);
						}
					} : null,
					child: ThreadRow(
						style: useCatalogGrid ?
							(settings.useStaggeredCatalogGrid ? ThreadRowStyle.staggeredGrid : ThreadRowStyle.grid)
							: ThreadRowStyle.row,
						showLastReplies: !useCatalogGrid && settings.showLastRepliesInCatalog,
						thread: thread,
						isSelected: isSelected,
						semanticParentIds: [widget.semanticId],
						dimReadThreads: settings.dimReadThreads,
						replyCountUnreliable: thread.replyCount < 0,
						imageCountUnreliable: thread.imageCount < 0,
						showBoardName: thread.board != board?.name,
						onThumbnailTap: (initialAttachment) {
							final attachments = _listController.items.expand((_) => _.item.attachments).toList();
							// It might not be in the list if the thread has been filtered
							final initialAttachmentInList = attachments.tryFirstWhere((a) => a.id == initialAttachment.id);
							showGallery(
								context: context,
								attachments: initialAttachmentInList == null ? [initialAttachment] : attachments,
								threads: {
									for (final thread in _listController.items)
										for (final attachment in thread.item.attachments)
											attachment: imageboard!.scope(thread.item)
								},
								onThreadSelected: (t) => _onThreadSelected(t.item.identifier),
								initialAttachment: initialAttachmentInList ?? initialAttachment,
								onChange: (attachment) {
									if (_listController.state?.searching ?? false) {
										return;
									}
									_listController.animateToIfOffscreen((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
								},
								semanticParentIds: [widget.semanticId],
								heroOtherEndIsBoxFitCover: useCatalogGrid ? settings.catalogGridModeCropThumbnails : settings.squareThumbnails
							);
						},
						baseOptions: PostSpanRenderOptions(
							highlightPattern: highlightPattern
						)
					),
					onTap: () => _onThreadSelected(thread.identifier)
				)
			);
		}
		String navigationBarBoardName = 'Select Imageboard';
		if (imageboard != null) {
			navigationBarBoardName = board != null ? imageboard.site.formatBoardName(board!.name) : 'Select Board';
		}
		final supportsSearch = imageboard?.site.supportsSearch(board?.name) ?? const ImageboardSearchMetadata(name: '', options: ImageboardSearchOptions());
		final sortMethods = <Comparator<Thread>>[
			if (variant.sortingMethod == ThreadSortingMethod.replyCount)
				(a, b) => b.replyCount.compareTo(a.replyCount)
			else if (variant.sortingMethod == ThreadSortingMethod.threadPostTime)
				(a, b) => b.id.compareTo(a.id)
			else if (variant.sortingMethod == ThreadSortingMethod.postsPerMinute)
				(a, b) {
					// If no replies, just put it at the bottom
					if (a.replyCount == 0 && b.replyCount > 0) {
						return 1;
					}
					if (b.replyCount == 0 && a.replyCount > 0) {
						return -1;
					}
					final ref = _lastCatalogUpdateTime ??= DateTime.now();
					final aAge = a.time.difference(ref).inSeconds;
					final bAge = b.time.difference(ref).inSeconds;
					return -1 * ((b.replyCount + 1) / bAge).compareTo((a.replyCount + 1) / aAge);
				}
			else if (variant.sortingMethod == ThreadSortingMethod.lastReplyTime)
				(a, b) => b.posts_.last.id.compareTo(a.posts_.last.id)
			else if (variant.sortingMethod == ThreadSortingMethod.imageCount)
				(a, b) => b.imageCount.compareTo(a.imageCount)
			else if (variant.sortingMethod == ThreadSortingMethod.alphabeticByTitle)
				(a, b) => a.compareTo(b)
		];
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: AdaptiveBar(
				title: AdaptiveIconButton(
					onPressed: widget.allowChangingBoard ? _selectBoard : null,
					dimWhenDisabled: false,
					icon: DefaultTextStyle.merge(
						style: CommonTextStyles.w600,
						child: Wrap(
							alignment: WrapAlignment.center,
							crossAxisAlignment: WrapCrossAlignment.center,
							children: [
								Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (context.read<PersistentBrowserTab?>()?.incognito ?? false) ...[
											const Icon(CupertinoIcons.eyeglasses),
											const Text(' ')
										],
										if (imageboard != null) ...[
											if (ImageboardRegistry.instance.count > 1) ...[
												ImageboardIcon(
													boardName: board?.name
												),
												const Text(' ')
											]
										]
									]
								),
								Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Flexible(child: AutoSizeText(navigationBarBoardName, minFontSize: 9, maxLines: 1)),
										if (widget.allowChangingBoard) const Icon(Icons.arrow_drop_down)
									]
								)
							]
						)
					)
				),
				leadings: [
					if (board != null) AdaptiveBarAction(
						icon: const Icon(CupertinoIcons.settings),
						title: 'Board Settings',
						onPressed: () {
							Navigator.of(context).push(TransparentRoute(
								builder: (context) => BoardSettingsPage(
									imageboard: imageboard!,
									board: board!
								)
							));
						}
					),
					AdaptiveBarAction(
						title: 'Sort...',
						icon: (variant.icon != null && !variant.temporary && variant != _defaultGlobalVariant) ? FittedBox(
							fit: BoxFit.contain,
							child: SizedBox(
								width: 40,
								height: 40,
								child: Stack(
									children: [
										Align(
											alignment: Alignment.bottomRight,
											child: Icon(variant.icon)
										),
										Align(
											alignment: Alignment.topLeft,
											child: Icon(variant.reverseAfterSorting ? CupertinoIcons.sort_up : CupertinoIcons.sort_down)
										)
									]
								)
							)
						) : (variant.icon != null && variant.temporary) ? Icon(variant.icon) : Icon(variant.reverseAfterSorting ? CupertinoIcons.sort_up : CupertinoIcons.sort_down),
						onPressed: () async {
							final choice = await showAdaptiveModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
								context: context,
								useRootNavigator: false,
								builder: (context) => AdaptiveActionSheet(
									title: const Text('Sort by...'),
									actions:(site?.catalogVariantGroups ?? []).map((v) => _buildVariantDetails(
										context: context,
										v: v,
										currentVariant: variant
									)).toList(),
									cancelButton: AdaptiveActionSheetAction(
										child: const Text('Cancel'),
										onPressed: () => Navigator.pop(context)
									)
								)
							);
							if (choice == null) {
								return;
							}
							if (choice.$1 == null) {
								if (choice.$2 == _ThreadSortingMethodScope.tab) {
									_variant = null;
									widget.tab?.mutate((tab) => tab.catalogVariant = _variant);
								}
								else if (choice.$2 == _ThreadSortingMethodScope.board) {
									persistence?.browserState.catalogVariants.remove(board?.boardKey);
								}
								setState(() {});
								return;
							}
							switch (choice.$2) {
								case _ThreadSortingMethodScope.global:
									site?.defaultCatalogVariant = choice.$1!;
									break;
								case _ThreadSortingMethodScope.board:
									persistence?.browserState.catalogVariants[board!.boardKey] = choice.$1!;
									persistence?.didUpdateBrowserState();
									break;
								case _ThreadSortingMethodScope.tab:
									final otherwiseDefault = _defaultBoardVariant ?? _defaultGlobalVariant;
									if (otherwiseDefault == choice.$1!) {
										_variant = null;
									}
									else {
										_variant = choice.$1!;
									}
									widget.tab?.mutate((tab) => tab.catalogVariant = _variant);
									setState(() {});
									break;
							}
						}
					),
				],
				actions: [
					if (
						// Is root board on desktop
						(mouseSettings.supportMouse && !Navigator.of(context).canPop()) ||
						// Space is generally available
						!(context.watch<MasterDetailLocation?>()?.isVeryConstrained ?? false)
					) AnimatedBuilder(
						animation: _listController,
						builder: (context, _) => ValueListenableBuilder<({String id, Future<void> future, CancelToken cancelToken})?>(
							valueListenable: _listController.updatingNow,
							builder: (context, pair, _) => AdaptiveIconButton(
								icon: pair == null ? const Icon(CupertinoIcons.refresh) : const Icon(CupertinoIcons.xmark),
								onPressed: switch (pair?.cancelToken) {
									CancelToken cancelToken => cancelToken.cancel,
									null => _listController.blockAndUpdate
								}
							)
						)
					),
					if (imageboard?.site.supportsPosting ?? false) NotifyingIcon(
						sideBySide: true,
						primaryCount: MappingValueListenable(
							parent: Outbox.instance,
							mapper: (o) =>
								o.queuedPostsFor(imageboard?.key ?? '', board?.name ?? '', null).where((e) => e.state.isSubmittable).length
						),
						secondaryCount: MappingValueListenable(
							parent: Outbox.instance,
							mapper: (o) => o.submittableCount - o.queuedPostsFor(imageboard?.key ?? '', board?.name ?? '', null).where((e) => e.state.isSubmittable).length
						),
						icon: AdaptiveIconButton(
							icon: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.pencil_slash) : const Icon(CupertinoIcons.pencil),
							onPressed: () {
								if ((context.read<MasterDetailLocation?>()?.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
									showAdaptiveModalPopup(
										context: context,
										builder: (ctx) => ImageboardScope(
											imageboardKey: null,
											imageboard: imageboard!,
											child: Padding(
												padding: MediaQuery.viewInsetsOf(ctx),
												child: Container(
													color: ChanceTheme.backgroundColorOf(ctx),
													child: ReplyBox(
														fullyExpanded: true,
														board: board!.boardKey,
														initialDraft: widget.tab?.draft,
														onDraftChanged: (draft) {
															widget.tab?.mutate((tab) => tab.draft = draft);
														},
														onReplyPosted: (receipt) async {
															if (imageboard.site.supportsPushNotifications) {
																await promptForPushNotificationsIfNeeded(ctx);
															}
															if (!ctx.mounted) return;
															final newThread = ThreadIdentifier(board!.name, receipt.id);
															_listController.update();
															_onThreadSelected(newThread);
															Navigator.of(ctx).pop();
														}
													)
												)
											)
										)
									);
								}
								else {
									_replyBoxKey.currentState?.toggleReplyBox();
									setState(() {});
								}
							}
						)
					)
				]
			),
			body: PullTab(
				key: _boardsPullTabKey,
				tab: PullTabTab(
					child: const Text('Open boards'),
					onActivation: _selectBoard,
				),
				enabled: settings.openBoardSwitcherSlideGesture && widget.allowChangingBoard,
				child: board == null ? Center(
					child: ErrorMessageCard(
						'No board selected',
						remedies: {
							if (widget.allowChangingBoard) 'Pick one': _selectBoard
						}
					)
				) : _BoardPageThreadPullTabHandler(
					key: _threadPullTabHandlerKey,
					onPull: _onThreadSelected,
					child: FilterZone(
						filter: context.select<Persistence, Filter>((p) => p.browserState.getCatalogFilter(board!.boardKey)),
						child: PopScope(
							canPop: !(_replyBoxKey.currentState?.show ?? false),
							onPopInvokedWithResult: (didPop, result) {
								if (!didPop) {
									_replyBoxKey.currentState?.hideReplyBox();
									setState(() {});
								}
							},
							child: ReplyBoxLayout(
								body: TransformedMediaQuery(
									transformation: (context, mq) => mq.removePadding(removeBottom: _replyBoxKey.currentState?.show ?? false),
									child: CallbackShortcuts(
										bindings: {
											ConditionalShortcut(
												parent: LogicalKeySet(LogicalKeyboardKey.keyG),
												condition: () => !(_listController.state?.searchHasFocus ?? false)
											): _showGalleryFromNextImage
										},
										child: site == null ? const Center(
											child: ErrorMessageCard('No imageboard selected')
										) : Stack(
											fit: StackFit.expand,
											children: [
												RefreshableList<Thread>(
													initialFilter: widget.initialSearch ?? widget.tab?.initialSearch,
													onFilterChanged: (newFilter) {
														widget.tab?.mutate((tab) => tab.initialSearch = newFilter);
														bool newSearching = newFilter != null;
														if (newSearching != _searching) {
															setState(() {
																_searching = newSearching;
															});
														}
													},
													filterableAdapter: (t) => (imageboard?.key ?? '', t),
													allowReordering: true,
													onWantAutosave: (thread) async {
														final persistence = context.read<Persistence>();
														if (persistence.browserState.autosavedIds[thread.boardKey]?.contains(thread.id) ?? false) {
															// Already saw this thread
															return;
														}
														final threadState = persistence.getThreadState(thread.identifier);
														threadState.savedTime = DateTime.now();
														threadState.thread ??= thread;
														persistence.browserState.autosavedIds.putIfAbsent(thread.boardKey, () => []).add(thread.id);
														await threadState.save();
														await persistence.didUpdateBrowserState();
													},
													onWantAutowatch: (thread, autoWatch) async {
														final imageboard = context.read<Imageboard>();
														await Future.microtask(() => {});
														if (imageboard.persistence.browserState.autowatchedIds[thread.boardKey]?.contains(thread.id) ?? false) {
															// Already saw this thread
															return;
														}
														final threadState = imageboard.persistence.getThreadState(thread.identifier);
														threadState.thread ??= thread;
														imageboard.notifications.subscribeToThread(
															thread: thread.identifier,
															lastSeenId: thread.posts_.last.id,
															localYousOnly: settings.defaultThreadWatch?.localYousOnly ?? false,
															pushYousOnly: settings.defaultThreadWatch?.pushYousOnly ?? false,
															push: autoWatch.push ?? settings.defaultThreadWatch?.push ?? true,
															youIds: threadState.youIds,
															foregroundMuted: settings.defaultThreadWatch?.foregroundMuted ?? false,
															notifyOnSecondLastPage: settings.defaultThreadWatch?.notifyOnSecondLastPage ?? false,
															notifyOnLastPage: settings.defaultThreadWatch?.notifyOnLastPage ?? true,
															notifyOnDead: settings.defaultThreadWatch?.notifyOnDead ?? false
														);
														imageboard.persistence.browserState.autowatchedIds.putIfAbsent(thread.boardKey, () => []).add(thread.id);
														await imageboard.persistence.didUpdateBrowserState();
													},
													sortMethods: sortMethods,
													reverseSort: variant.reverseAfterSorting,
													minCacheExtent: useCatalogGrid ? settings.catalogGridHeight : 0,
													gridDelegate: (useCatalogGrid && !settings.useStaggeredCatalogGrid) ? SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery(
														maxCrossAxisExtent: settings.catalogGridWidth,
														childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
													) : null,
													staggeredGridDelegate: (useCatalogGrid && settings.useStaggeredCatalogGrid) ? SliverStaggeredGridDelegateWithMaxCrossAxisExtent(
														maxCrossAxisExtent: settings.catalogGridWidth
													) : null,
													controller: _listController,
													listUpdater: (options) async {
														final list = await site.getCatalog(
															board!.name,
															variant: variant,
															priority: RequestPriority.interactive,
															cancelToken: options.cancelToken
														);
														for (final thread in list) {
															await thread.preinit(catalog: true);
															await persistence?.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
														}
														_lastCatalogUpdateTime = DateTime.now();
														if (settings.hideOldStickiedThreads && board?.name != 'chance') {
															final threshold = _lastCatalogUpdateTime!.subtract(_oldThreadThreshold);
															list.removeWhere((thread) {
																return thread.isSticky && thread.time.isBefore(threshold);
															});
														}
														Future.delayed(const Duration(milliseconds: 100), () {
															if (!mounted) return;
															if (_loadCompleter?.isCompleted == false) {
																_loadCompleter?.complete();
															}
														});
														return list;
													},
													autoExtendDuringScroll: true,
													listExtender: (after, cancelToken) => site.getMoreCatalog(
														board!.name,
														after,
														variant: variant,
														priority: RequestPriority.interactive,
														cancelToken: cancelToken
													).then((list) async {
														for (final thread in list) {
															await thread.preinit(catalog: true);
															await persistence?.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
														}
														return list;
													}),
													disableBottomUpdates: !(variant.hasPagedCatalog ?? site.hasPagedCatalog),
													id: '${site.name} /${board!.name}/${variant.dataId}',
													itemBuilder: (context, thread) => itemBuilder(context, thread),
													filteredItemBuilder: (context, thread, resetPage, filterPattern) => itemBuilder(context, thread, highlightPattern: filterPattern),
													filterHint: 'Search in board',
													filterAlternative: (widget.onWantArchiveSearch == null || !supportsSearch.options.text) ? null : FilterAlternative(
														name: supportsSearch.name,
														handler: (s) {
															widget.onWantArchiveSearch!(imageboard!.key, board!.name, s);
														}
													)
												),
												RepaintBoundary(
													child: SafeArea(
														child: Align(
															alignment: settings.showListPositionIndicatorsOnLeft ? Alignment.bottomLeft : Alignment.bottomRight,
															child: Padding(
																padding: const EdgeInsets.all(16),
																child: AnimatedBuilder(
																	animation: _listController,
																	builder: (context, _) {
																		if (_listController.state?.originalList == null) {
																			return const SizedBox.shrink();
																		}
																		final theme = context.watch<SavedTheme>();
																		final primaryColorWithBrightness80 = theme.primaryColorWithBrightness(0.8);
																		scrollAnimationDuration() => Settings.instance.showAnimations ? const Duration(milliseconds: 200) : const Duration(milliseconds: 1);
																		scrollToTop() => _listController.animateToIndex(0, duration: scrollAnimationDuration());
																		scrollToBottom() => _listController.animateToIndex(_listController.itemsLength - 1, alignment: 1.0, duration: scrollAnimationDuration());
																		final realImageCount = _listController.items.fold<int>(0, (t, a) => t + a.item.attachments.length);
																		return Row(
																			mainAxisSize: MainAxisSize.min,
																			children: [
																				if (settings.showGalleryGridButton && realImageCount > 1) ...[
																					AdaptiveFilledButton(
																						padding: const EdgeInsets.all(8),
																						color: primaryColorWithBrightness80,
																						onPressed: () => _showGalleryFromNextImage(initiallyShowGrid: true),
																						child: Icon(CupertinoIcons.square_grid_2x2, size: 24, color: theme.backgroundColor)
																					),
																					const SizedBox(width: 8),
																				],
																				GestureDetector(
																					longPressDuration: const Duration(milliseconds: 300),
																					onLongPress: () {
																						final position = _listController.scrollController?.tryPosition;
																						if (position != null && position.extentAfter < 200 && position.extentBefore > 200) {
																							scrollToTop();
																						}
																						else {
																							scrollToBottom();
																						}
																						mediumHapticFeedback();
																					},
																					onPanStart: (details) {
																						_skipNextIndicatorSwipe = eventTooCloseToEdge(details.globalPosition);
																					},
																					onPanEnd: (details) {
																						if (_skipNextIndicatorSwipe) {
																							return;
																						}
																						final position =_listController.scrollController?.tryPosition;
																						if ((-1 * details.velocity.pixelsPerSecond.dy) > details.velocity.pixelsPerSecond.dx.abs()) {
																							mediumHapticFeedback();
																							if (position != null && position.extentAfter > 0) {
																								scrollToBottom();
																							}
																							else {
																								// Not possible, do a "double buzz"
																								Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
																							}
																						}
																						else if (details.velocity.pixelsPerSecond.dy > details.velocity.pixelsPerSecond.dx.abs()) {
																							mediumHapticFeedback();
																							if (position != null && position.extentBefore > 0) {
																								scrollToTop();
																							}
																							else {
																								// Not possible, do a "double buzz"
																								Future.delayed(const Duration(milliseconds: 100), mediumHapticFeedback);
																							}
																						}
																					},
																					child: AdaptiveFilledButton(
																						onPressed: () async {
																							lightHapticFeedback();
																							if (_searching) {
																								_listController.state?.closeSearch();
																							}
																							else {
																								try {
																									await scrollToTop();
																									_page = _listController.items.first.item.currentPage ?? 1;
																								}
																								on TimeoutException {
																									// Sometimes this happens. Don't do anything
																								}
																							}
																						},
																						color: primaryColorWithBrightness80,
																						padding: const EdgeInsets.all(8),
																						child: Row(
																							mainAxisSize: MainAxisSize.min,
																							children: _searching ? [
																								Icon(CupertinoIcons.search, color: theme.backgroundColor),
																								const SizedBox(width: 8),
																								Icon(CupertinoIcons.xmark, color: theme.backgroundColor)
																							] : [
																								if (sortMethods.isEmpty)
																									Icon(CupertinoIcons.doc, color: theme.backgroundColor),
																								ConstrainedBox(
																									constraints: BoxConstraints(
																										minWidth: MediaQuery.textScalerOf(context).scale(24)
																									),
																									child: AnimatedBuilder(
																										animation: _listController.slowScrolls,
																										builder: (context, _) {
																											_page = (_listController.firstVisibleItem?.item.currentPage ?? _page);
																											return Text(
																												(sortMethods.isEmpty ? _page : (_listController.itemsLength - (_listController.lastVisibleIndex + 1))).toString(),
																												textAlign: TextAlign.center,
																												style: TextStyle(
																													color: theme.backgroundColor,
																													fontFeatures: const [FontFeature.tabularFigures()]
																												)
																											);
																										}
																									)
																								)
																							]
																						)
																					)
																				)
																			]
																		);
																	}
																)
															)
														)
													)
												)
											]
										)
									)
								),
								replyBox: RepaintBoundary(
									child: ReplyBox(
										key: _replyBoxKey,
										board: board!.boardKey,
										initialDraft: widget.tab?.draft,
										onDraftChanged: (draft) {
											widget.tab?.mutate((tab) => tab.draft = draft);
										},
										onReplyPosted: (receipt) async {
											if (imageboard?.site.supportsPushNotifications == true) {
												await promptForPushNotificationsIfNeeded(context);
											}
											if (!mounted) return;
											_listController.update();
											_onThreadSelected(ThreadIdentifier(board!.name, receipt.id));
										},
										onVisibilityChanged: () => setState(() {}),
									)
								)
							)
						)
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

// Separate Widget to optimize rebuild
class _BoardPageThreadPullTabHandler extends StatefulWidget {
	final Widget child;
	final ValueChanged<ThreadIdentifier> onPull;

	const _BoardPageThreadPullTabHandler({
		required this.child,
		required this.onPull,
		super.key
	});

	@override
	createState() => _BoardPageThreadPullTabHandlerState();
}

class _BoardPageThreadPullTabHandlerState extends State<_BoardPageThreadPullTabHandler> {
	(Imageboard?, ThreadIdentifier)? _lastSelectedThread;

	void onThreadSelected(ThreadIdentifier thread) {
		_lastSelectedThread = (_lastSelectedThread?.$1, thread);
		setState(() {});
	}

	@override
	void initState() {
		super.initState();
		final imageboard = context.read<Imageboard?>();
		final hint = context.read<MasterDetailHint?>();
		dynamic possibleThread = hint?.currentValue;
		if (possibleThread is ThreadIdentifier) {
			_lastSelectedThread = (imageboard, possibleThread);
		}
		else if (possibleThread is ImageboardScoped<ThreadIdentifier>) {
			_lastSelectedThread = (imageboard, possibleThread.item);
		}
		if (context.findAncestorStateOfType<NavigatorState>()?.canPop() == false) {
			final tab = context.read<PersistentBrowserTab?>();
			final threadFromTab = tab?.threadForPullTab ?? tab?.thread;
			if (threadFromTab != null) {
				_lastSelectedThread ??= (imageboard, threadFromTab);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final hint = context.watch<MasterDetailHint?>();
		final imageboard = context.watch<Imageboard?>();
		dynamic possibleThread = hint?.currentValue;
		if (possibleThread is ThreadIdentifier) {
			_lastSelectedThread = (imageboard, possibleThread);
		}
		else if (possibleThread is ImageboardScoped<ThreadIdentifier>) {
			_lastSelectedThread = (imageboard, possibleThread.item);
		}
		return PullTab(
			tab: (hint?.currentValue != null || _lastSelectedThread == null || _lastSelectedThread?.$1 != imageboard) ? null : PullTabTab(
				child: Text('Re-open /${_lastSelectedThread!.$2.board}/${_lastSelectedThread!.$2.id}'),
				onActivation: () => widget.onPull(_lastSelectedThread!.$2)
			),
			position: PullTabPosition.left,
			child: widget.child
		);
	}
}
