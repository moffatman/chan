import 'package:flutter/services.dart';

const _platform = MethodChannel('com.moffatman.chan/apple');

bool? _isOnMac;
bool? _isDevelopmentBuild;

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

Future<bool> _checkIsDevelopmentBuild() async {
	try {
		return await _platform.invokeMethod('isDevelopmentBuild');
	}
	on MissingPluginException {
		return false;
	}
}

Future<bool> isDevelopmentBuild() async {
	_isDevelopmentBuild ??= await _checkIsDevelopmentBuild();
	return _isDevelopmentBuild!;
}