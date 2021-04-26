import 'dart:async';
import 'dart:math';

import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:rxdart/rxdart.dart';

abstract class Filterable {
	List<String> getSearchableText();
}

class RefreshableList<T extends Filterable> extends StatefulWidget {
	final Widget Function(BuildContext context, T value) itemBuilder;
	final List<T>? initialList;
	final Future<List<T>> Function() listUpdater;
	final String id;
	final RefreshableListController? controller;
	final String? filterHint;
	final Widget Function(BuildContext context, T value, VoidCallback resetPage)? filteredItemBuilder;
	final Duration? autoUpdateDuration;
	final Map<Type, Widget Function(BuildContext, VoidCallback)> remedies;
	final String? updateDisabledText;

	RefreshableList({
		required this.itemBuilder,
		required this.listUpdater,
		required this.id,
		this.controller,
		this.filterHint,
		this.filteredItemBuilder,
		this.autoUpdateDuration,
		this.remedies = const {},
		this.initialList,
		this.updateDisabledText
	});

	createState() => RefreshableListState<T>();
}

class RefreshableListState<T extends Filterable> extends State<RefreshableList<T>> {
	List<T>? list;
	String? errorMessage;
	Type? errorType;
	String _filter = '';
	bool updatingNow = false;
	final _searchController = TextEditingController();
	final _searchFocusNode = FocusNode();
	DateTime? lastUpdateTime;
	DateTime? nextUpdateTime;
	Timer? autoUpdateTimer;
	bool _searchFocused = false;

	@override
	void initState() {
		super.initState();
		widget.controller?.attach(this);
		_searchFocusNode.addListener(() {
			if (mounted && _searchFocusNode.hasFocus != _searchFocused) {
				setState(() {
					_searchFocused = _searchFocusNode.hasFocus;
				});
			}
		});
		list = widget.initialList;
		if (list != null) {
			widget.controller?.setItems(list!);
		}
		if (widget.updateDisabledText == null) {
			update();
			resetTimer();
		}
	}

