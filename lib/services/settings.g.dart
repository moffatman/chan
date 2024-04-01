// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContentSettingsFields {
  static bool getImages(ContentSettings x) => x.images;
  static void setImages(ContentSettings x, bool v) => x.images = v;
  static const images = HiveFieldAdapter<ContentSettings, bool>(
    getter: getImages,
    setter: setImages,
    fieldNumber: 0,
    fieldName: 'images',
    merger: PrimitiveMerger(),
  );
  static bool getNsfwBoards(ContentSettings x) => x.nsfwBoards;
  static void setNsfwBoards(ContentSettings x, bool v) => x.nsfwBoards = v;
  static const nsfwBoards = HiveFieldAdapter<ContentSettings, bool>(
    getter: getNsfwBoards,
    setter: setNsfwBoards,
    fieldNumber: 1,
    fieldName: 'nsfwBoards',
    merger: PrimitiveMerger(),
  );
  static bool getNsfwImages(ContentSettings x) => x.nsfwImages;
  static void setNsfwImages(ContentSettings x, bool v) => x.nsfwImages = v;
  static const nsfwImages = HiveFieldAdapter<ContentSettings, bool>(
    getter: getNsfwImages,
    setter: setNsfwImages,
    fieldNumber: 2,
    fieldName: 'nsfwImages',
    merger: PrimitiveMerger(),
  );
  static bool getNsfwText(ContentSettings x) => x.nsfwText;
  static void setNsfwText(ContentSettings x, bool v) => x.nsfwText = v;
  static const nsfwText = HiveFieldAdapter<ContentSettings, bool>(
    getter: getNsfwText,
    setter: setNsfwText,
    fieldNumber: 3,
    fieldName: 'nsfwText',
    merger: PrimitiveMerger(),
  );
  static Set<String> getSiteKeys(ContentSettings x) => x.siteKeys;
  static void setSiteKeys(ContentSettings x, Set<String> v) => x.siteKeys = v;
  static const siteKeys = HiveFieldAdapter<ContentSettings, Set<String>>(
    getter: getSiteKeys,
    setter: setSiteKeys,
    fieldNumber: 6,
    fieldName: 'siteKeys',
    merger: SetMerger<String>(PrimitiveMerger()),
  );
}

class ContentSettingsAdapter extends TypeAdapter<ContentSettings> {
  const ContentSettingsAdapter();

  static const int kTypeId = 20;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ContentSettings, dynamic>> fields =
      const {
    0: ContentSettingsFields.images,
    1: ContentSettingsFields.nsfwBoards,
    2: ContentSettingsFields.nsfwImages,
    3: ContentSettingsFields.nsfwText,
    6: ContentSettingsFields.siteKeys
  };

  @override
  ContentSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContentSettings(
      images: fields[0] as bool,
      nsfwBoards: fields[1] as bool,
      nsfwImages: fields[2] as bool,
      nsfwText: fields[3] as bool,
      deprecatedSites: (fields[5] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<dynamic, dynamic>())),
      siteKeys: (fields[6] as Set?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ContentSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.images)
      ..writeByte(1)
      ..write(obj.nsfwBoards)
      ..writeByte(2)
      ..write(obj.nsfwImages)
      ..writeByte(3)
      ..write(obj.nsfwText)
      ..writeByte(6)
      ..write(obj.siteKeys);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedThemeFields {
  static Color getBackgroundColor(SavedTheme x) => x.backgroundColor;
  static void setBackgroundColor(SavedTheme x, Color v) =>
      x.backgroundColor = v;
  static const backgroundColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getBackgroundColor,
    setter: setBackgroundColor,
    fieldNumber: 0,
    fieldName: 'backgroundColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static Color getBarColor(SavedTheme x) => x.barColor;
  static void setBarColor(SavedTheme x, Color v) => x.barColor = v;
  static const barColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getBarColor,
    setter: setBarColor,
    fieldNumber: 1,
    fieldName: 'barColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static Color getPrimaryColor(SavedTheme x) => x.primaryColor;
  static void setPrimaryColor(SavedTheme x, Color v) => x.primaryColor = v;
  static const primaryColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getPrimaryColor,
    setter: setPrimaryColor,
    fieldNumber: 2,
    fieldName: 'primaryColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static Color getSecondaryColor(SavedTheme x) => x.secondaryColor;
  static void setSecondaryColor(SavedTheme x, Color v) => x.secondaryColor = v;
  static const secondaryColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getSecondaryColor,
    setter: setSecondaryColor,
    fieldNumber: 3,
    fieldName: 'secondaryColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static Color getQuoteColor(SavedTheme x) => x.quoteColor;
  static void setQuoteColor(SavedTheme x, Color v) => x.quoteColor = v;
  static const quoteColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getQuoteColor,
    setter: setQuoteColor,
    fieldNumber: 4,
    fieldName: 'quoteColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static SavedTheme? getCopiedFrom(SavedTheme x) => x.copiedFrom;
  static void setCopiedFrom(SavedTheme x, SavedTheme? v) => x.copiedFrom = v;
  static const copiedFrom = HiveFieldAdapter<SavedTheme, SavedTheme?>(
    getter: getCopiedFrom,
    setter: setCopiedFrom,
    fieldNumber: 5,
    fieldName: 'copiedFrom',
    merger: NullableMerger(AdaptedMerger(SavedThemeAdapter.kTypeId)),
  );
  static bool getLocked(SavedTheme x) => x.locked;
  static void setLocked(SavedTheme x, bool v) => x.locked = v;
  static const locked = HiveFieldAdapter<SavedTheme, bool>(
    getter: getLocked,
    setter: setLocked,
    fieldNumber: 6,
    fieldName: 'locked',
    merger: PrimitiveMerger(),
  );
  static Color getTitleColor(SavedTheme x) => x.titleColor;
  static void setTitleColor(SavedTheme x, Color v) => x.titleColor = v;
  static const titleColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getTitleColor,
    setter: setTitleColor,
    fieldNumber: 7,
    fieldName: 'titleColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
  static Color getTextFieldColor(SavedTheme x) => x.textFieldColor;
  static void setTextFieldColor(SavedTheme x, Color v) => x.textFieldColor = v;
  static const textFieldColor = HiveFieldAdapter<SavedTheme, Color>(
    getter: getTextFieldColor,
    setter: setTextFieldColor,
    fieldNumber: 8,
    fieldName: 'textFieldColor',
    merger: AdaptedMerger(ColorAdapter.kTypeId),
  );
}

class SavedThemeAdapter extends TypeAdapter<SavedTheme> {
  const SavedThemeAdapter();

  static const int kTypeId = 25;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<SavedTheme, dynamic>> fields = const {
    0: SavedThemeFields.backgroundColor,
    1: SavedThemeFields.barColor,
    2: SavedThemeFields.primaryColor,
    3: SavedThemeFields.secondaryColor,
    4: SavedThemeFields.quoteColor,
    5: SavedThemeFields.copiedFrom,
    6: SavedThemeFields.locked,
    7: SavedThemeFields.titleColor,
    8: SavedThemeFields.textFieldColor
  };

