import 'dart:convert';
import 'dart:io';

import 'package:chan/services/clipboard_image.dart';
import 'package:chan/services/persistence.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
	final binding = TestWidgetsFlutterBinding.ensureInitialized();
	const channel = MethodChannel('com.moffatman.chan/clipboard');

		test('copies image data to the platform clipboard', () async {
		final temporaryDirectory = await Directory.systemTemp.createTemp('chance_clipboard_test');
		addTearDown(() async {
			binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
			await temporaryDirectory.delete(recursive: true);
		});
		Persistence.temporaryDirectory = temporaryDirectory;
		final staleClipboardFile = File('${temporaryDirectory.path}/clipboard/stale.png');
		await staleClipboardFile.create(recursive: true);
		MethodCall? receivedCall;
		binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
			receivedCall = call;
			return null;
		});
		final source = File('${temporaryDirectory.path}/image.bin');
		await source.writeAsBytes(base64Decode(
			'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=='
		));

		await copyImageToClipboard(source);

		expect(receivedCall?.method, 'setClipboardImage');
		final arguments = receivedCall?.arguments as Map<Object?, Object?>;
		expect(arguments['mimeType'], 'image/png');
		final copiedPath = arguments['path'] as String;
		expect(copiedPath, endsWith('.png'));
		expect(
			File(copiedPath).parent.path.replaceAll('\\', '/'),
			'${temporaryDirectory.path.replaceAll('\\', '/')}/clipboard'
		);
		expect(await File(copiedPath).exists(), isTrue);
		expect(await staleClipboardFile.exists(), isFalse);
	});
}
