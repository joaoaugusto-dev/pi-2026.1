import 'package:flutter/services.dart';

import '../models/inspection_result.dart';
import '../models/inspection_step.dart';

class NativeMetrologyService {
  static const MethodChannel _channel = MethodChannel(
    'br.com.teste_gemini_qwen/metrology',
  );

  Future<InspectionResult> processStep({
    required InspectionStep step,
    required String imagePath,
    required double markerSizeMm,
  }) async {
    final dynamic raw = await _channel
        .invokeMethod<dynamic>('processImage', <String, dynamic>{
          'imagePath': imagePath,
          'analysisType': step.analysisType.channelValue,
          'measurementMode': step.measurementMode.channelValue,
          'axisPreference': step.axisPreference.channelValue,
          'targetHint': step.targetHint,
          'requiresAllMarkers': step.requiresAllMarkers,
          'expectedValue': step.expectedValue,
          'markerSizeMm': markerSizeMm,
        });

    final payload = _normalizeMap(raw);

    final measuredValue = _toDouble(payload['measuredValue']);
    final returnedUnit = payload['unit']?.toString() ?? step.unit;
    final delta = (measuredValue - step.expectedValue).abs();
    final approved = delta <= step.tolerance;

    return InspectionResult(
      step: step,
      measuredValue: measuredValue,
      unit: returnedUnit,
      approved: approved,
      delta: delta,
      markerCount: _toInt(payload['markerCount']),
      confidence: _toDouble(payload['confidence']),
      debug: payload['debug']?.toString() ?? '',
      imagePath: imagePath,
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Resposta invalida do bridge nativo.');
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}
