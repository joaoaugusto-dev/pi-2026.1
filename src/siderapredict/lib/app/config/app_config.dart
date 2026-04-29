import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static const String _firestoreProjectIdKey = 'FIRESTORE_PROJECT_ID';
  static const String _firestoreApiKeyKey = 'FIRESTORE_API_KEY';
  static const String _firestoreCollectionKey = 'FIRESTORE_COLLECTION';
  static const String _ollamaBaseUrlKey = 'OLLAMA_BASE_URL';
  static const String _ollamaModelKey = 'OLLAMA_MODEL';

  static String get firestoreProjectId => _read(_firestoreProjectIdKey);
  static String get firestoreApiKey => _read(_firestoreApiKeyKey);
  static String get firestoreCollection => _read(_firestoreCollectionKey);
  static String get ollamaBaseUrl {
    final raw = _normalizeBaseUrl(_read(_ollamaBaseUrlKey));
    return _isPublicHttpsUrl(raw) ? raw : '';
  }

  static String get ollamaModel => _read(_ollamaModelKey);

  static bool get isFirestoreConfigured =>
      firestoreProjectId.isNotEmpty &&
      firestoreApiKey.isNotEmpty &&
      firestoreCollection.isNotEmpty;

  static bool get isOllamaConfigured =>
      ollamaBaseUrl.isNotEmpty && ollamaModel.isNotEmpty;

  static List<String> get validationMessages {
    final messages = <String>[];

    if (!isFirestoreConfigured) {
      messages.add(
        'Preencha `FIRESTORE_PROJECT_ID`, `FIRESTORE_API_KEY` e `FIRESTORE_COLLECTION` no `.env`.',
      );
    }

    final rawOllamaBaseUrl = _normalizeBaseUrl(_read(_ollamaBaseUrlKey));
    if (rawOllamaBaseUrl.isEmpty) {
      messages.add(
        'Preencha `OLLAMA_BASE_URL` no `.env` com uma URL pública HTTPS.',
      );
    } else if (!_isPublicHttpsUrl(rawOllamaBaseUrl)) {
      messages.add(
        '`OLLAMA_BASE_URL` precisa ser uma URL pública HTTPS, sem `localhost` nem IP interno.',
      );
    }

    if (ollamaModel.isEmpty) {
      messages.add('Preencha `OLLAMA_MODEL` no `.env`.');
    }

    return List<String>.unmodifiable(messages);
  }

  static String _read(String key) => (dotenv.env[key] ?? '').trim();

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static bool _isPublicHttpsUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return false;
    }

    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    return !_isPrivateHost(uri.host);
  }

  static bool _isPrivateHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.lan')) {
      return true;
    }

    final ipv4Match = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    ).firstMatch(normalized);
    if (ipv4Match != null) {
      final octets = <int>[
        for (int i = 1; i <= 4; i++) int.tryParse(ipv4Match.group(i)!) ?? -1,
      ];
      if (octets.any((value) => value < 0 || value > 255)) {
        return true;
      }

      if (octets[0] == 10 ||
          octets[0] == 127 ||
          (octets[0] == 169 && octets[1] == 254) ||
          (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
          (octets[0] == 192 && octets[1] == 168)) {
        return true;
      }
    }

    return !normalized.contains('.');
  }
}
