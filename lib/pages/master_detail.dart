import 'dart:math';

import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/injecting_navigator.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/util.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

PageRoute fullWidthCupertinoPageRouteBuilder(WidgetBuilder builder, {bool? showAnimations, required bool? showAnimationsForward}) => adaptivePageRoute(builder: builder, showAnimations: showAnimations, showAnimationsForward: showAnimationsForward);
PageRoute transparentPageRouteBuilder(WidgetBuilder builder, {bool? showAnimations, required bool? showAnimationsForward}) => TransparentRoute(builder: builder, showAnimations: showAnimations, showAnimationsForward: showAnimationsForward);

enum MasterDetailLocation {
	onePaneMaster,
	twoPaneHorizontalMaster,
	twoPaneHorizontalDetail,
	twoPaneVerticalMaster,
	twoPaneVerticalDetail;
	bool get isVeryConstrained => switch(this) {
		twoPaneHorizontalMaster || twoPaneVerticalMaster || twoPaneVerticalDetail => true,
		onePaneMaster || twoPaneHorizontalDetail => false
	};
	bool get twoPane => switch (this) {
		onePaneMaster => false,
		_ => true
	};
	bool get isDetail => switch (this) {
		twoPaneHorizontalDetail || twoPaneVerticalDetail => true,
		_ => false
	};
}

class MasterDetailHint {
	final MasterDetailLocation location;
	final GlobalKey<PrimaryScrollControllerInjectingNavigatorState> primaryInterceptorKey;
	final dynamic currentValue;

	const MasterDetailHint({
		required this.location,
		required this.primaryInterceptorKey,
		required this.currentValue
	});

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is MasterDetailHint &&
		other.location == location &&
		other.primaryInterceptorKey == primaryInterceptorKey &&
		other.currentValue == currentValue;
	
	@override
	int get hashCode => Object.hash(location, primaryInterceptorKey, currentValue);

	bool get twoPane => location.twoPane;
}

const dontAutoPopSettings = RouteSettings(
	name: 'dontautoclose'
);

class WillPopZone {
	/// True = did pop
	Future<bool> Function()? maybePop;
}

class BuiltDetailPane {
	final Widget widget;
	final PageRoute Function(WidgetBuilder builder, {required bool? showAnimations, required bool? showAnimationsForward}) pageRouteBuilder;

	BuiltDetailPane({
		required this.widget,
		required this.pageRouteBuilder
	});

	PageRoute pageRoute({required bool? showAnimations, required bool? showAnimationsForward}) => pageRouteBuilder((context) => widget, showAnimations: showAnimations, showAnimationsForward: showAnimationsForward);
}

