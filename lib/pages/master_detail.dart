import 'dart:math';

import 'package:chan/services/settings.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/util.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/subjects.dart';

PageRoute fullWidthCupertinoPageRouteBuilder(WidgetBuilder builder, bool showAnimations) => FullWidthCupertinoPageRoute(builder: builder, showAnimations: showAnimations);
PageRoute transparentPageRouteBuilder(WidgetBuilder builder, bool showAnimations) => TransparentRoute(builder: builder, showAnimations: showAnimations);

const dontAutoPopSettings = RouteSettings(
	name: 'dontautoclose'
);

class WillPopZone {
	WillPopCallback? callback;
}

class BuiltDetailPane {
	final Widget widget;
	final PageRoute Function(WidgetBuilder builder, bool showAnimations) pageRouteBuilder;

	BuiltDetailPane({
		required this.widget,
		required this.pageRouteBuilder
	});

	PageRoute pageRoute(bool showAnimations) => pageRouteBuilder((context) => widget, showAnimations);
}

class MasterDetailPage<T> extends StatelessWidget {
	final Object? id;
	final Widget Function(BuildContext context, T? selectedValue, ValueChanged<T?> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue, bool poppedOut) detailBuilder;
	final T? initialValue;
	final ValueChanged<T?>? onValueChanged;
	const MasterDetailPage({
		required this.id,
		required this.masterBuilder,
		required this.detailBuilder,
		this.initialValue,
		this.onValueChanged,
		Key? key
	}) : super(key: key);
	@override
	Widget build(BuildContext context) {
		return MultiMasterDetailPage(
			showChrome: false,
			id: id,
			paneCreator: () => [
				MultiMasterPane<T>(
					masterBuilder: masterBuilder,
					detailBuilder: detailBuilder,
					initialValue: initialValue,
					onValueChanged: onValueChanged
				)
			]
		);
	}
}

class MultiMasterPane<T> {
	final Widget? title;
	final ObstructingPreferredSizeWidget? navigationBar;
	final IconData? icon;
	final Widget Function(BuildContext context, T? selectedValue, ValueChanged<T?> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue, bool poppedOut) detailBuilder;
	ValueNotifier<T?> currentValue;
	final ValueChanged<T?>? onValueChanged;

	MultiMasterPane({
		required this.masterBuilder,
		required this.detailBuilder,
		this.title,
		this.navigationBar,
		this.icon,
		T? initialValue,
		this.onValueChanged
	}) : currentValue = ValueNotifier<T?>(initialValue);

	Widget buildMaster(BuildContext context, VoidCallback onNewValue, bool provideCurrentValue) {
		return ValueListenableBuilder(
			valueListenable: currentValue,
			builder: (context, T? v, child) => masterBuilder(context, provideCurrentValue ? v : null, (newValue) {
					currentValue.value = newValue;
					onValueChanged?.call(newValue);
					onNewValue();
				}
			)
		);
	}

	void onPushReturn(dynamic value) {
		if (value != false) {
			// it was a user-initiated pop
			currentValue.value = null;
			onValueChanged?.call(null);
		}
	}

	Widget buildDetail() {
		return ValueListenableBuilder(
			valueListenable: currentValue,
			builder: (context, T? v, child) => detailBuilder(v, false).widget
		);
	}

	PageRoute buildDetailRoute(bool showAnimations) {
		return detailBuilder(currentValue.value, true).pageRoute(showAnimations);
	}
}

class MultiMasterDetailPage extends StatefulWidget {
	final Object? id;
	final List<MultiMasterPane> Function() paneCreator;
	final bool showChrome;

	const MultiMasterDetailPage({
		required this.paneCreator,
		this.id,
		this.showChrome = true,
		Key? key
	}) : super(key: key);

	@override
	createState() => _MultiMasterDetailPageState();
}

class _MultiMasterDetailPageState extends State<MultiMasterDetailPage> with TickerProviderStateMixin {
	late TabController _tabController;
	late GlobalKey<NavigatorState> _masterKey;
	late GlobalKey _masterInterceptorKey;
	late GlobalKey _masterContentKey;
	late GlobalKey<NavigatorState> _detailKey;
	late GlobalKey _detailInterceptorKey;
	late GlobalKey _detailContentKey;
	List<MultiMasterPane> panes = [];
 	bool? lastOnePane;
	late bool onePane;
	final _rebuild = BehaviorSubject<void>();

	void _onPaneChanged() {
		setState(() {});
		_rebuild.add(null);
	}

	void _initGlobalKeys() {
		_masterKey = GlobalKey<NavigatorState>(debugLabel: '${widget.id} _masterKey');
		_masterInterceptorKey = GlobalKey(debugLabel: '${widget.id} _masterInterceptorKey');
		_masterContentKey = GlobalKey(debugLabel: '${widget.id} _masterContentKey');
		_detailKey = GlobalKey<NavigatorState>(debugLabel: '${widget.id} _detailKey}');
		_detailInterceptorKey = GlobalKey(debugLabel: '${widget.id} _detailInterceptorKey');
		_detailContentKey = GlobalKey(debugLabel: '${widget.id} _detailContentKey');
	}

