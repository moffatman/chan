import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/services/is_on_mac.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> alertError(BuildContext context, String error) async {
	await showCupertinoDialog(
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

void showToast({
	required BuildContext context,
	required String message,
	required IconData icon
}) {
	FToast().init(context).showToast(
		child: Container(
			padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(24),
				color: CupertinoTheme.of(context).primaryColorWithBrightness(0.2)
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(icon, color: CupertinoTheme.of(context).primaryColor),
					const SizedBox(width: 12),
					Text(message, style: TextStyle(color: CupertinoTheme.of(context).primaryColor))
				]
			)
		)
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
	final bool showAnimations;
	TransparentRoute({
		required this.builder,
		RouteSettings? settings,
		required this.showAnimations
  	}) : super(settings: settings);
	
	@override
  bool get barrierDismissible => false;

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
	Duration get transitionDuration => showAnimations ? const Duration(milliseconds: 150) : Duration.zero;

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
		return FadeTransition(
			opacity: animation,
			child: BackdropFilter(
				filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
				child: child
			)
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

Future<void> openBrowser(BuildContext context, Uri url) async {
	final webmMatcher = RegExp('https?://${context.read<ImageboardSite>().imageUrl}/([^/]+)/([0-9]+).webm');
	final match = webmMatcher.firstMatch(url.toString());
	if (match != null) {
		final String board = match.group(1)!;
		final int id = int.parse(match.group(2)!);
		await showGallery(
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
		if (await isOnMac()) {
			launch(url.toString());
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
	Color shiftHue(double offset) {
		HSVColor hsv = HSVColor.fromColor(this);
		hsv = hsv.withHue(hsv.hue + offset % 360);
		return hsv.toColor();
	}
	Color shiftSaturation(double offset) {
		HSVColor hsv = HSVColor.fromColor(this);
		hsv = hsv.withSaturation((hsv.saturation + offset).clamp(0, 1));
		return hsv.toColor();
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

class Expander extends StatefulWidget {
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
	createState() => _ExpanderState();
}

class _ExpanderState extends State<Expander> with TickerProviderStateMixin {
	late final AnimationController animation;

	@override
	void initState() {
		super.initState();
		animation = AnimationController(
			value: widget.expanded ? 1.0 : 0.0,
			vsync: this,
			duration: const Duration(milliseconds: 300)
		);
	}

	@override
	void didUpdateWidget(Expander oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.expanded && !oldWidget.expanded) {
			animation.forward(from: 0.0);
		}
		else if (!widget.expanded && oldWidget.expanded) {
			animation.reverse(from: 1.0);
		}
	}

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			bottom: !widget.bottomSafe,
			child: AnimatedBuilder(
				animation: animation,
				builder: (context, _) => SizedBox(
					height: Curves.ease.transform(animation.value) * widget.height,
					child: Stack(
						clipBehavior: Clip.hardEdge,
						children: [
							Positioned(
								top: 0,
								left: 0,
								right: 0,
								child: SizedBox(
									height: widget.height,
									child: widget.child
								)
							)
						]
					)
				)
			)
		);
	}

	@override
	void dispose() {
		super.dispose();
		animation.dispose();
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
		final mq = MediaQuery.of(context);
    return FractionallySizedBox(
      widthFactor: 1 * scale,
      heightFactor: 1 * scale,
      child: Transform.scale(
        scale: 1 / scale,
        child: MediaQuery(
					data: mq.copyWith(
						viewInsets: mq.viewInsets * scale,
						systemGestureInsets: mq.systemGestureInsets * scale,
						viewPadding: mq.viewPadding * scale,
						padding: mq.padding * scale
					),
					child: child
				)
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

class BenchmarkBuilder extends StatelessWidget {
	final WidgetBuilder builder;

	const BenchmarkBuilder({
		required this.builder,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final start = DateTime.now();
		final child = builder(context);
		return Stack(
			children: [
				child,
				Container(
					color: CupertinoTheme.of(context).scaffoldBackgroundColor,
					child: Text('${DateTime.now().difference(start).inMicroseconds / 1000} ms')
				)
			]
		);
	}
}

class TransformedMediaQuery extends StatelessWidget {
	final Widget child;
	final MediaQueryData Function(MediaQueryData) transformation;

	const TransformedMediaQuery({
		required this.child,
		required this.transformation,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return MediaQuery(
			data: transformation(MediaQuery.of(context)),
			child: child
		);
	}
}