class MasterDetailPage<T> extends StatelessWidget {
	final Object? id;
	final Widget Function(BuildContext context, bool Function(BuildContext, T) isSelected, ValueChanged<T?> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue, ValueChanged<T?> valueSetter, bool poppedOut) detailBuilder;
	final T? initialValue;
	final ValueChanged<T?>? onValueChanged;
	final Key? multiMasterDetailPageKey;
	const MasterDetailPage({
		required this.id,
		required this.masterBuilder,
		required this.detailBuilder,
		this.initialValue,
		this.onValueChanged,
		this.multiMasterDetailPageKey,
		Key? key
	}) : super(key: key);
	@override
	Widget build(BuildContext context) {
		return MultiMasterDetailPage(
			showChrome: false,
			id: id,
			key: multiMasterDetailPageKey,
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
	final AdaptiveBar? navigationBar;
	final IconData? icon;
	final Widget Function(BuildContext context, bool Function(BuildContext, T) isSelected, ValueChanged<T?> valueSetter) masterBuilder;
	final BuiltDetailPane Function(T? selectedValue, ValueChanged<T?> valueSetter, bool poppedOut) detailBuilder;
	ValueNotifier<T?> currentValue;
	final ValueChanged<T?>? onValueChanged;
	DateTime? _lastAutomatedPop;
	final bool useRootNavigator;

	MultiMasterPane({
		required this.masterBuilder,
		required this.detailBuilder,
		this.title,
		this.navigationBar,
		this.icon,
		T? initialValue,
		this.useRootNavigator = false,
		this.onValueChanged
	}) : currentValue = ValueNotifier<T?>(initialValue);

	callOnValueChanged(dynamic newValue) {
		if (newValue is T?) {
			onValueChanged?.call(newValue);
		}
	}

	Widget buildMaster(BuildContext context, VoidCallback onNewValue, bool provideCurrentValue) {
		return masterBuilder(context, (context, thisValue) => context.select<MasterDetailHint?, bool>((h) {
			if (!provideCurrentValue) return false;
			return h?.currentValue == thisValue;
		}), (newValue) {
			currentValue.value = newValue;
			callOnValueChanged(newValue);
			onNewValue();
		});
	}

	void onPushReturn(dynamic value) {
		if (_lastAutomatedPop == null || DateTime.now().difference(_lastAutomatedPop!) > const Duration(milliseconds: 300)) {
			// it was a user-initiated pop
			currentValue.value = null;
			callOnValueChanged(null);
		}
	}

	Widget buildDetail(VoidCallback onNewValue) {
		return ValueListenableBuilder(
			valueListenable: currentValue,
			builder: (context, T? v, child) => detailBuilder(v, (newValue) {
				currentValue.value = newValue;
				callOnValueChanged(newValue);
				onNewValue();
			}, false).widget
		);
	}

	PageRoute buildDetailRoute(VoidCallback onNewValue, {bool? showAnimations, required bool? showAnimationsForward}) {
		return detailBuilder(currentValue.value, (newValue) {
				currentValue.value = newValue;
				callOnValueChanged(newValue);
				onNewValue();
			}, true).pageRoute(showAnimations: showAnimations, showAnimationsForward: showAnimationsForward);
	}

	void dispose() {
		currentValue.dispose();
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
	createState() => MultiMasterDetailPageState();
}

class MultiMasterDetailPageState extends State<MultiMasterDetailPage> with TickerProviderStateMixin {
	late TabController _tabController;
	late GlobalKey<NavigatorState> masterKey;
	late GlobalKey<PrimaryScrollControllerInjectingNavigatorState> _masterInterceptorKey;
	late GlobalKey _masterContentKey;
	late GlobalKey _tabBarViewKey;
	final Map<int, GlobalKey> _masterPaneKeys = {};
	late GlobalKey<NavigatorState> detailKey;
	late GlobalKey<PrimaryScrollControllerInjectingNavigatorState> _detailInterceptorKey;
	late GlobalKey _detailContentKey;
	List<MultiMasterPane> panes = [];
 	bool? lastOnePane;
	late bool onePane;
	late final EasyListenable _rebuild;

	void _onPaneChanged() {
		setState(() {});
		_rebuild.didUpdate();
	}

	int get selectedPane => _tabController.index;
	set selectedPane(int newPane) {
		_tabController.index = newPane;
	}

	void _initGlobalKeys() {
		masterKey = GlobalKey<NavigatorState>(debugLabel: '${widget.id} masterKey');
		_masterInterceptorKey = GlobalKey(debugLabel: '${widget.id} _masterInterceptorKey');
		_masterContentKey = GlobalKey(debugLabel: '${widget.id} _masterContentKey');
		_tabBarViewKey = GlobalKey(debugLabel: '${widget.id} _tabBarViewKey');
		detailKey = GlobalKey<NavigatorState>(debugLabel: '${widget.id} detailKey}');
		_detailInterceptorKey = GlobalKey(debugLabel: '${widget.id} _detailInterceptorKey');
		_detailContentKey = GlobalKey(debugLabel: '${widget.id} _detailContentKey');
	}

	@override
	void initState() {
		super.initState();
		_rebuild = EasyListenable();
		panes = widget.paneCreator();
		_tabController = TabController(length: panes.length, vsync: this);
		_tabController.addListener(_onPaneChanged);
		_initGlobalKeys();
		WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
			if (panes[_tabController.index].currentValue.value != null) {
				_onNewValue(panes[_tabController.index], showAnimationsForward: false);
			}
		});
	}

	@override
	void didUpdateWidget(MultiMasterDetailPage oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
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

	void setValue(int index, dynamic value, {bool updateDetailPane = true, bool showAnimationsForward = true}) {
		if (panes[index].currentValue.value == value) {
			return;
		}
		panes[index].currentValue.value = value;
		panes[index].callOnValueChanged(value);
		_onNewValue(panes[index], updateDetailPane: updateDetailPane, showAnimationsForward: showAnimationsForward);
	}

	T? getValue<T>(int index) {
		dynamic value = panes[index].currentValue.value;
		if (value is T) {
			return value;
		}
		else if (value != null) {
			print('Tried to getValue<$T>($index) but found ${value.runtimeType}');
		}
		return null;
	}

	void _popMasterValueRoutes() {
		bool continuePopping = true;
		while ((masterKey.currentState?.canPop() ?? false) && continuePopping) {
			// Hack to peek at top route
			// Need to pop with value=false so can't just use popUntil
			masterKey.currentState?.popUntil((route) {
				continuePopping = route.settings != dontAutoPopSettings;
				if (continuePopping) {
					panes[selectedPane]._lastAutomatedPop = DateTime.now();
					masterKey.currentState?.pop();
				}
				return true;
			});
		}
	}

	void _onNewValue<T> (MultiMasterPane<T> pane, {bool? showAnimationsForward, bool updateDetailPane = true}) {
		if (!updateDetailPane) {
			return;
		}
		if (onePane) {
			if (pane.currentValue.value != null) {
				_popMasterValueRoutes();
				(pane.useRootNavigator ? Navigator.of(context, rootNavigator: true) : masterKey.currentState!).push(pane.buildDetailRoute(
					() => _onNewValue(pane, showAnimationsForward: false),
					showAnimationsForward: showAnimationsForward
				)).then(pane.onPushReturn);
			}
		}
		else {
			detailKey.currentState?.popUntil((route) => route.isFirst);
		}
		setState(() {});
	}

	Future<bool> _maybePop() async {
		if (onePane) {
			return await masterKey.currentState?.maybePop() ?? false;
		}
		else {
			if (await detailKey.currentState?.maybePop() ?? false) {
				return true;
			}
			return await masterKey.currentState?.maybePop() ?? false;
		}
	}

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		final horizontalSplit = shouldHorizontalSplit(context, listen: true);
		final verticalSplit = !settings.verticalTwoPaneMinimumPaneSize.isNegative && MediaQuery.sizeOf(context).height >= (settings.verticalTwoPaneMinimumPaneSize * 2);
		onePane = !(horizontalSplit || verticalSplit);
		final masterNavigator = Provider.value(
			value: masterKey,
			child: ClipRect(
				child: PrimaryScrollControllerInjectingNavigator(
					key: _masterInterceptorKey,
					navigatorKey: masterKey,
					observers: [
						HeroController(),
						ScrollTrackerNavigatorObserver()
					],
					buildRoot: (context) => AnimatedBuilder(
						animation: _rebuild,
						builder: (context, _) {
							Widget child = TabBarView(
								key: _tabBarViewKey,
								controller: _tabController,
								physics: panes.length > 1 ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
								children: panes.asMap().entries.map((entry) => KeepAliver(
									key: _masterPaneKeys.putIfAbsent(entry.key, () => GlobalKey(debugLabel: '${widget.id} _masterPaneKeys[${entry.key}]')),
									child: AnimatedBuilder(
										animation: _tabController,
										builder: (context, child) => entry.key == _tabController.index ? child! : PrimaryScrollController.none(
											child: child!
										),
										child: Builder(
											builder: (context) => entry.value.buildMaster(context, () => _onNewValue(entry.value), !onePane)
										)
									)
								)).toList()
							);
							if (widget.showChrome) {
								child = AdaptiveScaffold(
									resizeToAvoidBottomInset: false,
									bar: panes[_tabController.index].navigationBar ?? AdaptiveBar(
										title: panes[_tabController.index].title
									),
									body: Stack(
										children: [
											TransformedMediaQuery(
												transformation: (context, mq) => mq.copyWith(
													padding: mq.padding + const EdgeInsets.only(top: 46),
													viewPadding: mq.viewPadding + const EdgeInsets.only(top: 46)
												),
												child: child
											),
											SafeArea(
												bottom: false,
												child: AncestorScrollBuilder(
													builder: (context, direction, child) => settings.hideBarsWhenScrollingDown ? AnimatedOpacity(
														opacity: direction == VerticalDirection.up ? 1.0 : 0.0,
														duration: const Duration(milliseconds: 350),
														curve: Curves.ease,
														child: IgnorePointer(
															ignoring: direction == VerticalDirection.down,
															child: child
														)
													) : child!,
													child: Material(
														color: ChanceTheme.backgroundColorOf(context),
														child: TabBar(
															controller: _tabController,
															indicatorColor: ChanceTheme.primaryColorOf(context),
															dividerColor: ChanceTheme.primaryColorWithBrightness20Of(context),
															tabs: panes.map((pane) => Tab(
																icon: Icon(
																	pane.icon,
																	color: ChanceTheme.primaryColorOf(context)
																)
															)).toList()
														)
													)
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
			value: detailKey,
			child: ClipRect(
				child: PrimaryScrollControllerInjectingNavigator(
					key: _detailInterceptorKey,
					navigatorKey: detailKey,
					observers: [
						ScrollTrackerNavigatorObserver()
					],
					buildRoot: (context) => AnimatedBuilder(
						animation: _rebuild,
						builder: (context, _) => KeyedSubtree(
							key: _detailContentKey,
							child: panes[_tabController.index].buildDetail(() => _onNewValue(panes[_tabController.index], showAnimationsForward: false))
						)
					)
				)
			)
		);
		if (lastOnePane != null && lastOnePane != onePane) {
			final pane = panes[_tabController.index];
			if (onePane && pane.currentValue.value != null) {
				masterKey.currentState!.push(pane.buildDetailRoute(
					() => _onNewValue(pane, showAnimationsForward: false),
					showAnimationsForward: false
				)).then(pane.onPushReturn);
			}
			else {
				_popMasterValueRoutes();
				while (detailKey.currentState?.canPop() ?? false) {
					pane._lastAutomatedPop = DateTime.now();
					detailKey.currentState?.pop();
				}
			}
		}
		lastOnePane = onePane;
		context.watch<WillPopZone?>()?.maybePop = _maybePop;
		return onePane ? Provider.value(
			value: MasterDetailHint(
				location: MasterDetailLocation.onePaneMaster,
				primaryInterceptorKey: onePane ? _masterInterceptorKey : _detailInterceptorKey,
				currentValue: panes[_tabController.index].currentValue.value
			),
			child: masterNavigator
		) : (horizontalSplit ? Row(
			children: [
				Flexible(
					flex: settings.twoPaneSplit,
					child: PrimaryScrollController.none(
						child: Provider.value(
							value: MasterDetailHint(
								location: MasterDetailLocation.twoPaneHorizontalMaster,
								primaryInterceptorKey: onePane ? _masterInterceptorKey : _detailInterceptorKey,
								currentValue: panes[_tabController.index].currentValue.value,
							),
							child: masterNavigator
						)
					)
				),
				VerticalDivider(
					width: 0,
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
				Flexible(
					flex: twoPaneSplitDenominator - settings.twoPaneSplit,
					child: Provider.value(
						value: MasterDetailHint(
							location: MasterDetailLocation.twoPaneHorizontalDetail,
							primaryInterceptorKey: onePane ? _masterInterceptorKey : _detailInterceptorKey,
							currentValue: panes[_tabController.index].currentValue.value,
						),
						child: detailNavigator
					)
				)
			]
		) : Column(
			children: [
				SizedBox(
					height: settings.verticalTwoPaneMinimumPaneSize.abs(),
					child: PrimaryScrollController.none(
						child: Provider.value(
							value: MasterDetailHint(
								location: MasterDetailLocation.twoPaneVerticalMaster,
								primaryInterceptorKey: onePane ? _masterInterceptorKey : _detailInterceptorKey,
								currentValue: panes[_tabController.index].currentValue.value,
							),
							child: masterNavigator
						)
					)
				),
				Divider(
					height: 0,
					color: ChanceTheme.primaryColorWithBrightness20Of(context)
				),
				Expanded(
					child: TransformedMediaQuery(
						transformation: (context, data) => data.removePadding(removeTop: true),
						child: Provider.value(
							value: MasterDetailHint(
								location: MasterDetailLocation.twoPaneVerticalDetail,
								primaryInterceptorKey: onePane ? _masterInterceptorKey : _detailInterceptorKey,
								currentValue: panes[_tabController.index].currentValue.value,
							),
							child: detailNavigator
						)
					)
				)
			]
		));
	}

	@override
	void dispose() {
		super.dispose();
		_tabController.dispose();
		for (final pane in panes) {
			pane.dispose();
		}
		_rebuild.dispose();
	}
}