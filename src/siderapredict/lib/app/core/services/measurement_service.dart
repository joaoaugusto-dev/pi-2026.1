import 'dart:async';

import 'package:siderapredict/app/core/cv_bridge.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class MeasurementService {
  MeasurementService({CvBridge? bridge}) : _bridge = bridge ?? CvBridge();

  final CvBridge _bridge;

  Future<MeasurementDraft> processImage(String imagePath) async {
    final payload = await _bridge
        .analyze(imagePath)
        .timeout(
          const Duration(seconds: 200),
          onTimeout: () {
            throw TimeoutException(
              'O processamento OpenCV excedeu o tempo limite. Refaca a captura com mais luz e mantenha as bordas visiveis do board ChArUco ao redor da peca.',
            );
          },
        );

    final edges = _toDoubleList(payload['edgesMm']);
    final semicircles = _toDoubleList(payload['semiCircleRadiiMm'] ?? payload['semicircleRadiiMm']);
    final holes = _toDoubleList(payload['holeRadiiMm']);
    final angles = _toDoubleList(payload['anglesDeg']);

    final segments = <PieceSegmentMeasurement>[
      PieceSegmentMeasurement(
        type: PieceSegmentType.overallWidth,
        label: 'Largura geral',
        valueMm: (payload['width'] as num? ?? 0).toDouble(),
      ),
      PieceSegmentMeasurement(
        type: PieceSegmentType.overallHeight,
        label: 'Altura geral',
        valueMm: (payload['height'] as num? ?? 0).toDouble(),
      ),
      // Prioritize Semicircles, Holes and Angles
      for (int i = 0; i < semicircles.length; i++)
        PieceSegmentMeasurement(
          type: PieceSegmentType.semicircle,
          label: 'Semicírculo ${i + 1}',
          valueMm: semicircles[i],
          isRadius: true,
        ),
      for (int i = 0; i < holes.length; i++)
        PieceSegmentMeasurement(
          type: PieceSegmentType.hole,
          label: 'Furo ${i + 1}',
          valueMm: holes[i],
          isRadius: true,
        ),
      for (int i = 0; i < angles.length; i++)
        PieceSegmentMeasurement(
          type: PieceSegmentType.angle,
          label: 'Ângulo ${i + 1}',
          valueMm: angles[i],
          isAngle: true,
        ),
      // Show all edges without filtering
      ...edges
          .asMap()
          .entries
          .map((entry) => PieceSegmentMeasurement(
                type: PieceSegmentType.edge,
                label: 'Aresta ${entry.key + 1}',
                valueMm: entry.value,
              )),
    ];

    return MeasurementDraft(
      sourceImagePath: imagePath,
      processedImagePath: payload['outputPath'] as String? ?? imagePath,
      calibrationSuccess: payload['calibrationSuccess'] == true,
      objectFound: payload['objectFound'] == true,
      widthMm: (payload['width'] as num? ?? 0).toDouble(),
      heightMm: (payload['height'] as num? ?? 0).toDouble(),
      perimeterMm: (payload['perimeterMm'] as num? ?? 0).toDouble(),
      areaMm2: (payload['areaMm2'] as num? ?? 0).toDouble(),
      scaleMicronsPerPx: (payload['scaleMicronsPerPx'] as num?)?.toDouble(),
      markerSizeMm: (payload['markerSizeMm'] as num? ?? 10).toDouble(),
      segments: segments
          .where((segment) => segment.valueMm > 0)
          .toList(growable: false),
      extraInfo: payload['errorMessage'] as String?,
      quickStatus: _buildQuickStatus(payload),
    );
  }

  List<double> _toDoubleList(dynamic value) {
    if (value is! List) {
      return const <double>[];
    }

    return value
        .whereType<num>()
        .map((item) => item.toDouble())
        .toList(growable: false);
  }

  String? _buildQuickStatus(Map<String, dynamic> payload) {
    final markerCount = (payload['markerCount'] as num?)?.toInt();
    final charucoCornerCount = (payload['charucoCornerCount'] as num?)?.toInt();
    final pixelsPerMm = (payload['pixelsPerMm'] as num?)?.toDouble();

    final parts = <String>[];
    if (markerCount != null && markerCount > 0) {
      parts.add('$markerCount marcadores');
    }
    if (charucoCornerCount != null && charucoCornerCount > 0) {
      parts.add('$charucoCornerCount cantos ChArUco');
    }
    if (pixelsPerMm != null && pixelsPerMm > 0) {
      parts.add('${pixelsPerMm.toStringAsFixed(3)} px/mm');
    }

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' | ');
  }
}
