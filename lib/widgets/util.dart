import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:chan/main.dart';
import 'package:chan/models/attachment.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/pages/board.dart';
import 'package:chan/pages/gallery.dart';
import 'package:chan/pages/thread.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/report_bug.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/services/thumbnailer.dart';
import 'package:chan/services/translation.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/attachment_thumbnail.dart';
import 'package:chan/widgets/imageboard_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> alert(BuildContext context, String title, String message, {
	Map<String, FutureOr<void> Function()> actions = const {},
	bool barrierDismissible = true
}) async {
	final looksForeign = title.looksForeign || message.looksForeign;
	bool translating = false;
	String? translatedTitle;
	String? translatedMessage;
	final outerContext = context;
	await showAdaptiveDialog(
		context: context,
		barrierDismissible: barrierDismissible,
		builder: (context) => StatefulBuilder(
			builder: (context, setState) => AdaptiveAlertDialog(
				title: Text(translatedTitle ?? title),
				content: Text(translatedMessage ?? message),
				actions: [
					for (final action in actions.entries) AdaptiveDialogAction(
						onPressed: () async {
							Navigator.of(context).pop();
							try {
								await action.value();
							}
							catch (e, st) {
								if (outerContext.mounted) {
									alertError(outerContext, e, st);
								}
								else {
									Future.error(e, st); // crashlytics
								}
							}
						},
						child: Text(action.key)
					),
					if (looksForeign) AdaptiveDialogAction(
						onPressed: translating ? null : () async {
							if (translatedMessage != null) {
								setState(() {
									translatedTitle = null;
									translatedMessage = null;
								});
								return;
							}
							setState(() {
								translating = true;
							});
							try {
								translatedTitle = await translateHtml(title, toLanguage: Settings.instance.translationTargetLanguage);
								translatedMessage = await translateHtml(message, toLanguage: Settings.instance.translationTargetLanguage);
							}
							catch (e, st) {
								Future.error(e, st); // crashlytics
								if (context.mounted) {
									showToast(
										context: context,
										icon: CupertinoIcons.exclamationmark_triangle,
										message: 'Translation failed: ${e.toStringDio()}'
									);
								}
							}
							finally {
								translating = false;
								if (context.mounted) {
									setState(() {});
								}
							}
						},
						child:
							translating ? const CircularProgressIndicator.adaptive() :
								(translatedMessage != null ? const Text('Original') : const Text('Translate'))
					),
					AdaptiveDialogAction(
						child: const Text('OK'),
						onPressed: () {
							Navigator.of(context).pop();
						}
					)
				]
			)
		)
	);
}

Future<void> alertError(BuildContext context, Object error, StackTrace? stackTrace, {
	Map<String, FutureOr<void> Function()> actions = const {},
	bool barrierDismissible = false
}) => alert(context, 'Error', error.toStringDio(), actions: {
	...actions,
	if (error is ExtendedException)
		for (final remedy in error.remedies.entries)
			remedy.key: () => remedy.value(context),
	if (stackTrace != null && !(error is ExtendedException && !error.isReportable)) 'Report bug': () => reportBug(error, stackTrace)
}, barrierDismissible: barrierDismissible);

void showToast({
	required BuildContext context,
	required String message,
	required IconData? icon,
	Widget? iconWidget,
	bool hapticFeedback = true,
	Widget? button,
	(String, VoidCallback)? easyButton,
	Duration duration = const Duration(seconds: 2),
	EdgeInsets padding = EdgeInsets.zero
}) {
	if (hapticFeedback) {
		lightHapticFeedback();
	}
	if (easyButton != null) {
		bool pressed = false;
		button = StatefulBuilder(
			builder: (context, setState) => AdaptiveIconButton(
				padding: EdgeInsets.zero,
				minSize: 0,
				onPressed: pressed ? null : () {
					easyButton.$2();
					setState(() {
						pressed = true;
					});
				},
				icon: Text(easyButton.$1, style: TextStyle(
					color: pressed ? null : Settings.instance.theme.secondaryColor
				))
			)
		);
	}
	final theme = context.read<SavedTheme>();
	FToast().init(context).showToast(
		positionedToastBuilder: (context, child) => Positioned(
			bottom: 114 + padding.bottom,
			left: 24 + padding.left,
			right: 24 + padding.right,
			child: child
		),
		child: Container(
			padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
			decoration: BoxDecoration(
				borderRadius: BorderRadius.circular(24),
				color: theme.primaryColorWithBrightness(0.2)
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (icon != null) Padding(
						padding: const EdgeInsets.only(right: 12),
						child: Icon(icon, color: theme.primaryColor),
					)
					else if (iconWidget != null) Padding(
						padding: const EdgeInsets.only(right: 12),
						child: iconWidget
					),
					Flexible(
						child: Text(
							message,
							style: TextStyle(
								color: theme.primaryColor
							),
							textAlign: TextAlign.center
						)
					),
					if (button != null) ...[
						const SizedBox(width: 12),
						button
					]
				]
			)
		),
		toastDuration: duration
	);
}

void showUndoToast({
	required BuildContext context,
	required String message,
	required VoidCallback onUndo,
	EdgeInsets padding = EdgeInsets.zero
}) => showToast(
	context: context,
	message: message,
	icon: null,
	easyButton: ('Undo', onUndo),
	duration: const Duration(milliseconds: 3500),
	padding: padding
);

class ModalLoadController {
	final progress = ValueNotifier<(String, double?)>(('', null));
	bool cancelled = false;
	VoidCallback? onCancel;

	void cancel() {
		cancelled = true;
		onCancel?.call();
	}

	void dispose() {
		progress.dispose();
	}
}

Future<T> modalLoad<T>(BuildContext context, String title, Future<T> Function(ModalLoadController controller) work, {Duration wait = Duration.zero, bool cancellable = false}) async {
	final rootNavigator = Navigator.of(context, rootNavigator: true);
	final controller = ModalLoadController();
	bool popped = false;
	final timer = Timer(wait, () {
		showAdaptiveDialog(
			context: context,
			barrierDismissible: false,
			builder: (context) => StatefulBuilder(
				builder: (context, setDialogState) => AdaptiveAlertDialog(
					title: Text(title),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const SizedBox(height: 16),
							ValueListenableBuilder(
								valueListenable: controller.progress,
								builder: (context, value, _) => Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										LinearProgressIndicator(value: value.$2),
										if (value.$1.isNotEmpty) Padding(
											padding: const EdgeInsets.only(top: 8),
											child: Text(value.$1, style: CommonTextStyles.tabularFigures)
										)
									]
								)
							),
							if (cancellable) CupertinoButton(
								padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
								minSize: 0,
								onPressed: controller.cancelled ? null : () {
									controller.cancel();
									setDialogState(() {});
									Future.delayed(const Duration(milliseconds: 750), () {
										if (!popped && context.mounted) {
											popped = true;
											Navigator.pop(context);
										}
									});
								},
								child: const Text('Cancel')
							)
						]	
					)
				)
			)
		);
	});
	try {
		await Future.delayed(Duration.zero);
		return await work(controller);
	}
	finally {
		if (timer.isActive) {
			timer.cancel();
		}
		else if (!popped) {
			popped = true;
			rootNavigator.pop();
		}
		Future.delayed(const Duration(seconds: 1), controller.dispose);
	}
}

