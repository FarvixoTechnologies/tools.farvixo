// Exercises the hand-written Hive adapter's binary round-trip and its
// forward/backward schema-compatibility guarantees. Uses Hive's binary
// impls directly (the standard way to unit-test a TypeAdapter).
// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/models/scan_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';

void main() {
  final registry = TypeRegistryImpl();
  final adapter = ScanHistoryEntryAdapter();

  ScanHistoryEntry roundTrip(ScanHistoryEntry e) {
    final writer = BinaryWriterImpl(registry);
    adapter.write(writer, e);
    final reader = BinaryReaderImpl(writer.toBytes(), registry);
    return adapter.read(reader);
  }

  group('adapter round-trip (current schema)', () {
    test('full entry with subtitle + flags + deletedAt', () {
      final e = ScanHistoryEntry(
        id: 'id-1',
        raw: 'https://farvixo.com',
        typeIndex: QrType.url.index,
        title: 'farvixo.com',
        subtitle: '/tools',
        source: 'gallery',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1737000000000),
        favorite: true,
        pinned: true,
        deletedAt: DateTime.fromMillisecondsSinceEpoch(1737100000000),
      );
      final out = roundTrip(e);
      expect(out.id, e.id);
      expect(out.raw, e.raw);
      expect(out.type, QrType.url);
      expect(out.title, e.title);
      expect(out.subtitle, '/tools');
      expect(out.source, 'gallery');
      expect(out.createdAt, e.createdAt);
      expect(out.favorite, isTrue);
      expect(out.pinned, isTrue);
      expect(out.deletedAt, e.deletedAt);
    });

    test('null subtitle + null deletedAt survive', () {
      final e = ScanHistoryEntry(
        id: 'id-2',
        raw: 'hello',
        typeIndex: QrType.text.index,
        title: 'hello',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1737000000000),
      );
      final out = roundTrip(e);
      expect(out.subtitle, isNull);
      expect(out.deletedAt, isNull);
      expect(out.favorite, isFalse);
    });

    test('out-of-range typeIndex degrades to text', () {
      final e = ScanHistoryEntry(
        id: 'id-3',
        raw: 'x',
        typeIndex: 999,
        title: 'x',
        createdAt: DateTime.now(),
      );
      expect(roundTrip(e).type, QrType.text);
    });
  });

  group('backward compatibility (reading an OLDER record)', () {
    test('record written with only the first 7 fields fills defaults', () {
      // Simulate a v1 record: id, raw, typeIndex, title, subtitle, source,
      // createdAt — no favorite/pinned/deletedAt yet.
      final writer = BinaryWriterImpl(registry);
      writer.writeByte(7);
      writer.writeString('legacy-id');
      writer.writeString('legacy raw');
      writer.writeInt(QrType.wifi.index);
      writer.writeString('Legacy Wi-Fi');
      writer.writeString(''); // subtitle
      writer.writeString('camera');
      writer.writeInt(1737000000000);

      final out =
          adapter.read(BinaryReaderImpl(writer.toBytes(), registry));
      expect(out.id, 'legacy-id');
      expect(out.type, QrType.wifi);
      expect(out.favorite, isFalse);
      expect(out.pinned, isFalse);
      expect(out.deletedAt, isNull);
    });
  });

  group('forward compatibility (reading a NEWER record)', () {
    test('extra appended fields are ignored, known fields intact', () {
      final writer = BinaryWriterImpl(registry);
      writer.writeByte(12); // two more fields than this build knows
      writer.writeString('future-id');
      writer.writeString('future raw');
      writer.writeInt(QrType.email.index);
      writer.writeString('Future Email');
      writer.writeString('subj');
      writer.writeString('gallery');
      writer.writeInt(1737000000000);
      writer.writeBool(true); // favorite
      writer.writeBool(false); // pinned
      writer.writeInt(0); // deletedAt
      writer.writeString('future-field-1'); // unknown
      writer.writeBool(true); // unknown

      final out =
          adapter.read(BinaryReaderImpl(writer.toBytes(), registry));
      expect(out.id, 'future-id');
      expect(out.type, QrType.email);
      expect(out.subtitle, 'subj');
      expect(out.favorite, isTrue);
      expect(out.pinned, isFalse);
    });
  });

  test('typeId is stable at 42', () {
    expect(adapter.typeId, 42);
  });

  test('toBytes produces non-empty buffer', () {
    final writer = BinaryWriterImpl(registry);
    adapter.write(
      writer,
      ScanHistoryEntry(
        id: 'x',
        raw: 'x',
        typeIndex: 0,
        title: 'x',
        createdAt: DateTime.now(),
      ),
    );
    expect(writer.toBytes(), isA<Uint8List>());
    expect(writer.toBytes().isNotEmpty, isTrue);
  });
}
