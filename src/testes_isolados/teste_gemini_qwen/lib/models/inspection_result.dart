import 'inspection_step.dart';

class InspectionResult {
  const InspectionResult({
    required this.step,
    required this.measuredValue,
    required this.unit,
    required this.approved,
    required this.delta,
    required this.markerCount,
    required this.confidence,
    required this.debug,
    required this.imagePath,
  });

  final InspectionStep step;
  final double measuredValue;
  final String unit;
  final bool approved;
  final double delta;
  final int markerCount;
  final double confidence;
  final String debug;
  final String imagePath;
}
