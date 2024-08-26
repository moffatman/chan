import 'dart:ui' as ui;

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
	final size = listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size;
	return switch (masterDetailHint) {
		MasterDetailLocation.onePaneMaster
			|| MasterDetailLocation.twoPaneVerticalMaster
			|| MasterDetailLocation.twoPaneVerticalDetail
			|| null => size.width,
		MasterDetailLocation.twoPaneHorizontalMaster =>
			(Settings.twoPaneSplitSetting.get(context, listen) / twoPaneSplitDenominator) * size.width,
		MasterDetailLocation.twoPaneHorizontalDetail =>
			(1 - (Settings.twoPaneSplitSetting.get(context, listen) / twoPaneSplitDenominator)) * size.width
	};
}

bool shouldHorizontalSplit(BuildContext context, {bool listen = true}) {
	final displayWidth = (listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size).width;
	double drawerWidth = 85;
	if (Settings.persistentDrawerSetting.get(context, listen) && Settings.androidDrawerSetting.get(context, listen)) {
		final displayFeatures = listen ? MediaQuery.displayFeaturesOf(context) : context.mediaQuery.displayFeatures;
		final hingeBounds = displayFeatures.tryFirstWhere((f) => (f.type == ui.DisplayFeatureType.hinge && f.bounds.left > 0 /* Only when hinge is vertical */))?.bounds;
		if (hingeBounds != null || displayWidth > 700) {
			drawerWidth = hingeBounds?.left ?? 304;
		}
	}
	final twoPaneBreakpoint = Settings.twoPaneBreakpointSetting.get(context, listen);
	// For legacy behaviour reasons, don't count 85 px of drawer width here
	return (displayWidth + 85 - drawerWidth) >= twoPaneBreakpoint;
}

double estimateDetailWidth(BuildContext context, {bool listen = true}) {
	final size = listen ? MediaQuery.sizeOf(context) : context.mediaQuery.size;
	if (shouldHorizontalSplit(context, listen: listen)) {
		final twoPaneSplit = Settings.twoPaneSplitSetting.get(context, listen);
		return (1 - (twoPaneSplit / twoPaneSplitDenominator)) * size.width;
	}
	return size.width;
}

/// Whether tab bar would be on side rather than bottom
bool isScreenWide(context) =>
	(MediaQuery.sizeOf(context).width - 85) > (MediaQuery.sizeOf(context).height - 50);