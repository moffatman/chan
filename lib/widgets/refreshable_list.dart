import 'dart:async';
import 'dart:math';

import 'package:chan/services/filtering.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

const double _overscrollTriggerThreshold = 100;

class FilterAlternative {
	final String name;
	final void Function(String) handler;

	const FilterAlternative({
		required this.name,
		required this.handler
	});
}

class RefreshableList<T> extends StatefulWidget {
	final Widget Function(BuildContext context, T value) itemBuilder;
	final List<T>? initialList;
	final Future<List<T>?> Function() listUpdater;
	final String id;
	final RefreshableListController? controller;
	final String? filterHint;
	final Widget Function(BuildContext context, T value, VoidCallback resetPage, String filter)? filteredItemBuilder;
	final Duration? autoUpdateDuration;
	final Map<Type, Widget Function(BuildContext, VoidCallback)> remedies;
	final bool disableUpdates;
	final Widget? footer;
	final Size? gridSize;
	final String? initialFilter;
	final bool allowReordering;
	final ValueChanged<T>? onWantAutosave;
	final Filterable Function(T)? filterableAdapter;
	final FilterAlternative? filterAlternative;

	const RefreshableList({
		required this.itemBuilder,
		required this.listUpdater,
		required this.id,
		this.controller,
		this.filterHint,
		this.filteredItemBuilder,
		this.autoUpdateDuration,
		this.remedies = const {},
		this.initialList,
		this.disableUpdates = false,
		this.gridSize,
		this.footer,
		this.initialFilter,
		this.allowReordering = false,
		this.onWantAutosave,
		required this.filterableAdapter,
		this.filterAlternative,
		Key? key
	}) : super(key: key);

	@override
	createState() => RefreshableListState<T>();
}

class RefreshableListState<T> extends State<RefreshableList<T>> with TickerProviderStateMixin {
	List<T>? list;
	String? errorMessage;
	Type? errorType;
	SearchFilter? _searchFilter;
	bool updatingNow = false;
	final _searchController = TextEditingController();
	final _searchFocusNode = FocusNode();
	DateTime? lastUpdateTime;
	DateTime? nextUpdateTime;
	Timer? autoUpdateTimer;
	GlobalKey _scrollViewKey = GlobalKey();
	GlobalKey _sliverListKey = GlobalKey();
	int _pointerDownCount = 0;
	bool _showFilteredValues = false;
	bool _searchTapped = false;
	bool _overscrollEndingNow = false;
	late final AnimationController _footerShakeAnimation;
	List<T> _listAfterFiltering = [];

	@override
	void initState() {
		super.initState();
		 _footerShakeAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
		if (widget.initialFilter != null) {
			_searchFilter = SearchFilter(widget.initialFilter!);
			_searchTapped = true;
			_searchController.text = widget.initialFilter!;
		}
		widget.controller?.attach(this);
		widget.controller?.newContentId(widget.id);
		list = widget.initialList;
		if (!widget.disableUpdates) {
			update();
			resetTimer();
		}
	}

