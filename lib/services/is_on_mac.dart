import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/isOnMac');

bool? _isOnMac;

Future<bool> _checkIsOnMac() async {
  try {
		return await _platform.invokeMethod('isOnMac');
	}
	on MissingPluginException {
		return false;
	}
}

Future<bool> isOnMac() async {
	_isOnMac ??= await _checkIsOnMac();
	return _isOnMac!;
}