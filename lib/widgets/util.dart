import 'dart:async';
import 'dart:ui';

import 'package:chan/models/attachment.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/cupertino_page_route.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ActionableException implements Exception {
	final String message;
	final Map<String, VoidCallback> actions;
	const ActionableException({
		required this.message,
		required this.actions
	});

	@override
	String toString() => 'ActionableException(message: $message, ${actions.length} actions)';
}

Future<void> alertError(BuildContext context, String error, {
	Map<String, VoidCallback> actions = const {},
	bool barrierDismissible = false
}) async {
	await showCupertinoDialog(
		context: context,
		barrierDismissible: barrierDismissible,
		builder: (context) {
			return CupertinoAlertDialog(
				title: const Text('Error'),
				content: Text(error),
				actions: [
					for (final action in actions.entries) CupertinoDialogAction(
						onPressed: action.value,
						child: Text(action.key)
					),
					CupertinoDialogAction(
						child: const Text('OK'),
						onPressed: () {
							Navigator.of(context).pop();
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
	required IconData icon,
	bool hapticFeedback = true
}) {
	if (hapticFeedback) {
		lightHapticFeedback();
	}
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
					Flexible(
						child: Text(
							message,
							style: TextStyle(
								color: CupertinoTheme.of(context).primaryColor
							)
						)
					)
				]
			)
		)
	);
}

Future<T> modalLoad<T>(BuildContext context, String title, Future<T> Function() work, {wait = Duration.zero}) async {
	final rootNavigator = Navigator.of(context, rootNavigator: true);
	final timer = Timer(wait, () {
		showCupertinoDialog(
			context: context,
			barrierDismissible: false,
			builder: (context) => CupertinoAlertDialog(
				title: Text(title),
				content: const Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						SizedBox(height: 8),
						LinearProgressIndicator()
					]	
				)
			)
		);
	});
	try {
		return await work();
	}
	finally {
		if (timer.isActive) {
			timer.cancel();
		}
		else {
			rootNavigator.pop();
		}
	}
}

String formatTime(DateTime time) {
	final now = DateTime.now();
	final notToday = (now.day != time.day) || (now.month != time.month) || (now.year != time.year);
	String prefix = '';
	const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	if (notToday) {
		if (now.difference(time).inDays > 7) {
			prefix = '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ';
		}
		else {
			prefix = '${days[time.weekday]} ';
		}
	}
	return '$prefix${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}

String formatRelativeTime(DateTime time) {
	final diff = time.difference(DateTime.now()).abs();
	String timeDiff = '';
	if (diff.inDays > 365) {
		timeDiff = '${diff.inDays ~/ 365}y';
	}
	else if (diff.inDays > 30) {
		timeDiff = '${diff.inDays ~/ 30}mo';
	}
	else if (diff.inDays > 0) {
		timeDiff = '${diff.inDays}d';
	}
	else if (diff.inHours > 0) {
		timeDiff = '${diff.inHours}h';
	}
	else if (diff.inMinutes > 0) {
		timeDiff = '${diff.inMinutes}m';
	}
	else {
		timeDiff = '${(diff.inMilliseconds / 1000).round()}s';
	}
	if (time.isAfter(DateTime.now())) {
		timeDiff = 'in $timeDiff';
	}
	return timeDiff;
}

String formatDuration(Duration d) {
	return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class TransparentRoute<T> extends PageRoute<T> {
	final bool showAnimations;
	final bool? showAnimationsForward;
	TransparentRoute({
		required this.builder,
		RouteSettings? settings,
		required this.showAnimations,
		this.showAnimationsForward
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
	Duration get transitionDuration => (showAnimationsForward ?? showAnimations) ? const Duration(milliseconds: 150) : Duration.zero;

	@override
	Duration get reverseTransitionDuration => showAnimations ? const Duration(milliseconds: 150) : Duration.zero;

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
			child: Persistence.settings.blurEffects ? BackdropFilter(
				filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
				child: child
			) : child
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
					Flexible(
						child: Text(
							message,
							style: TextStyle(color: CupertinoTheme.of(context).scaffoldBackgroundColor),
							textAlign: TextAlign.center,
							overflow: TextOverflow.fade
						)
					),
					for (final remedy in remedies.entries) ...[
						const SizedBox(height: 8),
						CupertinoButton(
							color: CupertinoTheme.of(context).scaffoldBackgroundColor,
							onPressed: remedy.value,
							child: Text(remedy.key, style: TextStyle(
								color: CupertinoTheme.of(context).primaryColor
							), textAlign: TextAlign.center)
						)
					]
				]
			)
		);
	}
}

