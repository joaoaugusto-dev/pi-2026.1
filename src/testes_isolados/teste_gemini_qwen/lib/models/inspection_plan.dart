import 'dart:convert';

import 'inspection_step.dart';

class GeometryCheck {
  const GeometryCheck({
    required this.isFlatPlate,
    required this.hasPhysicalBendsOrFolds,
    required this.hasCircularHoles,
  });

  static const GeometryCheck empty = GeometryCheck(
    isFlatPlate: true,
    hasPhysicalBendsOrFolds: false,
    hasCircularHoles: false,
  );

  final bool isFlatPlate;
  final bool hasPhysicalBendsOrFolds;
  final bool hasCircularHoles;

  factory GeometryCheck.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      return GeometryCheck.empty;
    }

    return GeometryCheck(
      isFlatPlate: _toBoolValue(json['is_flat_plate'], fallback: true),
      hasPhysicalBendsOrFolds: _toBoolValue(
        json['has_physical_bends_or_folds'],
        fallback: false,
      ),
      hasCircularHoles: _toBoolValue(
        json['has_circular_holes'],
        fallback: false,
      ),
    );
  }
}

class CapturePlanPhoto {
  const CapturePlanPhoto({
    required this.photoId,
    required this.view,
    required this.minimumShots,
    required this.intent,
    required this.relatedSteps,
    required this.relatedClasses,
    required this.cameraPose,
    required this.hiddenFeatureFocus,
    required this.occlusionRisk,
    required this.mustIncludeReverseSide,
    required this.framingChecklist,
  });

  final String photoId;
  final String view;
  final int minimumShots;
  final String intent;
  final List<String> relatedSteps;
  final List<String> relatedClasses;
  final String cameraPose;
  final bool hiddenFeatureFocus;
  final String occlusionRisk;
  final bool mustIncludeReverseSide;
  final List<String> framingChecklist;

  factory CapturePlanPhoto.fromJson(dynamic raw, {required int fallbackIndex}) {
    final json = _asStringMap(raw);
    if (json == null) {
      return CapturePlanPhoto(
        photoId: 'PHOTO_${fallbackIndex + 1}',
        view: 'top',
        minimumShots: 1,
        intent: '',
        relatedSteps: const <String>[],
        relatedClasses: const <String>[],
        cameraPose: '',
        hiddenFeatureFocus: false,
        occlusionRisk: 'low',
        mustIncludeReverseSide: false,
        framingChecklist: const <String>[],
      );
    }

    return CapturePlanPhoto(
      photoId: _toStringValue(
        json['photo_id'],
        fallback: 'PHOTO_${fallbackIndex + 1}',
      ),
      view: _toStringValue(json['view'], fallback: 'top'),
      minimumShots: _toIntValue(json['minimum_shots'], fallback: 1),
      intent: _toStringValue(json['intent'], fallback: ''),
      relatedSteps: _toStringList(json['related_steps']),
      relatedClasses: _toStringList(json['related_classes']),
      cameraPose: _toStringValue(json['camera_pose'], fallback: ''),
      hiddenFeatureFocus: _toBoolValue(
        json['hidden_feature_focus'],
        fallback: false,
      ),
      occlusionRisk: _toStringValue(json['occlusion_risk'], fallback: 'low'),
      mustIncludeReverseSide: _toBoolValue(
        json['must_include_reverse_side'],
        fallback: false,
      ),
      framingChecklist: _toStringList(json['framing_checklist']),
    );
  }
}

class CapturePlan {
  const CapturePlan({
    required this.strategy,
    required this.requiresMultiView,
    required this.viewsSummary,
    required this.photoViewsSummary,
    required this.hiddenFeatureRisk,
    required this.requiredPhotos,
  });

  final String strategy;
  final bool requiresMultiView;
  final Map<String, int> viewsSummary;
  final Map<String, int> photoViewsSummary;
  final Map<String, dynamic>? hiddenFeatureRisk;
  final List<CapturePlanPhoto> requiredPhotos;

