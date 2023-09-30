import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/apple.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/user_agents.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
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

final platformIsMaterial = !(Platform.isMacOS || Platform.isIOS);

const _defaultQuoteColor = Color.fromRGBO(120, 153, 34, 1);
const _defaultTitleColor = Color.fromRGBO(87, 153, 57, 1);

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
	@HiveField(6, defaultValue: false)
	bool locked;
	@HiveField(7, defaultValue: _defaultTitleColor)
	Color titleColor;
	@HiveField(8)
	Color textFieldColor;

	SavedTheme({
		required this.backgroundColor,
		required this.barColor,
		required this.primaryColor,
		required this.secondaryColor,
		this.quoteColor = _defaultQuoteColor,
		this.titleColor = _defaultTitleColor,
		this.locked = false,
		this.copiedFrom,
		Color? textFieldColor
	}) : textFieldColor = textFieldColor ?? (primaryColor.computeLuminance() > backgroundColor.computeLuminance() ? Colors.black : Colors.white);

	factory SavedTheme.decode(String data) {
		final b = base64Url.decode(data);
		if (b.length < 15) {
			throw Exception('Data has been truncated');
		}
		Color? titleColor;
		if (b.length >= 18) {
			titleColor = Color.fromARGB(255, b[15], b[16], b[17]);
		}
		Color? textFieldColor;
		if (b.length >= 21) {
			textFieldColor = Color.fromARGB(255, b[18], b[19], b[20]);
		}
		final theme = SavedTheme(
			backgroundColor: Color.fromARGB(255, b[0], b[1], b[2]),
			barColor: Color.fromARGB(255, b[3], b[4], b[5]),
			primaryColor: Color.fromARGB(255, b[6], b[7], b[8]),
			secondaryColor: Color.fromARGB(255, b[9], b[10], b[11]),
			quoteColor: Color.fromARGB(255, b[12], b[13], b[14]),
			titleColor: titleColor ?? _defaultTitleColor,
			textFieldColor: textFieldColor
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
			quoteColor.blue,
			titleColor.red,
			titleColor.green,
			titleColor.blue,
			textFieldColor.red,
			textFieldColor.green,
			textFieldColor.blue
		]);
	}

	SavedTheme.copyFrom(SavedTheme original) :
		backgroundColor = original.backgroundColor,
		barColor = original.barColor,
		primaryColor = original.primaryColor,
		secondaryColor = original.secondaryColor,
		quoteColor = original.quoteColor,
		copiedFrom = original,
		locked = false,
		titleColor = original.titleColor,
		textFieldColor = original.textFieldColor;
	
	@override
	bool operator ==(dynamic other) => (other is SavedTheme) &&
		backgroundColor == other.backgroundColor &&
		barColor == other.barColor &&
		primaryColor == other.primaryColor &&
		secondaryColor == other.secondaryColor &&
		quoteColor == other.quoteColor &&
		locked == other.locked &&
		titleColor == other.titleColor &&
		textFieldColor == other.textFieldColor;// &&
		//copiedFrom == other.copiedFrom;

	@override
	int get hashCode => Object.hash(backgroundColor, barColor, primaryColor, secondaryColor, quoteColor, copiedFrom, locked, titleColor, textFieldColor);

	Color primaryColorWithBrightness(double factor) {
		return Color.fromRGBO(
			((primaryColor.red * factor) + (backgroundColor.red * (1 - factor))).round(),
			((primaryColor.green * factor) + (backgroundColor.green * (1 - factor))).round(),
			((primaryColor.blue * factor) + (backgroundColor.blue * (1 - factor))).round(),
			primaryColor.opacity
		);
	}

	Brightness get brightness => primaryColor.computeLuminance() > backgroundColor.computeLuminance() ? Brightness.dark : Brightness.light;

	CupertinoThemeData get cupertinoThemeData => CupertinoThemeData(
		brightness: brightness,
		scaffoldBackgroundColor: backgroundColor,
		barBackgroundColor: barColor,
		primaryColor: primaryColor,
		primaryContrastingColor: backgroundColor,
		applyThemeToAll: true,
		textTheme: CupertinoTextThemeData(
			textStyle: Persistence.settings.textStyle.copyWith(
				fontSize: 17.0,
				letterSpacing: -0.41,
				fontWeight: PlatformDispatcher.instance.accessibilityFeatures.boldText ? FontWeight.w500 : null,
				color: primaryColor
			),
			actionTextStyle: Persistence.settings.textStyle.copyWith(
				color: secondaryColor
			),
			navActionTextStyle: Persistence.settings.textStyle.copyWith(
				color: primaryColor
			),
			navTitleTextStyle: Persistence.settings.textStyle.copyWith(
				inherit: false,
				fontSize: 17.0,
				letterSpacing: -0.41,
				fontWeight: FontWeight.w600,
				color: primaryColor,
				decoration: TextDecoration.none,
			),
			navLargeTitleTextStyle: Persistence.settings.textStyle.copyWith(
				inherit: false,
				fontSize: 34.0,
				fontWeight: FontWeight.w700,
				letterSpacing: 0.41,
				color: primaryColor,
			),
			tabLabelTextStyle: Persistence.settings.textStyle.copyWith(
				inherit: false,
				fontSize: 10.0,
				fontWeight: FontWeight.w500,
				letterSpacing: -0.24,
				color: CupertinoColors.inactiveGray,
			),
		)
	);

	ThemeData get materialThemeData {
		final colorScheme = ColorScheme.fromSwatch(
			brightness: brightness,
			primarySwatch: MaterialColor(primaryColor.value, Map.fromIterable(
				[0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
				key: (strength) => (strength * 1000).round(),
				value: (strength) {
					final ds = 0.5 - strength;
					return Color.fromRGBO(
						primaryColor.red + ((ds < 0) ? primaryColor.red : (255 - primaryColor.red) * ds).round(),
						primaryColor.green + ((ds < 0) ? primaryColor.green : (255 - primaryColor.green) * ds).round(),
						primaryColor.blue + ((ds < 0) ? primaryColor.blue : (255 - primaryColor.blue) * ds).round(),
						1
					);
				}
			)),
			accentColor: secondaryColor,
			cardColor: barColor,
			backgroundColor: backgroundColor
		).copyWith(
			onBackground: primaryColor
		);
		final textTheme = (brightness == Brightness.dark ? Typography.whiteMountainView : Typography.blackMountainView).apply(
			bodyColor: primaryColor,
			displayColor: primaryColor,
			decorationColor: primaryColor,
			fontFamily: Persistence.settings.textStyle.fontFamily ?? (platformIsMaterial ? 'Roboto' : '.SF Pro Text')
		);
		return ThemeData.from(
			colorScheme: colorScheme,
			useMaterial3: true,
			textTheme: textTheme.copyWith(
				bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 17, height: 1.3)
			)
		).copyWith(
			platform: (platformIsMaterial || !Persistence.settings.materialStyle) ? null : TargetPlatform.android,
			pageTransitionsTheme: const PageTransitionsTheme(builders: {}),
			iconTheme: IconThemeData(
				color: primaryColor
			),
			buttonTheme: ButtonThemeData(
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(4)
				)
			),
			outlinedButtonTheme: OutlinedButtonThemeData(
				style: ButtonStyle(
					side: MaterialStateProperty.all(BorderSide(color: primaryColor))
				)
			),
			listTileTheme: ListTileThemeData(
				iconColor: primaryColor,
				textColor: primaryColor,
				selectedTileColor: primaryColorWithBrightness(0.3)
			),
			segmentedButtonTheme: SegmentedButtonThemeData(
				style: ButtonStyle(
					backgroundColor: MaterialStateProperty.resolveWith((s) {
						if (s.contains(MaterialState.selected)) {
							return primaryColor;
						}
						return null;
					}),
					foregroundColor: MaterialStateProperty.resolveWith((s) {
						if (s.contains(MaterialState.selected)) {
							return backgroundColor;
						}
						return null;
					}),
					shape: MaterialStateProperty.all(RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(4),
						side: BorderSide(
							color: primaryColor
						)
					)),
					side: MaterialStateProperty.resolveWith((s) {
						if (s.contains(MaterialState.disabled)) {
							return null;
						}
						return BorderSide(color: primaryColor);
					})
				)
			),
			iconButtonTheme: IconButtonThemeData(
				style: ButtonStyle(
					iconColor: MaterialStateProperty.all(primaryColor)
				)
			),
			switchTheme: SwitchThemeData(
				thumbColor: MaterialStateProperty.resolveWith((states) {
					if (states.contains(MaterialState.hovered) || states.contains(MaterialState.pressed)) {
						return primaryColorWithBrightness(0.1);
					}
					return null;
				})
			),
			sliderTheme: const SliderThemeData(
				allowedInteraction: SliderInteraction.slideThumb
			),
			cupertinoOverrideTheme: cupertinoThemeData
		);
	}

	Color get searchTextFieldColor {
		if (brightness == Brightness.light) {
			return textFieldColor.towardsGrey(0.43).withOpacity(0.4);
		}
		return textFieldColor.towardsGrey(0.43);
	}
}

