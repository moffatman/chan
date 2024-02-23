import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

double estimateWidth(BuildContext context) {
	final masterDetailHint = context.watch<MasterDetailHint?>();
	final size = MediaQuery.sizeOf(context);
	return switch (masterDetailHint?.location) {
		MasterDetailLocation.onePaneMaster
			|| MasterDetailLocation.twoPaneVerticalMaster
			|| MasterDetailLocation.twoPaneVerticalDetail
			|| null => size.width,
		MasterDetailLocation.twoPaneHorizontalMaster =>
			(Settings.twoPaneSplitSetting.watch(context) / twoPaneSplitDenominator) * size.width,
		MasterDetailLocation.twoPaneHorizontalDetail =>
			(1 - (Settings.twoPaneSplitSetting.watch(context) / twoPaneSplitDenominator)) * size.width
	};
}