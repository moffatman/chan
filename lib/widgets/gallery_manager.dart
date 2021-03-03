import 'dart:async';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:flutter/cupertino.dart';

Future<Attachment?> showGallery({
	required BuildContext context,
	required List<Attachment> attachments,
	required List<int> semanticParentIds,
	Attachment? initialAttachment,
	bool initiallyShowChrome = false,
	ValueChanged<Attachment>? onChange,
}) {
	return Navigator.of(context, rootNavigator: true).push(TransparentRoute<Attachment>(
		builder: (BuildContext _context) {
			return GalleryPage(
				attachments: attachments,
				initialAttachment: initialAttachment,
				initiallyShowChrome: initiallyShowChrome,
				onChange: onChange,
				semanticParentIds: semanticParentIds
			);
		}
	));
}

class TransparentRoute<T> extends PageRoute<T> {
	TransparentRoute({
		required this.builder,
		RouteSettings? settings,
  	}) : super(settings: settings, fullscreenDialog: false);

	final WidgetBuilder builder;

	@override
	bool get opaque => false;

	@override
	Color? get barrierColor => null;

	@override
	String? get barrierLabel => null;

	@override
	bool get maintainState => true;

	@override
	Duration get transitionDuration => Duration(milliseconds: 150);

	@override
  	Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
		final result = builder(context);
		return FadeTransition(
			opacity: Tween<double>(begin: 0, end: 1).animate(animation),
			child: Semantics(
				scopesRoute: true,
				explicitChildNodes: true,
				child: result,
			)
		);
	}
}