const _dynamicLightKey = 'Dynamic (Light)';
const _dynamicDarkKey = 'Dynamic (Dark)';

Future<bool> updateDynamicColors() async {
	if (!Platform.isAndroid) {
		return false;
	}
	final colors = await DynamicColorPlugin.getCorePalette();
	if (colors != null) {
		final light = SavedTheme(
			backgroundColor: Color(colors.neutral.get(99)),
			barColor: Color(colors.neutralVariant.get(90)),
			primaryColor: Color(colors.primary.get(10)),
			secondaryColor: Color(colors.primary.get(40)),
			quoteColor: _defaultQuoteColor,
			titleColor: Color(colors.tertiary.get(40)),
			locked: true
		);
		final dark = SavedTheme(
			backgroundColor: Color(colors.neutral.get(10)),
			barColor: Color(colors.neutralVariant.get(30)),
			primaryColor: Color(colors.primary.get(99)),
			secondaryColor: Color(colors.primary.get(70)),
			quoteColor: _defaultQuoteColor,
			titleColor: Color(colors.tertiary.get(70)),
			locked: true
		);
		final updated = ((Persistence.settings.lightThemeKey == _dynamicLightKey) && (light != Persistence.settings.themes[_dynamicLightKey])) ||
		                ((Persistence.settings.darkThemeKey == _dynamicDarkKey) && (dark != Persistence.settings.themes[_dynamicDarkKey]));
		Persistence.settings.themes[_dynamicLightKey] = light;
		Persistence.settings.themes[_dynamicDarkKey] = dark;
		return updated;
	}
	return false;
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
	@HiveField(9)
	ipNumber,
	@HiveField(10)
	postNumber,
	@HiveField(11)
	lineBreak
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
			case PostDisplayField.ipNumber:
				return 'IP Address #';
			case PostDisplayField.postNumber:
				return 'Post #';
			case PostDisplayField.lineBreak:
				return 'Line break';
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
	toggleListPositionIndicatorLocation,
	@HiveField(5)
	toggleVerticalTwoPaneSplit
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
			case SettingsQuickAction.toggleVerticalTwoPaneSplit:
				return 'Toggle vertical two-pane layout';
			case null:
				return 'None';
		}
	}
}

@HiveType(typeId: 37)
enum GallerySavePathOrganizing {
	@HiveField(0)
	noSubfolders,
	@HiveField(1)
	boardSubfolders,
	@HiveField(2)
	boardAndThreadSubfolders
}

