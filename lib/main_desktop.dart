// @dart=2.9
import 'package:chan/services/persistence.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';

import './main.dart';

void main() async {
	debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
	await Persistence.initialize();
	runApp(ChanApp());
}