String formatTime(DateTime time, {bool forceFullDate = false}) {
	final now = DateTime.now();
	final notToday = (now.day != time.day) || (now.month != time.month) || (now.year != time.year);
	String prefix = '';
	if (forceFullDate || notToday || Persistence.settings.exactTimeShowsDateForToday) {
		if (Persistence.settings.exactTimeUsesCustomDateFormat) {
			prefix = '${time.formatDate(Persistence.settings.customDateFormat)} ';
		}
		else if (forceFullDate || now.difference(time).inDays > 7) {
			prefix = '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ';
		}
		else {
			prefix = '${time.weekdayShortName} ';
		}
	}
	if (Persistence.settings.exactTimeIsTwelveHour) {
		return '$prefix${((time.hour - 1) % 12) + 1}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';
	}
	else {
		return '$prefix${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
	}
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
	final seconds = (d.inMilliseconds / 1000).round();
	return '${(seconds / 60).floor()}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String formatFilesize(int sizeInBytes) {
	const kGB = 1e9;
	if (sizeInBytes > kGB) {
		return '${(sizeInBytes / kGB).toStringAsFixed(2)} GB';
	}
	const kMB = 1e6;
	if (sizeInBytes > kMB) {
		return '${(sizeInBytes / kMB).toStringAsFixed(1)} MB';
	}
	else {
		const kKB = 1e3;
		return '${(sizeInBytes / kKB).round()} KB';
	}
}

class TransparentRoute<T> extends PageRoute<T> {
	final bool? showAnimations;
	final bool? showAnimationsForward;
	TransparentRoute({
		required this.builder,
		RouteSettings? settings,
		this.showAnimations,
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
	Duration get transitionDuration => (showAnimationsForward ?? showAnimations ?? Persistence.settings.showAnimations) ? const Duration(milliseconds: 150) : Duration.zero;

	@override
	Duration get reverseTransitionDuration => (showAnimations ?? Persistence.settings.showAnimations) ? const Duration(milliseconds: 150) : Duration.zero;

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
			opacity: animation.drive(CurveTween(curve: Curves.ease)),
			child: Persistence.settings.blurEffects ? BackdropFilter(
				filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
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
				color: ChanceTheme.primaryColorOf(context),
				borderRadius: const BorderRadius.all(Radius.circular(8))
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(CupertinoIcons.exclamationmark_triangle_fill, color: ChanceTheme.backgroundColorOf(context)),
					const SizedBox(height: 8),
					Flexible(
						child: Text(
							message,
							style: TextStyle(color: ChanceTheme.backgroundColorOf(context)),
							textAlign: TextAlign.center,
							overflow: TextOverflow.fade
						)
					),
					for (final remedy in remedies.entries) ...[
						const SizedBox(height: 8),
						CupertinoButton(
							color: ChanceTheme.backgroundColorOf(context),
							onPressed: remedy.value,
							child: Text(remedy.key, style: TextStyle(
								color: ChanceTheme.primaryColorOf(context)
							), textAlign: TextAlign.center)
						)
					]
				]
			)
		);
	}
}

Future<void> openImageboardTarget(BuildContext context, (Imageboard, BoardThreadOrPostIdentifier, bool) imageboardTarget) {
	return (context.read<GlobalKey<NavigatorState>?>()?.currentState ?? Navigator.of(context)).push(adaptivePageRoute(
			builder: (ctx) => ImageboardScope(
			imageboardKey: null,
			imageboard: imageboardTarget.$1,
			child: imageboardTarget.$2.threadId == null ? BoardPage(
				initialBoard: imageboardTarget.$1.persistence.getBoard(imageboardTarget.$2.board),
				semanticId: -1
			) : ThreadPage(
				thread: imageboardTarget.$2.threadIdentifier!,
				initialPostId: imageboardTarget.$2.postId,
				initiallyUseArchive: imageboardTarget.$3,
				boardSemanticId: -1
			)
		)
	));
}

