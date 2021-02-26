import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'dart:async';

typedef DataStreamBuilderFunction<T> = Widget Function(BuildContext context, T value, Future<void> Function() requestUpdate);
typedef DataStreamErrorBuilderFunction = Widget Function(BuildContext context, Exception error);
typedef DataStreamPlaceholderBuilderFunction<T> = Widget Function(BuildContext context, T value);

class DataProvider<T> extends StatefulWidget {
	final DataStreamBuilderFunction<T> builder;
	final DataStreamPlaceholderBuilderFunction<T> placeholder;
	final Future<T> Function() updater;
	final DataStreamErrorBuilderFunction? onError;
	final T initialValue;
	final String id;

	DataProvider({
		required this.builder,
		required this.placeholder,
		this.onError,
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
			});
		}
		on Exception catch (error, stackTrace) {
			print('DataStreamProvider update error');
			print(error);
			print(stackTrace);
			if (widget.onError != null) {
				widget.onError?.call(context, error);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return realValuePresent ? Provider.value(
			value: value,
			child: widget.builder(context, value, update)
		) : widget.placeholder(context, value);
	}
}