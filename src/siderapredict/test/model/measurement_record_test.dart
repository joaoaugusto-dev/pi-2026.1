import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

import '../helpers/sidera_test_fakes.dart';

void main() {
  group('MeasurementRecord - Testes de Modelo', () {
    test('TC12 - Segmentos formatam valores conforme tipo de medida', () {
      const radius = PieceSegmentMeasurement(
        type: PieceSegmentType.hole,
        label: 'Furo 1',
        valueMm: 3.125,
        isRadius: true,
      );
      const diameter = PieceSegmentMeasurement(
        type: PieceSegmentType.diameter,
        label: 'Furo 1',
        valueMm: 6.25,
        isDiameter: true,
      );
      const angle = PieceSegmentMeasurement(
        type: PieceSegmentType.angle,
        label: 'Ângulo 1',
        valueMm: 45,
        isAngle: true,
      );

      expect(radius.displayValue, 'R3.125 mm');
      expect(diameter.displayValue, 'D6.250 mm');
      expect(angle.displayValue, '45.0º');
      expect(PieceSegmentTypeLabel.fromStorage('slot'), PieceSegmentType.slot);
      expect(
        PieceSegmentTypeLabel.fromStorage('desconhecido'),
        PieceSegmentType.hole,
      );
    });

    test('TC13 - Draft preserva validade e campos no JSON', () {
      final draft = testMeasurementDraft(pieceNumberOfDay: 4);

      final decoded = MeasurementDraft.fromJson(draft.toJson());

      expect(decoded.isValidMeasurement, isTrue);
      expect(decoded.primaryValueMm, 42.5);
      expect(decoded.pieceNumberOfDay, 4);
      expect(decoded.segments, hasLength(2));
      expect(decoded.quickStatus, '4 marcadores | 12 cantos ChArUco');
    });

    test(
      'TC14 - Registro serializa lista e status de IA com retrocompatibilidade',
      () {
        final record = testMeasurementRecord(
          id: 'record-json',
          pieceName: 'Suporte A',
          aiReportStatus: AiReportStatus.generating,
          conformityStatus: ConformityStatus.nok,
          nonConformityReason: 'Furo deslocado',
          nonConformityObservation: 'Desvio visível',
          responsavel: 'João',
        );

        final encoded = MeasurementRecord.encodeList([record]);
        final decoded = MeasurementRecord.decodeList(encoded).single;

        expect(decoded.id, 'record-json');
        expect(decoded.pieceName, 'Suporte A');
        expect(decoded.aiReportStatus, AiReportStatus.generating);
        expect(decoded.conformityStatus, ConformityStatus.nok);
        expect(decoded.nonConformityReason, 'Furo deslocado');
        expect(decoded.responsavel, 'João');

        expect(
          AiReportStatusStorage.fromStorage(null, aiReport: ''),
          AiReportStatus.pending,
        );
        expect(
          AiReportStatusStorage.fromStorage(null, aiReport: 'texto pronto'),
          AiReportStatus.completed,
        );
        expect(MeasurementRecord.decodeList('{"invalid":true}'), isEmpty);
      },
    );
  });
}
