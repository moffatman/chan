import 'package:flutter/widgets.dart';

import 'dart:async';

typedef DataStreamBuilderFunction<T> = Widget Function(BuildContext context, T value, Future<void> Function() requestUpdate);
typedef DataStreamErrorBuilderFunction = Widget Function(BuildContext context, Error error);

class DataProvider<T> extends StatefulWidget {
	final DataStreamBuilderFunction<T> builder;
	final Future<T> Function() updater;
	final Function(Error) onError;
	final T initialValue;

	DataProvider({
		@required this.builder,
		this.onError,
		@required this.updater,
		@required this.initialValue,
	});

	@override
	_DataProviderState createState() => _DataProviderState<T>();
}

class _DataProviderState<T> extends State<DataProvider> {
	T value;

	@override
	void initState() {
		super.initState();
		setState(() {
			value = widget.initialValue;
		});
		this.update();
	}

  @override
  void didUpdateWidget(DataProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
	  if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        value = widget.initialValue;
      });
      this.update();
    }
  }

	Future<void> update() async {
		try {
			final newData = await widget.updater();
			setState(() {
				value = newData;
			});
		}
		catch (error) {
			if (widget.onError != null) {
        print('DataStreamProvider update error');
        print(error);
        widget.onError(error);
      }
		}
	}

	@override
	Widget build(BuildContext context) {
		return widget.builder(context, value, update);
	}
}