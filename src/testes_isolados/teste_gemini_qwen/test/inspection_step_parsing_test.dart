import 'package:flutter_test/flutter_test.dart';
import 'package:teste_gemini_qwen/models/inspection_step.dart';

void main() {
  group('InspectionStep.fromJson', () {
    test('normaliza cota Nx45° como chanfro linear em mm', () {
      final step = InspectionStep.fromJson(<String, dynamic>{
        'id': 'STEP_1',
        'title': 'Medida do Angulo de 45°',
        'instruction': 'Alinhar para medir angulo.',
        'required_view': 'profile',
        'analysis_type': 'angle_profile',
        'expected_value': 45,
        'tolerance': 1.0,
        'unit': 'deg',
        'target_hint': 'angulo de 45 graus',
        'source_callout': '10x45°',
        'requires_all_markers': false,
      }, fallbackIndex: 0);

      expect(step.analysisType, AnalysisType.aruco2d);
      expect(step.expectedValue, closeTo(10.0, 0.0001));
      expect(step.unit, 'mm');
      expect(step.tolerance, closeTo(0.2, 0.0001));
      expect(step.targetHint.toLowerCase(), contains('chanfro'));
      expect(step.requiresAllMarkers, isTrue);
    });

    test('mantem angulo real quando nao e notacao de chanfro', () {
      final step = InspectionStep.fromJson(<String, dynamic>{
        'id': 'STEP_2',
        'title': 'Medida do Angulo',
        'instruction': 'Capturar perfil para medir o angulo.',
        'required_view': 'profile',
        'analysis_type': 'angle_profile',
        'expected_value': 45,
        'tolerance': 1.0,
        'unit': 'deg',
        'target_hint': 'angulo de dobra',
        'source_callout': '45°',
      }, fallbackIndex: 1);

      expect(step.analysisType, AnalysisType.angleProfile);
      expect(step.expectedValue, closeTo(45.0, 0.0001));
      expect(step.unit, 'deg');
      expect(step.tolerance, closeTo(1.0, 0.0001));
    });

    test('prioriza valor decimal literal da cota para expected_value', () {
      final step = InspectionStep.fromJson(<String, dynamic>{
        'id': 'STEP_3',
        'title': 'Medir espessura da chapa',
        'instruction': 'Medir espessura na vista de perfil.',
        'required_view': 'profile',
        'analysis_type': 'aruco_2d',
        'expected_value': 63,
        'tolerance': 0.5,
        'unit': 'mm',
        'target_hint': 'espessura da chapa',
        'source_callout': '6.3',
        'requires_all_markers': true,
      }, fallbackIndex: 2);

      expect(step.expectedValue, closeTo(6.3, 0.0001));
      expect(step.unit, 'mm');
    });

    test('corrige expected_value quando diverge da cota literal simples', () {
      final step = InspectionStep.fromJson(<String, dynamic>{
        'id': 'STEP_4',
        'title': 'Medir base inferior',
        'instruction': 'Medir distancia horizontal na base.',
        'required_view': 'front',
        'analysis_type': 'aruco_2d',
        'expected_value': 65,
        'tolerance': 0.5,
        'unit': 'mm',
        'target_hint': 'base inferior',
        'source_callout': '55',
        'requires_all_markers': true,
      }, fallbackIndex: 3);

      expect(step.expectedValue, closeTo(55.0, 0.0001));
    });
  });
}
