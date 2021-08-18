import 'dart:math';

import 'package:flutter/gestures.dart';
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
	final GlobalKey _childKey = GlobalKey();
	late double _scrollStopPosition;
	Offset? _pointerDownPosition;
	bool _pointerInSpacer = false;
	double _opacity = 1;
	bool _popping = false;

	@override
	void initState() {
		super.initState();
		_scrollStopPosition = -150.0 - widget.heightEstimate;
		_controller = ScrollController(initialScrollOffset: _scrollStopPosition);
		_controller.addListener(_onScrollUpdate);
	}

	// To fix behavior when stopping the scroll-in with tap event
	void _onScrollUpdate() {
		if (!_popping) {
			final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
			final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
			final double desiredOpacity = 1 - (((max(overscrollTop, overscrollBottom) + _scrollStopPosition) - 40) / 200).clamp(0, 1);
			if (desiredOpacity != _opacity) {
				setState(() {
					_opacity = desiredOpacity;
				});
			}
		}
		if (_scrollStopPosition != 0 && _controller.position.pixels > _scrollStopPosition) {
			_scrollStopPosition = _controller.position.pixels;
			// Stop when coming to intial rest (since start position is largely negative)
			if (_scrollStopPosition > -2) {
				_scrollStopPosition = 0;
			}
		}
	}

	void _onPointerUp() {
		if (_popping) {
			return;
		}
		final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
		final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
		if (max(overscrollTop, overscrollBottom) > 50 - _scrollStopPosition) {
			_popping = true;
			Navigator.of(context).pop();
		}
		else if (_pointerInSpacer) {
			_popping = true;
			// Simulate onTap for the Spacers which fill the transparent space
			// It's done here rather than using GestureDetector so it works during scroll-in
			Navigator.of(context).pop();
		}
	}

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) => Stack(
				fit: StackFit.expand,
				children: [
					Container(
						color: widget.backgroundColor
					),
					NotificationListener<ScrollNotification>(
						onNotification: (notification) {
							if ((notification is ScrollEndNotification) || (notification is ScrollUpdateNotification && notification.dragDetails == null)) {
								_onPointerUp();
							}
							return false;
						},
						child: Listener(
							onPointerDown: (event) {
								final RenderBox childBox = _childKey.currentContext!.findRenderObject()! as RenderBox;
								_pointerDownPosition = event.position;
								_pointerInSpacer = event.position.dy < childBox.localToGlobal(childBox.semanticBounds.topCenter).dy || event.position.dy > childBox.localToGlobal(childBox.semanticBounds.bottomCenter).dy;
							},
							onPointerMove: (event) {
								if (_pointerInSpacer) {
									if ((event.position - _pointerDownPosition!).distance > kTouchSlop) {
										_pointerInSpacer = false;
									}
								}
							},
							onPointerUp: (event) => _onPointerUp(),
							child: Actions(
								actions: {
									DismissIntent: CallbackAction<DismissIntent>(
										onInvoke: (i) => Navigator.of(context).pop()
									)
								},
								child: Focus(
									autofocus: true,
									child: CustomScrollView(
										controller: _controller,
										physics: AlwaysScrollableScrollPhysics(),
										slivers: [
											SliverToBoxAdapter(
												child: ConstrainedBox(
													constraints: BoxConstraints(
														minHeight: constraints.maxHeight
													),
													child: Center(
														child: SafeArea(
															child: Opacity(
																key: _childKey,
																opacity: _opacity,
																child: widget.child
															)
														)
													)
												)
											)
										]
									)
								)
							)
						)
					)
				]
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_controller.dispose();
	}
}