  factory CapturePlan.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      throw const FormatException('capture_plan invalido');
    }

    final rawPhotos = json['required_photos'];
    final photos = <CapturePlanPhoto>[];
    if (rawPhotos is List) {
      for (var i = 0; i < rawPhotos.length; i++) {
        photos.add(CapturePlanPhoto.fromJson(rawPhotos[i], fallbackIndex: i));
      }
    }

    return CapturePlan(
      strategy: _toStringValue(json['strategy'], fallback: ''),
      requiresMultiView: _toBoolValue(
        json['requires_multi_view'],
        fallback: false,
      ),
      viewsSummary: _toStringIntMap(json['views_summary']),
      photoViewsSummary: _toStringIntMap(json['photo_views_summary']),
      hiddenFeatureRisk: _toDynamicMap(json['hidden_feature_risk']),
      requiredPhotos: photos,
    );
  }
}

class AnalysisIssue {
  const AnalysisIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.stepId,
    required this.className,
  });

  final String code;
  final String severity;
  final String message;
  final String stepId;
  final String className;

  factory AnalysisIssue.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      return const AnalysisIssue(
        code: '',
        severity: '',
        message: '',
        stepId: '',
        className: '',
      );
    }

    return AnalysisIssue(
      code: _toStringValue(json['code'], fallback: ''),
      severity: _toStringValue(json['severity'], fallback: ''),
      message: _toStringValue(json['message'], fallback: ''),
      stepId: _toStringValue(json['step_id'], fallback: ''),
      className: _toStringValue(json['class_name'], fallback: ''),
    );
  }
}

class AnalysisCoverage {
  const AnalysisCoverage({
    required this.byClass,
    required this.requiredClasses,
    required this.missingRequiredClasses,
    required this.focusClasses,
    required this.missingFocusClasses,
    required this.coveredFocusClasses,
  });

  final Map<String, int> byClass;
  final List<String> requiredClasses;
  final List<String> missingRequiredClasses;
  final List<String> focusClasses;
  final List<String> missingFocusClasses;
  final List<String> coveredFocusClasses;

  bool get hasRequiredGaps => missingRequiredClasses.isNotEmpty;

  factory AnalysisCoverage.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      throw const FormatException('analysis_coverage invalido');
    }

    return AnalysisCoverage(
      byClass: _toStringIntMap(json['by_class']),
      requiredClasses: _toStringList(json['required_classes']),
      missingRequiredClasses: _toStringList(json['missing_required_classes']),
      focusClasses: _toStringList(json['focus_classes']),
      missingFocusClasses: _toStringList(json['missing_focus_classes']),
      coveredFocusClasses: _toStringList(json['covered_focus_classes']),
    );
  }
}

class AnalysisQuality {
  const AnalysisQuality({
    required this.confidence,
    required this.ensembleAgreement,
    required this.status,
    required this.issues,
    required this.coverage,
  });

  final double confidence;
  final double ensembleAgreement;
  final String status;
  final List<AnalysisIssue> issues;
  final AnalysisCoverage? coverage;

  bool get isLow => status.toLowerCase() == 'low';
  bool get isHigh => status.toLowerCase() == 'high';

  factory AnalysisQuality.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      throw const FormatException('analysis_quality invalido');
    }

    final rawIssues = json['issues'];
    final parsedIssues = <AnalysisIssue>[];
    if (rawIssues is List) {
      for (final item in rawIssues) {
        parsedIssues.add(AnalysisIssue.fromJson(item));
      }
    }

    AnalysisCoverage? parsedCoverage;
    final rawCoverage = json['coverage'];
    if (rawCoverage != null) {
      try {
        parsedCoverage = AnalysisCoverage.fromJson(rawCoverage);
      } catch (_) {
        parsedCoverage = null;
      }
    }

    return AnalysisQuality(
      confidence: _toDoubleValue(json['confidence'], fallback: 0),
      ensembleAgreement: _toDoubleValue(
        json['ensemble_agreement'],
        fallback: 0,
      ),
      status: _toStringValue(json['status'], fallback: 'unknown'),
      issues: parsedIssues,
      coverage: parsedCoverage,
    );
  }
}

class AnalysisDiagnostics {
  const AnalysisDiagnostics({
    required this.ensembleSize,
    required this.selectedSteps,
    required this.totalCandidateSteps,
    required this.agreementRatio,
  });

