import 'dart:async';

import 'package:flutter/widgets.dart';

class TimedRebuilder extends StatefulWidget {
	final Duration interval;
	final WidgetBuilder builder;
	final bool enabled;
	const TimedRebuilder({
		required this.interval,
		required this.builder,
		required this.enabled,
		Key? key
	}) : super(key: key);
	@override
	createState() => _TimedRebuilderState();
}

class _TimedRebuilderState extends State<TimedRebuilder> {
	late final Timer timer;
	@override
	void initState() {
		super.initState();
		timer = Timer.periodic(widget.interval, (_) => {
			if (mounted && widget.enabled) setState(() {})
		});
	}
	@override
	void dispose() {
		super.dispose();
		timer.cancel();
	}

	@override
	Widget build(BuildContext context) {
		return widget.builder(context);
	}
}