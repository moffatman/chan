import 'dart:async';

import 'package:chan/widgets/timed_rebuilder.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

abstract class Filterable {
	List<String> getSearchableText();
}

class RefreshableList<T extends Filterable> extends StatefulWidget {
	final Widget Function(BuildContext context, T value) itemBuilder;
	final Future<List<T>> Function() listUpdater;
	final String id;
	final RefreshableListController? controller;
	final bool lazy;
	final String? filterHint;
	final Widget Function(BuildContext context, T value, VoidCallback resetPage)? filteredItemBuilder;
	final Duration? autoUpdateDuration;
	final List<Provider> additionalProviders;

	RefreshableList({
		required this.itemBuilder,
		required this.listUpdater,
		required this.id,
		this.additionalProviders = const [],
		this.controller,
		this.lazy = false,
		this.filterHint,
		this.filteredItemBuilder,
		this.autoUpdateDuration
	});

	createState() => RefreshableListState<T>();
}

class RefreshableListState<T extends Filterable> extends State<RefreshableList<T>> {
	List<T>? list;
	String? errorMessage;
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
		update();
		resetTimer();
	}

	@override
	void didUpdateWidget(RefreshableList<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
			this.autoUpdateTimer?.cancel();
			this.autoUpdateTimer = null;
			setState(() {
				this.list = null;
				this.errorMessage = null;
				this.lastUpdateTime = null;
			});
			update();
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
				this.updatingNow = true;
			});
			final newData = await widget.listUpdater();
			resetTimer();
			setState(() {
				this.updatingNow = false;
				this.list = newData;
				this.lastUpdateTime = DateTime.now();
				this.errorMessage = null;
			});
		}
		catch (e, st) {
			print(e);
			print(st);
			setState(() {
				this.errorMessage = e.toString();
				this.updatingNow = false;
			});
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
		if (errorMessage != null) {
			return Center(
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						ErrorMessageCard(errorMessage.toString()),
						CupertinoButton(
							child: Text('Retry'),
							onPressed: widget.listUpdater
						)
					]
				)
			);
		}
		else if (list != null) {
			final List<T> values = _filter.isEmpty ? list! : list!.where((val) => val.getSearchableText().any((s) => s.toLowerCase().contains(_filter))).toList();
			widget.controller?.resetItems(values.length);
			return MultiProvider(
				providers: [
					Provider<List<T>>.value(value: list!),
					...widget.additionalProviders
				],
				child: Listener(
					onPointerUp: (event) {
						if (widget.controller != null) {
							double overscroll = widget.controller!.scrollController.position.pixels - widget.controller!.scrollController.position.maxScrollExtent;
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
									refreshTriggerPullDistance: 150,
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
								if (widget.lazy) SliverList(
									delegate: SliverChildBuilderDelegate(
										(context, i) {
											if (i % 2 == 0) {
												return LayoutBuilder(
													builder: (context, constraints) {
														widget.controller?.registerItem(i ~/ 2, context, values[i ~/ 2]);
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
								)
								else SliverToBoxAdapter(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: List.generate(values.length * 2, (i) {
											if (i % 2 == 0) {
												return LayoutBuilder(
													builder: (context, constraints) {
														widget.controller?.registerItem(i ~/ 2, context, values[i ~/ 2]);
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
										}),
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
									child: TimedRebuilder(
										interval: const Duration(seconds: 1),
										builder: (context) => RefreshableListFooter(
											updater: update,
											updatingNow: updatingNow,
											lastUpdateTime: lastUpdateTime,
											nextUpdateTime: nextUpdateTime
										)
									)
								)
							)
						]
					)
				)
			);
		}
		else {
			return Center(
				child: CircularProgressIndicator()
			);
		}
	}
}

class RefreshableListFooter extends StatelessWidget {
	final VoidCallback updater;
	final bool updatingNow;
	final DateTime? lastUpdateTime;
	final DateTime? nextUpdateTime;
	RefreshableListFooter({
		required this.updater,
		required this.updatingNow,
		this.lastUpdateTime,
		this.nextUpdateTime
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
				height: 75,
				padding: EdgeInsets.all(16),
				child: Center(
					child: AnimatedSwitcher(
						duration: const Duration(milliseconds: 200),
						child: Text(updatingNow ? 'Updating now...' : timeLines.join('\n'), key: ValueKey<bool>(updatingNow), textAlign: TextAlign.center)
					)
				)
			)
		);
	}
}

class _RefreshableListItem<T> {
	final BuildContext context;
	final T item;
	_RefreshableListItem(this.context, this.item);
}
class RefreshableListController<T extends Filterable> {
	late List<_RefreshableListItem<T>?> _items;
	ScrollController scrollController = ScrollController();
	BehaviorSubject<Null> _scrollStream = BehaviorSubject();
	BehaviorSubject<Null> slowScrollUpdates = BehaviorSubject();
	RefreshableListController() {
		_scrollStream.bufferTime(const Duration(milliseconds: 1000)).where((batch) => batch.isNotEmpty).listen(_onScroll);
	}
	void _onScroll(List<Null> notifications) {
		slowScrollUpdates.add(null);
		//T? minObject = findNextMatch((item) => true);
		//print('New top: $minObject');
	}
	void attach(RefreshableListState<T> list) {
		scrollController.addListener(() {
			_scrollStream.add(null);
		});
	}
	void dispose() {
		_scrollStream.close();
		slowScrollUpdates.close();
		scrollController.dispose();
	}
	void resetItems(int length) {
		_items = List.generate(length, (_) => null);
	}
	void registerItem(int id, BuildContext context, T item) {
		this._items[id] = _RefreshableListItem(context, item);
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object)!.getOffsetToReveal(object, 0.0).offset;
	}
	_RefreshableListItem<T>? _findNextMatch(bool f(T val)) {
		_RefreshableListItem<T>? lastMatch;
		for (_RefreshableListItem<T>? item in _items) {
			final RenderObject? object = item!.context.findRenderObject();

			if (object == null || !object.attached) {
				continue;
			}

			final double vpHeight = RenderAbstractViewport.of(object)!.paintBounds.height;

			final Size size = object.semanticBounds.size;

			final double deltaTop = _getOffset(object) - Scrollable.of(item.context)!.position.pixels;
			final double deltaBottom = deltaTop + size.height;

			bool isBelowTopOfViewport = deltaTop >= 0.0 && deltaTop < vpHeight;
			bool isAboveBottomOfViewport = deltaBottom > 0.0 && deltaBottom < vpHeight;

			if (f(item.item)) {
				lastMatch = item;
				if (isBelowTopOfViewport) {
					return item;
				}
			}
		}
		return lastMatch;
	}
	T? findNextMatch(bool f(T val)) {
		return _findNextMatch(f)?.item;
	}
	void scrollToFirstMatching(bool f(T val)) {
		final match = _findNextMatch(f);
		if (match != null) {
			// Need to do some math here to account for the header
			final screenHeight = MediaQuery.of(match.context).size.height;
			final height = match.context.findRenderObject()!.semanticBounds.size.height;
			final safeAreaHeight = MediaQuery.of(match.context).padding.top;
			Scrollable.ensureVisible(
				match.context,
				alignment: safeAreaHeight / (screenHeight - height),
				duration: const Duration(milliseconds: 200)
			);
			/*scrollController.position.animateTo(
				_getOffset(match.context.findRenderObject()),
				duration: const Duration(milliseconds: 200),
				curve: Curves.ease
			);*/
		}
		else {
			print('No match found');
		}
	}
}