  @override
  SavedTheme read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedTheme(
      backgroundColor: fields[0] as Color,
      barColor: fields[1] as Color,
      primaryColor: fields[2] as Color,
      secondaryColor: fields[3] as Color,
      quoteColor: fields[4] == null
          ? const Color.fromRGBO(120, 153, 34, 1.0)
          : fields[4] as Color,
      titleColor: fields[7] == null
          ? const Color.fromRGBO(87, 153, 57, 1.0)
          : fields[7] as Color,
      locked: fields[6] as bool,
      copiedFrom: fields[5] as SavedTheme?,
      textFieldColor: fields[8] as Color?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedTheme obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.backgroundColor)
      ..writeByte(1)
      ..write(obj.barColor)
      ..writeByte(2)
      ..write(obj.primaryColor)
      ..writeByte(3)
      ..write(obj.secondaryColor)
      ..writeByte(4)
      ..write(obj.quoteColor)
      ..writeByte(5)
      ..write(obj.copiedFrom)
      ..writeByte(6)
      ..write(obj.locked)
      ..writeByte(7)
      ..write(obj.titleColor)
      ..writeByte(8)
      ..write(obj.textFieldColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedThemeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedSettingsFields {
  static AutoloadAttachmentsSetting getAutoloadAttachments(SavedSettings x) =>
      x.autoloadAttachments;
  static void setAutoloadAttachments(
          SavedSettings x, AutoloadAttachmentsSetting v) =>
      x.autoloadAttachments = v;
  static const autoloadAttachments =
      HiveFieldAdapter<SavedSettings, AutoloadAttachmentsSetting>(
    getter: getAutoloadAttachments,
    setter: setAutoloadAttachments,
    fieldNumber: 0,
    fieldName: 'autoloadAttachments',
    merger: PrimitiveMerger(),
  );
  static TristateSystemSetting getTheme(SavedSettings x) => x.theme;
  static void setTheme(SavedSettings x, TristateSystemSetting v) => x.theme = v;
  static const theme = HiveFieldAdapter<SavedSettings, TristateSystemSetting>(
    getter: getTheme,
    setter: setTheme,
    fieldNumber: 1,
    fieldName: 'theme',
    merger: PrimitiveMerger(),
  );
  static bool getHideOldStickiedThreads(SavedSettings x) =>
      x.hideOldStickiedThreads;
  static void setHideOldStickiedThreads(SavedSettings x, bool v) =>
      x.hideOldStickiedThreads = v;
  static const hideOldStickiedThreads = HiveFieldAdapter<SavedSettings, bool>(
    getter: getHideOldStickiedThreads,
    setter: setHideOldStickiedThreads,
    fieldNumber: 2,
    fieldName: 'hideOldStickiedThreads',
    merger: PrimitiveMerger(),
  );
  static ThreadSortingMethod getSavedThreadsSortingMethod(SavedSettings x) =>
      x.savedThreadsSortingMethod;
  static void setSavedThreadsSortingMethod(
          SavedSettings x, ThreadSortingMethod v) =>
      x.savedThreadsSortingMethod = v;
  static const savedThreadsSortingMethod =
      HiveFieldAdapter<SavedSettings, ThreadSortingMethod>(
    getter: getSavedThreadsSortingMethod,
    setter: setSavedThreadsSortingMethod,
    fieldNumber: 5,
    fieldName: 'savedThreadsSortingMethod',
    merger: PrimitiveMerger(),
  );
  static bool getAutoRotateInGallery(SavedSettings x) => x.autoRotateInGallery;
  static void setAutoRotateInGallery(SavedSettings x, bool v) =>
      x.autoRotateInGallery = v;
  static const autoRotateInGallery = HiveFieldAdapter<SavedSettings, bool>(
    getter: getAutoRotateInGallery,
    setter: setAutoRotateInGallery,
    fieldNumber: 6,
    fieldName: 'autoRotateInGallery',
    merger: PrimitiveMerger(),
  );
  static bool getUseTouchLayout(SavedSettings x) => x.useTouchLayout;
  static void setUseTouchLayout(SavedSettings x, bool v) =>
      x.useTouchLayout = v;
  static const useTouchLayout = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseTouchLayout,
    setter: setUseTouchLayout,
    fieldNumber: 9,
    fieldName: 'useTouchLayout',
    merger: PrimitiveMerger(),
  );
  static String getUserId(SavedSettings x) => x.userId;
  static void setUserId(SavedSettings x, String v) => x.userId = v;
  static const userId = HiveFieldAdapter<SavedSettings, String>(
    getter: getUserId,
    setter: setUserId,
    fieldNumber: 10,
    fieldName: 'userId',
    merger: PrimitiveMerger(),
  );
  static ContentSettings getContentSettings(SavedSettings x) =>
      x.contentSettings;
  static void setContentSettings(SavedSettings x, ContentSettings v) =>
      x.contentSettings = v;
  static const contentSettings =
      HiveFieldAdapter<SavedSettings, ContentSettings>(
    getter: getContentSettings,
    setter: setContentSettings,
    fieldNumber: 11,
    fieldName: 'contentSettings',
    merger: AdaptedMerger(ContentSettingsAdapter.kTypeId),
  );
  static String getFilterConfiguration(SavedSettings x) =>
      x.filterConfiguration;
  static void setFilterConfiguration(SavedSettings x, String v) =>
      x.filterConfiguration = v;
  static const filterConfiguration = HiveFieldAdapter<SavedSettings, String>(
    getter: getFilterConfiguration,
    setter: setFilterConfiguration,
    fieldNumber: 13,
    fieldName: 'filterConfiguration',
    merger: PrimitiveMerger(),
  );
  static bool getBoardSwitcherHasKeyboardFocus(SavedSettings x) =>
      x.boardSwitcherHasKeyboardFocus;
  static void setBoardSwitcherHasKeyboardFocus(SavedSettings x, bool v) =>
      x.boardSwitcherHasKeyboardFocus = v;
  static const boardSwitcherHasKeyboardFocus =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getBoardSwitcherHasKeyboardFocus,
    setter: setBoardSwitcherHasKeyboardFocus,
    fieldNumber: 14,
    fieldName: 'boardSwitcherHasKeyboardFocus',
    merger: PrimitiveMerger(),
  );
  static Map<String, PersistentBrowserState> getBrowserStateBySite(
          SavedSettings x) =>
      x.browserStateBySite;
  static void setBrowserStateBySite(
          SavedSettings x, Map<String, PersistentBrowserState> v) =>
      x.browserStateBySite = v;
  static const browserStateBySite =
      HiveFieldAdapter<SavedSettings, Map<String, PersistentBrowserState>>(
    getter: getBrowserStateBySite,
    setter: setBrowserStateBySite,
    fieldNumber: 18,
    fieldName: 'browserStateBySite',
    merger: MapMerger(AdaptedMerger(PersistentBrowserStateAdapter.kTypeId)),
  );
  static Map<String, Map<String, SavedPost>> getSavedPostsBySite(
          SavedSettings x) =>
      x.savedPostsBySite;
  static void setSavedPostsBySite(
          SavedSettings x, Map<String, Map<String, SavedPost>> v) =>
      x.savedPostsBySite = v;
  static const savedPostsBySite =
      HiveFieldAdapter<SavedSettings, Map<String, Map<String, SavedPost>>>(
    getter: getSavedPostsBySite,
    setter: setSavedPostsBySite,
    fieldNumber: 19,
    fieldName: 'savedPostsBySite',
    merger: MapMerger(MapMerger(AdaptedMerger(SavedPostAdapter.kTypeId))),
  );
  static Map<String, Map<String, SavedAttachment>> getSavedAttachmentsBySite(
          SavedSettings x) =>
      x.savedAttachmentsBySite;
  static void setSavedAttachmentsBySite(
          SavedSettings x, Map<String, Map<String, SavedAttachment>> v) =>
      x.savedAttachmentsBySite = v;
  static const savedAttachmentsBySite = HiveFieldAdapter<SavedSettings,
      Map<String, Map<String, SavedAttachment>>>(
    getter: getSavedAttachmentsBySite,
    setter: setSavedAttachmentsBySite,
    fieldNumber: 20,
    fieldName: 'savedAttachmentsBySite',
    merger: MapMerger(MapMerger(AdaptedMerger(SavedAttachmentAdapter.kTypeId))),
  );
  static double getTwoPaneBreakpoint(SavedSettings x) => x.twoPaneBreakpoint;
  static void setTwoPaneBreakpoint(SavedSettings x, double v) =>
      x.twoPaneBreakpoint = v;
  static const twoPaneBreakpoint = HiveFieldAdapter<SavedSettings, double>(
    getter: getTwoPaneBreakpoint,
    setter: setTwoPaneBreakpoint,
    fieldNumber: 22,
    fieldName: 'twoPaneBreakpoint',
    merger: PrimitiveMerger(),
  );
  static int getTwoPaneSplit(SavedSettings x) => x.twoPaneSplit;
  static void setTwoPaneSplit(SavedSettings x, int v) => x.twoPaneSplit = v;
  static const twoPaneSplit = HiveFieldAdapter<SavedSettings, int>(
    getter: getTwoPaneSplit,
    setter: setTwoPaneSplit,
    fieldNumber: 23,
    fieldName: 'twoPaneSplit',
    merger: PrimitiveMerger(),
  );
  static bool getUseCatalogGrid(SavedSettings x) => x.useCatalogGrid;
  static void setUseCatalogGrid(SavedSettings x, bool v) =>
      x.useCatalogGrid = v;
  static const useCatalogGrid = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseCatalogGrid,
    setter: setUseCatalogGrid,
    fieldNumber: 24,
    fieldName: 'useCatalogGrid',
    merger: PrimitiveMerger(),
  );
  static double getCatalogGridWidth(SavedSettings x) => x.catalogGridWidth;
  static void setCatalogGridWidth(SavedSettings x, double v) =>
      x.catalogGridWidth = v;
  static const catalogGridWidth = HiveFieldAdapter<SavedSettings, double>(
    getter: getCatalogGridWidth,
    setter: setCatalogGridWidth,
    fieldNumber: 25,
    fieldName: 'catalogGridWidth',
    merger: PrimitiveMerger(),
  );
  static double getCatalogGridHeight(SavedSettings x) => x.catalogGridHeight;
  static void setCatalogGridHeight(SavedSettings x, double v) =>
      x.catalogGridHeight = v;
  static const catalogGridHeight = HiveFieldAdapter<SavedSettings, double>(
    getter: getCatalogGridHeight,
    setter: setCatalogGridHeight,
    fieldNumber: 26,
    fieldName: 'catalogGridHeight',
    merger: PrimitiveMerger(),
  );
  static bool getShowImageCountInCatalog(SavedSettings x) =>
      x.showImageCountInCatalog;
  static void setShowImageCountInCatalog(SavedSettings x, bool v) =>
      x.showImageCountInCatalog = v;
  static const showImageCountInCatalog = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowImageCountInCatalog,
    setter: setShowImageCountInCatalog,
    fieldNumber: 27,
    fieldName: 'showImageCountInCatalog',
    merger: PrimitiveMerger(),
  );
  static bool getShowClockIconInCatalog(SavedSettings x) =>
      x.showClockIconInCatalog;
  static void setShowClockIconInCatalog(SavedSettings x, bool v) =>
      x.showClockIconInCatalog = v;
  static const showClockIconInCatalog = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowClockIconInCatalog,
    setter: setShowClockIconInCatalog,
    fieldNumber: 28,
    fieldName: 'showClockIconInCatalog',
    merger: PrimitiveMerger(),
  );
  static TristateSystemSetting getSupportMouse(SavedSettings x) =>
      x.supportMouse;
  static void setSupportMouse(SavedSettings x, TristateSystemSetting v) =>
      x.supportMouse = v;
  static const supportMouse =
      HiveFieldAdapter<SavedSettings, TristateSystemSetting>(
    getter: getSupportMouse,
    setter: setSupportMouse,
    fieldNumber: 30,
    fieldName: 'supportMouse',
    merger: PrimitiveMerger(),
  );
  static bool getShowNameInCatalog(SavedSettings x) => x.showNameInCatalog;
  static void setShowNameInCatalog(SavedSettings x, bool v) =>
      x.showNameInCatalog = v;
  static const showNameInCatalog = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowNameInCatalog,
    setter: setShowNameInCatalog,
    fieldNumber: 31,
    fieldName: 'showNameInCatalog',
    merger: PrimitiveMerger(),
  );
  static double getInterfaceScale(SavedSettings x) => x.interfaceScale;
  static void setInterfaceScale(SavedSettings x, double v) =>
      x.interfaceScale = v;
  static const interfaceScale = HiveFieldAdapter<SavedSettings, double>(
    getter: getInterfaceScale,
    setter: setInterfaceScale,
    fieldNumber: 32,
    fieldName: 'interfaceScale',
    merger: PrimitiveMerger(),
  );
  static bool getShowAnimations(SavedSettings x) => x.showAnimations;
  static void setShowAnimations(SavedSettings x, bool v) =>
      x.showAnimations = v;
  static const showAnimations = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowAnimations,
    setter: setShowAnimations,
    fieldNumber: 33,
    fieldName: 'showAnimations',
    merger: PrimitiveMerger(),
  );
  static bool getImagesOnRight(SavedSettings x) => x.imagesOnRight;
  static void setImagesOnRight(SavedSettings x, bool v) => x.imagesOnRight = v;
  static const imagesOnRight = HiveFieldAdapter<SavedSettings, bool>(
    getter: getImagesOnRight,
    setter: setImagesOnRight,
    fieldNumber: 34,
    fieldName: 'imagesOnRight',
    merger: PrimitiveMerger(),
  );
  static String? getAndroidGallerySavePath(SavedSettings x) =>
      x.androidGallerySavePath;
  static void setAndroidGallerySavePath(SavedSettings x, String? v) =>
      x.androidGallerySavePath = v;
  static const androidGallerySavePath =
      HiveFieldAdapter<SavedSettings, String?>(
    getter: getAndroidGallerySavePath,
    setter: setAndroidGallerySavePath,
    fieldNumber: 35,
    fieldName: 'androidGallerySavePath',
    merger: PrimitiveMerger(),
  );
  static double getReplyBoxHeightOffset(SavedSettings x) =>
      x.replyBoxHeightOffset;
  static void setReplyBoxHeightOffset(SavedSettings x, double v) =>
      x.replyBoxHeightOffset = v;
  static const replyBoxHeightOffset = HiveFieldAdapter<SavedSettings, double>(
    getter: getReplyBoxHeightOffset,
    setter: setReplyBoxHeightOffset,
    fieldNumber: 36,
    fieldName: 'replyBoxHeightOffset',
    merger: PrimitiveMerger(),
  );
  static bool getBlurThumbnails(SavedSettings x) => x.blurThumbnails;
  static void setBlurThumbnails(SavedSettings x, bool v) =>
      x.blurThumbnails = v;
  static const blurThumbnails = HiveFieldAdapter<SavedSettings, bool>(
    getter: getBlurThumbnails,
    setter: setBlurThumbnails,
    fieldNumber: 37,
    fieldName: 'blurThumbnails',
    merger: PrimitiveMerger(),
  );
  static bool getShowTimeInCatalogHeader(SavedSettings x) =>
      x.showTimeInCatalogHeader;
  static void setShowTimeInCatalogHeader(SavedSettings x, bool v) =>
      x.showTimeInCatalogHeader = v;
  static const showTimeInCatalogHeader = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowTimeInCatalogHeader,
    setter: setShowTimeInCatalogHeader,
    fieldNumber: 38,
    fieldName: 'showTimeInCatalogHeader',
    merger: PrimitiveMerger(),
  );
  static bool getShowTimeInCatalogStats(SavedSettings x) =>
      x.showTimeInCatalogStats;
  static void setShowTimeInCatalogStats(SavedSettings x, bool v) =>
      x.showTimeInCatalogStats = v;
  static const showTimeInCatalogStats = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowTimeInCatalogStats,
    setter: setShowTimeInCatalogStats,
    fieldNumber: 39,
    fieldName: 'showTimeInCatalogStats',
    merger: PrimitiveMerger(),
  );
  static bool getShowIdInCatalogHeader(SavedSettings x) =>
      x.showIdInCatalogHeader;
  static void setShowIdInCatalogHeader(SavedSettings x, bool v) =>
      x.showIdInCatalogHeader = v;
  static const showIdInCatalogHeader = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowIdInCatalogHeader,
    setter: setShowIdInCatalogHeader,
    fieldNumber: 40,
    fieldName: 'showIdInCatalogHeader',
    merger: PrimitiveMerger(),
  );
  static bool getShowFlagInCatalogHeader(SavedSettings x) =>
      x.showFlagInCatalogHeader;
  static void setShowFlagInCatalogHeader(SavedSettings x, bool v) =>
      x.showFlagInCatalogHeader = v;
  static const showFlagInCatalogHeader = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowFlagInCatalogHeader,
    setter: setShowFlagInCatalogHeader,
    fieldNumber: 41,
    fieldName: 'showFlagInCatalogHeader',
    merger: PrimitiveMerger(),
  );
  static bool getOnlyShowFavouriteBoardsInSwitcher(SavedSettings x) =>
      x.onlyShowFavouriteBoardsInSwitcher;
  static void setOnlyShowFavouriteBoardsInSwitcher(SavedSettings x, bool v) =>
      x.onlyShowFavouriteBoardsInSwitcher = v;
  static const onlyShowFavouriteBoardsInSwitcher =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getOnlyShowFavouriteBoardsInSwitcher,
    setter: setOnlyShowFavouriteBoardsInSwitcher,
    fieldNumber: 42,
    fieldName: 'onlyShowFavouriteBoardsInSwitcher',
    merger: PrimitiveMerger(),
  );
  static bool getUseBoardSwitcherList(SavedSettings x) =>
      x.useBoardSwitcherList;
  static void setUseBoardSwitcherList(SavedSettings x, bool v) =>
      x.useBoardSwitcherList = v;
  static const useBoardSwitcherList = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseBoardSwitcherList,
    setter: setUseBoardSwitcherList,
    fieldNumber: 43,
    fieldName: 'useBoardSwitcherList',
    merger: PrimitiveMerger(),
  );
  static bool? getContributeCaptchas(SavedSettings x) => x.contributeCaptchas;
  static void setContributeCaptchas(SavedSettings x, bool? v) =>
      x.contributeCaptchas = v;
  static const contributeCaptchas = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getContributeCaptchas,
    setter: setContributeCaptchas,
    fieldNumber: 44,
    fieldName: 'contributeCaptchas',
    merger: PrimitiveMerger(),
  );
  static bool getShowReplyCountsInGallery(SavedSettings x) =>
      x.showReplyCountsInGallery;
  static void setShowReplyCountsInGallery(SavedSettings x, bool v) =>
      x.showReplyCountsInGallery = v;
  static const showReplyCountsInGallery = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowReplyCountsInGallery,
    setter: setShowReplyCountsInGallery,
    fieldNumber: 45,
    fieldName: 'showReplyCountsInGallery',
    merger: PrimitiveMerger(),
  );
  static bool getUseNewCaptchaForm(SavedSettings x) => x.useNewCaptchaForm;
  static void setUseNewCaptchaForm(SavedSettings x, bool v) =>
      x.useNewCaptchaForm = v;
  static const useNewCaptchaForm = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseNewCaptchaForm,
    setter: setUseNewCaptchaForm,
    fieldNumber: 46,
    fieldName: 'useNewCaptchaForm',
    merger: PrimitiveMerger(),
  );
  static bool? getAutoLoginOnMobileNetwork(SavedSettings x) =>
      x.autoLoginOnMobileNetwork;
  static void setAutoLoginOnMobileNetwork(SavedSettings x, bool? v) =>
      x.autoLoginOnMobileNetwork = v;
  static const autoLoginOnMobileNetwork =
      HiveFieldAdapter<SavedSettings, bool?>(
    getter: getAutoLoginOnMobileNetwork,
    setter: setAutoLoginOnMobileNetwork,
    fieldNumber: 47,
    fieldName: 'autoLoginOnMobileNetwork',
    merger: PrimitiveMerger(),
  );
  static bool getShowScrollbars(SavedSettings x) => x.showScrollbars;
  static void setShowScrollbars(SavedSettings x, bool v) =>
      x.showScrollbars = v;
  static const showScrollbars = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowScrollbars,
    setter: setShowScrollbars,
    fieldNumber: 48,
    fieldName: 'showScrollbars',
    merger: PrimitiveMerger(),
  );
  static bool getRandomizeFilenames(SavedSettings x) => x.randomizeFilenames;
  static void setRandomizeFilenames(SavedSettings x, bool v) =>
      x.randomizeFilenames = v;
  static const randomizeFilenames = HiveFieldAdapter<SavedSettings, bool>(
    getter: getRandomizeFilenames,
    setter: setRandomizeFilenames,
    fieldNumber: 49,
    fieldName: 'randomizeFilenames',
    merger: PrimitiveMerger(),
  );
  static bool getShowNameOnPosts(SavedSettings x) => x.showNameOnPosts;
  static void setShowNameOnPosts(SavedSettings x, bool v) =>
      x.showNameOnPosts = v;
  static const showNameOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowNameOnPosts,
    setter: setShowNameOnPosts,
    fieldNumber: 50,
    fieldName: 'showNameOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowTripOnPosts(SavedSettings x) => x.showTripOnPosts;
  static void setShowTripOnPosts(SavedSettings x, bool v) =>
      x.showTripOnPosts = v;
  static const showTripOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowTripOnPosts,
    setter: setShowTripOnPosts,
    fieldNumber: 51,
    fieldName: 'showTripOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowAbsoluteTimeOnPosts(SavedSettings x) =>
      x.showAbsoluteTimeOnPosts;
  static void setShowAbsoluteTimeOnPosts(SavedSettings x, bool v) =>
      x.showAbsoluteTimeOnPosts = v;
  static const showAbsoluteTimeOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowAbsoluteTimeOnPosts,
    setter: setShowAbsoluteTimeOnPosts,
    fieldNumber: 52,
    fieldName: 'showAbsoluteTimeOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowRelativeTimeOnPosts(SavedSettings x) =>
      x.showRelativeTimeOnPosts;
  static void setShowRelativeTimeOnPosts(SavedSettings x, bool v) =>
      x.showRelativeTimeOnPosts = v;
  static const showRelativeTimeOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowRelativeTimeOnPosts,
    setter: setShowRelativeTimeOnPosts,
    fieldNumber: 53,
    fieldName: 'showRelativeTimeOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowCountryNameOnPosts(SavedSettings x) =>
      x.showCountryNameOnPosts;
  static void setShowCountryNameOnPosts(SavedSettings x, bool v) =>
      x.showCountryNameOnPosts = v;
  static const showCountryNameOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowCountryNameOnPosts,
    setter: setShowCountryNameOnPosts,
    fieldNumber: 54,
    fieldName: 'showCountryNameOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowPassOnPosts(SavedSettings x) => x.showPassOnPosts;
  static void setShowPassOnPosts(SavedSettings x, bool v) =>
      x.showPassOnPosts = v;
  static const showPassOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowPassOnPosts,
    setter: setShowPassOnPosts,
    fieldNumber: 55,
    fieldName: 'showPassOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowFilenameOnPosts(SavedSettings x) => x.showFilenameOnPosts;
  static void setShowFilenameOnPosts(SavedSettings x, bool v) =>
      x.showFilenameOnPosts = v;
  static const showFilenameOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowFilenameOnPosts,
    setter: setShowFilenameOnPosts,
    fieldNumber: 56,
    fieldName: 'showFilenameOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowFilesizeOnPosts(SavedSettings x) => x.showFilesizeOnPosts;
  static void setShowFilesizeOnPosts(SavedSettings x, bool v) =>
      x.showFilesizeOnPosts = v;
  static const showFilesizeOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowFilesizeOnPosts,
    setter: setShowFilesizeOnPosts,
    fieldNumber: 57,
    fieldName: 'showFilesizeOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowFileDimensionsOnPosts(SavedSettings x) =>
      x.showFileDimensionsOnPosts;
  static void setShowFileDimensionsOnPosts(SavedSettings x, bool v) =>
      x.showFileDimensionsOnPosts = v;
  static const showFileDimensionsOnPosts =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowFileDimensionsOnPosts,
    setter: setShowFileDimensionsOnPosts,
    fieldNumber: 58,
    fieldName: 'showFileDimensionsOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowFlagOnPosts(SavedSettings x) => x.showFlagOnPosts;
  static void setShowFlagOnPosts(SavedSettings x, bool v) =>
      x.showFlagOnPosts = v;
  static const showFlagOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowFlagOnPosts,
    setter: setShowFlagOnPosts,
    fieldNumber: 59,
    fieldName: 'showFlagOnPosts',
    merger: PrimitiveMerger(),
  );
  static double getThumbnailSize(SavedSettings x) => x.thumbnailSize;
  static void setThumbnailSize(SavedSettings x, double v) =>
      x.thumbnailSize = v;
  static const thumbnailSize = HiveFieldAdapter<SavedSettings, double>(
    getter: getThumbnailSize,
    setter: setThumbnailSize,
    fieldNumber: 60,
    fieldName: 'thumbnailSize',
    merger: PrimitiveMerger(),
  );
  static bool getMuteAudio(SavedSettings x) => x.muteAudio;
  static void setMuteAudio(SavedSettings x, bool v) => x.muteAudio = v;
  static const muteAudio = HiveFieldAdapter<SavedSettings, bool>(
    getter: getMuteAudio,
    setter: setMuteAudio,
    fieldNumber: 61,
    fieldName: 'muteAudio',
    merger: PrimitiveMerger(),
  );
  static bool? getUsePushNotifications(SavedSettings x) =>
      x.usePushNotifications;
  static void setUsePushNotifications(SavedSettings x, bool? v) =>
      x.usePushNotifications = v;
  static const usePushNotifications = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUsePushNotifications,
    setter: setUsePushNotifications,
    fieldNumber: 62,
    fieldName: 'usePushNotifications',
    merger: PrimitiveMerger(),
  );
  static bool getUseEmbeds(SavedSettings x) => x.useEmbeds;
  static void setUseEmbeds(SavedSettings x, bool v) => x.useEmbeds = v;
  static const useEmbeds = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseEmbeds,
    setter: setUseEmbeds,
    fieldNumber: 63,
    fieldName: 'useEmbeds',
    merger: PrimitiveMerger(),
  );
  static bool? getUseInternalBrowser(SavedSettings x) => x.useInternalBrowser;
  static void setUseInternalBrowser(SavedSettings x, bool? v) =>
      x.useInternalBrowser = v;
  static const useInternalBrowser = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseInternalBrowser,
    setter: setUseInternalBrowser,
    fieldNumber: 64,
    fieldName: 'useInternalBrowser',
    merger: PrimitiveMerger(),
  );
  static int getAutomaticCacheClearDays(SavedSettings x) =>
      x.automaticCacheClearDays;
  static void setAutomaticCacheClearDays(SavedSettings x, int v) =>
      x.automaticCacheClearDays = v;
  static const automaticCacheClearDays = HiveFieldAdapter<SavedSettings, int>(
    getter: getAutomaticCacheClearDays,
    setter: setAutomaticCacheClearDays,
    fieldNumber: 65,
    fieldName: 'automaticCacheClearDays',
    merger: PrimitiveMerger(),
  );
  static bool getAlwaysAutoloadTappedAttachment(SavedSettings x) =>
      x.alwaysAutoloadTappedAttachment;
  static void setAlwaysAutoloadTappedAttachment(SavedSettings x, bool v) =>
      x.alwaysAutoloadTappedAttachment = v;
  static const alwaysAutoloadTappedAttachment =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getAlwaysAutoloadTappedAttachment,
    setter: setAlwaysAutoloadTappedAttachment,
    fieldNumber: 66,
    fieldName: 'alwaysAutoloadTappedAttachment',
    merger: PrimitiveMerger(),
  );
  static List<PostDisplayField> getPostDisplayFieldOrder(SavedSettings x) =>
      x.postDisplayFieldOrder;
  static void setPostDisplayFieldOrder(
          SavedSettings x, List<PostDisplayField> v) =>
      x.postDisplayFieldOrder = v;
  static const postDisplayFieldOrder =
      HiveFieldAdapter<SavedSettings, List<PostDisplayField>>(
    getter: getPostDisplayFieldOrder,
    setter: setPostDisplayFieldOrder,
    fieldNumber: 67,
    fieldName: 'postDisplayFieldOrder',
    merger: OrderedSetLikePrimitiveListMerger<PostDisplayField>(),
  );
  static int? getMaximumImageUploadDimension(SavedSettings x) =>
      x.maximumImageUploadDimension;
  static void setMaximumImageUploadDimension(SavedSettings x, int? v) =>
      x.maximumImageUploadDimension = v;
  static const maximumImageUploadDimension =
      HiveFieldAdapter<SavedSettings, int?>(
    getter: getMaximumImageUploadDimension,
    setter: setMaximumImageUploadDimension,
    fieldNumber: 68,
    fieldName: 'maximumImageUploadDimension',
    merger: PrimitiveMerger(),
  );
  static List<PersistentBrowserTab> getTabs(SavedSettings x) => x.tabs;
  static void setTabs(SavedSettings x, List<PersistentBrowserTab> v) =>
      x.tabs = v;
  static const tabs =
      HiveFieldAdapter<SavedSettings, List<PersistentBrowserTab>>(
    getter: getTabs,
    setter: setTabs,
    fieldNumber: 69,
    fieldName: 'tabs',
    merger: PersistentBrowserTab.listMerger,
  );
  static int getCurrentTabIndex(SavedSettings x) => x.currentTabIndex;
  static void setCurrentTabIndex(SavedSettings x, int v) =>
      x.currentTabIndex = v;
  static const currentTabIndex = HiveFieldAdapter<SavedSettings, int>(
    getter: getCurrentTabIndex,
    setter: setCurrentTabIndex,
    fieldNumber: 70,
    fieldName: 'currentTabIndex',
    merger: PrimitiveMerger(),
  );
  static PersistentRecentSearches getRecentSearches(SavedSettings x) =>
      x.recentSearches;
  static void setRecentSearches(SavedSettings x, PersistentRecentSearches v) =>
      x.recentSearches = v;
  static const recentSearches =
      HiveFieldAdapter<SavedSettings, PersistentRecentSearches>(
    getter: getRecentSearches,
    setter: setRecentSearches,
    fieldNumber: 71,
    fieldName: 'recentSearches',
    merger: AdaptedMerger(PersistentRecentSearchesAdapter.kTypeId),
  );
  static bool getHideDefaultNamesOnPosts(SavedSettings x) =>
      x.hideDefaultNamesOnPosts;
  static void setHideDefaultNamesOnPosts(SavedSettings x, bool v) =>
      x.hideDefaultNamesOnPosts = v;
  static const hideDefaultNamesOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getHideDefaultNamesOnPosts,
    setter: setHideDefaultNamesOnPosts,
    fieldNumber: 72,
    fieldName: 'hideDefaultNamesOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowThumbnailsInGallery(SavedSettings x) =>
      x.showThumbnailsInGallery;
  static void setShowThumbnailsInGallery(SavedSettings x, bool v) =>
      x.showThumbnailsInGallery = v;
  static const showThumbnailsInGallery = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowThumbnailsInGallery,
    setter: setShowThumbnailsInGallery,
    fieldNumber: 73,
    fieldName: 'showThumbnailsInGallery',
    merger: PrimitiveMerger(),
  );
  static ThreadSortingMethod getWatchedThreadsSortingMethod(SavedSettings x) =>
      x.watchedThreadsSortingMethod;
  static void setWatchedThreadsSortingMethod(
          SavedSettings x, ThreadSortingMethod v) =>
      x.watchedThreadsSortingMethod = v;
  static const watchedThreadsSortingMethod =
      HiveFieldAdapter<SavedSettings, ThreadSortingMethod>(
    getter: getWatchedThreadsSortingMethod,
    setter: setWatchedThreadsSortingMethod,
    fieldNumber: 74,
    fieldName: 'watchedThreadsSortingMethod',
    merger: PrimitiveMerger(),
  );
  static bool getCloseTabSwitcherAfterUse(SavedSettings x) =>
      x.closeTabSwitcherAfterUse;
  static void setCloseTabSwitcherAfterUse(SavedSettings x, bool v) =>
      x.closeTabSwitcherAfterUse = v;
  static const closeTabSwitcherAfterUse = HiveFieldAdapter<SavedSettings, bool>(
    getter: getCloseTabSwitcherAfterUse,
    setter: setCloseTabSwitcherAfterUse,
    fieldNumber: 75,
    fieldName: 'closeTabSwitcherAfterUse',
    merger: PrimitiveMerger(),
  );
  static double getTextScale(SavedSettings x) => x.textScale;
  static void setTextScale(SavedSettings x, double v) => x.textScale = v;
  static const textScale = HiveFieldAdapter<SavedSettings, double>(
    getter: getTextScale,
    setter: setTextScale,
    fieldNumber: 76,
    fieldName: 'textScale',
    merger: PrimitiveMerger(),
  );
  static int? getCatalogGridModeTextLinesLimit(SavedSettings x) =>
      x.catalogGridModeTextLinesLimit;
  static void setCatalogGridModeTextLinesLimit(SavedSettings x, int? v) =>
      x.catalogGridModeTextLinesLimit = v;
  static const catalogGridModeTextLinesLimit =
      HiveFieldAdapter<SavedSettings, int?>(
    getter: getCatalogGridModeTextLinesLimit,
    setter: setCatalogGridModeTextLinesLimit,
    fieldNumber: 77,
    fieldName: 'catalogGridModeTextLinesLimit',
    merger: PrimitiveMerger(),
  );
  static bool getCatalogGridModeAttachmentInBackground(SavedSettings x) =>
      x.catalogGridModeAttachmentInBackground;
  static void setCatalogGridModeAttachmentInBackground(
          SavedSettings x, bool v) =>
      x.catalogGridModeAttachmentInBackground = v;
  static const catalogGridModeAttachmentInBackground =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCatalogGridModeAttachmentInBackground,
    setter: setCatalogGridModeAttachmentInBackground,
    fieldNumber: 78,
    fieldName: 'catalogGridModeAttachmentInBackground',
    merger: PrimitiveMerger(),
  );
  static double getMaxCatalogRowHeight(SavedSettings x) =>
      x.maxCatalogRowHeight;
  static void setMaxCatalogRowHeight(SavedSettings x, double v) =>
      x.maxCatalogRowHeight = v;
  static const maxCatalogRowHeight = HiveFieldAdapter<SavedSettings, double>(
    getter: getMaxCatalogRowHeight,
    setter: setMaxCatalogRowHeight,
    fieldNumber: 79,
    fieldName: 'maxCatalogRowHeight',
    merger: PrimitiveMerger(),
  );
  static Map<String, SavedTheme> getThemes(SavedSettings x) => x.themes;
  static void setThemes(SavedSettings x, Map<String, SavedTheme> v) =>
      x.themes = v;
  static const themes =
      HiveFieldAdapter<SavedSettings, Map<String, SavedTheme>>(
    getter: getThemes,
    setter: setThemes,
    fieldNumber: 80,
    fieldName: 'themes',
    merger: MapMerger(AdaptedMerger(SavedThemeAdapter.kTypeId)),
  );
  static String getLightThemeKey(SavedSettings x) => x.lightThemeKey;
  static void setLightThemeKey(SavedSettings x, String v) =>
      x.lightThemeKey = v;
  static const lightThemeKey = HiveFieldAdapter<SavedSettings, String>(
    getter: getLightThemeKey,
    setter: setLightThemeKey,
    fieldNumber: 81,
    fieldName: 'lightThemeKey',
    merger: PrimitiveMerger(),
  );
  static String getDarkThemeKey(SavedSettings x) => x.darkThemeKey;
  static void setDarkThemeKey(SavedSettings x, String v) => x.darkThemeKey = v;
  static const darkThemeKey = HiveFieldAdapter<SavedSettings, String>(
    getter: getDarkThemeKey,
    setter: setDarkThemeKey,
    fieldNumber: 83,
    fieldName: 'darkThemeKey',
    merger: PrimitiveMerger(),
  );
  static List<String> getHostsToOpenExternally(SavedSettings x) =>
      x.hostsToOpenExternally;
  static void setHostsToOpenExternally(SavedSettings x, List<String> v) =>
      x.hostsToOpenExternally = v;
  static const hostsToOpenExternally =
      HiveFieldAdapter<SavedSettings, List<String>>(
    getter: getHostsToOpenExternally,
    setter: setHostsToOpenExternally,
    fieldNumber: 84,
    fieldName: 'hostsToOpenExternally',
    merger: SetLikePrimitiveListMerger<String>(),
  );
  static bool getUseFullWidthForCatalogCounters(SavedSettings x) =>
      x.useFullWidthForCatalogCounters;
  static void setUseFullWidthForCatalogCounters(SavedSettings x, bool v) =>
      x.useFullWidthForCatalogCounters = v;
  static const useFullWidthForCatalogCounters =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseFullWidthForCatalogCounters,
    setter: setUseFullWidthForCatalogCounters,
    fieldNumber: 85,
    fieldName: 'useFullWidthForCatalogCounters',
    merger: PrimitiveMerger(),
  );
  static bool getAllowSwipingInGallery(SavedSettings x) =>
      x.allowSwipingInGallery;
  static void setAllowSwipingInGallery(SavedSettings x, bool v) =>
      x.allowSwipingInGallery = v;
  static const allowSwipingInGallery = HiveFieldAdapter<SavedSettings, bool>(
    getter: getAllowSwipingInGallery,
    setter: setAllowSwipingInGallery,
    fieldNumber: 87,
    fieldName: 'allowSwipingInGallery',
    merger: PrimitiveMerger(),
  );
  static SettingsQuickAction? getSettingsQuickAction(SavedSettings x) =>
      x.settingsQuickAction;
  static void setSettingsQuickAction(SavedSettings x, SettingsQuickAction? v) =>
      x.settingsQuickAction = v;
  static const settingsQuickAction =
      HiveFieldAdapter<SavedSettings, SettingsQuickAction?>(
    getter: getSettingsQuickAction,
    setter: setSettingsQuickAction,
    fieldNumber: 88,
    fieldName: 'settingsQuickAction',
    merger: PrimitiveMerger(),
  );
  static bool getUseHapticFeedback(SavedSettings x) => x.useHapticFeedback;
  static void setUseHapticFeedback(SavedSettings x, bool v) =>
      x.useHapticFeedback = v;
  static const useHapticFeedback = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseHapticFeedback,
    setter: setUseHapticFeedback,
    fieldNumber: 89,
    fieldName: 'useHapticFeedback',
    merger: PrimitiveMerger(),
  );
  static bool getPromptedAboutCrashlytics(SavedSettings x) =>
      x.promptedAboutCrashlytics;
  static void setPromptedAboutCrashlytics(SavedSettings x, bool v) =>
      x.promptedAboutCrashlytics = v;
  static const promptedAboutCrashlytics = HiveFieldAdapter<SavedSettings, bool>(
    getter: getPromptedAboutCrashlytics,
    setter: setPromptedAboutCrashlytics,
    fieldNumber: 90,
    fieldName: 'promptedAboutCrashlytics',
    merger: PrimitiveMerger(),
  );
  static bool getShowCountryNameInCatalogHeader(SavedSettings x) =>
      x.showCountryNameInCatalogHeader;
  static void setShowCountryNameInCatalogHeader(SavedSettings x, bool v) =>
      x.showCountryNameInCatalogHeader = v;
  static const showCountryNameInCatalogHeader =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowCountryNameInCatalogHeader,
    setter: setShowCountryNameInCatalogHeader,
    fieldNumber: 91,
    fieldName: 'showCountryNameInCatalogHeader',
    merger: PrimitiveMerger(),
  );
  static WebmTranscodingSetting getWebmTranscoding(SavedSettings x) =>
      x.webmTranscoding;
  static void setWebmTranscoding(SavedSettings x, WebmTranscodingSetting v) =>
      x.webmTranscoding = v;
  static const webmTranscoding =
      HiveFieldAdapter<SavedSettings, WebmTranscodingSetting>(
    getter: getWebmTranscoding,
    setter: setWebmTranscoding,
    fieldNumber: 92,
    fieldName: 'webmTranscoding',
    merger: PrimitiveMerger(),
  );
  static bool getShowListPositionIndicatorsOnLeft(SavedSettings x) =>
      x.showListPositionIndicatorsOnLeft;
  static void setShowListPositionIndicatorsOnLeft(SavedSettings x, bool v) =>
      x.showListPositionIndicatorsOnLeft = v;
  static const showListPositionIndicatorsOnLeft =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowListPositionIndicatorsOnLeft,
    setter: setShowListPositionIndicatorsOnLeft,
    fieldNumber: 93,
    fieldName: 'showListPositionIndicatorsOnLeft',
    merger: PrimitiveMerger(),
  );
  static List<String> getAppliedMigrations(SavedSettings x) =>
      x.appliedMigrations;
  static void setAppliedMigrations(SavedSettings x, List<String> v) =>
      x.appliedMigrations = v;
  static const appliedMigrations =
      HiveFieldAdapter<SavedSettings, List<String>>(
    getter: getAppliedMigrations,
    setter: setAppliedMigrations,
    fieldNumber: 94,
    fieldName: 'appliedMigrations',
    merger: SetLikePrimitiveListMerger<String>(),
  );
  static bool? getUseStatusBarWorkaround(SavedSettings x) =>
      x.useStatusBarWorkaround;
  static void setUseStatusBarWorkaround(SavedSettings x, bool? v) =>
      x.useStatusBarWorkaround = v;
  static const useStatusBarWorkaround = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseStatusBarWorkaround,
    setter: setUseStatusBarWorkaround,
    fieldNumber: 95,
    fieldName: 'useStatusBarWorkaround',
    merger: PrimitiveMerger(),
  );
  static bool getEnableIMEPersonalizedLearning(SavedSettings x) =>
      x.enableIMEPersonalizedLearning;
  static void setEnableIMEPersonalizedLearning(SavedSettings x, bool v) =>
      x.enableIMEPersonalizedLearning = v;
  static const enableIMEPersonalizedLearning =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getEnableIMEPersonalizedLearning,
    setter: setEnableIMEPersonalizedLearning,
    fieldNumber: 96,
    fieldName: 'enableIMEPersonalizedLearning',
    merger: PrimitiveMerger(),
  );
  static CatalogVariant getCatalogVariant(SavedSettings x) => x.catalogVariant;
  static void setCatalogVariant(SavedSettings x, CatalogVariant v) =>
      x.catalogVariant = v;
  static const catalogVariant = HiveFieldAdapter<SavedSettings, CatalogVariant>(
    getter: getCatalogVariant,
    setter: setCatalogVariant,
    fieldNumber: 97,
    fieldName: 'catalogVariant',
    merger: PrimitiveMerger(),
  );
  static CatalogVariant getRedditCatalogVariant(SavedSettings x) =>
      x.redditCatalogVariant;
  static void setRedditCatalogVariant(SavedSettings x, CatalogVariant v) =>
      x.redditCatalogVariant = v;
  static const redditCatalogVariant =
      HiveFieldAdapter<SavedSettings, CatalogVariant>(
    getter: getRedditCatalogVariant,
    setter: setRedditCatalogVariant,
    fieldNumber: 98,
    fieldName: 'redditCatalogVariant',
    merger: PrimitiveMerger(),
  );
  static bool getDimReadThreads(SavedSettings x) => x.dimReadThreads;
  static void setDimReadThreads(SavedSettings x, bool v) =>
      x.dimReadThreads = v;
  static const dimReadThreads = HiveFieldAdapter<SavedSettings, bool>(
    getter: getDimReadThreads,
    setter: setDimReadThreads,
    fieldNumber: 99,
    fieldName: 'dimReadThreads',
    merger: PrimitiveMerger(),
  );
  static CatalogVariant getHackerNewsCatalogVariant(SavedSettings x) =>
      x.hackerNewsCatalogVariant;
  static void setHackerNewsCatalogVariant(SavedSettings x, CatalogVariant v) =>
      x.hackerNewsCatalogVariant = v;
  static const hackerNewsCatalogVariant =
      HiveFieldAdapter<SavedSettings, CatalogVariant>(
    getter: getHackerNewsCatalogVariant,
    setter: setHackerNewsCatalogVariant,
    fieldNumber: 100,
    fieldName: 'hackerNewsCatalogVariant',
    merger: PrimitiveMerger(),
  );
  static bool getHideDefaultNamesInCatalog(SavedSettings x) =>
      x.hideDefaultNamesInCatalog;
  static void setHideDefaultNamesInCatalog(SavedSettings x, bool v) =>
      x.hideDefaultNamesInCatalog = v;
  static const hideDefaultNamesInCatalog =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getHideDefaultNamesInCatalog,
    setter: setHideDefaultNamesInCatalog,
    fieldNumber: 101,
    fieldName: 'hideDefaultNamesInCatalog',
    merger: PrimitiveMerger(),
  );
  static int getLaunchCount(SavedSettings x) => x.launchCount;
  static void setLaunchCount(SavedSettings x, int v) => x.launchCount = v;
  static const launchCount = HiveFieldAdapter<SavedSettings, int>(
    getter: getLaunchCount,
    setter: setLaunchCount,
    fieldNumber: 102,
    fieldName: 'launchCount',
    merger: _LaunchCountMerger(),
  );
  static String getUserAgent(SavedSettings x) => x.userAgent;
  static void setUserAgent(SavedSettings x, String v) => x.userAgent = v;
  static const userAgent = HiveFieldAdapter<SavedSettings, String>(
    getter: getUserAgent,
    setter: setUserAgent,
    fieldNumber: 103,
    fieldName: 'userAgent',
    merger: PrimitiveMerger(),
  );
  static int getCaptcha4ChanCustomNumLetters(SavedSettings x) =>
      x.captcha4ChanCustomNumLetters;
  static void setCaptcha4ChanCustomNumLetters(SavedSettings x, int v) =>
      x.captcha4ChanCustomNumLetters = v;
  static const captcha4ChanCustomNumLetters =
      HiveFieldAdapter<SavedSettings, int>(
    getter: getCaptcha4ChanCustomNumLetters,
    setter: setCaptcha4ChanCustomNumLetters,
    fieldNumber: 104,
    fieldName: 'captcha4ChanCustomNumLetters',
    merger: PrimitiveMerger(),
  );
  static bool getTabMenuHidesWhenScrollingDown(SavedSettings x) =>
      x.tabMenuHidesWhenScrollingDown;
  static void setTabMenuHidesWhenScrollingDown(SavedSettings x, bool v) =>
      x.tabMenuHidesWhenScrollingDown = v;
  static const tabMenuHidesWhenScrollingDown =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getTabMenuHidesWhenScrollingDown,
    setter: setTabMenuHidesWhenScrollingDown,
    fieldNumber: 105,
    fieldName: 'tabMenuHidesWhenScrollingDown',
    merger: PrimitiveMerger(),
  );
  static bool getDoubleTapScrollToReplies(SavedSettings x) =>
      x.doubleTapScrollToReplies;
  static void setDoubleTapScrollToReplies(SavedSettings x, bool v) =>
      x.doubleTapScrollToReplies = v;
  static const doubleTapScrollToReplies = HiveFieldAdapter<SavedSettings, bool>(
    getter: getDoubleTapScrollToReplies,
    setter: setDoubleTapScrollToReplies,
    fieldNumber: 106,
    fieldName: 'doubleTapScrollToReplies',
    merger: PrimitiveMerger(),
  );
  static String? getLastUnifiedPushEndpoint(SavedSettings x) =>
      x.lastUnifiedPushEndpoint;
  static void setLastUnifiedPushEndpoint(SavedSettings x, String? v) =>
      x.lastUnifiedPushEndpoint = v;
  static const lastUnifiedPushEndpoint =
      HiveFieldAdapter<SavedSettings, String?>(
    getter: getLastUnifiedPushEndpoint,
    setter: setLastUnifiedPushEndpoint,
    fieldNumber: 107,
    fieldName: 'lastUnifiedPushEndpoint',
    merger: PrimitiveMerger(),
  );
  static WebImageSearchMethod getWebImageSearchMethod(SavedSettings x) =>
      x.webImageSearchMethod;
  static void setWebImageSearchMethod(
          SavedSettings x, WebImageSearchMethod v) =>
      x.webImageSearchMethod = v;
  static const webImageSearchMethod =
      HiveFieldAdapter<SavedSettings, WebImageSearchMethod>(
    getter: getWebImageSearchMethod,
    setter: setWebImageSearchMethod,
    fieldNumber: 108,
    fieldName: 'webImageSearchMethod',
    merger: PrimitiveMerger(),
  );
  static bool getShowIPNumberOnPosts(SavedSettings x) => x.showIPNumberOnPosts;
  static void setShowIPNumberOnPosts(SavedSettings x, bool v) =>
      x.showIPNumberOnPosts = v;
  static const showIPNumberOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowIPNumberOnPosts,
    setter: setShowIPNumberOnPosts,
    fieldNumber: 109,
    fieldName: 'showIPNumberOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getShowNoBeforeIdOnPosts(SavedSettings x) =>
      x.showNoBeforeIdOnPosts;
  static void setShowNoBeforeIdOnPosts(SavedSettings x, bool v) =>
      x.showNoBeforeIdOnPosts = v;
  static const showNoBeforeIdOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowNoBeforeIdOnPosts,
    setter: setShowNoBeforeIdOnPosts,
    fieldNumber: 110,
    fieldName: 'showNoBeforeIdOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getBlurEffects(SavedSettings x) => x.blurEffects;
  static void setBlurEffects(SavedSettings x, bool v) => x.blurEffects = v;
  static const blurEffects = HiveFieldAdapter<SavedSettings, bool>(
    getter: getBlurEffects,
    setter: setBlurEffects,
    fieldNumber: 111,
    fieldName: 'blurEffects',
    merger: PrimitiveMerger(),
  );
  static bool getScrollbarsOnLeft(SavedSettings x) => x.scrollbarsOnLeft;
  static void setScrollbarsOnLeft(SavedSettings x, bool v) =>
      x.scrollbarsOnLeft = v;
  static const scrollbarsOnLeft = HiveFieldAdapter<SavedSettings, bool>(
    getter: getScrollbarsOnLeft,
    setter: setScrollbarsOnLeft,
    fieldNumber: 112,
    fieldName: 'scrollbarsOnLeft',
    merger: PrimitiveMerger(),
  );
  static bool getExactTimeIsTwelveHour(SavedSettings x) =>
      x.exactTimeIsTwelveHour;
  static void setExactTimeIsTwelveHour(SavedSettings x, bool v) =>
      x.exactTimeIsTwelveHour = v;
  static const exactTimeIsTwelveHour = HiveFieldAdapter<SavedSettings, bool>(
    getter: getExactTimeIsTwelveHour,
    setter: setExactTimeIsTwelveHour,
    fieldNumber: 113,
    fieldName: 'exactTimeIsTwelveHour',
    merger: PrimitiveMerger(),
  );
  static bool getExactTimeShowsDateForToday(SavedSettings x) =>
      x.exactTimeShowsDateForToday;
  static void setExactTimeShowsDateForToday(SavedSettings x, bool v) =>
      x.exactTimeShowsDateForToday = v;
  static const exactTimeShowsDateForToday =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getExactTimeShowsDateForToday,
    setter: setExactTimeShowsDateForToday,
    fieldNumber: 114,
    fieldName: 'exactTimeShowsDateForToday',
    merger: PrimitiveMerger(),
  );
  static double getAttachmentsPageMaxCrossAxisExtent(SavedSettings x) =>
      x.attachmentsPageMaxCrossAxisExtent;
  static void setAttachmentsPageMaxCrossAxisExtent(SavedSettings x, double v) =>
      x.attachmentsPageMaxCrossAxisExtent = v;
  static const attachmentsPageMaxCrossAxisExtent =
      HiveFieldAdapter<SavedSettings, double>(
    getter: getAttachmentsPageMaxCrossAxisExtent,
    setter: setAttachmentsPageMaxCrossAxisExtent,
    fieldNumber: 115,
    fieldName: 'attachmentsPageMaxCrossAxisExtent',
    merger: PrimitiveMerger(),
  );
  static bool getCatalogGridModeCellBorderRadiusAndMargin(SavedSettings x) =>
      x.catalogGridModeCellBorderRadiusAndMargin;
  static void setCatalogGridModeCellBorderRadiusAndMargin(
          SavedSettings x, bool v) =>
      x.catalogGridModeCellBorderRadiusAndMargin = v;
  static const catalogGridModeCellBorderRadiusAndMargin =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCatalogGridModeCellBorderRadiusAndMargin,
    setter: setCatalogGridModeCellBorderRadiusAndMargin,
    fieldNumber: 116,
    fieldName: 'catalogGridModeCellBorderRadiusAndMargin',
    merger: PrimitiveMerger(),
  );
  static bool getCatalogGridModeShowMoreImageIfLessText(SavedSettings x) =>
      x.catalogGridModeShowMoreImageIfLessText;
  static void setCatalogGridModeShowMoreImageIfLessText(
          SavedSettings x, bool v) =>
      x.catalogGridModeShowMoreImageIfLessText = v;
  static const catalogGridModeShowMoreImageIfLessText =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCatalogGridModeShowMoreImageIfLessText,
    setter: setCatalogGridModeShowMoreImageIfLessText,
    fieldNumber: 117,
    fieldName: 'catalogGridModeShowMoreImageIfLessText',
    merger: PrimitiveMerger(),
  );
  static bool getShowPostNumberOnPosts(SavedSettings x) =>
      x.showPostNumberOnPosts;
  static void setShowPostNumberOnPosts(SavedSettings x, bool v) =>
      x.showPostNumberOnPosts = v;
  static const showPostNumberOnPosts = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowPostNumberOnPosts,
    setter: setShowPostNumberOnPosts,
    fieldNumber: 118,
    fieldName: 'showPostNumberOnPosts',
    merger: PrimitiveMerger(),
  );
  static bool getOverscrollModalTapPopsAll(SavedSettings x) =>
      x.overscrollModalTapPopsAll;
  static void setOverscrollModalTapPopsAll(SavedSettings x, bool v) =>
      x.overscrollModalTapPopsAll = v;
  static const overscrollModalTapPopsAll =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getOverscrollModalTapPopsAll,
    setter: setOverscrollModalTapPopsAll,
    fieldNumber: 119,
    fieldName: 'overscrollModalTapPopsAll',
    merger: PrimitiveMerger(),
  );
  static bool getSquareThumbnails(SavedSettings x) => x.squareThumbnails;
  static void setSquareThumbnails(SavedSettings x, bool v) =>
      x.squareThumbnails = v;
  static const squareThumbnails = HiveFieldAdapter<SavedSettings, bool>(
    getter: getSquareThumbnails,
    setter: setSquareThumbnails,
    fieldNumber: 120,
    fieldName: 'squareThumbnails',
    merger: PrimitiveMerger(),
  );
  static bool getAlwaysShowSpoilers(SavedSettings x) => x.alwaysShowSpoilers;
  static void setAlwaysShowSpoilers(SavedSettings x, bool v) =>
      x.alwaysShowSpoilers = v;
  static const alwaysShowSpoilers = HiveFieldAdapter<SavedSettings, bool>(
    getter: getAlwaysShowSpoilers,
    setter: setAlwaysShowSpoilers,
    fieldNumber: 121,
    fieldName: 'alwaysShowSpoilers',
    merger: PrimitiveMerger(),
  );
  static GallerySavePathOrganizing getGallerySavePathOrganizing(
          SavedSettings x) =>
      x.gallerySavePathOrganizing;
  static void setGallerySavePathOrganizing(
          SavedSettings x, GallerySavePathOrganizing v) =>
      x.gallerySavePathOrganizing = v;
  static const gallerySavePathOrganizing =
      HiveFieldAdapter<SavedSettings, GallerySavePathOrganizing>(
    getter: getGallerySavePathOrganizing,
    setter: setGallerySavePathOrganizing,
    fieldNumber: 122,
    fieldName: 'gallerySavePathOrganizing',
    merger: PrimitiveMerger(),
  );
  static AutoloadAttachmentsSetting getFullQualityThumbnails(SavedSettings x) =>
      x.fullQualityThumbnails;
  static void setFullQualityThumbnails(
          SavedSettings x, AutoloadAttachmentsSetting v) =>
      x.fullQualityThumbnails = v;
  static const fullQualityThumbnails =
      HiveFieldAdapter<SavedSettings, AutoloadAttachmentsSetting>(
    getter: getFullQualityThumbnails,
    setter: setFullQualityThumbnails,
    fieldNumber: 123,
    fieldName: 'fullQualityThumbnails',
    merger: PrimitiveMerger(),
  );
  static bool getRecordThreadsInHistory(SavedSettings x) =>
      x.recordThreadsInHistory;
  static void setRecordThreadsInHistory(SavedSettings x, bool v) =>
      x.recordThreadsInHistory = v;
  static const recordThreadsInHistory = HiveFieldAdapter<SavedSettings, bool>(
    getter: getRecordThreadsInHistory,
    setter: setRecordThreadsInHistory,
    fieldNumber: 124,
    fieldName: 'recordThreadsInHistory',
    merger: PrimitiveMerger(),
  );
  static String? getFontFamily(SavedSettings x) => x.fontFamily;
  static void setFontFamily(SavedSettings x, String? v) => x.fontFamily = v;
  static const fontFamily = HiveFieldAdapter<SavedSettings, String?>(
    getter: getFontFamily,
    setter: setFontFamily,
    fieldNumber: 125,
    fieldName: 'fontFamily',
    merger: PrimitiveMerger(),
  );
  static AutoloadAttachmentsSetting getAutoCacheAttachments(SavedSettings x) =>
      x.autoCacheAttachments;
  static void setAutoCacheAttachments(
          SavedSettings x, AutoloadAttachmentsSetting v) =>
      x.autoCacheAttachments = v;
  static const autoCacheAttachments =
      HiveFieldAdapter<SavedSettings, AutoloadAttachmentsSetting>(
    getter: getAutoCacheAttachments,
    setter: setAutoCacheAttachments,
    fieldNumber: 126,
    fieldName: 'autoCacheAttachments',
    merger: PrimitiveMerger(),
  );
  static bool getExactTimeUsesCustomDateFormat(SavedSettings x) =>
      x.exactTimeUsesCustomDateFormat;
  static void setExactTimeUsesCustomDateFormat(SavedSettings x, bool v) =>
      x.exactTimeUsesCustomDateFormat = v;
  static const exactTimeUsesCustomDateFormat =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getExactTimeUsesCustomDateFormat,
    setter: setExactTimeUsesCustomDateFormat,
    fieldNumber: 127,
    fieldName: 'exactTimeUsesCustomDateFormat',
    merger: PrimitiveMerger(),
  );
  static bool getShowOverlaysInGallery(SavedSettings x) =>
      x.showOverlaysInGallery;
  static void setShowOverlaysInGallery(SavedSettings x, bool v) =>
      x.showOverlaysInGallery = v;
  static const showOverlaysInGallery = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowOverlaysInGallery,
    setter: setShowOverlaysInGallery,
    fieldNumber: 129,
    fieldName: 'showOverlaysInGallery',
    merger: PrimitiveMerger(),
  );
  static double getVerticalTwoPaneMinimumPaneSize(SavedSettings x) =>
      x.verticalTwoPaneMinimumPaneSize;
  static void setVerticalTwoPaneMinimumPaneSize(SavedSettings x, double v) =>
      x.verticalTwoPaneMinimumPaneSize = v;
  static const verticalTwoPaneMinimumPaneSize =
      HiveFieldAdapter<SavedSettings, double>(
    getter: getVerticalTwoPaneMinimumPaneSize,
    setter: setVerticalTwoPaneMinimumPaneSize,
    fieldNumber: 130,
    fieldName: 'verticalTwoPaneMinimumPaneSize',
    merger: PrimitiveMerger(),
  );
  static Set<String> getHiddenImageMD5s(SavedSettings x) => x.hiddenImageMD5s;
  static void setHiddenImageMD5s(SavedSettings x, Set<String> v) =>
      x.hiddenImageMD5s = v;
  static const hiddenImageMD5s = HiveFieldAdapter<SavedSettings, Set<String>>(
    getter: getHiddenImageMD5s,
    setter: setHiddenImageMD5s,
    fieldNumber: 131,
    fieldName: 'hiddenImageMD5s',
    merger: PrimitiveSetMerger(),
  );
  static bool getShowLastRepliesInCatalog(SavedSettings x) =>
      x.showLastRepliesInCatalog;
  static void setShowLastRepliesInCatalog(SavedSettings x, bool v) =>
      x.showLastRepliesInCatalog = v;
  static const showLastRepliesInCatalog = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowLastRepliesInCatalog,
    setter: setShowLastRepliesInCatalog,
    fieldNumber: 132,
    fieldName: 'showLastRepliesInCatalog',
    merger: PrimitiveMerger(),
  );
  static AutoloadAttachmentsSetting getLoadThumbnails(SavedSettings x) =>
      x.loadThumbnails;
  static void setLoadThumbnails(
          SavedSettings x, AutoloadAttachmentsSetting v) =>
      x.loadThumbnails = v;
  static const loadThumbnails =
      HiveFieldAdapter<SavedSettings, AutoloadAttachmentsSetting>(
    getter: getLoadThumbnails,
    setter: setLoadThumbnails,
    fieldNumber: 133,
    fieldName: 'loadThumbnails',
    merger: PrimitiveMerger(),
  );
  static bool getApplyImageFilterToThreads(SavedSettings x) =>
      x.applyImageFilterToThreads;
  static void setApplyImageFilterToThreads(SavedSettings x, bool v) =>
      x.applyImageFilterToThreads = v;
  static const applyImageFilterToThreads =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getApplyImageFilterToThreads,
    setter: setApplyImageFilterToThreads,
    fieldNumber: 134,
    fieldName: 'applyImageFilterToThreads',
    merger: PrimitiveMerger(),
  );
  static bool getAskForAuthenticationOnLaunch(SavedSettings x) =>
      x.askForAuthenticationOnLaunch;
  static void setAskForAuthenticationOnLaunch(SavedSettings x, bool v) =>
      x.askForAuthenticationOnLaunch = v;
  static const askForAuthenticationOnLaunch =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getAskForAuthenticationOnLaunch,
    setter: setAskForAuthenticationOnLaunch,
    fieldNumber: 135,
    fieldName: 'askForAuthenticationOnLaunch',
    merger: PrimitiveMerger(),
  );
  static bool getEnableSpellCheck(SavedSettings x) => x.enableSpellCheck;
  static void setEnableSpellCheck(SavedSettings x, bool v) =>
      x.enableSpellCheck = v;
  static const enableSpellCheck = HiveFieldAdapter<SavedSettings, bool>(
    getter: getEnableSpellCheck,
    setter: setEnableSpellCheck,
    fieldNumber: 136,
    fieldName: 'enableSpellCheck',
    merger: PrimitiveMerger(),
  );
  static bool getOpenCrossThreadLinksInNewTab(SavedSettings x) =>
      x.openCrossThreadLinksInNewTab;
  static void setOpenCrossThreadLinksInNewTab(SavedSettings x, bool v) =>
      x.openCrossThreadLinksInNewTab = v;
  static const openCrossThreadLinksInNewTab =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getOpenCrossThreadLinksInNewTab,
    setter: setOpenCrossThreadLinksInNewTab,
    fieldNumber: 137,
    fieldName: 'openCrossThreadLinksInNewTab',
    merger: PrimitiveMerger(),
  );
  static int getBackgroundThreadAutoUpdatePeriodSeconds(SavedSettings x) =>
      x.backgroundThreadAutoUpdatePeriodSeconds;
  static void setBackgroundThreadAutoUpdatePeriodSeconds(
          SavedSettings x, int v) =>
      x.backgroundThreadAutoUpdatePeriodSeconds = v;
  static const backgroundThreadAutoUpdatePeriodSeconds =
      HiveFieldAdapter<SavedSettings, int>(
    getter: getBackgroundThreadAutoUpdatePeriodSeconds,
    setter: setBackgroundThreadAutoUpdatePeriodSeconds,
    fieldNumber: 138,
    fieldName: 'backgroundThreadAutoUpdatePeriodSeconds',
    merger: PrimitiveMerger(),
  );
  static int getCurrentThreadAutoUpdatePeriodSeconds(SavedSettings x) =>
      x.currentThreadAutoUpdatePeriodSeconds;
  static void setCurrentThreadAutoUpdatePeriodSeconds(SavedSettings x, int v) =>
      x.currentThreadAutoUpdatePeriodSeconds = v;
  static const currentThreadAutoUpdatePeriodSeconds =
      HiveFieldAdapter<SavedSettings, int>(
    getter: getCurrentThreadAutoUpdatePeriodSeconds,
    setter: setCurrentThreadAutoUpdatePeriodSeconds,
    fieldNumber: 139,
    fieldName: 'currentThreadAutoUpdatePeriodSeconds',
    merger: PrimitiveMerger(),
  );
  static ShareablePostsStyle getLastShareablePostsStyle(SavedSettings x) =>
      x.lastShareablePostsStyle;
  static void setLastShareablePostsStyle(
          SavedSettings x, ShareablePostsStyle v) =>
      x.lastShareablePostsStyle = v;
  static const lastShareablePostsStyle =
      HiveFieldAdapter<SavedSettings, ShareablePostsStyle>(
    getter: getLastShareablePostsStyle,
    setter: setLastShareablePostsStyle,
    fieldNumber: 140,
    fieldName: 'lastShareablePostsStyle',
    merger: AdaptedMerger(ShareablePostsStyleAdapter.kTypeId),
  );
  static ThreadWatch? getDefaultThreadWatch(SavedSettings x) =>
      x.defaultThreadWatch;
  static void setDefaultThreadWatch(SavedSettings x, ThreadWatch? v) =>
      x.defaultThreadWatch = v;
  static const defaultThreadWatch =
      HiveFieldAdapter<SavedSettings, ThreadWatch?>(
    getter: getDefaultThreadWatch,
    setter: setDefaultThreadWatch,
    fieldNumber: 141,
    fieldName: 'defaultThreadWatch',
    merger: NullableMerger(AdaptedMerger(ThreadWatchAdapter.kTypeId)),
  );
  static bool getHighlightRepeatingDigitsInPostIds(SavedSettings x) =>
      x.highlightRepeatingDigitsInPostIds;
  static void setHighlightRepeatingDigitsInPostIds(SavedSettings x, bool v) =>
      x.highlightRepeatingDigitsInPostIds = v;
  static const highlightRepeatingDigitsInPostIds =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getHighlightRepeatingDigitsInPostIds,
    setter: setHighlightRepeatingDigitsInPostIds,
    fieldNumber: 142,
    fieldName: 'highlightRepeatingDigitsInPostIds',
    merger: PrimitiveMerger(),
  );
  static bool getIncludeThreadsYouRepliedToWhenDeletingHistory(
          SavedSettings x) =>
      x.includeThreadsYouRepliedToWhenDeletingHistory;
  static void setIncludeThreadsYouRepliedToWhenDeletingHistory(
          SavedSettings x, bool v) =>
      x.includeThreadsYouRepliedToWhenDeletingHistory = v;
  static const includeThreadsYouRepliedToWhenDeletingHistory =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getIncludeThreadsYouRepliedToWhenDeletingHistory,
    setter: setIncludeThreadsYouRepliedToWhenDeletingHistory,
    fieldNumber: 143,
    fieldName: 'includeThreadsYouRepliedToWhenDeletingHistory',
    merger: PrimitiveMerger(),
  );
  static double getNewPostHighlightBrightness(SavedSettings x) =>
      x.newPostHighlightBrightness;
  static void setNewPostHighlightBrightness(SavedSettings x, double v) =>
      x.newPostHighlightBrightness = v;
  static const newPostHighlightBrightness =
      HiveFieldAdapter<SavedSettings, double>(
    getter: getNewPostHighlightBrightness,
    setter: setNewPostHighlightBrightness,
    fieldNumber: 144,
    fieldName: 'newPostHighlightBrightness',
    merger: PrimitiveMerger(),
  );
  static ImagePeekingSetting getImagePeeking(SavedSettings x) => x.imagePeeking;
  static void setImagePeeking(SavedSettings x, ImagePeekingSetting v) =>
      x.imagePeeking = v;
  static const imagePeeking =
      HiveFieldAdapter<SavedSettings, ImagePeekingSetting>(
    getter: getImagePeeking,
    setter: setImagePeeking,
    fieldNumber: 145,
    fieldName: 'imagePeeking',
    merger: PrimitiveMerger(),
  );
  static bool? getUseMaterialStyle(SavedSettings x) => x.useMaterialStyle;
  static void setUseMaterialStyle(SavedSettings x, bool? v) =>
      x.useMaterialStyle = v;
  static const useMaterialStyle = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseMaterialStyle,
    setter: setUseMaterialStyle,
    fieldNumber: 146,
    fieldName: 'useMaterialStyle',
    merger: PrimitiveMerger(),
  );
  static bool? getUseAndroidDrawer(SavedSettings x) => x.useAndroidDrawer;
  static void setUseAndroidDrawer(SavedSettings x, bool? v) =>
      x.useAndroidDrawer = v;
  static const useAndroidDrawer = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseAndroidDrawer,
    setter: setUseAndroidDrawer,
    fieldNumber: 147,
    fieldName: 'useAndroidDrawer',
    merger: PrimitiveMerger(),
  );
  static bool? getUseMaterialRoutes(SavedSettings x) => x.useMaterialRoutes;
  static void setUseMaterialRoutes(SavedSettings x, bool? v) =>
      x.useMaterialRoutes = v;
  static const useMaterialRoutes = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseMaterialRoutes,
    setter: setUseMaterialRoutes,
    fieldNumber: 148,
    fieldName: 'useMaterialRoutes',
    merger: PrimitiveMerger(),
  );
  static bool getHideBarsWhenScrollingDown(SavedSettings x) =>
      x.hideBarsWhenScrollingDown;
  static void setHideBarsWhenScrollingDown(SavedSettings x, bool v) =>
      x.hideBarsWhenScrollingDown = v;
  static const hideBarsWhenScrollingDown =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getHideBarsWhenScrollingDown,
    setter: setHideBarsWhenScrollingDown,
    fieldNumber: 149,
    fieldName: 'hideBarsWhenScrollingDown',
    merger: PrimitiveMerger(),
  );
  static bool getShowPerformanceOverlay(SavedSettings x) =>
      x.showPerformanceOverlay;
  static void setShowPerformanceOverlay(SavedSettings x, bool v) =>
      x.showPerformanceOverlay = v;
  static const showPerformanceOverlay = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowPerformanceOverlay,
    setter: setShowPerformanceOverlay,
    fieldNumber: 150,
    fieldName: 'showPerformanceOverlay',
    merger: PrimitiveMerger(),
  );
  static String getCustomDateFormat(SavedSettings x) => x.customDateFormat;
  static void setCustomDateFormat(SavedSettings x, String v) =>
      x.customDateFormat = v;
  static const customDateFormat = HiveFieldAdapter<SavedSettings, String>(
    getter: getCustomDateFormat,
    setter: setCustomDateFormat,
    fieldNumber: 151,
    fieldName: 'customDateFormat',
    merger: PrimitiveMerger(),
  );
  static int getHoverPopupDelayMilliseconds(SavedSettings x) =>
      x.hoverPopupDelayMilliseconds;
  static void setHoverPopupDelayMilliseconds(SavedSettings x, int v) =>
      x.hoverPopupDelayMilliseconds = v;
  static const hoverPopupDelayMilliseconds =
      HiveFieldAdapter<SavedSettings, int>(
    getter: getHoverPopupDelayMilliseconds,
    setter: setHoverPopupDelayMilliseconds,
    fieldNumber: 152,
    fieldName: 'hoverPopupDelayMilliseconds',
    merger: PrimitiveMerger(),
  );
  static MouseModeQuoteLinkBehavior getMouseModeQuoteLinkBehavior(
          SavedSettings x) =>
      x.mouseModeQuoteLinkBehavior;
  static void setMouseModeQuoteLinkBehavior(
          SavedSettings x, MouseModeQuoteLinkBehavior v) =>
      x.mouseModeQuoteLinkBehavior = v;
  static const mouseModeQuoteLinkBehavior =
      HiveFieldAdapter<SavedSettings, MouseModeQuoteLinkBehavior>(
    getter: getMouseModeQuoteLinkBehavior,
    setter: setMouseModeQuoteLinkBehavior,
    fieldNumber: 153,
    fieldName: 'mouseModeQuoteLinkBehavior',
    merger: PrimitiveMerger(),
  );
  static DrawerMode getDrawerMode(SavedSettings x) => x.drawerMode;
  static void setDrawerMode(SavedSettings x, DrawerMode v) => x.drawerMode = v;
  static const drawerMode = HiveFieldAdapter<SavedSettings, DrawerMode>(
    getter: getDrawerMode,
    setter: setDrawerMode,
    fieldNumber: 154,
    fieldName: 'drawerMode',
    merger: PrimitiveMerger(),
  );
  static bool getShowLineBreakInPostInfoRow(SavedSettings x) =>
      x.showLineBreakInPostInfoRow;
  static void setShowLineBreakInPostInfoRow(SavedSettings x, bool v) =>
      x.showLineBreakInPostInfoRow = v;
  static const showLineBreakInPostInfoRow =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowLineBreakInPostInfoRow,
    setter: setShowLineBreakInPostInfoRow,
    fieldNumber: 155,
    fieldName: 'showLineBreakInPostInfoRow',
    merger: PrimitiveMerger(),
  );
  static bool? getUseCloudCaptchaSolver(SavedSettings x) =>
      x.useCloudCaptchaSolver;
  static void setUseCloudCaptchaSolver(SavedSettings x, bool? v) =>
      x.useCloudCaptchaSolver = v;
  static const useCloudCaptchaSolver = HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseCloudCaptchaSolver,
    setter: setUseCloudCaptchaSolver,
    fieldNumber: 156,
    fieldName: 'useCloudCaptchaSolver',
    merger: PrimitiveMerger(),
  );
  static bool? getUseHeadlessCloudCaptchaSolver(SavedSettings x) =>
      x.useHeadlessCloudCaptchaSolver;
  static void setUseHeadlessCloudCaptchaSolver(SavedSettings x, bool? v) =>
      x.useHeadlessCloudCaptchaSolver = v;
  static const useHeadlessCloudCaptchaSolver =
      HiveFieldAdapter<SavedSettings, bool?>(
    getter: getUseHeadlessCloudCaptchaSolver,
    setter: setUseHeadlessCloudCaptchaSolver,
    fieldNumber: 157,
    fieldName: 'useHeadlessCloudCaptchaSolver',
    merger: PrimitiveMerger(),
  );
  static bool getRemoveMetadataOnUploadedFiles(SavedSettings x) =>
      x.removeMetadataOnUploadedFiles;
  static void setRemoveMetadataOnUploadedFiles(SavedSettings x, bool v) =>
      x.removeMetadataOnUploadedFiles = v;
  static const removeMetadataOnUploadedFiles =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getRemoveMetadataOnUploadedFiles,
    setter: setRemoveMetadataOnUploadedFiles,
    fieldNumber: 158,
    fieldName: 'removeMetadataOnUploadedFiles',
    merger: PrimitiveMerger(),
  );
  static bool getRandomizeChecksumOnUploadedFiles(SavedSettings x) =>
      x.randomizeChecksumOnUploadedFiles;
  static void setRandomizeChecksumOnUploadedFiles(SavedSettings x, bool v) =>
      x.randomizeChecksumOnUploadedFiles = v;
  static const randomizeChecksumOnUploadedFiles =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getRandomizeChecksumOnUploadedFiles,
    setter: setRandomizeChecksumOnUploadedFiles,
    fieldNumber: 159,
    fieldName: 'randomizeChecksumOnUploadedFiles',
    merger: PrimitiveMerger(),
  );
  static List<String> getRecentWebImageSearches(SavedSettings x) =>
      x.recentWebImageSearches;
  static void setRecentWebImageSearches(SavedSettings x, List<String> v) =>
      x.recentWebImageSearches = v;
  static const recentWebImageSearches =
      HiveFieldAdapter<SavedSettings, List<String>>(
    getter: getRecentWebImageSearches,
    setter: setRecentWebImageSearches,
    fieldNumber: 160,
    fieldName: 'recentWebImageSearches',
    merger: OrderedSetLikePrimitiveListMerger<String>(),
  );
  static bool getCloverStyleRepliesButton(SavedSettings x) =>
      x.cloverStyleRepliesButton;
  static void setCloverStyleRepliesButton(SavedSettings x, bool v) =>
      x.cloverStyleRepliesButton = v;
  static const cloverStyleRepliesButton = HiveFieldAdapter<SavedSettings, bool>(
    getter: getCloverStyleRepliesButton,
    setter: setCloverStyleRepliesButton,
    fieldNumber: 161,
    fieldName: 'cloverStyleRepliesButton',
    merger: PrimitiveMerger(),
  );
  static bool getWatchThreadAutomaticallyWhenReplying(SavedSettings x) =>
      x.watchThreadAutomaticallyWhenReplying;
  static void setWatchThreadAutomaticallyWhenReplying(
          SavedSettings x, bool v) =>
      x.watchThreadAutomaticallyWhenReplying = v;
  static const watchThreadAutomaticallyWhenReplying =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getWatchThreadAutomaticallyWhenReplying,
    setter: setWatchThreadAutomaticallyWhenReplying,
    fieldNumber: 162,
    fieldName: 'watchThreadAutomaticallyWhenReplying',
    merger: PrimitiveMerger(),
  );
  static bool getSaveThreadAutomaticallyWhenReplying(SavedSettings x) =>
      x.saveThreadAutomaticallyWhenReplying;
  static void setSaveThreadAutomaticallyWhenReplying(SavedSettings x, bool v) =>
      x.saveThreadAutomaticallyWhenReplying = v;
  static const saveThreadAutomaticallyWhenReplying =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getSaveThreadAutomaticallyWhenReplying,
    setter: setSaveThreadAutomaticallyWhenReplying,
    fieldNumber: 163,
    fieldName: 'saveThreadAutomaticallyWhenReplying',
    merger: PrimitiveMerger(),
  );
  static bool getCancellableRepliesSlideGesture(SavedSettings x) =>
      x.cancellableRepliesSlideGesture;
  static void setCancellableRepliesSlideGesture(SavedSettings x, bool v) =>
      x.cancellableRepliesSlideGesture = v;
  static const cancellableRepliesSlideGesture =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCancellableRepliesSlideGesture,
    setter: setCancellableRepliesSlideGesture,
    fieldNumber: 164,
    fieldName: 'cancellableRepliesSlideGesture',
    merger: PrimitiveMerger(),
  );
  static bool getOpenBoardSwitcherSlideGesture(SavedSettings x) =>
      x.openBoardSwitcherSlideGesture;
  static void setOpenBoardSwitcherSlideGesture(SavedSettings x, bool v) =>
      x.openBoardSwitcherSlideGesture = v;
  static const openBoardSwitcherSlideGesture =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getOpenBoardSwitcherSlideGesture,
    setter: setOpenBoardSwitcherSlideGesture,
    fieldNumber: 165,
    fieldName: 'openBoardSwitcherSlideGesture',
    merger: PrimitiveMerger(),
  );
  static bool getPersistentDrawer(SavedSettings x) => x.persistentDrawer;
  static void setPersistentDrawer(SavedSettings x, bool v) =>
      x.persistentDrawer = v;
  static const persistentDrawer = HiveFieldAdapter<SavedSettings, bool>(
    getter: getPersistentDrawer,
    setter: setPersistentDrawer,
    fieldNumber: 166,
    fieldName: 'persistentDrawer',
    merger: PrimitiveMerger(),
  );
  static bool getShowGalleryGridButton(SavedSettings x) =>
      x.showGalleryGridButton;
  static void setShowGalleryGridButton(SavedSettings x, bool v) =>
      x.showGalleryGridButton = v;
  static const showGalleryGridButton = HiveFieldAdapter<SavedSettings, bool>(
    getter: getShowGalleryGridButton,
    setter: setShowGalleryGridButton,
    fieldNumber: 167,
    fieldName: 'showGalleryGridButton',
    merger: PrimitiveMerger(),
  );
  static double getCenteredPostThumbnailSize(SavedSettings x) =>
      x.centeredPostThumbnailSize;
  static void setCenteredPostThumbnailSize(SavedSettings x, double v) =>
      x.centeredPostThumbnailSize = v;
  static const centeredPostThumbnailSize =
      HiveFieldAdapter<SavedSettings, double>(
    getter: getCenteredPostThumbnailSize,
    setter: setCenteredPostThumbnailSize,
    fieldNumber: 168,
    fieldName: 'centeredPostThumbnailSize',
    merger: PrimitiveMerger(),
  );
  static bool getEllipsizeLongFilenamesOnPosts(SavedSettings x) =>
      x.ellipsizeLongFilenamesOnPosts;
  static void setEllipsizeLongFilenamesOnPosts(SavedSettings x, bool v) =>
      x.ellipsizeLongFilenamesOnPosts = v;
  static const ellipsizeLongFilenamesOnPosts =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getEllipsizeLongFilenamesOnPosts,
    setter: setEllipsizeLongFilenamesOnPosts,
    fieldNumber: 169,
    fieldName: 'ellipsizeLongFilenamesOnPosts',
    merger: PrimitiveMerger(),
  );
  static TristateSystemSetting getMuteAudioWhenOpeningGallery(
          SavedSettings x) =>
      x.muteAudioWhenOpeningGallery;
  static void setMuteAudioWhenOpeningGallery(
          SavedSettings x, TristateSystemSetting v) =>
      x.muteAudioWhenOpeningGallery = v;
  static const muteAudioWhenOpeningGallery =
      HiveFieldAdapter<SavedSettings, TristateSystemSetting>(
    getter: getMuteAudioWhenOpeningGallery,
    setter: setMuteAudioWhenOpeningGallery,
    fieldNumber: 170,
    fieldName: 'muteAudioWhenOpeningGallery',
    merger: PrimitiveMerger(),
  );
  static String getTranslationTargetLanguage(SavedSettings x) =>
      x.translationTargetLanguage;
  static void setTranslationTargetLanguage(SavedSettings x, String v) =>
      x.translationTargetLanguage = v;
  static const translationTargetLanguage =
      HiveFieldAdapter<SavedSettings, String>(
    getter: getTranslationTargetLanguage,
    setter: setTranslationTargetLanguage,
    fieldNumber: 171,
    fieldName: 'translationTargetLanguage',
    merger: PrimitiveMerger(),
  );
  static String? getHomeImageboardKey(SavedSettings x) => x.homeImageboardKey;
  static void setHomeImageboardKey(SavedSettings x, String? v) =>
      x.homeImageboardKey = v;
  static const homeImageboardKey = HiveFieldAdapter<SavedSettings, String?>(
    getter: getHomeImageboardKey,
    setter: setHomeImageboardKey,
    fieldNumber: 172,
    fieldName: 'homeImageboardKey',
    merger: PrimitiveMerger(),
  );
  static String getHomeBoardName(SavedSettings x) => x.homeBoardName;
  static void setHomeBoardName(SavedSettings x, String v) =>
      x.homeBoardName = v;
  static const homeBoardName = HiveFieldAdapter<SavedSettings, String>(
    getter: getHomeBoardName,
    setter: setHomeBoardName,
    fieldNumber: 173,
    fieldName: 'homeBoardName',
    merger: PrimitiveMerger(),
  );
  static bool getTapPostIdToReply(SavedSettings x) => x.tapPostIdToReply;
  static void setTapPostIdToReply(SavedSettings x, bool v) =>
      x.tapPostIdToReply = v;
  static const tapPostIdToReply = HiveFieldAdapter<SavedSettings, bool>(
    getter: getTapPostIdToReply,
    setter: setTapPostIdToReply,
    fieldNumber: 174,
    fieldName: 'tapPostIdToReply',
    merger: PrimitiveMerger(),
  );
  static bool getDownloadUsingServerSideFilenames(SavedSettings x) =>
      x.downloadUsingServerSideFilenames;
  static void setDownloadUsingServerSideFilenames(SavedSettings x, bool v) =>
      x.downloadUsingServerSideFilenames = v;
  static const downloadUsingServerSideFilenames =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getDownloadUsingServerSideFilenames,
    setter: setDownloadUsingServerSideFilenames,
    fieldNumber: 175,
    fieldName: 'downloadUsingServerSideFilenames',
    merger: PrimitiveMerger(),
  );
  static double getCatalogGridModeTextScale(SavedSettings x) =>
      x.catalogGridModeTextScale;
  static void setCatalogGridModeTextScale(SavedSettings x, double v) =>
      x.catalogGridModeTextScale = v;
  static const catalogGridModeTextScale =
      HiveFieldAdapter<SavedSettings, double>(
    getter: getCatalogGridModeTextScale,
    setter: setCatalogGridModeTextScale,
    fieldNumber: 176,
    fieldName: 'catalogGridModeTextScale',
    merger: PrimitiveMerger(),
  );
  static bool getCatalogGridModeCropThumbnails(SavedSettings x) =>
      x.catalogGridModeCropThumbnails;
  static void setCatalogGridModeCropThumbnails(SavedSettings x, bool v) =>
      x.catalogGridModeCropThumbnails = v;
  static const catalogGridModeCropThumbnails =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCatalogGridModeCropThumbnails,
    setter: setCatalogGridModeCropThumbnails,
    fieldNumber: 177,
    fieldName: 'catalogGridModeCropThumbnails',
    merger: PrimitiveMerger(),
  );
  static bool getUseSpamFilterWorkarounds(SavedSettings x) =>
      x.useSpamFilterWorkarounds;
  static void setUseSpamFilterWorkarounds(SavedSettings x, bool v) =>
      x.useSpamFilterWorkarounds = v;
  static const useSpamFilterWorkarounds = HiveFieldAdapter<SavedSettings, bool>(
    getter: getUseSpamFilterWorkarounds,
    setter: setUseSpamFilterWorkarounds,
    fieldNumber: 178,
    fieldName: 'useSpamFilterWorkarounds',
    merger: PrimitiveMerger(),
  );
  static double getScrollbarThickness(SavedSettings x) => x.scrollbarThickness;
  static void setScrollbarThickness(SavedSettings x, double v) =>
      x.scrollbarThickness = v;
  static const scrollbarThickness = HiveFieldAdapter<SavedSettings, double>(
    getter: getScrollbarThickness,
    setter: setScrollbarThickness,
    fieldNumber: 179,
    fieldName: 'scrollbarThickness',
    merger: PrimitiveMerger(),
  );
  static int getThumbnailPixelation(SavedSettings x) => x.thumbnailPixelation;
  static void setThumbnailPixelation(SavedSettings x, int v) =>
      x.thumbnailPixelation = v;
  static const thumbnailPixelation = HiveFieldAdapter<SavedSettings, int>(
    getter: getThumbnailPixelation,
    setter: setThumbnailPixelation,
    fieldNumber: 180,
    fieldName: 'thumbnailPixelation',
    merger: PrimitiveMerger(),
  );
  static bool getCatalogGridModeTextAboveAttachment(SavedSettings x) =>
      x.catalogGridModeTextAboveAttachment;
  static void setCatalogGridModeTextAboveAttachment(SavedSettings x, bool v) =>
      x.catalogGridModeTextAboveAttachment = v;
  static const catalogGridModeTextAboveAttachment =
      HiveFieldAdapter<SavedSettings, bool>(
    getter: getCatalogGridModeTextAboveAttachment,
    setter: setCatalogGridModeTextAboveAttachment,
    fieldNumber: 181,
    fieldName: 'catalogGridModeTextAboveAttachment',
    merger: PrimitiveMerger(),
  );
}

