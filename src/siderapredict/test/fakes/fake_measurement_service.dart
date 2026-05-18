import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

/// Implementação fake do MeasurementService para testes.
/// Permite configurar cenários: sucesso, falha de calibração,
/// peça não encontrada, e erro genérico.
///
/// Não estende MeasurementService real para evitar dependência
/// do NativeVisionBridge (FFI nativo).
class FakeMeasurementService {
  /// Draft que será retornado na próxima chamada de processImage.
  MeasurementDraft? nextDraft;

  /// Exceção que será lançada na próxima chamada de processImage.
  /// Tem prioridade sobre nextDraft se não for null.
  Exception? nextError;

  Future<MeasurementDraft> processImage(String imagePath) async {
    // Simula um delay mínimo como o serviço real
    await Future.delayed(const Duration(milliseconds: 10));

    if (nextError != null) {
      throw nextError!;
    }

    if (nextDraft != null) {
      return nextDraft!;
    }

    // Retorno padrão: medição válida com sucesso
    return createSuccessDraft(imagePath: imagePath);
  }

  /// Cria um draft de sucesso com dados realistas para testes.
  static MeasurementDraft createSuccessDraft({
    String imagePath = '/fake/image.jpg',
    double widthMm = 120.5,
    double heightMm = 85.3,
  }) {
    return MeasurementDraft(
      sourceImagePath: imagePath,
      processedImagePath: '/fake/processed.jpg',
      calibrationSuccess: true,
      objectFound: true,
      widthMm: widthMm,
      heightMm: heightMm,
      perimeterMm: 411.6,
      areaMm2: 10278.65,
      scaleMicronsPerPx: 52.3,
      markerSizeMm: 11.0,
      segments: const [
        PieceSegmentMeasurement(
          type: PieceSegmentType.overallWidth,
          label: 'Largura geral',
          valueMm: 120.5,
        ),
        PieceSegmentMeasurement(
          type: PieceSegmentType.overallHeight,
          label: 'Altura geral',
          valueMm: 85.3,
        ),
      ],
      pieceNumberOfDay: 1,
    );
  }

  /// Cria um draft onde a calibração ArUco falhou
  /// (marcadores não detectados).
  static MeasurementDraft createCalibrationFailDraft({
    String imagePath = '/fake/image.jpg',
  }) {
    return MeasurementDraft(
      sourceImagePath: imagePath,
      processedImagePath: '',
      calibrationSuccess: false,
      objectFound: false,
      widthMm: 0,
      heightMm: 0,
      perimeterMm: 0,
      areaMm2: 0,
      scaleMicronsPerPx: null,
      markerSizeMm: 11.0,
      segments: const [],
    );
  }

  /// Cria um draft onde calibração funcionou mas a peça
  /// não foi encontrada no centro da prancheta.
  static MeasurementDraft createObjectNotFoundDraft({
    String imagePath = '/fake/image.jpg',
  }) {
    return MeasurementDraft(
      sourceImagePath: imagePath,
      processedImagePath: '/fake/processed.jpg',
      calibrationSuccess: true,
      objectFound: false,
      widthMm: 0,
      heightMm: 0,
      perimeterMm: 0,
      areaMm2: 0,
      scaleMicronsPerPx: 52.3,
      markerSizeMm: 11.0,
      segments: const [],
    );
  }
}
