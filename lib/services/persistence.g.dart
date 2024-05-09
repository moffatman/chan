// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persistence.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersistentRecentSearchesFields {
  static List<ImageboardArchiveSearchQuery> getEntries(
          PersistentRecentSearches x) =>
      x.entries;
  static void setEntries(
          PersistentRecentSearches x, List<ImageboardArchiveSearchQuery> v) =>
      x.entries = v;
  static const entries = HiveFieldAdapter<PersistentRecentSearches,
      List<ImageboardArchiveSearchQuery>>(
    getter: getEntries,
    setter: setEntries,
    fieldNumber: 0,
    fieldName: 'entries',
    merger: OrderedSetLikePrimitiveListMerger<ImageboardArchiveSearchQuery>(),
  );
}

class PersistentRecentSearchesAdapter
    extends TypeAdapter<PersistentRecentSearches> {
  const PersistentRecentSearchesAdapter();

  static const int kTypeId = 8;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PersistentRecentSearches, dynamic>>
      fields = const {0: PersistentRecentSearchesFields.entries};

  @override
  PersistentRecentSearches read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistentRecentSearches()
      ..entries = (fields[0] as List).cast<ImageboardArchiveSearchQuery>();
  }

  @override
  void write(BinaryWriter writer, PersistentRecentSearches obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.entries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistentRecentSearchesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PersistentThreadStateFields {
  static int? getLastSeenPostId(PersistentThreadState x) => x.lastSeenPostId;
  static void setLastSeenPostId(PersistentThreadState x, int? v) =>
      x.lastSeenPostId = v;
  static const lastSeenPostId = HiveFieldAdapter<PersistentThreadState, int?>(
    getter: getLastSeenPostId,
    setter: setLastSeenPostId,
    fieldNumber: 0,
    fieldName: 'lastSeenPostId',
    merger: PrimitiveMerger(),
  );
  static DateTime getLastOpenedTime(PersistentThreadState x) =>
      x.lastOpenedTime;
  static void setLastOpenedTime(PersistentThreadState x, DateTime v) =>
      x.lastOpenedTime = v;
  static const lastOpenedTime =
      HiveFieldAdapter<PersistentThreadState, DateTime>(
    getter: getLastOpenedTime,
    setter: setLastOpenedTime,
    fieldNumber: 1,
    fieldName: 'lastOpenedTime',
    merger: PrimitiveMerger(),
  );
  static DateTime? getSavedTime(PersistentThreadState x) => x.savedTime;
  static void setSavedTime(PersistentThreadState x, DateTime? v) =>
      x.savedTime = v;
  static const savedTime = HiveFieldAdapter<PersistentThreadState, DateTime?>(
    getter: getSavedTime,
    setter: setSavedTime,
    fieldNumber: 6,
    fieldName: 'savedTime',
    merger: PrimitiveMerger(),
  );
  static List<PostReceipt> getReceipts(PersistentThreadState x) => x.receipts;
  static void setReceipts(PersistentThreadState x, List<PostReceipt> v) =>
      x.receipts = v;
  static const receipts =
      HiveFieldAdapter<PersistentThreadState, List<PostReceipt>>(
    getter: getReceipts,
    setter: setReceipts,
    fieldNumber: 3,
    fieldName: 'receipts',
    merger: MapLikeListMerger<PostReceipt, int>(
        childMerger: AdaptedMerger(PostReceiptAdapter.kTypeId),
        keyer: PostReceiptFields.getId),
  );
  static Thread? _getDeprecatedThread(PersistentThreadState x) =>
      x._deprecatedThread;
  static void _setDeprecatedThread(PersistentThreadState x, Thread? v) =>
      x._deprecatedThread = v;
  static const _deprecatedThread =
      HiveFieldAdapter<PersistentThreadState, Thread?>(
    getter: _getDeprecatedThread,
    setter: _setDeprecatedThread,
    fieldNumber: 4,
    fieldName: '_deprecatedThread',
    merger: NullableMerger(AdaptedMerger(ThreadAdapter.kTypeId)),
  );
  static bool getUseArchive(PersistentThreadState x) => x.useArchive;
  static void setUseArchive(PersistentThreadState x, bool v) =>
      x.useArchive = v;
  static const useArchive = HiveFieldAdapter<PersistentThreadState, bool>(
    getter: getUseArchive,
    setter: setUseArchive,
    fieldNumber: 5,
    fieldName: 'useArchive',
    merger: PrimitiveMerger(),
  );
  static List<int> getPostsMarkedAsYou(PersistentThreadState x) =>
      x.postsMarkedAsYou;
  static void setPostsMarkedAsYou(PersistentThreadState x, List<int> v) =>
      x.postsMarkedAsYou = v;
  static const postsMarkedAsYou =
      HiveFieldAdapter<PersistentThreadState, List<int>>(
    getter: getPostsMarkedAsYou,
    setter: setPostsMarkedAsYou,
    fieldNumber: 7,
    fieldName: 'postsMarkedAsYou',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static List<int> getHiddenPostIds(PersistentThreadState x) => x.hiddenPostIds;
  static void setHiddenPostIds(PersistentThreadState x, List<int> v) =>
      x.hiddenPostIds = v;
  static const hiddenPostIds =
      HiveFieldAdapter<PersistentThreadState, List<int>>(
    getter: getHiddenPostIds,
    setter: setHiddenPostIds,
    fieldNumber: 8,
    fieldName: 'hiddenPostIds',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static String? getDeprecatedDraftReply(PersistentThreadState x) =>
      x.deprecatedDraftReply;
  static void setDeprecatedDraftReply(PersistentThreadState x, String? v) =>
      x.deprecatedDraftReply = v;
  static const deprecatedDraftReply =
      HiveFieldAdapter<PersistentThreadState, String?>(
    getter: getDeprecatedDraftReply,
    setter: setDeprecatedDraftReply,
    fieldNumber: 9,
    fieldName: 'deprecatedDraftReply',
    merger: PrimitiveMerger(),
  );
  static List<int> getTreeHiddenPostIds(PersistentThreadState x) =>
      x.treeHiddenPostIds;
  static void setTreeHiddenPostIds(PersistentThreadState x, List<int> v) =>
      x.treeHiddenPostIds = v;
  static const treeHiddenPostIds =
      HiveFieldAdapter<PersistentThreadState, List<int>>(
    getter: getTreeHiddenPostIds,
    setter: setTreeHiddenPostIds,
    fieldNumber: 10,
    fieldName: 'treeHiddenPostIds',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static List<String> getHiddenPosterIds(PersistentThreadState x) =>
      x.hiddenPosterIds;
  static void setHiddenPosterIds(PersistentThreadState x, List<String> v) =>
      x.hiddenPosterIds = v;
  static const hiddenPosterIds =
      HiveFieldAdapter<PersistentThreadState, List<String>>(
    getter: getHiddenPosterIds,
    setter: setHiddenPosterIds,
    fieldNumber: 11,
    fieldName: 'hiddenPosterIds',
    merger: SetLikePrimitiveListMerger<String>(),
  );
  static Map<int, Post> getTranslatedPosts(PersistentThreadState x) =>
      x.translatedPosts;
  static void setTranslatedPosts(PersistentThreadState x, Map<int, Post> v) =>
      x.translatedPosts = v;
  static const translatedPosts =
      HiveFieldAdapter<PersistentThreadState, Map<int, Post>>(
    getter: getTranslatedPosts,
    setter: setTranslatedPosts,
    fieldNumber: 12,
    fieldName: 'translatedPosts',
    merger: MapMerger(AdaptedMerger(PostAdapter.kTypeId)),
  );
  static bool getAutoTranslate(PersistentThreadState x) => x.autoTranslate;
  static void setAutoTranslate(PersistentThreadState x, bool v) =>
      x.autoTranslate = v;
  static const autoTranslate = HiveFieldAdapter<PersistentThreadState, bool>(
    getter: getAutoTranslate,
    setter: setAutoTranslate,
    fieldNumber: 13,
    fieldName: 'autoTranslate',
    merger: PrimitiveMerger(),
  );
  static bool? getUseTree(PersistentThreadState x) => x.useTree;
  static void setUseTree(PersistentThreadState x, bool? v) => x.useTree = v;
  static const useTree = HiveFieldAdapter<PersistentThreadState, bool?>(
    getter: getUseTree,
    setter: setUseTree,
    fieldNumber: 14,
    fieldName: 'useTree',
    merger: PrimitiveMerger(),
  );
  static ThreadVariant? getVariant(PersistentThreadState x) => x.variant;
  static void setVariant(PersistentThreadState x, ThreadVariant? v) =>
      x.variant = v;
  static const variant =
      HiveFieldAdapter<PersistentThreadState, ThreadVariant?>(
    getter: getVariant,
    setter: setVariant,
    fieldNumber: 15,
    fieldName: 'variant',
    merger: PrimitiveMerger(),
  );
  static List<List<int>> getCollapsedItems(PersistentThreadState x) =>
      x.collapsedItems;
  static void setCollapsedItems(PersistentThreadState x, List<List<int>> v) =>
      x.collapsedItems = v;
  static const collapsedItems =
      HiveFieldAdapter<PersistentThreadState, List<List<int>>>(
    getter: getCollapsedItems,
    setter: setCollapsedItems,
    fieldNumber: 16,
    fieldName: 'collapsedItems',
    merger: TreePathListMerger(),
  );
  static List<String> getDownloadedAttachmentIds(PersistentThreadState x) =>
      x.downloadedAttachmentIds;
  static void setDownloadedAttachmentIds(
          PersistentThreadState x, List<String> v) =>
      x.downloadedAttachmentIds = v;
  static const downloadedAttachmentIds =
      HiveFieldAdapter<PersistentThreadState, List<String>>(
    getter: getDownloadedAttachmentIds,
    setter: setDownloadedAttachmentIds,
    fieldNumber: 17,
    fieldName: 'downloadedAttachmentIds',
    merger: SetLikePrimitiveListMerger<String>(),
  );
  static String getImageboardKey(PersistentThreadState x) => x.imageboardKey;
  static void setImageboardKey(PersistentThreadState x, String v) =>
      x.imageboardKey = v;
  static const imageboardKey = HiveFieldAdapter<PersistentThreadState, String>(
    getter: getImageboardKey,
    setter: setImageboardKey,
    fieldNumber: 18,
    fieldName: 'imageboardKey',
    merger: PrimitiveMerger(),
  );
  static Map<int, int> getPrimarySubtreeParents(PersistentThreadState x) =>
      x.primarySubtreeParents;
  static void setPrimarySubtreeParents(
          PersistentThreadState x, Map<int, int> v) =>
      x.primarySubtreeParents = v;
  static const primarySubtreeParents =
      HiveFieldAdapter<PersistentThreadState, Map<int, int>>(
    getter: getPrimarySubtreeParents,
    setter: setPrimarySubtreeParents,
    fieldNumber: 21,
    fieldName: 'primarySubtreeParents',
    merger: MapMerger(PrimitiveMerger()),
  );
  static bool getShowInHistory(PersistentThreadState x) => x.showInHistory;
  static void setShowInHistory(PersistentThreadState x, bool v) =>
      x.showInHistory = v;
  static const showInHistory = HiveFieldAdapter<PersistentThreadState, bool>(
    getter: getShowInHistory,
    setter: setShowInHistory,
    fieldNumber: 22,
    fieldName: 'showInHistory',
    merger: PrimitiveMerger(),
  );
  static int? getFirstVisiblePostId(PersistentThreadState x) =>
      x.firstVisiblePostId;
  static void setFirstVisiblePostId(PersistentThreadState x, int? v) =>
      x.firstVisiblePostId = v;
  static const firstVisiblePostId =
      HiveFieldAdapter<PersistentThreadState, int?>(
    getter: getFirstVisiblePostId,
    setter: setFirstVisiblePostId,
    fieldNumber: 23,
    fieldName: 'firstVisiblePostId',
    merger: PrimitiveMerger(),
  );
  static EfficientlyStoredIntSet getUnseenPostIds(PersistentThreadState x) =>
      x.unseenPostIds;
  static const unseenPostIds =
      ReadOnlyHiveFieldAdapter<PersistentThreadState, EfficientlyStoredIntSet>(
    getter: getUnseenPostIds,
    fieldNumber: 24,
    fieldName: 'unseenPostIds',
    merger: AdaptedMerger(EfficientlyStoredIntSetAdapter.kTypeId),
  );
  static double? getFirstVisiblePostAlignment(PersistentThreadState x) =>
      x.firstVisiblePostAlignment;
  static void setFirstVisiblePostAlignment(
          PersistentThreadState x, double? v) =>
      x.firstVisiblePostAlignment = v;
  static const firstVisiblePostAlignment =
      HiveFieldAdapter<PersistentThreadState, double?>(
    getter: getFirstVisiblePostAlignment,
    setter: setFirstVisiblePostAlignment,
    fieldNumber: 25,
    fieldName: 'firstVisiblePostAlignment',
    merger: PrimitiveMerger(),
  );
  static PostSortingMethod? getPostSortingMethod(PersistentThreadState x) =>
      x.postSortingMethod;
  static void setPostSortingMethod(
          PersistentThreadState x, PostSortingMethod? v) =>
      x.postSortingMethod = v;
  static const postSortingMethod =
      HiveFieldAdapter<PersistentThreadState, PostSortingMethod?>(
    getter: getPostSortingMethod,
    setter: setPostSortingMethod,
    fieldNumber: 26,
    fieldName: 'postSortingMethod',
    merger: PrimitiveMerger(),
  );
  static EfficientlyStoredIntSet getPostIdsToStartRepliesAtBottom(
          PersistentThreadState x) =>
      x.postIdsToStartRepliesAtBottom;
  static const postIdsToStartRepliesAtBottom =
      ReadOnlyHiveFieldAdapter<PersistentThreadState, EfficientlyStoredIntSet>(
    getter: getPostIdsToStartRepliesAtBottom,
    fieldNumber: 27,
    fieldName: 'postIdsToStartRepliesAtBottom',
    merger: AdaptedMerger(EfficientlyStoredIntSetAdapter.kTypeId),
  );
  static List<int> getOverrideShowPostIds(PersistentThreadState x) =>
      x.overrideShowPostIds;
  static void setOverrideShowPostIds(PersistentThreadState x, List<int> v) =>
      x.overrideShowPostIds = v;
  static const overrideShowPostIds =
      HiveFieldAdapter<PersistentThreadState, List<int>>(
    getter: getOverrideShowPostIds,
    setter: setOverrideShowPostIds,
    fieldNumber: 28,
    fieldName: 'overrideShowPostIds',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static String? getDeprecatedReplyOptions(PersistentThreadState x) =>
      x.deprecatedReplyOptions;
  static void setDeprecatedReplyOptions(PersistentThreadState x, String? v) =>
      x.deprecatedReplyOptions = v;
  static const deprecatedReplyOptions =
      HiveFieldAdapter<PersistentThreadState, String?>(
    getter: getDeprecatedReplyOptions,
    setter: setDeprecatedReplyOptions,
    fieldNumber: 29,
    fieldName: 'deprecatedReplyOptions',
    merger: PrimitiveMerger(),
  );
  static int? getTreeSplitId(PersistentThreadState x) => x.treeSplitId;
  static void setTreeSplitId(PersistentThreadState x, int? v) =>
      x.treeSplitId = v;
  static const treeSplitId = HiveFieldAdapter<PersistentThreadState, int?>(
    getter: getTreeSplitId,
    setter: setTreeSplitId,
    fieldNumber: 30,
    fieldName: 'treeSplitId',
    merger: PrimitiveMerger(),
  );
  static DraftPost? getDraft(PersistentThreadState x) => x.draft;
  static void setDraft(PersistentThreadState x, DraftPost? v) => x.draft = v;
  static const draft = HiveFieldAdapter<PersistentThreadState, DraftPost?>(
    getter: getDraft,
    setter: setDraft,
    fieldNumber: 31,
    fieldName: 'draft',
    merger: NullableMerger(AdaptedMerger(DraftPostAdapter.kTypeId)),
  );
  static String getBoard(PersistentThreadState x) => x.board;
  static void setBoard(PersistentThreadState x, String v) => x.board = v;
  static const board = HiveFieldAdapter<PersistentThreadState, String>(
    getter: getBoard,
    setter: setBoard,
    fieldNumber: 19,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static int getId(PersistentThreadState x) => x.id;
  static void setId(PersistentThreadState x, int v) => x.id = v;
  static const id = HiveFieldAdapter<PersistentThreadState, int>(
    getter: getId,
    setter: setId,
    fieldNumber: 20,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
}

class PersistentThreadStateAdapter extends TypeAdapter<PersistentThreadState> {
  const PersistentThreadStateAdapter();

  static const int kTypeId = 3;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PersistentThreadState, dynamic>>
      fields = const {
    0: PersistentThreadStateFields.lastSeenPostId,
    1: PersistentThreadStateFields.lastOpenedTime,
    6: PersistentThreadStateFields.savedTime,
    3: PersistentThreadStateFields.receipts,
    4: PersistentThreadStateFields._deprecatedThread,
    5: PersistentThreadStateFields.useArchive,
    7: PersistentThreadStateFields.postsMarkedAsYou,
    8: PersistentThreadStateFields.hiddenPostIds,
    9: PersistentThreadStateFields.deprecatedDraftReply,
    10: PersistentThreadStateFields.treeHiddenPostIds,
    11: PersistentThreadStateFields.hiddenPosterIds,
    12: PersistentThreadStateFields.translatedPosts,
    13: PersistentThreadStateFields.autoTranslate,
    14: PersistentThreadStateFields.useTree,
    15: PersistentThreadStateFields.variant,
    16: PersistentThreadStateFields.collapsedItems,
    17: PersistentThreadStateFields.downloadedAttachmentIds,
    18: PersistentThreadStateFields.imageboardKey,
    21: PersistentThreadStateFields.primarySubtreeParents,
    22: PersistentThreadStateFields.showInHistory,
    23: PersistentThreadStateFields.firstVisiblePostId,
    24: PersistentThreadStateFields.unseenPostIds,
    25: PersistentThreadStateFields.firstVisiblePostAlignment,
    26: PersistentThreadStateFields.postSortingMethod,
    27: PersistentThreadStateFields.postIdsToStartRepliesAtBottom,
    28: PersistentThreadStateFields.overrideShowPostIds,
    29: PersistentThreadStateFields.deprecatedReplyOptions,
    30: PersistentThreadStateFields.treeSplitId,
    31: PersistentThreadStateFields.draft,
    19: PersistentThreadStateFields.board,
    20: PersistentThreadStateFields.id
  };

  @override
  PersistentThreadState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistentThreadState(
      imageboardKey: fields[18] == null ? '' : fields[18] as String,
      board: fields[19] == null ? '' : fields[19] as String,
      id: fields[20] == null ? 0 : fields[20] as int,
      showInHistory: fields[22] == null ? true : fields[22] as bool,
      unseenPostIds: fields[24] as EfficientlyStoredIntSet?,
      postSortingMethod: fields[26] as PostSortingMethod?,
      postIdsToStartRepliesAtBottom: fields[27] as EfficientlyStoredIntSet?,
      draft: fields[31] as DraftPost?,
    )
      ..lastSeenPostId = fields[0] as int?
      ..lastOpenedTime = fields[1] as DateTime
      ..savedTime = fields[6] as DateTime?
      ..receipts = (fields[3] as List).cast<PostReceipt>()
      .._deprecatedThread = fields[4] as Thread?
      ..useArchive = fields[5] as bool
      ..postsMarkedAsYou =
          fields[7] == null ? [] : (fields[7] as List).cast<int>()
      ..hiddenPostIds = fields[8] == null ? [] : (fields[8] as List).cast<int>()
      ..deprecatedDraftReply = fields[9] as String?
      ..treeHiddenPostIds =
          fields[10] == null ? [] : (fields[10] as List).cast<int>()
      ..hiddenPosterIds =
          fields[11] == null ? [] : (fields[11] as List).cast<String>()
      ..translatedPosts =
          fields[12] == null ? {} : (fields[12] as Map).cast<int, Post>()
      ..autoTranslate = fields[13] == null ? false : fields[13] as bool
      ..useTree = fields[14] as bool?
      ..variant = fields[15] as ThreadVariant?
      ..collapsedItems = fields[16] == null
          ? []
          : (fields[16] as List)
              .map((dynamic e) => (e as List).cast<int>())
              .toList()
      ..downloadedAttachmentIds =
          fields[17] == null ? [] : (fields[17] as List).cast<String>()
      ..primarySubtreeParents =
          fields[21] == null ? {} : (fields[21] as Map).cast<int, int>()
      ..firstVisiblePostId = fields[23] as int?
      ..firstVisiblePostAlignment = fields[25] as double?
      ..overrideShowPostIds =
          fields[28] == null ? [] : (fields[28] as List).cast<int>()
      ..deprecatedReplyOptions = fields[29] as String?
      ..treeSplitId = fields[30] as int?;
  }

  @override
  void write(BinaryWriter writer, PersistentThreadState obj) {
    writer
      ..writeByte(31)
      ..writeByte(0)
      ..write(obj.lastSeenPostId)
      ..writeByte(1)
      ..write(obj.lastOpenedTime)
      ..writeByte(6)
      ..write(obj.savedTime)
      ..writeByte(3)
      ..write(obj.receipts)
      ..writeByte(4)
      ..write(obj._deprecatedThread)
      ..writeByte(5)
      ..write(obj.useArchive)
      ..writeByte(7)
      ..write(obj.postsMarkedAsYou)
      ..writeByte(8)
      ..write(obj.hiddenPostIds)
      ..writeByte(9)
      ..write(obj.deprecatedDraftReply)
      ..writeByte(10)
      ..write(obj.treeHiddenPostIds)
      ..writeByte(11)
      ..write(obj.hiddenPosterIds)
      ..writeByte(12)
      ..write(obj.translatedPosts)
      ..writeByte(13)
      ..write(obj.autoTranslate)
      ..writeByte(14)
      ..write(obj.useTree)
      ..writeByte(15)
      ..write(obj.variant)
      ..writeByte(16)
      ..write(obj.collapsedItems)
      ..writeByte(17)
      ..write(obj.downloadedAttachmentIds)
      ..writeByte(18)
      ..write(obj.imageboardKey)
      ..writeByte(21)
      ..write(obj.primarySubtreeParents)
      ..writeByte(22)
      ..write(obj.showInHistory)
      ..writeByte(23)
      ..write(obj.firstVisiblePostId)
      ..writeByte(24)
      ..write(obj.unseenPostIds)
      ..writeByte(25)
      ..write(obj.firstVisiblePostAlignment)
      ..writeByte(26)
      ..write(obj.postSortingMethod)
      ..writeByte(27)
      ..write(obj.postIdsToStartRepliesAtBottom)
      ..writeByte(28)
      ..write(obj.overrideShowPostIds)
      ..writeByte(29)
      ..write(obj.deprecatedReplyOptions)
      ..writeByte(30)
      ..write(obj.treeSplitId)
      ..writeByte(31)
      ..write(obj.draft)
      ..writeByte(19)
      ..write(obj.board)
      ..writeByte(20)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistentThreadStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PostReceiptFields {
  static String getPassword(PostReceipt x) => x.password;
  static const password = ReadOnlyHiveFieldAdapter<PostReceipt, String>(
    getter: getPassword,
    fieldNumber: 0,
    fieldName: 'password',
    merger: PrimitiveMerger(),
  );
  static int getId(PostReceipt x) => x.id;
  static const id = ReadOnlyHiveFieldAdapter<PostReceipt, int>(
    getter: getId,
    fieldNumber: 1,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static String getName(PostReceipt x) => x.name;
  static const name = ReadOnlyHiveFieldAdapter<PostReceipt, String>(
    getter: getName,
    fieldNumber: 2,
    fieldName: 'name',
    merger: PrimitiveMerger(),
  );
  static String getOptions(PostReceipt x) => x.options;
  static const options = ReadOnlyHiveFieldAdapter<PostReceipt, String>(
    getter: getOptions,
    fieldNumber: 3,
    fieldName: 'options',
    merger: PrimitiveMerger(),
  );
  static DateTime? getTime(PostReceipt x) => x.time;
  static const time = ReadOnlyHiveFieldAdapter<PostReceipt, DateTime?>(
    getter: getTime,
    fieldNumber: 4,
    fieldName: 'time',
    merger: PrimitiveMerger(),
  );
  static bool getMarkAsYou(PostReceipt x) => x.markAsYou;
  static void setMarkAsYou(PostReceipt x, bool v) => x.markAsYou = v;
  static const markAsYou = HiveFieldAdapter<PostReceipt, bool>(
    getter: getMarkAsYou,
    setter: setMarkAsYou,
    fieldNumber: 5,
    fieldName: 'markAsYou',
    merger: PrimitiveMerger(),
  );
  static bool getSpamFiltered(PostReceipt x) => x.spamFiltered;
  static void setSpamFiltered(PostReceipt x, bool v) => x.spamFiltered = v;
  static const spamFiltered = HiveFieldAdapter<PostReceipt, bool>(
    getter: getSpamFiltered,
    setter: setSpamFiltered,
    fieldNumber: 6,
    fieldName: 'spamFiltered',
    merger: PrimitiveMerger(),
  );
  static String? getIp(PostReceipt x) => x.ip;
  static void setIp(PostReceipt x, String? v) => x.ip = v;
  static const ip = HiveFieldAdapter<PostReceipt, String?>(
    getter: getIp,
    setter: setIp,
    fieldNumber: 7,
    fieldName: 'ip',
    merger: PrimitiveMerger(),
  );
  static DraftPost? getPost(PostReceipt x) => x.post;
  static void setPost(PostReceipt x, DraftPost? v) => x.post = v;
  static const post = HiveFieldAdapter<PostReceipt, DraftPost?>(
    getter: getPost,
    setter: setPost,
    fieldNumber: 8,
    fieldName: 'post',
    merger: NullableMerger(AdaptedMerger(DraftPostAdapter.kTypeId)),
  );
}

class PostReceiptAdapter extends TypeAdapter<PostReceipt> {
  const PostReceiptAdapter();

  static const int kTypeId = 4;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PostReceipt, dynamic>> fields =
      const {
    0: PostReceiptFields.password,
    1: PostReceiptFields.id,
    2: PostReceiptFields.name,
    3: PostReceiptFields.options,
    4: PostReceiptFields.time,
    5: PostReceiptFields.markAsYou,
    6: PostReceiptFields.spamFiltered,
    7: PostReceiptFields.ip,
    8: PostReceiptFields.post
  };

  @override
  PostReceipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PostReceipt(
      password: fields[0] as String,
      id: fields[1] as int,
      name: fields[2] == null ? '' : fields[2] as String,
      options: fields[3] == null ? '' : fields[3] as String,
      time: fields[4] as DateTime?,
      post: fields[8] as DraftPost?,
      markAsYou: fields[5] == null ? true : fields[5] as bool,
      spamFiltered: fields[6] == null ? false : fields[6] as bool,
      ip: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PostReceipt obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.password)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.options)
      ..writeByte(4)
      ..write(obj.time)
      ..writeByte(5)
      ..write(obj.markAsYou)
      ..writeByte(6)
      ..write(obj.spamFiltered)
      ..writeByte(7)
      ..write(obj.ip)
      ..writeByte(8)
      ..write(obj.post);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostReceiptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedAttachmentFields {
  static Attachment getAttachment(SavedAttachment x) => x.attachment;
  static const attachment =
      ReadOnlyHiveFieldAdapter<SavedAttachment, Attachment>(
    getter: getAttachment,
    fieldNumber: 0,
    fieldName: 'attachment',
    merger: AdaptedMerger(AttachmentAdapter.kTypeId),
  );
  static DateTime getSavedTime(SavedAttachment x) => x.savedTime;
  static const savedTime = ReadOnlyHiveFieldAdapter<SavedAttachment, DateTime>(
    getter: getSavedTime,
    fieldNumber: 1,
    fieldName: 'savedTime',
    merger: PrimitiveMerger(),
  );
  static List<int> getTags(SavedAttachment x) => x.tags;
  static const tags = ReadOnlyHiveFieldAdapter<SavedAttachment, List<int>>(
    getter: getTags,
    fieldNumber: 2,
    fieldName: 'tags',
    merger: SetLikePrimitiveListMerger<int>(),
  );
  static String? getSavedExt(SavedAttachment x) => x.savedExt;
  static void setSavedExt(SavedAttachment x, String? v) => x.savedExt = v;
  static const savedExt = HiveFieldAdapter<SavedAttachment, String?>(
    getter: getSavedExt,
    setter: setSavedExt,
    fieldNumber: 3,
    fieldName: 'savedExt',
    merger: PrimitiveMerger(),
  );
}

class SavedAttachmentAdapter extends TypeAdapter<SavedAttachment> {
  const SavedAttachmentAdapter();

  static const int kTypeId = 18;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<SavedAttachment, dynamic>> fields =
      const {
    0: SavedAttachmentFields.attachment,
    1: SavedAttachmentFields.savedTime,
    2: SavedAttachmentFields.tags,
    3: SavedAttachmentFields.savedExt
  };

  @override
  SavedAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedAttachment(
      attachment: fields[0] as Attachment,
      savedTime: fields[1] as DateTime,
      tags: (fields[2] as List?)?.cast<int>(),
      savedExt: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SavedAttachment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.attachment)
      ..writeByte(1)
      ..write(obj.savedTime)
      ..writeByte(2)
      ..write(obj.tags)
      ..writeByte(3)
      ..write(obj.savedExt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavedPostFields {
  static Post getPost(SavedPost x) => x.post;
  static void setPost(SavedPost x, Post v) => x.post = v;
  static const post = HiveFieldAdapter<SavedPost, Post>(
    getter: getPost,
    setter: setPost,
    fieldNumber: 0,
    fieldName: 'post',
    merger: AdaptedMerger(PostAdapter.kTypeId),
  );
  static DateTime getSavedTime(SavedPost x) => x.savedTime;
  static const savedTime = ReadOnlyHiveFieldAdapter<SavedPost, DateTime>(
    getter: getSavedTime,
    fieldNumber: 1,
    fieldName: 'savedTime',
    merger: PrimitiveMerger(),
  );
}

class SavedPostAdapter extends TypeAdapter<SavedPost> {
  const SavedPostAdapter();

  static const int kTypeId = 19;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<SavedPost, dynamic>> fields = const {
    0: SavedPostFields.post,
    1: SavedPostFields.savedTime
  };

  @override
  SavedPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedPost(
      post: fields[0] as Post,
      savedTime: fields[1] as DateTime,
    )..deprecatedThread = fields[2] as Thread?;
  }

  @override
  void write(BinaryWriter writer, SavedPost obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.post)
      ..writeByte(1)
      ..write(obj.savedTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PersistentBrowserTabFields {
  static String? getBoard(PersistentBrowserTab x) => x.board;
  static void setBoard(PersistentBrowserTab x, String? v) => x.board = v;
  static const board = HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getBoard,
    setter: setBoard,
    fieldNumber: 0,
    fieldName: 'board',
    merger: PrimitiveMerger(),
  );
  static ThreadIdentifier? getThread(PersistentBrowserTab x) => x.thread;
  static void setThread(PersistentBrowserTab x, ThreadIdentifier? v) =>
      x.thread = v;
  static const thread =
      HiveFieldAdapter<PersistentBrowserTab, ThreadIdentifier?>(
    getter: getThread,
    setter: setThread,
    fieldNumber: 1,
    fieldName: 'thread',
    merger: NullableMerger(AdaptedMerger(ThreadIdentifierAdapter.kTypeId)),
  );
  static String? getDeprecatedDraftThread(PersistentBrowserTab x) =>
      x.deprecatedDraftThread;
  static void setDeprecatedDraftThread(PersistentBrowserTab x, String? v) =>
      x.deprecatedDraftThread = v;
  static const deprecatedDraftThread =
      HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getDeprecatedDraftThread,
    setter: setDeprecatedDraftThread,
    fieldNumber: 2,
    fieldName: 'deprecatedDraftThread',
    merger: PrimitiveMerger(),
  );
  static String? getDeprecatedDraftSubject(PersistentBrowserTab x) =>
      x.deprecatedDraftSubject;
  static void setDeprecatedDraftSubject(PersistentBrowserTab x, String? v) =>
      x.deprecatedDraftSubject = v;
  static const deprecatedDraftSubject =
      HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getDeprecatedDraftSubject,
    setter: setDeprecatedDraftSubject,
    fieldNumber: 3,
    fieldName: 'deprecatedDraftSubject',
    merger: PrimitiveMerger(),
  );
  static String? getImageboardKey(PersistentBrowserTab x) => x.imageboardKey;
  static void setImageboardKey(PersistentBrowserTab x, String? v) =>
      x.imageboardKey = v;
  static const imageboardKey = HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getImageboardKey,
    setter: setImageboardKey,
    fieldNumber: 4,
    fieldName: 'imageboardKey',
    merger: PrimitiveMerger(),
  );
  static String? getDeprecatedDraftOptions(PersistentBrowserTab x) =>
      x.deprecatedDraftOptions;
  static void setDeprecatedDraftOptions(PersistentBrowserTab x, String? v) =>
      x.deprecatedDraftOptions = v;
  static const deprecatedDraftOptions =
      HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getDeprecatedDraftOptions,
    setter: setDeprecatedDraftOptions,
    fieldNumber: 5,
    fieldName: 'deprecatedDraftOptions',
    merger: PrimitiveMerger(),
  );
  static String? getDeprecatedDraftFilePath(PersistentBrowserTab x) =>
      x.deprecatedDraftFilePath;
  static void setDeprecatedDraftFilePath(PersistentBrowserTab x, String? v) =>
      x.deprecatedDraftFilePath = v;
  static const deprecatedDraftFilePath =
      HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getDeprecatedDraftFilePath,
    setter: setDeprecatedDraftFilePath,
    fieldNumber: 6,
    fieldName: 'deprecatedDraftFilePath',
    merger: PrimitiveMerger(),
  );
  static String? getInitialSearch(PersistentBrowserTab x) => x.initialSearch;
  static void setInitialSearch(PersistentBrowserTab x, String? v) =>
      x.initialSearch = v;
  static const initialSearch = HiveFieldAdapter<PersistentBrowserTab, String?>(
    getter: getInitialSearch,
    setter: setInitialSearch,
    fieldNumber: 7,
    fieldName: 'initialSearch',
    merger: PrimitiveMerger(),
  );
  static CatalogVariant? getCatalogVariant(PersistentBrowserTab x) =>
      x.catalogVariant;
  static void setCatalogVariant(PersistentBrowserTab x, CatalogVariant? v) =>
      x.catalogVariant = v;
  static const catalogVariant =
      HiveFieldAdapter<PersistentBrowserTab, CatalogVariant?>(
    getter: getCatalogVariant,
    setter: setCatalogVariant,
    fieldNumber: 8,
    fieldName: 'catalogVariant',
    merger: PrimitiveMerger(),
  );
  static bool getIncognito(PersistentBrowserTab x) => x.incognito;
  static void setIncognito(PersistentBrowserTab x, bool v) => x.incognito = v;
  static const incognito = HiveFieldAdapter<PersistentBrowserTab, bool>(
    getter: getIncognito,
    setter: setIncognito,
    fieldNumber: 9,
    fieldName: 'incognito',
    merger: PrimitiveMerger(),
  );
  static String getId(PersistentBrowserTab x) => x.id;
  static void setId(PersistentBrowserTab x, String v) => x.id = v;
  static const id = HiveFieldAdapter<PersistentBrowserTab, String>(
    getter: getId,
    setter: setId,
    fieldNumber: 10,
    fieldName: 'id',
    merger: PrimitiveMerger(),
  );
  static DraftPost? getDraft(PersistentBrowserTab x) => x.draft;
  static void setDraft(PersistentBrowserTab x, DraftPost? v) => x.draft = v;
  static const draft = HiveFieldAdapter<PersistentBrowserTab, DraftPost?>(
    getter: getDraft,
    setter: setDraft,
    fieldNumber: 11,
    fieldName: 'draft',
    merger: NullableMerger(AdaptedMerger(DraftPostAdapter.kTypeId)),
  );
}

class PersistentBrowserTabAdapter extends TypeAdapter<PersistentBrowserTab> {
  const PersistentBrowserTabAdapter();

  static const int kTypeId = 21;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PersistentBrowserTab, dynamic>>
      fields = const {
    0: PersistentBrowserTabFields.board,
    1: PersistentBrowserTabFields.thread,
    2: PersistentBrowserTabFields.deprecatedDraftThread,
    3: PersistentBrowserTabFields.deprecatedDraftSubject,
    4: PersistentBrowserTabFields.imageboardKey,
    5: PersistentBrowserTabFields.deprecatedDraftOptions,
    6: PersistentBrowserTabFields.deprecatedDraftFilePath,
    7: PersistentBrowserTabFields.initialSearch,
    8: PersistentBrowserTabFields.catalogVariant,
    9: PersistentBrowserTabFields.incognito,
    10: PersistentBrowserTabFields.id,
    11: PersistentBrowserTabFields.draft
  };

  @override
  PersistentBrowserTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    _readHookPersistentBrowserTabFields(fields);
    return PersistentBrowserTab(
      board: fields[0] as String?,
      thread: fields[1] as ThreadIdentifier?,
      deprecatedDraftThread: fields[2] as String?,
      deprecatedDraftSubject: fields[3] as String?,
      imageboardKey: fields[4] as String?,
      deprecatedDraftOptions: fields[5] as String?,
      deprecatedDraftFilePath: fields[6] as String?,
      initialSearch: fields[7] as String?,
      catalogVariant: fields[8] as CatalogVariant?,
      incognito: fields[9] == null ? false : fields[9] as bool,
      id: fields[10] == null ? '' : fields[10] as String,
      draft: fields[11] as DraftPost?,
    );
  }

  @override
  void write(BinaryWriter writer, PersistentBrowserTab obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.thread)
      ..writeByte(2)
      ..write(obj.deprecatedDraftThread)
      ..writeByte(3)
      ..write(obj.deprecatedDraftSubject)
      ..writeByte(4)
      ..write(obj.imageboardKey)
      ..writeByte(5)
      ..write(obj.deprecatedDraftOptions)
      ..writeByte(6)
      ..write(obj.deprecatedDraftFilePath)
      ..writeByte(7)
      ..write(obj.initialSearch)
      ..writeByte(8)
      ..write(obj.catalogVariant)
      ..writeByte(9)
      ..write(obj.incognito)
      ..writeByte(10)
      ..write(obj.id)
      ..writeByte(11)
      ..write(obj.draft);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistentBrowserTabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PersistentBrowserStateFields {
  static List<PersistentBrowserTab> getDeprecatedTabs(
          PersistentBrowserState x) =>
      x.deprecatedTabs;
  static void setDeprecatedTabs(
          PersistentBrowserState x, List<PersistentBrowserTab> v) =>
      x.deprecatedTabs = v;
  static const deprecatedTabs =
      HiveFieldAdapter<PersistentBrowserState, List<PersistentBrowserTab>>(
    getter: getDeprecatedTabs,
    setter: setDeprecatedTabs,
    fieldNumber: 0,
    fieldName: 'deprecatedTabs',
    merger: PersistentBrowserTab.listMerger,
  );
  static Map<String, List<int>> getHiddenIds(PersistentBrowserState x) =>
      x.hiddenIds;
  static const hiddenIds =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, List<int>>>(
    getter: getHiddenIds,
    fieldNumber: 2,
    fieldName: 'hiddenIds',
    merger: MapMerger<String, List<int>>(SetLikePrimitiveListMerger()),
  );
  static List<String> getFavouriteBoards(PersistentBrowserState x) =>
      x.favouriteBoards;
  static const favouriteBoards =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, List<String>>(
    getter: getFavouriteBoards,
    fieldNumber: 3,
    fieldName: 'favouriteBoards',
    merger: OrderedSetLikePrimitiveListMerger<String>(),
  );
  static Map<String, List<int>> getAutosavedIds(PersistentBrowserState x) =>
      x.autosavedIds;
  static const autosavedIds =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, List<int>>>(
    getter: getAutosavedIds,
    fieldNumber: 5,
    fieldName: 'autosavedIds',
    merger: MapMerger<String, List<int>>(SetLikePrimitiveListMerger()),
  );
  static Map<String, String> getLoginFields(PersistentBrowserState x) =>
      x.loginFields;
  static void setLoginFields(PersistentBrowserState x, Map<String, String> v) =>
      x.loginFields = v;
  static const loginFields =
      HiveFieldAdapter<PersistentBrowserState, Map<String, String>>(
    getter: getLoginFields,
    setter: setLoginFields,
    fieldNumber: 7,
    fieldName: 'loginFields',
    merger: MapMerger(PrimitiveMerger()),
  );
  static String getNotificationsId(PersistentBrowserState x) =>
      x.notificationsId;
  static void setNotificationsId(PersistentBrowserState x, String v) =>
      x.notificationsId = v;
  static const notificationsId =
      HiveFieldAdapter<PersistentBrowserState, String>(
    getter: getNotificationsId,
    setter: setNotificationsId,
    fieldNumber: 8,
    fieldName: 'notificationsId',
    merger: PrimitiveMerger(),
  );
  static List<BoardWatch> getBoardWatches(PersistentBrowserState x) =>
      x.boardWatches;
  static void setBoardWatches(PersistentBrowserState x, List<BoardWatch> v) =>
      x.boardWatches = v;
  static const boardWatches =
      HiveFieldAdapter<PersistentBrowserState, List<BoardWatch>>(
    getter: getBoardWatches,
    setter: setBoardWatches,
    fieldNumber: 11,
    fieldName: 'boardWatches',
    merger: MapLikeListMerger<BoardWatch, String>(
        childMerger: AdaptedMerger(BoardWatchAdapter.kTypeId),
        keyer: BoardWatchFields.getBoard),
  );
  static bool getNotificationsMigrated(PersistentBrowserState x) =>
      x.notificationsMigrated;
  static void setNotificationsMigrated(PersistentBrowserState x, bool v) =>
      x.notificationsMigrated = v;
  static const notificationsMigrated =
      HiveFieldAdapter<PersistentBrowserState, bool>(
    getter: getNotificationsMigrated,
    setter: setNotificationsMigrated,
    fieldNumber: 12,
    fieldName: 'notificationsMigrated',
    merger: PrimitiveMerger(),
  );
  static bool? getUseTree(PersistentBrowserState x) => x.useTree;
  static void setUseTree(PersistentBrowserState x, bool? v) => x.useTree = v;
  static const useTree = HiveFieldAdapter<PersistentBrowserState, bool?>(
    getter: getUseTree,
    setter: setUseTree,
    fieldNumber: 16,
    fieldName: 'useTree',
    merger: PrimitiveMerger(),
  );
  static Map<String, CatalogVariant> getCatalogVariants(
          PersistentBrowserState x) =>
      x.catalogVariants;
  static const catalogVariants = ReadOnlyHiveFieldAdapter<
      PersistentBrowserState, Map<String, CatalogVariant>>(
    getter: getCatalogVariants,
    fieldNumber: 17,
    fieldName: 'catalogVariants',
    merger: MapMerger(PrimitiveMerger()),
  );
  static Map<String, String> getPostingNames(PersistentBrowserState x) =>
      x.postingNames;
  static const postingNames =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, String>>(
    getter: getPostingNames,
    fieldNumber: 18,
    fieldName: 'postingNames',
    merger: MapMerger(PrimitiveMerger()),
  );
  static bool getTreeModeInitiallyCollapseSecondLevelReplies(
          PersistentBrowserState x) =>
      x.treeModeInitiallyCollapseSecondLevelReplies;
  static void setTreeModeInitiallyCollapseSecondLevelReplies(
          PersistentBrowserState x, bool v) =>
      x.treeModeInitiallyCollapseSecondLevelReplies = v;
  static const treeModeInitiallyCollapseSecondLevelReplies =
      HiveFieldAdapter<PersistentBrowserState, bool>(
    getter: getTreeModeInitiallyCollapseSecondLevelReplies,
    setter: setTreeModeInitiallyCollapseSecondLevelReplies,
    fieldNumber: 19,
    fieldName: 'treeModeInitiallyCollapseSecondLevelReplies',
    merger: PrimitiveMerger(),
  );
  static bool getTreeModeCollapsedPostsShowBody(PersistentBrowserState x) =>
      x.treeModeCollapsedPostsShowBody;
  static void setTreeModeCollapsedPostsShowBody(
          PersistentBrowserState x, bool v) =>
      x.treeModeCollapsedPostsShowBody = v;
  static const treeModeCollapsedPostsShowBody =
      HiveFieldAdapter<PersistentBrowserState, bool>(
    getter: getTreeModeCollapsedPostsShowBody,
    setter: setTreeModeCollapsedPostsShowBody,
    fieldNumber: 20,
    fieldName: 'treeModeCollapsedPostsShowBody',
    merger: PrimitiveMerger(),
  );
  static bool? getUseCatalogGrid(PersistentBrowserState x) => x.useCatalogGrid;
  static void setUseCatalogGrid(PersistentBrowserState x, bool? v) =>
      x.useCatalogGrid = v;
  static const useCatalogGrid = HiveFieldAdapter<PersistentBrowserState, bool?>(
    getter: getUseCatalogGrid,
    setter: setUseCatalogGrid,
    fieldNumber: 21,
    fieldName: 'useCatalogGrid',
    merger: PrimitiveMerger(),
  );
  static Map<String, bool> getUseCatalogGridPerBoard(
          PersistentBrowserState x) =>
      x.useCatalogGridPerBoard;
  static const useCatalogGridPerBoard =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, bool>>(
    getter: getUseCatalogGridPerBoard,
    fieldNumber: 22,
    fieldName: 'useCatalogGridPerBoard',
    merger: MapMerger(PrimitiveMerger()),
  );
  static Map<ThreadIdentifier, ThreadWatch> getThreadWatches(
          PersistentBrowserState x) =>
      x.threadWatches;
  static void setThreadWatches(
          PersistentBrowserState x, Map<ThreadIdentifier, ThreadWatch> v) =>
      x.threadWatches = v;
  static const threadWatches = HiveFieldAdapter<PersistentBrowserState,
      Map<ThreadIdentifier, ThreadWatch>>(
    getter: getThreadWatches,
    setter: setThreadWatches,
    fieldNumber: 23,
    fieldName: 'threadWatches',
    merger: MapMerger(AdaptedMerger(ThreadWatchAdapter.kTypeId)),
  );
  static bool getTreeModeRepliesToOPAreTopLevel(PersistentBrowserState x) =>
      x.treeModeRepliesToOPAreTopLevel;
  static void setTreeModeRepliesToOPAreTopLevel(
          PersistentBrowserState x, bool v) =>
      x.treeModeRepliesToOPAreTopLevel = v;
  static const treeModeRepliesToOPAreTopLevel =
      HiveFieldAdapter<PersistentBrowserState, bool>(
    getter: getTreeModeRepliesToOPAreTopLevel,
    setter: setTreeModeRepliesToOPAreTopLevel,
    fieldNumber: 24,
    fieldName: 'treeModeRepliesToOPAreTopLevel',
    merger: PrimitiveMerger(),
  );
  static Map<String, List<int>> getOverrideShowIds(PersistentBrowserState x) =>
      x.overrideShowIds;
  static const overrideShowIds =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, List<int>>>(
    getter: getOverrideShowIds,
    fieldNumber: 25,
    fieldName: 'overrideShowIds',
    merger: MapMerger<String, List<int>>(SetLikePrimitiveListMerger()),
  );
  static bool getTreeModeNewRepliesAreLinear(PersistentBrowserState x) =>
      x.treeModeNewRepliesAreLinear;
  static void setTreeModeNewRepliesAreLinear(
          PersistentBrowserState x, bool v) =>
      x.treeModeNewRepliesAreLinear = v;
  static const treeModeNewRepliesAreLinear =
      HiveFieldAdapter<PersistentBrowserState, bool>(
    getter: getTreeModeNewRepliesAreLinear,
    setter: setTreeModeNewRepliesAreLinear,
    fieldNumber: 26,
    fieldName: 'treeModeNewRepliesAreLinear',
    merger: PrimitiveMerger(),
  );
  static Map<String, List<int>> getAutowatchedIds(PersistentBrowserState x) =>
      x.autowatchedIds;
  static const autowatchedIds =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Map<String, List<int>>>(
    getter: getAutowatchedIds,
    fieldNumber: 27,
    fieldName: 'autowatchedIds',
    merger: MapMerger<String, List<int>>(SetLikePrimitiveListMerger()),
  );
  static List<DraftPost> getOutbox(PersistentBrowserState x) => x.outbox;
  static const outbox =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, List<DraftPost>>(
    getter: getOutbox,
    fieldNumber: 28,
    fieldName: 'outbox',
    merger: OrderedSetLikePrimitiveListMerger(),
  );
  static Set<String> getDisabledArchiveNames(PersistentBrowserState x) =>
      x.disabledArchiveNames;
  static const disabledArchiveNames =
      ReadOnlyHiveFieldAdapter<PersistentBrowserState, Set<String>>(
    getter: getDisabledArchiveNames,
    fieldNumber: 29,
    fieldName: 'disabledArchiveNames',
    merger: PrimitiveSetMerger(),
  );
  static PostSortingMethod? getPostSortingMethod(PersistentBrowserState x) =>
      x.postSortingMethod;
  static void setPostSortingMethod(
          PersistentBrowserState x, PostSortingMethod? v) =>
      x.postSortingMethod = v;
  static const postSortingMethod =
      HiveFieldAdapter<PersistentBrowserState, PostSortingMethod?>(
    getter: getPostSortingMethod,
    setter: setPostSortingMethod,
    fieldNumber: 30,
    fieldName: 'postSortingMethod',
    merger: PrimitiveMerger(),
  );
  static Map<String, PostSortingMethod> getPostSortingMethodPerBoard(
          PersistentBrowserState x) =>
      x.postSortingMethodPerBoard;
  static const postSortingMethodPerBoard = ReadOnlyHiveFieldAdapter<
      PersistentBrowserState, Map<String, PostSortingMethod>>(
    getter: getPostSortingMethodPerBoard,
    fieldNumber: 31,
    fieldName: 'postSortingMethodPerBoard',
    merger: MapMerger(PrimitiveMerger()),
  );
}

class PersistentBrowserStateAdapter
    extends TypeAdapter<PersistentBrowserState> {
  const PersistentBrowserStateAdapter();

  static const int kTypeId = 22;

  @override
  final int typeId = kTypeId;

  @override
  final Map<int, ReadOnlyHiveFieldAdapter<PersistentBrowserState, dynamic>>
      fields = const {
    0: PersistentBrowserStateFields.deprecatedTabs,
    2: PersistentBrowserStateFields.hiddenIds,
    3: PersistentBrowserStateFields.favouriteBoards,
    5: PersistentBrowserStateFields.autosavedIds,
    7: PersistentBrowserStateFields.loginFields,
    8: PersistentBrowserStateFields.notificationsId,
    11: PersistentBrowserStateFields.boardWatches,
    12: PersistentBrowserStateFields.notificationsMigrated,
    16: PersistentBrowserStateFields.useTree,
    17: PersistentBrowserStateFields.catalogVariants,
    18: PersistentBrowserStateFields.postingNames,
    19: PersistentBrowserStateFields
        .treeModeInitiallyCollapseSecondLevelReplies,
    20: PersistentBrowserStateFields.treeModeCollapsedPostsShowBody,
    21: PersistentBrowserStateFields.useCatalogGrid,
    22: PersistentBrowserStateFields.useCatalogGridPerBoard,
    23: PersistentBrowserStateFields.threadWatches,
    24: PersistentBrowserStateFields.treeModeRepliesToOPAreTopLevel,
    25: PersistentBrowserStateFields.overrideShowIds,
    26: PersistentBrowserStateFields.treeModeNewRepliesAreLinear,
    27: PersistentBrowserStateFields.autowatchedIds,
    28: PersistentBrowserStateFields.outbox,
    29: PersistentBrowserStateFields.disabledArchiveNames,
    30: PersistentBrowserStateFields.postSortingMethod,
    31: PersistentBrowserStateFields.postSortingMethodPerBoard
  };

  @override
  PersistentBrowserState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    _readHookPersistentBrowserStateFields(fields);
    return PersistentBrowserState(
      deprecatedTabs: (fields[0] as List).cast<PersistentBrowserTab>(),
      hiddenIds: fields[2] == null
          ? {}
          : (fields[2] as Map).map((dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<int>())),
      favouriteBoards:
          fields[3] == null ? [] : (fields[3] as List).cast<String>(),
      autosavedIds: fields[5] == null
          ? {}
          : (fields[5] as Map).map((dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<int>())),
      autowatchedIds: fields[27] == null
          ? {}
          : (fields[27] as Map).map((dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<int>())),
      deprecatedHiddenImageMD5s:
          fields[6] == null ? {} : (fields[6] as Set).cast<String>(),
      loginFields:
          fields[7] == null ? {} : (fields[7] as Map).cast<String, String>(),
      notificationsId: fields[8] as String?,
      deprecatedThreadWatches:
          fields[10] == null ? [] : (fields[10] as List).cast<ThreadWatch>(),
      threadWatches: fields[23] == null
          ? {}
          : (fields[23] as Map).cast<ThreadIdentifier, ThreadWatch>(),
      boardWatches:
          fields[11] == null ? [] : (fields[11] as List).cast<BoardWatch>(),
      notificationsMigrated: fields[12] == null ? false : fields[12] as bool,
      deprecatedBoardSortingMethods: fields[13] == null
          ? {}
          : (fields[13] as Map).cast<String, ThreadSortingMethod>(),
      deprecatedBoardReverseSortings:
          fields[14] == null ? {} : (fields[14] as Map).cast<String, bool>(),
      catalogVariants: fields[17] == null
          ? {}
          : (fields[17] as Map).cast<String, CatalogVariant>(),
      postingNames:
          fields[18] == null ? {} : (fields[18] as Map).cast<String, String>(),
      useTree: fields[16] as bool?,
      treeModeInitiallyCollapseSecondLevelReplies:
          fields[19] == null ? false : fields[19] as bool,
      treeModeCollapsedPostsShowBody:
          fields[20] == null ? false : fields[20] as bool,
      treeModeRepliesToOPAreTopLevel:
          fields[24] == null ? true : fields[24] as bool,
      useCatalogGrid: fields[21] as bool?,
      useCatalogGridPerBoard:
          fields[22] == null ? {} : (fields[22] as Map).cast<String, bool>(),
      overrideShowIds: fields[25] == null
          ? {}
          : (fields[25] as Map).map((dynamic k, dynamic v) =>
              MapEntry(k as String, (v as List).cast<int>())),
      treeModeNewRepliesAreLinear:
          fields[26] == null ? true : fields[26] as bool,
      outbox: fields[28] == null ? [] : (fields[28] as List).cast<DraftPost>(),
      disabledArchiveNames:
          fields[29] == null ? {} : (fields[29] as Set).cast<String>(),
      postSortingMethod: fields[30] as PostSortingMethod?,
      postSortingMethodPerBoard: fields[31] == null
          ? {}
          : (fields[31] as Map).cast<String, PostSortingMethod>(),
    );
  }

  @override
  void write(BinaryWriter writer, PersistentBrowserState obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.deprecatedTabs)
      ..writeByte(2)
      ..write(obj.hiddenIds)
      ..writeByte(3)
      ..write(obj.favouriteBoards)
      ..writeByte(5)
      ..write(obj.autosavedIds)
      ..writeByte(7)
      ..write(obj.loginFields)
      ..writeByte(8)
      ..write(obj.notificationsId)
      ..writeByte(11)
      ..write(obj.boardWatches)
      ..writeByte(12)
      ..write(obj.notificationsMigrated)
      ..writeByte(16)
      ..write(obj.useTree)
      ..writeByte(17)
      ..write(obj.catalogVariants)
      ..writeByte(18)
      ..write(obj.postingNames)
      ..writeByte(19)
      ..write(obj.treeModeInitiallyCollapseSecondLevelReplies)
      ..writeByte(20)
      ..write(obj.treeModeCollapsedPostsShowBody)
      ..writeByte(21)
      ..write(obj.useCatalogGrid)
      ..writeByte(22)
      ..write(obj.useCatalogGridPerBoard)
      ..writeByte(23)
      ..write(obj.threadWatches)
      ..writeByte(24)
      ..write(obj.treeModeRepliesToOPAreTopLevel)
      ..writeByte(25)
      ..write(obj.overrideShowIds)
      ..writeByte(26)
      ..write(obj.treeModeNewRepliesAreLinear)
      ..writeByte(27)
      ..write(obj.autowatchedIds)
      ..writeByte(28)
      ..write(obj.outbox)
      ..writeByte(29)
      ..write(obj.disabledArchiveNames)
      ..writeByte(30)
      ..write(obj.postSortingMethod)
      ..writeByte(31)
      ..write(obj.postSortingMethodPerBoard);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistentBrowserStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
