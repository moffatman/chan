import 'dart:io';

import 'package:chan/services/apple.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/util.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final _pattern = RegExp(r'([^/]+).[ot]tf');

Future<List<String>> getInstalledFontFamilies(BuildContext context) async {
	if (Platform.isAndroid) {
		return await modalLoad(context, 'Searching...', (controller) async {
			final fonts = <String>[];
			final list = Directory('/system/fonts').listSync();
			for (final pair in list.indexed) {
				final name = _pattern.firstMatch(pair.$2.path)?.group(1);
				if (name != null) {
					final loader = FontLoader(name);
					loader.addFont(File(pair.$2.path).readAsBytes().then((b) => b.buffer.asByteData()));
					await loader.load();
					fonts.add(name);
				}
				controller.progress.value = ('', (pair.$1 + 1) / list.length);
			}
			return fonts;
		});
	}
	if (Platform.isIOS) {
		return getUIFontFamilyNames();
	}
	throw Exception('Installed font listing not implemented for ${Platform.operatingSystem}');
}

String? fontLoadingError;
String? fallbackFontLoadingError;

Future<void> initializeFonts() async {
	fontLoadingError = null;
	fallbackFontLoadingError = null;
	try {
		final fontFamilyName = Persistence.settings.fontFamily;
		if (fontFamilyName != null &&
		    (fontFamilyName.endsWith('.ttf') || fontFamilyName.endsWith('.otf'))) {
			// If fontFamily ends with .ttf or .otf, load it from documents dir
			final family = fontFamilyName.beforeFirst('.');
			final file = Persistence.documentsDirectory.dir(Persistence.fontsDir).file(fontFamilyName);
			if (!file.existsSync()) {
				throw FileSystemException('Font file not found', file.path);
			}
			final loader = FontLoader(family);
			final bytes = await file.readAsBytes();
			loader.addFont(Future.value(ByteData.view(bytes.buffer)));
			await loader.load();
		}
		else if (fontFamilyName != null && Platform.isAndroid) {
			// Need to load from /system/fonts
			final ttf = File('/system/fonts/$fontFamilyName.ttf');
			final otf = File('/system/fonts/$fontFamilyName.otf');
			final File file;
			if (ttf.existsSync()) {
				file = ttf;
			}
			else if (otf.existsSync()) {
				file = otf;
			}
			else {
				throw FileSystemException('Not able to find $fontFamilyName in /system/fonts');
			}
			final loader = FontLoader(fontFamilyName);
			final bytes = await file.readAsBytes();
			loader.addFont(Future.value(ByteData.view(bytes.buffer)));
			await loader.load();
		}
	}
	catch (e, st) {
		fontLoadingError = e.toString();
		Future.error(e, st); // Report to crashlytics
	}
	try {
		final fontFamilyFallbackName = Persistence.settings.fontFamilyFallback;
		if (fontFamilyFallbackName != null &&
		    (fontFamilyFallbackName.endsWith('.ttf') || fontFamilyFallbackName.endsWith('.otf'))) {
			// If fontFamily ends with .ttf or .otf, load it from documents dir
			final family = fontFamilyFallbackName.beforeFirst('.');
			final file = Persistence.documentsDirectory.dir(Persistence.fontsDir).file(fontFamilyFallbackName);
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
		fallbackFontLoadingError = e.toString();
		Future.error(e, st); // Report to crashlytics
	}
}