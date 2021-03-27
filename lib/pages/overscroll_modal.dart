import 'dart:math';

import 'package:flutter/material.dart';

class OverscrollModalPage extends StatefulWidget {
	final Widget child;
	final double heightEstimate;
	final Color backgroundColor;

	OverscrollModalPage({
		required this.child,
		this.heightEstimate = 0,
		this.backgroundColor = Colors.black38
	});

	@override
	createState() => _OverscrollModalPageState();
}

class _OverscrollModalPageState extends State<OverscrollModalPage> {
	late final ScrollController _controller;
	final GlobalKey _topSpacerKey = GlobalKey();
	final GlobalKey _bottomSpacerKey = GlobalKey();
	late double _scrollStopPosition;
	Duration? _pointerDownTime;

	@override
	void initState() {
		super.initState();
		_scrollStopPosition = -150.0 - widget.heightEstimate;
		_controller = ScrollController(initialScrollOffset: _scrollStopPosition);
		_controller.addListener(_onScrollUpdate);
	}

	// To fix behavior when stopping the scroll-in with tap event
	void _onScrollUpdate() {
		if (_controller.position.pixels > _scrollStopPosition) {
			_scrollStopPosition = _controller.position.pixels;
			// Stop when coming to intial rest (since start position is largely negative)
			if (_scrollStopPosition > -2) {
				_scrollStopPosition = 0;
				_controller.removeListener(_onScrollUpdate);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			fit: StackFit.expand,
			children: [
				Container(
					color: widget.backgroundColor
				),
				SafeArea(
					child: Listener(
						onPointerDown: (event) {
							_pointerDownTime = event.timeStamp;
						},
						onPointerUp: (event) {
							final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
							final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
							if (max(overscrollTop, overscrollBottom) > 50 - _scrollStopPosition) {
								Navigator.of(context).pop();
							}
							else if (_pointerDownTime != null) {
								// Simulate onTap for the Spacers which fill the transparent space
								// It's done here rather than using GestureDetector so it works during scroll-in
								if ((event.timeStamp - _pointerDownTime!).inMilliseconds < 125) {
									final RenderBox topBox = _topSpacerKey.currentContext!.findRenderObject()! as RenderBox;
									final RenderBox bottomBox = _bottomSpacerKey.currentContext!.findRenderObject()! as RenderBox;
									if (event.position.dy < topBox.localToGlobal(topBox.semanticBounds.bottomCenter).dy || event.position.dy > bottomBox.localToGlobal(bottomBox.semanticBounds.topCenter).dy) {
										Navigator.of(context).pop();
									}
								}
							}
						},
						child: CustomScrollView(
							controller: _controller,
							physics: AlwaysScrollableScrollPhysics(),
							slivers: [
								SliverFillRemaining(
									hasScrollBody: false,
									child: Column(
										children: [
											Flexible(
												key: _topSpacerKey,
												child: Container()
											),
											widget.child,
											Flexible(
												key: _bottomSpacerKey,
												child: Container()
											)
										]
									)
								)
							]
						)
					)
				)
			]
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
	}
}