Future<void> openBrowser(BuildContext context, Uri url, {bool fromShareOne = false, bool useCooperativeBrowser = false}) async {
	if (url.host.isEmpty && url.scheme.isEmpty) {
		url = url.replace(
			scheme: 'https',
			host: context.read<Imageboard?>()?.site.baseUrl,
		);
	}
	final webmMatcher = RegExp('https?://${context.read<ImageboardSite?>()?.imageUrl}/([^/]+)/([0-9]+).webm');
	final match = webmMatcher.firstMatch(url.toString());
	if (match != null) {
		final String board = match.group(1)!;
		final String id = match.group(2)!;
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
					md5: '',
					width: null,
					height: null,
					sizeInBytes: null,
					threadId: null
				)
			],
			semanticParentIds: []
		);
	}
	else {
		final settings = context.read<EffectiveSettings>();
		final imageboardTarget = await modalLoad(context, 'Checking url...', () => ImageboardRegistry.instance.decodeUrl(url.toString()), wait: const Duration(milliseconds: 50));
		openInChance() {
			(context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(FullWidthCupertinoPageRoute(
				builder: (ctx) => ImageboardScope(
					imageboardKey: null,
					imageboard: imageboardTarget!.$1,
					child: imageboardTarget.$2.threadId == null ? BoardPage(
						initialBoard: imageboardTarget.$1.persistence.getBoard(imageboardTarget.$2.board),
						semanticId: -1
					) : ThreadPage(
						thread: imageboardTarget.$2.threadIdentifier!,
						initialPostId: imageboardTarget.$2.postId,
						initiallyUseArchive: imageboardTarget.$3,
						boardSemanticId: -1
					)
				),
				showAnimations: context.read<EffectiveSettings>().showAnimations
			));
		}
		if (Persistence.settings.hostsToOpenExternally.any((s) => url.host.endsWith(s))) {
			if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
				launchUrl(url, mode: LaunchMode.externalApplication);
			}
		}
		else if (settings.useInternalBrowser == null && !fromShareOne) {
			if (context.mounted) {
				shareOne(
					context: context,
					text: url.toString(),
					type: "text",
					sharePositionOrigin: null,
					additionalOptions: {
						if (imageboardTarget != null) 'Open in Chance': openInChance
					}
				);
			}
		}
		else if ((isOnMac && !useCooperativeBrowser && imageboardTarget == null) || settings.useInternalBrowser == false || (url.scheme != 'http' && url.scheme != 'https')) {
			launchUrl(url, mode: LaunchMode.externalApplication);
		}
		else if (imageboardTarget != null && !fromShareOne) {
			openInChance();
		}
		else if (context.mounted) {
			if (useCooperativeBrowser) {
				final fakeAttachment = Attachment(
					type: AttachmentType.url,
					board: '',
					id: '',
					ext: '',
					filename: '',
					url: url,
					thumbnailUrl: Uri.https('thumbs.chance.surf', '/', {
						'url': url.toString()
					}),
					md5: '',
					width: null,
					height: null,
					sizeInBytes: null,
					threadId: null
				);
				showGallery(
					context: context,
					attachments: [fakeAttachment],
					allowChrome: false,
					semanticParentIds: [],
					fullscreen: false,
					allowScroll: false
				);
			}
			else {
				try {
					await ChromeSafariBrowser().open(url: WebUri.uri(url), settings: ChromeSafariBrowserSettings(
						toolbarBackgroundColor: CupertinoTheme.of(context).barBackgroundColor,
						preferredBarTintColor: CupertinoTheme.of(context).barBackgroundColor,
						preferredControlTintColor: CupertinoTheme.of(context).primaryColor
					));
				}
				on PlatformException {
					await launchUrl(url);
				}
			}
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
		hsv = hsv.withHue((hsv.hue + offset) % 360);
		return hsv.toColor();
	}
	Color shiftSaturation(double offset) {
		HSVColor hsv = HSVColor.fromColor(this);
		hsv = hsv.withSaturation((hsv.saturation * (1 + offset)).clamp(0, 1));
		return hsv.toColor();
	}
	Color withSaturation(double saturation) {
		HSVColor hsv = HSVColor.fromColor(this);
		hsv = hsv.withSaturation(saturation);
		return hsv.toColor();
	}
	Color withMinValue(double value) {
		HSVColor hsv = HSVColor.fromColor(this);
		if (hsv.value >= value) {
			return this;
		}
		hsv = hsv.withValue(value);
		return hsv.toColor();
	}
}

