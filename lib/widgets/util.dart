import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

extension NoThrowingProvider on BuildContext {
	T? watchOrNull<T>() {
		try {
			return Provider.of<T>(this);
		}
		on ProviderNotFoundException {
			return null;
		}
	}
	T? readOrNull<T>() {
		try {
			return Provider.of<T>(this, listen: false);
		}
		on ProviderNotFoundException {
			return null;
		}
	}
}

void alertError(BuildContext context, String error) {
  	showCupertinoDialog(
		context: context,
		builder: (_context) {
			return CupertinoAlertDialog(
				title: const Text('Error'),
				content: Text(error),
				actions: [
					CupertinoDialogAction(
						child: const Text('OK'),
						onPressed: () {
							Navigator.of(_context).pop();
						}
					)
				]
			);
		}
	);
}

String formatTime(DateTime time) {
	final now = DateTime.now();
	final notToday = (now.day != time.day) || (now.month != time.month) || (now.year != time.year);
	String prefix = '';
	const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	if (notToday) {
		if (now.difference(time).inDays > 7) {
			prefix = time.year.toString() + '-' + time.month.toString().padLeft(2, '0') + '-' + time.day.toString().padLeft(2, '0') + ' ';
		}
		else {
			prefix = days[time.weekday] + ' ';
		}
	}
	return prefix + time.hour.toString().padLeft(2, '0') + ':' + time.minute.toString().padLeft(2, '0') + ':' + time.second.toString().padLeft(2, '0');
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

class ErrorMessageCard extends StatelessWidget {
	final String message;
	ErrorMessageCard(this.message);

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).primaryColor,
				borderRadius: BorderRadius.all(Radius.circular(8))
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(Icons.error, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
					SizedBox(height: 8),
					Text(message, style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor), textAlign: TextAlign.center),
				]
			)
		);
	}
}

Future<void> openBrowser(BuildContext context, Uri url) {
	final webmMatcher = RegExp('https?://${context.read<ImageboardSite>().imageUrl}/([^/]+)/([0-9]+).webm');
	final match = webmMatcher.firstMatch(url.toString());
	if (match != null) {
		final String board = match.group(1)!;
		final int id = int.parse(match.group(2)!);
		return showGallery(
			context: context,
			attachments: [
				Attachment(
					type: AttachmentType.WEBM,
					board: board,
					id: id,
					ext: '.webm',
					filename: '$id.webm',
					url: url,
					thumbnailUrl: Uri.https(context.read<ImageboardSite>().imageUrl, '/$board/${id}s.jpg'),
					md5: ''
				)
			],
			semanticParentIds: []
		);
	}
	else {
		return ChromeSafariBrowser().open(url: url, options: ChromeSafariBrowserClassOptions(
			android: AndroidChromeCustomTabsOptions(
				toolbarBackgroundColor: CupertinoTheme.of(context).barBackgroundColor
			),
			ios: IOSSafariOptions(
				preferredBarTintColor: CupertinoTheme.of(context).barBackgroundColor,
				preferredControlTintColor: CupertinoTheme.of(context).primaryColor
			)
		));
	}
}

extension ReduceBrightness on Color {
	Color withBrightness(double factor) {
		return Color.fromRGBO(
			((this.red * factor) + ((255 - this.red) * (1 - factor))).round(),
			((this.green * factor) + ((255 - this.green) * (1 - factor))).round(),
			((this.blue * factor) + ((255 - this.blue) * (1 - factor))).round(),
			this.opacity
		);
	}
}

class FirstBuildDetector extends StatefulWidget {
	final Object identifier;
	final Widget Function(BuildContext, bool) builder;

	FirstBuildDetector({
		required this.identifier,
		required this.builder
	});

	createState() => _FirstBuildDetectorState();
}

class _FirstBuildDetectorState extends State<FirstBuildDetector> {
	bool passedFirstBuild = false;

	@override
	void didUpdateWidget(FirstBuildDetector old) {
		super.didUpdateWidget(old);
		if (widget.identifier != old.identifier) {
			passedFirstBuild = false;
		}
	}

	@override
	Widget build(BuildContext context) {
		Widget child = widget.builder(context, passedFirstBuild);
		if (!passedFirstBuild) {
			passedFirstBuild = true;
			Future.delayed(Duration.zero, () => setState(() {}));
		}
		return child;
	}
}