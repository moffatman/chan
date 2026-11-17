import 'dart:ui' as ui;
import 'dart:ui';

import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

extension ReadMediaQuery on BuildContext {
	MediaQueryData get mediaQuery {
		return getInheritedWidgetOfExactType<MediaQuery>()!.data;
	}
}

double estimateWidth(BuildContext context, {bool listen = true}) {
	final masterDetailHint = Provider.of<MasterDetailLocation?>(context, listen: listen);
	final width = _doHorizontalSplit(context, listen: listen).contentWidth;
	return switch (masterDetailHint) {
		MasterDetailLocation.onePaneMaster
			|| MasterDetailLocation.twoPaneVerticalMaster
			|| MasterDetailLocation.twoPaneVerticalDetail
			|| null => width,
		MasterDetailLocation.twoPaneHorizontalMaster =>
			(Settings.twoPaneSplitSetting.get(context, listen) / twoPaneSplitDenominator) * width,
		MasterDetailLocation.twoPaneHorizontalDetail =>
			(1 - (Settings.twoPaneSplitSetting.get(context, listen) / twoPaneSplitDenominator)) * width
	};
}

double _navigationSidebarWidth(Size size, List<ui.DisplayFeature> displayFeatures, {
	required bool androidDrawer,
	required bool persistentDrawer,
	required bool hasDuoBar
}) {
	if (!androidDrawer) {
		return hasDuoBar || isScreenSizeWide(size) ? 85 : 0;
	}
	if (!persistentDrawer) return 0;
	final hingeBounds = displayFeatures.tryFirstWhere((f) => f.type == ui.DisplayFeatureType.hinge && f.bounds.left > 0)?.bounds;
	return hingeBounds?.left ?? (size.width > 650 ? 304 : 0);
}

double navigationSidebarWidthOf(BuildContext context, {bool listen = true}) => _navigationSidebarWidth(
	listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size,
	listen ? MediaQuery.displayFeaturesOf(context) : context.mediaQuery.displayFeatures,
	androidDrawer: Settings.androidDrawerSetting.get(context, listen),
	persistentDrawer: Settings.persistentDrawerSetting.get(context, listen),
	hasDuoBar: Provider.of<DuoLayout?>(context, listen: listen)?.hasSidebar ?? false
);

({bool shouldSplit, double contentWidth}) _doHorizontalSplitStatic() {
	final displaySize = (PlatformDispatcher.instance.views.first.physicalSize / PlatformDispatcher.instance.views.first.devicePixelRatio) / Settings.instance.interfaceScale;
	final drawerWidth = _navigationSidebarWidth(displaySize, PlatformDispatcher.instance.views.first.displayFeatures,
		androidDrawer: Settings.instance.androidDrawer,
		persistentDrawer: Settings.instance.persistentDrawer,
		hasDuoBar: duoLayout.value?.hasSidebar ?? false
	);
	final twoPaneBreakpoint = Settings.instance.twoPaneBreakpoint;
	return (
		// For legacy behaviour reasons, don't count 85 px of drawer width here
		shouldSplit: (displaySize.width + 85 - drawerWidth) >= twoPaneBreakpoint,
		contentWidth: displaySize.width - drawerWidth
	);
}


({bool shouldSplit, double contentWidth}) _doHorizontalSplit(BuildContext context, {bool listen = true}) {
	final displaySize = listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size;
	final drawerWidth = navigationSidebarWidthOf(context, listen: listen);
	final twoPaneBreakpoint = Settings.twoPaneBreakpointSetting.get(context, listen);
	return (
		// For legacy behaviour reasons, don't count 85 px of drawer width here
		shouldSplit: (displaySize.width + 85 - drawerWidth) >= twoPaneBreakpoint,
		contentWidth: displaySize.width - drawerWidth
	);
}

bool shouldHorizontalSplit(BuildContext context, {bool listen = true}) {
	return _doHorizontalSplit(context, listen: listen).shouldSplit;
}

double estimateMasterWidthStatic() {
	final split = _doHorizontalSplitStatic();
	if (split.shouldSplit) {
		final twoPaneSplit = Settings.instance.twoPaneSplit;
		return (twoPaneSplit / twoPaneSplitDenominator) * split.contentWidth;
	}
	return split.contentWidth;
}

double estimateDetailWidth(BuildContext context, {bool listen = true}) {
	final split = _doHorizontalSplit(context, listen: listen);
	if (split.shouldSplit) {
		final twoPaneSplit = Settings.twoPaneSplitSetting.get(context, listen);
		return (1 - (twoPaneSplit / twoPaneSplitDenominator)) * split.contentWidth;
	}
	return split.contentWidth;
}

/// Whether tab bar would be on side rather than bottom
bool isScreenWide(BuildContext context) => (Provider.of<DuoLayout?>(context)?.hasSidebar ?? false) || isScreenSizeWide(MediaQuery.sizeOf(context));
bool isScreenSizeWide(Size size) => (size.width - 85) > (size.height - 50);
