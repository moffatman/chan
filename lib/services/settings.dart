import 'dart:async';
import 'dart:io';

import 'package:chan/services/util.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
part 'settings.g.dart';

@HiveType(typeId: 1)
enum AutoloadAttachmentsSetting {
	@HiveField(0)
	Never,
	@HiveField(1)
	WiFi,
	@HiveField(2)
	Always
}

@HiveType(typeId: 2)
enum ThemeSetting {
	@HiveField(0)
	Light,
	@HiveField(1)
	System,
	@HiveField(2)
	Dark
}

@HiveType(typeId: 17)
enum ThreadSortingMethod {
	@HiveField(0)
	Unsorted,
	@HiveField(1)
	LastPostTime,
	@HiveField(2)
	ReplyCount,
	@HiveField(3)
	OPTime,
	@HiveField(4)
	SavedTime
}

@HiveType(typeId: 0)
class SavedSettings extends HiveObject {
	@HiveField(0)
	AutoloadAttachmentsSetting autoloadAttachments;
	@HiveField(1)
	ThemeSetting theme;
	@HiveField(2)
	bool hideStickiedThreads;
	@HiveField(3)
	ThreadSortingMethod catalogSortingMethod;
	@HiveField(4)
	bool reverseCatalogSorting;
	@HiveField(5)
	ThreadSortingMethod savedThreadsSortingMethod;
	@HiveField(6)
	bool autoRotateInGallery;

	SavedSettings({
		AutoloadAttachmentsSetting? autoloadAttachments,
		ThemeSetting? theme = ThemeSetting.System,
		bool? hideStickiedThreads,
		ThreadSortingMethod? catalogSortingMethod,
		bool? reverseCatalogSorting,
		ThreadSortingMethod? savedThreadsSortingMethod,
		bool? autoRotateInGallery
	}): this.autoloadAttachments = autoloadAttachments ?? AutoloadAttachmentsSetting.WiFi,
		this.theme = theme ?? ThemeSetting.System,
		this.hideStickiedThreads = hideStickiedThreads ?? false,
		this.catalogSortingMethod = catalogSortingMethod ?? ThreadSortingMethod.Unsorted,
		this.reverseCatalogSorting = reverseCatalogSorting ?? false,
		this.savedThreadsSortingMethod = savedThreadsSortingMethod ?? ThreadSortingMethod.SavedTime,
		this.autoRotateInGallery = autoRotateInGallery ?? false;
}

class EffectiveSettings extends ChangeNotifier {
	SavedSettings _settings = Hive.box<SavedSettings>('settings').get('settings', defaultValue: SavedSettings())!;
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
	set systemBrightness(Brightness? newBrightness) {
		_systemBrightness = newBrightness;
		notifyListeners();
	}
	AutoloadAttachmentsSetting get autoloadAttachmentsSetting => _settings.autoloadAttachments;
	set autoloadAttachmentsSetting(AutoloadAttachmentsSetting setting) {
		_settings.autoloadAttachments = setting;
		_settings.save();
		notifyListeners();
	}
	bool get autoloadAttachments {
		return (_settings.autoloadAttachments == AutoloadAttachmentsSetting.Always) ||
			((_settings.autoloadAttachments == AutoloadAttachmentsSetting.WiFi) && (connectivity == ConnectivityResult.wifi));
	}
	ThemeSetting get themeSetting => _settings.theme;
	set themeSetting(ThemeSetting setting) {
		_settings.theme = setting;
		_settings.save();
		notifyListeners();
	}
	Brightness get theme {
		if (_settings.theme == ThemeSetting.Dark) {
			return Brightness.dark;
		}
		else if (_settings.theme == ThemeSetting.Light) {
			return Brightness.light;
		}
		return _systemBrightness ?? Brightness.light;
	}

	bool get useTouchLayout => Platform.isAndroid || Platform.isIOS;

	bool get hideStickiedThreads => _settings.hideStickiedThreads;
	set hideStickiedThreads(bool setting) {
		_settings.hideStickiedThreads = setting;
		_settings.save();
		notifyListeners();
	}

	ThreadSortingMethod get catalogSortingMethod => _settings.catalogSortingMethod;
	set catalogSortingMethod(ThreadSortingMethod setting) {
		_settings.catalogSortingMethod = setting;
		_settings.save();
		notifyListeners();
	}
	bool get reverseCatalogSorting => _settings.reverseCatalogSorting;
	set reverseCatalogSorting(bool setting) {
		_settings.reverseCatalogSorting = setting;
		_settings.save();
		notifyListeners();
	}

	ThreadSortingMethod get savedThreadsSortingMethod => _settings.savedThreadsSortingMethod;
	set savedThreadsSortingMethod(ThreadSortingMethod setting) {
		_settings.savedThreadsSortingMethod = setting;
		_settings.save();
		notifyListeners();
	}

	bool get autoRotateInGallery => _settings.autoRotateInGallery;
	set autoRotateInGallery(bool setting) {
		_settings.autoRotateInGallery = setting;
		_settings.save();
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
			context.read<EffectiveSettings>().connectivity = result;
		});
		if (isDesktop()) {
			Future.delayed(Duration(milliseconds: 10), () {
				context.read<EffectiveSettings>().connectivity = ConnectivityResult.wifi;
			});
		}
	}

	void _checkConnectivity() {
		Connectivity().checkConnectivity().then((result) {
			context.read<EffectiveSettings>().connectivity = result;
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
		context.read<EffectiveSettings>().systemBrightness = SchedulerBinding.instance!.window.platformBrightness;
	}

	@override
	Widget build(BuildContext context) {
		return widget.child;
	}
}