import 'package:flutter/foundation.dart';

import 'package:siderapredict/app/core/native_vision_bridge.dart';

class VisionViewModel extends ChangeNotifier {
  final NativeVisionBridge _nativeVisionBridge = NativeVisionBridge();

  String resultText = "Nenhuma medição realizada.";
  bool isProcessing = false;
  String? imagePath;

  void analyzeImage(String path) async {
    isProcessing = true;
    resultText = "Processando nativamente...";
    imagePath = path;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final result = await _nativeVisionBridge.analyze(path);
      if (result['calibrationSuccess'] == true) {
        if (result['objectFound'] == true) {
          final w = result['width'] as double;
          final h = result['height'] as double;
          final hasMeasures = w > 0 || h > 0;
          resultText = hasMeasures
              ? "✅ MEDIÇÃO CONCLUÍDA\n\nLargura: ${w.toStringAsFixed(1)} mm\nAltura: ${h.toStringAsFixed(1)} mm"
              : "✅ HOMOGRAFIA ChArUco CONCLUÍDA\n\nImagem planificada gerada com sucesso.";

          imagePath = result['outputPath'] as String? ?? imagePath;
        } else {
          resultText =
              result['errorMessage'] as String? ??
              "⚠️ Calibração ChArUco concluída, mas nenhuma geometria mensurável foi extraída.";
        }
      } else {
        resultText =
            result['errorMessage'] as String? ??
            "❌ FALHA NA CALIBRAÇÃO\n\nOs cantos do board ChArUco não puderam ser interpolados.";
      }
    } catch (e) {
      resultText = "Erro ao executar FFI: $e";
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  void reset() {
    resultText = "Nenhuma medição realizada.";
    isProcessing = false;
    imagePath = null;
    notifyListeners();
  }
}
