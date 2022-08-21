import 'dart:math';

import 'package:tuple/tuple.dart';
import 'package:flutter/cupertino.dart';

class _CircularLoadingIndicatorPainter extends CustomPainter {
	final double startValue;
	final double endValue;
	final Color color;

	_CircularLoadingIndicatorPainter({
		required this.startValue,
		required this.endValue,
		required this.color
	});

	@override
	void paint(Canvas canvas, Size size) {
		final startAngle = (startValue % 1) * 2 * pi;
		double endAngle = (endValue % 1) * 2 * pi;
		if (startAngle > endAngle || (endValue == 1.0 && startValue == 0.0)) {
			endAngle += 2 * pi;
		}

		canvas.saveLayer(Offset.zero & size, Paint());
		final Paint paint = Paint()..color = color;
		final center = Offset(size.width / 2, size.height / 2);
		final rect = Rect.fromCenter(center: center, width: size.height, height: size.height);
		canvas.drawCircle(center, size.height / 2, paint);
		canvas.drawCircle(center, size.height / 2 - 4, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.25)..blendMode = BlendMode.src);
		canvas.drawArc(
			rect,
			(-pi / 2) + startAngle,
			endAngle - startAngle,
			true,
			paint..blendMode = BlendMode.src
		);
		canvas.restore();
	}

	@override
	bool shouldRepaint(_CircularLoadingIndicatorPainter old) => true;
}
class CircularLoadingIndicator extends StatefulWidget {
	final double? value;
	final Color? color;
	const CircularLoadingIndicator({
		this.value,
		this.color,
		Key? key
	}) : super(key: key);

	@override
	createState() => _CircularLoadingIndicatorState();
}

class _CircularLoadingIndicatorState extends State<CircularLoadingIndicator> with TickerProviderStateMixin {
	static const double _continuousSweepAngle = 1 / 6;
	static const int _periodMs = 1000;
	late AnimationController _startValueController;
	bool _startValueControllerDisposed = false;
	late AnimationController _endValueController;
	bool _endValueControllerDisposed = false;

	void _startValueControllerDispose() {
		if (!_startValueControllerDisposed) {
			_startValueControllerDisposed = true;
			_startValueController.dispose();
		}
	}

	void _replaceStartValueController(AnimationController newController) {
		_startValueControllerDispose();
		_startValueController = newController;
		_startValueControllerDisposed = false;
	}

	void _endValueControllerDispose() {
		if (!_endValueControllerDisposed) {
			_endValueControllerDisposed = true;
			_endValueController.dispose();
		}
	}

	void _replaceEndValueController(AnimationController newController) {
		_endValueControllerDispose();
		_endValueController = newController;
		_endValueControllerDisposed = false;
	}

	@override
	void initState() {
		super.initState();
		_startValueController = AnimationController(
			vsync: this
		);
		_startValueController.reset();
		_endValueController = AnimationController(
			vsync: this
		);
		_endValueController.reset();
		if (widget.value != null) {
			_transitionToFixed(widget.value!, 0);
		}
		else {
			_transitionToContinuous();
		}
	}

	double get _startValue => _startValueController.value % 1;
	double get _endValue => _endValueController.value % 1;
	double get _sweepAngle => _endValue - _startValue;

	AnimationController _continuousAnimation(double from) {
		final a = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: _periodMs)
		);
		a.forward(from: from);
		a.stop();
		a.repeat(
			period: const Duration(milliseconds: _periodMs)
		);
		return a;
	}

	Tuple2<AnimationController, Future<void>> _constantVelocityAnimation(double from, double to, {bool reversed = false}) {
		double dest = reversed ? to : (to >= from) ? to : to + 1;
		final a = AnimationController(
			vsync: this,
			duration: Duration(milliseconds: ((dest - from).abs() * _periodMs).round()),
			lowerBound: reversed ? dest : from,
			upperBound: reversed ? from : dest
		);
		a.reset();
		return Tuple2(
			a,
			(reversed ? a.reverse() : a.forward()).orCancel.catchError((e) => {})
		);
	}

	Future<void> _transitionToFixed(double value, double lastValue) async {
		if (value < lastValue) {
			await _transitionToContinuous();
			if (!mounted) return;
		}
		// continue animate both start and end forward
		// when startAngle reaches 0, stop that motion
		// when endAngle reaches value, stop that motion
		Tuple2<AnimationController, Future<void>>? s;
		Tuple2<AnimationController, Future<void>>? e;
		if (_startValue != 0) {
			s = _constantVelocityAnimation(_startValue, 0, reversed: _startValue < value);
			_replaceStartValueController(s.item1);
		}
		if (_endValue != value) {
			e = _constantVelocityAnimation(_endValue, value);
			_replaceEndValueController(e.item1);
		}
		setState(() {});
		await s?.item2;
		if (!mounted) return;
		await e?.item2;
		if (!mounted) return;
	}

	Future<void> _transitionToContinuous() async {
		// animate startAngle forward until sweepAngle <= _CONTINUOUS_SWEEP_ANGLE
		// animate endAngle forward until sweepAngle >= _CONTINUOUS_SWEEP_ANGLE
		// animate both angles forward
		if (_sweepAngle - _continuousSweepAngle > 0.001) {
			final x = _constantVelocityAnimation(_startValue, _endValue - _continuousSweepAngle);
			_replaceStartValueController(x.item1);
			setState(() {});
			await x.item2;
			if (!mounted) return;
		}
		if (_continuousSweepAngle - _sweepAngle > 0.001) {
			final x = _constantVelocityAnimation(_endValue, _startValue + _continuousSweepAngle);
			_replaceEndValueController(x.item1);
			setState(() {});
			await x.item2;
			if (!mounted) return;
		}
		if (mounted) {
			_replaceStartValueController(_continuousAnimation(_startValue));
			_replaceEndValueController(_continuousAnimation(_endValue));
			setState(() {});
		}
	}

	@override
	void didUpdateWidget(CircularLoadingIndicator old) {
		super.didUpdateWidget(old);
		if (widget.value != null) {
			_transitionToFixed(widget.value!, old.value ?? 0);
		}
		else if (old.value != null) {
			_transitionToContinuous();
		}
	}

	@override
	void dispose() {
		_startValueControllerDispose();
		_endValueControllerDispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: _startValueController,
			builder: (context, child) => AnimatedBuilder(
				animation: _endValueController,
				builder: (context, child) => CustomPaint(
					size: const Size(50, 50),
					painter: _CircularLoadingIndicatorPainter(
						startValue: _startValueController.value % 1,
						endValue: _endValueController.value,
						color: widget.color ?? CupertinoTheme.of(context).primaryColor
					)
				)
			)
		);
	}
}