final allowedGoogleFonts = {
	'Josefin Sans': GoogleFonts.josefinSans,
	'Lato': GoogleFonts.lato,
	'Merriweather': GoogleFonts.merriweather,
	'Merriweather Sans': GoogleFonts.merriweatherSans,
	'Montserrat': GoogleFonts.montserrat,
	'Noto Sans': GoogleFonts.notoSans,
	'Open Sans': GoogleFonts.openSans,
	'PT Sans': GoogleFonts.ptSans,
	'Raleway': GoogleFonts.raleway,
	'Roboto': GoogleFonts.roboto,
	'Roboto Slab': GoogleFonts.robotoSlab,
	'Slabo 27px': GoogleFonts.slabo27px,
	'Source Sans Pro': GoogleFonts.sourceSansPro
};

@HiveType(typeId: 43)
enum ImagePeekingSetting {
	@HiveField(0)
	disabled,
	@HiveField(1)
	standard,
	@HiveField(2)
	unsafe,
	@HiveField(3)
	ultraUnsafe;
}

@HiveType(typeId: 44)
enum MouseModeQuoteLinkBehavior {
	@HiveField(0)
	expandInline,
	@HiveField(1)
	scrollToPost,
	@HiveField(2)
	popupPostsPage
}

@HiveType(typeId: 45)
enum DrawerMode {
	@HiveField(0)
	tabs,
	@HiveField(1)
	watchedThreads,
	@HiveField(2)
	savedThreads;
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
	Map<String, Map<String, ImageboardBoard>> deprecatedBoardsBySite;
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
	@HiveField(102)
	int launchCount;
	@HiveField(103)
	String userAgent;
	@HiveField(104)
	int captcha4ChanCustomNumLetters;
	@HiveField(105)
	bool tabMenuHidesWhenScrollingDown;
	@HiveField(106)
	bool doubleTapScrollToReplies;
	@HiveField(107)
	String? lastUnifiedPushEndpoint;
	@HiveField(108)
	WebImageSearchMethod webImageSearchMethod;
	@HiveField(109)
	bool showIPNumberOnPosts;
	@HiveField(110)
	bool showNoBeforeIdOnPosts;
	@HiveField(111)
	bool blurEffects;
	@HiveField(112)
	bool scrollbarsOnLeft;
	@HiveField(113)
	bool exactTimeIsTwelveHour;
	@HiveField(114)
	bool exactTimeShowsDateForToday;
	@HiveField(115)
	double attachmentsPageMaxCrossAxisExtent;
	@HiveField(116)
	bool catalogGridModeCellBorderRadiusAndMargin;
	@HiveField(117)
	bool catalogGridModeShowMoreImageIfLessText;
	@HiveField(118)
	bool showPostNumberOnPosts;
	@HiveField(119)
	bool overscrollModalTapPopsAll;
	@HiveField(120)
	bool squareThumbnails;
	@HiveField(121)
	bool alwaysShowSpoilers;
	@HiveField(122)
	GallerySavePathOrganizing gallerySavePathOrganizing;
	@HiveField(123)
	AutoloadAttachmentsSetting fullQualityThumbnails;
	@HiveField(124)
	bool recordThreadsInHistory;
	@HiveField(125)
	String? fontFamily;
	@HiveField(126)
	AutoloadAttachmentsSetting autoCacheAttachments;
	@HiveField(127)
	bool exactTimeUsesCustomDateFormat;
	@HiveField(128)
	bool deprecatedUnsafeImagePeeking;
	@HiveField(129)
	bool showOverlaysInGallery;
	@HiveField(130)
	double verticalTwoPaneMinimumPaneSize;
	@HiveField(131)
	Set<String> hiddenImageMD5s;
	@HiveField(132)
	bool showLastRepliesInCatalog;
	@HiveField(133)
	AutoloadAttachmentsSetting loadThumbnails;
	@HiveField(134)
	bool applyImageFilterToThreads;
	@HiveField(135)
	bool askForAuthenticationOnLaunch;
	@HiveField(136)
	bool enableSpellCheck;
	@HiveField(137)
	bool openCrossThreadLinksInNewTab;
	@HiveField(138)
	int backgroundThreadAutoUpdatePeriodSeconds;
	@HiveField(139)
	int currentThreadAutoUpdatePeriodSeconds;
	@HiveField(140)
	ShareablePostsStyle lastShareablePostsStyle;
	@HiveField(141)
	ThreadWatch? defaultThreadWatch;
	@HiveField(142)
	bool highlightRepeatingDigitsInPostIds;
	@HiveField(143)
	bool includeThreadsYouRepliedToWhenDeletingHistory;
	@HiveField(144)
	double newPostHighlightBrightness;
	@HiveField(145)
	ImagePeekingSetting imagePeeking;
	// These next few fields are done this way to allow the default to be changed later.
	@HiveField(146)
	bool? useMaterialStyle;
	bool get materialStyle => useMaterialStyle ?? platformIsMaterial;
	@HiveField(147)
	bool? useAndroidDrawer;
	bool get androidDrawer => useAndroidDrawer ?? false;
	@HiveField(148)
	bool? useMaterialRoutes;
	bool get materialRoutes => useMaterialRoutes ?? false;
	@HiveField(149)
	bool hideBarsWhenScrollingDown;
	@HiveField(150)
	bool showPerformanceOverlay;
	@HiveField(151)
	String customDateFormat;
	@HiveField(152)
	int hoverPopupDelayMilliseconds;
	@HiveField(153)
	MouseModeQuoteLinkBehavior mouseModeQuoteLinkBehavior;
	@HiveField(154)
	DrawerMode drawerMode;
	@HiveField(155)
	bool showLineBreakInPostInfoRow;
	@HiveField(156)
	bool? useCloudCaptchaSolver;
	@HiveField(157)
	bool? useHeadlessCloudCaptchaSolver;
	@HiveField(158)
	bool removeMetadataOnUploadedFiles;
	@HiveField(159)
	bool randomizeChecksumOnUploadedFiles;
	@HiveField(160)
	List<String> recentWebImageSearches;

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
		Map<String, Map<String, ImageboardBoard>>? deprecatedBoardsBySite,
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
		int? launchCount,
		String? userAgent,
		int? captcha4ChanCustomNumLetters,
		bool? tabMenuHidesWhenScrollingDown,
		bool? doubleTapScrollToReplies,
		this.lastUnifiedPushEndpoint,
		WebImageSearchMethod? webImageSearchMethod,
		bool? showIPNumberOnPosts,
		bool? showNoBeforeIdOnPosts,
		bool? blurEffects,
		bool? scrollbarsOnLeft,
		bool? exactTimeIsTwelveHour,
		bool? exactTimeShowsDateForToday,
		double? attachmentsPageMaxCrossAxisExtent,
		bool? catalogGridModeCellBorderRadiusAndMargin,
		bool? catalogGridModeShowMoreImageIfLessText,
		bool? showPostNumberOnPosts,
		bool? overscrollModalTapPopsAll,
		bool? squareThumbnails,
		bool? alwaysShowSpoilers,
		GallerySavePathOrganizing? gallerySavePathOrganizing,
		AutoloadAttachmentsSetting? fullQualityThumbnails,
		bool? recordThreadsInHistory,
		this.fontFamily,
		AutoloadAttachmentsSetting? autoCacheAttachments,
		bool? exactTimeUsesCustomDateFormat,
		bool? deprecatedUnsafeImagePeeking,
		bool? showOverlaysInGallery,
		double? verticalTwoPaneMinimumPaneSize,
		List<String>? hiddenImageMD5s,
		bool? showLastRepliesInCatalog,
		AutoloadAttachmentsSetting? loadThumbnails,
		bool? applyImageFilterToThreads,
		bool? askForAuthenticationOnLaunch,
		bool? enableSpellCheck,
		bool? openCrossThreadLinksInNewTab,
		int? backgroundThreadAutoUpdatePeriodSeconds,
		int? currentThreadAutoUpdatePeriodSeconds,
		ShareablePostsStyle? lastShareablePostsStyle,
		this.defaultThreadWatch,
		bool? highlightRepeatingDigitsInPostIds,
		bool? includeThreadsYouRepliedToWhenDeletingHistory,
		double? newPostHighlightBrightness,
		ImagePeekingSetting? imagePeeking,
		this.useMaterialStyle,
		this.useAndroidDrawer,
		this.useMaterialRoutes,
		bool? hideBarsWhenScrollingDown,
		bool? showPerformanceOverlay,
		String? customDateFormat,
		int? hoverPopupDelayMilliseconds,
		MouseModeQuoteLinkBehavior? mouseModeQuoteLinkBehavior,
		DrawerMode? drawerMode,
		bool? showLineBreakInPostInfoRow,
		this.useCloudCaptchaSolver,
		this.useHeadlessCloudCaptchaSolver,
		bool? removeMetadataOnUploadedFiles,
		bool? randomizeChecksumOnUploadedFiles,
		List<String>? recentWebImageSearches,
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
		deprecatedBoardsBySite = deprecatedBoardsBySite ?? {},
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
			PostDisplayField.postNumber,
			PostDisplayField.ipNumber,
			PostDisplayField.name,
			PostDisplayField.posterId,
			PostDisplayField.attachmentInfo,
			PostDisplayField.pass,
			PostDisplayField.lineBreak,
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
		webmTranscoding = webmTranscoding ?? WebmTranscodingSetting.never,
		showListPositionIndicatorsOnLeft = showListPositionIndicatorsOnLeft ?? false,
		appliedMigrations = appliedMigrations ?? [],
		enableIMEPersonalizedLearning = enableIMEPersonalizedLearning ?? true,
		catalogVariant = catalogVariant ?? CatalogVariant.unsorted,
		redditCatalogVariant = redditCatalogVariant ?? CatalogVariant.redditHot,
		dimReadThreads = dimReadThreads ?? true,
		hackerNewsCatalogVariant = hackerNewsCatalogVariant ?? CatalogVariant.hackerNewsTop,
		hideDefaultNamesInCatalog = hideDefaultNamesInCatalog ?? false,
		launchCount = launchCount ?? 0,
		userAgent = userAgent ?? getAppropriateUserAgents().first,
		captcha4ChanCustomNumLetters = captcha4ChanCustomNumLetters ?? 6,
		tabMenuHidesWhenScrollingDown = tabMenuHidesWhenScrollingDown ?? true,
		doubleTapScrollToReplies = doubleTapScrollToReplies ?? true,
		webImageSearchMethod = webImageSearchMethod ?? WebImageSearchMethod.google,
		showIPNumberOnPosts = showIPNumberOnPosts ?? true,
		showNoBeforeIdOnPosts = showNoBeforeIdOnPosts ?? false,
		blurEffects = blurEffects ?? true,
		scrollbarsOnLeft = scrollbarsOnLeft ?? false,
		exactTimeIsTwelveHour = exactTimeIsTwelveHour ?? false,
		exactTimeShowsDateForToday = exactTimeShowsDateForToday ?? false,
		attachmentsPageMaxCrossAxisExtent = attachmentsPageMaxCrossAxisExtent ?? 400,
		catalogGridModeCellBorderRadiusAndMargin = catalogGridModeCellBorderRadiusAndMargin ?? false,
		catalogGridModeShowMoreImageIfLessText = catalogGridModeShowMoreImageIfLessText ?? true,
		showPostNumberOnPosts = showPostNumberOnPosts ?? true,
		overscrollModalTapPopsAll = overscrollModalTapPopsAll ?? true,
		squareThumbnails = squareThumbnails ?? false,
		alwaysShowSpoilers = alwaysShowSpoilers ?? false,
		gallerySavePathOrganizing = gallerySavePathOrganizing ?? GallerySavePathOrganizing.noSubfolders,
		fullQualityThumbnails = fullQualityThumbnails ?? AutoloadAttachmentsSetting.never,
		recordThreadsInHistory = recordThreadsInHistory ?? true,
		autoCacheAttachments = autoCacheAttachments ?? AutoloadAttachmentsSetting.never,
		exactTimeUsesCustomDateFormat = exactTimeUsesCustomDateFormat ?? false,
		deprecatedUnsafeImagePeeking = deprecatedUnsafeImagePeeking ?? false,
		showOverlaysInGallery = showOverlaysInGallery ?? true,
		verticalTwoPaneMinimumPaneSize = verticalTwoPaneMinimumPaneSize ?? -400,
		hiddenImageMD5s = hiddenImageMD5s?.toSet() ?? {},
		showLastRepliesInCatalog = showLastRepliesInCatalog ?? false,
		loadThumbnails = loadThumbnails ?? AutoloadAttachmentsSetting.always,
		applyImageFilterToThreads = applyImageFilterToThreads ?? false,
		askForAuthenticationOnLaunch = askForAuthenticationOnLaunch ?? false,
		enableSpellCheck = enableSpellCheck ?? true,
		openCrossThreadLinksInNewTab = openCrossThreadLinksInNewTab ?? false,
		backgroundThreadAutoUpdatePeriodSeconds = backgroundThreadAutoUpdatePeriodSeconds ?? 60,
		currentThreadAutoUpdatePeriodSeconds = currentThreadAutoUpdatePeriodSeconds ?? 60,
		lastShareablePostsStyle = lastShareablePostsStyle ?? const ShareablePostsStyle(),
		highlightRepeatingDigitsInPostIds = highlightRepeatingDigitsInPostIds ?? false,
		includeThreadsYouRepliedToWhenDeletingHistory = includeThreadsYouRepliedToWhenDeletingHistory ?? false,
		newPostHighlightBrightness = newPostHighlightBrightness ?? 0.1,
		imagePeeking = imagePeeking ?? (deprecatedUnsafeImagePeeking == true ? ImagePeekingSetting.unsafe : ImagePeekingSetting.standard),
		hideBarsWhenScrollingDown = hideBarsWhenScrollingDown ?? false,
		showPerformanceOverlay = showPerformanceOverlay ?? false,
		customDateFormat = customDateFormat ?? DateTimeConversion.kISO8601DateFormat,
		hoverPopupDelayMilliseconds = hoverPopupDelayMilliseconds ?? 0,
		mouseModeQuoteLinkBehavior = mouseModeQuoteLinkBehavior ?? MouseModeQuoteLinkBehavior.expandInline,
		drawerMode = drawerMode ?? DrawerMode.tabs,
		showLineBreakInPostInfoRow = showLineBreakInPostInfoRow ?? false,
		removeMetadataOnUploadedFiles = removeMetadataOnUploadedFiles ?? true,
		randomizeChecksumOnUploadedFiles = randomizeChecksumOnUploadedFiles ?? false,
		recentWebImageSearches = recentWebImageSearches ?? [] {
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
			if (!this.appliedMigrations.contains('uar')) {
				// uar means userAgentReset
				if (Platform.isAndroid && !getAppropriateUserAgents().contains(this.userAgent) && this.contentSettings.sites.containsKey('4chan')) {
					this.userAgent = getAppropriateUserAgents().first;
				}
				this.appliedMigrations.add('uar');
			}
			if (!this.postDisplayFieldOrder.contains(PostDisplayField.ipNumber)) {
				this.postDisplayFieldOrder.insert(0, PostDisplayField.ipNumber);
			}
			if (!this.postDisplayFieldOrder.contains(PostDisplayField.postNumber)) {
				this.postDisplayFieldOrder.insert(0, PostDisplayField.postNumber);
			}
			if (getInappropriateUserAgents().contains(this.userAgent) && !getAppropriateUserAgents().contains(this.userAgent)) {
				// To handle user-agents breaking with OS updates
				this.userAgent = getAppropriateUserAgents().first;
			}
			if (!this.appliedMigrations.contains('uif')) {
				// uif means unifiedImageFilter
				this.hiddenImageMD5s.addAll(this.browserStateBySite.values.expand((s) => s.deprecatedHiddenImageMD5s));
				for (final s in this.browserStateBySite.values) {
					s.deprecatedHiddenImageMD5s.clear();
				}
				this.appliedMigrations.add('uif');
			}
			if (!this.postDisplayFieldOrder.contains(PostDisplayField.lineBreak)) {
				this.postDisplayFieldOrder.insert(min(this.postDisplayFieldOrder.length - 1, 6), PostDisplayField.lineBreak);
			}
			if (!this.appliedMigrations.contains('mk')) {
				// mk means media-kit
				this.webmTranscoding = WebmTranscodingSetting.never;
				this.appliedMigrations.add('mk');
			}
		}

