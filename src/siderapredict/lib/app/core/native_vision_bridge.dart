import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

final class MeasurementResultStruct extends Struct {
  @Float()
  external double widthMm;
  @Float()
  external double heightMm;
  @Bool()
  external bool calibrationSuccess;
  @Bool()
  external bool objectFound;
}

typedef ProcessImageC =
    MeasurementResultStruct Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );
typedef ProcessImageDart =
    MeasurementResultStruct Function(
      Pointer<Utf8> inputPath,
      Pointer<Utf8> outputPath,
    );

class NativeVisionBridge {
  Future<Map<String, dynamic>> analyze(String inputPath) async {
    final directory = await getTemporaryDirectory();
    final now = DateTime.now().microsecondsSinceEpoch;
    final outputPath = '${directory.path}/processed_output_$now.png';
    final preparedInput = await _prepareInputImage(
      inputPath: inputPath,
      directory: directory,
      timestamp: now,
    );

    final pathToSend = preparedInput.path;

    try {
      return await Isolate.run<Map<String, dynamic>>(
        () => _analyzeImageInBackground(
          libraryName: _libraryNameForPlatform(),
          inputPath: pathToSend,
          outputPath: outputPath,
        ),
      );
    } finally {
      if (preparedInput.deleteAfterUse) {
        final preparedFile = File(preparedInput.path);
        if (await preparedFile.exists()) {
          try {
            await preparedFile.delete();
          } catch (_) {}
        }
      }
    }
  }
}

Future<_PreparedInputImage> _prepareInputImage({
  required String inputPath,
  required Directory directory,
  required int timestamp,
}) async {
  final sourceFile = File(inputPath);
  if (!await sourceFile.exists()) {
    return _PreparedInputImage(path: inputPath);
  }

  try {
    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _PreparedInputImage(path: inputPath);
    }

    var normalized = img.bakeOrientation(decoded);
    const maxDimensionPx =
        -1; // <= 0 desativa resize para manter resolucao original.
    final needsResize =
        maxDimensionPx > 0 &&
        (normalized.width > maxDimensionPx ||
            normalized.height > maxDimensionPx);

    if (needsResize) {
      normalized = normalized.width >= normalized.height
          ? img.copyResize(normalized, width: maxDimensionPx)
          : img.copyResize(normalized, height: maxDimensionPx);
    }

    final preparedPath = '${directory.path}/opencv_input_$timestamp.png';
    final encoded = img.encodePng(normalized, level: 2);
    await File(preparedPath).writeAsBytes(encoded, flush: true);

    return _PreparedInputImage(path: preparedPath, deleteAfterUse: true);
  } catch (_) {
    return _PreparedInputImage(path: inputPath);
  }
}

