import 'dart:async';

import 'package:flutter/widgets.dart';

class TimedRebuilder<T> extends StatefulWidget {
	final Duration Function() interval;
	final Widget Function(BuildContext, T) builder;
	final bool enabled;
	final T Function() function;

	const TimedRebuilder({
		required this.interval,
		required this.builder,
		required this.function,
		this.enabled = true,
		Key? key
	}) : super(key: key);

	@override
	createState() => _TimedRebuilderState<T>();
}

class _TimedRebuilderState<T> extends State<TimedRebuilder<T>> {
	Timer? timer;
	late final ValueNotifier<T> notifier;

	Timer _makeTimer() => Timer(widget.interval(), () {
		if (mounted) {
			notifier.value = widget.function();
			if (widget.enabled) {
				timer = _makeTimer();
			}
		}
	});

	@override
	void initState() {
		super.initState();
		notifier = ValueNotifier(widget.function());
		if (widget.enabled) {
			timer = _makeTimer();
		}
	}
	
	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		final tickerMode = TickerMode.of(context);
		if (tickerMode && widget.enabled && timer == null) {
			// Update and reactivate
			notifier.value = widget.function();
			timer = _makeTimer();
		}
		else if (!tickerMode && timer != null) {
			// Deactivate
			timer?.cancel();
			timer = null;
		}
	}

	@override
	void didUpdateWidget(TimedRebuilder<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.enabled && !oldWidget.enabled) {
			// Update and reactivate
			notifier.value = widget.function();
			timer?.cancel();
			timer = _makeTimer();
		}
		else if (!widget.enabled && oldWidget.enabled) {
			// Deactivate
			timer?.cancel();
			timer = null;
		}
	}

	@override
	void dispose() {
		super.dispose();
		timer?.cancel();
	}

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: notifier,
			builder: (context, v, _) => widget.builder(context, v)
		);
	}
}