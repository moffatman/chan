import 'dart:async';
import 'dart:math' as math;

import 'package:chan/main.dart';
import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/screen_size_hacks.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/notifying_icon.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

Widget _withNavigationBarPadding(BuildContext context, Widget child, {double horizontalContentPadding = 0}) {
	final nativePadding = context.select<DuoLayout?, EdgeInsets?>((layout) => layout?.side == AxisDirection.up ? layout!.padding : null);
	if (nativePadding == null) {
		return child;
	}
	final location = context.watch<MasterDetailLocation?>();
	if (location == MasterDetailLocation.twoPaneVerticalDetail) {
		return child;
	}
	final scale = Settings.interfaceScaleSetting.watch(context);
	final padding = nativePadding / scale;
	final safePadding = MediaQuery.paddingOf(context);
	final view = View.of(context);
	final additionalInsets = sumAdditionalSafeAreaInsets();
	// The bar insets are window-relative. SafeArea ancestors have already
	// consumed part of that space before this navbar is laid out.
	final consumedLeft = math.max(0.0, (view.padding.left / view.devicePixelRatio - additionalInsets.left) / scale - safePadding.left);
	final consumedRight = math.max(0.0, (view.padding.right / view.devicePixelRatio - additionalInsets.right) / scale - safePadding.right);
	final sidebarWidth = navigationSidebarWidthOf(context);
	double leftOffset = consumedLeft + sidebarWidth;
	double rightOffset = consumedRight;
	if (location == MasterDetailLocation.twoPaneHorizontalMaster || location == MasterDetailLocation.twoPaneHorizontalDetail) {
		final contentWidth = MediaQuery.sizeOf(context).width - consumedLeft - consumedRight - sidebarWidth;
		final masterWidth = contentWidth * Settings.twoPaneSplitSetting.watch(context) / twoPaneSplitDenominator;
		if (location == MasterDetailLocation.twoPaneHorizontalDetail) {
			leftOffset += masterWidth;
		}
		else {
			rightOffset += contentWidth - masterWidth;
		}
	}
	// The navbar's own content padding already contributes to this clearance.
	final left = math.max(safePadding.left, padding.left - leftOffset - horizontalContentPadding);
	final right = math.max(safePadding.right, padding.right - rightOffset - horizontalContentPadding);
	final target = EdgeInsets.only(left: left, right: right);
	return TweenAnimationBuilder<EdgeInsets>(
		tween: EdgeInsetsTween(begin: target, end: target),
		duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
		curve: Curves.easeInOutCubic,
		builder: (context, animatedPadding, child) {
			if (animatedPadding.left == safePadding.left && animatedPadding.right == safePadding.right) {
				return child!;
			}
			return MediaQuery(
				data: MediaQuery.of(context).copyWith(padding: safePadding.copyWith(left: animatedPadding.left, right: animatedPadding.right)),
				child: child!
			);
		},
		child: child
	);
}

class AdaptiveBarAction<T> {
	final Widget icon;
	final String title;
	final FutureOr<T> Function()? onPressed;

	const AdaptiveBarAction({
		required this.icon,
		required this.title,
		required this.onPressed
	});
}

class AdaptiveBar {
	final List<AdaptiveBarAction>? leadings;
	final Widget? title;
	final List<Widget>? actions;
	final Color? backgroundColor;
	final Brightness? brightness;
	
	const AdaptiveBar({
		this.leadings,
		this.title,
		this.actions,
		this.backgroundColor,
		this.brightness
	});
}

