import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _platform = MethodChannel('com.moffatman.chan/launchUrl');

Future<bool> launchUrlExternally(Uri url) async {
	if (!Platform.isAndroid) {
		return await launchUrl(url, mode: LaunchMode.externalApplication);
	}
	return await _platform.invokeMethod('launchUrl', {
		'url': url.toString()
	}) == true;
}