import 'inspection_plan.dart';

class OllamaAnalysisResult {
  const OllamaAnalysisResult({required this.plan, required this.rawResponse});

  final InspectionPlan plan;
  final String rawResponse;
}
