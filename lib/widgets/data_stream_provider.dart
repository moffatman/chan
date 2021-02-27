import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'dart:async';

typedef DataStreamBuilderFunction<T> = Widget Function(BuildContext context, T value, Future<void> Function() requestUpdate);
typedef DataStreamErrorBuilderFunction = Widget Function(BuildContext context, Exception error);
typedef DataStreamPlaceholderBuilderFunction<T> = Widget Function(BuildContext context, T value);

class DataProvider<T> extends StatefulWidget {
	final DataStreamBuilderFunction<T> builder;
	final DataStreamPlaceholderBuilderFunction<T> placeholderBuilder;
	final Future<T> Function() updater;
	final DataStreamErrorBuilderFunction errorBuilder;
	final T initialValue;
	final String id;

	DataProvider({
		required this.builder,
		required this.placeholderBuilder,
		required this.errorBuilder,
		required this.updater,
		required this.initialValue,
		required this.id
	});

	@override
	_DataProviderState<T> createState() => _DataProviderState<T>();
}

class _DataProviderState<T> extends State<DataProvider<T>> {
	late T value;
	bool realValuePresent = false;
	Exception? exception;

	@override
	void initState() {
		super.initState();
		value = widget.initialValue;
		realValuePresent = false;
		this.update();
	}

	@override
	void didUpdateWidget(DataProvider<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.id != widget.id) {
			setState(() {
				value = widget.initialValue;
				realValuePresent = false;
				exception = null;
			});
			this.update();
		}
	}

	Future<void> update() async {
		try {
			final newData = await widget.updater();
			setState(() {
				value = newData;
				realValuePresent = true;
				exception = null;
			});
		}
		on Exception catch (e) {
			setState(() {
				this.exception = e;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return (exception != null) ? widget.errorBuilder(context, exception!) : (realValuePresent ? Provider.value(
			value: value,
			child: widget.builder(context, value, update)
		) : widget.placeholderBuilder(context, value));
	}
}