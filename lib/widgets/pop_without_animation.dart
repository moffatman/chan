import 'package:flutter/widgets.dart';

mixin PopWithoutAnimation<T> on TransitionRoute<T> {
	bool _skipPopAnimation = false;

	@protected
	Duration get normalReverseTransitionDuration => super.reverseTransitionDuration;

	// Material routes read the duration again in didPop().
	@override
	Duration get reverseTransitionDuration =>
		_skipPopAnimation ? Duration.zero : normalReverseTransitionDuration;

	void popWithoutAnimation() {
		final transition = controller!;
		final reverseDuration = transition.reverseDuration;
		_skipPopAnimation = true;
		transition.reverseDuration = Duration.zero;
		try {
			navigator!.pop<T>();
		} finally {
			// A route can consume the pop through its local history.
			_skipPopAnimation = false;
			transition.reverseDuration = reverseDuration;
		}
	}
}