	@override
	void didUpdateWidget(RefreshableList<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			widget.controller?.newContentId(widget.id);
			_scrollViewKey = GlobalKey();
			_sliverListKey = GlobalKey();
			_closeSearch();
			list = widget.initialList;
			errorMessage = null;
			errorType = null;
			lastUpdateTime = null;
			update();
		}
		else if (oldWidget.disableUpdates != widget.disableUpdates) {
			autoUpdateTimer?.cancel();
			autoUpdateTimer = null;
			if (!widget.disableUpdates) {
				update();
				resetTimer();
			}
		}
		else if (widget.disableUpdates && !listEquals(oldWidget.initialList, widget.initialList)) {
			list = widget.initialList;
		}
	}

	@override
	void dispose() {
		super.dispose();
		autoUpdateTimer?.cancel();
	}

	void resetTimer() {
		autoUpdateTimer?.cancel();
		if (widget.autoUpdateDuration != null) {
			autoUpdateTimer = Timer(widget.autoUpdateDuration!, update);
			nextUpdateTime = DateTime.now().add(widget.autoUpdateDuration!);
		}
	}

	void _closeSearch() {
		_searchFocusNode.unfocus();
		_searchController.clear();
		setState(() {
			_searchTapped = false;
			_searchFilter = null;
		});
	}

	void _focusSearch() {
		_searchFocusNode.requestFocus();
		_searchTapped = true;
		setState(() {});
	}

	Future<void> update() async {
		if (updatingNow) {
			return;
		}
		List<T>? newList;
		try {
			setState(() {
				errorMessage = null;
				errorType = null;
				updatingNow = true;
			});
			Duration minUpdateDuration = const Duration(milliseconds: 500);
			if (widget.controller?.scrollController?.positions.length == 1 && (widget.controller!.scrollController!.position.pixels > 0 && (widget.controller!.scrollController!.position.pixels <= widget.controller!.scrollController!.position.maxScrollExtent))) {
				minUpdateDuration = const Duration(seconds: 1);
			}
			newList = (await Future.wait([widget.listUpdater(), Future<List<T>?>.delayed(minUpdateDuration)])).first;
			resetTimer();
			lastUpdateTime = DateTime.now();
		}
		catch (e, st) {
			errorMessage = e.toStringDio();
			errorType = e.runtimeType;
			if (mounted) {
				if (widget.remedies[errorType] == null) {
					print('Error refreshing list: $e');
					print(st);
					resetTimer();
				}
				else {
					nextUpdateTime = null;
				}
			}
		}
		if (widget.controller?.scrollController?.positions.length == 1 && widget.controller?.scrollController?.position.isScrollingNotifier.value == true) {
			final completer = Completer<void>();
			void listener() {
				if (widget.controller!.scrollController!.position.isScrollingNotifier.value == false) {
					completer.complete();
				}
			}
			widget.controller!.scrollController!.position.isScrollingNotifier.addListener(listener);
			await Future.any([completer.future, Future.delayed(const Duration(seconds: 3))]);
			widget.controller?.scrollController?.position.isScrollingNotifier.removeListener(listener);
		}
		updatingNow = false;
		if (mounted && newList != null) {
			setState(() {
				list = newList;
			});
		}
	}

	Widget _itemBuilder(BuildContext context, T value, {bool highlighted = false}) {
		Widget child;
		if (_searchFilter != null && widget.filteredItemBuilder!= null) {
			child = widget.filteredItemBuilder!(context, value, _closeSearch, _searchFilter!.text);
		}
		else {
			child = widget.itemBuilder(context, value);
		}
		if (highlighted) {
			return ColorFiltered(
				colorFilter: ColorFilter.mode(CupertinoTheme.of(context).textTheme.actionTextStyle.color?.withOpacity(0.2) ?? Colors.white.withOpacity(0.2), BlendMode.srcOver),
				child: child
			);
		}
		return child;
	}

	@override
	Widget build(BuildContext context) {
		widget.controller?.reportPrimaryScrollController(PrimaryScrollController.of(context));
		widget.controller?.topOffset = MediaQuery.of(context).padding.top;
		widget.controller?.bottomOffset = MediaQuery.of(context).padding.bottom;
		if (list != null) {
			final pinnedValues = <T>[];
			final values = <Tuple2<T, bool>>[];
			final filteredValues = <Tuple2<T, String>>[];
			final filters = [
				Filter.of(context),
				if (_searchFilter != null) _searchFilter!
			];
			for (final item in list!) {
				bool handled = false;
				for (final filter in filters) {
					final result = widget.filterableAdapter != null ? filter.filter(widget.filterableAdapter!(item)) : null;
					if (result != null) {
						switch (result.type) {
							case FilterResultType.hide:
								filteredValues.add(Tuple2(item, result.reason));
								break;
							case FilterResultType.highlight:
								values.add(Tuple2(item, true));
								break;
							case FilterResultType.pinToTop:
								if (widget.allowReordering) {
									pinnedValues.add(item);
								}
								else {
									values.add(Tuple2(item, true));
								}
								break;
							case FilterResultType.autoSave:
								widget.onWantAutosave?.call(item);
								values.add(Tuple2(item, true));
						}
						handled = true;
						break;
					}
				}
				if (!handled) {
					values.add(Tuple2(item, false));
				}
			}
			values.insertAll(0, pinnedValues.map((x) => Tuple2(x, true)));
			final newList = values.map((x) => x.item1).toList();
			if (!listEquals(newList, _listAfterFiltering)) {
				_listAfterFiltering = newList;
				widget.controller?.setItems(newList);
			}
			if (filteredValues.isEmpty) {
				// Don't auto open filtered values after clearing it before
				_showFilteredValues = false;
			}
			final shakeAnimation = CurvedAnimation(
				curve: Curves.easeInOutCubic,
				parent: _footerShakeAnimation
			);
			return NotificationListener<ScrollNotification>(
				key: ValueKey(widget.id),
				onNotification: (notification) {
					final bool isScrollEnd = (notification is ScrollEndNotification) || (notification is ScrollUpdateNotification && notification.dragDetails == null);
					if (widget.controller != null && isScrollEnd) {
						if (!_overscrollEndingNow) {
							double overscroll = widget.controller!.scrollController!.position.pixels - widget.controller!.scrollController!.position.maxScrollExtent;
							if (overscroll > _overscrollTriggerThreshold && !widget.disableUpdates) {
								_overscrollEndingNow = true;
								update();
							}
						}
					}
					else {
						_overscrollEndingNow = false;
					}
					return false;
					// Auto update here
				},
				child: Listener(
					onPointerDown:(e) {
						_pointerDownCount++;
					},
					onPointerUp: (e) {
						_pointerDownCount--;
					},
					onPointerCancel: (e) {
						_pointerDownCount--;
					},
					onPointerPanZoomStart: (e) {
						_pointerDownCount++;
					},
					onPointerPanZoomEnd: (e) {
						_pointerDownCount--;
					},
					child: GestureDetector(
						onTap: () {
							if (widget.controller?.scrollController != null && (widget.controller!.scrollController!.position.userScrollDirection != ScrollDirection.idle) && _pointerDownCount == 0) {
								widget.controller!.scrollController!.jumpTo(widget.controller!.scrollController!.position.pixels);
							}
							widget.controller?.cancelCurrentAnimation();
						},
						child: MaybeCupertinoScrollbar(
							controller: widget.controller?.scrollController,
							child: CustomScrollView(
								key: _scrollViewKey,
								cacheExtent: 1000,
								controller: widget.controller?.scrollController,
								physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
								slivers: [
									SliverSafeArea(
										sliver: widget.disableUpdates ? SliverToBoxAdapter(
											child: Container()
										) : CupertinoSliverRefreshControl(
											onRefresh: update,
											refreshTriggerPullDistance: 125
										),
										bottom: false
									),
									if ((list?.isNotEmpty ?? false) && widget.filterableAdapter != null) SliverToBoxAdapter(
										child: Container(
											height: kMinInteractiveDimensionCupertino * context.select<EffectiveSettings, double>((s) => s.textScale),
											padding: const EdgeInsets.all(4),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Expanded(
														child: Center(
															child: CupertinoSearchTextField(
																prefixIcon: const Padding(
																	padding: EdgeInsets.only(top: 2),
																	child: Icon(CupertinoIcons.search)
																),
																onTap: () {
																	setState(() {
																		_searchTapped = true;
																	});
																},
																onChanged: (searchText) {
																	setState(() {
																		_searchFilter = SearchFilter(searchText.toLowerCase());
																	});
																},
																controller: _searchController,
																focusNode: _searchFocusNode,
																placeholder: widget.filterHint,
																smartQuotesType: SmartQuotesType.disabled,
																smartDashesType: SmartDashesType.disabled
															)
														),
													),
													if (_searchTapped) CupertinoButton(
														padding: const EdgeInsets.only(left: 8),
														onPressed: _closeSearch,
														child: const Text('Cancel')
													)
												]
											)
										)
									),
									if (filteredValues.isNotEmpty && widget.filterAlternative != null) SliverToBoxAdapter(
										child: Container(
											decoration: BoxDecoration(
												border: Border(
													top: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)),
													bottom: BorderSide(color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2))
												)
											),
											child: CupertinoButton(
												padding: const EdgeInsets.all(16),
												onPressed: () => widget.filterAlternative!.handler(_searchFilter!.text),
												child: Row(
													children: [
														const Icon(CupertinoIcons.search),
														const SizedBox(width: 8),
														Text('Search ${widget.filterAlternative?.name}')
													]
												)
											)
										)
									),
									if (values.isNotEmpty)
										if (widget.gridSize != null) SliverGrid(
											key: PageStorageKey('grid for ${widget.id}'),
											gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
												maxCrossAxisExtent: widget.gridSize!.width,
												childAspectRatio: widget.gridSize!.aspectRatio
											),
											delegate: SliverChildBuilderDelegate(
												(context, i) => Builder(
													builder: (context) {
														widget.controller?.registerItem(i, values[i].item1, context);
														return _itemBuilder(context, values[i].item1, highlighted: values[i].item2);
													}
												),
												childCount: values.length
											)
										)
										else SliverList(
											key: _sliverListKey,
											delegate: SliverChildBuilderDelegate(
												(context, i) {
													if (i % 2 == 0) {
														return Builder(
															builder: (context) {
																widget.controller?.registerItem(i ~/ 2, values[i ~/ 2].item1, context);
																return _itemBuilder(context, values[i ~/ 2].item1, highlighted: values[i ~/ 2].item2);
															}
														);
													}
													else {
														return Divider(
															thickness: 1,
															height: 0,
															color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
														);
													}
												},
												childCount: values.length * 2
											)
										),
									if (values.isEmpty)
										const SliverToBoxAdapter(
												child: SizedBox(
													height: 100,
													child: Center(
														child: Text('Nothing to see here')
													)
												)
											),
									if (filteredValues.isNotEmpty) ...[
										SliverToBoxAdapter(
											child: GestureDetector(
												onTap: () {
													setState(() {
														_showFilteredValues = !_showFilteredValues;
													});
												},
												child: SizedBox(
													height: 50,
													child: Center(
														child: Text(
															(_showFilteredValues ? 'Showing ' : '') + describeCount(filteredValues.length, 'filtered item'),
															style: TextStyle(
																color: CupertinoTheme.of(context).primaryColorWithBrightness(0.4)
															)
														)
													)
												)
											),
										),
										if (_showFilteredValues) SliverList(
											key: PageStorageKey('filtered list for ${widget.id}'),
											delegate: SliverChildBuilderDelegate(
												(context, i) {
													if (i % 2 == 0) {
														return Stack(
															children: [
																_itemBuilder(context, filteredValues[i ~/ 2].item1),
																IgnorePointer(
																	child: Align(
																		alignment: Alignment.topRight,
																		child: Container(
																			padding: const EdgeInsets.all(4),
																			color: CupertinoTheme.of(context).primaryColor,
																			child: Text('Filter reason:\n${filteredValues[i ~/ 2].item2}', style: TextStyle(
																				color: CupertinoTheme.of(context).scaffoldBackgroundColor
																			))
																		)
																	)
																)
															]
														);
													}
													else {
														return Divider(
															thickness: 1,
															height: 0,
															color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
														);
													}
												},
												childCount: filteredValues.length * 2
											)
										)
									],
									if (widget.footer != null && widget.disableUpdates) SliverSafeArea(
										top: false,
										sliver: SliverToBoxAdapter(
											child: widget.footer
										)
									)
									else if (widget.footer != null && !widget.disableUpdates) SliverToBoxAdapter(
										child: RepaintBoundary(
											child: GestureDetector(
												behavior: HitTestBehavior.opaque,
												onTap: updatingNow ? null : () {
													Future.delayed(const Duration(milliseconds: 17), () {
														widget.controller?.scrollController?.animateTo(
															widget.controller!.scrollController!.position.maxScrollExtent,
															duration: const Duration(milliseconds: 250),
															curve: Curves.ease
														);
													});
													_footerShakeAnimation.forward(from: 0);
													update();
												},
												child: AnimatedBuilder(
													animation: shakeAnimation,
													builder: (context, child) => Transform.scale(
														scale: 1.0 - 0.2*sin(pi * shakeAnimation.value),
														child: child
													),
													child: widget.footer
												)
											)
										)
									)
									else if (widget.disableUpdates) SliverSafeArea(
										top: false,
										sliver: SliverToBoxAdapter(
											child: Container()
										)
									),
									if (!widget.disableUpdates) SliverSafeArea(
										top: false,
										sliver: SliverToBoxAdapter(
											child: RepaintBoundary(
												child: RefreshableListFooter(
													updater: update,
													updatingNow: updatingNow,
													lastUpdateTime: lastUpdateTime,
													nextUpdateTime: nextUpdateTime,
													errorMessage: errorMessage,
													remedy: widget.remedies[errorType]?.call(context, update),
													overscrollFactor: widget.controller?.overscrollFactor,
													pointerDownNow: () {
														return _pointerDownCount > 0;
													}
												)
											)
										)
									)
								]
							)
						)
					)
				)
			);
		}
		else if (errorMessage != null) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						ErrorMessageCard('Error loading ${widget.id}:\n${errorMessage?.toStringDio()}'),
						CupertinoButton(
							onPressed: update,
							child: const Text('Retry')
						),
						if (widget.remedies[errorType] != null) widget.remedies[errorType]!(context, update)
					]
				)
			);
		}
		else {
			return const Center(
				child: CupertinoActivityIndicator()
			);
		}
	}
}

