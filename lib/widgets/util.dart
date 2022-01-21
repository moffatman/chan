import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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
	Duration get transitionDuration => const Duration(milliseconds: 150);

	@override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
		return Semantics(
			scopesRoute: true,
			explicitChildNodes: true,
			child: builder(context)
		);
	}

	@override
	Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
		return AnimatedBuilder(
			animation: animation,
			builder: (context, child) {
				return BackdropFilter(
					filter: ImageFilter.blur(sigmaX: animation.value * 5, sigmaY: animation.value * 5),
					child: Opacity(
						opacity: animation.value,
						child: child
					)
				);
			},
			child: child
		);
	}
}

class TrulyTransparentRoute<T> extends PageRoute<T> {
	TrulyTransparentRoute({
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
	Duration get transitionDuration => const Duration(milliseconds: 150);

	@override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
		final result = builder(context);
		return FadeTransition(
			opacity: animation,
			child: Semantics(
				scopesRoute: true,
				explicitChildNodes: true,
				child: result
			)
		);
	}
}

class ErrorMessageCard extends StatelessWidget {
	final String message;
	final Map<String, VoidCallback> remedies;

	const ErrorMessageCard(this.message, {
		this.remedies = const {},
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: CupertinoTheme.of(context).primaryColor,
				borderRadius: const BorderRadius.all(Radius.circular(8))
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoTheme.of(context).scaffoldBackgroundColor),
					const SizedBox(height: 8),
					Text(message, maxLines: 20, style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor), textAlign: TextAlign.center),
					for (final remedy in remedies.entries) ...[
						const SizedBox(height: 8),
						CupertinoButton(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							child: Text(remedy.key, style: TextStyle(
								color: CupertinoTheme.of(context).primaryColor
							)),
							onPressed: remedy.value
						)
					]
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
					type: AttachmentType.webm,
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

extension ReduceBrightness on CupertinoThemeData {
	Color primaryColorWithBrightness(double factor) {
		return Color.fromRGBO(
			((primaryColor.red * factor) + (scaffoldBackgroundColor.red * (1 - factor))).round(),
			((primaryColor.green * factor) + (scaffoldBackgroundColor.green * (1 - factor))).round(),
			((primaryColor.blue * factor) + (scaffoldBackgroundColor.blue * (1 - factor))).round(),
			primaryColor.opacity
		);
	}
}

extension OffsetBrightness on Color {
	Color towardsWhite(double factor) {
		return Color.fromRGBO(
			red + ((255 - red) * factor).round(),
			green + ((255 - green) * factor).round(),
			blue + ((255 - blue) * factor).round(),
			opacity
		);
	}
	Color towardsBlack(double factor) {
		return Color.fromRGBO(
			(red * (1 - factor)).round(),
			(green * (1 - factor)).round(),
			(blue * (1 - factor)).round(),
			opacity
		);
	}
}

class FirstBuildDetector extends StatefulWidget {
	final Object identifier;
	final Widget Function(BuildContext, bool) builder;

	const FirstBuildDetector({
		required this.identifier,
		required this.builder,
		Key? key
	}) : super(key: key);

	@override
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

class Expander extends StatelessWidget {
	final Widget child;
	final Duration duration;
	final Curve curve;
	final double height;
	final bool expanded;
	final bool bottomSafe;

	const Expander({
		required this.child,
		this.duration = const Duration(milliseconds: 300),
		this.curve = Curves.ease,
		required this.height,
		required this.expanded,
		this.bottomSafe = false,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			bottom: !bottomSafe,
			child: AnimatedContainer(
				curve: Curves.ease,
				alignment: Alignment.topCenter,
				duration: const Duration(milliseconds: 300),
				height: expanded ? height : 0,
				child: Stack(
					clipBehavior: Clip.hardEdge,
					children: [
						Positioned(
							top: 0,
							left: 0,
							right: 0,
							child: SizedBox(
								height: height,
								child: child
							)
						)
					]
				)
			)
		);
	}
}

InlineSpan buildFakeMarkdown(BuildContext context, String input) {
	return TextSpan(
		children: input.split('`').asMap().entries.map((t) => TextSpan(
			text: t.value,
			style: t.key % 2 == 0 ? null : GoogleFonts.ibmPlexMono(
				backgroundColor: CupertinoTheme.of(context).primaryColor,
				color: CupertinoTheme.of(context).scaffoldBackgroundColor
			)
		)).toList()
	);
}

class RootCustomScale extends StatelessWidget {
	final double scale;
	final Widget child;
	const RootCustomScale({
		required this.scale,
		required this.child,
		Key? key
	}) : super(key: key);
	@override
	Widget build(BuildContext context) {
		if (scale == 1) {
			return child;
		}
    return FractionallySizedBox(
      widthFactor: 1 * scale,
      heightFactor: 1 * scale,
      child: Transform.scale(
        scale: 1 / scale,
        child: child
			)
		);
	}
}

class MQCustomScale extends StatelessWidget {
	final double scale;
	final Widget child;
	const MQCustomScale({
		required this.scale,
		required this.child,
		Key? key
	}) : super(key: key);
	@override
	Widget build(BuildContext context) {
		final mq = MediaQuery.of(context);
    return MediaQuery(
			data: mq.copyWith(
				viewInsets: mq.viewInsets * scale,
				padding: mq.padding * scale,
				viewPadding: mq.viewPadding * scale,
				systemGestureInsets: mq.systemGestureInsets * scale,
				size: mq.size / scale
			),
			child: child
		);
	}
}