Future<void> openBrowser(BuildContext context, Uri url, {bool fromShareOne = false, bool useCooperativeBrowser = false}) async {
	if (url.isScheme('chance')) {
		fakeLinkStream.add(url.toString());
		return;
	}
	if (url.host.isEmpty && url.scheme.isEmpty) {
		url = url.replace(
			scheme: 'https',
			host: context.read<Imageboard?>()?.site.baseUrl,
		);
	}
	final settings = Settings.instance;
	final imageboardTarget = await modalLoad(context, 'Checking url...', (_) => ImageboardRegistry.instance.decodeUrl(url.toString()), wait: const Duration(milliseconds: 50));
	openInChance() {
		openImageboardTarget(context, imageboardTarget!);
	}
	final bool isMediaLink = [
		'.webm',
		'.mkv',
		'.mov',
		'.mp4',
		'.png',
		'.jpg',
		'.jpeg',
		'.gif'
	].any(url.path.endsWith);
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
	else if ((isOnMac && !useCooperativeBrowser && imageboardTarget == null && !isMediaLink) || settings.useInternalBrowser == false || (url.scheme != 'http' && url.scheme != 'https')) {
		launchUrl(url, mode: LaunchMode.externalApplication);
	}
	else if (imageboardTarget != null && !fromShareOne) {
		openInChance();
	}
	else if (context.mounted) {
		if (isMediaLink) {
			final attachment = Attachment(
				type: url.path.endsWith('.webm') ? AttachmentType.webm :
					['.png', '.jpg', '.jpeg', '.gif'].any((e) => url.path.endsWith(e)) ? AttachmentType.image : AttachmentType.mp4,
				board: '',
				id: url.toString(),
				ext: '.${url.path.split('.').last}',
				filename: url.path.split('/').last,
				url: url.toString(),
				thumbnailUrl: '',
				md5: '',
				width: null,
				height: null,
				sizeInBytes: null,
				threadId: null
			);
			await showGallery(
				context: context,
				attachments: [attachment],
				overrideSources: {
					attachment: url
				},
				semanticParentIds: [],
				heroOtherEndIsBoxFitCover: false
			);
		}
		else if (useCooperativeBrowser) {
			final fakeAttachment = Attachment(
				type: AttachmentType.url,
				board: '',
				id: '',
				ext: '',
				filename: '',
				url: url.toString(),
				thumbnailUrl: generateThumbnailerForUrl(url).toString(),
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
				allowScroll: false,
				heroOtherEndIsBoxFitCover: false
			);
		}
		else {
			try {
				final theme = context.read<SavedTheme>();
				await ChromeSafariBrowser().open(url: WebUri.uri(url), settings: ChromeSafariBrowserSettings(
					toolbarBackgroundColor: theme.barColor,
					preferredBarTintColor: theme.barColor,
					preferredControlTintColor: theme.primaryColor
				));
			}
			on PlatformException {
				await launchUrl(url);
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
	Color towardsGrey(double factor) {
		return Color.fromRGBO(
			(red + ((128 - red) * factor)).round(),
			(green + ((128 - green) * factor)).round(),
			(blue  + ((128 - blue) * factor)).round(),
			opacity
		);
	}
	Color shiftHue(double offset) {
		if (offset == 0) {
			return this;
		}
		HSVColor hsv = HSVColor.fromColor(this);
		hsv = hsv.withHue((hsv.hue + offset) % 360);
		return hsv.toColor();
	}
	Color shiftSaturation(double offset) {
		if (offset == 0) {
			return this;
		}
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
	Color withMaxValue(double value) {
		HSVColor hsv = HSVColor.fromColor(this);
		if (hsv.value <= value) {
			return this;
		}
		hsv = hsv.withValue(value);
		return hsv.toColor();
	}
}

extension Contrast on Color {
	double contrastWith(Color other) {
		final luminance = computeLuminance();
		final otherLuminance = other.computeLuminance();
		return (math.max(luminance, otherLuminance) + 0.05) / (math.min(luminance, otherLuminance) + 0.05);
	}
	bool isReadableOn(Color other) =>
		contrastWith(other) > 3;
}

Color colorToHex(String hexString) {
	hexString = hexString.replaceFirst('#', '');
	final buffer = StringBuffer();
	if (hexString.length == 3) {
		// Three-digit hex color means double all the letters
		buffer.write('ff'); // Opacity
		buffer.write(hexString[0]);
		buffer.write(hexString[0]);
		buffer.write(hexString[1]);
		buffer.write(hexString[1]);
		buffer.write(hexString[2]);
		buffer.write(hexString[2]);
	}
	else {
		if (hexString.length <= 6) buffer.write('ff');
		buffer.write(hexString);
	}
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
	final bool expanded;
	final bool bottomSafe;

	const Expander({
		required this.child,
		this.duration = const Duration(milliseconds: 300),
		this.curve = Curves.ease,
		required this.expanded,
		this.bottomSafe = false,
		Key? key
	}) : super(key: key);

	@override
	createState() => _ExpanderState();
}

class _ExpanderState extends State<Expander> with SingleTickerProviderStateMixin {
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
			animation.forward().then((_) => _afterAnimation());
		}
		else if (!widget.expanded && oldWidget.expanded) {
			animation.reverse().then((_) => _afterAnimation());
		}
		else if (widget.duration != oldWidget.duration) {
			animation.duration = widget.duration;
		}
	}

	void _afterAnimation() {
		if (mounted) {
			setState(() {});
		}
	}

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			bottom: !widget.bottomSafe,
			child: AnimatedBuilder(
				animation: animation,
				builder: (context, child) => _HiddenBox(
					factor: widget.curve.transform(animation.value),
					child: TickerMode(
						enabled: animation.value > 0,
						child: child!
					)
				),
				child: FadeTransition(
					opacity: animation,
					child: widget.child
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

class _HiddenBox extends SingleChildRenderObjectWidget {
	final double factor;

	const _HiddenBox({
		required super.child,
		required this.factor
	});

	@override
	_RenderHiddenBox createRenderObject(BuildContext context) {
		return _RenderHiddenBox(factor: factor);
	}
	
	@override
	void updateRenderObject(BuildContext context, _RenderHiddenBox renderObject) {
		renderObject.factor = factor;
	}
}

class _RenderHiddenBox extends RenderProxyBox {
	_RenderHiddenBox({
		required double factor
	}) : _factor = factor;

	double _factor;
	set factor(double value) {
		if (value == _factor) {
			return;
		}
		_factor = value;
		markNeedsLayout();
	}

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
			size = Size(
				child!.size.width,
				child!.size.height * _factor
			);
    } else {
      size = computeSizeForNoChild(constraints);
    }
  }

	@override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && _factor > 0) {
			if (_factor >= 1) {
				context.paintChild(child!, offset);
			}
			else {
				layer = context.pushClipRect(
					needsCompositing,
					offset,
					Offset.zero & size,
					(context, offset) => context.paintChild(child!, offset),
					oldLayer: layer as ClipRectLayer?,
				);
			}
    }
  }
}


InlineSpan buildFakeMarkdown(BuildContext context, String input) {
	return TextSpan(
		children: input.split('`').asMap().entries.map((t) => TextSpan(
			text: t.value,
			style: t.key % 2 == 0 ? null : GoogleFonts.ibmPlexMono(
				backgroundColor: ChanceTheme.primaryColorOf(context),
				color: ChanceTheme.backgroundColorOf(context)
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
	final _childKey = GlobalKey(debugLabel: '_RootCustomScaleState._childKey');
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
						size: mq.size * widget.scale,
						viewInsets: mq.viewInsets * widget.scale,
						systemGestureInsets: mq.systemGestureInsets * widget.scale,
						viewPadding: mq.viewPadding * widget.scale,
						padding: mq.padding * widget.scale,
						displayFeatures: mq.displayFeatures.map((f) => ui.DisplayFeature(
							type: f.type,
							state: f.state,
							bounds: Rect.fromPoints(
								f.bounds.topLeft * widget.scale,
								f.bounds.bottomRight * widget.scale
							)
						)).toList()
					),
					child: child
				)
			)
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
					color: ChanceTheme.backgroundColorOf(context),
					child: Text('${DateTime.now().difference(start).inMicroseconds / 1000} ms')
				)
			]
		);
	}
}

class TransformedMediaQuery extends StatelessWidget {
	final Widget child;
	final MediaQueryData Function(BuildContext context, MediaQueryData) transformation;

	const TransformedMediaQuery({
		required this.child,
		required this.transformation,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return MediaQuery(
			data: transformation(context, MediaQuery.of(context)),
			child: child
		);
	}
}

class MaybeScrollbar extends StatelessWidget {
	final Widget child;
	final ScrollController? controller;
	final bool? thumbVisibility;

