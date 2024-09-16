import 'package:chan/main.dart';
import 'package:chan/models/post.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/history_search.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/util.dart';
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

class HistoryPage extends StatefulWidget {
	const HistoryPage({
		Key? key
	}) : super(key: key);

	@override
	createState() => HistoryPageState();
}

const _historyPageSize = 35;

class HistoryPageState extends State<HistoryPage> {
	final masterDetailKey = GlobalKey<MultiMasterDetailPage1State<ImageboardScoped<PostIdentifier>>>();
	late final RefreshableListController<PersistentThreadState> _listController;
	late final ValueNotifier<ImageboardScoped<PostIdentifier>?> _valueInjector;
	List<PersistentThreadState> states = [];

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
							masterDetailKey.currentState!.setValue(result);
						}
					);
				}
			),
			settings: dontAutoPopSettings
		));
	}

	Future<void> updateList() => _listController.update();

	Future<List<PersistentThreadState>> _load(int startIndex) async {
		if (startIndex < 0) {
			return [];
		}
		final futures = <Future<void>>[];
		final out = <PersistentThreadState>[];
		for (int i = startIndex; i < states.length && out.length < _historyPageSize; i++) {
			final p = states[i];
			if (p.thread?.posts_.last.isInitialized ?? false) {
				out.add(p);
			}
			else if (p.isThreadCached) {
				out.add(p);
				futures.add(p.ensureThreadLoaded());
			}
		}
		await Future.wait(futures);
		return out.where((s) => s.thread != null).toList();
	}

	@override
	Widget build(BuildContext context) {
		return MultiMasterDetailPage1(
			showChrome: false,
			id: 'history',
			key: masterDetailKey,
			paneCreator: () =>
				MultiMasterPane<ImageboardScoped<PostIdentifier>>(
					masterBuilder: (context, selectedThread, threadSetter) {
						final settings = context.watch<Settings>();
						return AdaptiveScaffold(
							resizeToAvoidBottomInset: false,
							bar: AdaptiveBar(
								title: const Text('History'),
								actions: [
									AdaptiveIconButton(
										onPressed: () async {
											final toDelete = await showAdaptiveDialog<List<PersistentThreadState>>(
												context: context,
												barrierDismissible: true,
												builder: (context) => StatefulBuilder(
													builder: (context, setDialogState) {
														final openTabThreadBoxKeys = Persistence.tabs.map((t) => '${t.imageboardKey}/${t.thread?.board}/${t.thread?.id}').toSet();
														final states = Persistence.sharedThreadStateBox.values.where((i) => i.savedTime == null && i.threadWatch == null && (settings.includeThreadsYouRepliedToWhenDeletingHistory || i.youIds.isEmpty) && !openTabThreadBoxKeys.contains(i.boxKey)).toList();
														final thisSessionStates = states.where((s) => s.lastOpenedTime.compareTo(Persistence.appLaunchTime) >= 0).toList();
														final now = DateTime.now();
														final lastDayStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 1).toList();
														final lastWeekStates = states.where((s) => now.difference(s.lastOpenedTime).inDays < 7).toList();
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
																						Settings.includeThreadsYouRepliedToWhenDeletingHistorySetting.value = v;
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
																		Navigator.pop(context, thisSessionStates);
																	},
																	isDestructiveAction: true,
																	child: Text('This session (${thisSessionStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context, lastDayStates);
																	},
																	isDestructiveAction: true,
																	child: Text('Today (${lastDayStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context, lastWeekStates);
																	},
																	isDestructiveAction: true,
																	child: Text('This week (${lastWeekStates.length})')
																),
																AdaptiveDialogAction(
																	onPressed: () async {
																		Navigator.pop(context, states);
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
											if (toDelete != null) {
												final watches = <ImageboardScoped<ThreadWatch>>[];
												for (final state in toDelete) {
													final watch = state.threadWatch;
													final imageboard = state.imageboard;
													if (watch != null && imageboard != null) {
														watches.add(imageboard.scope(watch));
													}
													await state.delete();
												}
												if (context.mounted) {
													showUndoToast(
														context: context,
														message: 'Deleted ${describeCount(toDelete.length, 'thread')}',
														onUndo: () async {
															for (final state in toDelete) {
																await Persistence.sharedThreadStateBox.put(state.boxKey, state);
															}
															for (final watch in watches) {
																await watch.imageboard.notifications.insertWatch(watch.item);
															}
														}
													);
												}
											}
										},
										icon: const Icon(CupertinoIcons.delete)
									),
									Builder(
										builder: (context) => AdaptiveIconButton(
											icon: Icon(Settings.recordThreadsInHistorySetting.watch(context) ? CupertinoIcons.stop : CupertinoIcons.play),
											onPressed: () {
												Settings.recordThreadsInHistorySetting.value = !Settings.instance.recordThreadsInHistory;
												threadSetter(context.read<MasterDetailHint>().currentValue);
												showToast(
													context: context,
													message: Settings.instance.recordThreadsInHistory ? 'History resumed' : 'History stopped',
													icon: Settings.instance.recordThreadsInHistory ? CupertinoIcons.play : CupertinoIcons.stop
												);
											}
										)
									)
								]
							),
							body: RefreshableList<PersistentThreadState>(
								useFiltersFromContext: false,
								filterableAdapter: (t) => t,
								filterAlternative: FilterAlternative(
									name: 'full history',
									suggestWhenFilterEmpty: true,
									handler: _onFullHistorySearch
								),
								controller: _listController,
								autoExtendDuringScroll: true,
								updateAnimation: Persistence.sharedThreadStateBox.listenable(),
								disableUpdates: !TickerMode.of(context),
								listUpdater: (options) async {
									states = Persistence.sharedThreadStateBox.values.where((s) => s.imageboard != null && s.showInHistory).toList();
									states.sort((a, b) => b.lastOpenedTime.compareTo(a.lastOpenedTime));
									return _load(0);
								},
								listExtender: (after) async {
									return _load(states.indexOf(after));
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
													if (context.mounted) {
														showUndoToast(
															context: context,
															message: 'Thread hidden',
															onUndo: () async {
																state.showInHistory = true;
																await state.save();
																_listController.update();
															}
														);
													}
												},
												trailingIcon: CupertinoIcons.eye_slash,
												isDestructiveAction: true
											),
											ContextMenuAction(
												child: const Text('Remove'),
												onPressed: () async {
													final watch = state.threadWatch;
													if (watch != null) {
														await state.imageboard?.notifications.removeWatch(watch);
													}
													await state.delete();
													_listController.update();
													if (context.mounted) {
														showUndoToast(
															context: context,
															message: 'Removed thread',
															onUndo: () async {
																await Persistence.sharedThreadStateBox.put(state.boxKey, state);
																if (watch != null) {
																	await state.imageboard?.notifications.insertWatch(watch);
																}
																_listController.update();
															}
														);
													}
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
																heroOtherEndIsBoxFitCover: Settings.instance.squareThumbnails
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
						WidgetsBinding.instance.addPostFrameCallback((_){
							_valueInjector.value = selectedThread;
						});
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
		);
	}

	@override
	void dispose() {
		super.dispose();
		_listController.dispose();
	}
}