	@override
	void initState() {
		super.initState();
		panes = widget.paneCreator();
		_tabController = TabController(length: panes.length, vsync: this);
		_tabController.addListener(_onPaneChanged);
		_initGlobalKeys();
		Future.delayed(const Duration(milliseconds: 100), () {
			if (panes[_tabController.index].currentValue.value != null) {
				_onNewValue(panes[_tabController.index]);
			}
		});
	}

	@override
	void didUpdateWidget(MultiMasterDetailPage old) {
		super.didUpdateWidget(old);
		if (old.id != widget.id) {
			int newIndex = _tabController.index;
			panes = widget.paneCreator();
			if (_tabController.index >= panes.length) {
				newIndex = max(0, panes.length - 1);
			}
			_tabController.removeListener(_onPaneChanged);
			_tabController = TabController(
				initialIndex: newIndex,
				length: panes.length,
				vsync: this
			);
			_tabController.addListener(_onPaneChanged);
		  _initGlobalKeys();
		}
	}

	void _onNewValue<T> (MultiMasterPane<T> pane) {
		if (onePane) {
			if (pane.currentValue.value != null) {
				_masterKey.currentState!.push(pane.buildDetailRoute(context.read<EffectiveSettings>().showAnimations)).then(pane.onPushReturn);
			}
		}
		else {
			_detailKey.currentState?.popUntil((route) => route.isFirst);
		}
		setState(() {});
	}

	Future<bool> _onWillPop() async {
		if (onePane) {
			return !(await _masterKey.currentState?.maybePop() ?? false);
		}
		else {
			if (await _detailKey.currentState?.maybePop() ?? false) {
				return false;
			}
			return !(await _masterKey.currentState?.maybePop() ?? false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		onePane = MediaQuery.of(context, MediaQueryAspect.width).size.width < settings.twoPaneBreakpoint;
		final masterNavigator = Provider.value(
			value: _masterKey,
			child: ClipRect(
				child: PrimaryScrollControllerInjectingNavigator(
					key: _masterInterceptorKey,
					navigatorKey: _masterKey,
					observers: [HeroController()],
					buildRoot: (context) => StreamBuilder(
						stream: _rebuild,
						builder: (context, _) {
							Widget child = TabBarView(
								controller: _tabController,
								physics: panes.length > 1 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
								children: panes.map((pane) => pane.buildMaster(context, () => _onNewValue(pane), !onePane)).toList()
							);
							if (widget.showChrome) {
								child = CupertinoPageScaffold(
									resizeToAvoidBottomInset: false,
									navigationBar: panes[_tabController.index].navigationBar ?? CupertinoNavigationBar(
										transitionBetweenRoutes: false,
										middle: panes[_tabController.index].title
									),
									child: Column(
										children: [
											SafeArea(
												bottom: false,
												child: Material(
													color: CupertinoTheme.of(context).scaffoldBackgroundColor,
													child: TabBar(
														controller: _tabController,
														tabs: panes.map((pane) => Tab(
															icon: Icon(
																pane.icon,
																color: CupertinoTheme.of(context).primaryColor
															)
														)).toList()
													)
												)
											),
											TransformedMediaQuery(
												transformation: (mq) => mq.removePadding(removeTop: true),
												child: Expanded(
													child: child
												)
											)
										]
									)
								);
							}
							child = KeyedSubtree(
								key: _masterContentKey,
								child: child
							);
							return child;
						}
					)
				)
			)
		);
		final detailNavigator = Provider.value(
			value: _detailKey,
			child: ClipRect(
				child: PrimaryScrollControllerInjectingNavigator(
					key: _detailInterceptorKey,
					navigatorKey: _detailKey,
					buildRoot: (context) => StreamBuilder(
						stream: _rebuild,
						builder: (context, _) => KeyedSubtree(
							key: _detailContentKey,
							child: panes[_tabController.index].buildDetail()
						)
					)
				)
			)
		);
		if (lastOnePane != null && lastOnePane != onePane) {
			final pane = panes[_tabController.index];
			if (onePane && pane.currentValue.value != null) {
				_masterKey.currentState!.push(pane.buildDetailRoute(context.read<EffectiveSettings>().showAnimations)).then(pane.onPushReturn);
			}
			else {
				bool continuePopping = true;
				while ((_masterKey.currentState?.canPop() ?? false) && continuePopping) {
					// Hack to peek at top route
					// Need to pop with value=false so can't just use popUntil
					_masterKey.currentState?.popUntil((route) {
						continuePopping = route.settings != dontAutoPopSettings;
						if (continuePopping) {
							_masterKey.currentState?.pop(false);
						}
						return true;
					});
				}
				while (_detailKey.currentState?.canPop() ?? false) {
					_detailKey.currentState?.pop(false);
				}
			}
		}
		lastOnePane = onePane;
		context.watch<WillPopZone?>()?.callback = _onWillPop;
		return WillPopScope(
			onWillPop: _onWillPop,
			child: onePane ? masterNavigator : Row(
				children: [
					Flexible(
						flex: settings.twoPaneSplit,
						child: PrimaryScrollController.none(
							child: masterNavigator
						)
					),
					VerticalDivider(
						width: 0,
						color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
					),
					Flexible(
						flex: twoPaneSplitDenominator - settings.twoPaneSplit,
						child: detailNavigator
					)
				]
			)
		);
	}
}