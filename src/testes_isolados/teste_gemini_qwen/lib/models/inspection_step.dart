enum AnalysisType { aruco2d, angleProfile }

extension AnalysisTypeMapping on AnalysisType {
  String get channelValue {
    switch (this) {
      case AnalysisType.angleProfile:
        return 'angle_profile';
      case AnalysisType.aruco2d:
        return 'aruco_2d';
    }
  }

  static AnalysisType fromRaw(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized == 'angle_profile' ||
        normalized == 'angle' ||
        normalized == 'bend_angle') {
      return AnalysisType.angleProfile;
    }
    return AnalysisType.aruco2d;
  }
}

enum MeasurementMode {
  auto,
  outerSpan,
  holeDiameter,
  centerDistance,
  edgeToHoleCenter,
  slotWidth,
}

extension MeasurementModeMapping on MeasurementMode {
  String get channelValue {
    switch (this) {
      case MeasurementMode.outerSpan:
        return 'outer_span';
      case MeasurementMode.holeDiameter:
        return 'hole_diameter';
      case MeasurementMode.centerDistance:
        return 'center_distance';
      case MeasurementMode.edgeToHoleCenter:
        return 'edge_to_hole_center';
      case MeasurementMode.slotWidth:
        return 'slot_width';
      case MeasurementMode.auto:
        return 'auto';
    }
  }

  static MeasurementMode fromRaw(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    switch (normalized) {
      case 'outer_span':
      case 'overall_length':
      case 'overall_width':
      case 'width':
      case 'height':
        return MeasurementMode.outerSpan;
      case 'hole_diameter':
      case 'diameter':
      case 'furo_diametro':
        return MeasurementMode.holeDiameter;
      case 'center_distance':
      case 'hole_center_distance':
      case 'distance_between_centers':
        return MeasurementMode.centerDistance;
      case 'edge_to_hole_center':
      case 'edge_hole_center':
        return MeasurementMode.edgeToHoleCenter;
      case 'slot_width':
      case 'channel_width':
        return MeasurementMode.slotWidth;
      default:
        return MeasurementMode.auto;
    }
  }
}

enum AxisPreference { auto, horizontal, vertical }

extension AxisPreferenceMapping on AxisPreference {
  String get channelValue {
    switch (this) {
      case AxisPreference.horizontal:
        return 'horizontal';
      case AxisPreference.vertical:
        return 'vertical';
      case AxisPreference.auto:
        return 'auto';
    }
  }

  static AxisPreference fromRaw(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized == 'x' || normalized == 'horizontal') {
      return AxisPreference.horizontal;
    }
    if (normalized == 'y' || normalized == 'vertical') {
      return AxisPreference.vertical;
    }
    return AxisPreference.auto;
  }
}

class InspectionStep {
  const InspectionStep({
    required this.id,
    required this.title,
    required this.instruction,
    required this.requiredView,
    required this.analysisType,
    required this.expectedValue,
    required this.tolerance,
    required this.unit,
    required this.requiresAllMarkers,
    required this.captureChecklist,
    required this.measurementMode,
    required this.axisPreference,
    required this.targetHint,
    required this.sourceCallout,
    required this.stepClass,
    required this.hiddenFeatureCandidate,
    required this.occlusionRisk,
    required this.recommendedCapturePose,
    required this.verificationFocus,
  });

  final String id;
  final String title;
  final String instruction;
  final String requiredView;
  final AnalysisType analysisType;
  final double expectedValue;
  final double tolerance;
  final String unit;
  final bool requiresAllMarkers;
  final List<String> captureChecklist;
  final MeasurementMode measurementMode;
  final AxisPreference axisPreference;
  final String targetHint;
  final String sourceCallout;
  final String stepClass;
  final bool hiddenFeatureCandidate;
  final String occlusionRisk;
  final String recommendedCapturePose;
  final List<String> verificationFocus;

