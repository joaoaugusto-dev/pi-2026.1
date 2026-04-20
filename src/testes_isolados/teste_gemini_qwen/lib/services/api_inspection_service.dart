import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/inspection_plan.dart';
import '../models/ollama_analysis_result.dart';

class ApiInspectionService {
  ApiInspectionService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<OllamaAnalysisResult> analyzeBlueprint(File imageFile) async {
    final endpoint = Uri.parse(
      '${_normalizeBaseUrl(baseUrl)}/api/v1/blueprints/interpret?strict=false',
    );

    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(
        await http.MultipartFile.fromPath('blueprint', imageFile.path),
      );

    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Falha no servidor: ${response.statusCode}\n${response.body}',
      );
    }

    final decodedJson = jsonDecode(response.body);
    if (decodedJson is! Map) {
      throw const FormatException('Resposta do backend em formato invalido.');
    }

    final plan = InspectionPlan.fromJson(
      Map<String, dynamic>.from(decodedJson as Map<Object?, Object?>),
    );

    return OllamaAnalysisResult(plan: plan, rawResponse: response.body);
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
