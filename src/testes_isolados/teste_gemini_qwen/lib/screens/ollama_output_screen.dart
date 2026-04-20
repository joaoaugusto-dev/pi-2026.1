import 'package:flutter/material.dart';

import '../models/inspection_plan.dart';
import '../models/inspection_step.dart';
import 'inspection_flow_screen.dart';

class OllamaOutputScreen extends StatelessWidget {
  const OllamaOutputScreen({
    super.key,
    required this.plan,
    required this.rawOutput,
  });

  final InspectionPlan plan;
  final String rawOutput;

  @override
  Widget build(BuildContext context) {
    final quality = plan.analysisQuality;
    final coverage = plan.effectiveCoverage;
    final diagnostics = plan.analysisDiagnostics;
    final capturePlan = plan.capturePlan;
    final technicalReference = plan.technicalReference;
    final inferredReference = _asMap(technicalReference?['inferred']);

    final qualityColor = quality == null
        ? const Color(0xFF546E7A)
        : quality.isHigh
        ? const Color(0xFF1B7F3B)
        : quality.isLow
        ? const Color(0xFFB3261E)
        : const Color(0xFF8A6D1A);

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado do Ollama')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Roteiro gerado para: ${plan.partName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Unidade: ${plan.unit}'),
                      if (plan.inspectionId != null)
                        Text('Inspection ID: ${plan.inspectionId}'),
                      if (plan.generatedAt != null)
                        Text('Gerado em: ${plan.generatedAt}'),
                      const SizedBox(height: 8),
                      Text(
                        'Geometria: chapa plana=${plan.geometryCheck.isFlatPlate ? 'sim' : 'nao'}, '
                        'dobras=${plan.geometryCheck.hasPhysicalBendsOrFolds ? 'sim' : 'nao'}, '
                        'furos=${plan.geometryCheck.hasCircularHoles ? 'sim' : 'nao'}',
                      ),
                      if (quality != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Qualidade: ${quality.status.toUpperCase()} '
                          '(${(quality.confidence * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            color: qualityColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Concordancia ensemble: '
                          '${(quality.ensembleAgreement * 100).toStringAsFixed(1)}%',
                        ),
                        Text('Issues detectadas: ${quality.issues.length}'),
                      ],
                      if (diagnostics != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Diagnostico: ensemble=${diagnostics.ensembleSize}, '
                          'steps selecionados=${diagnostics.selectedSteps}, '
                          'ratio=${(diagnostics.agreementRatio * 100).toStringAsFixed(1)}%',
                        ),
                      ],
                      if (plan.notes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text('Observações da IA: ${plan.notes}'),
                      ],
                      const SizedBox(height: 8),
                      Text('Etapas de validação: ${plan.steps.length}'),
                    ],
                  ),
                ),
              ),
              if (coverage != null) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFF8FAFF),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Cobertura de classes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cobertas: ${coverage.coveredFocusClasses.map(_labelForClass).join(', ')}',
                        ),
                        if (coverage.missingRequiredClasses.isNotEmpty)
                          Text(
                            'Obrigatorias faltantes: '
                            '${coverage.missingRequiredClasses.map(_labelForClass).join(', ')}',
                            style: const TextStyle(
                              color: Color(0xFFB3261E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (coverage.missingFocusClasses.isNotEmpty)
                          Text(
                            'Foco faltante: '
                            '${coverage.missingFocusClasses.map(_labelForClass).join(', ')}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (technicalReference != null) ...<Widget>[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFF5F8FF),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Referencia tecnica aplicada',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fonte: ${technicalReference['source_document'] ?? '-'}',
                        ),
                        Text(
                          'Revisao: ${technicalReference['revision'] ?? '-'}',
                        ),
                        Text(
                          'Normas: ${_stringList(technicalReference['standards']).join(', ')}',
                        ),
                        if (inferredReference != null)
                          Text(
                            'Classes detectadas: ${_stringList(inferredReference['detected_classes']).map(_labelForClass).join(', ')}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (capturePlan != null &&
                  capturePlan.requiredPhotos.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                const Text(
                  'Plano de captura sugerido',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final photo in capturePlan.requiredPhotos)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: const Color(0xFFF6FAF8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${photo.photoId} - vista ${photo.view}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('Minimo de fotos: ${photo.minimumShots}'),
                          if (photo.intent.isNotEmpty) Text(photo.intent),
                          if (photo.relatedSteps.isNotEmpty)
                            Text('Etapas: ${photo.relatedSteps.join(', ')}'),
                          if (photo.relatedClasses.isNotEmpty)
                            Text(
                              'Classes: ${photo.relatedClasses.map(_labelForClass).join(', ')}',
                            ),
                          if (photo.cameraPose.isNotEmpty)
                            Text('Pose sugerida: ${photo.cameraPose}'),
                          Text(
                            'Risco de oclusao: ${photo.occlusionRisk.toUpperCase()}',
                          ),
                          if (photo.mustIncludeReverseSide)
                            const Text(
                              'Requisito: incluir foto do lado oposto.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          if (photo.framingChecklist.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            const Text('Checklist de enquadramento:'),
                            for (final item in photo.framingChecklist)
                              Text('- $item'),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Etapas e alvos extraídos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < plan.steps.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: const Color(0xFFF7FAF8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${index + 1}. ${plan.steps[index].title}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cota nominal: ${plan.steps[index].expectedValue.toStringAsFixed(3)} ${plan.steps[index].unit} | Tolerancia: ±${plan.steps[index].tolerance.toStringAsFixed(3)} ${plan.steps[index].unit}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Modo: ${plan.steps[index].measurementMode.channelValue}',
                        ),
                        Text(
                          'Classe: ${_labelForClass(plan.steps[index].stepClass)}',
                        ),
                        Text(
                          'Eixo: ${plan.steps[index].axisPreference.channelValue}',
                        ),
                        Text(
                          'Pose sugerida: ${plan.steps[index].recommendedCapturePose}',
                        ),
                        Text(
                          'Risco de oclusao: ${plan.steps[index].occlusionRisk.toUpperCase()}',
                        ),
                        Text('Alvo: ${plan.steps[index].targetHint}'),
                        if (plan.steps[index].sourceCallout.isNotEmpty)
                          Text(
                            'Cota lida no desenho: ${plan.steps[index].sourceCallout}',
                          ),
                        if (plan
                            .steps[index]
                            .verificationFocus
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          for (final item
                              in plan.steps[index].verificationFocus)
                            Text('- $item'),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Saída bruta do Ollama',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4D7DD)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    rawOutput.trim().isEmpty
                        ? 'Sem texto bruto retornado.'
                        : rawOutput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => InspectionFlowScreen(plan: plan),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Iniciar Inspeção'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelForClass(String raw) {
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

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
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
}
