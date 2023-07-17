import 'dart:async';

import 'package:flutter/widgets.dart';

class TimedRebuilder<T> extends StatefulWidget {
	final Duration interval;
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
	late final Timer timer;
	late final ValueNotifier<T> notifier;

	@override
	void initState() {
		super.initState();
		notifier = ValueNotifier(widget.function());
		timer = Timer.periodic(widget.interval, (_) {
			if (mounted && widget.enabled) {
				notifier.value = widget.function();
			}
		});
	}

	@override
	void dispose() {
		super.dispose();
		timer.cancel();
	}

	@override
	Widget build(BuildContext context) {
		return ValueListenableBuilder(
			valueListenable: notifier,
			builder: (context, v, _) => widget.builder(context, v)
		);
	}
}