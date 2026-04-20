import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inspection_plan.dart';
import '../models/inspection_step.dart';
import '../models/ollama_analysis_result.dart';
import '../services/api_inspection_service.dart';
import 'ollama_output_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'http://10.0.2.2:3000',
  );

  XFile? _blueprintImage;
  OllamaAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  String? _error;

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: 4096,
    );

    if (photo == null) {
      return;
    }

    setState(() {
      _blueprintImage = photo;
      _analysisResult = null;
      _error = null;
    });
  }

  Future<void> _analyzeBlueprint() async {
    if (_blueprintImage == null) {
      setState(() {
        _error = 'Capture ou selecione primeiro a imagem do desenho técnico.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final service = ApiInspectionService(baseUrl: _baseUrlController.text);
      final analysis = await service.analyzeBlueprint(
        File(_blueprintImage!.path),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _analysisResult = analysis;
        _isAnalyzing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnalyzing = false;
        _analysisResult = null;
        _error = error.toString();
      });
    }
  }

  void _startInspection() {
    final analysis = _analysisResult;
    if (analysis == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OllamaOutputScreen(
          plan: analysis.plan,
          rawOutput: _prettyRawResponse(analysis.rawResponse),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _analysisResult?.plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Inspeção Técnica com IA + ArUco')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildStepOneCard(),
              const SizedBox(height: 16),
              _buildServerCard(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeBlueprint,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_alt),
                label: Text(
                  _isAnalyzing
                      ? 'Analisando desenho...'
                      : 'Gerar roteiro de validação',
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (plan != null) ...<Widget>[
                const SizedBox(height: 20),
                _buildPlanPreview(plan),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _startInspection,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar validação por etapas'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepOneCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Etapa obrigatória 1: imagem do desenho técnico',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'O app só libera a validação da peça depois que a IA entender o desenho técnico.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _blueprintImage == null
                        ? 'Capturar imagem'
                        : 'Refazer foto',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    _blueprintImage == null
                        ? 'Selecionar da galeria'
                        : 'Trocar imagem',
                  ),
                ),
              ],
            ),
            if (_blueprintImage != null) ...<Widget>[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_blueprintImage!.path),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Configuração do Servidor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL do backend',
                hintText: 'http://192.168.0.10:3000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanPreview(InspectionPlan plan) {
    final quality = plan.analysisQuality;
    final coverage = plan.effectiveCoverage;
    final technicalReference = plan.technicalReference;
    final missingRequired =
        coverage?.missingRequiredClasses ?? const <String>[];

    final qualityColor = quality == null
        ? const Color(0xFF455A64)
        : quality.isHigh
        ? const Color(0xFF1B7F3B)
        : quality.isLow
        ? const Color(0xFFB3261E)
        : const Color(0xFF8A6D1A);

    final sortedViews = <String>[];
    final captureViews =
        plan.capturePlan?.viewsSummary ?? const <String, int>{};
    for (final entry in captureViews.entries) {
      if (entry.value > 0) {
        sortedViews.add('${entry.key}(${entry.value})');
      }
    }

    final photoViews = <String>[];
    final capturePhotoViews =
        plan.capturePlan?.photoViewsSummary ?? const <String, int>{};
    for (final entry in capturePhotoViews.entries) {
      if (entry.value > 0) {
        photoViews.add('${entry.key}(${entry.value})');
      }
    }

    final hiddenRisk = plan.capturePlan?.hiddenFeatureRisk;
    final inferred = _asMap(technicalReference?['inferred']);
    final closestThickness = _asMap(inferred?['closest_standard_thickness']);

    return Card(
      color: const Color(0xFFF4F9F7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Roteiro gerado para: ${plan.partName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (plan.inspectionId != null)
              Text('Inspection ID: ${plan.inspectionId}'),
            if (plan.generatedAt != null)
              Text('Gerado em: ${plan.generatedAt}'),
            Text('Unidade: ${plan.unit}'),
            Text(
              'Geometria: chapa plana=${plan.geometryCheck.isFlatPlate ? 'sim' : 'nao'}, '
              'dobras=${plan.geometryCheck.hasPhysicalBendsOrFolds ? 'sim' : 'nao'}, '
              'furos=${plan.geometryCheck.hasCircularHoles ? 'sim' : 'nao'}',
            ),
            if (quality != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Qualidade: ${quality.status.toUpperCase()} '
                '(${(quality.confidence * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: qualityColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (sortedViews.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Vistas de captura: ${sortedViews.join(', ')}'),
            ],
            if (photoViews.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('Pacote de fotos sugerido: ${photoViews.join(', ')}'),
            ],
            if (hiddenRisk != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Risco de feature oculta: ${_toBool(hiddenRisk['has_hidden_features']) ? 'sim' : 'nao'}',
              ),
            ],
            if (closestThickness != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Espessura prox. de referencia: ${closestThickness['closest_standard_mm']} mm (delta ${closestThickness['delta_mm']} mm)',
              ),
            ],
            if (missingRequired.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Classes obrigatorias faltantes: '
                '${missingRequired.map(_formatCoverageClass).join(', ')}',
                style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (plan.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Observações da IA: ${plan.notes}'),
            ],
            const SizedBox(height: 12),
            Text('Etapas de validação: ${plan.steps.length}'),
            const SizedBox(height: 6),
            for (var index = 0; index < plan.steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${index + 1}. ${plan.steps[index].title} (${plan.steps[index].analysisType.channelValue})',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCoverageClass(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'base':
        return 'BASE';
      case 'height':
        return 'ALTURA';
      case 'thickness':
        return 'ESPESSURA';
      case 'hole':
        return 'FURO';
      case 'chamfer':
        return 'CHANFRO';
      case 'bend':
        return 'DOBRA';
      case 'u_cutout':
        return 'RECORTE_U';
      default:
        return raw.toUpperCase();
    }
  }

  String _prettyRawResponse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return raw;
    }

    try {
      final decoded = jsonDecode(trimmed);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return value.toString().trim().toLowerCase() == 'true';
  }
}
