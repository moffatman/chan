import 'package:chan/widgets/data_stream_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:rxdart/rxdart.dart';

abstract class Filterable {
	List<String> getSearchableText();
}

class ProviderList<T extends Filterable> extends StatefulWidget {
	final Widget Function(BuildContext context, T value) builder;
	final Future<List<T>> Function() listUpdater;
	final String id;
	final ProviderListController? controller;
	final bool lazy;
	final String? searchHint;
	final Widget Function(BuildContext context, T value, VoidCallback resetPage)? searchBuilder;

	ProviderList({
		required this.builder,
		required this.listUpdater,
		required this.id,
		this.controller,
		this.lazy = false,
		this.searchHint,
		this.searchBuilder
	});

	createState() => ProviderListState<T>();
}

class ProviderListState<T extends Filterable> extends State<ProviderList<T>> {
	String _filter = '';
	TextEditingController _searchController = TextEditingController();

	@override
	void initState() {
		super.initState();
		widget.controller?.attach(this);
	}

	void _clearSearch() {
		FocusScope.of(context).unfocus();
		_searchController.clear();
		setState(() {
			_filter = '';
		});
	}

	Widget _builder(BuildContext context, T value) {
		if (_filter.isNotEmpty && widget.searchBuilder != null) {
			return widget.searchBuilder!(context, value, _clearSearch);
		}
		else {
			return widget.builder(context, value);
		}
	}

	@override
	Widget build(BuildContext context) {
		return DataProvider<List<T>>(
			id: widget.id,
			updater: widget.listUpdater,
			initialValue: [],
			placeholderBuilder: (BuildContext context, value) {
				return Center(
					child: CupertinoActivityIndicator()
				);
			},
			builder: (BuildContext context, List<T> unfilteredValues, Future<void> Function() requestUpdate) {
				final List<T> values = _filter.isEmpty ? unfilteredValues : unfilteredValues.where((val) => val.getSearchableText().any((s) => s.toLowerCase().contains(_filter))).toList();
				widget.controller?.resetItems(values.length);
				return CustomScrollView(
					controller: widget.controller?.scrollController,
					physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), 
					slivers: [
						SliverSafeArea(
							sliver: CupertinoSliverRefreshControl(
								onRefresh: requestUpdate,
								refreshTriggerPullDistance: 150,
							),
							bottom: false
						),
						SliverToBoxAdapter(
							child: Container(
								height: kMinInteractiveDimensionCupertino,
								padding: EdgeInsets.all(4),
								child: CupertinoSearchTextField(
									onChanged: (searchText) {
										setState(() {
											_filter = searchText.toLowerCase();
										});
									},
									controller: _searchController,
									placeholder: widget.searchHint,
									onSuffixTap: _clearSearch
								),
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
													return _builder(context, values[i ~/ 2]);
												}
											);
										}
										else {
											return Divider(
												thickness: 1
											);
										}
									},
									childCount: (values.length * 2) - 1
								)
							)
							else SliverToBoxAdapter(
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: List.generate(values.length * 2 - 1, (i) {
										if (i % 2 == 0) {
											return LayoutBuilder(
												builder: (context, constraints) {
													widget.controller?.registerItem(i ~/ 2, context, values[i ~/ 2]);
													return _builder(context, values[i ~/ 2]);
												}
											);
										}
										else {
											return Divider(
												thickness: 1
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
								child: Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Container(
											padding: EdgeInsets.only(top: 16, bottom: 16),
											child: ElevatedButton.icon(
												icon: Icon(Icons.refresh),
												label: Text("Reload"),
												onPressed: requestUpdate
											)
										)
									]
								)
							)
						)
					]
				);
			},
			errorBuilder: (context, exception) {
				return Center(
					child: Text(exception.toString())
				);
			}
		);
	}
}

class _ProviderListItem<T> {
	final BuildContext context;
	final T item;
	_ProviderListItem(this.context, this.item);
}
class ProviderListController<T extends Filterable> {
	late List<_ProviderListItem<T>?> _items;
	ScrollController scrollController = ScrollController();
	BehaviorSubject<Null> _scrollStream = BehaviorSubject();
	ProviderListController() {
		_scrollStream.bufferTime(const Duration(milliseconds: 100)).where((batch) => batch.isNotEmpty).listen(_onScroll);
	}
	void _onScroll(List<Null> notifications) {
		T? minObject = findNextMatch((item) => true);
		//print('New top: $minObject');
	}
	void attach(ProviderListState<T> list) {
		scrollController.addListener(() {
			_scrollStream.add(null);
		});
	}
	void dispose() {
		_scrollStream.close();
	}
	void resetItems(int length) {
		_items = List.generate(length, (_) => null);
	}
	void registerItem(int id, BuildContext context, T item) {
		this._items[id] = _ProviderListItem(context, item);
	}
	double _getOffset(RenderObject object) {
		return RenderAbstractViewport.of(object)!.getOffsetToReveal(object, 0.0).offset;
	}
	_ProviderListItem<T>? _findNextMatch(bool f(T val)) {
		_ProviderListItem<T>? lastMatch;
		for (_ProviderListItem<T>? item in _items) {
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