Map<String, dynamic> _analyzeImageInBackground({
  required String libraryName,
  required String inputPath,
  required String outputPath,
}) {
  final lib = DynamicLibrary.open(libraryName);
  final processImage = lib.lookupFunction<ProcessImageC, ProcessImageDart>(
    'process_image',
  );

  final inputPtr = inputPath.toNativeUtf8();
  final outputPtr = outputPath.toNativeUtf8();

  try {
    final result = processImage(inputPtr, outputPtr);

    final geometryPath = '$outputPath.json';
    List<double> edgesMm = const [];
    List<double> anglesDeg = const [];
    List<double> holeRadiiMm = const [];
    List<double> semiCircleRadiiMm = const [];
    double? perimeterMm;
    double? areaMm2;
    double? scaleMicronsPerPx;
    int edgeCount = 0;
    double? pixelsPerMm;
    int? markerCount;
    int? charucoCornerCount;
    String? errorMessage;
    double markerSizeMm = 11.0;
    List<double> holeDiametersMm = const [];
    List<double> holeSpacingMm = const [];
    List<double> slotWidthsMm = const [];
    List<double> slotLengthsMm = const [];

    final geometryFile = File(geometryPath);
    if (geometryFile.existsSync()) {
      try {
        final dynamic decoded = jsonDecode(geometryFile.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          final dynamic edges = decoded['edgesMm'];
          final dynamic angles = decoded['anglesDeg'];
          final dynamic holeRadii = decoded['holeRadiiMm'];
          final dynamic semiCircleRadii = decoded['semiCircleRadiiMm'];
          if (edges is List) {
            edgesMm = edges
                .whereType<num>()
                .map((e) => e.toDouble())
                .toList(growable: false);
          }
          if (angles is List) {
            anglesDeg = angles
                .whereType<num>()
                .map((a) => a.toDouble())
                .toList(growable: false);
          }
          if (holeRadii is List) {
            holeRadiiMm = holeRadii
                .whereType<num>()
                .map((r) => r.toDouble())
                .toList(growable: false);
          }
          if (semiCircleRadii is List) {
            semiCircleRadiiMm = semiCircleRadii
                .whereType<num>()
                .map((r) => r.toDouble())
                .toList(growable: false);
          }
          final dynamic perimeter = decoded['perimeterMm'];
          final dynamic area = decoded['areaMm2'];
          final dynamic scaleMicrons = decoded['scaleMicronsPerPx'];
          final dynamic count = decoded['edgeCount'];
          final dynamic pixelsPerMmRaw = decoded['pixelsPerMm'];
          final dynamic markerCountRaw = decoded['markerCount'];
          final dynamic charucoCornerCountRaw = decoded['charucoCornerCount'];
          final dynamic errorMessageRaw = decoded['errorMessage'];
          final dynamic markerSizeMmRaw = decoded['markerSizeMm'];
          if (perimeter is num) perimeterMm = perimeter.toDouble();
          if (area is num) areaMm2 = area.toDouble();
          if (scaleMicrons is num) scaleMicronsPerPx = scaleMicrons.toDouble();
          if (count is num) edgeCount = count.toInt();
          if (pixelsPerMmRaw is num) pixelsPerMm = pixelsPerMmRaw.toDouble();
          if (markerCountRaw is num) markerCount = markerCountRaw.toInt();
          if (charucoCornerCountRaw is num) {
            charucoCornerCount = charucoCornerCountRaw.toInt();
          }
          if (errorMessageRaw is String && errorMessageRaw.trim().isNotEmpty) {
            errorMessage = errorMessageRaw;
          }
          if (markerSizeMmRaw is num) {
            markerSizeMm = markerSizeMmRaw.toDouble();
          }
          // New expanded fields
          final dynamic holeDiametersRaw = decoded['holeDiametersMm'];
          final dynamic holeSpacingRaw = decoded['holeSpacingMm'];
          final dynamic slotWidthsRaw = decoded['slotWidthsMm'];
          final dynamic slotLengthsRaw = decoded['slotLengthsMm'];
          if (holeDiametersRaw is List) {
            holeDiametersMm = holeDiametersRaw
                .whereType<num>()
                .map((v) => v.toDouble())
                .toList(growable: false);
          }
          if (holeSpacingRaw is List) {
            holeSpacingMm = holeSpacingRaw
                .whereType<num>()
                .map((v) => v.toDouble())
                .toList(growable: false);
          }
          if (slotWidthsRaw is List) {
            slotWidthsMm = slotWidthsRaw
                .whereType<num>()
                .map((v) => v.toDouble())
                .toList(growable: false);
          }
          if (slotLengthsRaw is List) {
            slotLengthsMm = slotLengthsRaw
                .whereType<num>()
                .map((v) => v.toDouble())
                .toList(growable: false);
          }
        }
      } catch (_) {}
    }

    final resolvedOutputPath = File(outputPath).existsSync()
        ? outputPath
        : inputPath;

    return {
      'width': result.widthMm,
      'height': result.heightMm,
      'calibrationSuccess': result.calibrationSuccess,
      'objectFound': result.objectFound,
      'outputPath': resolvedOutputPath,
      'edgesMm': edgesMm,
      'anglesDeg': anglesDeg,
      'holeRadiiMm': holeRadiiMm,
      'semiCircleRadiiMm': semiCircleRadiiMm,
      'holeDiametersMm': holeDiametersMm,
      'holeSpacingMm': holeSpacingMm,
      'slotWidthsMm': slotWidthsMm,
      'slotLengthsMm': slotLengthsMm,
      'perimeterMm': perimeterMm,
      'areaMm2': areaMm2,
      'scaleMicronsPerPx': scaleMicronsPerPx,
      'markerSizeMm': markerSizeMm,
      'edgeCount': edgeCount,
      'errorMessage': errorMessage,
      'pixelsPerMm': pixelsPerMm,
      'markerCount': markerCount,
      'charucoCornerCount': charucoCornerCount,
    };
  } finally {
    calloc.free(inputPtr);
    calloc.free(outputPtr);
  }
}

String _libraryNameForPlatform() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libvision_engine.so';
  }
  if (Platform.isWindows) {
    return 'vision_engine.dll';
  }
  throw UnsupportedError('Plataforma nao suportada neste PoC');
}

final class _PreparedInputImage {
  const _PreparedInputImage({required this.path, this.deleteAfterUse = false});

  final String path;
  final bool deleteAfterUse;
}
