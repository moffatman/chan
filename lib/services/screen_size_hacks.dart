import 'package:chan/pages/master_detail.dart';
import 'package:chan/services/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

double estimateWidth(BuildContext context, {bool listen = true}) {
	final masterDetailHint = listen ? context.watch<MasterDetailHint?>() : context.read<MasterDetailHint?>();
	final size = listen ? MediaQuery.sizeOf(context) : context.getInheritedWidgetOfExactType<MediaQuery>()!.data.size;
	return switch (masterDetailHint?.location) {
		MasterDetailLocation.onePaneMaster
			|| MasterDetailLocation.twoPaneVerticalMaster
			|| MasterDetailLocation.twoPaneVerticalDetail
			|| null => size.width,
		MasterDetailLocation.twoPaneHorizontalMaster =>
			((listen ? Settings.twoPaneSplitSetting.watch(context) : Settings.instance.twoPaneSplit) / twoPaneSplitDenominator) * size.width,
		MasterDetailLocation.twoPaneHorizontalDetail =>
			(1 - ((listen ? Settings.twoPaneSplitSetting.watch(context) : Settings.instance.twoPaneSplit) / twoPaneSplitDenominator)) * size.width
	};
}