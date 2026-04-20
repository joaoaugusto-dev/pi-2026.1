import 'package:flutter_test/flutter_test.dart';
import 'package:teste_gemini_qwen/models/inspection_plan.dart';

void main() {
  group('InspectionPlan.fromOllamaRawResponse', () {
    test('extrai JSON valido mesmo com texto extra ao redor', () {
      const raw = '''
Aqui esta sua analise:

```json
{
  "part_name": "Suporte A",
  "unit": "mm",
  "notes": "Plano principal",
  "steps": [
    {
      "id": "STEP_1",
      "title": "Largura externa",
      "instruction": "Posicione em vista superior com 4 ArUco.",
      "required_view": "top",
      "analysis_type": "aruco_2d",
      "measurement_mode": "outer_span",
      "axis_preference": "horizontal",
      "target_hint": "largura externa",
      "source_callout": "25",
      "expected_value": 25,
      "tolerance": 0.2,
      "unit": "mm",
      "requires_all_markers": true,
      "capture_checklist": [
        "4 ArUco visiveis",
        "peca paralela ao plano",
        "contorno nitido"
      ]
    }
  ]
}
```
''';

      final plan = InspectionPlan.fromOllamaRawResponse(raw);

      expect(plan.partName, 'Suporte A');
      expect(plan.steps, hasLength(1));
      expect(plan.steps.first.sourceCallout, '25');
    });

    test('ignora candidato quebrado e usa primeiro JSON valido', () {
      const raw = '''
{ "part_name": "invalido", "steps": [ }

Texto intermediario

{
  "part_name": "Flange B",
  "unit": "mm",
  "notes": "",
  "steps": [
    {
      "id": "STEP_1",
      "title": "Diametro do furo central",
      "instruction": "Vista superior com foco no furo.",
      "required_view": "top",
      "analysis_type": "aruco_2d",
      "measurement_mode": "hole_diameter",
      "axis_preference": "auto",
      "target_hint": "furo central",
      "source_callout": "Ø12.5",
      "expected_value": 12.5,
      "tolerance": 0.2,
      "unit": "mm",
      "requires_all_markers": true,
      "capture_checklist": [
        "4 ArUco visiveis",
        "furo totalmente visivel",
        "sem reflexo"
      ]
    }
  ]
}
''';

      final plan = InspectionPlan.fromOllamaRawResponse(raw);

      expect(plan.partName, 'Flange B');
      expect(plan.steps, hasLength(1));
      expect(plan.steps.first.expectedValue, closeTo(12.5, 0.0001));
    });

    test('parseia metadados do backend de interpretacao v1', () {
      const raw = '''
{
  "inspection_id": "insp_123",
  "generated_at": "2026-04-17T23:59:59.000Z",
  "part_name": "Suporte Dobrado",
  "unit": "mm",
  "notes": "Plano consolidado por consenso.",
  "geometry_check": {
    "is_flat_plate": true,
    "has_physical_bends_or_folds": true,
    "has_circular_holes": true
  },
  "steps": [
    {
      "id": "STEP_1",
      "title": "Base",
      "instruction": "Medir base em vista superior",
      "required_view": "top",
      "analysis_type": "aruco_2d",
      "measurement_mode": "outer_span",
      "axis_preference": "horizontal",
      "target_hint": "base externa",
      "source_callout": "55",
      "expected_value": 55,
      "tolerance": 0.5,
      "unit": "mm",
      "requires_all_markers": true,
      "capture_checklist": ["4 ArUco visiveis"]
    }
  ],
  "capture_plan": {
    "strategy": "multi_view_guided_capture",
    "requires_multi_view": true,
    "views_summary": {"top": 1, "profile": 1},
    "required_photos": [
      {
        "photo_id": "PHOTO_1",
        "view": "top",
        "minimum_shots": 1,
        "intent": "Validar cotas da vista principal",
        "related_steps": ["STEP_1"]
      }
    ]
  },
  "analysis_quality": {
    "confidence": 0.93,
    "ensemble_agreement": 0.88,
    "status": "high",
    "issues": [],
    "coverage": {
      "by_class": {"base": 1, "height": 1, "thickness": 1},
      "required_classes": ["base", "height", "thickness"],
      "missing_required_classes": [],
      "focus_classes": ["base", "height", "thickness", "hole"],
      "missing_focus_classes": ["hole"],
      "covered_focus_classes": ["base", "height", "thickness"]
    }
  },
  "analysis_diagnostics": {
    "ensemble_size": 4,
    "selected_steps": 6,
    "total_candidate_steps": 12,
    "agreement_ratio": 0.75
  },
  "analysis_coverage": {
    "by_class": {"base": 1, "height": 1, "thickness": 1},
    "required_classes": ["base", "height", "thickness"],
    "missing_required_classes": [],
    "focus_classes": ["base", "height", "thickness", "hole"],
    "missing_focus_classes": ["hole"],
    "covered_focus_classes": ["base", "height", "thickness"]
  }
}
''';

      final plan = InspectionPlan.fromOllamaRawResponse(raw);

      expect(plan.inspectionId, 'insp_123');
      expect(plan.geometryCheck.hasPhysicalBendsOrFolds, isTrue);
      expect(plan.capturePlan, isNotNull);
      expect(plan.capturePlan!.requiredPhotos, hasLength(1));
      expect(plan.analysisQuality, isNotNull);
      expect(plan.analysisQuality!.status, 'high');
      expect(plan.analysisDiagnostics, isNotNull);
      expect(plan.analysisDiagnostics!.ensembleSize, 4);
      expect(plan.effectiveCoverage, isNotNull);
      expect(plan.hasCoverageGaps, isFalse);
    });
  });
}
