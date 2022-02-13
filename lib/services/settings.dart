import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/scheduler.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
part 'settings.g.dart';

const contentSettingsApiRoot = 'https://us-central1-chan-329813.cloudfunctions.net/preferences';
final _punctuationRegex = RegExp('(\\W+|s\\W)');
final _badWords = Set.from(ProfanityFilter().wordsToFilterOutList);
const defaultSite = {
	'type': 'lainchan',
	'name': 'testchan',
	'baseUrl': 'callum.crabdance.com'
};
final defaultLightTheme = SavedTheme(
	primaryColor: Colors.black,
	secondaryColor: Colors.red,
	barColor: const Color(0xFFF9F9F9),
	backgroundColor: CupertinoColors.systemBackground
);
final defaultDarkTheme = SavedTheme(
	primaryColor: Colors.white,
	secondaryColor: Colors.red,
	barColor: const Color.fromRGBO(40, 40, 40, 1),
	backgroundColor: const Color.fromRGBO(20, 20, 20, 1)
);
const twoPaneSplitDenominator = 12;

@HiveType(typeId: 1)
enum AutoloadAttachmentsSetting {
	@HiveField(0)
	never,
	@HiveField(1)
	wifi,
	@HiveField(2)
	always
}

@HiveType(typeId: 2)
enum TristateSystemSetting {
	@HiveField(0)
	a,
	@HiveField(1)
	system,
	@HiveField(2)
	b
}

@HiveType(typeId: 17)
enum ThreadSortingMethod {
	@HiveField(0)
	unsorted,
	@HiveField(1)
	lastPostTime,
	@HiveField(2)
	replyCount,
	@HiveField(3)
	threadPostTime,
	@HiveField(4)
	savedTime
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
	dynamic site;

	ContentSettings({
		this.images = false,
		this.nsfwBoards = false,
		this.nsfwImages = false,
		this.nsfwText = false,
		dynamic site
	}) : site = site ?? defaultSite;
}

class ColorAdapter extends TypeAdapter<Color> {
	@override
	final int typeId = 24;

	@override
  Color read(BinaryReader reader) {
		return Color(reader.readInt32());
  }

  @override
  void write(BinaryWriter writer, Color obj) {
    writer.writeInt32(obj.value);
  }
}

const _defaultQuoteColor = Color.fromRGBO(120, 153, 34, 1);

@HiveType(typeId: 25)
class SavedTheme {
	@HiveField(0)
	Color backgroundColor;
	@HiveField(1)
	Color barColor;
	@HiveField(2)
	Color primaryColor;
	@HiveField(3)
	Color secondaryColor;
	@HiveField(4, defaultValue: _defaultQuoteColor)
	Color quoteColor;

	SavedTheme({
		required this.backgroundColor,
		required this.barColor,
		required this.primaryColor,
		required this.secondaryColor,
		this.quoteColor = _defaultQuoteColor
	});
}

@HiveType(typeId: 0)
class SavedSettings extends HiveObject {
	@HiveField(0)
	AutoloadAttachmentsSetting autoloadAttachments;
	@HiveField(1)
	TristateSystemSetting theme;
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
	@HiveField(9)
	bool useTouchLayout;
	@HiveField(10)
	String userId;
  @HiveField(11)
	ContentSettings contentSettings;
	@HiveField(13)
	String filterConfiguration;
	@HiveField(14)
	bool boardSwitcherHasKeyboardFocus;
	@HiveField(15)
	SavedTheme lightTheme;
	@HiveField(16)
	SavedTheme darkTheme;
	@HiveField(17)
	Map<String, PersistentRecentSearches> recentSearchesBySite;
	@HiveField(18)
	Map<String, PersistentBrowserState> browserStateBySite;
	@HiveField(19)
	Map<String, Map<String, SavedPost>> savedPostsBySite;
	@HiveField(20)
	Map<String, Map<String, SavedAttachment>> savedAttachmentsBySite;
	@HiveField(21)
	Map<String, Map<String, ImageboardBoard>> boardsBySite;
	@HiveField(22)
	double twoPaneBreakpoint;
	@HiveField(23)
	int twoPaneSplit;
	@HiveField(24)
	bool useCatalogGrid;
	@HiveField(25)
	double catalogGridWidth;
	@HiveField(26)
	double catalogGridHeight;
	@HiveField(27)
	bool showImageCountInCatalog;
	@HiveField(28)
	bool showClockIconInCatalog;
	@HiveField(29)
	List<String> embedRegexes;
	@HiveField(30)
	TristateSystemSetting supportMouse;
  @HiveField(31)
	bool showNameInCatalog;
	@HiveField(32)
	double interfaceScale;
	@HiveField(33)
	bool showAnimations;
	@HiveField(34)
	bool imagesOnRight;

