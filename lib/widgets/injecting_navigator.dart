import 'package:chan/widgets/cupertino_page_route.dart';
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
	final _primaryScrollControllerTracker = ValueNotifier<ScrollController?>(null);

	@override
	Future<T?> push<T extends Object?>(Route<T> route) {
		if (route is FullWidthCupertinoPageRoute<T> && widget is InjectingNavigator) {
			return super.push(FullWidthCupertinoPageRoute<T>(
				settings: route.settings,
				builder: (context) => (widget as InjectingNavigator).injector(context, route.builder)
			));
		}
		return super.push(route);
	}

	@override
	Widget build(BuildContext context) {
		_primaryScrollControllerTracker.value = PrimaryScrollController.of(context);
		return super.build(context);
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

	Widget _injectController(BuildContext context, WidgetBuilder childBuilder) {
		return ValueListenableBuilder(
			valueListenable: _primaryScrollControllerTracker,
			builder: (context, ScrollController? controller, child) {
				if (controller == null) {
					return Builder(builder: childBuilder);
				}
				else {
					return PrimaryScrollController(
						controller: controller,
						child: Builder(builder: childBuilder)
					);
				}
			}
		);
	}

	@override
	Widget build(BuildContext context) {
		_primaryScrollControllerTracker.value = PrimaryScrollController.of(context);
		return InjectingNavigator(
			animation: _primaryScrollControllerTracker,
			injector: _injectController,
			initialRoute: '/',
			observers: widget.observers,
			key: widget.navigatorKey,
			onGenerateRoute: (settings) {
				return FullWidthCupertinoPageRoute(
					settings: settings,
					builder: (context) => _injectController(context, widget.buildRoot)
				);
			}
		);
	}
}