
import 'dart:io';

import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/textRecognition');

typedef RecognizedTextBlock = ({String text, Rect rect});

bool get isTextRecognitionSupported => Platform.isIOS;

Future<List<RecognizedTextBlock>> recognizeText(File image) async {
	final data = await _platform.invokeMethod<List>('recognizeText', {
		'path': image.path,
		'languages': ['en-US', 'fr-FR', 'it-IT', 'de-DE', 'es-ES', 'pt-BR', 'zh-Hans', 'zh-Hant', 'yue-Hans', 'yue-Hant', 'ko-KR', 'ja-JP', 'ru-RU', 'uk-UA'],
		'autoDetectLanguage': true
	});
	return data!.map((d) => (
		text: d['s'] as String,
		rect: Rect.fromLTWH(d['l'] as double, d['t'] as double, d['w'] as double, d['h'] as double)
	)).toList();
}