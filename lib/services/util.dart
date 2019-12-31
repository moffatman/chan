import 'dart:io';

bool isDesktop() {
	return !Platform.isIOS && !Platform.isAndroid;
}