Color colorToHex(String hexString) {
	final buffer = StringBuffer();
	if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
	buffer.write(hexString.replaceFirst('#', ''));
	return Color(int.parse(buffer.toString(), radix: 16));
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
			Future.delayed(Duration.zero, () {
				if (!mounted) return;
				setState(() {});
			});
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
			duration: widget.duration
		);
	}

	@override
	void didUpdateWidget(Expander oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.expanded && !oldWidget.expanded) {
			animation.forward();
		}
		else if (!widget.expanded && oldWidget.expanded) {
			animation.reverse();
		}
		else if (widget.duration != oldWidget.duration) {
			animation.duration = widget.duration;
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
					height: widget.curve.transform(animation.value) * widget.height,
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
		animation.dispose();
		super.dispose();
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

class RootCustomScale extends StatefulWidget {
	final double scale;
	final Widget child;
	const RootCustomScale({
		required this.scale,
		required this.child,
		Key? key
	}) : super(key: key);

	@override
	createState() => _RootCustomScaleState();
}

class _RootCustomScaleState extends State<RootCustomScale> {
	final _childKey = GlobalKey();
	@override
	Widget build(BuildContext context) {
		final child = KeyedSubtree(
			key: _childKey,
			child: widget.child
		);
		if (widget.scale == 1) {
			return child;
		}
		final mq = MediaQuery.of(context);
    return FractionallySizedBox(
      widthFactor: 1 * widget.scale,
      heightFactor: 1 * widget.scale,
      child: Transform.scale(
        scale: 1 / widget.scale,
        child: MediaQuery(
					data: mq.copyWith(
						viewInsets: mq.viewInsets * widget.scale,
						systemGestureInsets: mq.systemGestureInsets * widget.scale,
						viewPadding: mq.viewPadding * widget.scale,
						padding: mq.padding * widget.scale
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

class MaybeCupertinoScrollbar extends StatelessWidget {
	final Widget child;
	final ScrollController? controller;

	const MaybeCupertinoScrollbar({
		required this.child,
		this.controller,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<EffectiveSettings>();
		if (settings.showScrollbars) {
			return CupertinoScrollbar(
				controller: controller,
				scrollbarOrientation: settings.scrollbarsOnLeft ? ScrollbarOrientation.left : null,
				child: child
			);
		}
		return child;
	}
}

class _RenderTrulyUnconstrainedBox extends RenderProxyBox {
	_RenderTrulyUnconstrainedBox();
  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints.copyWith(maxHeight: double.infinity), parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = computeSizeForNoChild(constraints);
    }
  }
}

class _TrulyUnconstrainedBox extends SingleChildRenderObjectWidget {
	const _TrulyUnconstrainedBox({
		Key? key,
		required Widget child
	}) : super(key: key, child: child);

	@override
	_RenderTrulyUnconstrainedBox createRenderObject(BuildContext context) {
		return _RenderTrulyUnconstrainedBox();
	}
}

class ClippingBox extends StatelessWidget {
	final Widget child;
	const ClippingBox({
		Key? key,
		required this.child
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ClipRect(
			child: _TrulyUnconstrainedBox(
				child: child
			)
		);
	}
}

Future<void> editStringList({
	required BuildContext context,
	required List<String> list,
	required String name,
	required String title
}) async {
	await showCupertinoDialog(
		barrierDismissible: true,
		context: context,
		builder: (context) => CupertinoAlertDialog(
			title: Padding(
				padding: const EdgeInsets.only(bottom: 16),
				child: Text(title)
			),
			content: StatefulBuilder(
				builder: (context, setDialogState) => SizedBox(
					width: 100,
					height: 350,
					child: Stack(
						children: [
							ListView.builder(
								padding: const EdgeInsets.only(bottom: 128),
								itemCount: list.length,
								itemBuilder: (context, i) => Padding(
									padding: const EdgeInsets.all(4),
									child: GestureDetector(
										onTap: () async {
											final controller = TextEditingController(text: list[i]);
											controller.selection = TextSelection(baseOffset: 0, extentOffset: list[i].length);
											final newItem = await showCupertinoDialog<String>(
												context: context,
												barrierDismissible: true,
												builder: (context) => CupertinoAlertDialog(
													title: Text('Edit $name'),
													content: CupertinoTextField(
														autofocus: true,
														autocorrect: false,
														enableIMEPersonalizedLearning: false,
														smartDashesType: SmartDashesType.disabled,
														smartQuotesType: SmartQuotesType.disabled,
														controller: controller,
														onSubmitted: (s) => Navigator.pop(context, s)
													),
													actions: [
														CupertinoDialogAction(
															child: const Text('Cancel'),
															onPressed: () => Navigator.pop(context)
														),
														CupertinoDialogAction(
															isDefaultAction: true,
															child: const Text('Change'),
															onPressed: () => Navigator.pop(context, controller.text)
														)
													]
												)
											);
											if (newItem != null) {
												list[i] = newItem;
												setDialogState(() {});
											}
											controller.dispose();
										},
										child: Container(
											decoration: BoxDecoration(
												borderRadius: const BorderRadius.all(Radius.circular(4)),
												color: CupertinoTheme.of(context).primaryColor.withOpacity(0.1)
											),
											padding: const EdgeInsets.only(left: 16),
											child: Row(
												children: [
													Expanded(
														child: Text(list[i], style: const TextStyle(fontSize: 15), textAlign: TextAlign.left)
													),
													CupertinoButton(
														child: const Icon(CupertinoIcons.delete),
														onPressed: () {
															list.removeAt(i);
															setDialogState(() {});
														}
													)
												]
											)
										)
									)
								)
							),
							Align(
								alignment: Alignment.bottomCenter,
								child: ClipRect(
									child: BackdropFilter(
										filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
											child: Container(
											color: CupertinoTheme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													CupertinoButton(
														child: Row(
															mainAxisAlignment: MainAxisAlignment.center,
															children: [
																const Icon(CupertinoIcons.add),
																Text(' Add $name')
															]
														),
														onPressed: () async {
															final controller = TextEditingController();
															final newItem = await showCupertinoDialog<String>(
																context: context,
																barrierDismissible: true,
																builder: (context) => CupertinoAlertDialog(
																	title: Text('New $name'),
																	content: CupertinoTextField(
																		autofocus: true,
																		controller: controller,
																		autocorrect: false,
																		enableIMEPersonalizedLearning: false,
																		smartDashesType: SmartDashesType.disabled,
																		smartQuotesType: SmartQuotesType.disabled,
																		onSubmitted: (s) => Navigator.pop(context, s)
																	),
																	actions: [
																		CupertinoDialogAction(
																			child: const Text('Cancel'),
																			onPressed: () => Navigator.pop(context)
																		),
																		CupertinoDialogAction(
																			isDefaultAction: true,
																			child: const Text('Add'),
																			onPressed: () => Navigator.pop(context, controller.text)
																		)
																	]
																)
															);
															if (newItem != null) {
																list.add(newItem);
																setDialogState(() {});
															}
															controller.dispose();
														}
													)
												]
											)
										)
									)
								)
							)
						]
					)
				)
			),
			actions: [
				CupertinoDialogAction(
					child: const Text('Close'),
					onPressed: () => Navigator.pop(context)
				)
			]
		)
	);
}

class ConditionalTapGestureRecognizer extends TapGestureRecognizer {
	bool Function(PointerDownEvent) condition;

	ConditionalTapGestureRecognizer({
		required this.condition,
		super.debugOwner,
		super.supportedDevices
	});

	@override
	bool isPointerAllowed(PointerDownEvent event) {
		return super.isPointerAllowed(event) && condition(event);
	}
}

class ConditionalOnTapUp extends StatefulWidget {
	final Widget child;
	final bool Function(PointerDownEvent) condition;
	final GestureTapUpCallback onTapUp;

	const ConditionalOnTapUp({
		required this.child,
		required this.condition,
		required this.onTapUp,
		super.key
	});

	@override
	createState() => _ConditionalOnTapUpState();
}

class _ConditionalOnTapUpState extends State<ConditionalOnTapUp> {
	late final ConditionalTapGestureRecognizer recognizer;

	@override
	void initState() {
		super.initState();
		recognizer = ConditionalTapGestureRecognizer(
			debugOwner: this,
			condition: widget.condition
		)..onTapUp = widget.onTapUp;
	}

	@override
	void didUpdateWidget(ConditionalOnTapUp oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.condition != oldWidget.condition) {
			recognizer.condition = widget.condition;
		}
		if (widget.onTapUp != oldWidget.onTapUp) {
			recognizer.onTapUp = widget.onTapUp;
		}
	}

	@override
	Widget build(BuildContext context) {
		return Listener(
			onPointerDown: recognizer.addPointer,
			child: widget.child
		);
	}

	@override
	void dispose() {
		super.dispose();
		recognizer.dispose();
	}
}

extension HasOnePosition on ScrollController {
	// ignore: INVALID_USE_OF_PROTECTED_MEMBER
	bool get hasOnePosition => positions.length == 1;
}

Future<bool> confirm(BuildContext context, String message) async {
	return (await showCupertinoDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => CupertinoAlertDialog(
			title: Text(message),
			actions: [
				CupertinoDialogAction(
					child: const Text('Cancel'),
					onPressed: () {
						Navigator.of(context).pop();
					}
				),
				CupertinoDialogAction(
					isDefaultAction: true,
					onPressed: () {
						Navigator.of(context).pop(true);
					},
					child: const Text('OK')
				)
			]
		)
	)) ?? false;
}