	const MaybeScrollbar({
		required this.child,
		this.controller,
		this.thumbVisibility,
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final settings = context.watch<Settings>();
		if (settings.showScrollbars) {
			if (ChanceTheme.materialOf(context)) {
				return Scrollbar(
					controller: controller,
					scrollbarOrientation: settings.scrollbarsOnLeft ? ScrollbarOrientation.left : null,
					thickness: settings.scrollbarThickness,
					interactive: true,
					thumbVisibility: thumbVisibility,
					child: child
				);
			}
			return CupertinoScrollbar(
				controller: controller,
				scrollbarOrientation: settings.scrollbarsOnLeft ? ScrollbarOrientation.left : null,
				radius: const Radius.circular(8),
				radiusWhileDragging: const Radius.circular(12),
				thickness: settings.scrollbarThickness,
				thicknessWhileDragging: settings.scrollbarThickness * (5/3),
				thumbVisibility: thumbVisibility,
				child: child
			);
		}
		return child;
	}
}

class _RenderTrulyUnconstrainedBox extends RenderProxyBox {
	bool fade;
	bool _hasVerticalOverflow = false;

	_RenderTrulyUnconstrainedBox({
		required this.fade
	});

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints.copyWith(maxHeight: double.infinity), parentUsesSize: true);
      size = constraints.constrain(child!.size);
			_hasVerticalOverflow = child!.size.height > size.height;
    } else {
      size = computeSizeForNoChild(constraints);
			_hasVerticalOverflow = false;
    }
  }

	@override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
			if (fade && _hasVerticalOverflow) {
				context.canvas.saveLayer(offset & size, Paint());
				context.paintChild(child!, offset);
				context.canvas.translate(offset.dx, offset.dy);
				final Paint paint = Paint()
          ..blendMode = BlendMode.modulate
          ..shader = ui.Gradient.linear(
              Offset(0.0, size.height - (size.height ~/ 4)),
              Offset(0.0, size.height),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
        context.canvas.drawRect(Offset.zero & size, paint);
				context.canvas.translate(-offset.dx, -offset.dy);
				context.canvas.restore();
			}
			else {
				context.paintChild(child!, offset);
			}
    }
  }
}

class _TrulyUnconstrainedBox extends SingleChildRenderObjectWidget {
	final bool fade;

	const _TrulyUnconstrainedBox({
		required super.child,
		required this.fade
	});

	@override
	_RenderTrulyUnconstrainedBox createRenderObject(BuildContext context) {
		return _RenderTrulyUnconstrainedBox(fade: fade);
	}
	
	@override
	void updateRenderObject(BuildContext context, _RenderTrulyUnconstrainedBox renderObject) {
		renderObject.fade = fade;
	}
}

class ClippingBox extends StatelessWidget {
	final Widget child;
	final bool fade;

	const ClippingBox({
		Key? key,
		required this.child,
		this.fade = false
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return ClipRect(
			child: _TrulyUnconstrainedBox(
				fade: fade,
				child: child
			)
		);
	}
}

class RenderFixedWidthLayoutBox extends RenderProxyBox {
	RenderFixedWidthLayoutBox({
		required double width,
		required double threshold
	}) : _width = width, _threshold = threshold;

	double _width;
	set width(double newValue) {
		if (newValue == _width) {
			return;
		}
		_width = newValue;
		markNeedsLayout();
	}

	double _threshold;
	set threshold(double newValue) {
		if (newValue == _threshold) {
			return;
		}
		_threshold = newValue;
		markNeedsLayout();
	}

  @override
  void performLayout() {
    if (child != null) {
			final double width;
			if (constraints.maxWidth.isFinite) {
				final threshold = _width * _threshold;
				if (constraints.maxWidth > (_width + threshold)) {
					width = constraints.maxWidth - threshold;
				}
				else if (constraints.maxWidth < (_width - threshold)) {
					width = constraints.maxWidth + threshold;
				}
				else {
					width = _width;
				}
			}
			else {
				width = _width;
			}
			final double widthScale = constraints.maxWidth / width;
      child!.layout(constraints.copyWith(
				minHeight: 0,
				maxHeight: constraints.maxHeight / widthScale,
				maxWidth: width,
				minWidth: width
			), parentUsesSize: true);
			// Constrain basically just does tiny floating point rounding here
      size = constraints.constrain(child!.size * widthScale);
    } else {
      size = computeSizeForNoChild(constraints);
    }
  }

	Matrix4 get _effectiveTransform {
		final scale = size.width / child!.size.width;
		return Matrix4.identity()..scale(scale, scale, 1.0);
	}

	@override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
			layer = context.pushTransform(
				needsCompositing,
				offset,
				_effectiveTransform,
				(context, offset) => context.paintChild(child!, offset),
				oldLayer: layer is TransformLayer ? layer as TransformLayer? : null
			);
    }
  }

	@override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _effectiveTransform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_effectiveTransform);
  }
}

class FixedWidthLayoutBox extends SingleChildRenderObjectWidget {
	/// Fixed width
	final double width;
	/// Allow growth of width when available width exceeds beyond relative factor
	final double threshold;

	const FixedWidthLayoutBox({
		required this.width,
		this.threshold = 0.1,
		required super.child,
		super.key
	});


	@override
	RenderFixedWidthLayoutBox createRenderObject(BuildContext context) {
		return RenderFixedWidthLayoutBox(width: width, threshold: threshold);
	}

	@override
	void updateRenderObject(BuildContext context, RenderFixedWidthLayoutBox renderObject) {
		renderObject
			..width = width
			..threshold = threshold;
	}
}

class CachingBuilder<T> extends StatefulWidget {
	final T value;
	final Widget Function(T) builder;
	const CachingBuilder({
		required this.value,
		required this.builder,
		super.key
	});
	
	@override
	createState() => _CachingBuilderState<T>();
}

class _CachingBuilderState<T> extends State<CachingBuilder<T>> {
	Widget? _widget;

	@override
	void didUpdateWidget(CachingBuilder<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.value != oldWidget.value) {
			_widget = null;
		}
	}

	@override
	Widget build(BuildContext context) {
		return _widget ??= widget.builder(widget.value);
	}
}

class CachingContextBuilder<T> extends StatefulWidget {
	final T Function(BuildContext) watcher;
	final Widget Function(T) builder;
	const CachingContextBuilder({
		required this.watcher,
		required this.builder,
		super.key
	});

	@override
	createState() => _CachingContextBuilderState<T>();
}

class _CachingContextBuilderState<T> extends State<CachingContextBuilder<T>> {
	T? _lastValue;
	Widget? _widget;

	@override
	Widget build(BuildContext context) {
		final value = widget.watcher(context);
		if (value != _lastValue) {
			_widget = null;
		}
		return _widget ??= widget.builder(value);
	}
}