  factory InspectionStep.fromJson(
    Map<String, dynamic> json, {
    required int fallbackIndex,
  }) {
    final rawTitle = _toString(
      json['title'] ?? json['titulo'],
      fallback: 'Etapa ${fallbackIndex + 1}',
    );
    final rawInstruction = _toString(
      json['instruction'] ?? json['instrucao'],
      fallback: 'Capture a imagem solicitada para validacao.',
    );
    final rawTargetHint = _toString(
      json['target_hint'] ?? json['target_feature'] ?? json['alvo'],
      fallback: rawTitle,
    );
    final rawSourceCallout = _toString(
      json['source_callout'] ?? json['cota_original'] ?? json['callout'],
      fallback: '',
    );
    final rawAnalysisType = _toString(
      json['analysis_type'] ?? json['tipo_analise'],
      fallback: 'aruco_2d',
    );
    final rawUnit = _toString(json['unit'] ?? json['unidade'], fallback: 'mm');
    final expectedValueFromJson = _toDouble(
      json['expected_value'] ?? json['medida_esperada_mm'],
    );
    final toleranceFromJson = _toDouble(
      json['tolerance'] ?? json['tolerancia_mm'],
      fallback: 0.5,
    );

    final chamferLegMm =
        _extractChamferLegMm(rawSourceCallout) ??
        _extractChamferLegMm(rawTargetHint) ??
        _extractChamferLegMm(rawTitle) ??
        _extractChamferLegMm(rawInstruction);

    final isChamfer = _isChamferStep(
      sourceCallout: rawSourceCallout,
      targetHint: rawTargetHint,
      title: rawTitle,
      instruction: rawInstruction,
      chamferLegMm: chamferLegMm,
    );

    final analysisType = isChamfer
        ? AnalysisType.aruco2d
        : AnalysisTypeMapping.fromRaw(rawAnalysisType);

    final sourceCalloutValue = _extractLiteralValueFromCallout(
      rawSourceCallout,
    );

    var expectedValue = (isChamfer && chamferLegMm != null)
        ? chamferLegMm
        : expectedValueFromJson;

    if (!isChamfer) {
      expectedValue = _resolveExpectedValue(
        expectedValueFromJson: expectedValueFromJson,
        sourceCallout: rawSourceCallout,
        sourceCalloutValue: sourceCalloutValue,
      );
    }

    final tolerance = _normalizeTolerance(
      isChamfer: isChamfer,
      currentTolerance: toleranceFromJson,
      currentUnit: rawUnit,
      rawAnalysisType: rawAnalysisType,
      expectedValue: expectedValue,
    );

    final unit = isChamfer ? 'mm' : rawUnit;

    final requiresAllMarkers = _toBool(
      json['requires_all_markers'] ?? json['requer_todos_marcadores'],
      fallback: true,
    );

    final normalizedTargetHint = isChamfer
        ? _normalizeChamferTargetHint(
            rawTargetHint: rawTargetHint,
            sourceCallout: rawSourceCallout,
          )
        : rawTargetHint;

    final normalizedTitle = isChamfer
        ? _normalizeChamferTitle(
            rawTitle: rawTitle,
            sourceCallout: rawSourceCallout,
          )
        : rawTitle;

    final normalizedInstruction = isChamfer
        ? _normalizeChamferInstruction(
            rawInstruction: rawInstruction,
            sourceCallout: rawSourceCallout,
          )
        : rawInstruction;

    final measurementMode = MeasurementModeMapping.fromRaw(
      _toString(
        json['measurement_mode'] ??
            json['measurementMode'] ??
            json['tipo_medicao'],
        fallback: isChamfer
            ? 'auto'
            : analysisType == AnalysisType.angleProfile
            ? 'auto'
            : 'outer_span',
      ),
    );

    final parsedRequiredView = _toString(
      json['required_view'] ?? json['vista_requerida'],
      fallback: 'top',
    );

    final stepClass = _toString(
      json['step_class'] ?? json['classe_etapa'],
      fallback: _inferStepClass(
        title: normalizedTitle,
        instruction: normalizedInstruction,
        targetHint: normalizedTargetHint,
        sourceCallout: rawSourceCallout,
      ),
    );

    final hiddenFeatureCandidate = _toBool(
      json['hidden_feature_candidate'],
      fallback: _inferHiddenFeatureCandidate(
        stepClass: stepClass,
        requiredView: parsedRequiredView,
      ),
    );

    final recommendedCapturePose = _toString(
      json['recommended_capture_pose'],
      fallback: _defaultCapturePose(
        requiredView: parsedRequiredView,
        stepClass: stepClass,
      ),
    );

    final occlusionRisk = _toString(
      json['occlusion_risk'],
      fallback: hiddenFeatureCandidate ? 'medium' : 'low',
    );

    final verificationFocus = _toStringList(json['verification_focus']);

    return InspectionStep(
      id: _toString(json['id'], fallback: 'STEP_${fallbackIndex + 1}'),
      title: normalizedTitle,
      instruction: normalizedInstruction,
      requiredView: parsedRequiredView,
      analysisType: analysisType,
      expectedValue: expectedValue,
      tolerance: tolerance,
      unit: unit,
      requiresAllMarkers: analysisType == AnalysisType.aruco2d
          ? true
          : requiresAllMarkers,
      captureChecklist: _toStringList(
        json['capture_checklist'] ?? json['checklist'],
      ),
      measurementMode: measurementMode,
      axisPreference: AxisPreferenceMapping.fromRaw(
        _toString(
          json['axis_preference'] ?? json['axis'] ?? json['eixo'],
          fallback: 'auto',
        ),
      ),
      targetHint: normalizedTargetHint,
      sourceCallout: rawSourceCallout,
      stepClass: stepClass,
      hiddenFeatureCandidate: hiddenFeatureCandidate,
      occlusionRisk: occlusionRisk,
      recommendedCapturePose: recommendedCapturePose,
      verificationFocus: verificationFocus.isEmpty
          ? _defaultVerificationFocus(stepClass)
          : verificationFocus,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'instruction': instruction,
      'required_view': requiredView,
      'analysis_type': analysisType.channelValue,
      'expected_value': expectedValue,
      'tolerance': tolerance,
      'unit': unit,
      'requires_all_markers': requiresAllMarkers,
      'capture_checklist': captureChecklist,
      'measurement_mode': measurementMode.channelValue,
      'axis_preference': axisPreference.channelValue,
      'target_hint': targetHint,
      'source_callout': sourceCallout,
      'step_class': stepClass,
      'hidden_feature_candidate': hiddenFeatureCandidate,
      'occlusion_risk': occlusionRisk,
      'recommended_capture_pose': recommendedCapturePose,
      'verification_focus': verificationFocus,
    };
  }