/// Insert buttons for each [bar.leadings]
/// But if the screen is thin and there is more than one button, use a submenu.
void _handleLeadings({
	required BuildContext context,
	required List<Widget> leadings,
	required AdaptiveBar bar
}) {
	if (bar.leadings != null) {
		if (bar.leadings!.length > 1 && estimateWidth(context) < 270) {
			leadings.add(AdaptiveIconButton(
				onPressed: () => showAdaptiveModalPopup(
					useRootNavigator: false,
					context: context,
					builder: (context) => AdaptiveActionSheet(
						actions: bar.leadings!.map((l) => AdaptiveActionSheetAction(
							onPressed: l.onPressed == null ? null : () {
								Navigator.pop(context);
								l.onPressed!();
							},
							child: Row(
								children: [
									SizedBox(
										width: 40,
										child: Center(
											child: l.icon
										)
									),
									Expanded(
										child: Text(l.title)
									)
								]
							)
						)).toList(),
						cancelButton: AdaptiveActionSheetAction(
							onPressed: () => Navigator.pop(context),
							child: const Text('Cancel')
						)
					)
				),
				icon: const Icon(Icons.more_vert)
			));
		}
		else {
			leadings.addAll(bar.leadings!.map((l) => AdaptiveIconButton(
				icon: l.icon,
				onPressed: l.onPressed
			)));
		}
	}
}

class _NotifyingDrawerButtonWrapper extends StatelessWidget {
	final Widget child;

	const _NotifyingDrawerButtonWrapper({
		required this.child
	});

	@override
	Widget build(BuildContext context) {
		if (!Settings.androidDrawerSetting.watch(context)) {
			// Bottom/side bar will show the counters
			return child;
		}
		final tabs = context.watch<ChanTabs?>();
		int combine(int savedCount, int devCount) {
			if (tabs?.mainTabIndex == 4) {
				// Already in Settings
				return savedCount;
			}
			else if (tabs?.mainTabIndex == 1) {
				// Already in Saved
				return devCount;
			}
			return savedCount + devCount;
		}
		return NotifyingIcon(
			sideBySide: true,
			primaryCount: Combining2ValueListenable(
				child1: CombiningValueListenable<int>(
					children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenYouCount).toList(),
					combine: (list) => list.fold(0, (a, b) => a + b)
				),
				child2: ImageboardRegistry.instance.dev?.threadWatcher.unseenYouCount ?? const StoppedValueListenable(0),
				combine: combine
			),
			secondaryCount: Combining2ValueListenable(
				child1: CombiningValueListenable<int>(
					children: ImageboardRegistry.instance.imageboards.map((x) => x.threadWatcher.unseenCount).toList(),
					combine: (list) => list.fold(0, (a, b) => a + b)
				),
				child2: ImageboardRegistry.instance.dev?.threadWatcher.unseenCount ?? const StoppedValueListenable(0),
				combine: combine
			),
			icon: child
		);
	}
}

class _AppBarWithBackButtonPriority extends StatelessWidget implements PreferredSizeWidget {
	final AdaptiveBar bar;
	final VoidCallback? onDrawerButtonPressed;
	final bool autoHideOnScroll;

	const _AppBarWithBackButtonPriority({
		required this.bar,
		required this.autoHideOnScroll,
		this.onDrawerButtonPressed
	});

