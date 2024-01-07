import 'dart:math';

import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/util.dart';
import 'package:chan/widgets/sliver_center.dart';
import 'package:chan/widgets/util.dart';
import 'package:chan/widgets/weak_navigator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _kLongPressToPopAllTime = Duration(milliseconds: 500);

class OverscrollModalPage extends StatefulWidget {
	final Widget? child;
	final Widget? sliver;
	final double heightEstimate;
	final Color backgroundColor;
	final Widget? background;
	final bool allowScroll;
	final bool reverse;
	final ValueChanged<AxisDirection>? onPop;

	const OverscrollModalPage({
		required this.child,
		this.background,
		this.heightEstimate = 0,
		this.backgroundColor = Colors.black38,
		this.allowScroll = true,
		this.reverse = false,
		this.onPop,
		super.key
	}) : sliver = null;

	const OverscrollModalPage.sliver({
		required this.sliver,
		this.background,
		this.heightEstimate = 0,
		this.backgroundColor = Colors.black38,
		this.allowScroll = true,
		this.reverse = false,
		this.onPop,
		super.key
	}) : child = null;

	@override
	createState() => _OverscrollModalPageState();
}

class _OverscrollModalPageState extends State<OverscrollModalPage> {
	late final ScrollController _controller;
	final GlobalKey _scrollKey = GlobalKey(debugLabel: '_OverscrollModalPageState._scrollKey');
	final GlobalKey _childKey = GlobalKey(debugLabel: '_OverscrollModalPageState._childKey');
	final GlobalKey _childWidgetKey = GlobalKey(debugLabel: '_OverscrollModalPageState._childWidgetKey');
	late double _scrollStopPosition;
	final Map<int, (Offset position, bool initiallyInSpacer, DateTime globalTime)> _pointersDown = {};
	late final ValueNotifierAnimation<double> _opacity;
	bool _popping = false;
	bool _finishedPopIn = false;

	@override
	void initState() {
		super.initState();
		_opacity = ValueNotifierAnimation(1);
		_scrollStopPosition = -1 * min(150.0 + widget.heightEstimate, context.findAncestorWidgetOfExactType<MediaQuery>()!.data.size.height / 2);
		_controller = ScrollController(initialScrollOffset: context.read<EffectiveSettings>().showAnimations ? _scrollStopPosition : 0);
		_controller.addListener(_onScrollUpdate);
	}

	// To fix behavior when stopping the scroll-in with tap event
	void _onScrollUpdate() {
		if (!_popping) {
			final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
			final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
			_opacity.value = 1 - (((max(overscrollTop, overscrollBottom) + _scrollStopPosition) - 40) / 100).clamp(0, 1);
		}
		if (!_finishedPopIn && _scrollStopPosition != 0 && _controller.position.pixels > _scrollStopPosition) {
			_scrollStopPosition = _controller.position.pixels;
			// Stop when coming to intial rest (since start position is largely negative)
			if (_scrollStopPosition > -0.2) {
				_scrollStopPosition = 0;
				setState(() {
					_finishedPopIn = true;
				});
			}
		}
	}

	void _onPointerDown(PointerEvent event) {
		final RenderBox scrollBox = _scrollKey.currentContext!.findRenderObject()! as RenderBox;
		final EdgeInsets childBoxPadding = (_childKey.currentContext?.findRenderObject() as RenderSliverCenter?)?.resolvedPadding ?? EdgeInsets.zero;
		final pixelsVisuallyAbove = widget.reverse ? (_controller.tryPosition?.extentAfter ?? 0) : (_controller.tryPosition?.extentBefore ?? 0);
		final pointerInTopMargin =
			(event.position.dy < scrollBox.localToGlobal(Offset(0, childBoxPadding.top - pixelsVisuallyAbove)).dy);
		final pixelsVisuallyBelow = widget.reverse ? (_controller.tryPosition?.extentBefore ?? 0) : (_controller.tryPosition?.extentAfter ?? 0);
		final pointerInBottomMargin =
			(event.position.dy > scrollBox.localToGlobal(scrollBox.semanticBounds.bottomCenter - Offset(0, childBoxPadding.bottom)).dy + pixelsVisuallyBelow);
		_pointersDown[event.pointer] = (event.position, pointerInTopMargin || pointerInBottomMargin, DateTime.now());
		Future.delayed(_kLongPressToPopAllTime, () {
			if (mounted &&
			    WeakNavigator.of(context) != null &&
			    !context.read<EffectiveSettings>().overscrollModalTapPopsAll &&
					(_pointersDown[event.pointer]?.$2 ?? false)) {
				// Held long enough without moving to pop all
				lightHapticFeedback();
			}
		});
	}

