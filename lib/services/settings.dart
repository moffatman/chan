import 'dart:async';

import 'package:chan/services/util.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum Setting_AutoloadAttachments {
	Never,
	WiFi,
	Always
}

class Settings extends ChangeNotifier {
	String? filename;
	ConnectivityResult? _connectivity;
	ConnectivityResult? get connectivity {
		return _connectivity;
	}
	set connectivity(ConnectivityResult? newConnectivity) {
		_connectivity = newConnectivity;
		notifyListeners();
	}
	late Setting_AutoloadAttachments autoloadAttachmentsPreference;
	SharedPreferences? _prefs;

	void _initializePrefs() async {
		_prefs = await SharedPreferences.getInstance();
		notifyListeners();
	}

	Settings({
		required this.autoloadAttachmentsPreference
	}) {
		_initializePrefs();
	}

	bool get autoloadAttachments {
		return (autoloadAttachmentsPreference == Setting_AutoloadAttachments.Always) ||
			((autoloadAttachmentsPreference == Setting_AutoloadAttachments.WiFi) && (connectivity == ConnectivityResult.wifi));
	}

	static Settings of(BuildContext context) {
		return context.dependOnInheritedWidgetOfExactType<_SettingsData>()!.settings;
	}
}

class _SettingsData extends InheritedWidget {
	final Settings settings;

	const _SettingsData({
		required this.settings,
		required Widget child,
		Key? key
	}) : super(child: child, key: key);

	@override
	bool updateShouldNotify(_SettingsData old) {
		return true;
	}
}

class SettingsHandler extends StatefulWidget {
	final Widget child;
	final Settings Function() settingsBuilder;

	const SettingsHandler({
		Key? key,
		required this.child,
		required this.settingsBuilder
	}) : super(key: key);

	@override
	createState() => _SettingsHandlerState();
}

class _SettingsHandlerState extends State<SettingsHandler> with WidgetsBindingObserver {
	late StreamSubscription connectivitySubscription;
	late Settings settings;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance!.addObserver(this);
		settings = widget.settingsBuilder();
		_checkConnectivity();
		connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
			settings.connectivity = result;
		});
		if (isDesktop()) {
			settings.connectivity = ConnectivityResult.wifi;
		}
	}

	void _checkConnectivity() {
		Connectivity().checkConnectivity().then((result) {
			settings.connectivity = result;
		});
	}

	@override
	void dispose() {
		super.dispose();
		WidgetsBinding.instance!.removeObserver(this);
		connectivitySubscription.cancel();
	}

	@override
	void didChangeAppLifecycleState(AppLifecycleState state) {
		if (state == AppLifecycleState.resumed) {
			_checkConnectivity();
		}
	}

	@override
	Widget build(BuildContext context) {
		return _SettingsData(
			child: widget.child,
			settings: settings
		);
	}
}