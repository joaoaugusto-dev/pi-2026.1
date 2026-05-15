import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/core/services/measurement_service.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  group('MeasurementService - Testes de Unidade', () {
    test(
      'TC15 - Payload nativo válido vira draft medível com segmentos',
      () async {
        final bridge = FakeNativeVisionBridge({
          'width': 50.0,
          'height': 20.0,
          'calibrationSuccess': true,
          'objectFound': true,
          'outputPath': '/tmp/out.png',
          'edgesMm': [50.0, 20.0],
          'semiCircleRadiiMm': [4.2],
          'holeDiametersMm': [8.4],
          'holeSpacingMm': [12.0],
          'slotWidthsMm': [3.0],
          'slotLengthsMm': [9.0],
          'anglesDeg': [90.0],
          'perimeterMm': 140.0,
          'areaMm2': 1000.0,
          'scaleMicronsPerPx': 44.1,
          'markerSizeMm': 11.0,
          'markerCount': 4,
          'charucoCornerCount': 16,
          'pixelsPerMm': 22.3456,
        });
        final service = MeasurementService(bridge: bridge);

        final draft = await service.processImage('/tmp/input.png');

        expect(bridge.analyzedPaths, ['/tmp/input.png']);
        expect(draft.isValidMeasurement, isTrue);
        expect(draft.processedImagePath, '/tmp/out.png');
        expect(draft.widthMm, 50);
        expect(draft.heightMm, 20);
        expect(draft.perimeterMm, 140);
        expect(draft.areaMm2, 1000);
        expect(
          draft.segments.map((segment) => segment.type),
          contains(PieceSegmentType.diameter),
        );
        expect(
          draft.segments.map((segment) => segment.type),
          contains(PieceSegmentType.slot),
        );
        expect(
          draft.quickStatus,
          '4 marcadores | 16 cantos ChArUco | 22.346 px/mm',
        );
      },
    );

    test('TC16 - Payload sem calibração mantém erro e fica inválido', () async {
      final bridge = FakeNativeVisionBridge({
        'width': 0.0,
        'height': 0.0,
        'calibrationSuccess': false,
        'objectFound': false,
        'outputPath': '/tmp/input.png',
        'errorMessage': 'Board não detectado',
      });
      final service = MeasurementService(bridge: bridge);

      final draft = await service.processImage('/tmp/input.png');

      expect(draft.isValidMeasurement, isFalse);
      expect(draft.extraInfo, 'Board não detectado');
      expect(draft.segments, isEmpty);
      expect(draft.quickStatus, isNull);
    });
  });
}