	SavedSettings({
		AutoloadAttachmentsSetting? autoloadAttachments,
		TristateSystemSetting? theme = TristateSystemSetting.system,
		bool? hideOldStickiedThreads,
		ThreadSortingMethod? catalogSortingMethod,
		bool? reverseCatalogSorting,
		ThreadSortingMethod? savedThreadsSortingMethod,
		bool? autoRotateInGallery,
		String? currentBoardName,
		bool? useTouchLayout,
		String? userId,
		ContentSettings? contentSettings,
		int? boardCatalogColumns,
		String? filterConfiguration,
		bool? boardSwitcherHasKeyboardFocus,
		SavedTheme? lightTheme,
		SavedTheme? darkTheme,
		Map<String, PersistentRecentSearches>? recentSearchesBySite,
		Map<String, PersistentBrowserState>? browserStateBySite,
		Map<String, Map<String, SavedPost>>? savedPostsBySite,
		Map<String, Map<String, SavedAttachment>>? savedAttachmentsBySite,
		Map<String, Map<String, ImageboardBoard>>? boardsBySite,
		double? twoPaneBreakpoint,
		int? twoPaneSplit,
		bool? useCatalogGrid,
		double? catalogGridWidth,
		double? catalogGridHeight,
		bool? showImageCountInCatalog,
		bool? showClockIconInCatalog,
		List<String>? embedRegexes,
		TristateSystemSetting? supportMouse,
		bool? showNameInCatalog,
		double? interfaceScale,
		bool? showAnimations,
		bool? imagesOnRight,
	}): autoloadAttachments = autoloadAttachments ?? AutoloadAttachmentsSetting.wifi,
		theme = theme ?? TristateSystemSetting.system,
		hideOldStickiedThreads = hideOldStickiedThreads ?? false,
		catalogSortingMethod = catalogSortingMethod ?? ThreadSortingMethod.unsorted,
		reverseCatalogSorting = reverseCatalogSorting ?? false,
		savedThreadsSortingMethod = savedThreadsSortingMethod ?? ThreadSortingMethod.savedTime,
		autoRotateInGallery = autoRotateInGallery ?? false,
		useTouchLayout = useTouchLayout ?? (Platform.isAndroid || Platform.isIOS),
		userId = userId ?? (const Uuid()).v4(),
		contentSettings = contentSettings ?? ContentSettings(),
		filterConfiguration = filterConfiguration ?? '',
		boardSwitcherHasKeyboardFocus = boardSwitcherHasKeyboardFocus ?? true,
		lightTheme = lightTheme ?? SavedTheme(
			primaryColor: defaultLightTheme.primaryColor,
			secondaryColor: defaultLightTheme.secondaryColor,
			barColor: defaultLightTheme.barColor,
			backgroundColor: defaultLightTheme.backgroundColor
		),
		darkTheme = darkTheme ?? SavedTheme(
			primaryColor: defaultDarkTheme.primaryColor,
			secondaryColor: defaultDarkTheme.secondaryColor,
			barColor: defaultDarkTheme.barColor,
			backgroundColor: defaultDarkTheme.backgroundColor
		),
		recentSearchesBySite = recentSearchesBySite ?? {},
		browserStateBySite = browserStateBySite ?? {},
		savedPostsBySite = savedPostsBySite ?? {},
		savedAttachmentsBySite = savedAttachmentsBySite ?? {},
		boardsBySite = boardsBySite ?? {},
		twoPaneBreakpoint = twoPaneBreakpoint ?? 700,
		twoPaneSplit = twoPaneSplit ?? twoPaneSplitDenominator ~/ 4,
		useCatalogGrid = useCatalogGrid ?? false,
		catalogGridWidth = catalogGridWidth ?? 200,
		catalogGridHeight = catalogGridHeight ?? 300,
		showImageCountInCatalog = showImageCountInCatalog ?? true,
		showClockIconInCatalog = showClockIconInCatalog ?? true,
		embedRegexes = embedRegexes ?? [],
		supportMouse = supportMouse ?? TristateSystemSetting.system,
		showNameInCatalog = showNameInCatalog ?? true,
		interfaceScale = interfaceScale ?? 1.0,
		showAnimations = showAnimations ?? true,
		imagesOnRight = imagesOnRight ?? false;
}

