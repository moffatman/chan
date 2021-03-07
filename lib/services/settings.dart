import 'dart:async';

import 'package:chan/services/util.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/scheduler.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

enum Setting_AutoloadAttachments {
	Never,
	WiFi,
	Always
}

const _AUTOLOAD_ATTACHMENTS_KEY = 'SETTING_AUTOLOAD_ATTACHMENTS';

enum Setting_Theme {
	Light,
	System,
	Dark
}

const _THEME_KEY = 'SETTING_THEME';

const _HIDE_STICKIED_THREADS_KEY = 'HIDE_STICKIED_THREADS';

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
	Brightness? _systemBrightness;
	Brightness? get systemBrightness {
		return _systemBrightness;
	}
	set systemBrightness(Brightness? newBrightness) {
		_systemBrightness = newBrightness;
		notifyListeners();
	}
	SharedPreferences? _prefs;
	Setting_AutoloadAttachments get autoloadAttachmentsPreference {
		final index = _prefs?.getInt(_AUTOLOAD_ATTACHMENTS_KEY);
		return (index == null) ? Setting_AutoloadAttachments.WiFi : Setting_AutoloadAttachments.values[index];
	}
	set autoloadAttachmentsPreference(Setting_AutoloadAttachments newValue) {
		_prefs?.setInt(_AUTOLOAD_ATTACHMENTS_KEY, newValue.index);
		notifyListeners();
	}
	Setting_Theme get themePreference {
		final index = _prefs?.getInt(_THEME_KEY);
		return (index == null) ? Setting_Theme.System : Setting_Theme.values[index];
	}
	set themePreference(Setting_Theme newValue) {
		_prefs?.setInt(_THEME_KEY, newValue.index);
		notifyListeners();
	}

	void _initializePrefs() async {
		_prefs = await SharedPreferences.getInstance();
		notifyListeners();
	}

	Settings() {
		_initializePrefs();
	}

	bool get autoloadAttachments {
		return (autoloadAttachmentsPreference == Setting_AutoloadAttachments.Always) ||
			((autoloadAttachmentsPreference == Setting_AutoloadAttachments.WiFi) && (connectivity == ConnectivityResult.wifi));
	}
	Brightness get theme {
		if (themePreference == Setting_Theme.Dark) {
			return Brightness.dark;
		}
		else if (themePreference == Setting_Theme.Light) {
			return Brightness.light;
		}
		return systemBrightness ?? Brightness.light;
	}

	bool get hideStickiedThreads {
		return _prefs?.getBool(_HIDE_STICKIED_THREADS_KEY) ?? false;
	}

	set hideStickiedThreads(bool newValue) {
		_prefs?.setBool(_HIDE_STICKIED_THREADS_KEY, newValue);
		notifyListeners();
	}
}

class SettingsSystemListener extends StatefulWidget {
	final Widget child;

	const SettingsSystemListener({
		Key? key,
		required this.child,
	}) : super(key: key);

	@override
	createState() => _SettingsSystemListenerState();
}

class _SettingsSystemListenerState extends State<SettingsSystemListener> with WidgetsBindingObserver {
	late StreamSubscription connectivitySubscription;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance!.addObserver(this);
		_checkConnectivity();
		connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
			context.read<Settings>().connectivity = result;
		});
		if (isDesktop()) {
			Future.delayed(Duration(milliseconds: 10), () {
				context.read<Settings>().connectivity = ConnectivityResult.wifi;
			});
		}
	}

	void _checkConnectivity() {
		Connectivity().checkConnectivity().then((result) {
			context.read<Settings>().connectivity = result;
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
	void didChangePlatformBrightness() {
		context.read<Settings>().systemBrightness = SchedulerBinding.instance!.window.platformBrightness;
	}

	@override
	Widget build(BuildContext context) {
		return widget.child;
	}
}