Future<void> editStringList({
	required BuildContext context,
	required List<String> list,
	required String name,
	required String title,
	bool startEditsWithAllSelected = true
}) async {
	final theme = context.read<SavedTheme>();
	await showAdaptiveDialog(
		barrierDismissible: true,
		context: context,
		builder: (context) => StatefulBuilder(
			builder: (context, setDialogState) => AdaptiveAlertDialog(
				title: Padding(
					padding: const EdgeInsets.only(bottom: 16),
					child: Text(title)
				),
				content: SizedBox(
					width: 100,
					height: 350,
					child: ListView.builder(
						itemCount: list.length,
						itemBuilder: (context, i) => Padding(
							padding: const EdgeInsets.all(4),
							child: GestureDetector(
								onTap: () async {
									final controller = TextEditingController(text: list[i]);
									if (startEditsWithAllSelected) {
										controller.selection = TextSelection(baseOffset: 0, extentOffset: list[i].length);
									}
									final newItem = await showAdaptiveDialog<String>(
										context: context,
										barrierDismissible: true,
										builder: (context) => AdaptiveAlertDialog(
											title: Text('Edit $name'),
											content: AdaptiveTextField(
												autofocus: true,
												autocorrect: false,
												enableIMEPersonalizedLearning: false,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												controller: controller,
												onSubmitted: (s) => Navigator.pop(context, s)
											),
											actions: [
												AdaptiveDialogAction(
													isDefaultAction: true,
													child: const Text('Change'),
													onPressed: () => Navigator.pop(context, controller.text)
												),
												AdaptiveDialogAction(
													child: const Text('Cancel'),
													onPressed: () => Navigator.pop(context)
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
										color: theme.primaryColor.withOpacity(0.1)
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
					)
				),
				actions: [
					AdaptiveDialogAction(
						child: Text('Add $name'),
						onPressed: () async {
							final controller = TextEditingController();
							final newItem = await showAdaptiveDialog<String>(
								context: context,
								barrierDismissible: true,
								builder: (context) => AdaptiveAlertDialog(
									title: Text('New $name'),
									content: AdaptiveTextField(
										autofocus: true,
										controller: controller,
										autocorrect: false,
										enableIMEPersonalizedLearning: false,
										smartDashesType: SmartDashesType.disabled,
										smartQuotesType: SmartQuotesType.disabled,
										onSubmitted: (s) => Navigator.pop(context, s)
									),
									actions: [
										AdaptiveDialogAction(
											isDefaultAction: true,
											child: const Text('Add'),
											onPressed: () => Navigator.pop(context, controller.text)
										),
										AdaptiveDialogAction(
											child: const Text('Cancel'),
											onPressed: () => Navigator.pop(context)
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
					),
					AdaptiveDialogAction(
						child: const Text('Close'),
						onPressed: () => Navigator.pop(context)
					)
				]
			)
		)
	);
}

String _defaultMapEntryFormatter(MapEntry<String, String> entry) {
	return '${entry.key}\n${entry.value}';
}

Future<void> editStringMap({
	required BuildContext context,
	required Map<String, String> map,
	required String name,
	String keyName = 'Key',
	String valueName = 'Value',
	String Function(MapEntry<String, String>) formatter = _defaultMapEntryFormatter,
	required String title
}) async {
	final theme = context.read<SavedTheme>();
	final entries = map.entries.toList();
	await showAdaptiveDialog(
		barrierDismissible: true,
		context: context,
		builder: (context) => StatefulBuilder(
			builder: (context, setDialogState) => AdaptiveAlertDialog(
				title: Padding(
					padding: const EdgeInsets.only(bottom: 16),
					child: Text(title)
				),
				content: SizedBox(
					width: 100,
					height: 350,
					child: ListView.builder(
						itemCount: entries.length,
						itemBuilder: (context, i) => Padding(
							padding: const EdgeInsets.all(4),
							child: GestureDetector(
								onTap: () async {
									final keyController = TextEditingController(text: entries[i].key);
									final valueController = TextEditingController(text: entries[i].value);
									final change = await showAdaptiveDialog<bool>(
										context: context,
										barrierDismissible: true,
										builder: (context) => AdaptiveAlertDialog(
											title: Text('Edit $name'),
											content: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												mainAxisSize: MainAxisSize.min,
												children: [
													Text(keyName),
													AdaptiveTextField(
														autocorrect: false,
														enableIMEPersonalizedLearning: false,
														smartDashesType: SmartDashesType.disabled,
														smartQuotesType: SmartQuotesType.disabled,
														controller: keyController,
														onSubmitted: (_) => Navigator.pop(context, true)
													),
													const SizedBox(height: 16),
													Text(valueName),
													AdaptiveTextField(
														autocorrect: false,
														enableIMEPersonalizedLearning: false,
														smartDashesType: SmartDashesType.disabled,
														smartQuotesType: SmartQuotesType.disabled,
														controller: valueController,
														onSubmitted: (_) => Navigator.pop(context, true)
													),
												]
											),
											actions: [
												AdaptiveDialogAction(
													isDefaultAction: true,
													child: const Text('Change'),
													onPressed: () => Navigator.pop(context, true)
												),
												AdaptiveDialogAction(
													child: const Text('Cancel'),
													onPressed: () => Navigator.pop(context)
												)
											]
										)
									);
									if (change ?? false) {
										entries[i] = MapEntry<String, String>(keyController.text, valueController.text);
										setDialogState(() {});
									}
									keyController.dispose();
									valueController.dispose();
								},
								child: Container(
									decoration: BoxDecoration(
										borderRadius: const BorderRadius.all(Radius.circular(4)),
										color: theme.primaryColor.withOpacity(0.1)
									),
									padding: const EdgeInsets.only(left: 16),
									child: Row(
										children: [
											Expanded(
												child: Text(formatter(entries[i]), style: const TextStyle(fontSize: 15), textAlign: TextAlign.left)
											),
											CupertinoButton(
												child: const Icon(CupertinoIcons.delete),
												onPressed: () {
													entries.removeAt(i);
													setDialogState(() {});
												}
											)
										]
									)
								)
							)
						)
					)
				),
				actions: [
					AdaptiveDialogAction(
						child: Text('Add $name'),
						onPressed: () async {
							final keyController = TextEditingController();
							final valueController = TextEditingController();
							final add = await showAdaptiveDialog<bool>(
								context: context,
								barrierDismissible: true,
								builder: (context) => AdaptiveAlertDialog(
									title: Text('New $name'),
									content: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text(keyName),
											AdaptiveTextField(
												autocorrect: false,
												enableIMEPersonalizedLearning: false,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												controller: keyController,
												onSubmitted: (s) => Navigator.pop(context, s)
											),
											const SizedBox(height: 16),
											Text(valueName),
											AdaptiveTextField(
												autocorrect: false,
												enableIMEPersonalizedLearning: false,
												smartDashesType: SmartDashesType.disabled,
												smartQuotesType: SmartQuotesType.disabled,
												controller: valueController,
												onSubmitted: (s) => Navigator.pop(context, s)
											),
										]
									),
									actions: [
										AdaptiveDialogAction(
											isDefaultAction: true,
											child: const Text('Add'),
											onPressed: () => Navigator.pop(context, true)
										),
										AdaptiveDialogAction(
											child: const Text('Cancel'),
											onPressed: () => Navigator.pop(context)
										)
									]
								)
							);
							if (add ?? false) {
								entries.add(MapEntry<String, String>(keyController.text, valueController.text));
								setDialogState(() {});
							}
							keyController.dispose();
							valueController.dispose();
						}
					),
					AdaptiveDialogAction(
						child: const Text('Close'),
						onPressed: () => Navigator.pop(context)
					)
				]
			)
		)
	);
	map.clear();
	map.addEntries(entries);
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
	ScrollPosition? get tryPosition {
		if (positions.length == 1) {
			return position;
		}
		return null;
	}
}

Future<bool> confirm(BuildContext context, String message, {String actionName = 'OK'}) async {
	return (await showAdaptiveDialog<bool>(
		context: context,
		barrierDismissible: true,
		builder: (context) => AdaptiveAlertDialog(
			title: Text(message),
			actions: [
				AdaptiveDialogAction(
					isDefaultAction: true,
					onPressed: () {
						Navigator.of(context).pop(true);
					},
					child: Text(actionName)
				),
				AdaptiveDialogAction(
					child: const Text('Cancel'),
					onPressed: () {
						Navigator.of(context).pop();
					}
				)
			]
		)
	)) ?? false;
}

class KeepAliver extends StatefulWidget {
	final Widget child;

	const KeepAliver({
		required this.child,
		super.key
	});

	@override
	createState() => _KeepAliverState();
}

class _KeepAliverState extends State<KeepAliver> with AutomaticKeepAliveClientMixin {
	@override
	Widget build(BuildContext context) {
		super.build(context);
		return widget.child;
	}

	@override
	bool get wantKeepAlive => true;
}

Future<Attachment?> whichAttachment(BuildContext context, Iterable<Attachment> attachments) async {
	if (attachments.isEmpty) {
		return null;
	}
	else if (attachments.length == 1) {
		return attachments.first;
	}
	return await showAdaptiveDialog(
		context: context,
		barrierDismissible: true,
		builder: (innerContext) => AdaptiveAlertDialog(
			title: const Text('Which file?'),
			content: ImageboardScope(
				imageboardKey: null,
				imageboard: context.read<Imageboard>(),
				child: SizedBox(
					height: 350,
					child: GridView(
						gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1),
						children: attachments.map((a) => CupertinoButton(
							child: AttachmentThumbnail(
								attachment: a,
								mayObscure: false
							),
							onPressed: () => Navigator.pop(innerContext, a)
						)).toList()
					)
				)
			)
		)
	);
}

Future<DateTime?> pickDate({
	required BuildContext context,
	DateTime? initialDate
}) async {
	DateTime chosenDate = initialDate ?? DateTime.now();
	final choice = await showAdaptiveModalPopup<bool>(
		context: context,
		builder: (context) => Container(
			color: ChanceTheme.backgroundColorOf(context),
			child: SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						SizedBox(
							height: 300,
							child: CupertinoDatePicker(
								mode: CupertinoDatePickerMode.date,
								initialDateTime: initialDate,
								onDateTimeChanged: (newDate) {
									chosenDate = newDate;
								}
							)
						),
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceEvenly,
							children: [
								CupertinoButton(
									child: const Text('Cancel'),
									onPressed: () => Navigator.of(context).pop()
								),
								CupertinoButton(
									child: const Text('Clear Date'),
									onPressed: () => Navigator.of(context).pop(false)
								),
								CupertinoButton(
									child: const Text('Done'),
									onPressed: () => Navigator.of(context).pop(true)
								)
							]
						)
					]
				)
			)
		)
	);
	switch (choice) {
		case null:
			return initialDate;
		case false:
			return null;
		case true:
			return chosenDate;
	}
}

class HybridScrollPhysics extends BouncingScrollPhysics {
	const HybridScrollPhysics({
		super.decelerationRate,
		super.parent,
	});

	@override
  HybridScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HybridScrollPhysics(
      parent: buildParent(ancestor),
      decelerationRate: decelerationRate
    );
  }

	bool _bouncingScrollSimulationWouldGoOutOfBounds({
			required double position,
			required double velocity,
			required double leadingExtent,
			required double trailingExtent,
			required SpringDescription spring,
			double constantDeceleration = 0,
			required Tolerance tolerance
	}) {
		if (position < leadingExtent) {
			return true;
		} else if (position > trailingExtent) {
			return true;
		} else {
			final frictionSimulation = FrictionSimulation(0.135, position, velocity, constantDeceleration: constantDeceleration);
			final double finalX = frictionSimulation.finalX;
			if (velocity > 0.0 && finalX > trailingExtent) {
				return true;
			} else if (velocity < 0.0 && finalX < leadingExtent) {
				return true;
			} else {
				return false;
			}
		}
	}

	@override
  double carriedMomentum(double existingVelocity) {
    if (parent == null) {
      return 0.0;
    }
    return parent!.carriedMomentum(existingVelocity);
  }

	@override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      double constantDeceleration;
      switch (decelerationRate) {
        case ScrollDecelerationRate.fast:
          constantDeceleration = 1400;
        case ScrollDecelerationRate.normal:
          constantDeceleration = 0;
      }
			if (_bouncingScrollSimulationWouldGoOutOfBounds(
				position: position.pixels,
				velocity: velocity,
				leadingExtent: position.minScrollExtent,
				trailingExtent: position.maxScrollExtent,
				spring: spring,
				tolerance: tolerance,
				constantDeceleration: constantDeceleration
			)) {
				return BouncingScrollSimulation(
					spring: spring,
					position: position.pixels,
					velocity: velocity,
					leadingExtent: position.minScrollExtent,
					trailingExtent: position.maxScrollExtent,
					tolerance: tolerance,
					constantDeceleration: constantDeceleration
				);
			}
			return ClampingScrollSimulation(
				position: position.pixels,
				velocity: velocity,
				tolerance: tolerance,
			);
    }
    return null;
  }
}

class RenderGreedySizeCachingBox extends RenderProxyBox {
	Alignment alignment;
	double widthResetThreshold;
	double heightResetThreshold;
	Size _cachedSize = Size.zero;

	RenderGreedySizeCachingBox({
		required this.alignment,
		required this.widthResetThreshold,
		required this.heightResetThreshold
	});

	@override
	void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = child!.size;
    } else {
      size = computeSizeForNoChild(constraints);
    }
		if ((_cachedSize.width - size.width).abs() > widthResetThreshold ||
		    (_cachedSize.height - size.height).abs() > heightResetThreshold) {
			// size is way too different
			_cachedSize = size;
		}
		size = constraints.constrain(Size(math.max(_cachedSize.width, size.width), math.max(_cachedSize.height, size.height)));
		(child?.parentData as BoxParentData?)?.offset = alignment.inscribe(child!.size, Offset.zero & size).topLeft;
		_cachedSize = size;
  }

	@override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
			context.paintChild(child!, (child!.parentData as BoxParentData).offset + offset);
    }
  }

	@override
	void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset offset = (child.parentData! as BoxParentData).offset;
    transform.translate(offset.dx, offset.dy);
  }

	@override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    final RenderBox? child = this.child;
    if (child != null) {
      final BoxParentData childParentData = child.parentData! as BoxParentData;
      return result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child.hitTest(result, position: transformed);
        },
      );
    }
    return false;
  }
}

