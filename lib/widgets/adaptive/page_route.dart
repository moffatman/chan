import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:flutter/material.dart';

class _MaterialPageRoute<T> extends MaterialPageRoute<T> {
	final bool? showAnimations;
	final bool? showAnimationsForward;

	_MaterialPageRoute({
		required super.builder,
		required super.settings,
		this.showAnimations,
		this.showAnimationsForward
	});

	@override
	Duration get transitionDuration =>
		((showAnimationsForward ?? showAnimations) ?? Persistence.settings.showAnimations) ? const Duration(milliseconds: 300) : Duration.zero;

	@override
	Duration get reverseTransitionDuration =>
		(showAnimations ?? Persistence.settings.showAnimations) ? const Duration(milliseconds: 300) : Duration.zero;
}

PageRoute<T> adaptivePageRoute<T>({
	required WidgetBuilder builder,
	RouteSettings? settings,
	bool? showAnimations,
	bool? showAnimationsForward,
	bool useFullWidthGestures = true
}) {
	if (Settings.instance.materialRoutes) {
		return _MaterialPageRoute<T>(
			builder: builder,
			settings: settings,
			showAnimations: showAnimations,
			showAnimationsForward: showAnimationsForward
		);
	}
	return FullWidthCupertinoPageRoute<T>(
		builder: builder,
		settings: settings,
		showAnimations: showAnimations,
		showAnimationsForward: showAnimationsForward,
		useFullWidthGestures: useFullWidthGestures
	);
}