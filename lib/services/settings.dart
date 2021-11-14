import 'dart:async';
import 'dart:io';

import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/scheduler.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
part 'settings.g.dart';

const CONTENT_SETTINGS_API_ROOT = 'https://us-central1-chan-329813.cloudfunctions.net/preferences';
final _punctuationRegex = RegExp('(\\W+|s\\W)');
final _badWords = Set.from(ProfanityFilter().wordsToFilterOutList);
const _DEFAULT_SITE = {
	'type': 'lainchan',
	'name': 'testchan',
	'baseUrl': 'callum.crabdance.com'
};

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

@HiveType(typeId: 20)
class ContentSettings {
	@HiveField(0)
	bool images;
	@HiveField(1)
	bool nsfwBoards;
	@HiveField(2)
	bool nsfwImages;
	@HiveField(3)
	bool nsfwText;
	@HiveField(4)
	dynamic? site;

	ContentSettings({
		this.images = false,
		this.nsfwBoards = false,
		this.nsfwImages = false,
		this.nsfwText = false,
		dynamic site
	}) : this.site = site ?? _DEFAULT_SITE;
}

@HiveType(typeId: 0)
class SavedSettings extends HiveObject {
	@HiveField(0)
	AutoloadAttachmentsSetting autoloadAttachments;
	@HiveField(1)
	ThemeSetting theme;
	@HiveField(2)
	bool hideOldStickiedThreads;
	@HiveField(3)
	ThreadSortingMethod catalogSortingMethod;
	@HiveField(4)
	bool reverseCatalogSorting;
	@HiveField(5)
	ThreadSortingMethod savedThreadsSortingMethod;
	@HiveField(6)
	bool autoRotateInGallery;
	@HiveField(7)
	String currentBoardName;
	@HiveField(8)
	bool darkThemeIsPureBlack;
	@HiveField(9)
	bool useTouchLayout;
	@HiveField(10)
	String userId;
  @HiveField(11)
	ContentSettings contentSettings;

	SavedSettings({
		AutoloadAttachmentsSetting? autoloadAttachments,
		ThemeSetting? theme = ThemeSetting.System,
		bool? hideOldStickiedThreads,
		ThreadSortingMethod? catalogSortingMethod,
		bool? reverseCatalogSorting,
		ThreadSortingMethod? savedThreadsSortingMethod,
		bool? autoRotateInGallery,
		String? currentBoardName,
		bool? darkThemeIsPureBlack,
		bool? useTouchLayout,
		String? userId,
		ContentSettings? contentSettings
	}): this.autoloadAttachments = autoloadAttachments ?? AutoloadAttachmentsSetting.WiFi,
		this.theme = theme ?? ThemeSetting.System,
		this.hideOldStickiedThreads = hideOldStickiedThreads ?? false,
		this.catalogSortingMethod = catalogSortingMethod ?? ThreadSortingMethod.Unsorted,
		this.reverseCatalogSorting = reverseCatalogSorting ?? false,
		this.savedThreadsSortingMethod = savedThreadsSortingMethod ?? ThreadSortingMethod.SavedTime,
		this.autoRotateInGallery = autoRotateInGallery ?? false,
		this.currentBoardName = currentBoardName ?? 'tv',
		this.darkThemeIsPureBlack = darkThemeIsPureBlack ?? false,
		this.useTouchLayout = useTouchLayout ?? (Platform.isAndroid || Platform.isIOS),
		this.userId = userId ?? Uuid().v4(),
		this.contentSettings = contentSettings ?? ContentSettings();
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

	bool get darkThemeIsPureBlack => _settings.darkThemeIsPureBlack;
	set darkThemeIsPureBlack(bool setting) {
		_settings.darkThemeIsPureBlack = setting;
		_settings.save();
		notifyListeners();
	}

	bool get useTouchLayout => _settings.useTouchLayout;
	set useTouchLayout(bool setting) {
		_settings.useTouchLayout = setting;
		_settings.save();
		notifyListeners();
	}

	bool get hideOldStickiedThreads => _settings.hideOldStickiedThreads;
	set hideOldStickiedThreads(bool setting) {
		_settings.hideOldStickiedThreads = setting;
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

	String get currentBoardName => _settings.currentBoardName;
	set currentBoardName(String setting) {
		_settings.currentBoardName = setting;
		_settings.save();
		notifyListeners();
	}

	ContentSettings get contentSettings => _settings.contentSettings;
	String get contentSettingsUrl => '$CONTENT_SETTINGS_API_ROOT/user/${_settings.userId}/edit';

	void updateContentSettings() async {
		try {
			final response = await Dio().get('$CONTENT_SETTINGS_API_ROOT/user/${_settings.userId}');
			_settings.contentSettings.images = response.data['images'];
			_settings.contentSettings.nsfwBoards = response.data['nsfwBoards'];
			_settings.contentSettings.nsfwImages = response.data['nsfwImages'];
			_settings.contentSettings.nsfwText = response.data['nsfwText'];
			_settings.contentSettings.site = response.data['site'] ?? _DEFAULT_SITE;
			await _settings.save();
			notifyListeners();
		}
		catch (e) {
			print('Error updating content settings: $e');
		}
	}

	bool showBoard(BuildContext context, String board) {
		return context.read<Persistence>().getBoard(board).isWorksafe || _settings.contentSettings.nsfwBoards;
	}

	bool showImages(BuildContext context, String board) {
		return _settings.contentSettings.images && (context.read<Persistence>().getBoard(board).isWorksafe || _settings.contentSettings.nsfwImages);
	}

	String filterProfanity(String input) {
		if (_settings.contentSettings.nsfwText) {
			return input;
		}
		else {
			String output = input;
			final words = input.split(_punctuationRegex);
			for (final word in words) {
				if (_badWords.contains(word)) {
					output = input.replaceAll(word, '*' * word.length);
				}
			}
			return output;
		}
	}

	EffectiveSettings() {
		updateContentSettings();
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