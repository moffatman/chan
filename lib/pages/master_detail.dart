import 'dart:math';

import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:provider/provider.dart';

final fullWidthCupertinoPageRouteBuilder = (WidgetBuilder builder) => FullWidthCupertinoPageRoute(builder: builder);
final transparentPageRouteBuilder = (WidgetBuilder builder) => TransparentRoute(builder: builder);

class BuiltDetailPane {
	final Widget widget;
	final PageRoute Function(WidgetBuilder builder) pageRouteBuilder;

	BuiltDetailPane({
		required this.widget,
		required this.pageRouteBuilder
	});

	PageRoute get pageRoute => pageRouteBuilder((context) => widget);
}

class MasterDetailPage<T> extends StatelessWidget {
	final String id;
	final double? twoPaneBreakpoint;
	final Widget Function(BuildContext context, T? selectedValue, ValueChanged<T> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue) detailBuilder;
	MasterDetailPage({
		required this.id,
		required this.masterBuilder,
		required this.detailBuilder,
		this.twoPaneBreakpoint
	});
	@override
	Widget build(BuildContext context) {
		return MultiMasterDetailPage(
			showChrome: false,
			panes: [
				MultiMasterPane<T>(
					id: id,
					masterBuilder: masterBuilder,
					detailBuilder: detailBuilder
				)
			]
		);
	}
}

class MultiMasterPane<T> {
	final String id;
	final Widget? title;
	final ObstructingPreferredSizeWidget? navigationBar;
	final IconData? icon;
	final Widget Function(BuildContext context, T? selectedValue, ValueChanged<T> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue) detailBuilder;
	T? currentValue;

	MultiMasterPane({
		required this.id,
		required this.masterBuilder,
		required this.detailBuilder,
		this.title,
		this.navigationBar,
		this.icon
	});

	Widget buildMaster(BuildContext context, VoidCallback onNewValue) {
		return masterBuilder(context, currentValue, (newValue) {
			currentValue = newValue;
			onNewValue();
		});
	}

	BuiltDetailPane buildDetail() {
		return detailBuilder(currentValue);
	}
}

class MultiMasterDetailPage extends StatefulWidget {
	final double twoPaneBreakpoint;
	final List<MultiMasterPane> panes;
	final bool showChrome;

	MultiMasterDetailPage({
		required this.panes,
		this.twoPaneBreakpoint = 700,
		this.showChrome = true
	});

	@override
	createState() => _MultiMasterDetailPageState();
}

class _MultiMasterDetailPageState extends State<MultiMasterDetailPage> with TickerProviderStateMixin {
	late TabController _tabController;
	final _masterKey = GlobalKey<NavigatorState>();
	final _detailKey = GlobalKey<NavigatorState>();
	late bool onePane;

	void _onPaneChanged() {
		setState(() {});
	}

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: widget.panes.length, vsync: this);
		_tabController.addListener(_onPaneChanged);
	}

	@override
	void didUpdateWidget(MultiMasterDetailPage old) {
		super.didUpdateWidget(old);
		if (old.panes != widget.panes) {
			int? newIndex;
			if (_tabController.index >= widget.panes.length) {
				newIndex = max(0, widget.panes.length - 1);
			}
			for (final pane in widget.panes) {
				final prev = old.panes.tryFirstWhere((p) => p.id == pane.id);
				if (prev != null) {
					pane.currentValue = prev.currentValue;
				}
			}
			_tabController.removeListener(_onPaneChanged);
			_tabController = TabController(
				initialIndex: newIndex ?? _tabController.index,
				length: widget.panes.length,
				vsync: this
			);
			_tabController.addListener(_onPaneChanged);
		}
	}

	void _onNewValue<T> (MultiMasterPane<T> pane) {
		if (onePane) {
			_masterKey.currentState!.push(pane.buildDetail().pageRoute);
		}
		else {
			_detailKey.currentState!.popUntil((route) => route.isFirst);
		}
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		onePane = MediaQuery.of(context).size.width < widget.twoPaneBreakpoint;
		final masterNavigator = Provider.value(
			value: _masterKey,
			child: Navigator(
				key: _masterKey,
				initialRoute: '/',
				onGenerateRoute: (RouteSettings settings) {
					return TransparentRoute(
						builder: (context) {
							final child = TabBarView(
								controller: _tabController,
								physics: AlwaysScrollableScrollPhysics(),
								children: widget.panes.map((pane) => pane.buildMaster(context, () => _onNewValue(pane))).toList()
							);
							if (widget.showChrome) {
								return CupertinoPageScaffold(
									navigationBar: widget.panes[_tabController.index].navigationBar ?? CupertinoNavigationBar(
										transitionBetweenRoutes: false,
										middle: widget.panes[_tabController.index].title
									),
									child: Column(
										children: [
											SafeArea(
												bottom: false,
												child: Material(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													child: TabBar(
														controller: _tabController,
														tabs: widget.panes.map((pane) => Tab(icon: Icon(pane.icon))).toList()
													)
												)
											),
											MediaQuery(
												data: MediaQuery.of(context).removePadding(removeTop: true),
												child: Expanded(
													child: child
												)
											)
										]
									)
								);
							}
							return child;
						}
					);
				}
			)
		);
		final detailNavigator = Provider.value(
			value: _detailKey,
			child: Navigator(
				key: _detailKey,
				initialRoute: '/',
				onGenerateRoute: (RouteSettings settings) {
					return FullWidthCupertinoPageRoute(
						builder: (context) {
							return IndexedStack(
								index: _tabController.index,
								children: widget.panes.map((p) => p.buildDetail().widget).toList()
							);
						},
						settings: settings
					);
				}
			)
		);
		if (onePane) {
			return masterNavigator;
		}
		else {
			return Row(
				children: [
					Flexible(
						flex: 1,
						child: masterNavigator
					),
					VerticalDivider(
						width: 0,
						color: CupertinoTheme.of(context).primaryColor.withBrightness(0.2)
					),
					Flexible(
						flex: 3,
						child: detailNavigator
					)
				]
			);
		}
	}
}