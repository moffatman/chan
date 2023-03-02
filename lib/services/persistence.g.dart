// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persistence.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersistentRecentSearchesAdapter
    extends TypeAdapter<PersistentRecentSearches> {
  @override
  final int typeId = 8;

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

class PersistentThreadStateAdapter extends TypeAdapter<PersistentThreadState> {
  @override
  final int typeId = 3;

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
      ..draftReply = fields[9] == null ? '' : fields[9] as String
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
          fields[17] == null ? [] : (fields[17] as List).cast<String>();
  }

  @override
  void write(BinaryWriter writer, PersistentThreadState obj) {
    writer
      ..writeByte(20)
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
      ..write(obj.draftReply)
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

class PostReceiptAdapter extends TypeAdapter<PostReceipt> {
  @override
  final int typeId = 4;

  @override
  PostReceipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PostReceipt(
      password: fields[0] as String,
      id: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PostReceipt obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.password)
      ..writeByte(1)
      ..write(obj.id);
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

class SavedAttachmentAdapter extends TypeAdapter<SavedAttachment> {
  @override
  final int typeId = 18;

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
    );
  }

  @override
  void write(BinaryWriter writer, SavedAttachment obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.attachment)
      ..writeByte(1)
      ..write(obj.savedTime)
      ..writeByte(2)
      ..write(obj.tags);
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

class PersistentBrowserTabAdapter extends TypeAdapter<PersistentBrowserTab> {
  @override
  final int typeId = 21;

  @override
  PersistentBrowserTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersistentBrowserTab(
      board: fields[0] as ImageboardBoard?,
      thread: fields[1] as ThreadIdentifier?,
      draftThread: fields[2] == null ? '' : fields[2] as String,
      draftSubject: fields[3] == null ? '' : fields[3] as String,
      imageboardKey: fields[4] as String?,
      draftOptions: fields[5] == null ? '' : fields[5] as String,
      draftFilePath: fields[6] as String?,
      initialSearch: fields[7] as String?,
      catalogVariant: fields[8] as CatalogVariant?,
      incognito: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PersistentBrowserTab obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.board)
      ..writeByte(1)
      ..write(obj.thread)
      ..writeByte(2)
      ..write(obj.draftThread)
      ..writeByte(3)
      ..write(obj.draftSubject)
      ..writeByte(4)
      ..write(obj.imageboardKey)
      ..writeByte(5)
      ..write(obj.draftOptions)
      ..writeByte(6)
      ..write(obj.draftFilePath)
      ..writeByte(7)
      ..write(obj.initialSearch)
      ..writeByte(8)
      ..write(obj.catalogVariant)
      ..writeByte(9)
      ..write(obj.incognito);
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

class PersistentBrowserStateAdapter
    extends TypeAdapter<PersistentBrowserState> {
  @override
  final int typeId = 22;

  @override
  PersistentBrowserState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
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
      hiddenImageMD5s:
          fields[6] == null ? [] : (fields[6] as List).cast<String>(),
      loginFields:
          fields[7] == null ? {} : (fields[7] as Map).cast<String, String>(),
      notificationsId: fields[8] as String?,
      threadWatches:
          fields[10] == null ? [] : (fields[10] as List).cast<ThreadWatch>(),
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
    );
  }

  @override
  void write(BinaryWriter writer, PersistentBrowserState obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.deprecatedTabs)
      ..writeByte(2)
      ..write(obj.hiddenIds)
      ..writeByte(3)
      ..write(obj.favouriteBoards)
      ..writeByte(5)
      ..write(obj.autosavedIds)
      ..writeByte(6)
      ..write(obj.hiddenImageMD5s.toList())
      ..writeByte(7)
      ..write(obj.loginFields)
      ..writeByte(8)
      ..write(obj.notificationsId)
      ..writeByte(10)
      ..write(obj.threadWatches)
      ..writeByte(11)
      ..write(obj.boardWatches)
      ..writeByte(12)
      ..write(obj.notificationsMigrated)
      ..writeByte(13)
      ..write(obj.deprecatedBoardSortingMethods)
      ..writeByte(14)
      ..write(obj.deprecatedBoardReverseSortings)
      ..writeByte(16)
      ..write(obj.useTree)
      ..writeByte(17)
      ..write(obj.catalogVariants)
      ..writeByte(18)
      ..write(obj.postingNames);
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
