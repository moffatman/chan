import 'dart:ui' as ui;
import 'dart:ui';

import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/settings.dart';
import 'package:chan/util.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

extension _ReadMediaQuery on BuildContext {
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

({bool shouldSplit, double contentWidth}) _doHorizontalSplitStatic() {
	final displaySize = (PlatformDispatcher.instance.views.first.physicalSize / PlatformDispatcher.instance.views.first.devicePixelRatio) / Settings.instance.interfaceScale;
	double drawerWidth = isScreenSizeWide(displaySize) ? 85 : 0;
	if (Settings.instance.persistentDrawer && Settings.instance.androidDrawer) {
		final displayFeatures = PlatformDispatcher.instance.views.first.displayFeatures;
		final hingeBounds = displayFeatures.tryFirstWhere((f) => (f.type == ui.DisplayFeatureType.hinge && f.bounds.left > 0 /* Only when hinge is vertical */))?.bounds;
		if (hingeBounds != null || displaySize.width > 700) {
			drawerWidth = hingeBounds?.left ?? 304;
		}
	}
	final twoPaneBreakpoint = Settings.instance.twoPaneBreakpoint;
	return (
		// For legacy behaviour reasons, don't count 85 px of drawer width here
		shouldSplit: (displaySize.width + 85 - drawerWidth) >= twoPaneBreakpoint,
		contentWidth: displaySize.width - drawerWidth
	);
}


({bool shouldSplit, double contentWidth}) _doHorizontalSplit(BuildContext context, {bool listen = true}) {
	final displaySize = listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size;
	double drawerWidth = isScreenSizeWide(displaySize) ? 85 : 0;
	if (Settings.persistentDrawerSetting.get(context, listen) && Settings.androidDrawerSetting.get(context, listen)) {
		final displayFeatures = listen ? MediaQuery.displayFeaturesOf(context) : context.mediaQuery.displayFeatures;
		final hingeBounds = displayFeatures.tryFirstWhere((f) => (f.type == ui.DisplayFeatureType.hinge && f.bounds.left > 0 /* Only when hinge is vertical */))?.bounds;
		if (hingeBounds != null || displaySize.width > 700) {
			drawerWidth = hingeBounds?.left ?? 304;
		}
	}
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
bool isScreenWide(BuildContext context) => isScreenSizeWide(MediaQuery.sizeOf(context));
bool isScreenSizeWide(Size size) => (size.width - 85) > (size.height - 50);
