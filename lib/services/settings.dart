import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chan/models/board.dart';
import 'package:chan/pages/web_image_picker.dart';
import 'package:chan/services/filtering.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/json_cache.dart';
import 'package:chan/services/network_logging.dart';
import 'package:chan/services/notifications.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/services/streaming_mp4.dart';
import 'package:chan/services/thread_watcher.dart';
import 'package:chan/services/user_agents.dart';
import 'package:chan/services/util.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/shareable_posts.dart';
import 'package:chan/widgets/util.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

	static final _pattern = RegExp(r'^(.*?)((?:chance:\/\/|www\.)[^\s/$.?#].[^\s]*)');

  @override
  List<LinkifyElement> parse(elements, options) {
    final list = <LinkifyElement>[];

    for (final element in elements) {
      if (element is TextElement) {
        var match = _pattern.firstMatch(element.text);

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
const kTestchanKey = 'testchan';
const defaultSite = {
	'type': 'lainchan',
	'name': kTestchanKey,
	'baseUrl': 'boards.chance.surf',
	'maxUploadSizeBytes': 8000000
};
const defaultSites = {
	kTestchanKey: defaultSite
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
	lastReplyByYouTime,
	@HiveField(9)
	alphabeticByTitle
}

Set<String> getDefaultSiteKeys() {
	if (Platform.isAndroid) {
		return {'4chan'};
	}
	return defaultSites.keys.toSet();
}

ContentSettings getDefaultContentSettings() {
	if (Platform.isAndroid) {
		return ContentSettings(
			images: true,
			nsfwImages: true,
			nsfwBoards: true,
			nsfwText: true
		);
	}
	return ContentSettings(
		images: true,
		nsfwImages: false,
		nsfwBoards: false,
		nsfwText: false
	);
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
	@HiveField(5, merger: DeepCollectionEqualityMerger<Map<String, Map>?>(), isDeprecated: true)
	Map<String, Map>? deprecatedSites;
	@HiveField(6, merger: SetMerger<String>(PrimitiveMerger()))
	Set<String> siteKeys;

	ContentSettings({
		this.images = false,
		this.nsfwBoards = false,
		this.nsfwImages = false,
		this.nsfwText = false,
		this.deprecatedSites,
		Set<String>? siteKeys,
	}) : siteKeys = siteKeys ?? deprecatedSites?.keys.toSet() ?? getDefaultSiteKeys();

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is ContentSettings &&
		other.images == images &&
		other.nsfwBoards == nsfwBoards &&
		other.nsfwImages == nsfwImages &&
		other.nsfwText == nsfwText &&
		setEquals(other.siteKeys, siteKeys);

	@override
	int get hashCode => Object.hash(images, nsfwBoards, nsfwImages, nsfwText, siteKeys);
}

class ColorFields {
	static int getValueOnColor(Color x) => x.value;
	static const value = ReadOnlyHiveFieldAdapter<Color, int>(
		getter: getValueOnColor,
		fieldNumber: 0,
		fieldName: 'value',
		merger: PrimitiveMerger()
	);
}

class ColorAdapter extends TypeAdapter<Color> {
	const ColorAdapter();

	@override
	final fields = const {
		0: ColorFields.value
	};

	static const int kTypeId = 24;

	@override
	final int typeId = kTypeId;

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
	@HiveField(6)
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
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is SavedTheme &&
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
			platform: (platformIsMaterial || !Settings.instance.materialStyle) ? null : TargetPlatform.android,
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
	toggleVerticalTwoPaneSplit,
	@HiveField(6)
	toggleImages,
	@HiveField(7)
	togglePixelatedThumbnails
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
			case SettingsQuickAction.toggleImages:
				return 'Toggle images';
			case SettingsQuickAction.togglePixelatedThumbnails:
				return 'Toggle pixelated thumbnails';
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
	boardAndThreadSubfolders,
	@HiveField(3)
	boardAndThreadNameSubfolders,
	@HiveField(4)
	noFolder,
	@HiveField(5)
	threadNameSubfolders
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

class _LaunchCountMerger extends FieldMerger<int> {
	const _LaunchCountMerger();

	@override
	bool merge(MergerController<int> merger, int yours, int theirs, int? base) {
		if (yours == theirs) {
			return true;
		}
		if (!merger.canWrite) {
			// No match but also no ability to write
			return false;
		}
		final baseCount = base ?? 0;
		if (baseCount == 0) {
			// No base count, probably the same device, just use highest count found
			if (yours > theirs) {
				merger.writeTheirs(yours);
			}
			else {
				merger.writeYours(theirs);
			}
			return true;
		}
		// Assume this is two devices, add deltas in count
		final newCount = baseCount + (yours - baseCount) + (theirs - baseCount);
		if (yours != newCount) {
			merger.writeYours(newCount);
		}
		if (theirs != newCount) {
			merger.writeTheirs(newCount);
		}
		return true;
	}

}

void _readHookSavedSettingsFields(Map<int, dynamic> fields) {
	// Migrate List<String> to Set<String>
	fields.update(SavedSettingsFields.hiddenImageMD5s.fieldNumber, (hiddenImageMD5s) {
		if (hiddenImageMD5s is List) {
			return hiddenImageMD5s.toSet();
		}
		return hiddenImageMD5s;
	});
	fields.putIfAbsent(SavedSettingsFields.watchThreadAutomaticallyWhenCreating.fieldNumber, () {
		// Default when-creating to same as old when-replying
		return fields[SavedSettingsFields.watchThreadAutomaticallyWhenReplying.fieldNumber] ?? true;
	});
}

@HiveType(typeId: 0, readHook: _readHookSavedSettingsFields)
class SavedSettings extends HiveObject {
	@HiveField(0)
	AutoloadAttachmentsSetting autoloadAttachments;
	@HiveField(1)
	TristateSystemSetting theme;
	@HiveField(2)
	bool hideOldStickiedThreads;
	@HiveField(3, isDeprecated: true)
	ThreadSortingMethod deprecatedCatalogSortingMethod;
	@HiveField(4, isDeprecated: true)
	bool deprecatedReverseCatalogSorting;
	@HiveField(5)
	ThreadSortingMethod savedThreadsSortingMethod;
	@HiveField(6)
	bool autoRotateInGallery;
	@HiveField(9)
	bool useTouchLayout;
	@HiveField(10)
	/// Preserved for some future sync use or something
	String userId;
  @HiveField(11)
	ContentSettings contentSettings;
	@HiveField(13)
	String filterConfiguration;
	@HiveField(14)
	bool boardSwitcherHasKeyboardFocus;
	@HiveField(15, isDeprecated: true)
	SavedTheme deprecatedLightTheme;
	@HiveField(16, isDeprecated: true)
	SavedTheme deprecatedDarkTheme;
	@HiveField(17, isDeprecated: true)
	Map<String, PersistentRecentSearches> deprecatedRecentSearchesBySite;
	@HiveField(18)
	Map<String, PersistentBrowserState> browserStateBySite;
	@HiveField(19)
	Map<String, Map<String, SavedPost>> savedPostsBySite;
	@HiveField(20)
	Map<String, Map<String, SavedAttachment>> savedAttachmentsBySite;
	@HiveField(21, isDeprecated: true)
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
	@HiveField(29, isDeprecated: true)
	List<String> deprecatedEmbedRegexes;
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
	@HiveField(67, merger: OrderedSetLikePrimitiveListMerger<PostDisplayField>())
	List<PostDisplayField> postDisplayFieldOrder;
	@HiveField(68)
	int? maximumImageUploadDimension;
	@HiveField(69, merger: PersistentBrowserTab.listMerger)
	List<PersistentBrowserTab> tabs;
	@HiveField(70)
	int currentTabIndex; // TODO(sync): Maintain tabs[currentTabIndex] before/after merge
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
	@HiveField(84, merger: SetLikePrimitiveListMerger<String>())
	List<String> hostsToOpenExternally;
	@HiveField(85)
	bool useFullWidthForCatalogCounters;
	@HiveField(86, isDeprecated: true)
	bool? deprecatedAlwaysStartVideosMuted;
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
	@HiveField(94, merger: SetLikePrimitiveListMerger<String>())
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
	@HiveField(102, merger: _LaunchCountMerger())
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
	@HiveField(128, isDeprecated: true)
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
	@HiveField(147)
	bool? useAndroidDrawer;
	@HiveField(148)
	bool? useMaterialRoutes;
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
	@HiveField(160, merger: OrderedSetLikePrimitiveListMerger<String>())
	List<String> recentWebImageSearches;
	@HiveField(161)
	bool cloverStyleRepliesButton;
	@HiveField(162)
	bool watchThreadAutomaticallyWhenReplying;
	@HiveField(163)
	bool saveThreadAutomaticallyWhenReplying;
	@HiveField(164)
	bool cancellableRepliesSlideGesture;
	@HiveField(165)
	bool openBoardSwitcherSlideGesture;
	@HiveField(166)
	bool persistentDrawer;
	@HiveField(167)
	bool showGalleryGridButton;
	@HiveField(168)
	double centeredPostThumbnailSize;
	@HiveField(169)
	bool ellipsizeLongFilenamesOnPosts;
	@HiveField(170)
	TristateSystemSetting muteAudioWhenOpeningGallery;
	@HiveField(171)
	String translationTargetLanguage;
	@HiveField(172)
	String? homeImageboardKey;
	@HiveField(173)
	String homeBoardName;
	@HiveField(174)
	bool tapPostIdToReply;
	@HiveField(175)
	bool downloadUsingServerSideFilenames;
	@HiveField(176)
	double catalogGridModeTextScale;
	@HiveField(177)
	bool catalogGridModeCropThumbnails;
	@HiveField(178)
	bool useSpamFilterWorkarounds;
	@HiveField(179)
	double scrollbarThickness;
	@HiveField(180)
	int thumbnailPixelation;
	@HiveField(181)
	bool catalogGridModeTextAboveAttachment;
	@HiveField(182)
	bool swipeGesturesOnBottomBar;
	@HiveField(183)
	Map<String, String> mpvOptions;
	@HiveField(184)
	int dynamicIPKeepAlivePeriodSeconds;
	@HiveField(185)
	int postingRegretDelaySeconds;
	@HiveField(186)
	bool showHiddenItemsFooter;
	@HiveField(187)
	bool attachmentsPageUsePageView;
	@HiveField(188)
	bool showReplyCountInCatalog;
	@HiveField(189)
	bool watchThreadAutomaticallyWhenCreating;
	@HiveField(190)
	int imageMetaFilterDepth;
	@HiveField(191)
	bool useStaggeredCatalogGrid;

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
		List<String>? deprecatedEmbedRegexes,
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
		this.deprecatedAlwaysStartVideosMuted,
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
		Set<String>? hiddenImageMD5s,
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
		bool? cloverStyleRepliesButton,
		bool? watchThreadAutomaticallyWhenReplying,
		bool? saveThreadAutomaticallyWhenReplying,
		bool? cancellableRepliesSlideGesture,
		bool? openBoardSwitcherSlideGesture,
		bool? persistentDrawer,
		bool? showGalleryGridButton,
		double? centeredPostThumbnailSize,
		bool? ellipsizeLongFilenamesOnPosts,
		TristateSystemSetting? muteAudioWhenOpeningGallery,
		String? translationTargetLanguage,
		this.homeImageboardKey,
		String? homeBoardName,
		bool? tapPostIdToReply,
		bool? downloadUsingServerSideFilenames,
		double? catalogGridModeTextScale,
		bool? catalogGridModeCropThumbnails,
		bool? useSpamFilterWorkarounds,
		double? scrollbarThickness,
		int? thumbnailPixelation,
		bool? catalogGridModeTextAboveAttachment,
		bool? swipeGesturesOnBottomBar,
		Map<String, String>? mpvOptions,
		int? dynamicIPKeepAlivePeriodSeconds,
		int? postingRegretDelaySeconds,
		bool? showHiddenItemsFooter,
		bool? attachmentsPageUsePageView,
		bool? showReplyCountInCatalog,
		bool? watchThreadAutomaticallyWhenCreating,
		int? imageMetaFilterDepth,
		bool? useStaggeredCatalogGrid,
	}): autoloadAttachments = autoloadAttachments ?? AutoloadAttachmentsSetting.wifi,
		theme = theme ?? TristateSystemSetting.system,
		hideOldStickiedThreads = hideOldStickiedThreads ?? false,
		deprecatedCatalogSortingMethod = deprecatedCatalogSortingMethod ?? ThreadSortingMethod.unsorted,
		deprecatedReverseCatalogSorting = deprecatedReverseCatalogSorting ?? false,
		savedThreadsSortingMethod = savedThreadsSortingMethod ?? ThreadSortingMethod.savedTime,
		autoRotateInGallery = autoRotateInGallery ?? false,
		useTouchLayout = useTouchLayout ?? (Platform.isAndroid || Platform.isIOS),
		userId = userId ?? (const Uuid()).v4(),
		contentSettings = contentSettings ?? getDefaultContentSettings(),
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
		deprecatedEmbedRegexes = deprecatedEmbedRegexes ?? const [],
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
		watchedThreadsSortingMethod = watchedThreadsSortingMethod ?? ThreadSortingMethod.savedTime,
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
		hiddenImageMD5s = hiddenImageMD5s ?? {},
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
		recentWebImageSearches = recentWebImageSearches ?? [],
		cloverStyleRepliesButton = cloverStyleRepliesButton ?? false,
		watchThreadAutomaticallyWhenReplying = watchThreadAutomaticallyWhenReplying ?? true,
		saveThreadAutomaticallyWhenReplying = saveThreadAutomaticallyWhenReplying ?? false,
		cancellableRepliesSlideGesture = cancellableRepliesSlideGesture ?? true,
		openBoardSwitcherSlideGesture = openBoardSwitcherSlideGesture ?? true,
		persistentDrawer = persistentDrawer ?? false,
		showGalleryGridButton = showGalleryGridButton ?? false,
		centeredPostThumbnailSize = centeredPostThumbnailSize ?? -300,
		ellipsizeLongFilenamesOnPosts = ellipsizeLongFilenamesOnPosts ?? true,
		muteAudioWhenOpeningGallery = muteAudioWhenOpeningGallery ?? switch (deprecatedAlwaysStartVideosMuted) {
			true => TristateSystemSetting.b,
			false || null => TristateSystemSetting.a
		},
		translationTargetLanguage = translationTargetLanguage ?? 'en',
		homeBoardName = homeBoardName ?? '',
		tapPostIdToReply = tapPostIdToReply ?? true,
		downloadUsingServerSideFilenames = downloadUsingServerSideFilenames ?? false,
		catalogGridModeTextScale = catalogGridModeTextScale ?? 1.0,
		catalogGridModeCropThumbnails = catalogGridModeCropThumbnails ?? true,
		useSpamFilterWorkarounds = useSpamFilterWorkarounds ?? true,
		scrollbarThickness = scrollbarThickness ?? 6,
		thumbnailPixelation = thumbnailPixelation ?? -12,
		catalogGridModeTextAboveAttachment = catalogGridModeTextAboveAttachment ?? false,
		swipeGesturesOnBottomBar = swipeGesturesOnBottomBar ?? true,
		mpvOptions = mpvOptions ?? {},
		dynamicIPKeepAlivePeriodSeconds = dynamicIPKeepAlivePeriodSeconds ?? -15,
		postingRegretDelaySeconds = postingRegretDelaySeconds ?? -10,
		showHiddenItemsFooter = showHiddenItemsFooter ?? true,
		attachmentsPageUsePageView = attachmentsPageUsePageView ?? false,
		showReplyCountInCatalog = showReplyCountInCatalog ?? true,
		watchThreadAutomaticallyWhenCreating = watchThreadAutomaticallyWhenCreating ?? true,
		imageMetaFilterDepth = imageMetaFilterDepth ?? 0,
		useStaggeredCatalogGrid = useStaggeredCatalogGrid ?? false {
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
			if (Platform.isAndroid && !getAppropriateUserAgents().contains(this.userAgent) && this.contentSettings.siteKeys.contains('4chan')) {
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
		if (name.endsWith('.ttf') || name.endsWith('.otf')) {
			name = name.substring(0, name.length - 4);
		}
		return allowedGoogleFonts[name]?.call() ?? TextStyle(
			fontFamily: name
		);
	}
}

abstract class MutableSetting<T> {
	const MutableSetting();
	T read(BuildContext context);
	T watch(BuildContext context);
	T get(BuildContext context, listen) => listen ? watch(context) : read(context);
	Future<void> didMutate(BuildContext context);
	Future<void> Function() makeDidMutate(BuildContext context) => () => didMutate(context);
	List<String> get syncPaths;
}

class MutableSavedSetting<T> extends MutableSetting<T> {
	final FieldReader<SavedSettings, T> setting;
	const MutableSavedSetting(this.setting);

	T call(Settings settings) => setting.getter(settings.settings);

	@override
	T read(BuildContext context) => this(Settings.instance);

	@override
	T watch(BuildContext context) => context.select<Settings, T>(this);

	@override
	Future<void> didMutate(BuildContext context) => Settings.instance.didEdit();

	@override
	List<String> get syncPaths => [setting.fieldName];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is MutableSavedSetting &&
		other.setting == setting;

	@override
	int get hashCode => setting.hashCode;
}

abstract class ImmutableSetting<T> extends MutableSetting<T> {
	const ImmutableSetting();
	@override
	Future<void> didMutate(BuildContext context) => write(context, read(context));
	Future<void> write(BuildContext context, T value);
	Future<void> Function(T) makeWriter(BuildContext context) => (T value) => write(context, value);
	Future<T> edit(BuildContext context, T Function(T) editor) async {
		final value = editor(read(context));
		await write(context, value);
		return value;
	}
}

class CustomMutableSetting<T> extends MutableSetting<T> {
	final T Function(BuildContext) reader;
	final T Function(BuildContext)? watcher;
	final Future<void> Function(BuildContext) didMutater;

	const CustomMutableSetting({
		required this.reader,
		required this.didMutater,
		this.watcher
	});

	@override
	T read(BuildContext context) => reader(context);

	@override
	T watch(BuildContext context) => (watcher ?? reader).call(context);

	@override
	Future<void> didMutate(BuildContext context) => didMutater(context);

	@override
	List<String> get syncPaths => const [];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CustomMutableSetting &&
		other.reader == reader &&
		other.watcher == watcher &&
		other.didMutater == didMutater;

	@override
	int get hashCode => Object.hash(reader, watcher, didMutater);
}

class CustomImmutableSetting<T> extends ImmutableSetting<T> {
	final T Function(BuildContext) reader;
	final T Function(BuildContext)? watcher;
	final Future<void> Function(BuildContext, T) writer;

	const CustomImmutableSetting({
		required this.reader,
		required this.watcher,
		required this.writer
	});

	@override
	T read(BuildContext context) => reader(context);

	@override
	T watch(BuildContext context) => (watcher ?? reader).call(context);

	@override
	Future<void> write(BuildContext context, T value) => writer(context, value);

	@override
	List<String> get syncPaths => const [];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CustomImmutableSetting &&
		other.reader == reader &&
		other.watcher == watcher &&
		other.writer == writer;

	@override
	int get hashCode => Object.hash(reader, watcher, writer);
}

class SavedSetting<T> extends ImmutableSetting<T> {
	final FieldWriter<SavedSettings, T> setting;
	const SavedSetting(this.setting);

	T call(Settings settings) => setting.getter(settings.settings);
	Future<void> set(Settings settings, T value) async {
		setting.setter(settings.settings, value);
		await settings.didEdit();
	}
	T get value => this(Settings.instance);
	set value(T newValue) => set(Settings.instance, newValue);

	@override
	T read(BuildContext context) => this(Settings.instance);
	@override
	T watch(BuildContext context) => context.select<Settings, T>(this);
	@override
	Future<void> write(BuildContext context, T value) => set(Settings.instance, value);

	@override
	List<String> get syncPaths => [setting.fieldName];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SavedSetting &&
		other.setting == setting;
	
	@override
	int get hashCode => setting.hashCode;
}

class SavedSettingEquals<T> extends MutableSetting<bool> {
	final FieldAdapter<SavedSettings, T> setting;
	final T value;
	const SavedSettingEquals(this.setting, this.value);

	@override
	bool read(BuildContext context) => setting.getter(Settings.instance.settings) == value;

	@override
	bool watch(BuildContext context) => context.select<Settings, T>((s) => setting.getter(s.settings)) == value;

	@override
	/// This should never be called...
	Future<void> didMutate(BuildContext context) => Settings.instance.didEdit();

	@override
	List<String> get syncPaths => [setting.fieldName];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SavedSettingEquals &&
		other.setting == setting &&
		other.value == value;
	
	@override
	int get hashCode => Object.hash(setting, value);
}

class FieldMappers {
	static bool invert(bool x) => !x;
	static NullSafeOptional nullSafeOptionalify<T>(bool? x) => x.value;
	static bool? unNullSafeOptionalify<T>(NullSafeOptional x) => x.value;
	static int toInt(double x) => x.toInt();
	static double toDouble(int x) => x.toDouble();
	static double doubleAbs(double x) => x.abs();
	static int intAbs(int x) => x.abs();
	static double toDoubleAbs(int x) => x.abs().toDouble();
	static int toIntAbs(double x) => x.abs().toInt();
}

class MappedSetting<T, New> extends ImmutableSetting<New> {
	final ImmutableSetting<T> setting;
	final New Function(T) forwards;
	final T Function(New) reverse;
	const MappedSetting(this.setting, this.forwards, this.reverse);

	@override
	New read(BuildContext context) => forwards(setting.read(context));

	@override
	New watch(BuildContext context) => forwards(setting.watch(context));

	@override
	Future<void> write(BuildContext context, New value) => setting.write(context, reverse(value));

	@override
	List<String> get syncPaths => setting.syncPaths;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is MappedSetting &&
		other.setting == setting &&
		other.forwards == forwards &&
		other.reverse == reverse;
	
	@override
	int get hashCode => Object.hash(setting, forwards, reverse);
}

class MappedMutableSetting<T, New> extends MutableSetting<New> {
	final MutableSetting<T> setting;
	final New Function(T) forwards;
	const MappedMutableSetting(this.setting, this.forwards);

	@override
	New read(BuildContext context) => forwards(setting.read(context));

	@override
	New watch(BuildContext context) => forwards(setting.watch(context));

	@override
	Future<void> didMutate(BuildContext context) => setting.didMutate(context);

	@override
	List<String> get syncPaths => setting.syncPaths;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is MappedMutableSetting &&
		other.setting == setting &&
		other.forwards == forwards;
	
	@override
	int get hashCode => Object.hash(setting, forwards);
}

class CombinedSetting<T1, T2> extends ImmutableSetting<(T1, T2)> {
	final ImmutableSetting<T1> setting1;
	final ImmutableSetting<T2> setting2;
	const CombinedSetting(this.setting1, this.setting2);

	@override
	(T1, T2) read(BuildContext context) => (setting1.read(context), setting2.read(context));

	@override
	(T1, T2) watch(BuildContext context) => (setting1.watch(context), setting2.watch(context));

	@override
	Future<void> write(BuildContext context, (T1, T2) value) => Future.wait([
		setting1.write(context, value.$1),
		setting2.write(context, value.$2)
	]);

	@override
	List<String> get syncPaths => [
		...setting1.syncPaths,
		...setting2.syncPaths
	];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CombinedSetting &&
		other.setting1 == setting1 &&
		other.setting2 == setting2;
	
	@override
	int get hashCode => Object.hash(setting1, setting2);
}

class CombinedMutableSetting<T1, T2> extends MutableSetting<(T1, T2)> {
	final MutableSetting<T1> setting1;
	final MutableSetting<T2> setting2;
	const CombinedMutableSetting(this.setting1, this.setting2);

	@override
	(T1, T2) read(BuildContext context) => (setting1.read(context), setting2.read(context));

	@override
	(T1, T2) watch(BuildContext context) => (setting1.watch(context), setting2.watch(context));

	@override
	Future<void> didMutate(BuildContext context) => Future.wait([
		setting1.didMutate(context),
		setting2.didMutate(context)
	]);

	@override
	List<String> get syncPaths => [
		...setting1.syncPaths,
		...setting2.syncPaths
	];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is CombinedMutableSetting &&
		other.setting1 == setting1 &&
		other.setting2 == setting2;
	
	@override
	int get hashCode => Object.hash(setting1, setting2);
}

class SettingWithFallback<T> extends ImmutableSetting<T> {
	final ImmutableSetting<T?> setting;
	final T fallback;
	const SettingWithFallback(this.setting, this.fallback);

	@override
	T read(BuildContext context) => setting.read(context) ?? fallback;

	@override
	T watch(BuildContext context) => setting.watch(context) ?? fallback;

	@override
	Future<void> write(BuildContext context, T value) => setting.write(context, value);

	@override
	List<String> get syncPaths => setting.syncPaths;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is SettingWithFallback &&
		other.setting == setting &&
		other.fallback == fallback;

	@override
	int get hashCode => Object.hash(setting, fallback);
}

class HookedSetting<T> extends ImmutableSetting<T> {
	final ImmutableSetting<T> setting;
	final Future<bool> Function(BuildContext context, T oldValue, T newValue)? beforeChange;
	final VoidCallback? afterChange;

	const HookedSetting({
		required this.setting,
		this.beforeChange,
		this.afterChange
	});

	@override
	T read(BuildContext context) => setting.read(context);

	@override
	T watch(BuildContext context) => setting.watch(context);

	@override
	Future<void> write(BuildContext context, T value) async {
		if ((await beforeChange?.call(context, read(context), value) ?? true) && context.mounted) {
			await setting.write(context, value);
			afterChange?.call();
		}
	}

	@override
	List<String> get syncPaths => setting.syncPaths;

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is HookedSetting &&
		other.setting == setting &&
		other.beforeChange == beforeChange;
	
	@override
	int get hashCode => Object.hash(setting, beforeChange);
}

class AssociatedSetting<Old, Associated, New> extends ImmutableSetting<New> {
	final ImmutableSetting<Old> setting;
	final MutableSetting<Associated> associated;
	final New Function(Old, Associated) forwards;
	final Old Function(New, Associated) reverse;
	const AssociatedSetting({
		required this.setting,
		required this.associated,
		required this.forwards,
		required this.reverse
	});

	@override
	New read(BuildContext context) => forwards(setting.read(context), associated.read(context));

	@override
	New watch(BuildContext context) => forwards(setting.watch(context), associated.watch(context));

	@override
	Future<void> write(BuildContext context, New value) => setting.write(context, reverse(value, associated.read(context)));

	@override
	List<String> get syncPaths => [
		...setting.syncPaths,
		...associated.syncPaths
	];

	@override
	bool operator == (Object other) =>
		identical(this, other) ||
		other is AssociatedSetting &&
		other.setting == setting &&
		other.associated == associated &&
		other.forwards == forwards &&
		other.reverse == reverse;
	
	@override
	int get hashCode => Object.hash(setting, associated, forwards, reverse);
}


class Settings extends ChangeNotifier {
	static Settings? _instance;
	static Settings get instance => _instance ??= Settings._();
	
	static SavedSettings get _settings => Persistence.settings;
	SavedSettings get settings => _settings;

	final client = Dio();
	ConnectivityResult? _connectivity;
	ConnectivityResult? get connectivity {
		return _connectivity;
	}
	set connectivity(ConnectivityResult? newConnectivity) {
		if (_connectivity == ConnectivityResult.none) {
			// Network coming up
			ImageboardRegistry.instance.retryFailedBoardSetup();
			_runNetworkResumeCallbacks();
		}
		_connectivity = newConnectivity;
		notifyListeners();
	}
	bool get isNetworkDown => _connectivity == ConnectivityResult.none;
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
	static const autoloadAttachmentsSetting = SavedSetting(SavedSettingsFields.autoloadAttachments);
	bool get autoloadAttachments {
		return (_settings.autoloadAttachments == AutoloadAttachmentsSetting.always) ||
			((_settings.autoloadAttachments == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}
	static const themeSetting = SavedSetting(SavedSettingsFields.theme);
	Brightness get whichTheme {
		if (_settings.theme == TristateSystemSetting.b) {
			return Brightness.dark;
		}
		else if (_settings.theme == TristateSystemSetting.a) {
			return Brightness.light;
		}
		return _systemBrightness ?? PlatformDispatcher.instance.platformBrightness;
	}

	static const hideOldStickiedThreadsSetting = SavedSetting(SavedSettingsFields.hideOldStickiedThreads);
	bool get hideOldStickiedThreads => hideOldStickiedThreadsSetting(this);

	static const savedThreadsSortingMethodSetting = SavedSetting(SavedSettingsFields.savedThreadsSortingMethod);
	ThreadSortingMethod get savedThreadsSortingMethod => savedThreadsSortingMethodSetting(this);
	static const autoRotateInGallerySetting = SavedSetting(SavedSettingsFields.autoRotateInGallery);
	bool get autoRotateInGallery => autoRotateInGallerySetting(this);
	ContentSettings get contentSettings => _settings.contentSettings;


	void addSiteKey(String siteKey) {
		if (!(JsonCache.instance.sites.value ?? {}).containsKey(siteKey)) {
			throw Exception('No such site: "$siteKey"');
		}
		settings.contentSettings.siteKeys.add(siteKey);
		didEdit();
	}

	void removeSiteKey(String siteKey) {
		settings.contentSettings.siteKeys.remove(siteKey);
		didEdit();
	}

	List<RegExp> embedRegexes = [];
	void _onEmbedRegexesUpdate() {
		try {
			embedRegexes = JsonCache.instance.embedRegexes.value?.map((x) => RegExp(x)).toList() ?? embedRegexes;
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
	FilterCache<FilterGroup<CustomFilter>> _filter = FilterCache(FilterGroup([]));
	Iterable<CustomFilter> get customFilterLines => _filter.wrappedFilter.filters;
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
	static const filterConfigurationSetting = SavedSetting(SavedSettingsFields.filterConfiguration);
	String get filterConfiguration => filterConfigurationSetting(this);
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

	static const twoPaneBreakpointSetting = SavedSetting(SavedSettingsFields.twoPaneBreakpoint);
	double get twoPaneBreakpoint => twoPaneBreakpointSetting(this);

	static const twoPaneSplitSetting = SavedSetting(SavedSettingsFields.twoPaneSplit);
	int get twoPaneSplit => twoPaneSplitSetting(this);

	static const useCatalogGridSetting = SavedSetting(SavedSettingsFields.useCatalogGrid);
	bool get useCatalogGrid => useCatalogGridSetting(this);

	static const catalogGridWidthSetting = SavedSetting(SavedSettingsFields.catalogGridWidth);
	double get catalogGridWidth => catalogGridWidthSetting(this);

	static const catalogGridHeightSetting = SavedSetting(SavedSettingsFields.catalogGridHeight);
	double get catalogGridHeight => catalogGridHeightSetting(this);

	static const showImageCountInCatalogSetting = SavedSetting(SavedSettingsFields.showImageCountInCatalog);
	bool get showImageCountInCatalog => showImageCountInCatalogSetting(this);

	static const showClockIconInCatalogSetting = SavedSetting(SavedSettingsFields.showClockIconInCatalog);
	bool get showClockIconInCatalog => showClockIconInCatalogSetting(this);

	static const supportMouseSetting = SavedSetting(SavedSettingsFields.supportMouse);
	TristateSystemSetting get supportMouse => supportMouseSetting(this);

	static const interfaceScaleSetting = SavedSetting(SavedSettingsFields.interfaceScale);
	double get interfaceScale => interfaceScaleSetting(this);

	static const showNameInCatalogSetting = SavedSetting(SavedSettingsFields.showNameInCatalog);
	bool get showNameInCatalog => showNameInCatalogSetting(this);

	static const showAnimationsSetting = SavedSetting(SavedSettingsFields.showAnimations);
	bool get showAnimations => showAnimationsSetting(this);

	static const imagesOnRightSetting = SavedSetting(SavedSettingsFields.imagesOnRight);
	bool get imagesOnRight => imagesOnRightSetting(this);
	static const androidGallerySavePathSetting = SavedSetting(SavedSettingsFields.androidGallerySavePath);
	String? get androidGallerySavePath => androidGallerySavePathSetting(this);

	double get replyBoxHeightOffset => _settings.replyBoxHeightOffset;
	set replyBoxHeightOffset(double setting) {
		_settings.replyBoxHeightOffset = setting;
	}
	void finalizeReplyBoxHeightOffset() {
		_settings.save();
		notifyListeners();
	}

	static const blurThumbnailsSetting = SavedSetting(SavedSettingsFields.blurThumbnails);
	bool get blurThumbnails => blurThumbnailsSetting(this);

	static const showTimeInCatalogHeaderSetting = SavedSetting(SavedSettingsFields.showTimeInCatalogHeader);
	bool get showTimeInCatalogHeader => showTimeInCatalogHeaderSetting(this);

	static const showTimeInCatalogStatsSetting = SavedSetting(SavedSettingsFields.showTimeInCatalogStats);
	bool get showTimeInCatalogStats => showTimeInCatalogStatsSetting(this);

	static const showIdInCatalogHeaderSetting = SavedSetting(SavedSettingsFields.showIdInCatalogHeader);
	bool get showIdInCatalogHeader => showIdInCatalogHeaderSetting(this);

	static const showFlagInCatalogHeaderSetting = SavedSetting(SavedSettingsFields.showFlagInCatalogHeader);
	bool get showFlagInCatalogHeader => showFlagInCatalogHeaderSetting(this);

	static const showCountryNameInCatalogHeaderSetting = SavedSetting(SavedSettingsFields.showCountryNameInCatalogHeader);
	bool get showCountryNameInCatalogHeader => showCountryNameInCatalogHeaderSetting(this);

	static const onlyShowFavouriteBoardsInSwitcherSetting = SavedSetting(SavedSettingsFields.onlyShowFavouriteBoardsInSwitcher);
	bool get onlyShowFavouriteBoardsInSwitcher => onlyShowFavouriteBoardsInSwitcherSetting(this);

	static const useBoardSwitcherListSetting = SavedSetting(SavedSettingsFields.useBoardSwitcherList);
	bool get useBoardSwitcherList => useBoardSwitcherListSetting(this);

	static const contributeCaptchasSetting = SavedSetting(SavedSettingsFields.contributeCaptchas);
	bool? get contributeCaptchas => contributeCaptchasSetting(this);

	static const showReplyCountsInGallerySetting = SavedSetting(SavedSettingsFields.showReplyCountsInGallery);
	bool get showReplyCountsInGallery => showReplyCountsInGallerySetting(this);

	static const useNewCaptchaFormSetting = SavedSetting(SavedSettingsFields.useNewCaptchaForm);
	bool get useNewCaptchaForm => useNewCaptchaFormSetting(this);

	static const autoLoginOnMobileNetworkSetting = SavedSetting(SavedSettingsFields.autoLoginOnMobileNetwork);
	bool? get autoLoginOnMobileNetwork => autoLoginOnMobileNetworkSetting(this);

	static const showScrollbarsSetting = SavedSetting(SavedSettingsFields.showScrollbars);
	bool get showScrollbars => showScrollbarsSetting(this);

	static const randomizeFilenamesSetting = SavedSetting(SavedSettingsFields.randomizeFilenames);
	bool get randomizeFilenames => randomizeFilenamesSetting(this);

	static const showNameOnPostsSetting = SavedSetting(SavedSettingsFields.showNameOnPosts);
	bool get showNameOnPosts => showNameOnPostsSetting(this);

	static const showTripOnPostsSetting = SavedSetting(SavedSettingsFields.showTripOnPosts);
	bool get showTripOnPosts => showTripOnPostsSetting(this);

	static const showAbsoluteTimeOnPostsSetting = SavedSetting(SavedSettingsFields.showAbsoluteTimeOnPosts);
	bool get showAbsoluteTimeOnPosts => showAbsoluteTimeOnPostsSetting(this);

	static const showRelativeTimeOnPostsSetting = SavedSetting(SavedSettingsFields.showRelativeTimeOnPosts);
	bool get showRelativeTimeOnPosts => showRelativeTimeOnPostsSetting(this);

	static const showCountryNameOnPostsSetting = SavedSetting(SavedSettingsFields.showCountryNameOnPosts);
	bool get showCountryNameOnPosts => showCountryNameOnPostsSetting(this);

	static const showPassOnPostsSetting = SavedSetting(SavedSettingsFields.showPassOnPosts);
	bool get showPassOnPosts => showPassOnPostsSetting(this);

	static const showFilenameOnPostsSetting = SavedSetting(SavedSettingsFields.showFilenameOnPosts);
	bool get showFilenameOnPosts => showFilenameOnPostsSetting(this);

	static const showFilesizeOnPostsSetting = SavedSetting(SavedSettingsFields.showFilesizeOnPosts);
	bool get showFilesizeOnPosts => showFilesizeOnPostsSetting(this);

	static const showFileDimensionsOnPostsSetting = SavedSetting(SavedSettingsFields.showFileDimensionsOnPosts);
	bool get showFileDimensionsOnPosts => showFileDimensionsOnPostsSetting(this);

	static const showFlagOnPostsSetting = SavedSetting(SavedSettingsFields.showFlagOnPosts);
	bool get showFlagOnPosts => showFlagOnPostsSetting(this);

	static const thumbnailSizeSetting = SavedSetting(SavedSettingsFields.thumbnailSize);
	double get thumbnailSize => thumbnailSizeSetting(this);

	final muteAudio = ValueNotifier<bool>(true);
	void setMuteAudio(bool setting) {
		_settings.muteAudio = setting;
		_settings.save();
		muteAudio.value = setting;
	}
	
	static const usePushNotificationsSetting = SavedSetting(SavedSettingsFields.usePushNotifications);
	bool? get usePushNotifications => usePushNotificationsSetting(this);
	set usePushNotifications(bool? setting) {
		_settings.usePushNotifications = setting;
		_settings.save();
		notifyListeners();
		Notifications.didUpdateUsePushNotificationsSetting();
	}

	static const useEmbedsSetting = SavedSetting(SavedSettingsFields.useEmbeds);
	bool get useEmbeds => useEmbedsSetting(this);
	static const useInternalBrowserSetting = SavedSetting(SavedSettingsFields.useInternalBrowser);
	bool? get useInternalBrowser => useInternalBrowserSetting(this);
	static const automaticCacheClearDaysSetting = SavedSetting(SavedSettingsFields.automaticCacheClearDays);
	int get automaticCacheClearDays => automaticCacheClearDaysSetting(this);
	static const alwaysAutoloadTappedAttachmentSetting = SavedSetting(SavedSettingsFields.alwaysAutoloadTappedAttachment);
	bool get alwaysAutoloadTappedAttachment => alwaysAutoloadTappedAttachmentSetting(this);
	static const postDisplayFieldOrderSetting = SavedSetting(SavedSettingsFields.postDisplayFieldOrder);
	List<PostDisplayField> get postDisplayFieldOrder => postDisplayFieldOrderSetting(this);
	static const maximumImageUploadDimensionSetting = SavedSetting(SavedSettingsFields.maximumImageUploadDimension);
	int? get maximumImageUploadDimension => maximumImageUploadDimensionSetting(this);
	static const hideDefaultNamesOnPostsSetting = SavedSetting(SavedSettingsFields.hideDefaultNamesOnPosts);
	bool get hideDefaultNamesOnPosts => hideDefaultNamesOnPostsSetting(this);
	static const showThumbnailsInGallerySetting = SavedSetting(SavedSettingsFields.showThumbnailsInGallery);
	bool get showThumbnailsInGallery => showThumbnailsInGallerySetting(this);
	static const watchedThreadsSortingMethodSetting = SavedSetting(SavedSettingsFields.watchedThreadsSortingMethod);
	ThreadSortingMethod get watchedThreadsSortingMethod => watchedThreadsSortingMethodSetting(this);

	static const closeTabSwitcherAfterUseSetting = SavedSetting(SavedSettingsFields.closeTabSwitcherAfterUse);
	bool get closeTabSwitcherAfterUse => closeTabSwitcherAfterUseSetting(this);

	static const textScaleSetting = SavedSetting(SavedSettingsFields.textScale);
	double get textScale => textScaleSetting(this);

	static const catalogGridModeTextLinesLimitSetting = SavedSetting(SavedSettingsFields.catalogGridModeTextLinesLimit);
	int? get catalogGridModeTextLinesLimit => catalogGridModeTextLinesLimitSetting(this);

	static const catalogGridModeAttachmentInBackgroundSetting = SavedSetting(SavedSettingsFields.catalogGridModeAttachmentInBackground);
	bool get catalogGridModeAttachmentInBackground => catalogGridModeAttachmentInBackgroundSetting(this);

	static const maxCatalogRowHeightSetting = SavedSetting(SavedSettingsFields.maxCatalogRowHeight);
	double get maxCatalogRowHeight => maxCatalogRowHeightSetting(this);

	static const lightThemeKeySetting = SavedSetting(SavedSettingsFields.lightThemeKey);
	String get lightThemeKey => lightThemeKeySetting(this);
	static const darkThemeKeySetting = SavedSetting(SavedSettingsFields.darkThemeKey);
	String get darkThemeKey => darkThemeKeySetting(this);
	Map<String, SavedTheme> get themes => _settings.themes;

	static const hostsToOpenExternallySetting = SavedSetting(SavedSettingsFields.hostsToOpenExternally);
	List<String> get hostsToOpenExternally => hostsToOpenExternallySetting(this);
	void didUpdateHostsToOpenExternally() {
		_settings.save();
		notifyListeners();
	}

	static const useFullWidthForCatalogCountersSetting = SavedSetting(SavedSettingsFields.useFullWidthForCatalogCounters);
	bool get useFullWidthForCatalogCounters => useFullWidthForCatalogCountersSetting(this);

	static const allowSwipingInGallerySetting = SavedSetting(SavedSettingsFields.allowSwipingInGallery);
	bool get allowSwipingInGallery => allowSwipingInGallerySetting(this);

	static const settingsQuickActionSetting = SavedSetting(SavedSettingsFields.settingsQuickAction);
	SettingsQuickAction? get settingsQuickAction => settingsQuickActionSetting(this);

	static const useHapticFeedbackSetting = SavedSetting(SavedSettingsFields.useHapticFeedback);
	bool get useHapticFeedback => useHapticFeedbackSetting(this);

	static const promptedAboutCrashlyticsSetting = SavedSetting(SavedSettingsFields.promptedAboutCrashlytics);
	bool get promptedAboutCrashlytics => promptedAboutCrashlyticsSetting(this);

	static const webmTranscodingSetting = SavedSetting(SavedSettingsFields.webmTranscoding);
	WebmTranscodingSetting get webmTranscoding => webmTranscodingSetting(this);

	static const showListPositionIndicatorsOnLeftSetting = SavedSetting(SavedSettingsFields.showListPositionIndicatorsOnLeft);
	bool get showListPositionIndicatorsOnLeft => showListPositionIndicatorsOnLeftSetting(this);

	static const useStatusBarWorkaroundSetting = SavedSetting(SavedSettingsFields.useStatusBarWorkaround);
	bool? get useStatusBarWorkaround => useStatusBarWorkaroundSetting(this);

	static const enableIMEPersonalizedLearningSetting = SavedSetting(SavedSettingsFields.enableIMEPersonalizedLearning);
	bool get enableIMEPersonalizedLearning => enableIMEPersonalizedLearningSetting(this);

	static const catalogVariantSetting = SavedSetting(SavedSettingsFields.catalogVariant);
	CatalogVariant get catalogVariant => catalogVariantSetting(this);

	static const redditCatalogVariantSetting = SavedSetting(SavedSettingsFields.redditCatalogVariant);
	CatalogVariant get redditCatalogVariant => redditCatalogVariantSetting(this);

	static const dimReadThreadsSetting = SavedSetting(SavedSettingsFields.dimReadThreads);
	bool get dimReadThreads => dimReadThreadsSetting(this);

	static const hackerNewsCatalogVariantSetting = SavedSetting(SavedSettingsFields.hackerNewsCatalogVariant);
	CatalogVariant get hackerNewsCatalogVariant => hackerNewsCatalogVariantSetting(this);

	static const hideDefaultNamesInCatalogSetting = SavedSetting(SavedSettingsFields.hideDefaultNamesInCatalog);
	bool get hideDefaultNamesInCatalog => hideDefaultNamesInCatalogSetting(this);

	int get launchCount => _settings.launchCount;

	static const userAgentSetting = SavedSetting(SavedSettingsFields.userAgent);
	String get userAgent => userAgentSetting(this);

	static const captcha4ChanCustomNumLettersSetting = SavedSetting(SavedSettingsFields.captcha4ChanCustomNumLetters);
	int get captcha4ChanCustomNumLetters => captcha4ChanCustomNumLettersSetting(this);

	static const tabMenuHidesWhenScrollingDownSetting = SavedSetting(SavedSettingsFields.tabMenuHidesWhenScrollingDown);
	bool get tabMenuHidesWhenScrollingDown => tabMenuHidesWhenScrollingDownSetting(this);
	
	static const doubleTapScrollToRepliesSetting = SavedSetting(SavedSettingsFields.doubleTapScrollToReplies);
	bool get doubleTapScrollToReplies => doubleTapScrollToRepliesSetting(this);

	static const lastUnifiedPushEndpointSetting = SavedSetting(SavedSettingsFields.lastUnifiedPushEndpoint);
	String? get lastUnifiedPushEndpoint => lastUnifiedPushEndpointSetting(this);

	static const webImageSearchMethodSetting = SavedSetting(SavedSettingsFields.webImageSearchMethod);
	WebImageSearchMethod get webImageSearchMethod => webImageSearchMethodSetting(this);

	static const showIPNumberOnPostsSetting = SavedSetting(SavedSettingsFields.showIPNumberOnPosts);
	bool get showIPNumberOnPosts => showIPNumberOnPostsSetting(this);

	static const showNoBeforeIdOnPostsSetting = SavedSetting(SavedSettingsFields.showNoBeforeIdOnPosts);
	bool get showNoBeforeIdOnPosts => showNoBeforeIdOnPostsSetting(this);

	static const blurEffectsSetting = SavedSetting(SavedSettingsFields.blurEffects);
	bool get blurEffects => blurEffectsSetting(this);

	static const scrollbarsOnLeftSetting = SavedSetting(SavedSettingsFields.scrollbarsOnLeft);
	bool get scrollbarsOnLeft => scrollbarsOnLeftSetting(this);

	static const exactTimeIsTwelveHourSetting = SavedSetting(SavedSettingsFields.exactTimeIsTwelveHour);
	bool get exactTimeIsTwelveHour => exactTimeIsTwelveHourSetting(this);

	static const exactTimeShowsDateForTodaySetting = SavedSetting(SavedSettingsFields.exactTimeShowsDateForToday);
	bool get exactTimeShowsDateForToday => exactTimeShowsDateForTodaySetting(this);

	static const attachmentsPageMaxCrossAxisExtentSetting = SavedSetting(SavedSettingsFields.attachmentsPageMaxCrossAxisExtent);
	double get attachmentsPageMaxCrossAxisExtent => attachmentsPageMaxCrossAxisExtentSetting(this);

	static const catalogGridModeCellBorderRadiusAndMarginSetting = SavedSetting(SavedSettingsFields.catalogGridModeCellBorderRadiusAndMargin);
	bool get catalogGridModeCellBorderRadiusAndMargin => catalogGridModeCellBorderRadiusAndMarginSetting(this);

	static const catalogGridModeShowMoreImageIfLessTextSetting = SavedSetting(SavedSettingsFields.catalogGridModeShowMoreImageIfLessText);
	bool get catalogGridModeShowMoreImageIfLessText => catalogGridModeShowMoreImageIfLessTextSetting(this);

	static const showPostNumberOnPostsSetting = SavedSetting(SavedSettingsFields.showPostNumberOnPosts);
	bool get showPostNumberOnPosts => showPostNumberOnPostsSetting(this);

	static const overscrollModalTapPopsAllSetting = SavedSetting(SavedSettingsFields.overscrollModalTapPopsAll);
	bool get overscrollModalTapPopsAll => overscrollModalTapPopsAllSetting(this);

	static const squareThumbnailsSetting = SavedSetting(SavedSettingsFields.squareThumbnails);
	bool get squareThumbnails => squareThumbnailsSetting(this);
	
	static const alwaysShowSpoilersSetting = SavedSetting(SavedSettingsFields.alwaysShowSpoilers);
	bool get alwaysShowSpoilers => alwaysShowSpoilersSetting(this);

	static const gallerySavePathOrganizingSetting = SavedSetting(SavedSettingsFields.gallerySavePathOrganizing);
	GallerySavePathOrganizing get gallerySavePathOrganizing => gallerySavePathOrganizingSetting(this);

	static const fullQualityThumbnailsSettingSetting = SavedSetting(SavedSettingsFields.fullQualityThumbnails);
	AutoloadAttachmentsSetting get fullQualityThumbnailsSetting => fullQualityThumbnailsSettingSetting(this);
	bool get fullQualityThumbnails {
		return (fullQualityThumbnailsSetting == AutoloadAttachmentsSetting.always) ||
			((fullQualityThumbnailsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	static const recordThreadsInHistorySetting = SavedSetting(SavedSettingsFields.recordThreadsInHistory);
	bool get recordThreadsInHistory => recordThreadsInHistorySetting(this);

	static const fontFamilySetting = SavedSetting(SavedSettingsFields.fontFamily);
	String? get fontFamily => fontFamilySetting(this);

	static const autoCacheAttachmentsSettingSetting = SavedSetting(SavedSettingsFields.autoCacheAttachments);
	AutoloadAttachmentsSetting get autoCacheAttachmentsSetting => autoCacheAttachmentsSettingSetting(this);
	bool get autoCacheAttachments {
		return (autoCacheAttachmentsSetting == AutoloadAttachmentsSetting.always) ||
			((autoCacheAttachmentsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	static const exactTimeUsesCustomDateFormatSetting = SavedSetting(SavedSettingsFields.exactTimeUsesCustomDateFormat);
	bool get exactTimeUsesCustomDateFormat => exactTimeUsesCustomDateFormatSetting(this);

	static const showOverlaysInGallerySetting = SavedSetting(SavedSettingsFields.showOverlaysInGallery);
	bool get showOverlaysInGallery => showOverlaysInGallerySetting(this);

	static const verticalTwoPaneMinimumPaneSizeSetting = SavedSetting(SavedSettingsFields.verticalTwoPaneMinimumPaneSize);
	double get verticalTwoPaneMinimumPaneSize => verticalTwoPaneMinimumPaneSizeSetting(this);

	static const showLastRepliesInCatalogSetting = SavedSetting(SavedSettingsFields.showLastRepliesInCatalog);
	bool get showLastRepliesInCatalog => showLastRepliesInCatalogSetting(this);

	static const loadThumbnailsSettingSetting = SavedSetting(SavedSettingsFields.loadThumbnails);
	AutoloadAttachmentsSetting get loadThumbnailsSetting => loadThumbnailsSettingSetting(this);
	bool get loadThumbnails {
		return (loadThumbnailsSetting == AutoloadAttachmentsSetting.always) ||
			((loadThumbnailsSetting == AutoloadAttachmentsSetting.wifi) && isConnectedToWifi);
	}

	static const applyImageFilterToThreadsSetting = SavedSetting(SavedSettingsFields.applyImageFilterToThreads);
	bool get applyImageFilterToThreads => applyImageFilterToThreadsSetting(this);

	static const askForAuthenticationOnLaunchSetting = SavedSetting(SavedSettingsFields.askForAuthenticationOnLaunch);
	bool get askForAuthenticationOnLaunch => askForAuthenticationOnLaunchSetting(this);

	static const enableSpellCheckSetting = SavedSetting(SavedSettingsFields.enableSpellCheck);
	bool get enableSpellCheck => enableSpellCheckSetting(this);

	static const openCrossThreadLinksInNewTabSetting = SavedSetting(SavedSettingsFields.openCrossThreadLinksInNewTab);
	bool get openCrossThreadLinksInNewTab => openCrossThreadLinksInNewTabSetting(this);

	static const backgroundThreadAutoUpdatePeriodSecondsSetting = SavedSetting(SavedSettingsFields.backgroundThreadAutoUpdatePeriodSeconds);
	int get backgroundThreadAutoUpdatePeriodSeconds => backgroundThreadAutoUpdatePeriodSecondsSetting(this);

	static const currentThreadAutoUpdatePeriodSecondsSetting = SavedSetting(SavedSettingsFields.currentThreadAutoUpdatePeriodSeconds);
	int get currentThreadAutoUpdatePeriodSeconds => currentThreadAutoUpdatePeriodSecondsSetting(this);

	static const lastShareablePostsStyleSetting = SavedSetting(SavedSettingsFields.lastShareablePostsStyle);
	ShareablePostsStyle get lastShareablePostsStyle => lastShareablePostsStyleSetting(this);

	static const defaultThreadWatchSetting = SavedSetting(SavedSettingsFields.defaultThreadWatch);
	ThreadWatch? get defaultThreadWatch => defaultThreadWatchSetting(this);

	static const highlightRepeatingDigitsInPostIdsSetting = SavedSetting(SavedSettingsFields.highlightRepeatingDigitsInPostIds);
	bool get highlightRepeatingDigitsInPostIds => highlightRepeatingDigitsInPostIdsSetting(this);

	static const includeThreadsYouRepliedToWhenDeletingHistorySetting = SavedSetting(SavedSettingsFields.includeThreadsYouRepliedToWhenDeletingHistory);
	bool get includeThreadsYouRepliedToWhenDeletingHistory => includeThreadsYouRepliedToWhenDeletingHistorySetting(this);

	static const newPostHighlightBrightnessSetting = SavedSetting(SavedSettingsFields.newPostHighlightBrightness);
	double get newPostHighlightBrightness => newPostHighlightBrightnessSetting(this);

	static const imagePeekingSetting = SavedSetting(SavedSettingsFields.imagePeeking);
	ImagePeekingSetting get imagePeeking => imagePeekingSetting(this);

	static const _useMaterialStyleSetting = SavedSetting(SavedSettingsFields.useMaterialStyle);
	static final materialStyleSetting = SettingWithFallback(_useMaterialStyleSetting, platformIsMaterial);
	bool get materialStyle => _useMaterialStyleSetting(this) ?? materialStyleSetting.fallback;

	static const _useAndroidDrawerSetting = SavedSetting(SavedSettingsFields.useAndroidDrawer);
	static final androidDrawerSetting = SettingWithFallback(_useAndroidDrawerSetting, platformIsMaterial);
	bool get androidDrawer => _useAndroidDrawerSetting(this) ?? androidDrawerSetting.fallback;

	static const _useMaterialRoutesSetting = SavedSetting(SavedSettingsFields.useMaterialRoutes);
	static const materialRoutesSetting = SettingWithFallback(_useMaterialRoutesSetting, false);
	bool get materialRoutes => _useMaterialRoutesSetting(this) ?? materialRoutesSetting.fallback;

	static const hideBarsWhenScrollingDownSetting = SavedSetting(SavedSettingsFields.hideBarsWhenScrollingDown);
	bool get hideBarsWhenScrollingDown => hideBarsWhenScrollingDownSetting(this);

	static const showPerformanceOverlaySetting = SavedSetting(SavedSettingsFields.showPerformanceOverlay);
	bool get showPerformanceOverlay => showPerformanceOverlaySetting(this);

	static const customDateFormatSetting = SavedSetting(SavedSettingsFields.customDateFormat);
	String get customDateFormat => customDateFormatSetting(this);

	static const hoverPopupDelayMillisecondsSetting = SavedSetting(SavedSettingsFields.hoverPopupDelayMilliseconds);
	int get hoverPopupDelayMilliseconds => hoverPopupDelayMillisecondsSetting(this);

	static const mouseModeQuoteLinkBehaviorSetting = SavedSetting(SavedSettingsFields.mouseModeQuoteLinkBehavior);
	MouseModeQuoteLinkBehavior get mouseModeQuoteLinkBehavior => mouseModeQuoteLinkBehaviorSetting(this);

	static const drawerModeSetting = SavedSetting(SavedSettingsFields.drawerMode);
	DrawerMode get drawerMode => drawerModeSetting(this);
	set drawerMode(DrawerMode setting) {
		_settings.drawerMode = setting;
		_settings.save();
		// Don't notify on purpose
	}

	static const showLineBreakInPostInfoRowSetting = SavedSetting(SavedSettingsFields.showLineBreakInPostInfoRow);
	bool get showLineBreakInPostInfoRow => showLineBreakInPostInfoRowSetting(this);

	static const useCloudCaptchaSolverSetting = SavedSetting(SavedSettingsFields.useCloudCaptchaSolver);
	bool? get useCloudCaptchaSolver => useCloudCaptchaSolverSetting(this);

	static const useHeadlessCloudCaptchaSolverSetting = SavedSetting(SavedSettingsFields.useHeadlessCloudCaptchaSolver);
	bool? get useHeadlessCloudCaptchaSolver => useHeadlessCloudCaptchaSolverSetting(this);

	static const removeMetadataOnUploadedFilesSetting = SavedSetting(SavedSettingsFields.removeMetadataOnUploadedFiles);
	bool get removeMetadataOnUploadedFiles => removeMetadataOnUploadedFilesSetting(this);

	static const randomizeChecksumOnUploadedFilesSetting = SavedSetting(SavedSettingsFields.randomizeChecksumOnUploadedFiles);
	bool get randomizeChecksumOnUploadedFiles => randomizeChecksumOnUploadedFilesSetting(this);

	static const cloverStyleRepliesButtonSetting = SavedSetting(SavedSettingsFields.cloverStyleRepliesButton);
	bool get cloverStyleRepliesButton => cloverStyleRepliesButtonSetting(this);

	static const watchThreadAutomaticallyWhenReplyingSetting = SavedSetting(SavedSettingsFields.watchThreadAutomaticallyWhenReplying);
	bool get watchThreadAutomaticallyWhenReplying => watchThreadAutomaticallyWhenReplyingSetting(this);

	static const saveThreadAutomaticallyWhenReplyingSetting = SavedSetting(SavedSettingsFields.saveThreadAutomaticallyWhenReplying);
	bool get saveThreadAutomaticallyWhenReplying => saveThreadAutomaticallyWhenReplyingSetting(this);

	static const cancellableRepliesSlideGestureSetting = SavedSetting(SavedSettingsFields.cancellableRepliesSlideGesture);
	bool get cancellableRepliesSlideGesture => cancellableRepliesSlideGestureSetting(this);

	static const openBoardSwitcherSlideGestureSetting = SavedSetting(SavedSettingsFields.openBoardSwitcherSlideGesture);
	bool get openBoardSwitcherSlideGesture => openBoardSwitcherSlideGestureSetting(this);

	static const persistentDrawerSetting = SavedSetting(SavedSettingsFields.persistentDrawer);
	bool get persistentDrawer => persistentDrawerSetting(this);

	static const showGalleryGridButtonSetting = SavedSetting(SavedSettingsFields.showGalleryGridButton);
	bool get showGalleryGridButton => showGalleryGridButtonSetting(this);

	double? get centeredPostThumbnailSize {
		if (_settings.centeredPostThumbnailSize <= 0) {
			return null;
		}
		return _settings.centeredPostThumbnailSize;
	}
	static const centeredPostThumbnailSizeSettingSetting = SavedSetting(SavedSettingsFields.centeredPostThumbnailSize);
	double get centeredPostThumbnailSizeSetting => centeredPostThumbnailSizeSettingSetting(this);

	static const ellipsizeLongFilenamesOnPostsSetting = SavedSetting(SavedSettingsFields.ellipsizeLongFilenamesOnPosts);
	bool get ellipsizeLongFilenamesOnPosts => ellipsizeLongFilenamesOnPostsSetting(this);

	static const muteAudioWhenOpeningGallerySetting = SavedSetting(SavedSettingsFields.muteAudioWhenOpeningGallery);
	TristateSystemSetting get muteAudioWhenOpeningGallery => muteAudioWhenOpeningGallerySetting(this);

	static const translationTargetLanguageSetting = SavedSetting(SavedSettingsFields.translationTargetLanguage);
	String get translationTargetLanguage => translationTargetLanguageSetting(this);

	static const homeImageboardKeySetting = SavedSetting(SavedSettingsFields.homeImageboardKey);
	String? get homeImageboardKey => homeImageboardKeySetting(this);
	Imageboard? get homeImageboard => ImageboardRegistry.instance.getImageboard(homeImageboardKey);
	static const homeBoardNameSetting = SavedSetting(SavedSettingsFields.homeBoardName);
	String get homeBoardName => homeBoardNameSetting(this);
	bool get usingHomeBoard => homeImageboardKey != null;

	static const tapPostIdToReplySetting = SavedSetting(SavedSettingsFields.tapPostIdToReply);
	bool get tapPostIdToReply => tapPostIdToReplySetting(this);

	static const downloadUsingServerSideFilenamesSetting = SavedSetting(SavedSettingsFields.downloadUsingServerSideFilenames);
	bool get downloadUsingServerSideFilenames => downloadUsingServerSideFilenamesSetting(this);

	static const catalogGridModeTextScaleSetting = SavedSetting(SavedSettingsFields.catalogGridModeTextScale);
	double get catalogGridModeTextScale => catalogGridModeTextScaleSetting(this);

	static const catalogGridModeCropThumbnailsSetting = SavedSetting(SavedSettingsFields.catalogGridModeCropThumbnails);
	bool get catalogGridModeCropThumbnails => catalogGridModeCropThumbnailsSetting(this);

	static const useSpamFilterWorkaroundsSetting = SavedSetting(SavedSettingsFields.useSpamFilterWorkarounds);
	bool get useSpamFilterWorkarounds => useSpamFilterWorkaroundsSetting(this);

	static const scrollbarThicknessSetting = SavedSetting(SavedSettingsFields.scrollbarThickness);
	double get scrollbarThickness => scrollbarThicknessSetting(this);

	static const thumbnailPixelationSetting = SavedSetting(SavedSettingsFields.thumbnailPixelation);
	int get thumbnailPixelation => thumbnailPixelationSetting(this);

	static const catalogGridModeTextAboveAttachmentSetting = SavedSetting(SavedSettingsFields.catalogGridModeTextAboveAttachment);
	bool get catalogGridModeTextAboveAttachment => catalogGridModeTextAboveAttachmentSetting(this);

	static const swipeGesturesOnBottomBarSetting = SavedSetting(SavedSettingsFields.swipeGesturesOnBottomBar);
	bool get swipeGesturesOnBottomBar => swipeGesturesOnBottomBarSetting(this);

	static const mpvOptionsSetting = SavedSetting(SavedSettingsFields.mpvOptions);
	Map<String, String> get mpvOptions => mpvOptionsSetting(this);

	static const dynamicIPKeepAlivePeriodSecondsSetting = SavedSetting(SavedSettingsFields.dynamicIPKeepAlivePeriodSeconds);
	int get dynamicIPKeepAlivePeriodSeconds => dynamicIPKeepAlivePeriodSecondsSetting(this);
	Duration? get dynamicIPKeepAlivePeriod {
		if (dynamicIPKeepAlivePeriodSeconds <= 0) {
			return null;
		}
		return Duration(seconds: dynamicIPKeepAlivePeriodSeconds);
	}

	static const postingRegretDelaySecondsSetting = SavedSetting(SavedSettingsFields.postingRegretDelaySeconds);
	int get postingRegretDelaySeconds => postingRegretDelaySecondsSetting(this);
	Duration get postingRegretDelay {
		if (postingRegretDelaySeconds <= 0) {
			return Duration.zero;
		}
		return Duration(seconds: postingRegretDelaySeconds);
	}

	static const showHiddenItemsFooterSetting = SavedSetting(SavedSettingsFields.showHiddenItemsFooter);
	bool get showHiddenItemsFooter => showHiddenItemsFooterSetting(this);

	static const attachmentsPageUsePageViewSetting = SavedSetting(SavedSettingsFields.attachmentsPageUsePageView);
	bool get attachmentsPageUsePageView => attachmentsPageUsePageViewSetting(this);

	static const showReplyCountInCatalogSetting = SavedSetting(SavedSettingsFields.showReplyCountInCatalog);
	bool get showReplyCountInCatalog => showReplyCountInCatalogSetting(this);

	static const watchThreadAutomaticallyWhenCreatingSetting = SavedSetting(SavedSettingsFields.watchThreadAutomaticallyWhenCreating);
	bool get watchThreadAutomaticallyWhenCreating => watchThreadAutomaticallyWhenCreatingSetting(this);

	static const imageMetaFilterDepthSetting = SavedSetting(SavedSettingsFields.imageMetaFilterDepth);
	int get imageMetaFilterDepth => imageMetaFilterDepthSetting(this);

	static const useStaggeredCatalogGridSetting = SavedSetting(SavedSettingsFields.useStaggeredCatalogGrid);
	bool get useStaggeredCatalogGrid => useStaggeredCatalogGridSetting(this);

	final List<VoidCallback> _appResumeCallbacks = [];
	void addAppResumeCallback(VoidCallback task) {
		_appResumeCallbacks.add(task);
	}
	void _runAppResumeCallbacks() {
		for (final task in _appResumeCallbacks) {
			Future.microtask(task);
		}
		_appResumeCallbacks.clear();
	}
	final List<VoidCallback> _networkResumeCallbacks = [];
	void addNetworkResumeCallback(VoidCallback task) {
		_networkResumeCallbacks.add(task);
	}
	void _runNetworkResumeCallbacks() {
		for (final task in _networkResumeCallbacks) {
			Future.microtask(task);
		}
		_networkResumeCallbacks.clear();
	}

	bool get isCrashlyticsCollectionEnabled => FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
	set isCrashlyticsCollectionEnabled(bool setting) => FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(setting).then((_) {
		notifyListeners();
	});

	bool areMD5sHidden(Iterable<String> md5s) {
		return md5s.any(_settings.hiddenImageMD5s.contains);
	}

	bool isMD5Hidden(String md5) {
		return _settings.hiddenImageMD5s.contains(md5);
	}

	late Filter imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads, imageMetaFilterDepth));
	void didUpdateImageFilter() {
		imageMD5Filter = FilterCache(MD5Filter(_settings.hiddenImageMD5s.toSet(), applyImageFilterToThreads, imageMetaFilterDepth));
		filterListenable.didUpdate();
		notifyListeners();
		_settings.save();
	}
	void hideByMD5(String md5) {
		_settings.hiddenImageMD5s.add(md5);
		didUpdateImageFilter();
	}

	void unHideByMD5(String md5) {
		_settings.hiddenImageMD5s.remove(md5);
		didUpdateImageFilter();
	}

	void unHideByMD5s(Iterable<String> md5s) {
		_settings.hiddenImageMD5s.removeAll(md5s);
		didUpdateImageFilter();
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
		didUpdateImageFilter();
	}

	Future<void> didEdit() async {
		notifyListeners();
		await _settings.save();
	}

	void runQuickAction(BuildContext context) {
		mediumHapticFeedback();
		switch (settingsQuickAction) {
			case SettingsQuickAction.toggleTheme:
				Settings.themeSetting.set(this, whichTheme == Brightness.light ? TristateSystemSetting.b : TristateSystemSetting.a);
				showToast(
					context: context,
					icon: CupertinoIcons.paintbrush,
					message: whichTheme == Brightness.light ? 'Switched to light theme' : 'Switched to dark theme'
				);
				break;
			case SettingsQuickAction.toggleBlurredThumbnails:
				blurThumbnailsSetting.value = !blurThumbnails;
				showToast(
					context: context,
					icon: CupertinoIcons.paintbrush,
					message: blurThumbnails ? 'Blurred thumbnails enabled' : 'Blurred thumbnails disabled'
				);
				break;
			case SettingsQuickAction.toggleCatalogLayout:
				useCatalogGridSetting.value = !useCatalogGrid;
				showToast(
					context: context,
					icon: CupertinoIcons.rectangle_stack,
					message: useCatalogGrid ? 'Switched to catalog grid' : 'Switched to catalog rows'
				);
				break;
			case SettingsQuickAction.toggleInterfaceStyle:
				final mouseSettings = context.read<MouseSettings>();
				supportMouseSetting.value = mouseSettings.supportMouse ? TristateSystemSetting.a : TristateSystemSetting.b;
				showToast(
					context: context,
					icon: mouseSettings.supportMouse ? Icons.mouse : CupertinoIcons.hand_draw,
					message: mouseSettings.supportMouse ? 'Switched to mouse layout' : 'Switched to touch layout'
				);
				break;
			case SettingsQuickAction.toggleListPositionIndicatorLocation:
				showListPositionIndicatorsOnLeftSetting.value = !showListPositionIndicatorsOnLeft;
				showToast(
					context: context,
					icon: showListPositionIndicatorsOnLeft ? CupertinoIcons.arrow_left_to_line : CupertinoIcons.arrow_right_to_line,
					message: showListPositionIndicatorsOnLeft ? 'Moved list position indicators to left' : 'Moved list position indicators to right'
				);
				break;
			case SettingsQuickAction.toggleVerticalTwoPaneSplit:
				verticalTwoPaneMinimumPaneSizeSetting.value = -1 * verticalTwoPaneMinimumPaneSize;
				showToast(
					context: context,
					icon: verticalTwoPaneMinimumPaneSize.isNegative ? CupertinoIcons.rectangle : CupertinoIcons.rectangle_grid_1x2,
					message: verticalTwoPaneMinimumPaneSize.isNegative ? 'Disabled vertical two-pane layout' : 'Enabled vertical two-pane layout'
				);
				break;
			case SettingsQuickAction.toggleImages:
				contentSettings.images = !contentSettings.images;
				didEdit();
				showToast(
					context: context,
					icon: contentSettings.images ? Adaptive.icons.photo : CupertinoIcons.xmark,
					message: contentSettings.images ? 'Enabled images' : 'Disabled images'
				);
				break;
			case SettingsQuickAction.togglePixelatedThumbnails:
				thumbnailPixelationSetting.value = -1 * thumbnailPixelation;
				didEdit();
				showToast(
					context: context,
					icon: thumbnailPixelation.isNegative ? Adaptive.icons.photo : CupertinoIcons.square,
					message: thumbnailPixelation.isNegative ? 'Disabled pixelated thumbnails' : 'Enabled pixelated thumbnails'
				);
				break;
			case null:
				break;
		}
	}

	static const featureStatusBarWorkaround = true;
	static const featureWebmTranscodingForPlayback = false;
	static const featureDumpData = false;

	late final MouseSettings mouseSettings;

	Settings._() {
		mouseSettings = MouseSettings._(this);
		client.interceptors.add(LoggingInterceptor.instance);
		client.interceptors.add(InterceptorsWrapper(
			onRequest: (options, handler) {
				options.headers[HttpHeaders.acceptEncodingHeader] ??= 'gzip';
				handler.next(options);
			}
		));
		muteAudio.value = _settings.muteAudio;
		_tryToSetupFilter();
		JsonCache.instance.embedRegexes.addListener(_onEmbedRegexesUpdate);
		_onEmbedRegexesUpdate(); // Set to initial value
	}
}

class MouseSettings extends ChangeNotifier {
	final Settings parent;
	bool get supportMouse => switch (_lastSupportMouseSetting) {
		TristateSystemSetting.a => false,
		TristateSystemSetting.system => _mouseConnected,
		TristateSystemSetting.b => true
	};
	late TristateSystemSetting _lastSupportMouseSetting;
	late bool _mouseConnected;
	set mouseConnected(bool newValue) {
		_mouseConnected = newValue;
		if (_lastSupportMouseSetting == TristateSystemSetting.system) {
			// Connection state change had an impact
			notifyListeners();
		}
	}

	MouseSettings._(this.parent) {
		_mouseConnected = false;
		_lastSupportMouseSetting = parent.supportMouse;
		parent.addListener(_settingsListener);
	}

	void _settingsListener() {
		if (parent.supportMouse != _lastSupportMouseSetting) {
			final lastSupportMouse = supportMouse;
			_lastSupportMouseSetting = parent.supportMouse;
			if (lastSupportMouse != supportMouse) {
				// Setting change had an impact
				notifyListeners();
			}
		}
	}

	@override
	void dispose() {
		super.dispose();
		parent.removeListener(_settingsListener);
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
			Settings.instance.connectivity = result;
		});
		if (isDesktop()) {
			Future.delayed(const Duration(milliseconds: 10), () {
				Settings.instance.connectivity = ConnectivityResult.wifi;
			});
		}
	}

	void _checkConnectivity() {
		Connectivity().checkConnectivity().then((result) {
			Settings.instance.connectivity = result;
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
			final settings = Settings.instance;
			settings._runAppResumeCallbacks();
			if (await updateDynamicColors()) {
				settings.handleThemesAltered();
			}
		}
	}

	@override
	void didChangePlatformBrightness() {
		Settings.instance.systemBrightness = PlatformDispatcher.instance.platformBrightness;
	}

	@override
	Widget build(BuildContext context) {
		return MouseRegion(
			onHover: (event) {
				if (event.kind != PointerDeviceKind.touch) {
					_mouseExitTimer?.cancel();
					Settings.instance.mouseSettings.mouseConnected = true;
					Settings.instance._runAppResumeCallbacks();
				}
			},
			onExit: (event) {
				_mouseExitTimer = Timer(_mouseStateChangeTimeout, () => Settings.instance.mouseSettings.mouseConnected = false);
			},
			opaque: false,
			child: ChangeNotifierProvider.value(
				value: Settings.instance.mouseSettings,
				child: widget.child
			)
		);
	}
}