import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

class RxStreamBuilder<T> extends StatelessWidget {
	final T? initialData;
	final Stream<T> stream;
	final AsyncWidgetBuilder<T> builder;
	
	RxStreamBuilder({
		required this.stream,
		required this.builder,
		this.initialData
	});

	@override
	Widget build(BuildContext context) {
		return StreamBuilder(
			initialData: initialData ?? (stream is ValueStream<T> ? (stream as ValueStream<T>).valueOrNull : null),
			stream: stream,
			builder: builder
		);
	}
}