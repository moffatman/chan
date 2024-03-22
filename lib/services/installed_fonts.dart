import 'dart:io';

import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/services.dart';

final _pattern = RegExp(r'([^/]+).[ot]tf');

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

String? fontLoadingError;

Future<void> initializeFonts() async {
	fontLoadingError = null;
	try {
		final fontFamilyName = Persistence.settings.fontFamily;
		if (fontFamilyName != null &&
		    (fontFamilyName.endsWith('.ttf') || fontFamilyName.endsWith('.otf'))) {
			// If fontFamily ends with .ttf or .otf, load it from documents dir
			final family = fontFamilyName.split('.').first;
			final file = File('${Persistence.documentsDirectory.path}/${Persistence.fontsDir}/$fontFamilyName');
			if (!file.existsSync()) {
				throw FileSystemException('Font file not found', file.path);
			}
			final loader = FontLoader(family);
			final bytes = await file.readAsBytes();
			loader.addFont(Future.value(ByteData.view(bytes.buffer)));
			await loader.load();
		}
	}
	catch (e, st) {
		fontLoadingError = e.toString();
		Future.error(e, st); // Report to crashlytics
	}
}