class RefreshableListFooter extends StatelessWidget {
	final String? errorMessage;
	final VoidCallback updater;
	final bool updatingNow;
	final DateTime? lastUpdateTime;
	final DateTime? nextUpdateTime;
	final Widget? remedy;
	final ValueListenable<double>? overscrollFactor;
	final bool Function() pointerDownNow;
	const RefreshableListFooter({
		required this.updater,
		required this.updatingNow,
		this.lastUpdateTime,
		this.nextUpdateTime,
		this.errorMessage,
		this.remedy,
		this.overscrollFactor,
		required this.pointerDownNow,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			onTap: updatingNow ? null : updater,
			child: Container(
				color: errorMessage != null ? Colors.orange.withOpacity(0.5) : null,
				padding: const EdgeInsets.all(1),
				child: Center(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (errorMessage != null) ...[
								const SizedBox(height: 16),
								Text(
									errorMessage!,
									textAlign: TextAlign.center
								),
								const SizedBox(height: 16)
							],
							if (!updatingNow && remedy != null) ...[
								remedy!,
								const SizedBox(height: 16)
							],
							if (overscrollFactor != null) SizedBox(
								height: updatingNow ? 64 : 0,
								child: OverflowBox(
									maxHeight: 100,
									alignment: Alignment.topCenter,
									child: ValueListenableBuilder(
										valueListenable: overscrollFactor!,
										builder: (context, double value, child) => TweenAnimationBuilder(
											tween: Tween<double>(begin: 0, end: value),
											duration: const Duration(milliseconds: 50),
											curve: Curves.ease,
											builder: (context, double smoothedValue, child) => Stack(
												alignment: Alignment.topCenter,
												clipBehavior: Clip.none,
												children: [
													Positioned(
														top: 0,
														child: Container(
															padding: const EdgeInsets.only(top: 32),
															constraints: const BoxConstraints(
																maxWidth: 100
															),
															child: ClipRRect(
																borderRadius: const BorderRadius.all(Radius.circular(8)),
																child: Stack(
																	children: [
																		if (nextUpdateTime != null && lastUpdateTime != null) TimedRebuilder(
																			enabled: true,
																			interval: const Duration(seconds: 1),
																			builder: (context) {
																				final now = DateTime.now();
																				return LinearProgressIndicator(
																					value: updatingNow ? 0 : now.difference(lastUpdateTime!).inSeconds / nextUpdateTime!.difference(lastUpdateTime!).inSeconds,
																					color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5),
																					backgroundColor: CupertinoTheme.of(context).primaryColorWithBrightness(0.2),
																					minHeight: 8
																				);
																			}
																		),
																		LinearProgressIndicator(
																			value: (updatingNow) ? null : (pointerDownNow() ? smoothedValue : 0),
																			backgroundColor: Colors.transparent,
																			color: CupertinoTheme.of(context).primaryColor,
																			minHeight: 8
																		)
																	]
																)
															)
														)
													)
												]
											)
										)
									)
								)
							)
						]
					)
				)
			)
		);
	}
}