class SavedSettingsAdapter extends TypeAdapter<SavedSettings> {
  const SavedSettingsAdapter();

  static const int kTypeId = 0;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<SavedSettings, dynamic>> fields =
      const {
    0: SavedSettingsFields.autoloadAttachments,
    1: SavedSettingsFields.theme,
    2: SavedSettingsFields.hideOldStickiedThreads,
    5: SavedSettingsFields.savedThreadsSortingMethod,
    6: SavedSettingsFields.autoRotateInGallery,
    9: SavedSettingsFields.useTouchLayout,
    10: SavedSettingsFields.userId,
    11: SavedSettingsFields.contentSettings,
    13: SavedSettingsFields.filterConfiguration,
    14: SavedSettingsFields.boardSwitcherHasKeyboardFocus,
    18: SavedSettingsFields.browserStateBySite,
    19: SavedSettingsFields.savedPostsBySite,
    20: SavedSettingsFields.savedAttachmentsBySite,
    22: SavedSettingsFields.twoPaneBreakpoint,
    23: SavedSettingsFields.twoPaneSplit,
    24: SavedSettingsFields.useCatalogGrid,
    25: SavedSettingsFields.catalogGridWidth,
    26: SavedSettingsFields.catalogGridHeight,
    27: SavedSettingsFields.showImageCountInCatalog,
    28: SavedSettingsFields.showClockIconInCatalog,
    30: SavedSettingsFields.supportMouse,
    31: SavedSettingsFields.showNameInCatalog,
    32: SavedSettingsFields.interfaceScale,
    33: SavedSettingsFields.showAnimations,
    34: SavedSettingsFields.imagesOnRight,
    35: SavedSettingsFields.androidGallerySavePath,
    36: SavedSettingsFields.replyBoxHeightOffset,
    37: SavedSettingsFields.blurThumbnails,
    38: SavedSettingsFields.showTimeInCatalogHeader,
    39: SavedSettingsFields.showTimeInCatalogStats,
    40: SavedSettingsFields.showIdInCatalogHeader,
    41: SavedSettingsFields.showFlagInCatalogHeader,
    42: SavedSettingsFields.onlyShowFavouriteBoardsInSwitcher,
    43: SavedSettingsFields.useBoardSwitcherList,
    44: SavedSettingsFields.contributeCaptchas,
    45: SavedSettingsFields.showReplyCountsInGallery,
    46: SavedSettingsFields.useNewCaptchaForm,
    47: SavedSettingsFields.autoLoginOnMobileNetwork,
    48: SavedSettingsFields.showScrollbars,
    49: SavedSettingsFields.randomizeFilenames,
    50: SavedSettingsFields.showNameOnPosts,
    51: SavedSettingsFields.showTripOnPosts,
    52: SavedSettingsFields.showAbsoluteTimeOnPosts,
    53: SavedSettingsFields.showRelativeTimeOnPosts,
    54: SavedSettingsFields.showCountryNameOnPosts,
    55: SavedSettingsFields.showPassOnPosts,
    56: SavedSettingsFields.showFilenameOnPosts,
    57: SavedSettingsFields.showFilesizeOnPosts,
    58: SavedSettingsFields.showFileDimensionsOnPosts,
    59: SavedSettingsFields.showFlagOnPosts,
    60: SavedSettingsFields.thumbnailSize,
    61: SavedSettingsFields.muteAudio,
    62: SavedSettingsFields.usePushNotifications,
    63: SavedSettingsFields.useEmbeds,
    64: SavedSettingsFields.useInternalBrowser,
    65: SavedSettingsFields.automaticCacheClearDays,
    66: SavedSettingsFields.alwaysAutoloadTappedAttachment,
    67: SavedSettingsFields.postDisplayFieldOrder,
    68: SavedSettingsFields.maximumImageUploadDimension,
    69: SavedSettingsFields.tabs,
    70: SavedSettingsFields.currentTabIndex,
    71: SavedSettingsFields.recentSearches,
    72: SavedSettingsFields.hideDefaultNamesOnPosts,
    73: SavedSettingsFields.showThumbnailsInGallery,
    74: SavedSettingsFields.watchedThreadsSortingMethod,
    75: SavedSettingsFields.closeTabSwitcherAfterUse,
    76: SavedSettingsFields.textScale,
    77: SavedSettingsFields.catalogGridModeTextLinesLimit,
    78: SavedSettingsFields.catalogGridModeAttachmentInBackground,
    79: SavedSettingsFields.maxCatalogRowHeight,
    80: SavedSettingsFields.themes,
    81: SavedSettingsFields.lightThemeKey,
    83: SavedSettingsFields.darkThemeKey,
    84: SavedSettingsFields.hostsToOpenExternally,
    85: SavedSettingsFields.useFullWidthForCatalogCounters,
    87: SavedSettingsFields.allowSwipingInGallery,
    88: SavedSettingsFields.settingsQuickAction,
    89: SavedSettingsFields.useHapticFeedback,
    90: SavedSettingsFields.promptedAboutCrashlytics,
    91: SavedSettingsFields.showCountryNameInCatalogHeader,
    92: SavedSettingsFields.webmTranscoding,
    93: SavedSettingsFields.showListPositionIndicatorsOnLeft,
    94: SavedSettingsFields.appliedMigrations,
    95: SavedSettingsFields.useStatusBarWorkaround,
    96: SavedSettingsFields.enableIMEPersonalizedLearning,
    97: SavedSettingsFields.catalogVariant,
    98: SavedSettingsFields.redditCatalogVariant,
    99: SavedSettingsFields.dimReadThreads,
    100: SavedSettingsFields.hackerNewsCatalogVariant,
    101: SavedSettingsFields.hideDefaultNamesInCatalog,
    102: SavedSettingsFields.launchCount,
    103: SavedSettingsFields.userAgent,
    104: SavedSettingsFields.captcha4ChanCustomNumLetters,
    105: SavedSettingsFields.tabMenuHidesWhenScrollingDown,
    106: SavedSettingsFields.doubleTapScrollToReplies,
    107: SavedSettingsFields.lastUnifiedPushEndpoint,
    108: SavedSettingsFields.webImageSearchMethod,
    109: SavedSettingsFields.showIPNumberOnPosts,
    110: SavedSettingsFields.showNoBeforeIdOnPosts,
    111: SavedSettingsFields.blurEffects,
    112: SavedSettingsFields.scrollbarsOnLeft,
    113: SavedSettingsFields.exactTimeIsTwelveHour,
    114: SavedSettingsFields.exactTimeShowsDateForToday,
    115: SavedSettingsFields.attachmentsPageMaxCrossAxisExtent,
    116: SavedSettingsFields.catalogGridModeCellBorderRadiusAndMargin,
    117: SavedSettingsFields.catalogGridModeShowMoreImageIfLessText,
    118: SavedSettingsFields.showPostNumberOnPosts,
    119: SavedSettingsFields.overscrollModalTapPopsAll,
    120: SavedSettingsFields.squareThumbnails,
    121: SavedSettingsFields.alwaysShowSpoilers,
    122: SavedSettingsFields.gallerySavePathOrganizing,
    123: SavedSettingsFields.fullQualityThumbnails,
    124: SavedSettingsFields.recordThreadsInHistory,
    125: SavedSettingsFields.fontFamily,
    126: SavedSettingsFields.autoCacheAttachments,
    127: SavedSettingsFields.exactTimeUsesCustomDateFormat,
    129: SavedSettingsFields.showOverlaysInGallery,
    130: SavedSettingsFields.verticalTwoPaneMinimumPaneSize,
    131: SavedSettingsFields.hiddenImageMD5s,
    132: SavedSettingsFields.showLastRepliesInCatalog,
    133: SavedSettingsFields.loadThumbnails,
    134: SavedSettingsFields.applyImageFilterToThreads,
    135: SavedSettingsFields.askForAuthenticationOnLaunch,
    136: SavedSettingsFields.enableSpellCheck,
    137: SavedSettingsFields.openCrossThreadLinksInNewTab,
    138: SavedSettingsFields.backgroundThreadAutoUpdatePeriodSeconds,
    139: SavedSettingsFields.currentThreadAutoUpdatePeriodSeconds,
    140: SavedSettingsFields.lastShareablePostsStyle,
    141: SavedSettingsFields.defaultThreadWatch,
    142: SavedSettingsFields.highlightRepeatingDigitsInPostIds,
    143: SavedSettingsFields.includeThreadsYouRepliedToWhenDeletingHistory,
    144: SavedSettingsFields.newPostHighlightBrightness,
    145: SavedSettingsFields.imagePeeking,
    146: SavedSettingsFields.useMaterialStyle,
    147: SavedSettingsFields.useAndroidDrawer,
    148: SavedSettingsFields.useMaterialRoutes,
    149: SavedSettingsFields.hideBarsWhenScrollingDown,
    150: SavedSettingsFields.showPerformanceOverlay,
    151: SavedSettingsFields.customDateFormat,
    152: SavedSettingsFields.hoverPopupDelayMilliseconds,
    153: SavedSettingsFields.mouseModeQuoteLinkBehavior,
    154: SavedSettingsFields.drawerMode,
    155: SavedSettingsFields.showLineBreakInPostInfoRow,
    156: SavedSettingsFields.useCloudCaptchaSolver,
    157: SavedSettingsFields.useHeadlessCloudCaptchaSolver,
    158: SavedSettingsFields.removeMetadataOnUploadedFiles,
    159: SavedSettingsFields.randomizeChecksumOnUploadedFiles,
    160: SavedSettingsFields.recentWebImageSearches,
    161: SavedSettingsFields.cloverStyleRepliesButton,
    162: SavedSettingsFields.watchThreadAutomaticallyWhenReplying,
    163: SavedSettingsFields.saveThreadAutomaticallyWhenReplying,
    164: SavedSettingsFields.cancellableRepliesSlideGesture,
    165: SavedSettingsFields.openBoardSwitcherSlideGesture,
    166: SavedSettingsFields.persistentDrawer,
    167: SavedSettingsFields.showGalleryGridButton,
    168: SavedSettingsFields.centeredPostThumbnailSize,
    169: SavedSettingsFields.ellipsizeLongFilenamesOnPosts,
    170: SavedSettingsFields.muteAudioWhenOpeningGallery,
    171: SavedSettingsFields.translationTargetLanguage,
    172: SavedSettingsFields.homeImageboardKey,
    173: SavedSettingsFields.homeBoardName,
    174: SavedSettingsFields.tapPostIdToReply,
    175: SavedSettingsFields.downloadUsingServerSideFilenames,
    176: SavedSettingsFields.catalogGridModeTextScale,
    177: SavedSettingsFields.catalogGridModeCropThumbnails,
    178: SavedSettingsFields.useSpamFilterWorkarounds,
    179: SavedSettingsFields.scrollbarThickness,
    180: SavedSettingsFields.thumbnailPixelation,
    181: SavedSettingsFields.catalogGridModeTextAboveAttachment
  };

