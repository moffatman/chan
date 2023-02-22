import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
class InjectingNavigator extends Navigator {
	final Listenable animation;
	final Widget Function(BuildContext, WidgetBuilder) injector;
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
	late final ValueNotifier<Route?> topRoute;

	@override
	void initState() {
		super.initState();
		topRoute = ValueNotifier<Route?>(null);
	}

	@override
	Future<T?> push<T extends Object?>(Route<T> route) {
		_routeStack.add(route);
		topRoute.value = route;
		if (route is FullWidthCupertinoPageRoute<T> && widget is InjectingNavigator) {
			return super.push(FullWidthCupertinoPageRoute<T>(
				settings: route.settings,
				builder: (context) => (widget as InjectingNavigator).injector(context, route.builder),
				showAnimationsForward: route.showAnimationsForward,
				showAnimations: route.showAnimations
			));
		}
		return super.push(route);
	}

	@override
	void pop<T extends Object?>([T? result]) {
		if (_routeStack.isNotEmpty) {
			_routeStack.removeLast();
			topRoute.value = _routeStack.isEmpty ? null : _routeStack.last;
		}
		super.pop(result);
	}

	/// Allow input to bottom route during transition.
	@override
	bool get overrideShouldIgnoreFocusRequest => false;

	@override
	void dispose() {
		super.dispose();
		topRoute.dispose();
	}
}

class _MyPopListener extends PopEntry<dynamic> {
	final ValueChanged<dynamic> onPop;
	_MyPopListener(this.onPop);
	@override
	ValueListenable<bool> get canPopNotifier => const ConstantValueListenable(true);
	@override
	void onPopInvoked(bool didPop) {
		onPop(null);
	}
	@override
	void onPopInvokedWithResult(bool didPop, dynamic result) {
		onPop(result);
	}
}

class PrimaryScrollControllerInjectingNavigator extends StatefulWidget {
	final List<NavigatorObserver> observers;
	final WidgetBuilder buildRoot;
	final (WidgetBuilder builder, ValueChanged<dynamic> onPop)? buildInitialAboveRoot;
	final GlobalKey<NavigatorState> navigatorKey;
	const PrimaryScrollControllerInjectingNavigator({
		this.observers = const [],
		required this.buildRoot,
		this.buildInitialAboveRoot,
		required this.navigatorKey,
		Key? key
	}) : super(key: key);
	@override
	createState() => PrimaryScrollControllerInjectingNavigatorState();
}

class PrimaryScrollControllerInjectingNavigatorState extends State<PrimaryScrollControllerInjectingNavigator> {
	late final ValueNotifier<ScrollController?> primaryScrollControllerTracker;
	late InjectingNavigator _navigator;

	Widget _injectController(BuildContext context, WidgetBuilder childBuilder) {
		final route = ModalRoute.of(context);
		final topRoute = ((widget.navigatorKey.currentState) as _InjectingNavigatorState?)?.topRoute;
		return AnimatedBuilder(
			animation: Listenable.merge([
				primaryScrollControllerTracker,
				topRoute
			]),
			builder: (context, child) {
				final bestController = primaryScrollControllerTracker.value;
				final automaticController = PrimaryScrollController.of(context);
				return PrimaryScrollController(
					controller: (route != topRoute?.value || bestController == null) ? automaticController : bestController,
					child: child!
				);
			},
			child: Builder(builder: childBuilder)
		);
	}

	static const _kInitialAboveRoot = '/iar';

	InjectingNavigator _makeNavigator() => InjectingNavigator(
		animation: primaryScrollControllerTracker,
		injector: _injectController,
		initialRoute: widget.buildInitialAboveRoot != null ? _kInitialAboveRoot : '/',
		observers: widget.observers,
		key: widget.navigatorKey,
		onGenerateRoute: (settings) {
			if (settings.name == _kInitialAboveRoot) {
				return adaptivePageRoute(
					settings: settings,
					builder: (context) => _injectController(context, widget.buildInitialAboveRoot!.$1),
					showAnimationsForward: false
				)..registerPopEntry(_MyPopListener(widget.buildInitialAboveRoot!.$2));
			}
			return adaptivePageRoute(
				settings: settings,
				builder: (context) => _injectController(context, widget.buildRoot)
			);
		}
	);

	@override
	void initState() {
		super.initState();
		primaryScrollControllerTracker = ValueNotifier<ScrollController?>(null);
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
		primaryScrollControllerTracker.value = PrimaryScrollController.maybeOf(context);
		return _navigator;
	}

	@override
	void dispose() {
		super.dispose();
		primaryScrollControllerTracker.dispose();
	}
}