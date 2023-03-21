import 'package:chan/models/post.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/history_search.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

final _appLaunchTime = DateTime.now();

class HistoryPage extends StatefulWidget {
	final bool isActive;
	final void Function(String, ThreadIdentifier)? onWantOpenThreadInNewTab;

	const HistoryPage({
		required this.isActive,
		this.onWantOpenThreadInNewTab,
		Key? key
	}) : super(key: key);

	@override
	createState() => _HistoryPageState();
}

const _historyPageSize = 50;

class _HistoryPageState extends State<HistoryPage> {
	final _masterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	late final RefreshableListController<PersistentThreadState> _listController;
	late final ValueNotifier<ImageboardScoped<PostIdentifier>?> _valueInjector;

	@override
	void initState() {
		super.initState();
		_listController = RefreshableListController();
		_valueInjector = ValueNotifier(null);
	}

	void _onFullHistorySearch(String query) {
		_masterDetailKey.currentState!.masterKey.currentState!.push(FullWidthCupertinoPageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _valueInjector,
				builder: (context, ImageboardScoped<PostIdentifier>? selectedResult, child) {
					return HistorySearchPage(
						query: query,
						selectedResult: _valueInjector.value,
						onResultSelected: (result) {
							_masterDetailKey.currentState!.setValue(0, result);
						}
					);
				}
			),
			showAnimations: context.read<EffectiveSettings>().showAnimations,
			settings: dontAutoPopSettings
		));
	}

	@override
	Widget build(BuildContext context) {
		final threadStateBoxesAnimation = FilteringListenable(Persistence.sharedThreadStateBox.listenable(), () => widget.isActive);
		return MultiMasterDetailPage(
			showChrome: false,
			id: 'history',
			key: _masterDetailKey,
			paneCreator: () => [
				MultiMasterPane<ImageboardScoped<PostIdentifier>>(
					masterBuilder: (context, selectedThread, threadSetter) {
						final v = context.watch<MasterDetailHint>().currentValue;
						WidgetsBinding.instance.addPostFrameCallback((_){
							_valueInjector.value = v;
						});
						List<PersistentThreadState> states = [];
						return CupertinoPageScaffold(
							resizeToAvoidBottomInset: false,
							navigationBar: CupertinoNavigationBar(
								transitionBetweenRoutes: false,
								middle: const Text('History'),
								trailing: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										CupertinoButton(
											padding: EdgeInsets.zero,
											onPressed: () async {
												bool includeThreadsYouRepliedTo = false;
												await showCupertinoDialog(
													context: context,
													barrierDismissible: true,
													builder: (context) => StatefulBuilder(
														builder: (context, setDialogState) {
															final states = Persistence.sharedThreadStateBox.keys.map((k) => ImageboardScoped(
																imageboard: ImageboardRegistry.instance.getImageboard(k.split('/').first)!,
																item: Persistence.sharedThreadStateBox.get(k)!
															)).where((i) => i.item.savedTime == null && i.item.thread != null && (includeThreadsYouRepliedTo || i.item.youIds.isEmpty)).toList();
															final thisSessionStates = states.where((s) => s.item.lastOpenedTime.compareTo(_appLaunchTime) >= 0).toList();
															final now = DateTime.now();
															final lastDayStates = states.where((s) => now.difference(s.item.lastOpenedTime).inDays < 1);
															final lastWeekStates = states.where((s) => now.difference(s.item.lastOpenedTime).inDays < 7);
															return CupertinoAlertDialog(
																title: const Text('Clear history'),
																content: Column(
																	mainAxisSize: MainAxisSize.min,
																	children: [
																		const Text('Saved threads will not be deleted'),
																		const SizedBox(height: 16),
																		Row(
																			children: [
																				const Expanded(
																					child: Text('Include threads with your posts')
																				),
																				CupertinoSwitch(
																					value: includeThreadsYouRepliedTo,
																					onChanged: (v) {
																						setDialogState(() {
																							includeThreadsYouRepliedTo = v;
																						});
																					}
																				)
																			]
																		)
																	]
																),
																actions: [
																	CupertinoDialogAction(
																		onPressed: () async {
																			Navigator.pop(context);
																			for (final state in thisSessionStates) {
																				await state.item.delete();
																			}
																		},
																		isDestructiveAction: true,
																		child: Text('This session (${thisSessionStates.length})')
																	),
																	CupertinoDialogAction(
																		onPressed: () async {
																			Navigator.pop(context);
																			for (final state in lastDayStates) {
																				await state.item.delete();
																			}
																		},
																		isDestructiveAction: true,
																		child: Text('Today (${lastDayStates.length})')
																	),
																	CupertinoDialogAction(
																		onPressed: () async {
																			Navigator.pop(context);
																			for (final state in lastWeekStates) {
																				await state.item.delete();
																			}
																		},
																		isDestructiveAction: true,
																		child: Text('This week (${lastWeekStates.length})')
																	),
																	CupertinoDialogAction(
																		onPressed: () async {
																			Navigator.pop(context);
																			for (final state in states) {
																				await state.item.delete();
																			}
																		},
																		isDestructiveAction: true,
																		child: Text('All time (${states.length})')
																	),
																	CupertinoDialogAction(
																		onPressed: () => Navigator.pop(context),
																		child: const Text('Cancel')
																	)
																]
															);
														}
													)
												);
											},
											child: const Icon(CupertinoIcons.delete)
										),
										AnimatedBuilder(
											animation: Persistence.browserHistoryStatusListenable,
											builder: (context, _) => CupertinoButton(
												padding: EdgeInsets.zero,
												child: Icon(Persistence.enableHistory ? CupertinoIcons.stop : CupertinoIcons.play),
												onPressed: () {
													Persistence.enableHistory = !Persistence.enableHistory;
													Persistence.didChangeBrowserHistoryStatus();
													threadSetter(context.read<MasterDetailHint>().currentValue);
													showToast(
														context: context,
														message: Persistence.enableHistory ? 'History resumed' : 'History stopped',
														icon: Persistence.enableHistory ? CupertinoIcons.play : CupertinoIcons.stop
													);
												}
											)
										)
									]
								)
							),
							child: RefreshableList<PersistentThreadState>(
								filterableAdapter: (t) => t,
								filterAlternative: FilterAlternative(
									name: 'full history',
									handler: _onFullHistorySearch
								),
								controller: _listController,
								updateAnimation: threadStateBoxesAnimation,
								listUpdater: () async {
									states = Persistence.sharedThreadStateBox.values.where((s) => s.imageboard != null).toList();
									states.sort((a, b) => b.lastOpenedTime.compareTo(a.lastOpenedTime));
									final part = states.take(_historyPageSize).toList();
									await Future.wait(part.map((p) => p.ensureThreadLoaded()));
									return part.where((p) => p.thread != null).toList();
								},
								listExtender: (after) async {
									final index = states.indexOf(after);
									if (index != -1) {
										final part = states.skip(index + 1).take(_historyPageSize).toList();
										await Future.wait(part.map((p) => p.ensureThreadLoaded()));
										return part.where((p) => p.thread != null).toList();
									}
									return [];
								},
								minUpdateDuration: Duration.zero,
								id: 'history',
								sortMethods: const [],
								itemBuilder: (itemContext, state) {
									final isSelected = selectedThread(itemContext, state.imageboard!.scope(PostIdentifier.thread(state.identifier)));
									return ContextMenu(
										maxHeight: 125,
										actions: [
											if (widget.onWantOpenThreadInNewTab != null) ContextMenuAction(
												child: const Text('Open in new tab'),
												trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
												onPressed: () {
													widget.onWantOpenThreadInNewTab?.call(state.imageboardKey, state.identifier);
												}
											),
											ContextMenuAction(
												child: const Text('Remove'),
												onPressed: () async {
													await state.delete();
													_listController.update();
												},
												trailingIcon: CupertinoIcons.xmark,
												isDestructiveAction: true
											)
										],
										child: GestureDetector(
											behavior: HitTestBehavior.opaque,
											child: ImageboardScope(
												imageboardKey: state.imageboardKey,
												child: Builder(
													builder: (context) => ThreadRow(
														thread: state.thread!,
														isSelected: isSelected,
														semanticParentIds: const [-3],
														showSiteIcon: ImageboardRegistry.instance.count > 1,
														showBoardName: true,
														onThumbnailTap: (initialAttachment) {
															final attachments = _listController.items.expand((_) => _.item.thread!.attachments).toList();
															showGallery(
																context: context,
																attachments: attachments,
																replyCounts: {
																	for (final state in _listController.items)
																		for (final attachment in state.item.thread!.attachments)
																			attachment: state.item.thread!.replyCount
																},
																initialAttachment: attachments.firstWhere((a) => a.id == initialAttachment.id),
																onChange: (attachment) {
																	_listController.animateTo((p) => p.thread!.attachments.any((a) => a.id == attachment.id));
																},
																semanticParentIds: [-3],
																heroOtherEndIsBoxFitCover: false
															);
														}
													)
												)
											),
											onTap: () => threadSetter(state.imageboard!.scope(PostIdentifier.thread(state.identifier)))
										)
									);
								},
								filterHint: 'Search history'
							)
						);
					},
					detailBuilder: (selectedThread, poppedOut) {
						return BuiltDetailPane(
							widget: selectedThread != null ? ImageboardScope(
								imageboardKey: selectedThread.imageboard.key,
								child: ThreadPage(
									thread: selectedThread.item.thread,
									initialPostId: selectedThread.item.postId,
									boardSemanticId: -3
								)
							) : Builder(
								builder: (context) => Container(
									decoration: BoxDecoration(
										color: CupertinoTheme.of(context).scaffoldBackgroundColor,
									),
									child: const Center(
										child: Text('Select a thread')
									)
								)
							),
							pageRouteBuilder: fullWidthCupertinoPageRouteBuilder
						);
					}
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_listController.dispose();
	}
}