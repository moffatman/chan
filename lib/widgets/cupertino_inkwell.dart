import 'dart:async';

import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class CupertinoInkwell<T> extends StatefulWidget {
  /// Creates an iOS-style button.
  const CupertinoInkwell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.minSize = kMinInteractiveDimensionCupertino,
    this.pressedOpacity = 0.4,
    this.alignment = Alignment.center,
    required this.onPressed,
  }) : assert(pressedOpacity == null || (pressedOpacity >= 0.0 && pressedOpacity <= 1.0));

  final Widget child;
  final EdgeInsetsGeometry padding;
  final FutureOr<T> Function()? onPressed;
  final double? minSize;
  final double? pressedOpacity;
  final AlignmentGeometry alignment;
  bool get enabled => onPressed != null;

  @override
  State<CupertinoInkwell> createState() => _CupertinoInkwellState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
  }
}

class _CupertinoInkwellState extends State<CupertinoInkwell> with SingleTickerProviderStateMixin {
  // Eyeballed values. Feel free to tweak.
  static const Duration kFadeOutDuration = Duration(milliseconds: 120);
  static const Duration kFadeInDuration = Duration(milliseconds: 180);
  final Tween<double> _opacityTween = Tween<double>(begin: 1.0);

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  late bool isFocused;

  @override
  void initState() {
    super.initState();
    isFocused = false;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      value: 0.0,
      vsync: this,
    );
    _opacityAnimation = _animationController
      .drive(CurveTween(curve: Curves.decelerate))
      .drive(_opacityTween);
    _setTween();
  }

  @override
  void didUpdateWidget(CupertinoInkwell old) {
    super.didUpdateWidget(old);
    _setTween();
  }

  void _setTween() {
    _opacityTween.end = widget.pressedOpacity ?? 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _buttonHeldDown = false;

  void _handleTapDown(TapDownDetails event) {
    if (!_buttonHeldDown) {
      _buttonHeldDown = true;
      _animate();
    }
  }

  void _handleTapUp(TapUpDetails event) {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _handleTapCancel() {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _animate() {
    if (_animationController.isAnimating) {
      return;
    }
    final bool wasHeldDown = _buttonHeldDown;
    final TickerFuture ticker = _buttonHeldDown
        ? _animationController.animateTo(1.0, duration: kFadeOutDuration, curve: Curves.easeInOutCubicEmphasized)
        : _animationController.animateTo(0.0, duration: kFadeInDuration, curve: Curves.easeOutCubic);
    ticker.then<void>((void value) {
      if (mounted && wasHeldDown != _buttonHeldDown) {
        _animate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null ? null : () async {
			try {
				await widget.onPressed?.call();
			}
			catch (e, st) {
				Future.error(e, st);
				if (context.mounted) {
					alertError(context, e, st);
				}
			}
		};
    final bool enabled = widget.enabled;

    return MouseRegion(
      cursor: enabled && kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
				behavior: HitTestBehavior.opaque,
				onTapDown: enabled ? _handleTapDown : null,
				onTapUp: enabled ? _handleTapUp : null,
				onTapCancel: enabled ? _handleTapCancel : null,
				onTap: onPressed,
				child: Semantics(
					button: true,
					child: ConstrainedBox(
						constraints: widget.minSize == null
							? const BoxConstraints()
							: BoxConstraints(
									minWidth: widget.minSize!,
									minHeight: widget.minSize!,
								),
						child: FadeTransition(
							opacity: _opacityAnimation,
							child: Padding(
								padding: widget.padding,
								child: Align(
									alignment: widget.alignment,
									widthFactor: 1.0,
									heightFactor: 1.0,
									child: widget.child,
								),
							),
						),
					),
				),
      ),
    );
  }
}