	void _onPointerUp(int pointer) {
		final downData = _pointersDown.remove(pointer);
		if (_popping || _controller.positions.isEmpty || downData == null || _pointersDown.isNotEmpty) {
			return;
		}
		final overscrollTop = _controller.position.minScrollExtent - _controller.position.pixels;
		final overscrollBottom = _controller.position.pixels - _controller.position.maxScrollExtent;
		if (max(overscrollTop, overscrollBottom) > 50 - _scrollStopPosition) {
			_popping = true;
			widget.onPop?.call(((overscrollTop > overscrollBottom) ^ widget.reverse) ? AxisDirection.up : AxisDirection.down);
			WeakNavigator.pop(context);
		}
		else if (downData.$2) {
			_popping = true;
			// Simulate onTap for the Spacers which fill the transparent space
			// It's done here rather than using GestureDetector so it works during scroll-in
			if (WeakNavigator.of(context) != null) {
				if (context.read<EffectiveSettings>().overscrollModalTapPopsAll || DateTime.now().difference(downData.$3) > _kLongPressToPopAllTime) {
					WeakNavigator.of(context)!.popAllExceptFirst(animated: true);
				}
				else {
					WeakNavigator.of(context)!.pop();
				}
			}
			else {
				Navigator.of(context).pop();
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final child = widget.child == null ? null : KeyedSubtree(
			key: _childWidgetKey,
			child: widget.child!
		);
		return Stack(
			fit: StackFit.expand,
			children: [
				RepaintBoundary(
					child: Container(
						color: widget.backgroundColor,
						child: (widget.background == null) ? null : SafeArea(
							top: false,
							bottom: false,
							child: AnimatedBuilder(
								animation: _controller,
								child: widget.background,
								builder: (context, child) {
									final double childBoxTopDiff = (_childKey.currentContext?.findRenderObject() as RenderSliverCenter?)?.resolvedPadding?.top ?? 0;
									final double childBoxBottomDiff = (_childKey.currentContext?.findRenderObject() as RenderSliverCenter?)?.resolvedPadding?.bottom ?? 0;
									double topOverscroll = 0;
									double bottomOverscroll = 0;
									if (_finishedPopIn && _controller.positions.isNotEmpty && _controller.position.isScrollingNotifier.value) {
										topOverscroll = -1 * min(0, _controller.position.pixels);
										bottomOverscroll = max(0, _controller.position.pixels - _controller.position.maxScrollExtent);
									}
									return Stack(
										fit: StackFit.expand,
										children: [
											Positioned(
												top: childBoxTopDiff - topOverscroll,
												bottom: childBoxBottomDiff - bottomOverscroll,
												left: 0,
												right: 0,
												child: Center(
													child: Visibility(
														visible: _finishedPopIn,
														child: ClippingBox(
															child: child!
														)
													)
												)
											)
										]
									);
								}
							)
						)
					)
				),
				RepaintBoundary(
					child: Listener(
						onPointerDown: _onPointerDown,
						onPointerPanZoomStart: _onPointerDown,
						onPointerMove: (event) {
							final downData = _pointersDown[event.pointer];
							if (downData?.$2 == true) {
								if ((event.position - downData!.$1).distance > kTouchSlop) {
									// Moved too far, will no longer pop
									if (WeakNavigator.of(context) != null &&
											!context.read<EffectiveSettings>().overscrollModalTapPopsAll &&
											DateTime.now().difference(downData.$3) > _kLongPressToPopAllTime) {
										// We played the haptic feedback to say it was held long enough
										// Do a double-vibrate to indicate cancel
										lightHapticFeedback();
										Future.delayed(const Duration(milliseconds: 75), lightHapticFeedback);
									}
									_pointersDown[event.pointer] = (downData.$1, false, downData.$3);
								}
							}
						},
						onPointerCancel: (event) {
							_pointersDown.remove(event.pointer);
						},
						onPointerUp: (event) => _onPointerUp(event.pointer),
						onPointerPanZoomEnd: (event) => _onPointerUp(event.pointer),
						child: Actions(
							actions: {
								DismissIntent: CallbackAction<DismissIntent>(
									onInvoke: (i) => WeakNavigator.pop(context)
								)
							},
							child: Focus(
								autofocus: true,
								child: Padding(
									padding: MediaQuery.viewInsetsOf(context),
									child: TransformedMediaQuery(
										transformation: (context, mq) => mq.copyWith(viewInsets: EdgeInsets.zero),
										child: MaybeScrollbar(
											controller: _controller,
											child: CustomScrollView(
												reverse: widget.reverse,
												controller: _controller,
												key: _scrollKey,
												physics: widget.allowScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
												slivers: [
													SliverFadeTransition(
														opacity: _opacity,
														sliver: SliverCenter(
															minimumPadding: MediaQuery.paddingOf(context),
															key: _childKey,
															child: MediaQuery.removePadding(
																context: context,
																removeLeft: true,
																removeRight: true,
																removeTop: true,
																removeBottom: true,
																child: widget.sliver ?? SliverToBoxAdapter(
																	child: ChanceTheme.materialOf(context) ? Material(
																		child: child
																	) : child
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
		_opacity.dispose();
	}
}

class ValueNotifierAnimation<T> extends Animation<T> with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
	T _value;
	ValueNotifierAnimation(this._value);

	@override
	T get value => _value;

	set value(T newValue) {
		if (_value == newValue) {
			return;
		}
		_value = newValue;
		notifyListeners();
	}

	@override
	AnimationStatus get status => AnimationStatus.forward;

	@override
	void didRegisterListener() {}

	@override
	void didUnregisterListener() {}

	void dispose() {
		clearListeners();
		clearStatusListeners();
	}

	@override
	String toString() => 'ValueNotifierAnimation<$T>($value)';
}