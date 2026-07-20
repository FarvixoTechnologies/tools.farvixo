import 'package:hive/hive.dart';

import 'parsed_qr.dart';
import 'qr_type.dart';

/// A persisted scan/generate record.
///
/// Stored in an encrypted Hive box via the hand-written [ScanHistoryEntryAdapter]
/// (no build_runner). The binary layout is versioned by a leading field count so
/// older records keep deserializing after new fields are appended — see the
/// adapter for the forward/backward-compatibility contract.
class ScanHistoryEntry {
  ScanHistoryEntry({
    required this.id,
    required this.raw,
    required this.typeIndex,
    required this.title,
    this.subtitle,
    this.source = 'camera',
    required this.createdAt,
    this.favorite = false,
    this.pinned = false,
    this.deletedAt,
  });

  /// Stable unique id (millisecond timestamp + short random suffix).
  final String id;

  /// Original decoded/encoded string.
  final String raw;

  /// [QrType] index — stored as int so reordering the enum stays a conscious
  /// migration decision, never an accidental data shift.
  final int typeIndex;

  final String title;
  final String? subtitle;

  /// 'camera' | 'gallery' | 'generated'.
  final String source;

  final DateTime createdAt;

  bool favorite;
  bool pinned;

  /// Soft-delete tombstone. Non-null → in "Recently Deleted", purged after TTL.
  DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  QrType get type => typeIndex >= 0 && typeIndex < QrType.values.length
      ? QrType.values[typeIndex]
      : QrType.text;

  /// Rebuild the parsed payload (re-parsed from [raw]) so history rows can run
  /// the same smart actions as a live scan without persisting the full model.
  ParsedQr toParsed() => ParsedQr(
        type: type,
        raw: raw,
        title: title,
        subtitle: subtitle,
      );

  ScanHistoryEntry copyWith({
    bool? favorite,
    bool? pinned,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) =>
      ScanHistoryEntry(
        id: id,
        raw: raw,
        typeIndex: typeIndex,
        title: title,
        subtitle: subtitle,
        source: source,
        createdAt: createdAt,
        favorite: favorite ?? this.favorite,
        pinned: pinned ?? this.pinned,
        deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      );
}

/// Hand-written Hive adapter — schema-versioned for forward/backward compat.
///
/// Layout: `[int fieldCount, ...fields in fixed order]`. Reading tolerates a
/// record written by an OLDER build (fewer fields → defaults fill the rest) and
/// by a NEWER build (extra trailing fields are skipped). Never remove or
/// reorder existing fields; only append.
class ScanHistoryEntryAdapter extends TypeAdapter<ScanHistoryEntry> {
  @override
  final int typeId = 42;

  /// Current number of serialized fields. Bump when appending a field.
  static const int _fieldCount = 10;

  @override
  ScanHistoryEntry read(BinaryReader reader) {
    final count = reader.readByte();
    // Each logical field is exactly one physical value, in fixed order, so a
    // record written by an older build (smaller [count]) fills the remaining
    // fields with defaults, and a newer build's extra fields are ignored here.
    final id = count > 0 ? reader.readString() : '';
    final raw = count > 1 ? reader.readString() : '';
    final typeIndex = count > 2 ? reader.readInt() : QrType.text.index;
    final title = count > 3 ? reader.readString() : '';
    final subtitle = count > 4 ? reader.readString() : '';
    final source = count > 5 ? reader.readString() : 'camera';
    final createdAtMs = count > 6 ? reader.readInt() : 0;
    final favorite = count > 7 ? reader.readBool() : false;
    final pinned = count > 8 ? reader.readBool() : false;
    final deletedAtMs = count > 9 ? reader.readInt() : 0;
    // Fields a newer build appended (count > _fieldCount) are left unread; Hive
    // discards the unconsumed remainder of the frame automatically.

    return ScanHistoryEntry(
      id: id,
      raw: raw,
      typeIndex: typeIndex,
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      source: source,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      favorite: favorite,
      pinned: pinned,
      deletedAt:
          deletedAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(deletedAtMs) : null,
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistoryEntry obj) {
    writer.writeByte(_fieldCount);
    writer.writeString(obj.id);
    writer.writeString(obj.raw);
    writer.writeInt(obj.typeIndex);
    writer.writeString(obj.title);
    writer.writeString(obj.subtitle ?? '');
    writer.writeString(obj.source);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.favorite);
    writer.writeBool(obj.pinned);
    writer.writeInt(obj.deletedAt?.millisecondsSinceEpoch ?? 0);
  }
}
