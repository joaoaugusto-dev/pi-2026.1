import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class LocalHistoryStore {
  LocalHistoryStore({String? Function()? sessionKeyProvider})
    : _sessionKeyProvider = sessionKeyProvider ?? _defaultSessionKeyProvider;

  final String? Function() _sessionKeyProvider;

  Future<File> _historyFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final sessionKey = _sanitizedSessionKey(_sessionKeyProvider());
    return File('${directory.path}/measurement_history_$sessionKey.json');
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
    return record;
  }

  static String? _defaultSessionKeyProvider() {
    try {
      return supabase.Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String _sanitizedSessionKey(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'signed_out';
    }
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}
