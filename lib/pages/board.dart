import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/board.dart';
import 'package:chan/pages/board_switcher.dart';
import 'package:chan/pages/board_watch_controls.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/reverse_image_search.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_dialog.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/post_spans.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/reply_box.dart';
import 'package:chan/widgets/pull_tab.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';

import 'package:chan/models/thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chan/widgets/cupertino_page_route.dart';

import 'package:chan/pages/gallery.dart';

const _oldThreadThreshold = Duration(days: 7);

enum _ThreadSortingMethodScope {
	global,
	board,
	tab
}

class BoardPage extends StatefulWidget {
	final int semanticId;
	final ImageboardBoard? initialBoard;
	final bool allowChangingBoard;
	final ValueChanged<ImageboardScoped<ImageboardBoard>>? onBoardChanged;
	final ValueChanged<ThreadIdentifier>? onThreadSelected;
	final bool Function(BuildContext, ThreadIdentifier)? isThreadSelected;
	final String? initialSearch;
	final ValueChanged<String?>? onSearchChanged;
	final String Function()? getInitialDraftText;
	final ValueChanged<String>? onDraftTextChanged;
	final String Function()? getInitialDraftSubject;
	final ValueChanged<String>? onDraftSubjectChanged;
	final void Function(String, ThreadIdentifier, bool)? onWantOpenThreadInNewTab;
	final String Function()? getInitialThreadDraftOptions;
	final ValueChanged<String>? onThreadDraftOptionsChanged;
	final String? Function()? getInitialThreadDraftFilePath;
	final ValueChanged<String?>? onThreadDraftFilePathChanged;
	final void Function(String, String, String)? onWantArchiveSearch;
	final CatalogVariant? initialCatalogVariant;
	final ValueChanged<CatalogVariant?>? onCatalogVariantChanged;
	const BoardPage({
		required this.initialBoard,
		this.allowChangingBoard = true,
		this.onBoardChanged,
		this.onThreadSelected,
		this.isThreadSelected,
		this.initialSearch,
		this.onSearchChanged,
		this.getInitialDraftText,
		this.onDraftTextChanged,
		this.getInitialDraftSubject,
		this.onDraftSubjectChanged,
		this.onWantOpenThreadInNewTab,
		this.getInitialThreadDraftOptions,
		this.onThreadDraftOptionsChanged,
		this.getInitialThreadDraftFilePath,
		this.onThreadDraftFilePathChanged,
		this.onWantArchiveSearch,
		this.initialCatalogVariant,
		this.onCatalogVariantChanged,
		required this.semanticId,
		Key? key
	}) : super(key: key);

	@override
	createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
	late ImageboardBoard? board;
	late final RefreshableListController<Thread> _listController;
	final _replyBoxKey = GlobalKey<ReplyBoxState>();
	Completer<void>? _loadCompleter;
	CatalogVariant? _variant;
	ThreadIdentifier? _lastSelectedThread;
	final _boardsPullTabKey = GlobalKey();
	final _threadPullTabKey = GlobalKey();
	int _page = 1;
	DateTime? _lastCatalogUpdateTime;
	bool _searching = false;

	CatalogVariant? get _defaultBoardVariant => context.read<Persistence?>()?.browserState.catalogVariants[board?.name];
	CatalogVariant get _defaultGlobalVariant {
		if (context.read<ImageboardSite?>()?.isReddit ?? false) {
			return context.read<EffectiveSettings>().redditCatalogVariant;
		}
		if (context.read<ImageboardSite?>()?.isHackerNews ?? false) {
			return context.read<EffectiveSettings>().hackerNewsCatalogVariant;
		}
		return context.read<EffectiveSettings>().catalogVariant;
	}