	@override
	Widget build(BuildContext context) {
		final leadings = <Widget>[];
		if (ModalRoute.of(context)?.canPop ?? false) {
			leadings.add(GestureDetector(
				onLongPress: () {
					Settings.instance.runQuickAction(context);
				},
				child: const _NotifyingDrawerButtonWrapper(
					child: BackButton()
				)
			));
		}
		else if (onDrawerButtonPressed != null) {
			leadings.add(GestureDetector(
				onLongPress: () {
					Settings.instance.runQuickAction(context);
				},
				child: _NotifyingDrawerButtonWrapper(
					child: DrawerButton(
						onPressed: onDrawerButtonPressed
					)
				)
			));
		}
		_handleLeadings(context: context, leadings: leadings, bar: bar);
		final child = _withNavigationBarPadding(context,
			AppBar(
				leadingWidth: leadings.length > 1 ? leadings.length * 48 : null,
				leading: leadings.isEmpty ? null : Row(
					mainAxisSize: MainAxisSize.min,
					children: leadings
				),
				surfaceTintColor: Colors.transparent,
				foregroundColor: ChanceTheme.primaryColorOf(context),
				//centerTitle: true,
				title: Container(
					height: 44,
					alignment: Alignment.centerLeft,
					child: bar.title
				),
				actions: bar.actions,
				backgroundColor: bar.backgroundColor,
				systemOverlayStyle: SystemUiOverlayStyle(
					statusBarBrightness: bar.brightness ?? ChanceTheme.brightnessOf(context),
					statusBarIconBrightness: (bar.brightness ?? ChanceTheme.brightnessOf(context)).inverted
				)
			)
		);
		if (!autoHideOnScroll) {
			return child;
		}
		return AncestorScrollBuilder(
			builder: (context, direction, _) => AnimatedOpacity(
				opacity: direction == VerticalDirection.up ? 1.0 : 0.0,
				duration: const Duration(milliseconds: 350),
				curve: Curves.ease,
				child: IgnorePointer(
					ignoring: direction == VerticalDirection.down,
					child: child
				)
			)
		);
	}
	
	@override
	Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Copied from 'package:flutter/src/cupertino/nav_bar.dart'
class _CupertinoBackChevron extends StatelessWidget {
  const _CupertinoBackChevron();

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final TextStyle textStyle = DefaultTextStyle.of(context).style;

    // Replicate the Icon logic here to get a tightly sized icon and add
    // custom non-square padding.
    Widget iconWidget = Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, end: 6),
      child: Text.rich(
        TextSpan(
          text: String.fromCharCode(CupertinoIcons.back.codePoint),
          style: TextStyle(
            inherit: false,
            color: textStyle.color,
            fontSize: 30.0,
            fontFamily: CupertinoIcons.back.fontFamily,
            package: CupertinoIcons.back.fontPackage,
          ),
        ),
      ),
    );
    switch (textDirection) {
      case TextDirection.rtl:
        iconWidget = Transform(
          transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
          alignment: Alignment.center,
          transformHitTests: false,
          child: iconWidget,
        );
      case TextDirection.ltr:
        break;
    }

    return iconWidget;
  }
}

class _CupertinoNavigationBar extends StatelessWidget implements ObstructingPreferredSizeWidget {
	final bool transitionBetweenRoutes;
	final Widget? leading;
	final Widget? middle;
	final Color? backgroundColor;
	final Widget? trailing;
	final Brightness brightness;
	final bool autoHideOnScroll;

	const _CupertinoNavigationBar({
		required this.autoHideOnScroll,
		this.transitionBetweenRoutes = true,
		this.leading,
		this.middle,
		this.backgroundColor,
		this.trailing,
		required this.brightness
	});

	@override
	bool shouldFullyObstruct(BuildContext context) {
		return !autoHideOnScroll && backgroundColor?.a == 1;
	}

	@override
	Size get preferredSize => const Size.fromHeight(kMinInteractiveDimensionCupertino);

	@override
	Widget build(BuildContext context) {
		final child = _withNavigationBarPadding(context,
			CupertinoNavigationBar(
				automaticallyImplyLeading: false,
				automaticBackgroundVisibility: false,
				transitionBetweenRoutes: transitionBetweenRoutes,
				leading: leading,
				middle: middle,
				backgroundColor: backgroundColor,
				trailing: trailing,
				brightness: brightness
			),
			// CupertinoNavigationBar adds 16px before its leading and after its trailing content.
			horizontalContentPadding: 16
		);
		if (!autoHideOnScroll) {
			return child;
		}
		return AncestorScrollBuilder(
			builder: (context, direction, _) => AnimatedOpacity(
				opacity: direction == VerticalDirection.up ? 1.0 : 0.0,
				duration: const Duration(milliseconds: 350),
				curve: Curves.ease,
				child: IgnorePointer(
					ignoring: direction == VerticalDirection.down,
					child: child
				)
			)
		);
	}
}

