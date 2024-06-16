import 'dart:math';

import 'package:chan/widgets/sliver_staggered_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class StaggeredGridDebuggingPage extends StatelessWidget {
	const StaggeredGridDebuggingPage({
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return CustomScrollView(
			slivers: [
				SliverStaggeredGrid(
					delegate:  SliverChildBuilderDelegate(
						(context, i) {
							return _HeightGrowingWidget(i);
						},
						childCount: 1000
					),
					gridDelegate: const SliverStaggeredGridDelegateWithMaxCrossAxisExtent(
						maxCrossAxisExtent: 300
					)
				)
			]
		);
	}
}

class _HeightGrowingWidget extends StatefulWidget {
	final int index;

	const _HeightGrowingWidget(this.index);

	@override
	createState() => _HeightGrowingWidgetState();
}

class _HeightGrowingWidgetState extends State<_HeightGrowingWidget> with SingleTickerProviderStateMixin {
	late final AnimationController controller;

	@override
	void initState() {
		super.initState();
		controller = AnimationController(vsync: this);
		controller.repeat(min: 0, max: 1, period: Duration(milliseconds: 2000 + (widget.index.hashCode % 2000)), reverse: true);
	}

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: controller,
			builder: (context, child) => SizedBox(
				height: 200 * (1 + sin(controller.value)) + (widget.index.hashCode % 5) * 20,
				child: child
			),
			child: Container(
				color: HSVColor.fromAHSV(1, widget.index.hashCode.toDouble() % 360, 0.5, 0.2).toColor(),
				alignment: Alignment.center,
				child: Text('${widget.index}')
			)
		);
	}

	@override
	void dispose() {
		controller.dispose();
		super.dispose();
	}
}