class GreedySizeCachingBox extends SingleChildRenderObjectWidget {
	final Alignment alignment;
	final double widthResetThreshold;
	final double heightResetThreshold;

	const GreedySizeCachingBox({
		required super.child,
		this.alignment = Alignment.topLeft,
		this.widthResetThreshold = 25,
		this.heightResetThreshold = 25,
		super.key
	});

	@override
	RenderGreedySizeCachingBox createRenderObject(BuildContext context) {
		return RenderGreedySizeCachingBox(
			alignment: alignment,
			widthResetThreshold: widthResetThreshold,
			heightResetThreshold: heightResetThreshold
		);
	}
	
	@override
	void updateRenderObject(BuildContext context, RenderGreedySizeCachingBox renderObject) {
		renderObject.alignment = alignment;
		renderObject.widthResetThreshold = widthResetThreshold;
		renderObject.heightResetThreshold = heightResetThreshold;
	}
}

class RenderWidthSnappingBox extends RenderProxyBox {
	RenderWidthSnappingBox({
		required double factor,
		required Alignment alignment
	}) : _factor = factor, _alignment = alignment;

	double _factor;
	set factor(double newValue) {
		if (newValue == _factor) {
			return;
		}
		_factor = newValue;
		markNeedsLayout();
	}
	Alignment _alignment;
	set alignment(Alignment newValue) {
		if (newValue == _alignment) {
			return;
		}
		_alignment = newValue;
		markNeedsLayout();
	}

