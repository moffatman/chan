import 'package:chan/services/settings.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class InjectingNavigator extends Navigator {
	final Listenable animation;
	final Widget Function(BuildContext, Route?, WidgetBuilder) injector;
	const InjectingNavigator({
		required this.animation,
		required this.injector,
		String? initialRoute,
		List<NavigatorObserver> observers = const [],
		RouteFactory? onGenerateRoute,
		Key? key}
	) : super(
		initialRoute: initialRoute,
		observers: observers,
		onGenerateRoute: onGenerateRoute,
		key: key
	);

	@override
	createState() => _InjectingNavigatorState();
}

class _InjectingNavigatorState extends NavigatorState {
	final _routeStack = <Route>[];
	final topRoute = ValueNotifier<Route?>(null);

	@override
	Future<T?> push<T extends Object?>(Route<T> route) {
		_routeStack.add(route);
		topRoute.value = route;
		if (route is FullWidthCupertinoPageRoute<T> && widget is InjectingNavigator) {
			return super.push(FullWidthCupertinoPageRoute<T>(
				settings: route.settings,
				builder: (context) => (widget as InjectingNavigator).injector(context, route, route.builder),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			));
		}
		return super.push(route);
	}

	@override
	void pop<T extends Object?>([T? result]) {
		_routeStack.removeLast();
		topRoute.value = _routeStack.isEmpty ? null : _routeStack.last;
		super.pop(result);
	}
}

class PrimaryScrollControllerInjectingNavigator extends StatefulWidget {
	final List<NavigatorObserver> observers;
	final WidgetBuilder buildRoot;
	final GlobalKey<NavigatorState> navigatorKey;
	const PrimaryScrollControllerInjectingNavigator({
		this.observers = const [],
		required this.buildRoot,
		required this.navigatorKey,
		Key? key
	}) : super(key: key);
	@override
	createState() => _PrimaryScrollControllerInjectingNavigatorState();
}

class _PrimaryScrollControllerInjectingNavigatorState extends State<PrimaryScrollControllerInjectingNavigator> {
	final _primaryScrollControllerTracker = ValueNotifier<ScrollController?>(null);
	late InjectingNavigator _navigator;

	Widget _injectController(BuildContext context, Route? route, WidgetBuilder childBuilder) {
		final topRoute = ((widget.navigatorKey.currentState) as _InjectingNavigatorState?)?.topRoute;
		return AnimatedBuilder(
			animation: Listenable.merge([
				_primaryScrollControllerTracker,
				topRoute
			]),
			builder: (context, child) {
				final bestController = _primaryScrollControllerTracker.value;
				final automaticController = PrimaryScrollController.of(context)!;
				return PrimaryScrollController(
					controller: (route != topRoute?.value || bestController == null) ? automaticController : bestController,
					child: child!
				);
			},
			child: Builder(builder: childBuilder)
		);
	}

	InjectingNavigator _makeNavigator() => InjectingNavigator(
		animation: _primaryScrollControllerTracker,
		injector: _injectController,
		initialRoute: '/',
		observers: widget.observers,
		key: widget.navigatorKey,
		onGenerateRoute: (settings) {
			return FullWidthCupertinoPageRoute(
				settings: settings,
				builder: (context) => _injectController(context, null, widget.buildRoot),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			);
		}
	);

	@override
	void initState() {
		super.initState();
		_navigator = _makeNavigator();
	}

	@override
	void didUpdateWidget(PrimaryScrollControllerInjectingNavigator oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.navigatorKey != oldWidget.navigatorKey) {
			_navigator = _makeNavigator();
		}
	}

	@override
	Widget build(BuildContext context) {
		_primaryScrollControllerTracker.value = PrimaryScrollController.of(context);
		return _navigator;
	}
}