class _RefreshableListItem<T> {
	BuildContext? context;
	T item;
	double? cachedOffset;
	double? cachedHeight;
	bool get hasGoodState {
		try {
			return (context?.findRenderObject()?.attached ?? false) && ((context?.findRenderObject() as RenderBox).hasSize);
		}
		on FlutterError {
			return false;
		}
	}
	_RefreshableListItem(this.item);

	@override
	bool operator == (dynamic o) => (o is _RefreshableListItem<T>) && o.item == item;

	@override
	int get hashCode => item.hashCode;

	@override
	String toString() => '_RefreshableListItem(item: $item, cachedOffset: $cachedOffset, cachedHeight: $cachedHeight)';
}
class RefreshableListController<T> {
	List<_RefreshableListItem<T>> _items = [];
	Iterable<T> get items => _items.map((i) => i.item);
	ScrollController? scrollController;
	final overscrollFactor = ValueNotifier<double>(0);
	final BehaviorSubject<void> _scrollStream = BehaviorSubject();
	final BehaviorSubject<void> slowScrollUpdates = BehaviorSubject();
	late final StreamSubscription<List<void>> _slowScrollSubscription;
	double? topOffset;
	double? bottomOffset;
	String? contentId;
	RefreshableListState<T>? state;
	final Map<Tuple2<int, bool>, Completer<void>> _itemCacheCallbacks = {};
	int? currentTargetIndex;
	RefreshableListController() {
		_slowScrollSubscription = _scrollStream.bufferTime(const Duration(milliseconds: 100)).where((batch) => batch.isNotEmpty).listen(_onSlowScroll);
		SchedulerBinding.instance.endOfFrame.then((_) => _onScrollControllerNotification());
	}
	Future<void> _tryCachingItem(int index, _RefreshableListItem<T> item) async {
		await SchedulerBinding.instance.endOfFrame;
		if (item.hasGoodState) {
			// ignore: use_build_context_synchronously
			final RenderObject object = item.context!.findRenderObject()!;
			item.cachedHeight = object.semanticBounds.height;
			final newOffset = _getOffset(object);
			if (item.cachedOffset != null && item.cachedOffset != newOffset) {
				for (final item in _items.skip(index + 1)) {
					item.cachedOffset = null;
				}
			}
			item.cachedOffset = newOffset;
			final keys = _itemCacheCallbacks.keys.toList();
			for (final position in keys) {
				if (position.item2 && index >= position.item1) {
					// scrolling down
					_itemCacheCallbacks[position]?.complete();
					_itemCacheCallbacks.remove(position);
				}
				else if (!position.item2 && index <= position.item1) {
					// scrolling up
					_itemCacheCallbacks[position]?.complete();
					_itemCacheCallbacks.remove(position);
				}
			}
		}
	}
	void _onSlowScroll(void update) {
		int lastCached = -1;
		for (final entry in _items.asMap().entries) {
			if (entry.value.cachedOffset != null) {
				lastCached = entry.key;
			}
		}
		lastCached++; // Cache the final item if uncached
		for (int i = 0; i < lastCached; i++) {
			if (_items[i].cachedOffset == null) {
				_tryCachingItem(i, _items[i]);
			}
		}
		slowScrollUpdates.add(null);
	}
	void _onScrollControllerNotification() {
		_scrollStream.add(null);
		if ((scrollController?.hasClients ?? false)) {
			final overscrollAmount = scrollController!.position.pixels - scrollController!.position.maxScrollExtent;
			overscrollFactor.value = (overscrollAmount / _overscrollTriggerThreshold).clamp(0, 1);
		}
	}
	void attach(RefreshableListState<T> list) {
		state = list;
	}
	void focusSearch() {
		state?._focusSearch();
	}
	void reportPrimaryScrollController(ScrollController? controller) {
		if (scrollController != controller) {
			scrollController?.removeListener(_onScrollControllerNotification);
			scrollController = controller;
			scrollController!.addListener(_onScrollControllerNotification);
		}
	}
	void dispose() {
		_scrollStream.close();
		_slowScrollSubscription.cancel();
		scrollController?.removeListener(_onScrollControllerNotification);
		slowScrollUpdates.close();
		overscrollFactor.dispose();
	}
	void newContentId(String contentId) {
		this.contentId = contentId;
		_items = [];
		for (final cb in _itemCacheCallbacks.values) {
			cb.completeError(Exception('page changed'));
		}
		_itemCacheCallbacks.clear();
	}
	void setItems(List<T> items) {
		if (items.isNotEmpty && _items.isNotEmpty && items.first == _items.first.item) {
			if (items.length < _items.length) {
				_items = _items.sublist(0, items.length);
			}
			for (int i = 0; i < items.length; i++) {
				if (i < _items.length) {
					_items[i].item = items[i];
				}
				else {
					_items.add(_RefreshableListItem(items[i]));
				}
			}
		}
		else {
			_items = items.map((item) => _RefreshableListItem(item)).toList();
		}
	}
	void registerItem(int index, T item, BuildContext context) {
		if (index < _items.length) {
			_items[index].item = item;
			_items[index].context = context;
			_tryCachingItem(index, _items[index]);
		}
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object)!.getOffsetToReveal(object, 0.0).offset;
	}
	double? _estimateOffset(int targetIndex) {
		final heightedItems = _items.map((i) => i.cachedHeight).where((i) => i != null);
		if (heightedItems.length < 2) return null;
		final averageItemHeight = heightedItems.reduce((a, b) => a! + b!)! / heightedItems.length;
		int nearestDistance = _items.length + 1;
		double? estimate;
		for (int i = 0; i < _items.length; i++) {
			if (_items[i].cachedOffset != null) {
				final distance = (targetIndex - i).abs();
				if (distance < nearestDistance) {
					estimate = _items[i].cachedOffset! + (averageItemHeight * (targetIndex - i));
					nearestDistance = distance;
				}
			}
		}
		return estimate;
	}
	Future<void> animateTo(bool Function(T val) f, {double alignment = 0.0, bool Function(T val)? orElseLast, Duration duration = const Duration(milliseconds: 200)}) async {
		final start = DateTime.now();
		int targetIndex = _items.indexWhere((i) => f(i.item));
		if (targetIndex == -1) {
			if (orElseLast != null) {
				targetIndex = _items.lastIndexWhere((i) => orElseLast(i.item));
			}
			if (targetIndex == -1) {
				throw StateError('No matching item to scroll to');
			}
		}
		print('$contentId animating to $targetIndex');
		currentTargetIndex = targetIndex;
		Duration d = duration;
		Curve c = Curves.easeIn;
		final initialContentId = contentId;
		Future<bool> attemptResolve() async {
			final completer = Completer<void>();
			double estimate = (_estimateOffset(targetIndex) ?? scrollController!.position.maxScrollExtent) - topOffset!;
			_itemCacheCallbacks[Tuple2(targetIndex, estimate > scrollController!.position.pixels)] = completer;
			final delay = Duration(milliseconds: min(300, max(1, (estimate - scrollController!.position.pixels).abs() ~/ 100)));
			scrollController!.animateTo(
				estimate,
				duration: delay,
				curve: c
			);
			await Future.any([completer.future, Future.wait([Future.delayed(const Duration(milliseconds: 32)), Future.delayed(delay ~/ 4)])]);
			return (_items[targetIndex].cachedOffset != null);
		}
		bool usingKnownGoodValue = true;
		if (_items[targetIndex].cachedOffset == null) {
			usingKnownGoodValue = false;
			while (contentId == initialContentId && !(await attemptResolve()) && DateTime.now().difference(start).inSeconds < 5 && targetIndex == currentTargetIndex) {
				c = Curves.linear;
			}
			if (initialContentId != contentId) throw Exception('List was hijacked ($initialContentId -> $contentId)');
			if (currentTargetIndex != targetIndex) throw Exception('animateTo was hijacked ($targetIndex -> $currentTargetIndex)');
			Duration timeLeft = duration - DateTime.now().difference(start);
			if (timeLeft.inMilliseconds.isNegative) {
				d = duration ~/ 4;
			}
			else {
				d = Duration(milliseconds: min(timeLeft.inMilliseconds, duration.inMilliseconds ~/ 4));
			}
		}
		if (_items[targetIndex].cachedOffset == null) {
			throw Exception('Scrolling timed out');
		}
		double atAlignment0 = _items[targetIndex].cachedOffset! - topOffset!;
		final alignmentSlidingWindow = scrollController!.position.viewportDimension - _items[targetIndex].cachedHeight! - topOffset! - bottomOffset!;
		if (_items[targetIndex] == _items.last) {
			// add offset to reveal the full footer
			atAlignment0 += 110;
		}
		else {
			atAlignment0 += 1;
		}
		double finalDestination = (atAlignment0 - (alignmentSlidingWindow * alignment));
		if (!usingKnownGoodValue) {
			finalDestination = finalDestination.clamp(0, scrollController!.position.maxScrollExtent);
		}
		await scrollController!.animateTo(
			max(0, finalDestination),
			duration: Duration(milliseconds: max(1, d.inMilliseconds)),
			curve: Curves.easeOut
		);
		await SchedulerBinding.instance.endOfFrame;
	}
	void cancelCurrentAnimation() {
		currentTargetIndex = null;
	}
	int get firstVisibleIndex {
		if (scrollController?.hasOnePosition ?? false) {
			return _items.indexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! > scrollController!.position.pixels));
		}
		return -1;
	}
	T? get firstVisibleItem {
		final index = firstVisibleIndex;
		return index < 0 ? null : _items[index].item;
	}
	T? get middleVisibleItem {
		if (scrollController?.hasOnePosition ?? false) {
			int index = _items.indexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! > (scrollController!.position.pixels + (scrollController!.position.viewportDimension / 2))));
			if (index != -1) {
				if (index > 0) {
					// It will be one too far, we want the item which covers the middle pixel row
					index--;
				}
				return _items[index].item;
			}
		}
		return null;
	}
	T? get lastVisibleItem {
		if (scrollController?.hasOnePosition ?? false) {
			if (_items.isNotEmpty &&
					_items.first.cachedHeight != null &&
					_items.first.cachedHeight! > scrollController!.position.pixels &&
					_items.first.cachedHeight! > scrollController!.position.viewportDimension) {
				return _items.first.item;
			}
			return _items.tryLastWhere((i) {
				return (i.cachedOffset != null) &&
							 ((i.cachedOffset! + i.cachedHeight!) < (scrollController!.position.pixels + scrollController!.position.viewportDimension));
			})?.item;
		}
		return null;
	}
	Future<void> blockAndUpdate() async {
		state?.list = null;
		setItems([]);
		await state?.update();
		slowScrollUpdates.add(null);
	}
	Future<void> update() async {
		await state?.update();
	}
}

extension HasOnePosition on ScrollController {
	// ignore: INVALID_USE_OF_PROTECTED_MEMBER
	bool get hasOnePosition => positions.length == 1;
}