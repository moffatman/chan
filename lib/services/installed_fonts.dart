import 'dart:io';

import 'package:chan/services/apple.dart';

final _pattern = RegExp(r'(.*).ttf');

Future<List<String>> getInstalledFontFamilies() async {
	if (Platform.isAndroid) {
		return await Directory('/system/fonts').list().expand<String>((file) {
			final name = _pattern.firstMatch(file.path)?.group(1);
			if (name != null) {
				return [name];
			}
			return [];
		}).toList();
	}
	if (Platform.isIOS) {
		return getUIFontFamilyNames();
	}
	throw Exception('Installed font listing not implemented for ${Platform.operatingSystem}');
}