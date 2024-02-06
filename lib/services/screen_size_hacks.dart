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
			(context.select<EffectiveSettings, int>((s) => s.twoPaneSplit) / twoPaneSplitDenominator) * size.width,
		MasterDetailLocation.twoPaneHorizontalDetail =>
			(1 - (context.select<EffectiveSettings, int>((s) => s.twoPaneSplit) / twoPaneSplitDenominator)) * size.width
	};
}