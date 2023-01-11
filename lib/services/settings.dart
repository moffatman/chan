import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chan/models/board.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:linkify/linkify.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
part 'settings.g.dart';

class ChanceLinkifier extends Linkifier {
  const ChanceLinkifier();

  @override
  List<LinkifyElement> parse(elements, options) {
    final list = <LinkifyElement>[];

    for (final element in elements) {
      if (element is TextElement) {
        var match = RegExp(r'^(.*?)((?:chance:\/\/|www\.)[^\s/$.?#].[^\s]*)').firstMatch(element.text);

        if (match == null) {
          list.add(element);
        } else {
          final text = element.text.replaceFirst(match.group(0)!, '');

          if (match.group(1)?.isNotEmpty == true) {
            list.add(TextElement(match.group(1)!));
          }

          if (match.group(2)?.isNotEmpty == true) {
            var originalUrl = match.group(2)!;
            String? end;

            if ((options.excludeLastPeriod) &&
                originalUrl[originalUrl.length - 1] == ".") {
              end = ".";
              originalUrl = originalUrl.substring(0, originalUrl.length - 1);
            }

            list.add(UrlElement(originalUrl));

            if (end != null) {
              list.add(TextElement(end));
            }
          }

          if (text.isNotEmpty) {
            list.addAll(parse([TextElement(text)], options));
          }
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

const contentSettingsApiRoot = 'https://api.chance.surf/preferences';
final _punctuationRegex = RegExp('(\\W+|s\\W)');
final _badWords = Set.from(ProfanityFilter().wordsToFilterOutList);
const defaultSite = {
	'type': 'lainchan',
	'name': 'testchan',
	'baseUrl': 'boards.chance.surf',
	'maxUploadSizeBytes': 8000000
};
const defaultSites = {
	'testchan': defaultSite
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
	savedTime,
	@HiveField(5)
	postsPerMinute,
	@HiveField(6)
	lastReplyTime,
	@HiveField(7)
	imageCount,
	@HiveField(8)
	lastReplyByYouTime
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
	@HiveField(5)
	Map<String, dynamic> sites;

	ContentSettings({
		this.images = false,
		this.nsfwBoards = false,
		this.nsfwImages = false,
		this.nsfwText = false,
		Map<String, dynamic>? sites,
	}) : sites = sites ?? defaultSites;
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
	@HiveField(5)
	SavedTheme? copiedFrom;

	SavedTheme({
		required this.backgroundColor,
		required this.barColor,
		required this.primaryColor,
		required this.secondaryColor,
		this.quoteColor = _defaultQuoteColor,
		this.copiedFrom
	});

	factory SavedTheme.decode(String data) {
		final b = base64Url.decode(data);
		if (b.length < 15) {
			throw Exception('Data has been truncated');
		}
		final theme = SavedTheme(
			backgroundColor: Color.fromARGB(255, b[0], b[1], b[2]),
			barColor: Color.fromARGB(255, b[3], b[4], b[5]),
			primaryColor: Color.fromARGB(255, b[6], b[7], b[8]),
			secondaryColor: Color.fromARGB(255, b[9], b[10], b[11]),
			quoteColor: Color.fromARGB(255, b[12], b[13], b[14])
		);
		return SavedTheme.copyFrom(theme);
	}

	String encode() {
		return base64Url.encode([
			backgroundColor.red,
			backgroundColor.green,
			backgroundColor.blue,
			barColor.red,
			barColor.green,
			barColor.blue,
			primaryColor.red,
			primaryColor.green,
			primaryColor.blue,
			secondaryColor.red,
			secondaryColor.green,
			secondaryColor.blue,
			quoteColor.red,
			quoteColor.green,
			quoteColor.blue
		]);
	}

	SavedTheme.copyFrom(SavedTheme original) :
		backgroundColor = original.backgroundColor,
		barColor = original.barColor,
		primaryColor = original.primaryColor,
		secondaryColor = original.secondaryColor,
		quoteColor = original.quoteColor,
		copiedFrom = original;
	
	@override
	bool operator ==(dynamic other) => (other is SavedTheme) &&
		backgroundColor == other.backgroundColor &&
		barColor == other.barColor &&
		primaryColor == other.primaryColor &&
		secondaryColor == other.secondaryColor &&
		quoteColor == other.quoteColor;// &&
		//copiedFrom == other.copiedFrom;

	@override
	int get hashCode => Object.hash(backgroundColor, barColor, primaryColor, secondaryColor, quoteColor, copiedFrom);

	Color primaryColorWithBrightness(double factor) {
		return Color.fromRGBO(
			((primaryColor.red * factor) + (backgroundColor.red * (1 - factor))).round(),
			((primaryColor.green * factor) + (backgroundColor.green * (1 - factor))).round(),
			((primaryColor.blue * factor) + (backgroundColor.blue * (1 - factor))).round(),
			primaryColor.opacity
		);
	}
}

@HiveType(typeId: 30)
enum PostDisplayField {
	@HiveField(0)
	name,
	@HiveField(1)
	posterId,
	@HiveField(2)
	attachmentInfo,
	@HiveField(3)
	pass,
	@HiveField(4)
	flag,
	@HiveField(5)
	countryName,
	@HiveField(6)
	absoluteTime,
	@HiveField(7)
	relativeTime,
	@HiveField(8)
	postId,
}

extension PostDisplayFieldName on PostDisplayField {
	String get displayName {
		switch (this) {
			case PostDisplayField.name:
				return 'Name';
			case PostDisplayField.posterId:
				return 'Poster ID';
			case PostDisplayField.attachmentInfo:
				return 'File Details';
			case PostDisplayField.pass:
				return 'Pass';
			case PostDisplayField.flag:
				return 'Flag';
			case PostDisplayField.countryName:
				return 'Country Name';
			case PostDisplayField.absoluteTime:
				return 'Exact Time';
			case PostDisplayField.relativeTime:
				return 'Relative Time';
			case PostDisplayField.postId:
				return 'Post ID';
		}
	}
}

@HiveType(typeId: 31)
enum SettingsQuickAction {
	@HiveField(0)
	toggleTheme,
	@HiveField(1)
	toggleBlurredThumbnails,
	@HiveField(2)
	toggleCatalogLayout,
	@HiveField(3)
	toggleInterfaceStyle,
	@HiveField(4)
	toggleListPositionIndicatorLocation
}

@HiveType(typeId: 32)
enum WebmTranscodingSetting {
	@HiveField(0)
	never,
	@HiveField(1)
	vp9,
	@HiveField(2)
	always
}

extension SettingsQuickActionName on SettingsQuickAction? {
	String get name {
		switch (this) {
			case SettingsQuickAction.toggleTheme:
				return 'Toggle theme';
			case SettingsQuickAction.toggleBlurredThumbnails:
				return 'Toggle blurred thumbnails';
			case SettingsQuickAction.toggleCatalogLayout:
				return 'Toggle catalog layout';
			case SettingsQuickAction.toggleInterfaceStyle:
				return 'Toggle interface style';
			case SettingsQuickAction.toggleListPositionIndicatorLocation:
				return 'Toggle list position indicator location';
			case null:
				return 'None';
		}
	}
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
	ThreadSortingMethod deprecatedCatalogSortingMethod;
	@HiveField(4)
	bool deprecatedReverseCatalogSorting;
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
	SavedTheme deprecatedLightTheme;
	@HiveField(16)
	SavedTheme deprecatedDarkTheme;
	@HiveField(17)
	Map<String, PersistentRecentSearches> deprecatedRecentSearchesBySite;
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
	@HiveField(35)
	String? androidGallerySavePath;
	@HiveField(36)
	double replyBoxHeightOffset;
	@HiveField(37)
	bool blurThumbnails;
	@HiveField(38)
	bool showTimeInCatalogHeader;
	@HiveField(39)
	bool showTimeInCatalogStats;
	@HiveField(40)
	bool showIdInCatalogHeader;
	@HiveField(41)
	bool showFlagInCatalogHeader;
	@HiveField(42)
	bool onlyShowFavouriteBoardsInSwitcher;
	@HiveField(43)
	bool useBoardSwitcherList;
	@HiveField(44)
	bool? contributeCaptchas;
	@HiveField(45)
	bool showReplyCountsInGallery;
	@HiveField(46)
	bool useNewCaptchaForm;
	@HiveField(47)
	bool? autoLoginOnMobileNetwork;
	@HiveField(48)
	bool showScrollbars;
	@HiveField(49)
	bool randomizeFilenames;
	@HiveField(50)
	bool showNameOnPosts;
	@HiveField(51)
	bool showTripOnPosts;
	@HiveField(52)
	bool showAbsoluteTimeOnPosts;
	@HiveField(53)
	bool showRelativeTimeOnPosts;
	@HiveField(54)
	bool showCountryNameOnPosts;
	@HiveField(55)
	bool showPassOnPosts;
	@HiveField(56)
	bool showFilenameOnPosts;
	@HiveField(57)
	bool showFilesizeOnPosts;
	@HiveField(58)
	bool showFileDimensionsOnPosts;
	@HiveField(59)
	bool showFlagOnPosts;
	@HiveField(60)
	double thumbnailSize;
	@HiveField(61)
	bool muteAudio;
	@HiveField(62)
	bool? usePushNotifications;
	@HiveField(63)
	bool useEmbeds;
	@HiveField(64)
	bool? useInternalBrowser;
	@HiveField(65)
	int automaticCacheClearDays;
	@HiveField(66)
	bool alwaysAutoloadTappedAttachment;
	@HiveField(67)
	List<PostDisplayField> postDisplayFieldOrder;
	@HiveField(68)
	int? maximumImageUploadDimension;
	@HiveField(69)
	List<PersistentBrowserTab> tabs;
	@HiveField(70)
	int currentTabIndex;
	@HiveField(71)
	PersistentRecentSearches recentSearches;
	@HiveField(72)
	bool hideDefaultNamesOnPosts;
	@HiveField(73)
	bool showThumbnailsInGallery;
	@HiveField(74)
	ThreadSortingMethod watchedThreadsSortingMethod;
	@HiveField(75)
	bool closeTabSwitcherAfterUse;
	@HiveField(76)
	double textScale;
	@HiveField(77)
	int? catalogGridModeTextLinesLimit;
	@HiveField(78)
	bool catalogGridModeAttachmentInBackground;
	@HiveField(79)
	double maxCatalogRowHeight;
	@HiveField(80)
	Map<String, SavedTheme> themes;
	@HiveField(81)
	String lightThemeKey;
	@HiveField(83)
	String darkThemeKey;
	@HiveField(84)
	List<String> hostsToOpenExternally;
	@HiveField(85)
	bool useFullWidthForCatalogCounters;
	@HiveField(86)
	bool alwaysStartVideosMuted;
	@HiveField(87)
	bool allowSwipingInGallery;
	@HiveField(88)
	SettingsQuickAction? settingsQuickAction;
	@HiveField(89)
	bool useHapticFeedback;
	@HiveField(90)
	bool promptedAboutCrashlytics;
	@HiveField(91)
	bool showCountryNameInCatalogHeader;
	@HiveField(92)
	WebmTranscodingSetting webmTranscoding;
	@HiveField(93)
	bool showListPositionIndicatorsOnLeft;
	@HiveField(94)
	List<String> appliedMigrations;
	@HiveField(95)
	bool? useStatusBarWorkaround;
	@HiveField(96)
	bool enableIMEPersonalizedLearning;
	@HiveField(97)
	CatalogVariant catalogVariant;
	@HiveField(98)
	CatalogVariant redditCatalogVariant;
	@HiveField(99)
	bool dimReadThreads;
	@HiveField(100)
	CatalogVariant hackerNewsCatalogVariant;
	@HiveField(101)
	bool hideDefaultNamesInCatalog;

	SavedSettings({
		AutoloadAttachmentsSetting? autoloadAttachments,
		TristateSystemSetting? theme = TristateSystemSetting.system,
		bool? hideOldStickiedThreads,
		ThreadSortingMethod? deprecatedCatalogSortingMethod,
		bool? deprecatedReverseCatalogSorting,
		ThreadSortingMethod? savedThreadsSortingMethod,
		bool? autoRotateInGallery,
		String? currentBoardName,
		bool? useTouchLayout,
		String? userId,
		ContentSettings? contentSettings,
		int? boardCatalogColumns,
		String? filterConfiguration,
		bool? boardSwitcherHasKeyboardFocus,
		SavedTheme? deprecatedLightTheme,
		SavedTheme? deprecatedDarkTheme,
		Map<String, PersistentRecentSearches>? deprecatedRecentSearchesBySite,
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
		this.androidGallerySavePath,
		double? replyBoxHeightOffset,
		bool? blurThumbnails,
		bool? showTimeInCatalogHeader,
		bool? showTimeInCatalogStats,
		bool? showIdInCatalogHeader,
		bool? showFlagInCatalogHeader,
		bool? onlyShowFavouriteBoardsInSwitcher,
		bool? useBoardSwitcherList,
		this.contributeCaptchas,
		bool? showReplyCountsInGallery,
		bool? useNewCaptchaForm,
		this.autoLoginOnMobileNetwork,
		bool? showScrollbars,
		bool? randomizeFilenames,
		bool? showNameOnPosts,
		bool? showTripOnPosts,
		bool? showAbsoluteTimeOnPosts,
		bool? showRelativeTimeOnPosts,
		bool? showCountryNameOnPosts,
		bool? showPassOnPosts,
		bool? showFilenameOnPosts,
		bool? showFilesizeOnPosts,
		bool? showFileDimensionsOnPosts,
		bool? showFlagOnPosts,
		double? thumbnailSize,
		bool? muteAudio,
		bool? notificationsMigrated,
		this.usePushNotifications,
		bool? useEmbeds,
		this.useInternalBrowser,
		int? automaticCacheClearDays,
		bool? alwaysAutoloadTappedAttachment,
		List<PostDisplayField>? postDisplayFieldOrder,
		this.maximumImageUploadDimension,
		List<PersistentBrowserTab>? tabs,
		int? currentTabIndex,
		PersistentRecentSearches? recentSearches,
		bool? hideDefaultNamesOnPosts,
		bool? showThumbnailsInGallery,
		ThreadSortingMethod? watchedThreadsSortingMethod,
		bool? closeTabSwitcherAfterUse,
		double? textScale,
		this.catalogGridModeTextLinesLimit,
		bool? catalogGridModeAttachmentInBackground,
		double? maxCatalogRowHeight,
		Map<String, SavedTheme>? themes,
		String? lightThemeKey,
		String? darkThemeKey,
		List<String>? hostsToOpenExternally,
		bool? useFullWidthForCatalogCounters,
		bool? alwaysStartVideosMuted,
		bool? allowSwipingInGallery,
		SettingsQuickAction? settingsQuickAction,
		bool? useHapticFeedback,
		bool? promptedAboutCrashlytics,
		bool? showCountryNameInCatalogHeader,
		WebmTranscodingSetting? webmTranscoding,
		bool? showListPositionIndicatorsOnLeft,
		List<String>? appliedMigrations,
		this.useStatusBarWorkaround,
		bool? enableIMEPersonalizedLearning,
		CatalogVariant? catalogVariant,
		CatalogVariant? redditCatalogVariant,
		bool? dimReadThreads,
		CatalogVariant? hackerNewsCatalogVariant,
		bool? hideDefaultNamesInCatalog,
	}): autoloadAttachments = autoloadAttachments ?? AutoloadAttachmentsSetting.wifi,
		theme = theme ?? TristateSystemSetting.system,
		hideOldStickiedThreads = hideOldStickiedThreads ?? false,
		deprecatedCatalogSortingMethod = deprecatedCatalogSortingMethod ?? ThreadSortingMethod.unsorted,
		deprecatedReverseCatalogSorting = deprecatedReverseCatalogSorting ?? false,
		savedThreadsSortingMethod = savedThreadsSortingMethod ?? ThreadSortingMethod.savedTime,
		autoRotateInGallery = autoRotateInGallery ?? false,
		useTouchLayout = useTouchLayout ?? (Platform.isAndroid || Platform.isIOS),
		userId = userId ?? (const Uuid()).v4(),
		contentSettings = contentSettings ?? ContentSettings(),
		filterConfiguration = filterConfiguration ?? '',
		boardSwitcherHasKeyboardFocus = boardSwitcherHasKeyboardFocus ?? true,
		deprecatedLightTheme = deprecatedLightTheme ?? SavedTheme(
			primaryColor: defaultLightTheme.primaryColor,
			secondaryColor: defaultLightTheme.secondaryColor,
			barColor: defaultLightTheme.barColor,
			backgroundColor: defaultLightTheme.backgroundColor
		),
		deprecatedDarkTheme = deprecatedDarkTheme ?? SavedTheme(
			primaryColor: defaultDarkTheme.primaryColor,
			secondaryColor: defaultDarkTheme.secondaryColor,
			barColor: defaultDarkTheme.barColor,
			backgroundColor: defaultDarkTheme.backgroundColor
		),
		deprecatedRecentSearchesBySite = deprecatedRecentSearchesBySite ?? {},
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
		imagesOnRight = imagesOnRight ?? false,
		replyBoxHeightOffset = replyBoxHeightOffset ?? 0.0,
		blurThumbnails = blurThumbnails ?? false,
		showTimeInCatalogHeader = showTimeInCatalogHeader ?? true,
		showTimeInCatalogStats = showTimeInCatalogStats ?? true,
		showIdInCatalogHeader = showIdInCatalogHeader ?? true,
		showFlagInCatalogHeader = showFlagInCatalogHeader ?? true,
		onlyShowFavouriteBoardsInSwitcher = onlyShowFavouriteBoardsInSwitcher ?? false,
		useBoardSwitcherList = useBoardSwitcherList ?? false,
		showReplyCountsInGallery = showReplyCountsInGallery ?? false,
		useNewCaptchaForm = useNewCaptchaForm ?? true,
		showScrollbars = showScrollbars ?? true,
		randomizeFilenames = randomizeFilenames ?? false,
		showNameOnPosts = showNameOnPosts ?? true,
		showTripOnPosts = showTripOnPosts ?? true,
		showAbsoluteTimeOnPosts = showAbsoluteTimeOnPosts ?? true,
		showRelativeTimeOnPosts = showRelativeTimeOnPosts ?? false,
		showCountryNameOnPosts = showCountryNameOnPosts ?? true,
		showPassOnPosts = showPassOnPosts ?? true,
		showFilenameOnPosts = showFilenameOnPosts ?? false,
		showFilesizeOnPosts = showFilesizeOnPosts ?? false,
		showFileDimensionsOnPosts = showFileDimensionsOnPosts ?? false,
		showFlagOnPosts = showFlagOnPosts ?? true,
		thumbnailSize = thumbnailSize ?? 75,
		muteAudio = muteAudio ?? false,
		useEmbeds = useEmbeds ?? true,
		automaticCacheClearDays = automaticCacheClearDays ?? 60,
		alwaysAutoloadTappedAttachment = alwaysAutoloadTappedAttachment ?? true,
		postDisplayFieldOrder = postDisplayFieldOrder ?? [
			PostDisplayField.name,
			PostDisplayField.posterId,
			PostDisplayField.attachmentInfo,
			PostDisplayField.pass,
			PostDisplayField.flag,
			PostDisplayField.countryName,
			PostDisplayField.absoluteTime,
			PostDisplayField.relativeTime,
			PostDisplayField.postId
		],
		tabs = tabs ?? [
			PersistentBrowserTab()
		],
		currentTabIndex = currentTabIndex ?? 0,
		recentSearches = recentSearches ?? PersistentRecentSearches(),
		hideDefaultNamesOnPosts = hideDefaultNamesOnPosts ?? false,
		showThumbnailsInGallery = showThumbnailsInGallery ?? true,
		watchedThreadsSortingMethod = watchedThreadsSortingMethod ?? ThreadSortingMethod.lastPostTime,
		closeTabSwitcherAfterUse = closeTabSwitcherAfterUse ?? false,
		textScale = textScale ?? 1.0,
		catalogGridModeAttachmentInBackground = catalogGridModeAttachmentInBackground ?? false,
		maxCatalogRowHeight = maxCatalogRowHeight ?? 125,
		themes = themes ?? {
			'Light': SavedTheme(
				primaryColor: (deprecatedLightTheme ?? defaultLightTheme).primaryColor,
				secondaryColor: (deprecatedLightTheme ?? defaultLightTheme).secondaryColor,
				barColor: (deprecatedLightTheme ?? defaultLightTheme).barColor,
				backgroundColor: (deprecatedLightTheme ?? defaultLightTheme).backgroundColor,
				copiedFrom: defaultLightTheme
			),
			'Dark': SavedTheme(
				primaryColor: (deprecatedDarkTheme ?? defaultDarkTheme).primaryColor,
				secondaryColor: (deprecatedDarkTheme ?? defaultDarkTheme).secondaryColor,
				barColor: (deprecatedDarkTheme ?? defaultDarkTheme).barColor,
				backgroundColor: (deprecatedDarkTheme ?? defaultDarkTheme).backgroundColor,
				copiedFrom: defaultDarkTheme
			)
		},
		lightThemeKey = lightThemeKey ?? 'Light',
		darkThemeKey = darkThemeKey ?? 'Dark',
		hostsToOpenExternally = hostsToOpenExternally ?? [
			'youtube.com',
			'youtu.be'
		],
		useFullWidthForCatalogCounters = useFullWidthForCatalogCounters ?? false,
		alwaysStartVideosMuted = alwaysStartVideosMuted ?? false,
		allowSwipingInGallery = allowSwipingInGallery ?? true,
		settingsQuickAction = settingsQuickAction ?? SettingsQuickAction.toggleTheme,
		useHapticFeedback = useHapticFeedback ?? true,
		promptedAboutCrashlytics = promptedAboutCrashlytics ?? false,
		showCountryNameInCatalogHeader = showCountryNameInCatalogHeader ?? (showFlagInCatalogHeader ?? true),
		webmTranscoding = webmTranscoding ?? ((Platform.isIOS || Platform.isMacOS) ? WebmTranscodingSetting.always : WebmTranscodingSetting.never),
		showListPositionIndicatorsOnLeft = showListPositionIndicatorsOnLeft ?? false,
		appliedMigrations = appliedMigrations ?? [],
		enableIMEPersonalizedLearning = enableIMEPersonalizedLearning ?? true,
		catalogVariant = catalogVariant ?? CatalogVariant.unsorted,
		redditCatalogVariant = redditCatalogVariant ?? CatalogVariant.redditHot,
		dimReadThreads = dimReadThreads ?? true,
		hackerNewsCatalogVariant = hackerNewsCatalogVariant ?? CatalogVariant.hackerNewsTop,
		hideDefaultNamesInCatalog = hideDefaultNamesInCatalog ?? false {
			if (!this.appliedMigrations.contains('filters')) {
				this.filterConfiguration = this.filterConfiguration.replaceAllMapped(RegExp(r'^(\/.*\/.*)(;save)(.*)$', multiLine: true), (m) {
					return '${m.group(1)};save;highlight${m.group(3)}';
				}).replaceAllMapped(RegExp(r'^(\/.*\/.*)(;top)(.*)$', multiLine: true), (m) {
					return '${m.group(1)};top;highlight${m.group(3)}';
				});
				this.appliedMigrations.add('filters');
			}
			if (!this.appliedMigrations.contains('catalogVariant')) {
				this.catalogVariant = CatalogVariantMetadata.migrate(this.deprecatedCatalogSortingMethod, this.deprecatedReverseCatalogSorting);
				for (final browserState in this.browserStateBySite.values) {
					for (final board in browserState.deprecatedBoardSortingMethods.keys) {
						browserState.catalogVariants[board] = CatalogVariantMetadata.migrate(browserState.deprecatedBoardSortingMethods[board], browserState.deprecatedBoardReverseSortings[board]);
					}
				}
				this.appliedMigrations.add('catalogVariant');
			}
		}

	@override
	Future<void> save() async {
		await runWhenIdle(const Duration(milliseconds: 500), super.save);
	}
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

	Future<void> updateContentSettings() async {
		try {
			String platform = Platform.operatingSystem;
			if (Platform.isIOS && isDevelopmentBuild) {
				platform += '-dev';
			}
			final response = await Dio().get('$contentSettingsApiRoot/user2/${_settings.userId}', queryParameters: {
				'platform': platform
			});
			_settings.contentSettings.images = response.data['images'];
			_settings.contentSettings.nsfwBoards = response.data['nsfwBoards'];
			_settings.contentSettings.nsfwImages = response.data['nsfwImages'];
			_settings.contentSettings.nsfwText = response.data['nsfwText'];
			_settings.contentSettings.sites = response.data['sites'];
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

	bool showBoard(ImageboardBoard board) {
		return board.isWorksafe || _settings.contentSettings.nsfwBoards;
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
	final filterListenable = EasyListenable();
	FilterCache _filter = FilterCache(const DummyFilter());
	Filter get filter => _filter;
	void _tryToSetupFilter() {
		try {
			final newFilter = makeFilter(filterConfiguration);
			if (newFilter != _filter.wrappedFilter) {
				_filter = FilterCache(newFilter);
			}
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
		filterListenable.didUpdate();
		notifyListeners();
	}

	bool get boardSwitcherHasKeyboardFocus => _settings.boardSwitcherHasKeyboardFocus;
	set boardSwitcherHasKeyboardFocus(bool setting) {
		_settings.boardSwitcherHasKeyboardFocus = setting;
		_settings.save();
		// no need
		// notifyListeners();
	}
	
	SavedTheme get lightTheme => _settings.themes[_settings.lightThemeKey] ?? defaultLightTheme;
	SavedTheme get darkTheme => _settings.themes[_settings.darkThemeKey] ?? defaultDarkTheme;
	SavedTheme get theme => whichTheme == Brightness.dark ? darkTheme : lightTheme;
	String addTheme(String name, SavedTheme theme) {
		String proposedName = name;
		int copyNumber = 0;
		while (themes.containsKey(proposedName)) {
			copyNumber++;
			proposedName = '$name ($copyNumber)';
		}
		themes[proposedName] = SavedTheme.copyFrom(theme);
		return proposedName;
	}
	void handleThemesAltered() {
		_settings.save();
		notifyListeners();
	}

	CupertinoThemeData makeLightTheme(BuildContext context) {
		return CupertinoThemeData(
			brightness: Brightness.light,
			scaffoldBackgroundColor: lightTheme.backgroundColor,
			barBackgroundColor: lightTheme.barColor,
			primaryColor: lightTheme.primaryColor,
			primaryContrastingColor: lightTheme.backgroundColor,
			textTheme: CupertinoTextThemeData(
				textStyle: TextStyle(
					fontFamily: '.SF Pro Text',
					fontSize: 17.0,
					letterSpacing: -0.41,
					fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.w500 : null,
					color: lightTheme.primaryColor
				),
				actionTextStyle: TextStyle(color: lightTheme.secondaryColor),
				navActionTextStyle: TextStyle(color: lightTheme.primaryColor),
				navTitleTextStyle: TextStyle(
  				inherit: false,
					fontFamily: '.SF Pro Text',
					fontSize: 17.0,
					letterSpacing: -0.41,
					fontWeight: FontWeight.w600,
					color: lightTheme.primaryColor,
					decoration: TextDecoration.none,
				),
				navLargeTitleTextStyle: TextStyle(
					inherit: false,
					fontFamily: '.SF Pro Display',
					fontSize: 34.0,
					fontWeight: FontWeight.w700,
					letterSpacing: 0.41,
					color: lightTheme.primaryColor,
				)
			)
		);
	}
	CupertinoThemeData makeDarkTheme(BuildContext context) {
		return CupertinoThemeData(
			brightness: Brightness.dark,
			scaffoldBackgroundColor: darkTheme.backgroundColor,
			barBackgroundColor: darkTheme.barColor,
			primaryColor: darkTheme.primaryColor,
			primaryContrastingColor: darkTheme.backgroundColor,
			textTheme: CupertinoTextThemeData(
				textStyle: TextStyle(
					fontFamily: '.SF Pro Text',
					fontSize: 17.0,
					letterSpacing: -0.41,
					fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.w500 : null,
					color: darkTheme.primaryColor
				),
				actionTextStyle: TextStyle(color: darkTheme.secondaryColor),
				navActionTextStyle: TextStyle(color: darkTheme.primaryColor),
				navTitleTextStyle: TextStyle(
  				inherit: false,
					fontFamily: '.SF Pro Text',
					fontSize: 17.0,
					letterSpacing: -0.41,
					fontWeight: FontWeight.w600,
					color: darkTheme.primaryColor,
					decoration: TextDecoration.none,
				),
				navLargeTitleTextStyle: TextStyle(
					inherit: false,
					fontFamily: '.SF Pro Display',
					fontSize: 34.0,
					fontWeight: FontWeight.w700,
					letterSpacing: 0.41,
					color: darkTheme.primaryColor,
				)
			)
		);
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

	String? get androidGallerySavePath => _settings.androidGallerySavePath;
	set androidGallerySavePath(String? setting) {
		_settings.androidGallerySavePath = setting;
		_settings.save();
		notifyListeners();
	}

	double get replyBoxHeightOffset => _settings.replyBoxHeightOffset;
	set replyBoxHeightOffset(double setting) {
		_settings.replyBoxHeightOffset = setting;
	}
	void finalizeReplyBoxHeightOffset() {
		_settings.save();
		notifyListeners();
	}

	bool get blurThumbnails => _settings.blurThumbnails;
	set blurThumbnails(bool setting) {
		_settings.blurThumbnails = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showTimeInCatalogHeader => _settings.showTimeInCatalogHeader;
	set showTimeInCatalogHeader(bool setting) {
		_settings.showTimeInCatalogHeader = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showTimeInCatalogStats => _settings.showTimeInCatalogStats;
	set showTimeInCatalogStats(bool setting) {
		_settings.showTimeInCatalogStats = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showIdInCatalogHeader => _settings.showIdInCatalogHeader;
	set showIdInCatalogHeader(bool setting) {
		_settings.showIdInCatalogHeader = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showFlagInCatalogHeader => _settings.showFlagInCatalogHeader;
	set showFlagInCatalogHeader(bool setting) {
		_settings.showFlagInCatalogHeader = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showCountryNameInCatalogHeader => _settings.showCountryNameInCatalogHeader;
	set showCountryNameInCatalogHeader(bool setting) {
		_settings.showCountryNameInCatalogHeader = setting;
		_settings.save();
		notifyListeners();
	}

	bool get onlyShowFavouriteBoardsInSwitcher => _settings.onlyShowFavouriteBoardsInSwitcher;
	set onlyShowFavouriteBoardsInSwitcher(bool setting) {
		_settings.onlyShowFavouriteBoardsInSwitcher = setting;
		_settings.save();
		notifyListeners();
	}

	bool get useBoardSwitcherList => _settings.useBoardSwitcherList;
	set useBoardSwitcherList(bool setting) {
		_settings.useBoardSwitcherList = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get contributeCaptchas => _settings.contributeCaptchas;
	set contributeCaptchas(bool? setting) {
		_settings.contributeCaptchas = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showReplyCountsInGallery => _settings.showReplyCountsInGallery;
	set showReplyCountsInGallery(bool setting) {
		_settings.showReplyCountsInGallery = setting;
		_settings.save();
		notifyListeners();
	}

	bool get useNewCaptchaForm => _settings.useNewCaptchaForm;
	set useNewCaptchaForm(bool setting) {
		_settings.useNewCaptchaForm = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get autoLoginOnMobileNetwork => _settings.autoLoginOnMobileNetwork;
	set autoLoginOnMobileNetwork(bool? setting) {
		_settings.autoLoginOnMobileNetwork = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showScrollbars => _settings.showScrollbars;
	set showScrollbars(bool setting) {
		_settings.showScrollbars = setting;
		_settings.save();
		notifyListeners();
	}

	bool get randomizeFilenames => _settings.randomizeFilenames;
	set randomizeFilenames(bool setting) {
		_settings.randomizeFilenames = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showNameOnPosts => _settings.showNameOnPosts;
	set showNameOnPosts(bool setting) {
		_settings.showNameOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showTripOnPosts => _settings.showTripOnPosts;
	set showTripOnPosts(bool setting) {
		_settings.showTripOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showAbsoluteTimeOnPosts => _settings.showAbsoluteTimeOnPosts;
	set showAbsoluteTimeOnPosts(bool setting) {
		_settings.showAbsoluteTimeOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showRelativeTimeOnPosts => _settings.showRelativeTimeOnPosts;
	set showRelativeTimeOnPosts(bool setting) {
		_settings.showRelativeTimeOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showCountryNameOnPosts => _settings.showCountryNameOnPosts;
	set showCountryNameOnPosts(bool setting) {
		_settings.showCountryNameOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showPassOnPosts => _settings.showPassOnPosts;
	set showPassOnPosts(bool setting) {
		_settings.showPassOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showFilenameOnPosts => _settings.showFilenameOnPosts;
	set showFilenameOnPosts(bool setting) {
		_settings.showFilenameOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showFilesizeOnPosts => _settings.showFilesizeOnPosts;
	set showFilesizeOnPosts(bool setting) {
		_settings.showFilesizeOnPosts = setting;
		_settings.save();
	notifyListeners();
	}

	bool get showFileDimensionsOnPosts => _settings.showFileDimensionsOnPosts;
	set showFileDimensionsOnPosts(bool setting) {
		_settings.showFileDimensionsOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showFlagOnPosts => _settings.showFlagOnPosts;
	set showFlagOnPosts(bool setting) {
		_settings.showFlagOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	double get thumbnailSize => _settings.thumbnailSize;
	set thumbnailSize(double setting) {
		_settings.thumbnailSize = setting;
		_settings.save();
		notifyListeners();
	}

	final muteAudio = ValueNotifier<bool>(true);
	void setMuteAudio(bool setting) {
		_settings.muteAudio = setting;
		_settings.save();
		muteAudio.value = setting;
	}
	
	bool? get usePushNotifications => _settings.usePushNotifications;
	set usePushNotifications(bool? setting) {
		_settings.usePushNotifications = setting;
		_settings.save();
		notifyListeners();
		Notifications.didUpdateUsePushNotificationsSetting();
	}

	bool get useEmbeds => _settings.useEmbeds;
	set useEmbeds(bool setting) {
		_settings.useEmbeds = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get useInternalBrowser => _settings.useInternalBrowser;
	set useInternalBrowser(bool? setting) {
		_settings.useInternalBrowser = setting;
		_settings.save();
		notifyListeners();
	}

	int get automaticCacheClearDays => _settings.automaticCacheClearDays;
	set automaticCacheClearDays(int setting) {
		_settings.automaticCacheClearDays = setting;
		_settings.save();
		notifyListeners();
	}

	bool get alwaysAutoloadTappedAttachment => _settings.alwaysAutoloadTappedAttachment;
	set alwaysAutoloadTappedAttachment(bool setting) {
		_settings.alwaysAutoloadTappedAttachment = setting;
		_settings.save();
		notifyListeners();
	}

	List<PostDisplayField> get postDisplayFieldOrder => _settings.postDisplayFieldOrder;
	set postDisplayFieldOrder(List<PostDisplayField> setting) {
		_settings.postDisplayFieldOrder = setting;
		_settings.save();
		notifyListeners();
	}

	int? get maximumImageUploadDimension => _settings.maximumImageUploadDimension;
	set maximumImageUploadDimension(int? setting) {
		_settings.maximumImageUploadDimension = setting;
		_settings.save();
		notifyListeners();
	}

	bool get hideDefaultNamesOnPosts => _settings.hideDefaultNamesOnPosts;
	set hideDefaultNamesOnPosts(bool setting) {
		_settings.hideDefaultNamesOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showThumbnailsInGallery => _settings.showThumbnailsInGallery;
	set showThumbnailsInGallery(bool setting) {
		_settings.showThumbnailsInGallery = setting;
		_settings.save();
		notifyListeners();
	}

	ThreadSortingMethod get watchedThreadsSortingMethod => _settings.watchedThreadsSortingMethod;
	set watchedThreadsSortingMethod(ThreadSortingMethod setting) {
		_settings.watchedThreadsSortingMethod = setting;
		_settings.save();
		notifyListeners();
	}

	bool get closeTabSwitcherAfterUse => _settings.closeTabSwitcherAfterUse;
	set closeTabSwitcherAfterUse(bool setting) {
		_settings.closeTabSwitcherAfterUse = setting;
		_settings.save();
		notifyListeners();
	}

	double get textScale => _settings.textScale;
	set textScale(double setting) {
		_settings.textScale = setting;
		_settings.save();
		notifyListeners();
	}

	int? get catalogGridModeTextLinesLimit => _settings.catalogGridModeTextLinesLimit;
	set catalogGridModeTextLinesLimit(int? setting) {
		_settings.catalogGridModeTextLinesLimit = setting;
		_settings.save();
		notifyListeners();
	}

	bool get catalogGridModeAttachmentInBackground => _settings.catalogGridModeAttachmentInBackground;
	set catalogGridModeAttachmentInBackground(bool setting) {
		_settings.catalogGridModeAttachmentInBackground = setting;
		_settings.save();
		notifyListeners();
	}

	double get maxCatalogRowHeight => _settings.maxCatalogRowHeight;
	set maxCatalogRowHeight(double setting) {
		_settings.maxCatalogRowHeight = setting;
		_settings.save();
		notifyListeners();
	}

	String get lightThemeKey => _settings.lightThemeKey;
	set lightThemeKey(String setting) {
		_settings.lightThemeKey = setting;
		_settings.save();
	}
	String get darkThemeKey => _settings.darkThemeKey;
	set darkThemeKey(String setting) {
		_settings.darkThemeKey = setting;
		_settings.save();
	}
	Map<String, SavedTheme> get themes => _settings.themes;

	List<String> get hostsToOpenExternally => _settings.hostsToOpenExternally;
	void didUpdateHostsToOpenExternally() {
		_settings.save();
		notifyListeners();
	}

	bool get useFullWidthForCatalogCounters => _settings.useFullWidthForCatalogCounters;
	set useFullWidthForCatalogCounters(bool setting) {
		_settings.useFullWidthForCatalogCounters = setting;
		_settings.save();
		notifyListeners();
	}

	bool get alwaysStartVideosMuted => _settings.alwaysStartVideosMuted;
	set alwaysStartVideosMuted(bool setting) {
		_settings.alwaysStartVideosMuted = setting;
		_settings.save();
		notifyListeners();
	}

	bool get allowSwipingInGallery => _settings.allowSwipingInGallery;
	set allowSwipingInGallery(bool setting) {
		_settings.allowSwipingInGallery = setting;
		_settings.save();
		notifyListeners();
	}

	SettingsQuickAction? get settingsQuickAction => _settings.settingsQuickAction;
	set settingsQuickAction(SettingsQuickAction? setting) {
		_settings.settingsQuickAction = setting;
		_settings.save();
		notifyListeners();
	}

	bool get useHapticFeedback => _settings.useHapticFeedback;
	set useHapticFeedback(bool setting) {
		_settings.useHapticFeedback = setting;
		_settings.save();
		notifyListeners();
	}

	bool get promptedAboutCrashlytics => _settings.promptedAboutCrashlytics;
	set promptedAboutCrashlytics(bool setting) {
		_settings.promptedAboutCrashlytics = setting;
		_settings.save();
	}

	WebmTranscodingSetting get webmTranscoding => _settings.webmTranscoding;
	set webmTranscoding(WebmTranscodingSetting setting) {
		_settings.webmTranscoding = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showListPositionIndicatorsOnLeft => _settings.showListPositionIndicatorsOnLeft;
	set showListPositionIndicatorsOnLeft(bool setting) {
		_settings.showListPositionIndicatorsOnLeft = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get useStatusBarWorkaround => _settings.useStatusBarWorkaround;
	set useStatusBarWorkaround(bool? setting) {
		_settings.useStatusBarWorkaround = setting;
		_settings.save();
		notifyListeners();
	}

	bool get enableIMEPersonalizedLearning => _settings.enableIMEPersonalizedLearning;
	set enableIMEPersonalizedLearning(bool setting) {
		_settings.enableIMEPersonalizedLearning = setting;
		_settings.save();
		notifyListeners();
	}

	CatalogVariant get catalogVariant => _settings.catalogVariant;
	set catalogVariant(CatalogVariant setting) {
		_settings.catalogVariant = setting;
		_settings.save();
		notifyListeners();
	}

	CatalogVariant get redditCatalogVariant => _settings.redditCatalogVariant;
	set redditCatalogVariant(CatalogVariant setting) {
		_settings.redditCatalogVariant = setting;
		_settings.save();
		notifyListeners();
	}

	bool get dimReadThreads => _settings.dimReadThreads;
	set dimReadThreads(bool setting) {
		_settings.dimReadThreads = setting;
		_settings.save();
		notifyListeners();
	}

	CatalogVariant get hackerNewsCatalogVariant => _settings.hackerNewsCatalogVariant;
	set hackerNewsCatalogVariant(CatalogVariant setting) {
		_settings.hackerNewsCatalogVariant = setting;
		_settings.save();
		notifyListeners();
	}

	bool get hideDefaultNamesInCatalog => _settings.hideDefaultNamesInCatalog;
	set hideDefaultNamesInCatalog(bool setting) {
		_settings.hideDefaultNamesInCatalog = setting;
		_settings.save();
		notifyListeners();
	}

	final List<VoidCallback> _appResumeCallbacks = [];
	void addAppResumeCallback(VoidCallback task) {
		_appResumeCallbacks.add(task);
	}
	void _runAppResumeCallbacks() {
		for (final task in _appResumeCallbacks) {
			task();
		}
		_appResumeCallbacks.clear();
	}

	EffectiveSettings() {
		_settings = Persistence.settings;
		if (_settings.supportMouse == TristateSystemSetting.b) {
			supportMouse.value = true;
		}
		muteAudio.value = _settings.muteAudio;
		_tryToSetupFilter();
		embedRegexes = _settings.embedRegexes.map((x) => RegExp(x)).toList();
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
			if (context.read<EffectiveSettings>().connectivity == ConnectivityResult.none) {
				ImageboardRegistry.instance.retryFailedBoardSetup();
			}
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
			context.read<EffectiveSettings>()._runAppResumeCallbacks();
		}
	}

	@override
	void didChangePlatformBrightness() {
		context.read<EffectiveSettings>().systemBrightness = SchedulerBinding.instance.window.platformBrightness;
	}

	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onHover: (event) {
				if (event.kind != PointerDeviceKind.touch) {
					_mouseExitTimer?.cancel();
					context.read<EffectiveSettings>().systemMousePresent = true;
					context.read<EffectiveSettings>()._runAppResumeCallbacks();
				}
			},
			onExit: (event) {
				_mouseExitTimer = Timer(_mouseStateChangeTimeout, () => context.read<EffectiveSettings>().systemMousePresent = false);
			},
			opaque: false,
			child: widget.child
		);
	}
}