  final int ensembleSize;
  final int selectedSteps;
  final int totalCandidateSteps;
  final double agreementRatio;

  factory AnalysisDiagnostics.fromJson(dynamic raw) {
    final json = _asStringMap(raw);
    if (json == null) {
      throw const FormatException('analysis_diagnostics invalido');
    }

    return AnalysisDiagnostics(
      ensembleSize: _toIntValue(json['ensemble_size'], fallback: 0),
      selectedSteps: _toIntValue(json['selected_steps'], fallback: 0),
      totalCandidateSteps: _toIntValue(
        json['total_candidate_steps'],
        fallback: 0,
      ),
      agreementRatio: _toDoubleValue(json['agreement_ratio'], fallback: 0),
    );
  }
}

class InspectionPlan {
  const InspectionPlan({
    required this.partName,
    required this.unit,
    required this.notes,
    required this.steps,
    this.inspectionId,
    this.generatedAt,
    this.geometryCheck = GeometryCheck.empty,
    this.capturePlan,
    this.analysisQuality,
    this.analysisDiagnostics,
    this.analysisCoverage,
    this.technicalReference,
    this.inspectionProfile,
  });

  final String partName;
  final String unit;
  final String notes;
  final List<InspectionStep> steps;
  final String? inspectionId;
  final String? generatedAt;
  final GeometryCheck geometryCheck;
  final CapturePlan? capturePlan;
  final AnalysisQuality? analysisQuality;
  final AnalysisDiagnostics? analysisDiagnostics;
  final AnalysisCoverage? analysisCoverage;
  final Map<String, dynamic>? technicalReference;
  final Map<String, dynamic>? inspectionProfile;

  AnalysisCoverage? get effectiveCoverage =>
      analysisCoverage ?? analysisQuality?.coverage;

  bool get hasCoverageGaps => effectiveCoverage?.hasRequiredGaps ?? false;

  factory InspectionPlan.fromJson(Map<String, dynamic> json) {
    final rawSteps =
        json['steps'] ?? json['inspection_steps'] ?? json['etapas'];
    final parsedSteps = <InspectionStep>[];

    if (rawSteps is List) {
      for (var index = 0; index < rawSteps.length; index++) {
        final item = rawSteps[index];
        if (item is Map) {
          final stepJson = _asStringMap(item);
          if (stepJson == null) {
            continue;
          }
          parsedSteps.add(
            InspectionStep.fromJson(stepJson, fallbackIndex: index),
          );
        }
      }
    }

    AnalysisQuality? parsedQuality;
    final rawQuality = json['analysis_quality'];
    if (rawQuality != null) {
      try {
        parsedQuality = AnalysisQuality.fromJson(rawQuality);
      } catch (_) {
        parsedQuality = null;
      }
    }

    AnalysisCoverage? parsedCoverage;
    final rawCoverage = json['analysis_coverage'];
    if (rawCoverage != null) {
      try {
        parsedCoverage = AnalysisCoverage.fromJson(rawCoverage);
      } catch (_) {
        parsedCoverage = null;
      }
    }

    CapturePlan? parsedCapturePlan;
    final rawCapturePlan = json['capture_plan'];
    if (rawCapturePlan != null) {
      try {
        parsedCapturePlan = CapturePlan.fromJson(rawCapturePlan);
      } catch (_) {
        parsedCapturePlan = null;
      }
    }

    AnalysisDiagnostics? parsedDiagnostics;
    final rawDiagnostics = json['analysis_diagnostics'];
    if (rawDiagnostics != null) {
      try {
        parsedDiagnostics = AnalysisDiagnostics.fromJson(rawDiagnostics);
      } catch (_) {
        parsedDiagnostics = null;
      }
    }

    return InspectionPlan(
      inspectionId: _toNullableString(json['inspection_id']),
      generatedAt: _toNullableString(json['generated_at']),
      partName: _toString(
        json['part_name'] ?? json['nome_peca'],
        fallback: 'Peca sem nome',
      ),
      unit: _toString(json['unit'] ?? json['unidade'], fallback: 'mm'),
      notes: _toString(json['notes'] ?? json['observacoes'], fallback: ''),
      steps: parsedSteps,
      geometryCheck: GeometryCheck.fromJson(json['geometry_check']),
      capturePlan: parsedCapturePlan,
      analysisQuality: parsedQuality,
      analysisDiagnostics: parsedDiagnostics,
      analysisCoverage: parsedCoverage ?? parsedQuality?.coverage,
      technicalReference: _toDynamicMap(json['technical_reference']),
      inspectionProfile: _toDynamicMap(json['inspection_profile']),
    );
  }

