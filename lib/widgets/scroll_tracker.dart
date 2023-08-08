import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class ScrollTracker {
	final isScrolling = ValueNotifier<bool>(false);
	final slowScrollDirection = ValueNotifier<VerticalDirection?>(null);
	VerticalDirection _lastNonNullDirection = VerticalDirection.up;
	VerticalDirection get lastNonNullDirection {
		return slowScrollDirection.value ?? _lastNonNullDirection;
	}
	double _accumulatedScrollDelta = 0;
	bool _thisScrollHasDragDetails = false;

	ScrollTracker._() {
		slowScrollDirection.addListener(_onSlowScrollDirectionChange);
	}

	void _onSlowScrollDirectionChange() {
		_lastNonNullDirection = slowScrollDirection.value ?? _lastNonNullDirection;
	}

	static ScrollTracker? _instance;
	static ScrollTracker get instance {
		return _instance ??= ScrollTracker._();
	}

	bool onNotification(ScrollNotification notification) {
		if (notification is ScrollStartNotification) {
			isScrolling.value = true;
			_thisScrollHasDragDetails = false;
		}
		else if (notification is ScrollEndNotification) {
			isScrolling.value = false;
			if (notification.metrics.extentAfter < 100 && notification.metrics.extentBefore > 500) {
				// At the bottom of the scroll view. Probably we want to show stuff again.
				slowScrollDirection.value = VerticalDirection.up;
			}
			slowScrollDirection.value = null;
		}
		else if (notification is ScrollUpdateNotification) {
			_thisScrollHasDragDetails |= notification.dragDetails != null;
			if (notification.metrics.axis == Axis.vertical && _thisScrollHasDragDetails && notification.metrics.extentAfter > 100) {
				final delta = notification.scrollDelta ?? 0;
				if ((notification.metrics.pixels > notification.metrics.minScrollExtent || delta < 0) &&
				    (notification.metrics.pixels < notification.metrics.maxScrollExtent || delta > 0)) {
					_accumulatedScrollDelta += delta;
				}
				_accumulatedScrollDelta = _accumulatedScrollDelta.clamp(-51, 51);
				if (_accumulatedScrollDelta > 50 && slowScrollDirection.value != VerticalDirection.down) {
					_accumulatedScrollDelta = 0;
					slowScrollDirection.value = VerticalDirection.down;
				}
				else if (_accumulatedScrollDelta < -50 && slowScrollDirection.value != VerticalDirection.up) {
					_accumulatedScrollDelta = 0;
					slowScrollDirection.value = VerticalDirection.up;
				}
			}
		}
		return false;
	}

	void navigatorDidPush() {
		slowScrollDirection.value = VerticalDirection.up;
		isScrolling.value = false;
	}

	void navigatorDidPop() {
		slowScrollDirection.value = VerticalDirection.up;
		isScrolling.value = false;
	}

	void weakNavigatorDidPush() {
		isScrolling.value = false;
	}

	void weakNavigatorDidPop() {
		isScrolling.value = false;
	}

	void dispose() {
		isScrolling.dispose();
		slowScrollDirection.dispose();
	}
}

class AncestorScrollBuilder extends StatefulWidget {
	final Widget Function(BuildContext context, VerticalDirection direction) builder;

	const AncestorScrollBuilder({
		required this.builder,
		super.key
	});

	@override
	createState() => _AncestorScrollBuilderState();
}

class _AncestorScrollBuilderState extends State<AncestorScrollBuilder> {
	late VerticalDirection direction;

	void _onSlowScrollDirectionChange() async {
		direction = ScrollTracker.instance.slowScrollDirection.value ?? direction;
		await SchedulerBinding.instance.endOfFrame;
		if (mounted) {
			setState(() {});
		}
	}

	@override
	void initState() {
		super.initState();
		direction = ScrollTracker.instance.lastNonNullDirection;
		ScrollTracker.instance.slowScrollDirection.addListener(_onSlowScrollDirectionChange);
	}

	@override
	Widget build(BuildContext context) {
		return widget.builder(context, direction);
	}

	@override
	void dispose() {
		super.dispose();
		ScrollTracker.instance.slowScrollDirection.removeListener(_onSlowScrollDirectionChange);
	}
}

class ScrollTrackerNavigatorObserver extends NavigatorObserver {
	@override
	void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
		ScrollTracker.instance.navigatorDidPush();
	}

	@override
	void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
		ScrollTracker.instance.navigatorDidPop();
	}
}