  static bool _isChamferStep({
    required String sourceCallout,
    required String targetHint,
    required String title,
    required String instruction,
    required double? chamferLegMm,
  }) {
    if (chamferLegMm != null) {
      return true;
    }

    final combined = '$sourceCallout $targetHint $title $instruction'
        .toLowerCase();
    return combined.contains('chanfro') || combined.contains('chamfer');
  }

  static double? _extractChamferLegMm(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(?:°|deg|grau|graus)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static double? _extractLiteralValueFromCallout(String sourceCallout) {
    final text = sourceCallout.trim();
    if (text.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static double _resolveExpectedValue({
    required double expectedValueFromJson,
    required String sourceCallout,
    required double? sourceCalloutValue,
  }) {
    if (sourceCalloutValue == null || sourceCalloutValue <= 0) {
      return expectedValueFromJson;
    }

    final strictLiteralCallout = RegExp(
      r'^\s*(?:[ø⌀r]\s*)?\d+(?:[.,]\d+)?\s*(?:°|deg|grau|graus)?\s*$',
      caseSensitive: false,
    ).hasMatch(sourceCallout);

    if (strictLiteralCallout) {
      return sourceCalloutValue;
    }

    if (RegExp(r'\d+[.,]\d+').hasMatch(sourceCallout)) {
      return sourceCalloutValue;
    }

    if (expectedValueFromJson <= 0) {
      return sourceCalloutValue;
    }

    final ratio = expectedValueFromJson / sourceCalloutValue;
    if (ratio >= 3 || ratio <= 0.33) {
      return sourceCalloutValue;
    }

    return expectedValueFromJson;
  }

  static double _normalizeTolerance({
    required bool isChamfer,
    required double currentTolerance,
    required String currentUnit,
    required String rawAnalysisType,
    required double expectedValue,
  }) {
    if (!isChamfer) {
      return currentTolerance;
    }

    final fallback = _defaultLinearTolerance(expectedValue);
    final normalizedUnit = currentUnit.trim().toLowerCase();
    final normalizedAnalysis = rawAnalysisType.trim().toLowerCase();

    final looksAngular =
        normalizedUnit.contains('deg') ||
        normalizedUnit.contains('grau') ||
        normalizedAnalysis == 'angle_profile' ||
        normalizedAnalysis == 'angle' ||
        normalizedAnalysis == 'bend_angle';

    if (looksAngular || currentTolerance >= 1.0) {
      return fallback;
    }

    if (currentTolerance <= 0) {
      return fallback;
    }

    return currentTolerance;
  }

  static double _defaultLinearTolerance(double expectedValue) {
    if (expectedValue > 0 && expectedValue <= 20) {
      return 0.20;
    }
    return 0.50;
  }

  static String _normalizeChamferTitle({
    required String rawTitle,
    required String sourceCallout,
  }) {
    final normalized = rawTitle.toLowerCase();
    if (normalized.contains('chanfro') || normalized.contains('chamfer')) {
      return rawTitle;
    }

    if (sourceCallout.isNotEmpty) {
      return 'Medida de chanfro ($sourceCallout)';
    }
    return 'Medida de chanfro';
  }

  static String _normalizeChamferTargetHint({
    required String rawTargetHint,
    required String sourceCallout,
  }) {
    final normalized = rawTargetHint.toLowerCase();
    if (normalized.contains('chanfro') || normalized.contains('chamfer')) {
      return rawTargetHint;
    }

    if (sourceCallout.isNotEmpty) {
      return 'chanfro $sourceCallout';
    }
    return 'chanfro da aresta';
  }

  static String _normalizeChamferInstruction({
    required String rawInstruction,
    required String sourceCallout,
  }) {
    final normalized = rawInstruction.toLowerCase();
    if (normalized.contains('chanfro') || normalized.contains('chamfer')) {
      return rawInstruction;
    }

    if (sourceCallout.isNotEmpty) {
      return 'Posicione a peca para medir o chanfro $sourceCallout em vista plana com os 4 ArUco completos.';
    }

    return 'Posicione a peca para medir o chanfro em vista plana com os 4 ArUco completos.';
  }

  static String _inferStepClass({
    required String title,
    required String instruction,
    required String targetHint,
    required String sourceCallout,
  }) {
    final combined = '$title $instruction $targetHint $sourceCallout'
        .toLowerCase();

    if (RegExp(r'(furo|diam|ø|⌀|hole)').hasMatch(combined)) {
      return 'hole';
    }
    if (RegExp(
      r'(chanfro|chamfer|\d+\s*[x×]\s*\d+\s*(?:deg|°))',
    ).hasMatch(combined)) {
      return 'chamfer';
    }
    if (RegExp(
      r'(dobra|fold|bend|linha de dobra|para cima|para baixo)',
    ).hasMatch(combined)) {
      return 'bend';
    }
    if (RegExp(r'(espessura|thickness)').hasMatch(combined)) {
      return 'thickness';
    }
    if (RegExp(r'(recorte|rasgo|slot|tipo\s*u)').hasMatch(combined)) {
      return 'u_cutout';
    }
    if (RegExp(r'(altura|height)').hasMatch(combined)) {
      return 'height';
    }
    if (RegExp(r'(base|comprimento|length)').hasMatch(combined)) {
      return 'base';
    }
    return 'other';
  }

  static bool _inferHiddenFeatureCandidate({
    required String stepClass,
    required String requiredView,
  }) {
    final normalizedClass = stepClass.trim().toLowerCase();
    final normalizedView = requiredView.trim().toLowerCase();

    return normalizedClass == 'hole' ||
        normalizedClass == 'bend' ||
        normalizedClass == 'u_cutout' ||
        normalizedView == 'profile' ||
        normalizedView == 'detail';
  }

  static String _defaultCapturePose({
    required String requiredView,
    required String stepClass,
  }) {
    final normalizedView = requiredView.trim().toLowerCase();
    final normalizedClass = stepClass.trim().toLowerCase();

    if (normalizedView == 'profile') {
      return 'camera_perpendicular_to_profile';
    }
    if (normalizedView == 'detail') {
      return 'closeup_with_aruco_reference';
    }
    if (normalizedClass == 'hole') {
      return 'top_view_centered_on_hole_axis';
    }
    return 'camera_perpendicular_to_surface';
  }

  static List<String> _defaultVerificationFocus(String stepClass) {
    final normalized = stepClass.trim().toLowerCase();
    if (normalized == 'bend') {
      return const <String>[
        'capturar linha de dobra completa sem perspectiva inclinada',
      ];
    }
    if (normalized == 'hole') {
      return const <String>[
        'centralizar o furo e manter bordas no enquadramento',
      ];
    }
    if (normalized == 'chamfer') {
      return const <String>['evidenciar aresta chanfrada com boa iluminacao'];
    }
    return const <String>['evitar oclusao parcial do alvo'];
  }

  static String _toString(dynamic value, {required String fallback}) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is num) {
      return value.toDouble();
    }
    final parsed = value.toString().replaceAll(',', '.').trim();
    return double.tryParse(parsed) ?? fallback;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
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

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}
