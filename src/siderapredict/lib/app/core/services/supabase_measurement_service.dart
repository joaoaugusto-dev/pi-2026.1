import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

const Set<String> _draftFieldsRemovedFromRemotePayload = <String>{
  'sourceImagePath',
  'processedImagePath',
  'calibrationSuccess',
  'objectFound',
  'scaleMicronsPerPx',
  'markerSizeMm',
  'source',
};

Map<String, dynamic> buildRemoteMeasurementPayload(MeasurementRecord record) {
  final payload = Map<String, dynamic>.from(record.toJson())
    ..remove('id')
    ..remove('createdAt')
    ..remove('primaryValueMm')
    ..remove('ownerUserId');

  final rawDraft = payload['draft'];
  if (rawDraft is Map<String, dynamic>) {
    rawDraft.removeWhere(
      (key, value) =>
          _draftFieldsRemovedFromRemotePayload.contains(key) || value == null,
    );
  } else if (rawDraft is Map) {
    final draft = Map<String, dynamic>.from(rawDraft)
      ..removeWhere(
        (key, value) =>
            _draftFieldsRemovedFromRemotePayload.contains(key) || value == null,
      );
    payload['draft'] = draft;
  }

  payload.removeWhere((_, value) => value == null);
  return payload;
}

class SupabaseMeasurementService {
  SupabaseMeasurementService({
    supabase.SupabaseClient? client,
    required this.tableName,
  }) : _client = client;

  final supabase.SupabaseClient? _client;
  final String tableName;

  supabase.SupabaseClient? get _maybeClient {
    final client = _client;
    if (client != null) return client;

    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  supabase.SupabaseClient get _supabase {
    final client = _maybeClient;
    if (client == null) {
      throw StateError('Supabase não foi inicializado.');
    }
    return client;
  }

  Future<void> saveRecord(MeasurementRecord record) async {
    final client = _supabase;
    final currentUserId = client.auth.currentUser?.id;
    final expectedOwnerUserId = record.ownerUserId?.trim();
    if (expectedOwnerUserId != null &&
        expectedOwnerUserId.isNotEmpty &&
        currentUserId != expectedOwnerUserId) {
      throw StateError('Sessão alterada antes do salvamento da medição.');
    }
    await client.from(tableName).upsert(_toRow(record, client));
  }

  Future<List<MeasurementRecord>> fetchRecords() async {
    final client = _maybeClient;
    if (client == null || tableName.trim().isEmpty) {
      return const <MeasurementRecord>[];
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const <MeasurementRecord>[];
    }

    final List<dynamic> rows = await client
        .from(tableName)
        .select('id, user_id, payload, created_at')
        .order('created_at', ascending: false);

    return _recordsFromRows(rows);
  }

  Future<void> deleteRecord(String recordId) async {
    await _supabase.from(tableName).delete().eq('id', recordId);
  }

  Stream<List<MeasurementRecord>> streamRecords() {
    final client = _maybeClient;
    if (client == null || tableName.trim().isEmpty) {
      return Stream.value(const <MeasurementRecord>[]);
    }

    late final StreamController<List<MeasurementRecord>> controller;
    StreamSubscription<supabase.AuthState>? authSubscription;
    StreamSubscription<List<MeasurementRecord>>? recordsSubscription;

    Future<void> listenForAuthentication(String? userId) async {
      await recordsSubscription?.cancel();
      recordsSubscription = null;

      if (userId == null) {
        controller.add(const <MeasurementRecord>[]);
        return;
      }

      recordsSubscription = _streamRecords(
        client: client,
      ).listen(controller.add, onError: controller.addError);
    }

    controller = StreamController<List<MeasurementRecord>>(
      onListen: () {
        unawaited(listenForAuthentication(client.auth.currentUser?.id));
        authSubscription = client.auth.onAuthStateChange.listen((state) {
          unawaited(listenForAuthentication(state.session?.user.id));
        }, onError: controller.addError);
      },
      onCancel: () async {
        await recordsSubscription?.cancel();
        await authSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<MeasurementRecord>> _streamRecords({
    required supabase.SupabaseClient client,
  }) {
    return client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(_recordsFromRows);
  }

  Map<String, dynamic> _toRow(
    MeasurementRecord record,
    supabase.SupabaseClient client,
  ) {
    final userId = client.auth.currentUser?.id;
    final row = <String, dynamic>{
      'id': record.id,
      'created_at': record.createdAt.toUtc().toIso8601String(),
      'payload': _toRemotePayload(record),
    };
    if (userId != null) {
      row['user_id'] = userId;
    }
    return row;
  }

  List<MeasurementRecord> _recordsFromRows(List<dynamic> rows) {
    final records = <MeasurementRecord>[];

    for (final row in rows) {
      try {
        if (row is Map<String, dynamic>) {
          records.add(_recordFromRow(row));
        } else if (row is Map) {
          records.add(_recordFromRow(Map<String, dynamic>.from(row)));
        }
      } catch (e) {
        debugPrint('Registro Supabase ignorado por formato inválido: $e');
      }
    }

    return records;
  }

  MeasurementRecord _recordFromRow(Map<String, dynamic> row) {
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) {
      return MeasurementRecord.fromJson(_withRowIdentity(payload, row));
    }
    if (payload is Map) {
      return MeasurementRecord.fromJson(
        _withRowIdentity(Map<String, dynamic>.from(payload), row),
      );
    }

    return MeasurementRecord.fromJson(row);
  }

  Map<String, dynamic> _toRemotePayload(MeasurementRecord record) {
    return buildRemoteMeasurementPayload(record);
  }

  Map<String, dynamic> _withRowIdentity(
    Map<String, dynamic> payload,
    Map<String, dynamic> row,
  ) {
    return <String, dynamic>{
      ...payload,
      'id': row['id'] ?? payload['id'],
      'ownerUserId': row['user_id'] ?? payload['ownerUserId'],
      'createdAt': row['created_at'] ?? payload['createdAt'],
    };
  }
}