class EffectiveSettings extends ChangeNotifier {
	late final SavedSettings _settings;
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
		if (_settings.theme == TristateSystemSetting.system) {
			notifyListeners();
		}
	}
	AutoloadAttachmentsSetting get autoloadAttachmentsSetting => _settings.autoloadAttachments;
	set autoloadAttachmentsSetting(AutoloadAttachmentsSetting setting) {
		_settings.autoloadAttachments = setting;
		_settings.save();
		notifyListeners();
	}
	bool get autoloadAttachments {
		return (_settings.autoloadAttachments == AutoloadAttachmentsSetting.always) ||
			((_settings.autoloadAttachments == AutoloadAttachmentsSetting.wifi) && (connectivity == ConnectivityResult.wifi));
	}
	TristateSystemSetting get themeSetting => _settings.theme;
	set themeSetting(TristateSystemSetting setting) {
		_settings.theme = setting;
		_settings.save();
		notifyListeners();
	}
	Brightness get whichTheme {
		if (_settings.theme == TristateSystemSetting.b) {
			return Brightness.dark;
		}
		else if (_settings.theme == TristateSystemSetting.a) {
			return Brightness.light;
		}
		return _systemBrightness ?? SchedulerBinding.instance.window.platformBrightness;
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

	ContentSettings get contentSettings => _settings.contentSettings;
	String get contentSettingsUrl => '$contentSettingsApiRoot/user/${_settings.userId}/edit';

	void updateContentSettings() async {
		try {
			final response = await Dio().get('$contentSettingsApiRoot/user/${_settings.userId}');
			_settings.contentSettings.images = response.data['images'];
			_settings.contentSettings.nsfwBoards = response.data['nsfwBoards'];
			_settings.contentSettings.nsfwImages = response.data['nsfwImages'];
			_settings.contentSettings.nsfwText = response.data['nsfwText'];
			_settings.contentSettings.site = response.data['site'] ?? defaultSite;
			await _settings.save();
			notifyListeners();
		}
		catch (e) {
			print('Error updating content settings: $e');
		}
	}

	late List<RegExp> embedRegexes;
	void updateEmbedRegexes() async {
		try {
			final response = await Dio().get('https://noembed.com/providers');
			final data = jsonDecode(response.data);
			_settings.embedRegexes = List<String>.from(data.expand((x) => (x['patterns'] as List<dynamic>).cast<String>()));
			embedRegexes = _settings.embedRegexes.map((x) => RegExp(x)).toList();
			notifyListeners();
		}
		catch (e) {
			print('Error updating embed regexes: $e');
		}
	}

	bool showBoard(BuildContext context, String board) {
		return context.read<Persistence>().getBoard(board).isWorksafe || _settings.contentSettings.nsfwBoards;
	}

	bool showImages(BuildContext context, String board) {
		return _settings.contentSettings.images && ((context.read<Persistence>().boards[board]?.isWorksafe ?? false) || _settings.contentSettings.nsfwImages);
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

	String? filterError;
	Filter? _filter;
	Filter get filter => _filter ?? const DummyFilter();
	void _tryToSetupFilter() {
		try {
			_filter = makeFilter(filterConfiguration);
			filterError = null;
		}
		catch (e) {
			filterError = e.toString();
		}
	}
	String get filterConfiguration => _settings.filterConfiguration;
	set filterConfiguration(String setting) {
		_settings.filterConfiguration = setting;
		_settings.save();
		_tryToSetupFilter();
		notifyListeners();
	}

	bool get boardSwitcherHasKeyboardFocus => _settings.boardSwitcherHasKeyboardFocus;
	set boardSwitcherHasKeyboardFocus(bool setting) {
		_settings.boardSwitcherHasKeyboardFocus = setting;
		_settings.save();
		// no need
		// notifyListeners();
	}
	
	SavedTheme get lightTheme => _settings.lightTheme;
	SavedTheme get darkTheme => _settings.darkTheme;
	SavedTheme get theme => whichTheme == Brightness.dark ? darkTheme : lightTheme;
	void handleThemesAltered() {
		_settings.save();
		notifyListeners();
	}

	double get twoPaneBreakpoint => _settings.twoPaneBreakpoint;
	set twoPaneBreakpoint(double setting) {
		_settings.twoPaneBreakpoint = setting;
		_settings.save();
		notifyListeners();
	}

	int get twoPaneSplit => _settings.twoPaneSplit;
	set twoPaneSplit(int setting) {
		_settings.twoPaneSplit = setting;
		_settings.save();
		notifyListeners();
	}

	bool get useCatalogGrid => _settings.useCatalogGrid;
	set useCatalogGrid(bool setting) {
		_settings.useCatalogGrid = setting;
		_settings.save();
		notifyListeners();
	}

	double get catalogGridWidth => _settings.catalogGridWidth;
	set catalogGridWidth(double setting) {
		_settings.catalogGridWidth = setting;
		_settings.save();
		notifyListeners();
	}

	double get catalogGridHeight => _settings.catalogGridHeight;
	set catalogGridHeight(double setting) {
		_settings.catalogGridHeight = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showImageCountInCatalog => _settings.showImageCountInCatalog;
	set showImageCountInCatalog(bool setting) {
		_settings.showImageCountInCatalog = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showClockIconInCatalog => _settings.showClockIconInCatalog;
	set showClockIconInCatalog(bool setting) {
		_settings.showClockIconInCatalog = setting;
		_settings.save();
		notifyListeners();
	}

	bool _systemMousePresent = false;
	set systemMousePresent(bool setting) {
		_systemMousePresent = setting;
		if (_settings.supportMouse == TristateSystemSetting.system) {
			supportMouse.value = setting;
		}
	}
	final supportMouse = ValueNotifier<bool>(false);

	TristateSystemSetting get supportMouseSetting => _settings.supportMouse;
	set supportMouseSetting(TristateSystemSetting setting) {
		_settings.supportMouse = setting;
		_settings.save();
		switch (supportMouseSetting) {
			case TristateSystemSetting.a:
				supportMouse.value = false;
				break;
			case TristateSystemSetting.system:
				supportMouse.value = _systemMousePresent;
				break;
			case TristateSystemSetting.b:
				supportMouse.value = true;
				break;
		}
		notifyListeners();
	}

	double get interfaceScale => _settings.interfaceScale;
	set interfaceScale(double setting) {
		_settings.interfaceScale = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showNameInCatalog => _settings.showNameInCatalog;
	set showNameInCatalog(bool setting) {
		_settings.showNameInCatalog = setting;
		_settings.save();
		notifyListeners();
	}
	
	bool get showAnimations => _settings.showAnimations;
	set showAnimations(bool setting) {
		_settings.showAnimations = setting;
		_settings.save();
		notifyListeners();
	}

	bool get imagesOnRight => _settings.imagesOnRight;
	set imagesOnRight(bool setting) {
		_settings.imagesOnRight = setting;
		_settings.save();
		notifyListeners();
	}

	EffectiveSettings(SavedSettings settings) {
		_settings = settings;
		if (_settings.supportMouse == TristateSystemSetting.b) {
			supportMouse.value = true;
		}
		_tryToSetupFilter();
		embedRegexes = settings.embedRegexes.map((x) => RegExp(x)).toList();
		updateEmbedRegexes();
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

const _mouseStateChangeTimeout = Duration(seconds: 3);

class _SettingsSystemListenerState extends State<SettingsSystemListener> with WidgetsBindingObserver {
	late StreamSubscription connectivitySubscription;
	Timer? _mouseExitTimer;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addObserver(this);
		_checkConnectivity();
		connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
			context.read<EffectiveSettings>().connectivity = result;
		});
		if (isDesktop()) {
			Future.delayed(const Duration(milliseconds: 10), () {
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
		WidgetsBinding.instance.removeObserver(this);
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
		context.read<EffectiveSettings>().systemBrightness = SchedulerBinding.instance.window.platformBrightness;
	}

	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onEnter: (event) {
				_mouseExitTimer?.cancel();
				context.read<EffectiveSettings>().systemMousePresent = true;
			},
			onExit: (event) {
				_mouseExitTimer = Timer(_mouseStateChangeTimeout, () => context.read<EffectiveSettings>().systemMousePresent = false);
			},
			opaque: false,
			child: widget.child
		);
	}
}