  factory InspectionPlan.fromOllamaRawResponse(String rawResponse) {
    final payload = _extractFirstJsonPayload(rawResponse);
    final decoded = jsonDecode(payload);

    if (decoded is List) {
      final wrapped = <String, dynamic>{
        'part_name': 'Peca identificada',
        'unit': 'mm',
        'notes': '',
        'steps': decoded,
      };
      final plan = InspectionPlan.fromJson(wrapped);
      if (plan.steps.isEmpty) {
        throw const FormatException('A resposta nao trouxe etapas validas.');
      }
      return plan;
    }

    if (decoded is Map) {
      final rawMap = _asStringMap(decoded);
      if (rawMap == null) {
        throw const FormatException('Resposta JSON em formato invalido.');
      }
      final plan = InspectionPlan.fromJson(rawMap);
      if (plan.steps.isEmpty) {
        throw const FormatException(
          'A resposta JSON nao contem etapas de inspecao.',
        );
      }
      return plan;
    }

    throw const FormatException('Formato de resposta JSON nao suportado.');
  }

  static String _toString(dynamic value, {required String fallback}) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _extractFirstJsonPayload(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Resposta da IA vazia.');
    }

    final candidates = _extractBalancedJsonCandidates(cleaned);
    for (final candidate in candidates) {
      try {
        jsonDecode(candidate);
        return candidate;
      } catch (_) {
        // Try next candidate.
      }
    }

    throw const FormatException(
      'Nao foi possivel extrair JSON valido da resposta da IA.',
    );
  }

  static List<String> _extractBalancedJsonCandidates(String text) {
    final candidates = <String>[];

    var inString = false;
    var escaping = false;
    final stack = <String>[];
    var candidateStart = -1;

    for (var index = 0; index < text.length; index++) {
      final char = text[index];

      if (inString) {
        if (escaping) {
          escaping = false;
          continue;
        }
        if (char == r'\') {
          escaping = true;
          continue;
        }
        if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }

      if (char == '{' || char == '[') {
        if (stack.isEmpty) {
          candidateStart = index;
        }
        stack.add(char);
        continue;
      }

      if (char == '}' || char == ']') {
        if (stack.isEmpty) {
          continue;
        }

        final opener = stack.removeLast();
        final isValidPair =
            (opener == '{' && char == '}') || (opener == '[' && char == ']');
        if (!isValidPair) {
          stack.clear();
          candidateStart = -1;
          continue;
        }

        if (stack.isEmpty && candidateStart >= 0) {
          candidates.add(text.substring(candidateStart, index + 1));
          candidateStart = -1;
        }
      }
    }

    return candidates;
  }
}

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

Map<String, dynamic>? _toDynamicMap(dynamic value) {
  return _asStringMap(value);
}

String _toStringValue(dynamic value, {required String fallback}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _toNullableString(dynamic value) {
  final text = _toStringValue(value, fallback: '');
  return text.isEmpty ? null : text;
}

double _toDoubleValue(dynamic value, {required double fallback}) {
  if (value == null) {
    return fallback;
  }
  if (value is num) {
    return value.toDouble();
  }
  final parsed = value.toString().replaceAll(',', '.').trim();
  return double.tryParse(parsed) ?? fallback;
}

int _toIntValue(dynamic value, {required int fallback}) {
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString()) ?? fallback;
}

bool _toBoolValue(dynamic value, {required bool fallback}) {
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }

  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

Map<String, int> _toStringIntMap(dynamic value) {
  final json = _asStringMap(value);
  if (json == null) {
    return const <String, int>{};
  }

  final result = <String, int>{};
  for (final entry in json.entries) {
    result[entry.key] = _toIntValue(entry.value, fallback: 0);
  }
  return result;
}
