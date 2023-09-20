import 'package:chan/main.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/history_search.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/context_menu.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:chan/widgets/refreshable_list.dart';
import 'package:chan/widgets/thread_row.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

final _appLaunchTime = DateTime.now();

class HistoryPage extends StatefulWidget {
	final bool isActive;

	const HistoryPage({
		required this.isActive,
		Key? key
	}) : super(key: key);

	@override
	createState() => HistoryPageState();
}

const _historyPageSize = 50;

class HistoryPageState extends State<HistoryPage> {
	final masterDetailKey = GlobalKey<MultiMasterDetailPageState>();
	late final RefreshableListController<PersistentThreadState> _listController;
	late final ValueNotifier<ImageboardScoped<PostIdentifier>?> _valueInjector;

	@override
	void initState() {
		super.initState();
		_listController = RefreshableListController();
		_valueInjector = ValueNotifier(null);
	}

	void _onFullHistorySearch(String query) {
		masterDetailKey.currentState!.masterKey.currentState!.push(adaptivePageRoute(
			builder: (context) => ValueListenableBuilder(
				valueListenable: _valueInjector,
				builder: (context, ImageboardScoped<PostIdentifier>? selectedResult, child) {
					return HistorySearchPage(
						query: query,
						selectedResult: _valueInjector.value,
						onResultSelected: (result) {
							masterDetailKey.currentState!.setValue(0, result);
						}
					);
				}
			),
			settings: dontAutoPopSettings
		));
	}

	Future<void> updateList() => _listController.update();

	@override
	Widget build(BuildContext context) {
		final threadStateBoxesAnimation = FilteringListenable(Persistence.sharedThreadStateBox.listenable(), () => widget.isActive);
		return MultiMasterDetailPage(
			showChrome: false,
			id: 'history',
			key: masterDetailKey,
			paneCreator: () => [
				MultiMasterPane<ImageboardScoped<PostIdentifier>>(
					masterBuilder: (context, selectedThread, threadSetter) {
						final v = context.watch<MasterDetailHint>().currentValue;
						WidgetsBinding.instance.addPostFrameCallback((_){
							_valueInjector.value = v;
						});
						List<PersistentThreadState> states = [];
						final settings = context.watch<EffectiveSettings>();
						return AdaptiveScaffold(
							resizeToAvoidBottomInset: false,
							bar: AdaptiveBar(
								title: const Text('History'),
								actions: [
									AdaptiveIconButton(
										onPressed: () async {
											await showAdaptiveDialog(
												context: context,
												barrierDismissible: true,
												builder: (context) => StatefulBuilder(
													builder: (context, setDialogState) {
														final states = Persistence.sharedThreadStateBox.values.where((i) => i.savedTime == null && i.threadWatch == null && (settings.includeThreadsYouRepliedToWhenDeletingHistory || i.youIds.isEmpty)).toList();
														final thisSessionStates = states.where((s) => s.lastOpenedTime.compareTo(_appLaunchTime) >= 0).toList();
														final now = DateTime.now();
														final lastDayStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 1);
														final lastWeekStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 7);
														return AdaptiveAlertDialog(
															title: const Text('Clear history'),
															content: Column(
																mainAxisSize: MainAxisSize.min,
																children: [
																	const Text('Saved and watched threads will not be deleted'),
																	const SizedBox(height: 16),
																	Row(
																		children: [
																			const Expanded(
																				child: Text('Include threads with your posts')
																			),
																			AdaptiveSwitch(
																				value: settings.includeThreadsYouRepliedToWhenDeletingHistory,
																				onChanged: (v) {
																					setDialogState(() {
																						settings.includeThreadsYouRepliedToWhenDeletingHistory = v;
																					});
																				}
																			)
																		]
																	)
																]
															),
															actions: [
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context);
																		for (final state in thisSessionStates) {
																			await state.delete();
																		}
																	},
																	isDestructiveAction: true,
																	child: Text('This session (${thisSessionStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context);
																		for (final state in lastDayStates) {
																			await state.delete();
																		}
																	},
																	isDestructiveAction: true,
																	child: Text('Today (${lastDayStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context);
																		for (final state in lastWeekStates) {
																			await state.delete();
																		}
																	},
																	isDestructiveAction: true,
																	child: Text('This week (${lastWeekStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context);
																		for (final state in states) {
																			await state.delete();
																		}
																	},
																	isDestructiveAction: true,
																	child: Text('All time (${states.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () => Navigator.pop(context),
																	child: const Text('Cancel')
																)
															]
														);
													}
												)
											);
										},
										icon: const Icon(CupertinoIcons.delete)
									),
									Builder(
										builder: (context) => AdaptiveIconButton(
											icon: Icon(context.select<EffectiveSettings, bool>((s) => s.recordThreadsInHistory) ? CupertinoIcons.stop : CupertinoIcons.play),
											onPressed: () {
												context.read<EffectiveSettings>().recordThreadsInHistory = !context.read<EffectiveSettings>().recordThreadsInHistory;
												threadSetter(context.read<MasterDetailHint>().currentValue);
												showToast(
													context: context,
													message: context.read<EffectiveSettings>().recordThreadsInHistory ? 'History resumed' : 'History stopped',
													icon: context.read<EffectiveSettings>().recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
												);
											}
										)
									)
								]
							),
							body: RefreshableList<PersistentThreadState>(
								filterableAdapter: (t) => t,
								filterAlternative: FilterAlternative(
									name: 'full history',
									suggestWhenFilterEmpty: true,
									handler: _onFullHistorySearch
								),
								controller: _listController,
								updateAnimation: threadStateBoxesAnimation,
								listUpdater: () async {
									states = Persistence.sharedThreadStateBox.values.where((s) => s.imageboard != null && s.showInHistory).toList();
									states.sort((a, b) => b.lastOpenedTime.compareTo(a.lastOpenedTime));
									final part = states.take(_historyPageSize).toList();
									final futures = <Future<void>>[];
									for (final p in part) {
										if (p.thread?.posts_.last.isInitialized ?? false) {
											continue;
										}
										futures.add(p.ensureThreadLoaded());
									}
									if (futures.isNotEmpty) {
										await Future.wait(futures);
									}
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
									final openInNewTabZone = context.read<OpenInNewTabZone?>();
									return ContextMenu(
										maxHeight: 125,
										actions: [
											if (openInNewTabZone != null) ContextMenuAction(
												child: const Text('Open in new tab'),
												trailingIcon: CupertinoIcons.rectangle_stack_badge_plus,
												onPressed: () {
													openInNewTabZone.onWantOpenThreadInNewTab(state.imageboardKey, state.identifier);
												}
											),
											ContextMenuAction(
												child: const Text('Hide'),
												onPressed: () async {
													state.showInHistory = false;
													await state.save();
													_listController.update();
												},
												trailingIcon: CupertinoIcons.eye_slash,
												isDestructiveAction: true
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
																heroOtherEndIsBoxFitCover: context.read<EffectiveSettings>().squareThumbnails
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
					detailBuilder: (selectedThread, setter, poppedOut) {
						return BuiltDetailPane(
							widget: selectedThread != null ? ImageboardScope(
								imageboardKey: selectedThread.imageboard.key,
								child: ThreadPage(
									thread: selectedThread.item.thread,
									initialPostId: selectedThread.item.postId,
									boardSemanticId: -3
								)
							) : const AdaptiveScaffold(
								body: Center(
									child: Text('Select a thread')
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