	@override
	void setupParentData(RenderBox child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      if (child!.size.width >= (constraints.maxWidth * _factor)) {
				// Snap
				size = Size(constraints.maxWidth, child!.size.height);
				(child!.parentData as BoxParentData).offset = _alignment.inscribe(child!.size, Offset.zero & size).topLeft;
			}
			else {
				// Don't snap
				size = child!.size;
				(child!.parentData as BoxParentData).offset = Offset.zero;
			}
    }
		else {
      size = computeSizeForNoChild(constraints);
    }
  }

	@override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
			context.paintChild(child!, offset + (child!.parentData as BoxParentData).offset);
    }
  }

	@override
	void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset offset = (child.parentData! as BoxParentData).offset;
    transform.translate(offset.dx, offset.dy);
  }

	@override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    final RenderBox? child = this.child;
    if (child != null) {
      final BoxParentData childParentData = child.parentData! as BoxParentData;
      return result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return child.hitTest(result, position: transformed);
        },
      );
    }
    return false;
  }
}

class WidthSnappingBox extends SingleChildRenderObjectWidget {
	/// At what scalar factor of maximum width should the container be snapped to fill
	final double factor;
	final Alignment alignment;

	const WidthSnappingBox({
		required super.child,
		required this.factor,
		this.alignment = Alignment.topLeft,
		super.key
	});

	@override
	RenderWidthSnappingBox createRenderObject(BuildContext context) {
		return RenderWidthSnappingBox(
			factor: factor,
			alignment: alignment
		);
	}
	
	@override
	void updateRenderObject(BuildContext context, RenderWidthSnappingBox renderObject) {
		renderObject.factor = factor;
		renderObject.alignment = alignment;
	}
}

class ChainedLinearTextScaler extends TextScaler {
	final TextScaler parent;
	final double _textScaleFactor;
	@override
	// ignore: deprecated_member_use
	double get textScaleFactor => _textScaleFactor * parent.textScaleFactor;

	const ChainedLinearTextScaler({
		required this.parent,
		required double textScaleFactor
	}) : _textScaleFactor = textScaleFactor;

	@override
	double scale(double fontSize) {
		return parent.scale(_textScaleFactor * fontSize);
	}

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ChainedLinearTextScaler &&
		other.parent == parent &&
		other._textScaleFactor == _textScaleFactor;
	
	@override
	int get hashCode => Object.hash(parent, _textScaleFactor);
}

class TestMediaQuery extends StatelessWidget {
	final Widget child;
	final EdgeInsets edgeInsets;

	const TestMediaQuery({
		required this.child,
		this.edgeInsets = const EdgeInsets.all(50),
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return TransformedMediaQuery(
			transformation: (context, mq) => mq.copyWith(
				padding: mq.padding + edgeInsets,
				viewPadding: mq.viewPadding + edgeInsets
			),
			child: DecoratedBox(
				position: DecorationPosition.foreground,
				decoration: BoxDecoration(
					border: Border(
						top: BorderSide(color: Colors.pink.withOpacity(0.5), width: edgeInsets.top),
						bottom: BorderSide(color: Colors.pink.withOpacity(0.5), width: edgeInsets.bottom),
						left: BorderSide(color: Colors.pink.withOpacity(0.5), width: edgeInsets.left),
						right: BorderSide(color: Colors.pink.withOpacity(0.5), width: edgeInsets.right)
					)
				),
				child: child
			)
		);
	}
}

extension ToCss on Color {
	String toCssRgba() => 'rgba($red, $green, $blue, $opacity)';
	String toCssHex() => '#${red.toRadixString(16).padLeft(2, '0')}${green.toRadixString(16).padLeft(2, '0')}${blue.toRadixString(16).padLeft(2, '0')}';
}

extension Inverted on Brightness {
	Brightness get inverted => switch (this) {
		Brightness.dark => Brightness.light,
		Brightness.light => Brightness.dark
	};
}

class NotificationListener2<T1 extends Notification, T2 extends Notification> extends StatelessWidget {
	final Widget child;
	final NotificationListenerCallback<Notification> onNotification;

	const NotificationListener2({
		required this.child,
		required this.onNotification,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return NotificationListener<T1>(
			onNotification: onNotification,
			child: NotificationListener<T2>(
				onNotification: onNotification,
				child: child
			)
		);
	}
}

class ChanceDivider extends StatelessWidget {
	final double height;