	@override
	Future<void> save() async {
		await runWhenIdle(const Duration(milliseconds: 500), super.save);
	}


	TextStyle get textStyle {
		if (fontFamily == null) {
			return const TextStyle(
				fontFamily: '.SF Pro Text'
			);
		}
		String name = fontFamily!;
		if (name.endsWith('.ttf')) {
			name = name.replaceFirst(RegExp(r'\.ttf$'), '');
		}
		return allowedGoogleFonts[name]?.call() ?? TextStyle(
			fontFamily: name
		);
	}
}

class EffectiveSettings extends ChangeNotifier {
	static EffectiveSettings? _instance;
	static EffectiveSettings get instance => _instance ??= EffectiveSettings._();

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
	bool get isConnectedToWifi => switch (_connectivity) {
		ConnectivityResult.mobile || null => false,
		_ => true
	};
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
			((_settings.autoloadAttachments == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
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
		return _systemBrightness ?? PlatformDispatcher.instance.platformBrightness;
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
		return _settings.contentSettings.images && ((context.read<Persistence>().maybeGetBoard(board)?.isWorksafe ?? false) || _settings.contentSettings.nsfwImages);
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

	Filter get globalFilter => FilterGroup([filter, imageMD5Filter]);

	String? filterError;
	final filterListenable = EasyListenable();
	FilterCache<FilterGroup<CustomFilter>>? _filter;
	Iterable<CustomFilter> get customFilterLines => _filter?.wrappedFilter.filters ?? const Iterable.empty();
	Filter get filter => _filter ?? const DummyFilter();
	void _tryToSetupFilter() {
		try {
			final newFilter = makeFilter(filterConfiguration);
			if (newFilter != _filter?.wrappedFilter) {
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
	String get themeKey => whichTheme == Brightness.dark ? darkThemeKey : lightThemeKey;
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

	int get launchCount => _settings.launchCount;

	String get userAgent => _settings.userAgent;
	set userAgent(String setting) {
		_settings.userAgent = setting;
		_settings.save();
		notifyListeners();
	}

	int get captcha4ChanCustomNumLetters => _settings.captcha4ChanCustomNumLetters;
	set captcha4ChanCustomNumLetters(int setting) {
		_settings.captcha4ChanCustomNumLetters = setting;
		_settings.save();
		notifyListeners();
	}

	bool get tabMenuHidesWhenScrollingDown => _settings.tabMenuHidesWhenScrollingDown;
	set tabMenuHidesWhenScrollingDown(bool setting) {
		_settings.tabMenuHidesWhenScrollingDown = setting;
		_settings.save();
		notifyListeners();
	}
	
	bool get doubleTapScrollToReplies => _settings.doubleTapScrollToReplies;
	set doubleTapScrollToReplies(bool setting) {
		_settings.doubleTapScrollToReplies = setting;
		_settings.save();
		notifyListeners();
	}

	String? get lastUnifiedPushEndpoint => _settings.lastUnifiedPushEndpoint;
	set lastUnifiedPushEndpoint(String? setting) {
		_settings.lastUnifiedPushEndpoint = setting;
		_settings.save();
	}

	WebImageSearchMethod get webImageSearchMethod => _settings.webImageSearchMethod;
	set webImageSearchMethod(WebImageSearchMethod setting) {
		_settings.webImageSearchMethod = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showIPNumberOnPosts => _settings.showIPNumberOnPosts;
	set showIPNumberOnPosts(bool setting) {
		_settings.showIPNumberOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showNoBeforeIdOnPosts => _settings.showNoBeforeIdOnPosts;
	set showNoBeforeIdOnPosts(bool setting) {
		_settings.showNoBeforeIdOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get blurEffects => _settings.blurEffects;
	set blurEffects(bool setting) {
		_settings.blurEffects = setting;
		_settings.save();
		notifyListeners();
	}

	bool get scrollbarsOnLeft => _settings.scrollbarsOnLeft;
	set scrollbarsOnLeft(bool setting) {
		_settings.scrollbarsOnLeft = setting;
		_settings.save();
		notifyListeners();
	}

	bool get exactTimeIsTwelveHour => _settings.exactTimeIsTwelveHour;
	set exactTimeIsTwelveHour(bool setting) {
		_settings.exactTimeIsTwelveHour = setting;
		_settings.save();
		notifyListeners();
	}

	bool get exactTimeShowsDateForToday => _settings.exactTimeShowsDateForToday;
	set exactTimeShowsDateForToday(bool setting) {
		_settings.exactTimeShowsDateForToday = setting;
		_settings.save();
		notifyListeners();
	}

	double get attachmentsPageMaxCrossAxisExtent => _settings.attachmentsPageMaxCrossAxisExtent;
	set attachmentsPageMaxCrossAxisExtent(double setting) {
		_settings.attachmentsPageMaxCrossAxisExtent = setting;
		_settings.save();
		notifyListeners();
	}

	bool get catalogGridModeCellBorderRadiusAndMargin => _settings.catalogGridModeCellBorderRadiusAndMargin;
	set catalogGridModeCellBorderRadiusAndMargin(bool setting) {
		_settings.catalogGridModeCellBorderRadiusAndMargin = setting;
		_settings.save();
		notifyListeners();
	}

	bool get catalogGridModeShowMoreImageIfLessText => _settings.catalogGridModeShowMoreImageIfLessText;
	set catalogGridModeShowMoreImageIfLessText(bool setting) {
		_settings.catalogGridModeShowMoreImageIfLessText = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showPostNumberOnPosts => _settings.showPostNumberOnPosts;
	set showPostNumberOnPosts(bool setting) {
		_settings.showPostNumberOnPosts = setting;
		_settings.save();
		notifyListeners();
	}

	bool get overscrollModalTapPopsAll => _settings.overscrollModalTapPopsAll;
	set overscrollModalTapPopsAll(bool setting) {
		_settings.overscrollModalTapPopsAll = setting;
		_settings.save();
		notifyListeners();
	}

	bool get squareThumbnails => _settings.squareThumbnails;
	set squareThumbnails(bool setting) {
		_settings.squareThumbnails = setting;
		_settings.save();
		notifyListeners();
	}
	
	bool get alwaysShowSpoilers => _settings.alwaysShowSpoilers;
	set alwaysShowSpoilers(bool setting) {
		_settings.alwaysShowSpoilers = setting;
		_settings.save();
		notifyListeners();
	}

	GallerySavePathOrganizing get gallerySavePathOrganizing => _settings.gallerySavePathOrganizing;
	set gallerySavePathOrganizing(GallerySavePathOrganizing setting) {
		_settings.gallerySavePathOrganizing = setting;
		_settings.save();
		notifyListeners();
	}

	AutoloadAttachmentsSetting get fullQualityThumbnailsSetting => _settings.fullQualityThumbnails;
	set fullQualityThumbnailsSetting(AutoloadAttachmentsSetting setting) {
		_settings.fullQualityThumbnails = setting;
		_settings.save();
		notifyListeners();
	}
	bool get fullQualityThumbnails {
		return (fullQualityThumbnailsSetting == AutoloadAttachmentsSetting.always) ||
			((fullQualityThumbnailsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	bool get recordThreadsInHistory => _settings.recordThreadsInHistory;
	set recordThreadsInHistory(bool setting) {
		_settings.recordThreadsInHistory = setting;
		_settings.save();
		notifyListeners();
	}

	String? get fontFamily => _settings.fontFamily;
	set fontFamily(String? setting) {
		_settings.fontFamily = setting;
		_settings.save();
		notifyListeners();
	}

	AutoloadAttachmentsSetting get autoCacheAttachmentsSetting => _settings.autoCacheAttachments;
	set autoCacheAttachmentsSetting(AutoloadAttachmentsSetting setting) {
		_settings.autoCacheAttachments = setting;
		_settings.save();
		notifyListeners();
	}
	bool get autoCacheAttachments {
		return (autoCacheAttachmentsSetting == AutoloadAttachmentsSetting.always) ||
			((autoCacheAttachmentsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	bool get exactTimeUsesCustomDateFormat => _settings.exactTimeUsesCustomDateFormat;
	set exactTimeUsesCustomDateFormat(bool setting) {
		_settings.exactTimeUsesCustomDateFormat = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showOverlaysInGallery => _settings.showOverlaysInGallery;
	set showOverlaysInGallery(bool setting) {
		_settings.showOverlaysInGallery = setting;
		_settings.save();
		notifyListeners();
	}

	double get verticalTwoPaneMinimumPaneSize => _settings.verticalTwoPaneMinimumPaneSize;
	set verticalTwoPaneMinimumPaneSize(double setting) {
		_settings.verticalTwoPaneMinimumPaneSize = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showLastRepliesInCatalog => _settings.showLastRepliesInCatalog;
	set showLastRepliesInCatalog(bool setting) {
		_settings.showLastRepliesInCatalog = setting;
		_settings.save();
		notifyListeners();
	}

	AutoloadAttachmentsSetting get loadThumbnailsSetting => _settings.loadThumbnails;
	set loadThumbnailsSetting(AutoloadAttachmentsSetting setting) {
		_settings.loadThumbnails = setting;
		_settings.save();
		notifyListeners();
	}
	bool get loadThumbnails {
		return (loadThumbnailsSetting == AutoloadAttachmentsSetting.always) ||
			((loadThumbnailsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	bool get applyImageFilterToThreads => _settings.applyImageFilterToThreads;
	set applyImageFilterToThreads(bool setting) {
		_settings.applyImageFilterToThreads = setting;
		_settings.save();
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
		notifyListeners();
	}

	bool get askForAuthenticationOnLaunch => _settings.askForAuthenticationOnLaunch;
	set askForAuthenticationOnLaunch(bool setting) {
		_settings.askForAuthenticationOnLaunch = setting;
		_settings.save();
		notifyListeners();
	}

	bool get enableSpellCheck => _settings.enableSpellCheck;
	set enableSpellCheck(bool setting) {
		_settings.enableSpellCheck = setting;
		_settings.save();
		notifyListeners();
	}

	bool get openCrossThreadLinksInNewTab => _settings.openCrossThreadLinksInNewTab;
	set openCrossThreadLinksInNewTab (bool setting) {
		_settings.openCrossThreadLinksInNewTab = setting;
		_settings.save();
		notifyListeners();
	}

	int get backgroundThreadAutoUpdatePeriodSeconds => _settings.backgroundThreadAutoUpdatePeriodSeconds;
	set backgroundThreadAutoUpdatePeriodSeconds(int setting) {
		_settings.backgroundThreadAutoUpdatePeriodSeconds = setting;
		_settings.save();
		notifyListeners();
	}

	int get currentThreadAutoUpdatePeriodSeconds => _settings.currentThreadAutoUpdatePeriodSeconds;
	set currentThreadAutoUpdatePeriodSeconds(int setting) {
		_settings.currentThreadAutoUpdatePeriodSeconds = setting;
		_settings.save();
		notifyListeners();
	}

	ShareablePostsStyle get lastShareablePostsStyle => _settings.lastShareablePostsStyle;
	set lastShareablePostsStyle(ShareablePostsStyle setting) {
		_settings.lastShareablePostsStyle = setting;
		_settings.save();
	}

	ThreadWatch? get defaultThreadWatch => _settings.defaultThreadWatch;
	set defaultThreadWatch(ThreadWatch? setting) {
		_settings.defaultThreadWatch = setting;
		_settings.save();
		notifyListeners();
	}

	bool get highlightRepeatingDigitsInPostIds => _settings.highlightRepeatingDigitsInPostIds;
	set highlightRepeatingDigitsInPostIds(bool setting) {
		_settings.highlightRepeatingDigitsInPostIds = setting;
		_settings.save();
		notifyListeners();
	}
	
	bool get includeThreadsYouRepliedToWhenDeletingHistory => _settings.includeThreadsYouRepliedToWhenDeletingHistory;
	set includeThreadsYouRepliedToWhenDeletingHistory(bool setting) {
		_settings.includeThreadsYouRepliedToWhenDeletingHistory = setting;
		_settings.save();
		notifyListeners();
	}

	double get newPostHighlightBrightness => _settings.newPostHighlightBrightness;
	set newPostHighlightBrightness(double setting) {
		_settings.newPostHighlightBrightness = setting;
		_settings.save();
		notifyListeners();
	}

	ImagePeekingSetting get imagePeeking => _settings.imagePeeking;
	set imagePeeking(ImagePeekingSetting setting) {
		_settings.imagePeeking = setting;
		_settings.save();
		notifyListeners();
	}

	set materialStyle(bool setting) {
		_settings.useMaterialStyle = setting;
		_settings.save();
		notifyListeners();
	}
	bool get materialStyle => _settings.materialStyle;

	set androidDrawer(bool setting) {
		_settings.useAndroidDrawer = setting;
		_settings.save();
		notifyListeners();
	}
	bool get androidDrawer => _settings.androidDrawer;

	set materialRoutes(bool setting) {
		_settings.useMaterialRoutes = setting;
		_settings.save();
		notifyListeners();
	}
	bool get materialRoutes => _settings.materialRoutes;

	bool get hideBarsWhenScrollingDown => _settings.hideBarsWhenScrollingDown;
	set hideBarsWhenScrollingDown(bool setting) {
		_settings.hideBarsWhenScrollingDown = setting;
		_settings.save();
		notifyListeners();
	}

	bool get showPerformanceOverlay => _settings.showPerformanceOverlay;
	set showPerformanceOverlay(bool setting) {
		_settings.showPerformanceOverlay = setting;
		_settings.save();
		notifyListeners();
	}

	String get customDateFormat => _settings.customDateFormat;
	set customDateFormat(String setting) {
		_settings.customDateFormat = setting;
		_settings.save();
		notifyListeners();
	}

	int get hoverPopupDelayMilliseconds => _settings.hoverPopupDelayMilliseconds;
	set hoverPopupDelayMilliseconds(int setting) {
		_settings.hoverPopupDelayMilliseconds = setting;
		_settings.save();
		notifyListeners();
	}

	MouseModeQuoteLinkBehavior get mouseModeQuoteLinkBehavior => _settings.mouseModeQuoteLinkBehavior;
	set mouseModeQuoteLinkBehavior(MouseModeQuoteLinkBehavior setting) {
		_settings.mouseModeQuoteLinkBehavior = setting;
		_settings.save();
		notifyListeners();
	}

	DrawerMode get drawerMode => _settings.drawerMode;
	set drawerMode(DrawerMode setting) {
		_settings.drawerMode = setting;
		_settings.save();
	}

	bool get showLineBreakInPostInfoRow => _settings.showLineBreakInPostInfoRow;
	set showLineBreakInPostInfoRow(bool setting) {
		_settings.showLineBreakInPostInfoRow = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get useCloudCaptchaSolver => _settings.useCloudCaptchaSolver;
	set useCloudCaptchaSolver(bool? setting) {
		_settings.useCloudCaptchaSolver = setting;
		_settings.save();
		notifyListeners();
	}

	bool? get useHeadlessCloudCaptchaSolver => _settings.useHeadlessCloudCaptchaSolver;
	set useHeadlessCloudCaptchaSolver(bool? setting) {
		_settings.useHeadlessCloudCaptchaSolver = setting;
		_settings.save();
		notifyListeners();
	}

	bool get removeMetadataOnUploadedFiles => _settings.removeMetadataOnUploadedFiles;
	set removeMetadataOnUploadedFiles(bool setting) {
		_settings.removeMetadataOnUploadedFiles = setting;
		_settings.save();
		notifyListeners();
	}

	bool get randomizeChecksumOnUploadedFiles => _settings.randomizeChecksumOnUploadedFiles;
	set randomizeChecksumOnUploadedFiles(bool setting) {
		_settings.randomizeChecksumOnUploadedFiles = setting;
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

	bool areMD5sHidden(Iterable<String> md5s) {
		return md5s.any(_settings.hiddenImageMD5s.contains);
	}

	bool isMD5Hidden(String md5) {
		return _settings.hiddenImageMD5s.contains(md5);
	}

	late Filter imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
	void hideByMD5(String md5) {
		_settings.hiddenImageMD5s.add(md5);
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
	}

	void unHideByMD5(String md5) {
		_settings.hiddenImageMD5s.remove(md5);
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
	}

	void unHideByMD5s(Iterable<String> md5s) {
		_settings.hiddenImageMD5s.removeAll(md5s);
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
	}

	void setHiddenImageMD5s(Iterable<String> md5s) {
		_settings.hiddenImageMD5s.clear();
		_settings.hiddenImageMD5s.addAll(md5s.map((md5) {
			switch (md5.length % 3) {
				case 1:
					return '$md5==';
				case 2:
					return '$md5=';
			}
			return md5;
		}));
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads));
	}

	Future<void> didUpdateHiddenMD5s() async {
		notifyListeners();
		await _settings.save();
	}

	static const featureStatusBarWorkaround = true;

	EffectiveSettings._() {
		_settings = Persistence.settings;
		if (_settings.supportMouse == TristateSystemSetting.b) {
			supportMouse.value = true;
		}
		muteAudio.value = _settings.muteAudio;
		_tryToSetupFilter();
		embedRegexes = _settings.embedRegexes.map((x) => RegExp(x)).toList();
		if (_settings.launchCount % 10 == 0) {
			updateEmbedRegexes();
		}
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
	void didChangeAppLifecycleState(AppLifecycleState state) async {
		if (state == AppLifecycleState.resumed) {
			_checkConnectivity();
			VideoServer.instance.restartIfRunning();
			final settings = context.read<EffectiveSettings>();
			settings._runAppResumeCallbacks();
			if (await updateDynamicColors()) {
				settings.handleThemesAltered();
			}
		}
	}

	@override
	void didChangePlatformBrightness() {
		context.read<EffectiveSettings>().systemBrightness = PlatformDispatcher.instance.platformBrightness;
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