	@override
	void initState() {
		super.initState();
		_listController = RefreshableListController();
		_variant = widget.initialCatalogVariant;
		board = widget.initialBoard;
		if (board == null) {
			Future.delayed(const Duration(milliseconds: 100), _selectBoard);
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
		else if (context.findAncestorStateOfType<NavigatorState>()?.canPop() == false) {
			_lastSelectedThread = context.read<PersistentBrowserTab?>()?.thread;
		}
		_searching = widget.initialSearch?.isNotEmpty ?? false;
	}

	void _selectBoard() async {
		final newBoard = await Navigator.of(context).push<ImageboardScoped<ImageboardBoard>>(TransparentRoute(
			builder: (ctx) => BoardSwitcherPage(
				initialImageboardKey: context.read<Imageboard?>()?.key
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations
		));
		if (newBoard != null) {
			_swapBoard(newBoard);
		}
	}
	
	void _swapBoard(ImageboardScoped<ImageboardBoard> newBoard) {
		widget.onBoardChanged?.call(newBoard);
		setState(() {
			board = newBoard.item;
			if (_listController.scrollController?.hasOnePosition ?? false) {
				_listController.scrollController?.jumpTo(0);
			}
			_variant = null;
			widget.onCatalogVariantChanged?.call(_variant);
		});
	}

	void _onThreadSelected(ThreadIdentifier identifier) {
		_lastSelectedThread = identifier;
		setState(() {});
		if (widget.onThreadSelected != null) {
			widget.onThreadSelected!(identifier);
		}
		else {
			Navigator.of(context).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: context.read<Imageboard>(),
					child: ThreadPage(
						thread: identifier,
						boardSemanticId: widget.semanticId,
					)
				),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			));
		}
	}

	Future<(CatalogVariant?, _ThreadSortingMethodScope)?> _variantDetailsMenu({
		required BuildContext context,
		required CatalogVariant variant,
		required List<CatalogVariant> others,
		required CatalogVariant currentVariant
	}) => showCupertinoModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
		context: context,
		useRootNavigator: false,
		builder: (context) => CupertinoActionSheet(
			title: Text(variant.name),
			actions: [
				if (context.read<ImageboardSite>().supportsMultipleBoards) CupertinoActionSheetAction2(
					child: Row(
						children: [
							const SizedBox(width: 40),
							Expanded(
								child: Text('Set as default for /${board?.name}/', style: TextStyle(
									fontWeight: _defaultBoardVariant == variant ? FontWeight.bold : null,
									color: _defaultBoardVariant == variant ? CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context) : null
								), textAlign: TextAlign.left)
							),
							if (_defaultBoardVariant == variant) GestureDetector(
								child: const SizedBox(
									width: 40,
									child: Icon(CupertinoIcons.xmark)
								),
								onTap: () => Navigator.pop(context, const (null, _ThreadSortingMethodScope.board))
							)
						]
					),
					onPressed: () {
						if (_defaultBoardVariant == variant) return;
						Navigator.pop(context, (variant, _ThreadSortingMethodScope.board));
					}
				),
				CupertinoActionSheetAction2(
					child: Row(
						children: [
							const SizedBox(width: 40),
							Expanded(
								child: Text('Set as global default', style: TextStyle(
									fontWeight: _defaultGlobalVariant == variant ? FontWeight.bold : null,
									color: _defaultGlobalVariant == variant ? CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context) : null
								), textAlign: TextAlign.left)
							)
						]
					),
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
			cancelButton: CupertinoActionSheetAction2(
				child: const Text('Cancel'),
				onPressed: () => Navigator.pop(context)
			)
		)
	);

	Widget _buildVariantDetails({
		required BuildContext context,
		required CatalogVariantGroup v,
		required CatalogVariant currentVariant,
	}) => GestureDetector(
		child: Container(
			constraints: const BoxConstraints(
				minHeight: 56
			),
			padding: const EdgeInsets.symmetric(
				vertical: 16,
				horizontal: 10
			),
			child: Row(
				children: [
					SizedBox(
						width: 40,
						child: Center(
							child: Icon(
								v.variants.tryFirst?.icon ?? ((v.variants.tryFirst?.reverseAfterSorting ?? false) ? CupertinoIcons.sort_up : CupertinoIcons.sort_down),
								color: ((v.variants.length == 1 || v.hasPrimary) && v.variants.first == currentVariant) ? CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context) : null
							)
						)
					),
					Expanded(
						child: Text(v.name, style: TextStyle(
							fontSize: 20,
							fontWeight: v.variants.contains(currentVariant) ? FontWeight.bold : null,
							color: ((v.variants.length == 1 || v.hasPrimary) && v.variants.first == currentVariant) ? CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context) : null
						))
					),
					if (v.variants.first == _variant) GestureDetector(
						child: const SizedBox(
							width: 40,
							child: Icon(CupertinoIcons.xmark)
						),
						onTap: () => Navigator.pop(context, const (null, _ThreadSortingMethodScope.tab))
					),
					if ((v.hasPrimary || v.variants.length == 1) && !v.variants.first.temporary) GestureDetector(
						child: const SizedBox(
							width: 40,
							child: Icon(CupertinoIcons.ellipsis)
						),
						onTap: () async {
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
					else if (v.variants.length > 1) const Icon(CupertinoIcons.chevron_right)
				]
			)
		),
		onTap: () async {
			if (((v.variants.length == 1 || v.hasPrimary) && v.variants.first == currentVariant)) {
				return;
			}
			if (v.hasPrimary || v.variants.length == 1) {
				Navigator.pop(context, (v.variants.first, _ThreadSortingMethodScope.tab));
			}
			else {
				final choice = await showCupertinoModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
					context: context,
					useRootNavigator: false,
					builder: (context) => CupertinoActionSheet(
						title: Text(v.name),
						actions: v.variants.map((subvariant) => GestureDetector(
							child: Container(
								constraints: const BoxConstraints(
									minHeight: 56
								),
								padding: const EdgeInsets.symmetric(
									vertical: 16,
									horizontal: 10
								),
								child: Row(
									children: [
										SizedBox(
											width: 40,
											child: Center(
												child: Icon(subvariant.icon ?? (subvariant.reverseAfterSorting ? CupertinoIcons.sort_up : CupertinoIcons.sort_down)),
											)
										),
										Expanded(
											child: Text(subvariant.name, style: const TextStyle(
												fontSize: 20
											))
										),
										GestureDetector(
											child: const Icon(CupertinoIcons.ellipsis),
											onTap: () async {
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
								)
							),
							onTap: () async {
								Navigator.pop(context, (subvariant, _ThreadSortingMethodScope.tab));
							}
						)).toList()
					)
				);
				if (choice != null && mounted) {
					Navigator.pop(context, choice);
				}
			}
		}
	);

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
		final settings = context.watch<EffectiveSettings>();
		final persistence = context.watch<Persistence?>();
		final notifications = context.watch<Notifications?>();
		final boardWatch = notifications?.getBoardWatch(board?.name ?? '');
		final variant = _variant ?? (_defaultBoardVariant ?? _defaultGlobalVariant);
		Widget itemBuilder(BuildContext context, Thread thread, {String? highlightString}) {
			final isSaved = context.select<Persistence, bool>((p) => p.getThreadStateIfExists(thread.identifier)?.savedTime != null);
			final isThreadHidden = context.select<Persistence, bool>((p) => p.browserState.isThreadHidden(thread.board, thread.id));
			final isImageHidden = context.select<Persistence, bool>((p) => p.browserState.areMD5sHidden(thread.md5s));
			final isSelected = widget.isThreadSelected?.call(context, thread.identifier) ?? false;
			return ContextMenu(
				actions: [
					if (widget.onWantOpenThreadInNewTab != null) ...[
						ContextMenuAction(
							child: const Text('Open in new tab'),
							trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
							onPressed: () {
								widget.onWantOpenThreadInNewTab?.call(imageboard!.key, thread.identifier, false);
							}
						),
						ContextMenuAction(
							child: const Text('Open in new private tab'),
							trailingIcon: CupertinoIcons.eyeglasses,
							onPressed: () {
								widget.onWantOpenThreadInNewTab?.call(imageboard!.key, thread.identifier, true);
							}
						),
					],
					if (isSaved) ContextMenuAction(
						child: const Text('Un-save thread'),
						trailingIcon: CupertinoIcons.bookmark_fill,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							threadState.savedTime = null;
							threadState.save();
							setState(() {});
						}
					)
					else ContextMenuAction(
						child: const Text('Save thread'),
						trailingIcon: CupertinoIcons.bookmark,
						onPressed: () {
							final threadState = context.read<Persistence>().getThreadState(thread.identifier);
							threadState.thread = thread;
							threadState.savedTime = DateTime.now();
							threadState.save();
							setState(() {});
						}
					),
					if (isThreadHidden) ContextMenuAction(
						child: const Text('Unhide thread'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.unHideThread(thread.board, thread.id);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					)
					else ContextMenuAction(
						child: const Text('Hide thread'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							context.read<Persistence>().browserState.hideThread(thread.board, thread.id);
							context.read<Persistence>().didUpdateBrowserState();
							setState(() {});
						}
					),
					if (isImageHidden) ContextMenuAction(
						child: const Text('Unhide by image'),
						trailingIcon: CupertinoIcons.eye_slash_fill,
						onPressed: () {
							context.read<Persistence>().browserState.unHideByMD5s(thread.md5s);
							context.read<Persistence>().didUpdateHiddenMD5s();
							setState(() {});
						}
					)
					else if (thread.attachments.isNotEmpty) ContextMenuAction(
						child: const Text('Hide by image'),
						trailingIcon: CupertinoIcons.eye_slash,
						onPressed: () {
							thread.md5s.forEach(context.read<Persistence>().browserState.hideByMD5);
							context.read<Persistence>().didUpdateHiddenMD5s();
							setState(() {});
						}
					),
					...buildImageSearchActions(context, () => whichAttachment(context, thread.attachments)),
					ContextMenuAction(
						child: const Text('Report thread'),
						trailingIcon: CupertinoIcons.exclamationmark_octagon,
						onPressed: () {
							openBrowser(context, context.read<ImageboardSite>().getPostReportUrl(thread.board, thread.id, thread.id));
						}
					)
				],
				maxHeight: settings.maxCatalogRowHeight,
				child: GestureDetector(
					child: ThreadRow(
						contentFocus: settings.useCatalogGrid,
						contentFocusBorderRadiusAndPadding: settings.catalogGridModeCellBorderRadiusAndMargin,
						thread: thread,
						isSelected: isSelected,
						semanticParentIds: [widget.semanticId],
						dimReadThreads: settings.dimReadThreads,
						countsUnreliable: variant.countsUnreliable,
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
									_listController.animateTo((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
								},
								semanticParentIds: [widget.semanticId],
								heroOtherEndIsBoxFitCover: settings.useCatalogGrid || settings.squareThumbnails
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
			navigationBarBoardName = board != null ? imageboard.site.formatBoardName(board!) : 'Select Board';
		}
		return CupertinoPageScaffold(
			resizeToAvoidBottomInset: false,
			navigationBar: CupertinoNavigationBar(
				transitionBetweenRoutes: false,
				leading: settings.supportMouse.value && !Navigator.of(context).canPop() ? CupertinoButton(
					padding: EdgeInsets.zero,
					child: const Icon(CupertinoIcons.refresh),
					onPressed: () {
						_listController.blockAndUpdate();
					}
				) : null,
				middle: GestureDetector(
					onTap: widget.allowChangingBoard ? _selectBoard : null,
					child: Wrap(
						alignment: WrapAlignment.center,
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
				),
				trailing: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						if (board != null && (site?.supportsPushNotifications ?? false)) CupertinoButton(
							padding: EdgeInsets.zero,
							child: boardWatch == null ? const Icon(CupertinoIcons.bell) : const Icon(CupertinoIcons.bell_fill),
							onPressed: () {
								Navigator.of(context).push(TransparentRoute(
									showAnimations: settings.showAnimations,
									builder: (context) => BoardWatchControlsPage(
										imageboard: imageboard!,
										board: board!
									)
								));
							}
						),
						CupertinoButton(
							padding: EdgeInsets.zero,
							child: (variant.icon != null && !variant.temporary) ? FittedBox(
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
								final choice = await showCupertinoModalPopup<(CatalogVariant?, _ThreadSortingMethodScope)>(
									context: context,
									useRootNavigator: false,
									builder: (context) => CupertinoActionSheet(
										title: const Text('Sort by...'),
										actions:(site?.catalogVariantGroups ?? []).map((v) => _buildVariantDetails(
											context: context,
											v: v,
											currentVariant: variant
										)).toList(),
										cancelButton: CupertinoActionSheetAction2(
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
										widget.onCatalogVariantChanged?.call(_variant);
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
											settings.redditCatalogVariant = choice.$1!;
										}
										else if (site?.isHackerNews ?? false) {
											settings.hackerNewsCatalogVariant = choice.$1!;
										}
										else {
											settings.catalogVariant = choice.$1!;
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
										widget.onCatalogVariantChanged?.call(_variant);
										setState(() {});
										break;
								}
							}
						),
						if (imageboard?.site.supportsPosting ?? false) CupertinoButton(
							padding: EdgeInsets.zero,
							child: (_replyBoxKey.currentState?.show ?? false) ? const Icon(CupertinoIcons.pencil_slash) : const Icon(CupertinoIcons.pencil),
							onPressed: () {
								if (context.read<MasterDetailHint?>()?.twoPane == true && _replyBoxKey.currentState?.show != true) {
									showCupertinoModalPopup(
										context: context,
										builder: (ctx) => ImageboardScope(
											imageboardKey: null,
											imageboard: imageboard!,
											child: Padding(
												padding: MediaQuery.viewInsetsOf(ctx),
												child: Container(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													child: ReplyBox(
														fullyExpanded: true,
														board: board!.name,
														initialText: widget.getInitialDraftText?.call() ?? '',
														onTextChanged: (text) {
															widget.onDraftTextChanged?.call(text);
														},
														initialSubject: widget.getInitialDraftSubject?.call() ?? '',
														onSubjectChanged: (subject) {
															widget.onDraftSubjectChanged?.call(subject);
														},
														initialOptions: widget.getInitialThreadDraftOptions?.call() ?? '',
														onOptionsChanged: (options) {
															widget.onThreadDraftOptionsChanged?.call(options);
														},
														initialFilePath: widget.getInitialThreadDraftFilePath?.call() ?? '',
														onFilePathChanged: (filePath) {
															widget.onThreadDraftFilePathChanged?.call(filePath);
														},
														onReplyPosted: (receipt) async {
															if (imageboard.site.supportsPushNotifications) {
																await promptForPushNotificationsIfNeeded(ctx);
															}
															if (!mounted) return;
															imageboard.notifications.subscribeToThread(
																thread: ThreadIdentifier(board!.name, receipt.id),
																lastSeenId: receipt.id,
																localYousOnly: false,
																pushYousOnly: false,
																push: true,
																youIds: [receipt.id]
															);
															_listController.update();
															_onThreadSelected(ThreadIdentifier(board!.name, receipt.id));
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
					]
				)
			),
			child: board == null ? const Center(
				child: Text('No Board Selected')
			) : PullTab(
				key: _boardsPullTabKey,
				tab: PullTabTab(
					child: const Text('Open boards'),
					onActivation: _selectBoard,
				),
				enabled: widget.allowChangingBoard,
				child: PullTab(
					key: _threadPullTabKey,
					tab: (context.read<MasterDetailHint?>()?.currentValue != null || _lastSelectedThread == null) ? null : PullTabTab(
						child: Text('Re-open /${_lastSelectedThread!.board}/${_lastSelectedThread!.id}'),
						onActivation: () => _onThreadSelected(_lastSelectedThread!)
					),
					position: PullTabPosition.left,
					child: FilterZone(
						filter: context.select<Persistence, Filter>((p) => p.browserState.getCatalogFilter(board!.name)),
						child: WillPopScope(
							onWillPop: () async {
								if (_replyBoxKey.currentState?.show ?? false) {
									_replyBoxKey.currentState?.hideReplyBox();
									setState(() {});
									return false;
								}
								return true;
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
													if (board != null && context.read<EffectiveSettings>().showImages(context, board!.name)) {
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
																_listController.animateTo((p) => p.attachments.any((a) => a.id == attachment.id), alignment: 0.5);
															},
															semanticParentIds: [widget.semanticId],
															heroOtherEndIsBoxFitCover: true//settings.useCatalogGrid
														);
													}
												}
											},
											child: site == null ? const Center(
												child: ErrorMessageCard('No imageboard selected')
											) : Stack(
												fit: StackFit.expand,
												children: [
													RefreshableList<Thread>(
														initialFilter: widget.initialSearch,
														onFilterChanged: (newFilter) {
															widget.onSearchChanged?.call(newFilter);
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
														],
														reverseSort: variant.reverseAfterSorting,
														gridDelegate: settings.useCatalogGrid ? SliverGridDelegateWithMaxCrossAxisExtent(
															maxCrossAxisExtent: settings.catalogGridWidth,
															childAspectRatio: settings.catalogGridWidth / settings.catalogGridHeight
														) : null,
														controller: _listController,
														listUpdater: () => site.getCatalog(board!.name, variant: variant).then((list) async {
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
														listExtender: (after) => site.getMoreCatalog(after, variant: variant).then((list) async {
															for (final thread in list) {
																await thread.preinit(catalog: true);
																await persistence?.getThreadStateIfExists(thread.identifier)?.ensureThreadLoaded();
															}
															return list;
														}),
														disableBottomUpdates: !site.hasPagedCatalog,
														id: '${site.name} /${board!.name}/${variant.dataId}',
														itemBuilder: (context, thread) => itemBuilder(context, thread),
														filteredItemBuilder: (context, thread, resetPage, filterText) => itemBuilder(context, thread, highlightString: filterText),
														filterHint: 'Search in board',
														filterAlternative: (widget.onWantArchiveSearch == null || !imageboard!.site.supportsSearch) ? null : FilterAlternative(
															name: '${board == null ? '' : site.formatBoardName(board!)} archives',
															handler: (s) {
																widget.onWantArchiveSearch!(imageboard.key, board!.name, s);
															}
														)
													),
													RepaintBoundary(
														child: AnimatedBuilder(
															animation: _listController.slowScrolls,
															builder: (context, _) {
																_page = (_listController.firstVisibleItem?.currentPage ?? _page);
																scrollToTop() => _listController.scrollController?.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
																return SafeArea(
																	child: Align(
																		alignment: settings.showListPositionIndicatorsOnLeft ? Alignment.bottomLeft : Alignment.bottomRight,
																		child: Row(
																			mainAxisSize: MainAxisSize.min,
																			children: [
																				CupertinoButton(
																					padding: EdgeInsets.zero,
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
																					child: Container(
																						decoration: BoxDecoration(
																							color: CupertinoTheme.of(context).primaryColorWithBrightness(0.8),
																							borderRadius: const BorderRadius.all(Radius.circular(8))
																						),
																						padding: const EdgeInsets.all(8),
																						margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
																						child: Row(
																							mainAxisSize: MainAxisSize.min,
																							children: _searching ? [
																								Icon(CupertinoIcons.search, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
																								const SizedBox(width: 8),
																								Icon(CupertinoIcons.xmark, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
																							] : [
																								Icon(CupertinoIcons.doc, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
																								SizedBox(
																									width: 25,
																									child: Text(
																										_page.toString(),
																										textAlign: TextAlign.center,
																										style: TextStyle(
																											color: CupertinoTheme.of(context).scaffoldBackgroundColor
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
											initialText: widget.getInitialDraftText?.call() ?? '',
											onTextChanged: (text) {
												widget.onDraftTextChanged?.call(text);
											},
											initialSubject: widget.getInitialDraftSubject?.call() ?? '',
											onSubjectChanged: (subject) {
												widget.onDraftSubjectChanged?.call(subject);
											},
											initialOptions: widget.getInitialThreadDraftOptions?.call() ?? '',
											onOptionsChanged: (options) {
												widget.onThreadDraftOptionsChanged?.call(options);
											},
											initialFilePath: widget.getInitialThreadDraftFilePath?.call() ?? '',
											onFilePathChanged: (filePath) {
												widget.onThreadDraftFilePathChanged?.call(filePath);
											},
											onReplyPosted: (receipt) async {
												if (imageboard?.site.supportsPushNotifications == true) {
													await promptForPushNotificationsIfNeeded(context);
												}
												if (!mounted) return;
												imageboard?.notifications.subscribeToThread(
													thread: ThreadIdentifier(board!.name, receipt.id),
													lastSeenId: receipt.id,
													localYousOnly: false,
													pushYousOnly: false,
													push: true,
													youIds: [receipt.id]
												);
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