  @override
  SavedSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    _readHookSavedSettingsFields(fields);
    return SavedSettings(
      autoloadAttachments: fields[0] as AutoloadAttachmentsSetting?,
      theme: fields[1] as TristateSystemSetting?,
      hideOldStickiedThreads: fields[2] as bool?,
      deprecatedCatalogSortingMethod: fields[3] as ThreadSortingMethod?,
      deprecatedReverseCatalogSorting: fields[4] as bool?,
      savedThreadsSortingMethod: fields[5] as ThreadSortingMethod?,
      autoRotateInGallery: fields[6] as bool?,
      useTouchLayout: fields[9] as bool?,
      userId: fields[10] as String?,
      contentSettings: fields[11] as ContentSettings?,
      filterConfiguration: fields[13] as String?,
      boardSwitcherHasKeyboardFocus: fields[14] as bool?,
      deprecatedLightTheme: fields[15] as SavedTheme?,
      deprecatedDarkTheme: fields[16] as SavedTheme?,
      deprecatedRecentSearchesBySite:
          (fields[17] as Map?)?.cast<String, PersistentRecentSearches>(),
      browserStateBySite:
          (fields[18] as Map?)?.cast<String, PersistentBrowserState>(),
      savedPostsBySite: (fields[19] as Map?)?.map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, SavedPost>())),
      savedAttachmentsBySite: (fields[20] as Map?)?.map((dynamic k,
              dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, SavedAttachment>())),
      deprecatedBoardsBySite: (fields[21] as Map?)?.map((dynamic k,
              dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, ImageboardBoard>())),
      twoPaneBreakpoint: fields[22] as double?,
      twoPaneSplit: fields[23] as int?,
      useCatalogGrid: fields[24] as bool?,
      catalogGridWidth: fields[25] as double?,
      catalogGridHeight: fields[26] as double?,
      showImageCountInCatalog: fields[27] as bool?,
      showClockIconInCatalog: fields[28] as bool?,
      deprecatedEmbedRegexes: (fields[29] as List?)?.cast<String>(),
      supportMouse: fields[30] as TristateSystemSetting?,
      showNameInCatalog: fields[31] as bool?,
      interfaceScale: fields[32] as double?,
      showAnimations: fields[33] as bool?,
      imagesOnRight: fields[34] as bool?,
      androidGallerySavePath: fields[35] as String?,
      replyBoxHeightOffset: fields[36] as double?,
      blurThumbnails: fields[37] as bool?,
      showTimeInCatalogHeader: fields[38] as bool?,
      showTimeInCatalogStats: fields[39] as bool?,
      showIdInCatalogHeader: fields[40] as bool?,
      showFlagInCatalogHeader: fields[41] as bool?,
      onlyShowFavouriteBoardsInSwitcher: fields[42] as bool?,
      useBoardSwitcherList: fields[43] as bool?,
      contributeCaptchas: fields[44] as bool?,
      showReplyCountsInGallery: fields[45] as bool?,
      useNewCaptchaForm: fields[46] as bool?,
      autoLoginOnMobileNetwork: fields[47] as bool?,
      showScrollbars: fields[48] as bool?,
      randomizeFilenames: fields[49] as bool?,
      showNameOnPosts: fields[50] as bool?,
      showTripOnPosts: fields[51] as bool?,
      showAbsoluteTimeOnPosts: fields[52] as bool?,
      showRelativeTimeOnPosts: fields[53] as bool?,
      showCountryNameOnPosts: fields[54] as bool?,
      showPassOnPosts: fields[55] as bool?,
      showFilenameOnPosts: fields[56] as bool?,
      showFilesizeOnPosts: fields[57] as bool?,
      showFileDimensionsOnPosts: fields[58] as bool?,
      showFlagOnPosts: fields[59] as bool?,
      thumbnailSize: fields[60] as double?,
      muteAudio: fields[61] as bool?,
      usePushNotifications: fields[62] as bool?,
      useEmbeds: fields[63] as bool?,
      useInternalBrowser: fields[64] as bool?,
      automaticCacheClearDays: fields[65] as int?,
      alwaysAutoloadTappedAttachment: fields[66] as bool?,
      postDisplayFieldOrder: (fields[67] as List?)?.cast<PostDisplayField>(),
      maximumImageUploadDimension: fields[68] as int?,
      tabs: (fields[69] as List?)?.cast<PersistentBrowserTab>(),
      currentTabIndex: fields[70] as int?,
      recentSearches: fields[71] as PersistentRecentSearches?,
      hideDefaultNamesOnPosts: fields[72] as bool?,
      showThumbnailsInGallery: fields[73] as bool?,
      watchedThreadsSortingMethod: fields[74] as ThreadSortingMethod?,
      closeTabSwitcherAfterUse: fields[75] as bool?,
      textScale: fields[76] as double?,
      catalogGridModeTextLinesLimit: fields[77] as int?,
      catalogGridModeAttachmentInBackground: fields[78] as bool?,
      maxCatalogRowHeight: fields[79] as double?,
      themes: (fields[80] as Map?)?.cast<String, SavedTheme>(),
      lightThemeKey: fields[81] as String?,
      darkThemeKey: fields[83] as String?,
      hostsToOpenExternally: (fields[84] as List?)?.cast<String>(),
      useFullWidthForCatalogCounters: fields[85] as bool?,
      deprecatedAlwaysStartVideosMuted: fields[86] as bool?,
      allowSwipingInGallery: fields[87] as bool?,
      settingsQuickAction: fields[88] as SettingsQuickAction?,
      useHapticFeedback: fields[89] as bool?,
      promptedAboutCrashlytics: fields[90] as bool?,
      showCountryNameInCatalogHeader: fields[91] as bool?,
      webmTranscoding: fields[92] as WebmTranscodingSetting?,
      showListPositionIndicatorsOnLeft: fields[93] as bool?,
      appliedMigrations: (fields[94] as List?)?.cast<String>(),
      useStatusBarWorkaround: fields[95] as bool?,
      enableIMEPersonalizedLearning: fields[96] as bool?,
      catalogVariant: fields[97] as CatalogVariant?,
      redditCatalogVariant: fields[98] as CatalogVariant?,
      dimReadThreads: fields[99] as bool?,
      hackerNewsCatalogVariant: fields[100] as CatalogVariant?,
      hideDefaultNamesInCatalog: fields[101] as bool?,
      launchCount: fields[102] as int?,
      userAgent: fields[103] as String?,
      captcha4ChanCustomNumLetters: fields[104] as int?,
      tabMenuHidesWhenScrollingDown: fields[105] as bool?,
      doubleTapScrollToReplies: fields[106] as bool?,
      lastUnifiedPushEndpoint: fields[107] as String?,
      webImageSearchMethod: fields[108] as WebImageSearchMethod?,
      showIPNumberOnPosts: fields[109] as bool?,
      showNoBeforeIdOnPosts: fields[110] as bool?,
      blurEffects: fields[111] as bool?,
      scrollbarsOnLeft: fields[112] as bool?,
      exactTimeIsTwelveHour: fields[113] as bool?,
      exactTimeShowsDateForToday: fields[114] as bool?,
      attachmentsPageMaxCrossAxisExtent: fields[115] as double?,
      catalogGridModeCellBorderRadiusAndMargin: fields[116] as bool?,
      catalogGridModeShowMoreImageIfLessText: fields[117] as bool?,
      showPostNumberOnPosts: fields[118] as bool?,
      overscrollModalTapPopsAll: fields[119] as bool?,
      squareThumbnails: fields[120] as bool?,
      alwaysShowSpoilers: fields[121] as bool?,
      gallerySavePathOrganizing: fields[122] as GallerySavePathOrganizing?,
      fullQualityThumbnails: fields[123] as AutoloadAttachmentsSetting?,
      recordThreadsInHistory: fields[124] as bool?,
      fontFamily: fields[125] as String?,
      autoCacheAttachments: fields[126] as AutoloadAttachmentsSetting?,
      exactTimeUsesCustomDateFormat: fields[127] as bool?,
      deprecatedUnsafeImagePeeking: fields[128] as bool?,
      showOverlaysInGallery: fields[129] as bool?,
      verticalTwoPaneMinimumPaneSize: fields[130] as double?,
      hiddenImageMD5s: (fields[131] as Set?)?.cast<String>(),
      showLastRepliesInCatalog: fields[132] as bool?,
      loadThumbnails: fields[133] as AutoloadAttachmentsSetting?,
      applyImageFilterToThreads: fields[134] as bool?,
      askForAuthenticationOnLaunch: fields[135] as bool?,
      enableSpellCheck: fields[136] as bool?,
      openCrossThreadLinksInNewTab: fields[137] as bool?,
      backgroundThreadAutoUpdatePeriodSeconds: fields[138] as int?,
      currentThreadAutoUpdatePeriodSeconds: fields[139] as int?,
      lastShareablePostsStyle: fields[140] as ShareablePostsStyle?,
      defaultThreadWatch: fields[141] as ThreadWatch?,
      highlightRepeatingDigitsInPostIds: fields[142] as bool?,
      includeThreadsYouRepliedToWhenDeletingHistory: fields[143] as bool?,
      newPostHighlightBrightness: fields[144] as double?,
      imagePeeking: fields[145] as ImagePeekingSetting?,
      useMaterialStyle: fields[146] as bool?,
      useAndroidDrawer: fields[147] as bool?,
      useMaterialRoutes: fields[148] as bool?,
      hideBarsWhenScrollingDown: fields[149] as bool?,
      showPerformanceOverlay: fields[150] as bool?,
      customDateFormat: fields[151] as String?,
      hoverPopupDelayMilliseconds: fields[152] as int?,
      mouseModeQuoteLinkBehavior: fields[153] as MouseModeQuoteLinkBehavior?,
      drawerMode: fields[154] as DrawerMode?,
      showLineBreakInPostInfoRow: fields[155] as bool?,
      useCloudCaptchaSolver: fields[156] as bool?,
      useHeadlessCloudCaptchaSolver: fields[157] as bool?,
      removeMetadataOnUploadedFiles: fields[158] as bool?,
      randomizeChecksumOnUploadedFiles: fields[159] as bool?,
      recentWebImageSearches: (fields[160] as List?)?.cast<String>(),
      cloverStyleRepliesButton: fields[161] as bool?,
      watchThreadAutomaticallyWhenReplying: fields[162] as bool?,
      saveThreadAutomaticallyWhenReplying: fields[163] as bool?,
      cancellableRepliesSlideGesture: fields[164] as bool?,
      openBoardSwitcherSlideGesture: fields[165] as bool?,
      persistentDrawer: fields[166] as bool?,
      showGalleryGridButton: fields[167] as bool?,
      centeredPostThumbnailSize: fields[168] as double?,
      ellipsizeLongFilenamesOnPosts: fields[169] as bool?,
      muteAudioWhenOpeningGallery: fields[170] as TristateSystemSetting?,
      translationTargetLanguage: fields[171] as String?,
      homeImageboardKey: fields[172] as String?,
      homeBoardName: fields[173] as String?,
      tapPostIdToReply: fields[174] as bool?,
      downloadUsingServerSideFilenames: fields[175] as bool?,
      catalogGridModeTextScale: fields[176] as double?,
      catalogGridModeCropThumbnails: fields[177] as bool?,
      useSpamFilterWorkarounds: fields[178] as bool?,
      scrollbarThickness: fields[179] as double?,
      thumbnailPixelation: fields[180] as int?,
      catalogGridModeTextAboveAttachment: fields[181] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedSettings obj) {
    writer
      ..writeByte(169)
      ..writeByte(0)
      ..write(obj.autoloadAttachments)
      ..writeByte(1)
      ..write(obj.theme)
      ..writeByte(2)
      ..write(obj.hideOldStickiedThreads)
      ..writeByte(5)
      ..write(obj.savedThreadsSortingMethod)
      ..writeByte(6)
      ..write(obj.autoRotateInGallery)
      ..writeByte(9)
      ..write(obj.useTouchLayout)
      ..writeByte(10)
      ..write(obj.userId)
      ..writeByte(11)
      ..write(obj.contentSettings)
      ..writeByte(13)
      ..write(obj.filterConfiguration)
      ..writeByte(14)
      ..write(obj.boardSwitcherHasKeyboardFocus)
      ..writeByte(18)
      ..write(obj.browserStateBySite)
      ..writeByte(19)
      ..write(obj.savedPostsBySite)
      ..writeByte(20)
      ..write(obj.savedAttachmentsBySite)
      ..writeByte(22)
      ..write(obj.twoPaneBreakpoint)
      ..writeByte(23)
      ..write(obj.twoPaneSplit)
      ..writeByte(24)
      ..write(obj.useCatalogGrid)
      ..writeByte(25)
      ..write(obj.catalogGridWidth)
      ..writeByte(26)
      ..write(obj.catalogGridHeight)
      ..writeByte(27)
      ..write(obj.showImageCountInCatalog)
      ..writeByte(28)
      ..write(obj.showClockIconInCatalog)
      ..writeByte(30)
      ..write(obj.supportMouse)
      ..writeByte(31)
      ..write(obj.showNameInCatalog)
      ..writeByte(32)
      ..write(obj.interfaceScale)
      ..writeByte(33)
      ..write(obj.showAnimations)
      ..writeByte(34)
      ..write(obj.imagesOnRight)
      ..writeByte(35)
      ..write(obj.androidGallerySavePath)
      ..writeByte(36)
      ..write(obj.replyBoxHeightOffset)
      ..writeByte(37)
      ..write(obj.blurThumbnails)
      ..writeByte(38)
      ..write(obj.showTimeInCatalogHeader)
      ..writeByte(39)
      ..write(obj.showTimeInCatalogStats)
      ..writeByte(40)
      ..write(obj.showIdInCatalogHeader)
      ..writeByte(41)
      ..write(obj.showFlagInCatalogHeader)
      ..writeByte(42)
      ..write(obj.onlyShowFavouriteBoardsInSwitcher)
      ..writeByte(43)
      ..write(obj.useBoardSwitcherList)
      ..writeByte(44)
      ..write(obj.contributeCaptchas)
      ..writeByte(45)
      ..write(obj.showReplyCountsInGallery)
      ..writeByte(46)
      ..write(obj.useNewCaptchaForm)
      ..writeByte(47)
      ..write(obj.autoLoginOnMobileNetwork)
      ..writeByte(48)
      ..write(obj.showScrollbars)
      ..writeByte(49)
      ..write(obj.randomizeFilenames)
      ..writeByte(50)
      ..write(obj.showNameOnPosts)
      ..writeByte(51)
      ..write(obj.showTripOnPosts)
      ..writeByte(52)
      ..write(obj.showAbsoluteTimeOnPosts)
      ..writeByte(53)
      ..write(obj.showRelativeTimeOnPosts)
      ..writeByte(54)
      ..write(obj.showCountryNameOnPosts)
      ..writeByte(55)
      ..write(obj.showPassOnPosts)
      ..writeByte(56)
      ..write(obj.showFilenameOnPosts)
      ..writeByte(57)
      ..write(obj.showFilesizeOnPosts)
      ..writeByte(58)
      ..write(obj.showFileDimensionsOnPosts)
      ..writeByte(59)
      ..write(obj.showFlagOnPosts)
      ..writeByte(60)
      ..write(obj.thumbnailSize)
      ..writeByte(61)
      ..write(obj.muteAudio)
      ..writeByte(62)
      ..write(obj.usePushNotifications)
      ..writeByte(63)
      ..write(obj.useEmbeds)
      ..writeByte(64)
      ..write(obj.useInternalBrowser)
      ..writeByte(65)
      ..write(obj.automaticCacheClearDays)
      ..writeByte(66)
      ..write(obj.alwaysAutoloadTappedAttachment)
      ..writeByte(67)
      ..write(obj.postDisplayFieldOrder)
      ..writeByte(68)
      ..write(obj.maximumImageUploadDimension)
      ..writeByte(69)
      ..write(obj.tabs)
      ..writeByte(70)
      ..write(obj.currentTabIndex)
      ..writeByte(71)
      ..write(obj.recentSearches)
      ..writeByte(72)
      ..write(obj.hideDefaultNamesOnPosts)
      ..writeByte(73)
      ..write(obj.showThumbnailsInGallery)
      ..writeByte(74)
      ..write(obj.watchedThreadsSortingMethod)
      ..writeByte(75)
      ..write(obj.closeTabSwitcherAfterUse)
      ..writeByte(76)
      ..write(obj.textScale)
      ..writeByte(77)
      ..write(obj.catalogGridModeTextLinesLimit)
      ..writeByte(78)
      ..write(obj.catalogGridModeAttachmentInBackground)
      ..writeByte(79)
      ..write(obj.maxCatalogRowHeight)
      ..writeByte(80)
      ..write(obj.themes)
      ..writeByte(81)
      ..write(obj.lightThemeKey)
      ..writeByte(83)
      ..write(obj.darkThemeKey)
      ..writeByte(84)
      ..write(obj.hostsToOpenExternally)
      ..writeByte(85)
      ..write(obj.useFullWidthForCatalogCounters)
      ..writeByte(87)
      ..write(obj.allowSwipingInGallery)
      ..writeByte(88)
      ..write(obj.settingsQuickAction)
      ..writeByte(89)
      ..write(obj.useHapticFeedback)
      ..writeByte(90)
      ..write(obj.promptedAboutCrashlytics)
      ..writeByte(91)
      ..write(obj.showCountryNameInCatalogHeader)
      ..writeByte(92)
      ..write(obj.webmTranscoding)
      ..writeByte(93)
      ..write(obj.showListPositionIndicatorsOnLeft)
      ..writeByte(94)
      ..write(obj.appliedMigrations)
      ..writeByte(95)
      ..write(obj.useStatusBarWorkaround)
      ..writeByte(96)
      ..write(obj.enableIMEPersonalizedLearning)
      ..writeByte(97)
      ..write(obj.catalogVariant)
      ..writeByte(98)
      ..write(obj.redditCatalogVariant)
      ..writeByte(99)
      ..write(obj.dimReadThreads)
      ..writeByte(100)
      ..write(obj.hackerNewsCatalogVariant)
      ..writeByte(101)
      ..write(obj.hideDefaultNamesInCatalog)
      ..writeByte(102)
      ..write(obj.launchCount)
      ..writeByte(103)
      ..write(obj.userAgent)
      ..writeByte(104)
      ..write(obj.captcha4ChanCustomNumLetters)
      ..writeByte(105)
      ..write(obj.tabMenuHidesWhenScrollingDown)
      ..writeByte(106)
      ..write(obj.doubleTapScrollToReplies)
      ..writeByte(107)
      ..write(obj.lastUnifiedPushEndpoint)
      ..writeByte(108)
      ..write(obj.webImageSearchMethod)
      ..writeByte(109)
      ..write(obj.showIPNumberOnPosts)
      ..writeByte(110)
      ..write(obj.showNoBeforeIdOnPosts)
      ..writeByte(111)
      ..write(obj.blurEffects)
      ..writeByte(112)
      ..write(obj.scrollbarsOnLeft)
      ..writeByte(113)
      ..write(obj.exactTimeIsTwelveHour)
      ..writeByte(114)
      ..write(obj.exactTimeShowsDateForToday)
      ..writeByte(115)
      ..write(obj.attachmentsPageMaxCrossAxisExtent)
      ..writeByte(116)
      ..write(obj.catalogGridModeCellBorderRadiusAndMargin)
      ..writeByte(117)
      ..write(obj.catalogGridModeShowMoreImageIfLessText)
      ..writeByte(118)
      ..write(obj.showPostNumberOnPosts)
      ..writeByte(119)
      ..write(obj.overscrollModalTapPopsAll)
      ..writeByte(120)
      ..write(obj.squareThumbnails)
      ..writeByte(121)
      ..write(obj.alwaysShowSpoilers)
      ..writeByte(122)
      ..write(obj.gallerySavePathOrganizing)
      ..writeByte(123)
      ..write(obj.fullQualityThumbnails)
      ..writeByte(124)
      ..write(obj.recordThreadsInHistory)
      ..writeByte(125)
      ..write(obj.fontFamily)
      ..writeByte(126)
      ..write(obj.autoCacheAttachments)
      ..writeByte(127)
      ..write(obj.exactTimeUsesCustomDateFormat)
      ..writeByte(129)
      ..write(obj.showOverlaysInGallery)
      ..writeByte(130)
      ..write(obj.verticalTwoPaneMinimumPaneSize)
      ..writeByte(131)
      ..write(obj.hiddenImageMD5s)
      ..writeByte(132)
      ..write(obj.showLastRepliesInCatalog)
      ..writeByte(133)
      ..write(obj.loadThumbnails)
      ..writeByte(134)
      ..write(obj.applyImageFilterToThreads)
      ..writeByte(135)
      ..write(obj.askForAuthenticationOnLaunch)
      ..writeByte(136)
      ..write(obj.enableSpellCheck)
      ..writeByte(137)
      ..write(obj.openCrossThreadLinksInNewTab)
      ..writeByte(138)
      ..write(obj.backgroundThreadAutoUpdatePeriodSeconds)
      ..writeByte(139)
      ..write(obj.currentThreadAutoUpdatePeriodSeconds)
      ..writeByte(140)
      ..write(obj.lastShareablePostsStyle)
      ..writeByte(141)
      ..write(obj.defaultThreadWatch)
      ..writeByte(142)
      ..write(obj.highlightRepeatingDigitsInPostIds)
      ..writeByte(143)
      ..write(obj.includeThreadsYouRepliedToWhenDeletingHistory)
      ..writeByte(144)
      ..write(obj.newPostHighlightBrightness)
      ..writeByte(145)
      ..write(obj.imagePeeking)
      ..writeByte(146)
      ..write(obj.useMaterialStyle)
      ..writeByte(147)
      ..write(obj.useAndroidDrawer)
      ..writeByte(148)
      ..write(obj.useMaterialRoutes)
      ..writeByte(149)
      ..write(obj.hideBarsWhenScrollingDown)
      ..writeByte(150)
      ..write(obj.showPerformanceOverlay)
      ..writeByte(151)
      ..write(obj.customDateFormat)
      ..writeByte(152)
      ..write(obj.hoverPopupDelayMilliseconds)
      ..writeByte(153)
      ..write(obj.mouseModeQuoteLinkBehavior)
      ..writeByte(154)
      ..write(obj.drawerMode)
      ..writeByte(155)
      ..write(obj.showLineBreakInPostInfoRow)
      ..writeByte(156)
      ..write(obj.useCloudCaptchaSolver)
      ..writeByte(157)
      ..write(obj.useHeadlessCloudCaptchaSolver)
      ..writeByte(158)
      ..write(obj.removeMetadataOnUploadedFiles)
      ..writeByte(159)
      ..write(obj.randomizeChecksumOnUploadedFiles)
      ..writeByte(160)
      ..write(obj.recentWebImageSearches)
      ..writeByte(161)
      ..write(obj.cloverStyleRepliesButton)
      ..writeByte(162)
      ..write(obj.watchThreadAutomaticallyWhenReplying)
      ..writeByte(163)
      ..write(obj.saveThreadAutomaticallyWhenReplying)
      ..writeByte(164)
      ..write(obj.cancellableRepliesSlideGesture)
      ..writeByte(165)
      ..write(obj.openBoardSwitcherSlideGesture)
      ..writeByte(166)
      ..write(obj.persistentDrawer)
      ..writeByte(167)
      ..write(obj.showGalleryGridButton)
      ..writeByte(168)
      ..write(obj.centeredPostThumbnailSize)
      ..writeByte(169)
      ..write(obj.ellipsizeLongFilenamesOnPosts)
      ..writeByte(170)
      ..write(obj.muteAudioWhenOpeningGallery)
      ..writeByte(171)
      ..write(obj.translationTargetLanguage)
      ..writeByte(172)
      ..write(obj.homeImageboardKey)
      ..writeByte(173)
      ..write(obj.homeBoardName)
      ..writeByte(174)
      ..write(obj.tapPostIdToReply)
      ..writeByte(175)
      ..write(obj.downloadUsingServerSideFilenames)
      ..writeByte(176)
      ..write(obj.catalogGridModeTextScale)
      ..writeByte(177)
      ..write(obj.catalogGridModeCropThumbnails)
      ..writeByte(178)
      ..write(obj.useSpamFilterWorkarounds)
      ..writeByte(179)
      ..write(obj.scrollbarThickness)
      ..writeByte(180)
      ..write(obj.thumbnailPixelation)
      ..writeByte(181)
      ..write(obj.catalogGridModeTextAboveAttachment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AutoloadAttachmentsSettingAdapter
    extends TypeAdapter<AutoloadAttachmentsSetting> {
  const AutoloadAttachmentsSettingAdapter();

  static const int kTypeId = 1;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<AutoloadAttachmentsSetting, dynamic>>
      fields = const {};

  @override
  AutoloadAttachmentsSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AutoloadAttachmentsSetting.never;
      case 1:
        return AutoloadAttachmentsSetting.wifi;
      case 2:
        return AutoloadAttachmentsSetting.always;
      default:
        return AutoloadAttachmentsSetting.never;
    }
  }

  @override
  void write(BinaryWriter writer, AutoloadAttachmentsSetting obj) {
    switch (obj) {
      case AutoloadAttachmentsSetting.never:
        writer.writeByte(0);
        break;
      case AutoloadAttachmentsSetting.wifi:
        writer.writeByte(1);
        break;
      case AutoloadAttachmentsSetting.always:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoloadAttachmentsSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TristateSystemSettingAdapter extends TypeAdapter<TristateSystemSetting> {
  const TristateSystemSettingAdapter();

  static const int kTypeId = 2;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<TristateSystemSetting, dynamic>>
      fields = const {};

  @override
  TristateSystemSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TristateSystemSetting.a;
      case 1:
        return TristateSystemSetting.system;
      case 2:
        return TristateSystemSetting.b;
      default:
        return TristateSystemSetting.a;
    }
  }

  @override
  void write(BinaryWriter writer, TristateSystemSetting obj) {
    switch (obj) {
      case TristateSystemSetting.a:
        writer.writeByte(0);
        break;
      case TristateSystemSetting.system:
        writer.writeByte(1);
        break;
      case TristateSystemSetting.b:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TristateSystemSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreadSortingMethodAdapter extends TypeAdapter<ThreadSortingMethod> {
  const ThreadSortingMethodAdapter();

  static const int kTypeId = 17;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ThreadSortingMethod, dynamic>>
      fields = const {};

  @override
  ThreadSortingMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThreadSortingMethod.unsorted;
      case 1:
        return ThreadSortingMethod.lastPostTime;
      case 2:
        return ThreadSortingMethod.replyCount;
      case 3:
        return ThreadSortingMethod.threadPostTime;
      case 4:
        return ThreadSortingMethod.savedTime;
      case 5:
        return ThreadSortingMethod.postsPerMinute;
      case 6:
        return ThreadSortingMethod.lastReplyTime;
      case 7:
        return ThreadSortingMethod.imageCount;
      case 8:
        return ThreadSortingMethod.lastReplyByYouTime;
      case 9:
        return ThreadSortingMethod.alphabeticByTitle;
      default:
        return ThreadSortingMethod.unsorted;
    }
  }

  @override
  void write(BinaryWriter writer, ThreadSortingMethod obj) {
    switch (obj) {
      case ThreadSortingMethod.unsorted:
        writer.writeByte(0);
        break;
      case ThreadSortingMethod.lastPostTime:
        writer.writeByte(1);
        break;
      case ThreadSortingMethod.replyCount:
        writer.writeByte(2);
        break;
      case ThreadSortingMethod.threadPostTime:
        writer.writeByte(3);
        break;
      case ThreadSortingMethod.savedTime:
        writer.writeByte(4);
        break;
      case ThreadSortingMethod.postsPerMinute:
        writer.writeByte(5);
        break;
      case ThreadSortingMethod.lastReplyTime:
        writer.writeByte(6);
        break;
      case ThreadSortingMethod.imageCount:
        writer.writeByte(7);
        break;
      case ThreadSortingMethod.lastReplyByYouTime:
        writer.writeByte(8);
        break;
      case ThreadSortingMethod.alphabeticByTitle:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadSortingMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostDisplayFieldAdapter extends TypeAdapter<PostDisplayField> {
  const PostDisplayFieldAdapter();

  static const int kTypeId = 30;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostDisplayField, dynamic>> fields =
      const {};

  @override
  PostDisplayField read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PostDisplayField.name;
      case 1:
        return PostDisplayField.posterId;
      case 2:
        return PostDisplayField.attachmentInfo;
      case 3:
        return PostDisplayField.pass;
      case 4:
        return PostDisplayField.flag;
      case 5:
        return PostDisplayField.countryName;
      case 6:
        return PostDisplayField.absoluteTime;
      case 7:
        return PostDisplayField.relativeTime;
      case 8:
        return PostDisplayField.postId;
      case 9:
        return PostDisplayField.ipNumber;
      case 10:
        return PostDisplayField.postNumber;
      case 11:
        return PostDisplayField.lineBreak;
      default:
        return PostDisplayField.name;
    }
  }

  @override
  void write(BinaryWriter writer, PostDisplayField obj) {
    switch (obj) {
      case PostDisplayField.name:
        writer.writeByte(0);
        break;
      case PostDisplayField.posterId:
        writer.writeByte(1);
        break;
      case PostDisplayField.attachmentInfo:
        writer.writeByte(2);
        break;
      case PostDisplayField.pass:
        writer.writeByte(3);
        break;
      case PostDisplayField.flag:
        writer.writeByte(4);
        break;
      case PostDisplayField.countryName:
        writer.writeByte(5);
        break;
      case PostDisplayField.absoluteTime:
        writer.writeByte(6);
        break;
      case PostDisplayField.relativeTime:
        writer.writeByte(7);
        break;
      case PostDisplayField.postId:
        writer.writeByte(8);
        break;
      case PostDisplayField.ipNumber:
        writer.writeByte(9);
        break;
      case PostDisplayField.postNumber:
        writer.writeByte(10);
        break;
      case PostDisplayField.lineBreak:
        writer.writeByte(11);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostDisplayFieldAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SettingsQuickActionAdapter extends TypeAdapter<SettingsQuickAction> {
  const SettingsQuickActionAdapter();

  static const int kTypeId = 31;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<SettingsQuickAction, dynamic>>
      fields = const {};

  @override
  SettingsQuickAction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SettingsQuickAction.toggleTheme;
      case 1:
        return SettingsQuickAction.toggleBlurredThumbnails;
      case 2:
        return SettingsQuickAction.toggleCatalogLayout;
      case 3:
        return SettingsQuickAction.toggleInterfaceStyle;
      case 4:
        return SettingsQuickAction.toggleListPositionIndicatorLocation;
      case 5:
        return SettingsQuickAction.toggleVerticalTwoPaneSplit;
      case 6:
        return SettingsQuickAction.toggleImages;
      case 7:
        return SettingsQuickAction.togglePixelatedThumbnails;
      default:
        return SettingsQuickAction.toggleTheme;
    }
  }

  @override
  void write(BinaryWriter writer, SettingsQuickAction obj) {
    switch (obj) {
      case SettingsQuickAction.toggleTheme:
        writer.writeByte(0);
        break;
      case SettingsQuickAction.toggleBlurredThumbnails:
        writer.writeByte(1);
        break;
      case SettingsQuickAction.toggleCatalogLayout:
        writer.writeByte(2);
        break;
      case SettingsQuickAction.toggleInterfaceStyle:
        writer.writeByte(3);
        break;
      case SettingsQuickAction.toggleListPositionIndicatorLocation:
        writer.writeByte(4);
        break;
      case SettingsQuickAction.toggleVerticalTwoPaneSplit:
        writer.writeByte(5);
        break;
      case SettingsQuickAction.toggleImages:
        writer.writeByte(6);
        break;
      case SettingsQuickAction.togglePixelatedThumbnails:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsQuickActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WebmTranscodingSettingAdapter
    extends TypeAdapter<WebmTranscodingSetting> {
  const WebmTranscodingSettingAdapter();

  static const int kTypeId = 32;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<WebmTranscodingSetting, dynamic>>
      fields = const {};

  @override
  WebmTranscodingSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WebmTranscodingSetting.never;
      case 1:
        return WebmTranscodingSetting.vp9;
      case 2:
        return WebmTranscodingSetting.always;
      default:
        return WebmTranscodingSetting.never;
    }
  }

  @override
  void write(BinaryWriter writer, WebmTranscodingSetting obj) {
    switch (obj) {
      case WebmTranscodingSetting.never:
        writer.writeByte(0);
        break;
      case WebmTranscodingSetting.vp9:
        writer.writeByte(1);
        break;
      case WebmTranscodingSetting.always:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebmTranscodingSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GallerySavePathOrganizingAdapter
    extends TypeAdapter<GallerySavePathOrganizing> {
  const GallerySavePathOrganizingAdapter();

  static const int kTypeId = 37;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<GallerySavePathOrganizing, dynamic>>
      fields = const {};

  @override
  GallerySavePathOrganizing read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GallerySavePathOrganizing.noSubfolders;
      case 1:
        return GallerySavePathOrganizing.boardSubfolders;
      case 2:
        return GallerySavePathOrganizing.boardAndThreadSubfolders;
      case 3:
        return GallerySavePathOrganizing.boardAndThreadNameSubfolders;
      case 4:
        return GallerySavePathOrganizing.noFolder;
      case 5:
        return GallerySavePathOrganizing.threadNameSubfolders;
      default:
        return GallerySavePathOrganizing.noSubfolders;
    }
  }

  @override
  void write(BinaryWriter writer, GallerySavePathOrganizing obj) {
    switch (obj) {
      case GallerySavePathOrganizing.noSubfolders:
        writer.writeByte(0);
        break;
      case GallerySavePathOrganizing.boardSubfolders:
        writer.writeByte(1);
        break;
      case GallerySavePathOrganizing.boardAndThreadSubfolders:
        writer.writeByte(2);
        break;
      case GallerySavePathOrganizing.boardAndThreadNameSubfolders:
        writer.writeByte(3);
        break;
      case GallerySavePathOrganizing.noFolder:
        writer.writeByte(4);
        break;
      case GallerySavePathOrganizing.threadNameSubfolders:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GallerySavePathOrganizingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ImagePeekingSettingAdapter extends TypeAdapter<ImagePeekingSetting> {
  const ImagePeekingSettingAdapter();

  static const int kTypeId = 43;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<ImagePeekingSetting, dynamic>>
      fields = const {};

  @override
  ImagePeekingSetting read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ImagePeekingSetting.disabled;
      case 1:
        return ImagePeekingSetting.standard;
      case 2:
        return ImagePeekingSetting.unsafe;
      case 3:
        return ImagePeekingSetting.ultraUnsafe;
      default:
        return ImagePeekingSetting.disabled;
    }
  }

  @override
  void write(BinaryWriter writer, ImagePeekingSetting obj) {
    switch (obj) {
      case ImagePeekingSetting.disabled:
        writer.writeByte(0);
        break;
      case ImagePeekingSetting.standard:
        writer.writeByte(1);
        break;
      case ImagePeekingSetting.unsafe:
        writer.writeByte(2);
        break;
      case ImagePeekingSetting.ultraUnsafe:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImagePeekingSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MouseModeQuoteLinkBehaviorAdapter
    extends TypeAdapter<MouseModeQuoteLinkBehavior> {
  const MouseModeQuoteLinkBehaviorAdapter();

  static const int kTypeId = 44;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<MouseModeQuoteLinkBehavior, dynamic>>
      fields = const {};

  @override
  MouseModeQuoteLinkBehavior read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MouseModeQuoteLinkBehavior.expandInline;
      case 1:
        return MouseModeQuoteLinkBehavior.scrollToPost;
      case 2:
        return MouseModeQuoteLinkBehavior.popupPostsPage;
      default:
        return MouseModeQuoteLinkBehavior.expandInline;
    }
  }

  @override
  void write(BinaryWriter writer, MouseModeQuoteLinkBehavior obj) {
    switch (obj) {
      case MouseModeQuoteLinkBehavior.expandInline:
        writer.writeByte(0);
        break;
      case MouseModeQuoteLinkBehavior.scrollToPost:
        writer.writeByte(1);
        break;
      case MouseModeQuoteLinkBehavior.popupPostsPage:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MouseModeQuoteLinkBehaviorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DrawerModeAdapter extends TypeAdapter<DrawerMode> {
  const DrawerModeAdapter();

  static const int kTypeId = 45;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<DrawerMode, dynamic>> fields =
      const {};

  @override
  DrawerMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DrawerMode.tabs;
      case 1:
        return DrawerMode.watchedThreads;
      case 2:
        return DrawerMode.savedThreads;
      default:
        return DrawerMode.tabs;
    }
  }

  @override
  void write(BinaryWriter writer, DrawerMode obj) {
    switch (obj) {
      case DrawerMode.tabs:
        writer.writeByte(0);
        break;
      case DrawerMode.watchedThreads:
        writer.writeByte(1);
        break;
      case DrawerMode.savedThreads:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawerModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
