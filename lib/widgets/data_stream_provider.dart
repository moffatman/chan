import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'dart:async';

typedef DataStreamBuilderFunction<T> = Widget Function(BuildContext context, T value, Future<void> Function() requestUpdate);
typedef DataStreamErrorBuilderFunction = Widget Function(BuildContext context, String errorMessage, Future<void> Function() requestUpdate);
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
	String? errorMessage;

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
				errorMessage = null;
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
				errorMessage = null;
			});
		}
		catch (e, st) {
			print(e);
			print(st);
			setState(() {
				this.errorMessage = e.toString();
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return (errorMessage != null) ? widget.errorBuilder(context, errorMessage!, update) : (realValuePresent ? Provider.value(
			value: value,
			child: widget.builder(context, value, update)
		) : widget.placeholderBuilder(context, value));
	}
}