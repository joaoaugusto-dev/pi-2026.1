import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class LocalHistoryStore {
  Future<File> _historyFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/measurement_history.json');
  }

  Future<List<MeasurementRecord>> loadAll() async {
    final file = await _historyFile();
    if (!await file.exists()) {
      return const <MeasurementRecord>[];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return const <MeasurementRecord>[];
    }

    try {
      final decoded = MeasurementRecord.decodeList(raw);
      final sanitized = decoded.map(_sanitizeRecord).toList(growable: false);
      final hadSensitivePaths = decoded.any((record) {
        return record.draft.sourceImagePath.isNotEmpty ||
            record.draft.processedImagePath.isNotEmpty;
      });
      if (hadSensitivePaths) {
        await saveAll(sanitized);
      }
      return sanitized;
    } catch (_) {
      return const <MeasurementRecord>[];
    }
  }

  Future<void> saveAll(List<MeasurementRecord> records) async {
    final file = await _historyFile();
    await file.writeAsString(
      MeasurementRecord.encodeList(
        records.map(_sanitizeRecord).toList(growable: false),
      ),
      flush: true,
    );
  }

  Future<void> append(MeasurementRecord record) async {
    await upsert(record);
  }

  Future<void> upsert(MeasurementRecord record) async {
    final current = await loadAll();
    final updated = <MeasurementRecord>[
      record,
      for (final existing in current)
        if (existing.id != record.id) existing,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await saveAll(updated);
  }

  Future<void> deleteById(String recordId) async {
    final current = await loadAll();
    final updated = current
        .where((record) => record.id != recordId)
        .toList(growable: false);
    await saveAll(updated);
  }

  MeasurementRecord _sanitizeRecord(MeasurementRecord record) {
    final draft = record.draft.copyWith(
      sourceImagePath: '',
      processedImagePath: '',
    );
    return record.copyWith(draft: draft);
  }
}
