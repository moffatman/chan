import 'dart:math';

import 'package:flutter/cupertino.dart';

class _CircularLoadingIndicatorPainter extends CustomPainter {
	final Animation<double> initialAnimation;
	final Animation<double> continuousAnimation;
	final double animationRatio;
	final double? value;
	final Color color;

	_CircularLoadingIndicatorPainter({
		required this.initialAnimation,
		required this.continuousAnimation,
		required this.animationRatio,
		required this.value,
		required this.color
	}) : super(repaint: continuousAnimation);

	@override
	void paint(Canvas canvas, Size size) {
		canvas.saveLayer(Offset.zero & size, Paint());
		final Paint paint = Paint()..color = color;
		final center = Offset(size.width / 2, size.height / 2);
		final rect = Rect.fromCenter(center: center, width: size.height, height: size.height);
		canvas.drawCircle(center, size.height / 2, paint);
		canvas.drawCircle(center, size.height / 2 - 4, Paint()..color = Color.fromRGBO(0, 0, 0, 0.25)..blendMode = BlendMode.src);
		if (value == null) {
			if (initialAnimation.isCompleted) {
				canvas.drawArc(rect, -pi / 2 + (2 * pi * (continuousAnimation.value - animationRatio)), pi / 3, true, paint..blendMode = BlendMode.src);
			}
			else {
				canvas.drawArc(rect, -pi / 2, (pi / 3) * initialAnimation.value, true, paint..blendMode = BlendMode.src);
			}
		}
		else {
			canvas.drawArc(rect, -pi / 2, 2 * pi * value!, true, paint..blendMode = BlendMode.src);
		}
		canvas.restore();
	}

	@override
	bool shouldRepaint(_CircularLoadingIndicatorPainter old) => true;
}
class CircularLoadingIndicator extends StatefulWidget {
	final double? value;
	final Color? color;
	CircularLoadingIndicator({
		this.value,
		this.color
	});

	createState() => _CircularLoadingIndicatorState();
}

class _CircularLoadingIndicatorState extends State<CircularLoadingIndicator> with TickerProviderStateMixin {
	late final AnimationController _continuousController;
	late final AnimationController _initialController;

	@override
	void initState() {
		super.initState();
		_initialController = AnimationController(
			//duration: Duration(milliseconds: 333),
			duration: Duration(milliseconds: 200),
			vsync: this
		);
		_initialController.stop();
		_initialController.reset();
		_initialController.forward();
		_continuousController = AnimationController(
			vsync: this
		);
		_continuousController.stop();
		_continuousController.reset();
		_continuousController.repeat(
			period: Duration(milliseconds: 1200),
		);
	}

	@override
	void dispose() {
		_initialController.dispose();
		_continuousController.dispose();
		super.dispose();
	}

	Widget _build(double? value) {
		return CustomPaint(
			size: Size(50, 50),
			painter: _CircularLoadingIndicatorPainter(
				value: value,
				initialAnimation: _initialController,
				continuousAnimation: _continuousController,
				animationRatio: 1 / 6,
				color: widget.color ?? CupertinoTheme.of(context).primaryColor
			)
		);
	}

	@override Widget build(BuildContext context) {
		return Container(
			child: (widget.value == null) ? _build(widget.value) : TweenAnimationBuilder(
				tween: Tween<double>(begin: 0, end: widget.value),
				curve: Curves.linear,
				duration: const Duration(milliseconds: 150),
				builder: (context, double? smoothedValue, child) => _build(smoothedValue)
			)
		);
	}
}