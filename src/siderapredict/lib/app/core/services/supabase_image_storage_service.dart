import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class StoredMeasurementImages {
  const StoredMeasurementImages({
    required this.photoStoragePath,
    required this.thumbnailStoragePath,
  });

  final String? photoStoragePath;
  final String? thumbnailStoragePath;
}

class SupabaseImageStorageService {
  SupabaseImageStorageService({
    supabase.SupabaseClient? client,
    required this.bucketName,
  }) : _client = client;

  final supabase.SupabaseClient? _client;
  final String bucketName;

  final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};

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

  Future<StoredMeasurementImages> uploadMeasurementImages({
    required String recordId,
    required Uint8List? photoBytes,
    required Uint8List? thumbnailBytes,
    String? ownerUserId,
  }) async {
    final client = _supabase;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado para enviar imagens.');
    }
    final expectedOwnerUserId = ownerUserId?.trim();
    if (expectedOwnerUserId != null &&
        expectedOwnerUserId.isNotEmpty &&
        expectedOwnerUserId != userId) {
      throw StateError('Sessão alterada antes do envio das imagens.');
    }

    final detailedBytes = photoBytes;
    final photoPath = detailedBytes == null
        ? null
        : '$userId/$recordId/photo.${_extensionFor(detailedBytes)}';
    final thumbnailPath = thumbnailBytes == null
        ? null
        : '$userId/$recordId/thumb.jpg';

    if (photoPath != null && detailedBytes != null) {
      await _upload(
        path: photoPath,
        bytes: detailedBytes,
        contentType: _contentTypeFor(detailedBytes),
      );
    }
    final thumbBytes = thumbnailBytes;
    if (thumbnailPath != null && thumbBytes != null) {
      await _upload(
        path: thumbnailPath,
        bytes: thumbBytes,
        contentType: 'image/jpeg',
      );
    }

    return StoredMeasurementImages(
      photoStoragePath: photoPath,
      thumbnailStoragePath: thumbnailPath,
    );
  }

  Future<Uint8List?> imageBytesFor(
    MeasurementRecord record, {
    bool preferDetailedImage = false,
  }) async {
    final storagePath = preferDetailedImage
        ? (record.photoStoragePath ?? record.thumbnailStoragePath)
        : (record.thumbnailStoragePath ?? record.photoStoragePath);

    if (storagePath != null && storagePath.isNotEmpty) {
      return downloadImage(storagePath);
    }

    return _localImageBytesFor(record);
  }

  Future<Uint8List?> downloadImage(String storagePath) async {
    final cached = _memoryCache[storagePath];
    if (cached != null) return cached;

    // Check disk cache
    final diskFile = await _diskCacheFile(storagePath);
    if (await diskFile.exists()) {
      try {
        final bytes = await diskFile.readAsBytes();
        _memoryCache[storagePath] = bytes;
        return bytes;
      } catch (e) {
        debugPrint('Erro ao ler imagem do cache em disco: $e');
      }
    }

    try {
      final bytes = await _supabase.storage.from(bucketName).download(storagePath);

      // Save to disk cache
      try {
        if (!await diskFile.parent.exists()) {
          await diskFile.parent.create(recursive: true);
        }
        await diskFile.writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint('Erro ao salvar imagem no cache em disco: $e');
      }

      _memoryCache[storagePath] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('Erro ao baixar imagem do Supabase Storage: $e');
      return null;
    }
  }

  Future<File> _diskCacheFile(String storagePath) async {
    final directory = await getApplicationSupportDirectory();
    final sanitizedPath = storagePath.replaceAll('/', '_').replaceAll('\\', '_');
    return File('${directory.path}/image_cache/$sanitizedPath');
  }

  Future<void> deleteImagesFor(MeasurementRecord record) async {
    // 1. Deletar caminhos do Storage (nuvem + cache local)
    final remotePaths = <String>{
      if (record.photoStoragePath != null) record.photoStoragePath!,
      if (record.thumbnailStoragePath != null) record.thumbnailStoragePath!,
    }.where((path) => path.trim().isNotEmpty).toList(growable: false);

    if (remotePaths.isNotEmpty) {
      try {
        await _supabase.storage.from(bucketName).remove(remotePaths);
        for (final path in remotePaths) {
          _memoryCache.remove(path);
          try {
            final diskFile = await _diskCacheFile(path);
            if (await diskFile.exists()) {
              await diskFile.delete();
            }
          } catch (e) {
            debugPrint('Erro ao remover imagem do cache em disco: $e');
          }
        }
      } catch (e) {
        debugPrint('Erro ao remover imagens do Supabase Storage: $e');
      }
    }

    // 2. Deletar arquivos locais originais (capturados no dispositivo)
    final localPaths = <String>[
      record.draft.sourceImagePath,
      record.draft.processedImagePath,
    ];

    for (final path in localPaths) {
      if (path.trim().isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Erro ao remover arquivo de imagem local: $e');
      }
    }
  }

  Future<void> _upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    _memoryCache[path] = bytes;
  }

  String _contentTypeFor(Uint8List bytes) {
    if (_isPng(bytes)) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  String _extensionFor(Uint8List bytes) => _isPng(bytes) ? 'png' : 'jpg';

  bool _isPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  Future<Uint8List?> _localImageBytesFor(MeasurementRecord record) async {
    final candidates = <String>[
      record.draft.processedImagePath,
      record.draft.sourceImagePath,
    ];

    for (final path in candidates) {
      if (path.trim().isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) {
          return file.readAsBytes();
        }
      } catch (_) {}
    }

    return null;
  }
}