	const ChanceDivider({
		this.height = 0,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return Divider(
			thickness: 1,
			height: height,
			color: ChanceTheme.primaryColorWithBrightness20Of(context)
		);
	}
}

class DescendantNavigatorPopScope extends StatelessWidget {
	final bool Function() canPop;
	final void Function(bool, dynamic)? onPopInvokedWithResult;
	final Widget child;

	const DescendantNavigatorPopScope({
		required this.canPop,
		this.onPopInvokedWithResult,
		required this.child,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return StatefulBuilder(
			builder: (context, setState) => NotificationListener<NavigationNotification>(
				onNotification: (notification) {
					setState(() {}); // recalculate canPop
					return false;
				},
				child: PopScope(
					canPop: canPop(),
					onPopInvokedWithResult: (didPop, result) {
						onPopInvokedWithResult?.call(didPop, result);
					},
					child: child
				)
			)
		);
	}
}

class BuildContextMapRegistrant<T> extends StatelessWidget {
	final Map<T, BuildContext> map;
	final T value;
	final Widget child;

	const BuildContextMapRegistrant({
		required this.map,
		required this.value,
		required this.child,
		super.key
	});

	@override
	Widget build(BuildContext context) {
		return BuildContextRegistrant(
			onBuild: (context) {
				map[value] = context;
			},
			onDispose: (context) {
				// Make sure we don't overwrite a new context from another widget
				if (map[value] == context) {
					map.remove(context);
				}
			},
			child: child
		);
	}
}

class BuildContextRegistrant extends StatefulWidget {
	final ValueChanged<BuildContext> onBuild;
	final ValueChanged<BuildContext> onDispose;
	final Widget child;

	const BuildContextRegistrant({
		required this.onBuild,
		required this.onDispose,
		required this.child,
		super.key
	});

	@override
	createState() => _BuildContextRegistrantState();
}

class _BuildContextRegistrantState extends State<BuildContextRegistrant> {
	@override
	Widget build(BuildContext context) {
		widget.onBuild(context);
		return widget.child;
	}

	@override
	void dispose() {
		super.dispose();
		widget.onDispose(context);
	}
}

class IconSpan extends TextSpan {
	IconSpan({
		required IconData icon,
		double? size,
		Color? color
	}) : super(
		text: String.fromCharCode(icon.codePoint),
		style: TextStyle(
			fontSize: size,
			fontFamily: icon.fontFamily,
			color: color,
			package: icon.fontPackage,
			height: 1.0
		)
	);
}

extension WatchIdentity on BuildContext {
	T watchIdentity<T>() => select<T, T>(identity);
}

extension Bounds on BuildContext {
	Rect? get globalPaintBounds {
		final box = findRenderObject();
		if (box is! RenderBox) {
			return null;
		}
		return Rect.fromPoints(
			box.localToGlobal(box.paintBounds.topLeft),
			box.localToGlobal(box.paintBounds.bottomRight)
		);
	}
}

class NullableColorFiltered extends SingleChildRenderObjectWidget {
  /// Creates a widget that applies a [ColorFilter] to its child.
  const NullableColorFiltered({required this.colorFilter, super.child, super.key});

  /// The color filter to apply to the child of this widget.
  final ColorFilter? colorFilter;

  @override
  RenderObject createRenderObject(BuildContext context) => NullableColorFilterRenderObject(colorFilter);

  @override
  void updateRenderObject(BuildContext context, NullableColorFilterRenderObject renderObject) {
    renderObject.colorFilter = colorFilter;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ColorFilter>('colorFilter', colorFilter));
  }
}

class NullableColorFilterRenderObject extends RenderProxyBox {
  NullableColorFilterRenderObject(this._colorFilter);

  ColorFilter? get colorFilter => _colorFilter;
  ColorFilter? _colorFilter;
  set colorFilter(ColorFilter? value) {
    if (value != _colorFilter) {
			final had = _colorFilter != null;
      _colorFilter = value;
      markNeedsPaint();
			if (had != (value != null)) {
				markNeedsCompositingBitsUpdate();
			}
    }
  }

  @override
  bool get alwaysNeedsCompositing => child != null && colorFilter != null;

  @override
  void paint(PaintingContext context, Offset offset) {
		if (colorFilter != null) {
    	layer = context.pushColorFilter(offset, colorFilter!, super.paint, oldLayer: layer as ColorFilterLayer?);
			assert(() {
				layer!.debugCreator = debugCreator;
				return true;
			}());
		}
		else {
			layer = null;
			super.paint(context, offset);
		}
  }
}

class CommonFontVariations {
	CommonFontVariations._();
	static const w400 = [FontVariation.weight(400)];
	static const w500 = [FontVariation.weight(500)];
	static const w600 = [FontVariation.weight(600)];
	static const bold = [FontVariation.weight(700)];
}

class CommonTextStyles {
	CommonTextStyles._();
	static const w600 = TextStyle(
		fontWeight: FontWeight.w600,
		fontVariations: CommonFontVariations.w600
	);
	static const bold = TextStyle(
		fontWeight: FontWeight.bold,
		fontVariations: CommonFontVariations.bold
	);
	static const tabularFigures = TextStyle(
		fontFeatures: [FontFeature.tabularFigures()]
	);
}

class DebouncedBuilder<T> extends StatefulWidget {
	final T value;
	final Duration period;
	final Widget Function(T) builder;
	const DebouncedBuilder({
		required this.value,
		required this.period,
		required this.builder,
		super.key
	});
	
	@override
	createState() => _DebouncedBuilderState<T>();
}

class _DebouncedBuilderState<T> extends State<DebouncedBuilder<T>> {
	late Timer _timer;
	late T _value;
	/// The first value shouldn't be initially shown, it might be very short-lived
	bool _show = false;

	@override
	void initState() {
		super.initState();
		_timer = Timer(widget.period, _onTimerFire);
		_value = widget.value;
	}

	void _onTimerFire() {
		_value = widget.value;
		_show = true;
		setState(() {});
	}

	@override
	void didUpdateWidget(DebouncedBuilder<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (widget.value != oldWidget.value) {
			_timer.cancel();
			_timer = Timer(widget.period, _onTimerFire);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Visibility.maintain(
			visible: _show,
			child: widget.builder(_value)
		);
	}

	@override
	void dispose() {
		super.dispose();
		_timer.cancel();
	}
}

class ConditionalShortcut implements ShortcutActivator {
	final ShortcutActivator parent;
	final bool Function() condition;

	ConditionalShortcut({
		required this.parent,
		required this.condition
	});

	@override
	bool accepts(KeyEvent event, HardwareKeyboard state) {
		if (condition() && parent.accepts(event, state)) {
			return true;
		}
		return false;
	}

	@override
	String debugDescribeKeys() => parent.debugDescribeKeys();

	@override
	Iterable<LogicalKeyboardKey>? get triggers => parent.triggers;
}
