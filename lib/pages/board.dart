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
import 'package:chan/services/posts_image.dart';
import 'package:chan/services/report_post.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
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
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
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
	ThreadIdentifier? _lastSelectedThread;
	final _boardsPullTabKey = GlobalKey(debugLabel: '_BoardPageState._boardsPullTabKey');
	final _threadPullTabKey = GlobalKey(debugLabel: '_BoardPageState._threadPullTabKey');
	int _page = 1;
	DateTime? _lastCatalogUpdateTime;
	bool _searching = false;

	CatalogVariant? get _defaultBoardVariant => context.read<Persistence?>()?.browserState.catalogVariants[board?.name];
	CatalogVariant get _defaultGlobalVariant {
		if (context.read<ImageboardSite?>()?.isReddit ?? false) {
			return Settings.instance.redditCatalogVariant;
		}
		if (context.read<ImageboardSite?>()?.isHackerNews ?? false) {
			return Settings.instance.hackerNewsCatalogVariant;
		}
		return Settings.instance.catalogVariant;
	}

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
		dynamic possibleThread = hint?.currentValue;
		if (possibleThread is ThreadIdentifier) {
			selectedThread = possibleThread;
		}
		else if (possibleThread is ImageboardScoped<ThreadIdentifier>) {
			selectedThread = possibleThread.item;
		}
		if (selectedThread != null) {
			_lastSelectedThread = selectedThread;
			if (hint?.twoPane ?? false) {
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
		if (context.findAncestorStateOfType<NavigatorState>()?.canPop() == false) {
			final tab = context.read<PersistentBrowserTab?>();
			_lastSelectedThread ??= tab?.threadForPullTab ?? tab?.thread;
		}
		_searching = (widget.initialSearch ?? widget.tab?.initialSearch)?.isNotEmpty ?? false;
	}

	void _selectBoard() async {
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
		if (context.read<Imageboard?>()?.key != newBoard.imageboard.key) {
			_lastSelectedThread = null;
		}
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
		_lastSelectedThread = identifier;
		_listController.unfocusSearch();
		setState(() {});
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
						if (innerChoice != null && mounted) {
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
											fontSize: 20,
											fontWeight: subvariant == currentVariant ? FontWeight.bold : null
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
											if (innerChoice != null && mounted) {
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
				if (choice != null && mounted) {
					Navigator.pop(context, choice);
				}
			}
		}
	);

	void _showGalleryFromNextImage({bool initiallyShowGrid = false}) {
		if (board != null && Settings.instance.showImages(context, board!.name)) {
			final nextThreadWithImage = _listController.items.skip(max(0, _listController.firstVisibleIndex)).firstWhere((t) => t.item.attachments.isNotEmpty, orElse: () {
				return _listController.items.firstWhere((t) => t.item.attachments.isNotEmpty);
			});
			final attachments = _listController.items.expand((_) => _.item.attachments).toList();
			showGallery(
				context: context,
				attachments: attachments,
				replyCounts: {
					for (final thread in _listController.items)
						for (final attachment in thread.item.attachments)
							attachment: thread.item.replyCount
				},
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
		final selectedThread = context.watch<MasterDetailHint?>()?.currentValue;
		if (selectedThread is ThreadIdentifier) {
			_lastSelectedThread = selectedThread;
		}
		else if (selectedThread is ImageboardScoped<ThreadIdentifier>) {
			_lastSelectedThread = selectedThread.item;
		}
		final imageboard = context.watch<Imageboard?>();
		final site = context.watch<ImageboardSite?>();
		final settings = context.watch<Settings>();
		final mouseSettings = context.watch<MouseSettings>();
		final persistence = context.watch<Persistence?>();
		final variant = _variant ?? (_defaultBoardVariant ?? _defaultGlobalVariant);
		final openInNewTabZone = context.read<OpenInNewTabZone?>();
		final useCatalogGrid = persistence?.browserState.useCatalogGridPerBoard[board?.name] ?? persistence?.browserState.useCatalogGrid ?? settings.useCatalogGrid;
		Widget itemBuilder(BuildContext context, Thread thread, {String? highlightString}) {
			final isSaved = context.select<Persistence, bool>((p) => p.getThreadStateIfExists(thread.identifier)?.savedTime != null);
			final isThreadHidden = context.select<Persistence, bool?>((p) => p.browserState.getThreadHiding(thread.identifier));
			final isImageHidden = context.select<Settings, bool>((p) => p.areMD5sHidden(thread.md5s));
			final isSelected = widget.isThreadSelected?.call(context, thread.identifier) ?? false;
			final listFilterReason = context.watch<RefreshableListFilterReason?>();
			final isThreadHiddenByIdOrMD5s = isThreadHidden ?? isImageHidden;
			final isHidden = isThreadHiddenByIdOrMD5s || listFilterReason != null;
			return ContextMenu(
				// This makes sense for >1 column
				useLayoutBuilder: !useCatalogGrid,
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
							threadState.thread = thread;
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
					if (thread.attachments.any((a) => a.type.isImageSearchable)) ...buildImageSearchActions(context, () => whichAttachment(context, thread.attachments.where((a) => a.type.isImageSearchable).toList())),
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
												alertError(context, e.toStringDio());
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
				maxHeight: settings.maxCatalogRowHeight,
				child: GestureDetector(
					child: ThreadRow(
						contentFocus: useCatalogGrid,
						showLastReplies: !useCatalogGrid && settings.showLastRepliesInCatalog,
						thread: thread,
						isSelected: isSelected,
						semanticParentIds: [widget.semanticId],
						dimReadThreads: settings.dimReadThreads,
						countsUnreliable: thread.replyCount < 0,
						showBoardName: thread.board != board?.name,
						onThumbnailTap: (initialAttachment) {
							final attachments = _listController.items.expand((_) => _.item.attachments).toList();
							// It might not be in the list if the thread has been filtered
							final initialAttachmentInList = attachments.tryFirstWhere((a) => a.id == initialAttachment.id);
							showGallery(
								context: context,
								attachments: initialAttachmentInList == null ? [initialAttachment] : attachments,
								replyCounts: {
									for (final thread in _listController.items)
										for (final attachment in thread.item.attachments)
											attachment: thread.item.replyCount
								},
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
							highlightString: highlightString
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
		final supportsSearch = imageboard?.site.supportsSearch(board?.name) ?? const ImageboardSearchMetadata(name: '', options: ImageboardSearchOptions.none);
		return AdaptiveScaffold(
			resizeToAvoidBottomInset: false,
			bar: AdaptiveBar(
				title: AdaptiveIconButton(
					onPressed: widget.allowChangingBoard ? _selectBoard : null,
					dimWhenDisabled: false,
					icon: DefaultTextStyle.merge(
						style: const TextStyle(fontWeight: FontWeight.w600),
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
					if (board != null) AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.settings),
						onPressed: () {
							Navigator.of(context).push(TransparentRoute(
								builder: (context) => BoardSettingsPage(
									imageboard: imageboard!,
									board: board!
								)
							));
						}
					),
					AdaptiveIconButton(
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
									persistence?.browserState.catalogVariants.remove(board?.name);
								}
								setState(() {});
								return;
							}
							switch (choice.$2) {
								case _ThreadSortingMethodScope.global:
									if (site?.isReddit ?? false) {
										Settings.redditCatalogVariantSetting.value = choice.$1!;
									}
									else if (site?.isHackerNews ?? false) {
										Settings.hackerNewsCatalogVariantSetting.value = choice.$1!;
									}
									else {
										Settings.catalogVariantSetting.value = choice.$1!;
									}
									break;
								case _ThreadSortingMethodScope.board:
									persistence?.browserState.catalogVariants[board!.name] = choice.$1!;
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
						!(context.watch<MasterDetailHint?>()?.location.isVeryConstrained ?? false)
					) AdaptiveIconButton(
						icon: const Icon(CupertinoIcons.refresh),
						onPressed: () {
							_listController.blockAndUpdate();
						}
					),
					if (imageboard?.site.supportsPosting ?? false) NotifyingIcon(
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
								if ((context.read<MasterDetailHint?>()?.location.isVeryConstrained ?? false) && _replyBoxKey.currentState?.show != true) {
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
														board: board!.name,
														initialDraft: widget.tab?.draft,
														onDraftChanged: (draft) {
															widget.tab?.mutate((tab) => tab.draft = draft);
														},
														onReplyPosted: (receipt) async {
															if (imageboard.site.supportsPushNotifications) {
																await promptForPushNotificationsIfNeeded(ctx);
															}
															if (!mounted) return;
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
				) : PullTab(
					key: _threadPullTabKey,
					tab: (context.read<MasterDetailHint?>()?.currentValue != null || _lastSelectedThread == null) ? null : PullTabTab(
						child: Text('Re-open /${_lastSelectedThread!.board}/${_lastSelectedThread!.id}'),
						onActivation: () => _onThreadSelected(_lastSelectedThread!)
					),
					position: PullTabPosition.left,
					child: FilterZone(
						filter: context.select<Persistence, Filter>((p) => p.browserState.getCatalogFilter(board!.name)),
						child: PopScope(
							canPop: !(_replyBoxKey.currentState?.show ?? false),
							onPopInvoked: (didPop) {
								if (!didPop) {
									_replyBoxKey.currentState?.hideReplyBox();
									setState(() {});
								}
							},
							child: Column(
								children: [
									Flexible(
										child: CallbackShortcuts(
											bindings: {
												LogicalKeySet(LogicalKeyboardKey.keyG): () {
													if (_listController.state?.searchHasFocus ?? false) {
														return;
													}
													_showGalleryFromNextImage();
												}
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
														filterableAdapter: (t) => t,
														allowReordering: true,
														onWantAutosave: (thread) async {
															final persistence = context.read<Persistence>();
															if (persistence.browserState.autosavedIds[thread.board]?.contains(thread.id) ?? false) {
																// Already saw this thread
																return;
															}
															final threadState = persistence.getThreadState(thread.identifier);
															threadState.savedTime = DateTime.now();
															threadState.thread = thread;
															persistence.browserState.autosavedIds.putIfAbsent(thread.board, () => []).add(thread.id);
															await threadState.save();
															await persistence.didUpdateBrowserState();
														},
														onWantAutowatch: (thread, autoWatch) async {
															final imageboard = context.read<Imageboard>();
															await Future.microtask(() => {});
															if (imageboard.persistence.browserState.autowatchedIds[thread.board]?.contains(thread.id) ?? false) {
																// Already saw this thread
																return;
															}
															final threadState = imageboard.persistence.getThreadState(thread.identifier);
															threadState.thread = thread;
															imageboard.notifications.subscribeToThread(
																thread: thread.identifier,
																lastSeenId: thread.posts_.last.id,
																localYousOnly: settings.defaultThreadWatch?.localYousOnly ?? false,
																pushYousOnly: settings.defaultThreadWatch?.pushYousOnly ?? false,
																push: autoWatch.push ?? settings.defaultThreadWatch?.push ?? true,
																youIds: threadState.youIds,
																foregroundMuted: settings.defaultThreadWatch?.foregroundMuted ?? false
															);
															imageboard.persistence.browserState.autowatchedIds.putIfAbsent(thread.board, () => []).add(thread.id);
															await imageboard.persistence.didUpdateBrowserState();
														},
														sortMethods: [
															if (variant.sortingMethod == ThreadSortingMethod.replyCount)
																(a, b) => b.replyCount.compareTo(a.replyCount)
															else if (variant.sortingMethod == ThreadSortingMethod.threadPostTime)
																(a, b) => b.id.compareTo(a.id)
															else if (variant.sortingMethod == ThreadSortingMethod.postsPerMinute)
																(a, b) {
																	_lastCatalogUpdateTime ??= DateTime.now();
																	return -1 * ((b.replyCount + 1) / b.time.difference(_lastCatalogUpdateTime!).inSeconds).compareTo((a.replyCount + 1) / a.time.difference(_lastCatalogUpdateTime!).inSeconds);
																}
															else if (variant.sortingMethod == ThreadSortingMethod.lastReplyTime)
																(a, b) => b.posts.last.id.compareTo(a.posts.last.id)
															else if (variant.sortingMethod == ThreadSortingMethod.imageCount)
																(a, b) => b.imageCount.compareTo(a.imageCount)
															else if (variant.sortingMethod == ThreadSortingMethod.alphabeticByTitle)
																(a, b) => a.compareTo(b)
														],
														reverseSort: variant.reverseAfterSorting,
														minCacheExtent: useCatalogGrid ? settings.catalogGridHeight : 0,
														gridDelegate: useCatalogGrid ? SliverGridDelegateWithMaxCrossAxisExtentWithCacheTrickery(
															maxCrossAxisExtent: settings.catalogGridWidth,
															childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
														) : null,
														controller: _listController,
														listUpdater: () => site.getCatalog(board!.name, variant: variant, priority: RequestPriority.interactive).then((list) async {
															for (final thread in list) {
																await thread.preinit(catalog: true);
																await persistence?.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
															}
															_lastCatalogUpdateTime = DateTime.now();
															if (settings.hideOldStickiedThreads && list.length > 100) {
																list = list.where((thread) {
																	return !thread.isSticky || _lastCatalogUpdateTime!.difference(thread.time).compareTo(_oldThreadThreshold).isNegative;
																}).toList();
															}
															Future.delayed(const Duration(milliseconds: 100), () {
																if (!mounted) return;
																if (_loadCompleter?.isCompleted == false) {
																	_loadCompleter?.complete();
																}
															});
															return list;
														}),
														autoExtendDuringScroll: true,
														listExtender: (after) => site.getMoreCatalog(board!.name, after, variant: variant, priority: RequestPriority.interactive).then((list) async {
															for (final thread in list) {
																await thread.preinit(catalog: true);
																await persistence?.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
															}
															return list;
														}),
														disableBottomUpdates: !(variant.hasPagedCatalog ?? site.hasPagedCatalog),
														id: '${site.name} /${board!.name}/${variant.dataId}',
														itemBuilder: (context, thread) => itemBuilder(context, thread),
														filteredItemBuilder: (context, thread, resetPage, filterText) => itemBuilder(context, thread, highlightString: filterText),
														filterHint: 'Search in board',
														filterAlternative: (widget.onWantArchiveSearch == null || !supportsSearch.options.text) ? null : FilterAlternative(
															name: supportsSearch.name,
															handler: (s) {
																widget.onWantArchiveSearch!(imageboard!.key, board!.name, s);
															}
														)
													),
													RepaintBoundary(
														child: AnimatedBuilder(
															animation: _listController.slowScrolls,
															builder: (context, _) {
																_page = (_listController.firstVisibleItem?.item.currentPage ?? _page);
																final scrollAnimationDuration = Settings.showAnimationsSetting.watch(context) ? const Duration(milliseconds: 200) : const Duration(milliseconds: 1);
																scrollToTop() => _listController.scrollController?.animateTo(0.0, duration: scrollAnimationDuration, curve: Curves.ease);
																final realImageCount = _listController.items.fold<int>(0, (t, a) => t + a.item.attachments.length);
																return SafeArea(
																	child: Align(
																		alignment: settings.showListPositionIndicatorsOnLeft ? Alignment.bottomLeft : Alignment.bottomRight,
																		child: Padding(
																			padding: const EdgeInsets.all(16),
																			child: Row(
																				mainAxisSize: MainAxisSize.min,
																				children: [
																					if (settings.showGalleryGridButton && realImageCount > 1) ...[
																						AdaptiveFilledButton(
																							padding: const EdgeInsets.all(8),
																							color: ChanceTheme.primaryColorWithBrightness80Of(context),
																							onPressed: () => _showGalleryFromNextImage(initiallyShowGrid: true),
																							child: Icon(CupertinoIcons.square_grid_2x2, size: 24, color: ChanceTheme.backgroundColorOf(context))
																						),
																						const SizedBox(width: 8),
																					],
																					GestureDetector(
																						onLongPress: () {
																							lightHapticFeedback();
																							_listController.animateTo((item) => false, orElseLast: (item) => true, alignment: 1.0, duration: scrollAnimationDuration);
																						},
																						child: AdaptiveFilledButton(
																							onPressed: () async {
																								lightHapticFeedback();
																								if (_searching) {
																									_listController.state?.closeSearch();
																								}
																								else {
																									await scrollToTop();
																									_page = _listController.items.first.item.currentPage ?? 1;
																								}
																							},
																							color: ChanceTheme.primaryColorWithBrightness80Of(context),
																							padding: const EdgeInsets.all(8),
																							child: Row(
																								mainAxisSize: MainAxisSize.min,
																								children: _searching ? [
																									Icon(CupertinoIcons.search, color: ChanceTheme.backgroundColorOf(context)),
																									const SizedBox(width: 8),
																									Icon(CupertinoIcons.xmark, color: ChanceTheme.backgroundColorOf(context))
																								] : [
																									Icon(CupertinoIcons.doc, color: ChanceTheme.backgroundColorOf(context)),
																									SizedBox(
																										width: 25,
																										child: Text(
																											_page.toString(),
																											textAlign: TextAlign.center,
																											style: TextStyle(
																												color: ChanceTheme.backgroundColorOf(context)
																											)
																										)
																									)
																								]
																							)
																						)
																					)
																				]
																			)
																		)
																	)
																);
															}
														)
													)
												]
											)
										)
									),
									RepaintBoundary(
										child: ReplyBox(
											key: _replyBoxKey,
											board: board!.name,
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
								]
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