	@override
	void didUpdateWidget(RefreshableList<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
			this.autoUpdateTimer?.cancel();
			this.autoUpdateTimer = null;
			widget.controller?.newContentId(widget.id);
			_closeSearch();
			setState(() {
				if (widget.initialList != null) {
					widget.controller?.setItems(widget.initialList!);
				}
				this.list = widget.initialList;
				this.errorMessage = null;
				this.errorType = null;
				this.lastUpdateTime = null;
			});
			update();
		}
		else if (oldWidget.updateDisabledText != widget.updateDisabledText) {
			this.autoUpdateTimer?.cancel();
			this.autoUpdateTimer = null;
			if (widget.updateDisabledText == null) {
				update();
				resetTimer();
			}
		}
	}

	@override
	void dispose() {
		super.dispose();
		this.autoUpdateTimer?.cancel();
	}

	void resetTimer() {
		this.autoUpdateTimer?.cancel();
		if (widget.autoUpdateDuration != null) {
			this.autoUpdateTimer = Timer(widget.autoUpdateDuration!, update);
			this.nextUpdateTime = DateTime.now().add(widget.autoUpdateDuration!);
		}
	}

	void _closeSearch() {
		_searchFocusNode.unfocus();
		_searchController.clear();
		setState(() {
			this._filter = '';
		});
	}

	Future<void> update() async {
		try {
			setState(() {
				this.errorMessage = null;
				this.errorType = null;
				this.updatingNow = true;
			});
			final newData = await widget.listUpdater();
			widget.controller?.setItems(newData);
			resetTimer();
			setState(() {
				this.errorMessage = null;
				this.errorType = null;
				this.updatingNow = false;
				this.list = newData;
				this.lastUpdateTime = DateTime.now();
			});
		}
		catch (e, st) {
			if (mounted) {
				setState(() {
					this.errorMessage = e.toString();
					this.errorType = e.runtimeType;
					this.updatingNow = false;
				});
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
	}

	Widget _itemBuilder(BuildContext context, T value) {
		if (_filter.isNotEmpty && widget.filteredItemBuilder!= null) {
			return widget.filteredItemBuilder!(context, value, _closeSearch);
		}
		else {
			return widget.itemBuilder(context, value);
		}
	}

	@override
	Widget build(BuildContext context) {
		if (list != null) {
			final List<T> values = _filter.isEmpty ? list! : list!.where((val) => val.getSearchableText().any((s) => s.toLowerCase().contains(_filter))).toList();
			return Listener(
				key: ValueKey(widget.id),
				onPointerUp: (event) {
					if (widget.controller != null) {
						double overscroll = widget.controller!.scrollController!.position.pixels - widget.controller!.scrollController!.position.maxScrollExtent;
						if (overscroll > 150) {
							update();
						}
					}
					// Auto update here
				},
				child: CustomScrollView(
					controller: widget.controller?.scrollController,
					physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), 
					slivers: [
						SliverSafeArea(
							sliver: CupertinoSliverRefreshControl(
								onRefresh: update,
								refreshTriggerPullDistance: 125
							),
							bottom: false
						),
						SliverToBoxAdapter(
							child: Container(
								height: kMinInteractiveDimensionCupertino,
								padding: EdgeInsets.all(4),
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										Expanded(
											child: Container(
												child: CupertinoSearchTextField(
													onChanged: (searchText) {
														setState(() {
															this._filter = searchText.toLowerCase();
														});
													},
													controller: _searchController,
													focusNode: _searchFocusNode,
													placeholder: widget.filterHint,
												)
											)
										),
										if (_searchFocused) CupertinoButton(
											padding: EdgeInsets.only(left: 8),
											child: Text('Cancel'),
											onPressed: _closeSearch
										)
									]
								)
							)
						),
						if (values.length > 0)
							SliverList(
								key: PageStorageKey('list for ${widget.id}'),
								delegate: SliverChildBuilderDelegate(
									(context, i) {
										if (i % 2 == 0) {
											return Builder(
												builder: (context) {
													widget.controller?.registerItem(i ~/ 2, values[i ~/ 2], context);
													return _itemBuilder(context, values[i ~/ 2]);
												}
											);
										}
										else {
											return Divider(
												thickness: 1,
												height: 0,
												color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
											);
										}
									},
									childCount: (values.length * 2)
								)
							),
						if (values.length == 0)
							if (_filter.isNotEmpty)
								SliverToBoxAdapter(
									child: Container(
										height: 100,
										child: Center(
											child: Text('No results')
										)
									)
								),
						SliverSafeArea(
							top: false,
							sliver: SliverToBoxAdapter(
								child: (widget.updateDisabledText != null) ? Container(
									padding: EdgeInsets.all(16),
									child: Center(
										child: Text(widget.updateDisabledText!, style: TextStyle(
											color: CupertinoTheme.of(context).primaryColor.withOpacity(0.5)
										))
									)
								) : TimedRebuilder(
									interval: const Duration(seconds: 1),
									builder: (context) => RefreshableListFooter(
										updater: update,
										updatingNow: updatingNow,
										lastUpdateTime: lastUpdateTime,
										nextUpdateTime: nextUpdateTime,
										errorMessage: errorMessage,
										remedy: widget.remedies[errorType]?.call(context, update)
									)
								)
							)
						)
					]
				)
			);
		}
		else if (errorMessage != null) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						ErrorMessageCard(errorMessage.toString()),
						CupertinoButton(
							child: Text('Retry'),
							onPressed: update
						),
						if (widget.remedies[errorType] != null) widget.remedies[errorType]!(context, update)
					]
				)
			);
		}
		else {
			return Center(
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
	RefreshableListFooter({
		required this.updater,
		required this.updatingNow,
		this.lastUpdateTime,
		this.nextUpdateTime,
		this.errorMessage,
		this.remedy
	});

	String _timeDiff(DateTime value) {
		final diff = value.difference(DateTime.now()).abs();
		String timeDiff = '';
		if (diff.inHours > 0) {
			timeDiff = '${diff.inHours}h';
		}
		else if (diff.inMinutes > 0) {
			timeDiff = '${diff.inMinutes}m';
		}
		else {
			timeDiff = '${(diff.inMilliseconds / 1000).round()}s';
		}
		if (value.isAfter(DateTime.now())) {
			timeDiff = 'in $timeDiff';
		}
		else {
			timeDiff = '$timeDiff ago';
		}
		return timeDiff;
	}

	@override
	Widget build(BuildContext context) {
		final timeLines = [];
		if (errorMessage != null) {
			timeLines.add(errorMessage);
		}
		if (nextUpdateTime != null) {
			timeLines.add('Updating ${_timeDiff(nextUpdateTime!)}');
		}
		if (lastUpdateTime != null) {
			timeLines.add('Last updated ${_timeDiff(lastUpdateTime!)}');
		}
		return GestureDetector(
			behavior: HitTestBehavior.opaque,
			onTap: updatingNow ? null : updater,
			child: Container(
				color: errorMessage != null ? Colors.orange.withOpacity(0.5) : null,
				padding: EdgeInsets.all(16),
				child: Center(
					child: AnimatedSwitcher(
						duration: const Duration(milliseconds: 200),
						child: Column(
							key: ValueKey<bool>(updatingNow),
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(
									updatingNow ? 'Updating now...\n' : timeLines.join('\n'),
									textAlign: TextAlign.center
								),
								if (!updatingNow && remedy != null) ...[
									SizedBox(height: 16),
									remedy!
								]
							]
						)
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
	bool get hasGoodState => (context?.findRenderObject()?.attached ?? false) && ((context?.findRenderObject() as RenderBox).hasSize);
	_RefreshableListItem(this.item);
}
class RefreshableListController<T extends Filterable> {
	List<_RefreshableListItem<T>> _items = [];
	ScrollController? scrollController;
	BehaviorSubject<Null> _scrollStream = BehaviorSubject();
	BehaviorSubject<Null> slowScrollUpdates = BehaviorSubject();
	late StreamSubscription<List<Null>> _slowScrollSubscription;
	int currentIndex = 0;
	double? topOffset;
	double? bottomOffset;
	String? contentId;
	RefreshableListController() {
		_slowScrollSubscription = _scrollStream.bufferTime(const Duration(milliseconds: 100)).where((batch) => batch.isNotEmpty).listen(_onScroll);
		slowScrollUpdates.listen(_onSlowScroll);
		SchedulerBinding.instance!.endOfFrame.then((_) => _onScroll([]));
	}
	Future<void> _tryCachingItem(_RefreshableListItem<T> item) async {
		await SchedulerBinding.instance!.endOfFrame;
		if (item.hasGoodState) {
			final RenderObject object = item.context!.findRenderObject()!;
			item.cachedHeight = object.semanticBounds.height;
			item.cachedOffset = _getOffset(object);
		}
	}
	void _onSlowScroll(Null update) {
		for (final item in _items) {
			if (item.cachedOffset == null) {
				_tryCachingItem(item);
			}
		}
		double? scrollableViewportHeight;
		for (final item in _items) {
			if (item.hasGoodState) {
				scrollableViewportHeight ??= Scrollable.of(item.context!)!.position.pixels;
				if (item.cachedOffset! - scrollableViewportHeight > 0) {
					currentIndex = _items.indexOf(item);
				}
			}
		}
	}
	void _onScroll(List<Null> notifications) {
		slowScrollUpdates.add(null);
	}
	void attach(RefreshableListState<T> list) {
		WidgetsBinding.instance!.addPostFrameCallback((_) {
			scrollController = PrimaryScrollController.of(list.context);
			scrollController!.addListener(() {
				_scrollStream.add(null);
			});
		});
	}
	void dispose() {
		_scrollStream.close();
		_slowScrollSubscription.cancel();
		slowScrollUpdates.close();
		scrollController?.dispose();
	}
	void newContentId(String contentId) {
		this.contentId = contentId;
		_items = [];
		currentIndex = 0;
	}
	void setItems(List<T> items) {
		_items.addAll(items.skip(_items.length).map((item) => _RefreshableListItem(item)));
	}
	void registerItem(int index, T item, BuildContext context) {
		topOffset ??= MediaQuery.of(context).padding.top;
		bottomOffset ??= MediaQuery.of(context).padding.bottom;
		this._items[index].item = item;
		this._items[index].context = context;
		_tryCachingItem(this._items[index]);
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object)!.getOffsetToReveal(object, 0.0).offset;
	}
	double _estimateOffset(int targetIndex) {
		final heightedItems = _items.map((i) => i.cachedHeight).where((i) => i != null);
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
		return estimate!;
	}
	Future<void> animateTo(bool f(T val), {double alignment = 0.0, Duration duration = const Duration(milliseconds: 200)}) async {
		_RefreshableListItem<T> targetItem = _items.firstWhere((i) => f(i.item));
		Duration d = duration;
		Curve c = Curves.ease;
		final initialContentId = contentId;
		if (targetItem.cachedOffset == null) {
			int targetIndex = _items.indexOf(targetItem);
			DateTime scrollStartTime = DateTime.now();
			c = Curves.easeIn;
			while (DateTime.now().difference(scrollStartTime).compareTo(Duration(seconds: 5)).isNegative) {
				await SchedulerBinding.instance!.endOfFrame;
				if (initialContentId != contentId) return;
				await scrollController!.animateTo(
					_estimateOffset(targetIndex) - topOffset!,
					duration: duration ~/ 4,
					curve: c
				);
				if (initialContentId != contentId) return;
				c = Curves.linear;
				await SchedulerBinding.instance!.endOfFrame;
				if (initialContentId != contentId) return;
				if (_items[targetIndex].hasGoodState) {
					break;
				}
			}
			await _tryCachingItem(_items[targetIndex]);
			if (initialContentId != contentId) return;
			Duration timeLeft = duration - DateTime.now().difference(scrollStartTime);
			if (timeLeft.inMilliseconds.isNegative) {
				d = duration ~/ 4;
			}
			else {
				d = Duration(milliseconds: min(timeLeft.inMilliseconds, duration.inMilliseconds ~/ 4));
			}
			c = Curves.easeOut;
		}
		final atAlignment0 = targetItem.cachedOffset! - topOffset!;
		final alignmentSlidingWindow = scrollController!.position.viewportDimension - targetItem.context!.findRenderObject()!.semanticBounds.size.height - topOffset! - bottomOffset!;
		if (targetItem == _items.last) {
			print('animating to ${scrollController!.position.maxScrollExtent}');
			await scrollController!.animateTo(
				scrollController!.position.maxScrollExtent,
				duration: d,
				curve: c
			);
			await SchedulerBinding.instance!.endOfFrame;
			print(scrollController!.position.pixels);
		}
		else {
			print('animating to ${(atAlignment0 - (alignmentSlidingWindow * alignment)).clamp(0, scrollController!.position.maxScrollExtent)}');
			await scrollController!.animateTo(
				(atAlignment0 - (alignmentSlidingWindow * alignment)).clamp(0, scrollController!.position.maxScrollExtent),
				duration: d,
				curve: c
			);
			await SchedulerBinding.instance!.endOfFrame;
			print(scrollController!.position.pixels);
		}
	}
	int get firstVisibleIndex => _items.indexWhere((i) => (i.cachedOffset != null) && (i.cachedOffset! > scrollController!.position.pixels));
	int get lastVisibleIndex => _items.lastIndexWhere((i) => (i.cachedOffset != null) && ((i.cachedOffset! + i.cachedHeight!) < (scrollController!.position.pixels + scrollController!.position.viewportDimension)));
}