class _CupertinoDrawer {
	final GlobalKey<DrawerControllerState> key;
	const _CupertinoDrawer(this.key);

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is _CupertinoDrawer &&
		other.key == key;
	@override
	int get hashCode => key.hashCode;
}

class AdaptiveScaffold extends StatefulWidget {
	final Color? backgroundColor;
	final Widget body;
	final AdaptiveBar? bar;
	final bool resizeToAvoidBottomInset;
	final Widget? drawer;
	final bool disableAutoBarHiding;

	const AdaptiveScaffold({
		required this.body,
		this.bar,
		this.backgroundColor,
		this.resizeToAvoidBottomInset = true,
		this.drawer,
		this.disableAutoBarHiding = false,
		super.key
	});

	@override
	createState() => AdaptiveScaffoldState();
}

class AdaptiveScaffoldState extends State<AdaptiveScaffold> {
	final _materialScaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'AdaptiveScaffold._materialScaffoldKey');
	final _cupertinoDrawer = _CupertinoDrawer(GlobalKey<DrawerControllerState>(debugLabel: 'AdaptiveScaffold._cupertinoDrawerKey'));
	bool _isCupertinoDrawerOpen = false;

	bool get isDrawerOpen {
		if (Settings.instance.materialStyle) {
			return _materialScaffoldKey.currentState?.isDrawerOpen ?? false;
		}
		return _isCupertinoDrawerOpen;
	}

	void closeDrawer() {
		if (Settings.instance.materialStyle) {
			_materialScaffoldKey.currentState?.closeDrawer();
		}
		else {
			_cupertinoDrawer.key.currentState?.close();
		}
	}

	double? _calculateDrawerEdgeDragWidth(BuildContext context) {
		if (widget.drawer == null) {
			return null;
		}
		final factor = context.select<ChanTabs?, double?>((t) => t?.drawerEdgeGestureWidthFactor);
		if (factor == null) {
			return null;
		}
		final twoPaneBreakpoint = Settings.twoPaneBreakpointSetting.watch(context);
		final size = MediaQuery.sizeOf(context);
		if (size.width < twoPaneBreakpoint) {
			// Based on full screen width for one-pane
			return size.width * factor;
		}
		final twoPaneSplit = Settings.twoPaneSplitSetting.watch(context) / twoPaneSplitDenominator;
		// Based on master pane width for two-pane
		return size.width * factor * twoPaneSplit;
	}

	@override
	Widget build(BuildContext context) {
		final padding = context.select<DuoLayout?, EdgeInsets?>((layout) => layout?.side == AxisDirection.up ? layout!.padding : null);
		if (padding == null || widget.bar == null) {
			return _build(context);
		}
		final safePadding = MediaQuery.paddingOf(context);
		if (safePadding.top == 0) {
			return _build(context);
		}
		final scale = Settings.interfaceScaleSetting.watch(context);
		final view = View.of(context);
		final rootTop = (view.padding.top / view.devicePixelRatio - sumAdditionalSafeAreaInsets().top) / scale;
		final viewPadding = MediaQuery.viewPaddingOf(context);
		final top = math.max(0.0, safePadding.top - rootTop + padding.top / scale);
		final viewTop = math.max(0.0, viewPadding.top - rootTop + padding.top / scale);
		if (top == safePadding.top && viewTop == viewPadding.top) {
			return _build(context);
		}
		return MediaQuery(
			data: MediaQuery.of(context).copyWith(
				padding: safePadding.copyWith(top: top),
				viewPadding: viewPadding.copyWith(top: viewTop)
			),
			child: Builder(builder: _build)
		);
	}

	Widget _build(BuildContext context) {
		final bar_ = widget.bar;
		final autoHideBars = !widget.disableAutoBarHiding && Settings.hideBarsWhenScrollingDownSetting.watch(context);
		if (ChanceTheme.materialOf(context)) {
			VoidCallback? onDrawerButtonPressed;
			final parentScaffold = Scaffold.maybeOf(context);
			if (parentScaffold?.hasDrawer ?? false) {
				onDrawerButtonPressed = parentScaffold?.openDrawer;
			}
			if (context.watch<MasterDetailLocation?>()?.isDetail ?? false) {
				// Only show drawer on master
				onDrawerButtonPressed = null;
			}
			return Scaffold(
				key: _materialScaffoldKey,
				drawer: widget.drawer,
				drawerEdgeDragWidth: _calculateDrawerEdgeDragWidth(context),
				extendBodyBehindAppBar: autoHideBars || (bar_?.backgroundColor?.a ?? 1) < 1,
				resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
				backgroundColor: widget.backgroundColor,
				appBar: bar_ == null ? null : _AppBarWithBackButtonPriority(
					autoHideOnScroll: autoHideBars,
					bar: bar_,
					onDrawerButtonPressed: onDrawerButtonPressed
				),
				body: widget.body,
			);
		}
		final parentDrawer = context.watch<_CupertinoDrawer?>();
		final leadings = <Widget>[];
		final canPop = ModalRoute.of(context)?.canPop;
		if (canPop != true &&
		    parentDrawer != null &&
				context.watch<MasterDetailLocation?>()?.isDetail != true) {
			// Only if at root route
			leadings.add(GestureDetector(
				onLongPress: () {
					Settings.instance.runQuickAction(context);
				},
				child: _NotifyingDrawerButtonWrapper(
					child: CupertinoButton(
						onPressed: () => parentDrawer.key.currentState?.open(),
						minimumSize: Size.zero,
						padding: EdgeInsets.zero,
						child: const Icon(Icons.menu)
					)
				)
			));
		}
		else if (canPop == true) {
			leadings.add(GestureDetector(
				onLongPress: () {
					Settings.instance.runQuickAction(context);
				},
				child: _NotifyingDrawerButtonWrapper(
					child: CupertinoButton(
						onPressed: () => Navigator.pop(context),
						minimumSize: Size.zero,
						padding: EdgeInsets.zero,
						child: const _CupertinoBackChevron()
					)
				)
			));
		}
		if (bar_ != null) {
			_handleLeadings(context: context, leadings: leadings, bar: bar_);
		}
		final child = CupertinoPageScaffold(
			resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
			backgroundColor: widget.backgroundColor,
			navigationBar: bar_ == null ? null : _CupertinoNavigationBar(
				autoHideOnScroll: autoHideBars,
				transitionBetweenRoutes: false,
				leading: leadings.isEmpty ? null : IconTheme.merge(
          data: const IconThemeData(
            size: 24,
          ),
          child: Row(
						mainAxisSize: MainAxisSize.min,
						children: leadings
					)
				),
				middle: bar_.title,
				backgroundColor: bar_.backgroundColor,
				trailing: bar_.actions == null ? null : IconTheme.merge(
          data: const IconThemeData(
            size: 24,
          ),
          child: Row(
						mainAxisSize: MainAxisSize.min,
						children: bar_.actions!
					)
				),
				brightness: bar_.brightness ?? ChanceTheme.brightnessOf(context)
			),
			child: widget.body
		);
		final drawer_ = widget.drawer;
		if (drawer_ == null) {
			return child;
		}
		return Provider<_CupertinoDrawer>.value(
			value: _cupertinoDrawer,
			builder: (context, _) => Stack(
				children: [
					child,
					DrawerController(
						edgeDragWidth: _calculateDrawerEdgeDragWidth(context),
						drawerCallback: (isOpen) {
							_isCupertinoDrawerOpen = isOpen;
						},
						key: context.watch<_CupertinoDrawer>().key,
						alignment: DrawerAlignment.start,
						child: drawer_
					)
				]
			)
		);
	}
}