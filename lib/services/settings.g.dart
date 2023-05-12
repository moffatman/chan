// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContentSettingsAdapter extends TypeAdapter<ContentSettings> {
  @override
  final int typeId = 20;

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
      sites: (fields[5] as Map?)?.cast<String, dynamic>(),
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
      ..writeByte(5)
      ..write(obj.sites);
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

class SavedThemeAdapter extends TypeAdapter<SavedTheme> {
  @override
  final int typeId = 25;

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
      locked: fields[6] == null ? false : fields[6] as bool,
      copiedFrom: fields[5] as SavedTheme?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedTheme obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.titleColor);
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

class SavedSettingsAdapter extends TypeAdapter<SavedSettings> {
  @override
  final int typeId = 0;

  @override
  SavedSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
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
      embedRegexes: (fields[29] as List?)?.cast<String>(),
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
      alwaysStartVideosMuted: fields[86] as bool?,
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
      androidGallerySavePathOrganizing:
          fields[122] as AndroidGallerySavePathOrganizing?,
      fullQualityThumbnails: fields[123] as AutoloadAttachmentsSetting?,
      recordThreadsInHistory: fields[124] as bool?,
      fontFamily: fields[125] as String?,
      autoCacheAttachments: fields[126] as AutoloadAttachmentsSetting?,
      exactTimeIsISO8601: fields[127] as bool?,
      unsafeImagePeeking: fields[128] as bool?,
      showOverlaysInGallery: fields[129] as bool?,
      verticalTwoPaneMinimumPaneSize: fields[130] as double?,
      hiddenImageMD5s: (fields[131] as List?)?.cast<String>(),
      showLastRepliesInCatalog: fields[132] as bool?,
      loadThumbnails: fields[133] as AutoloadAttachmentsSetting?,
      applyImageFilterToThreads: fields[134] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedSettings obj) {
    writer
      ..writeByte(131)
      ..writeByte(0)
      ..write(obj.autoloadAttachments)
      ..writeByte(1)
      ..write(obj.theme)
      ..writeByte(2)
      ..write(obj.hideOldStickiedThreads)
      ..writeByte(3)
      ..write(obj.deprecatedCatalogSortingMethod)
      ..writeByte(4)
      ..write(obj.deprecatedReverseCatalogSorting)
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
      ..writeByte(15)
      ..write(obj.deprecatedLightTheme)
      ..writeByte(16)
      ..write(obj.deprecatedDarkTheme)
      ..writeByte(17)
      ..write(obj.deprecatedRecentSearchesBySite)
      ..writeByte(18)
      ..write(obj.browserStateBySite)
      ..writeByte(19)
      ..write(obj.savedPostsBySite)
      ..writeByte(20)
      ..write(obj.savedAttachmentsBySite)
      ..writeByte(21)
      ..write(obj.deprecatedBoardsBySite)
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
      ..writeByte(29)
      ..write(obj.embedRegexes)
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
      ..writeByte(86)
      ..write(obj.alwaysStartVideosMuted)
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
      ..write(obj.androidGallerySavePathOrganizing)
      ..writeByte(123)
      ..write(obj.fullQualityThumbnails)
      ..writeByte(124)
      ..write(obj.recordThreadsInHistory)
      ..writeByte(125)
      ..write(obj.fontFamily)
      ..writeByte(126)
      ..write(obj.autoCacheAttachments)
      ..writeByte(127)
      ..write(obj.exactTimeIsISO8601)
      ..writeByte(128)
      ..write(obj.unsafeImagePeeking)
      ..writeByte(129)
      ..write(obj.showOverlaysInGallery)
      ..writeByte(130)
      ..write(obj.verticalTwoPaneMinimumPaneSize)
      ..writeByte(131)
      ..write(obj.hiddenImageMD5s.toList())
      ..writeByte(132)
      ..write(obj.showLastRepliesInCatalog)
      ..writeByte(133)
      ..write(obj.loadThumbnails)
      ..writeByte(134)
      ..write(obj.applyImageFilterToThreads);
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
  @override
  final int typeId = 1;

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
  @override
  final int typeId = 2;

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
  @override
  final int typeId = 17;

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
  @override
  final int typeId = 30;

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
  @override
  final int typeId = 31;

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
  @override
  final int typeId = 32;

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

class AndroidGallerySavePathOrganizingAdapter
    extends TypeAdapter<AndroidGallerySavePathOrganizing> {
  @override
  final int typeId = 37;

  @override
  AndroidGallerySavePathOrganizing read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AndroidGallerySavePathOrganizing.noSubfolders;
      case 1:
        return AndroidGallerySavePathOrganizing.boardSubfolders;
      case 2:
        return AndroidGallerySavePathOrganizing.boardAndThreadSubfolders;
      default:
        return AndroidGallerySavePathOrganizing.noSubfolders;
    }
  }

  @override
  void write(BinaryWriter writer, AndroidGallerySavePathOrganizing obj) {
    switch (obj) {
      case AndroidGallerySavePathOrganizing.noSubfolders:
        writer.writeByte(0);
        break;
      case AndroidGallerySavePathOrganizing.boardSubfolders:
        writer.writeByte(1);
        break;
      case AndroidGallerySavePathOrganizing.boardAndThreadSubfolders:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidGallerySavePathOrganizingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
