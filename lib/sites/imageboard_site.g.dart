// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imageboard_site.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CatalogVariantAdapter extends TypeAdapter<CatalogVariant> {
  @override
  final int typeId = 33;

  @override
  CatalogVariant read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CatalogVariant.unsorted;
      case 1:
        return CatalogVariant.unsortedReversed;
      case 2:
        return CatalogVariant.lastPostTime;
      case 3:
        return CatalogVariant.lastPostTimeReversed;
      case 4:
        return CatalogVariant.replyCount;
      case 5:
        return CatalogVariant.replyCountReversed;
      case 6:
        return CatalogVariant.threadPostTime;
      case 7:
        return CatalogVariant.threadPostTimeReversed;
      case 8:
        return CatalogVariant.savedTime;
      case 9:
        return CatalogVariant.savedTimeReversed;
      case 10:
        return CatalogVariant.postsPerMinute;
      case 11:
        return CatalogVariant.postsPerMinuteReversed;
      case 12:
        return CatalogVariant.lastReplyTime;
      case 13:
        return CatalogVariant.lastReplyTimeReversed;
      case 14:
        return CatalogVariant.imageCount;
      case 15:
        return CatalogVariant.imageCountReversed;
      case 16:
        return CatalogVariant.lastReplyByYouTime;
      case 17:
        return CatalogVariant.lastReplyByYouTimeReversed;
      case 18:
        return CatalogVariant.redditHot;
      case 19:
        return CatalogVariant.redditNew;
      case 20:
        return CatalogVariant.redditRising;
      case 21:
        return CatalogVariant.redditControversialPastHour;
      case 22:
        return CatalogVariant.redditControversialPast24Hours;
      case 23:
        return CatalogVariant.redditControversialPastWeek;
      case 24:
        return CatalogVariant.redditControversialPastMonth;
      case 25:
        return CatalogVariant.redditControversialPastYear;
      case 26:
        return CatalogVariant.redditControversialAllTime;
      case 27:
        return CatalogVariant.redditTopPastHour;
      case 28:
        return CatalogVariant.redditTopPast24Hours;
      case 29:
        return CatalogVariant.redditTopPastWeek;
      case 30:
        return CatalogVariant.redditTopPastMonth;
      case 31:
        return CatalogVariant.redditTopPastYear;
      case 32:
        return CatalogVariant.redditTopAllTime;
      case 33:
        return CatalogVariant.chan4NativeArchive;
      default:
        return CatalogVariant.unsorted;
    }
  }

  @override
  void write(BinaryWriter writer, CatalogVariant obj) {
    switch (obj) {
      case CatalogVariant.unsorted:
        writer.writeByte(0);
        break;
      case CatalogVariant.unsortedReversed:
        writer.writeByte(1);
        break;
      case CatalogVariant.lastPostTime:
        writer.writeByte(2);
        break;
      case CatalogVariant.lastPostTimeReversed:
        writer.writeByte(3);
        break;
      case CatalogVariant.replyCount:
        writer.writeByte(4);
        break;
      case CatalogVariant.replyCountReversed:
        writer.writeByte(5);
        break;
      case CatalogVariant.threadPostTime:
        writer.writeByte(6);
        break;
      case CatalogVariant.threadPostTimeReversed:
        writer.writeByte(7);
        break;
      case CatalogVariant.savedTime:
        writer.writeByte(8);
        break;
      case CatalogVariant.savedTimeReversed:
        writer.writeByte(9);
        break;
      case CatalogVariant.postsPerMinute:
        writer.writeByte(10);
        break;
      case CatalogVariant.postsPerMinuteReversed:
        writer.writeByte(11);
        break;
      case CatalogVariant.lastReplyTime:
        writer.writeByte(12);
        break;
      case CatalogVariant.lastReplyTimeReversed:
        writer.writeByte(13);
        break;
      case CatalogVariant.imageCount:
        writer.writeByte(14);
        break;
      case CatalogVariant.imageCountReversed:
        writer.writeByte(15);
        break;
      case CatalogVariant.lastReplyByYouTime:
        writer.writeByte(16);
        break;
      case CatalogVariant.lastReplyByYouTimeReversed:
        writer.writeByte(17);
        break;
      case CatalogVariant.redditHot:
        writer.writeByte(18);
        break;
      case CatalogVariant.redditNew:
        writer.writeByte(19);
        break;
      case CatalogVariant.redditRising:
        writer.writeByte(20);
        break;
      case CatalogVariant.redditControversialPastHour:
        writer.writeByte(21);
        break;
      case CatalogVariant.redditControversialPast24Hours:
        writer.writeByte(22);
        break;
      case CatalogVariant.redditControversialPastWeek:
        writer.writeByte(23);
        break;
      case CatalogVariant.redditControversialPastMonth:
        writer.writeByte(24);
        break;
      case CatalogVariant.redditControversialPastYear:
        writer.writeByte(25);
        break;
      case CatalogVariant.redditControversialAllTime:
        writer.writeByte(26);
        break;
      case CatalogVariant.redditTopPastHour:
        writer.writeByte(27);
        break;
      case CatalogVariant.redditTopPast24Hours:
        writer.writeByte(28);
        break;
      case CatalogVariant.redditTopPastWeek:
        writer.writeByte(29);
        break;
      case CatalogVariant.redditTopPastMonth:
        writer.writeByte(30);
        break;
      case CatalogVariant.redditTopPastYear:
        writer.writeByte(31);
        break;
      case CatalogVariant.redditTopAllTime:
        writer.writeByte(32);
        break;
      case CatalogVariant.chan4NativeArchive:
        writer.writeByte(33);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogVariantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
