import 'dart:convert';

enum PieceSegmentType { edge, semicircle, hole, overallWidth, overallHeight, angle }

enum AiReportStatus { pending, generating, completed, failed }

extension AiReportStatusStorage on AiReportStatus {
  String get storageValue {
    switch (this) {
      case AiReportStatus.pending:
        return 'pending';
      case AiReportStatus.generating:
        return 'generating';
      case AiReportStatus.completed:
        return 'completed';
      case AiReportStatus.failed:
        return 'failed';
    }
  }

  static AiReportStatus fromStorage(String? raw, {required String aiReport}) {
    switch (raw) {
      case 'pending':
        return AiReportStatus.pending;
      case 'generating':
        return AiReportStatus.generating;
      case 'completed':
        return AiReportStatus.completed;
      case 'failed':
        return AiReportStatus.failed;
      default:
        return aiReport.trim().isEmpty
            ? AiReportStatus.pending
            : AiReportStatus.completed;
    }
  }
}

extension PieceSegmentTypeLabel on PieceSegmentType {
  String get label {
    switch (this) {
      case PieceSegmentType.edge:
        return 'Aresta';
      case PieceSegmentType.semicircle:
        return 'Semicirculo';
      case PieceSegmentType.hole:
        return 'Furo';
      case PieceSegmentType.overallWidth:
        return 'Largura geral';
      case PieceSegmentType.overallHeight:
        return 'Altura geral';
      case PieceSegmentType.angle:
        return 'Ângulo';
    }
  }

  String get storageValue {
    switch (this) {
      case PieceSegmentType.edge:
        return 'edge';
      case PieceSegmentType.semicircle:
        return 'semicircle';
      case PieceSegmentType.hole:
        return 'hole';
      case PieceSegmentType.overallWidth:
        return 'overall_width';
      case PieceSegmentType.overallHeight:
        return 'overall_height';
      case PieceSegmentType.angle:
        return 'angle';
    }
  }

  static PieceSegmentType fromStorage(String raw) {
    switch (raw) {
      case 'edge':
        return PieceSegmentType.edge;
      case 'semicircle':
        return PieceSegmentType.semicircle;
      case 'overall_width':
        return PieceSegmentType.overallWidth;
      case 'overall_height':
        return PieceSegmentType.overallHeight;
      case 'angle':
        return PieceSegmentType.angle;
      case 'hole':
      default:
        return PieceSegmentType.hole;
    }
  }
}

class PieceSegmentMeasurement {
  const PieceSegmentMeasurement({
    required this.type,
    required this.label,
    required this.valueMm,
    this.isRadius = false,
    this.isAngle = false,
  });

  final PieceSegmentType type;
  final String label;
  final double valueMm;
  final bool isRadius;
  final bool isAngle;

  String get displayValue {
    if (isAngle) return '${valueMm.toStringAsFixed(1)}°';
    final formatted = valueMm.toStringAsFixed(3);
    return isRadius ? 'R$formatted mm' : '$formatted mm';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.storageValue,
      'label': label,
      'valueMm': valueMm,
      'isRadius': isRadius,
      'isAngle': isAngle,
    };
  }

  factory PieceSegmentMeasurement.fromJson(Map<String, dynamic> json) {
    return PieceSegmentMeasurement(
      type: PieceSegmentTypeLabel.fromStorage(
        json['type'] as String? ?? 'hole',
      ),
      label: json['label'] as String? ?? 'Medida',
      valueMm: (json['valueMm'] as num? ?? 0).toDouble(),
      isRadius: json['isRadius'] as bool? ?? false,
      isAngle: json['isAngle'] as bool? ?? false,
    );
  }
}

class MeasurementDraft {
  const MeasurementDraft({
    required this.sourceImagePath,
    required this.processedImagePath,
    required this.calibrationSuccess,
    required this.objectFound,
    required this.widthMm,
    required this.heightMm,
    required this.perimeterMm,
    required this.areaMm2,
    required this.scaleMicronsPerPx,
    required this.markerSizeMm,
    required this.segments,
    this.pieceNumberOfDay,
    this.extraInfo,
    this.quickStatus,
  });

  final String sourceImagePath;
  final String processedImagePath;
  final bool calibrationSuccess;
  final bool objectFound;
  final double widthMm;
  final double heightMm;
  final double perimeterMm;
  final double areaMm2;
  final double? scaleMicronsPerPx;
  final double markerSizeMm;
  final List<PieceSegmentMeasurement> segments;
  final int? pieceNumberOfDay;
  final String? extraInfo;
  final String? quickStatus;

  bool get hasDimensionData =>
      widthMm > 0 ||
      heightMm > 0 ||
      perimeterMm > 0 ||
      areaMm2 > 0 ||
      segments.isNotEmpty;

  bool get isValidMeasurement =>
      calibrationSuccess && objectFound && hasDimensionData;

  double get primaryValueMm {
    if (segments.isNotEmpty) {
      return segments.first.valueMm;
    }
    if (widthMm > 0) {
      return widthMm;
    }
    return heightMm;
  }

  MeasurementDraft copyWith({
    String? sourceImagePath,
    String? processedImagePath,
    bool? calibrationSuccess,
    bool? objectFound,
    double? widthMm,
    double? heightMm,
    double? perimeterMm,
    double? areaMm2,
    double? scaleMicronsPerPx,
    double? markerSizeMm,
    List<PieceSegmentMeasurement>? segments,
    int? pieceNumberOfDay,
    String? extraInfo,
    String? quickStatus,
  }) {
    return MeasurementDraft(
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      calibrationSuccess: calibrationSuccess ?? this.calibrationSuccess,
      objectFound: objectFound ?? this.objectFound,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      perimeterMm: perimeterMm ?? this.perimeterMm,
      areaMm2: areaMm2 ?? this.areaMm2,
      scaleMicronsPerPx: scaleMicronsPerPx ?? this.scaleMicronsPerPx,
      markerSizeMm: markerSizeMm ?? this.markerSizeMm,
      segments: segments ?? this.segments,
      pieceNumberOfDay: pieceNumberOfDay ?? this.pieceNumberOfDay,
      extraInfo: extraInfo ?? this.extraInfo,
      quickStatus: quickStatus ?? this.quickStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceImagePath': sourceImagePath,
      'processedImagePath': processedImagePath,
      'calibrationSuccess': calibrationSuccess,
      'objectFound': objectFound,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'perimeterMm': perimeterMm,
      'areaMm2': areaMm2,
      'scaleMicronsPerPx': scaleMicronsPerPx,
      'markerSizeMm': markerSizeMm,
      'segments': segments.map((m) => m.toJson()).toList(growable: false),
      'pieceNumberOfDay': pieceNumberOfDay,
      'extraInfo': extraInfo,
      'quickStatus': quickStatus,
    };
  }

  factory MeasurementDraft.fromJson(Map<String, dynamic> json) {
    final rawSegments =
        (json['segments'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    return MeasurementDraft(
      sourceImagePath: json['sourceImagePath'] as String? ?? '',
      processedImagePath: json['processedImagePath'] as String? ?? '',
      calibrationSuccess: json['calibrationSuccess'] as bool? ?? false,
      objectFound: json['objectFound'] as bool? ?? false,
      widthMm: (json['widthMm'] as num? ?? 0).toDouble(),
      heightMm: (json['heightMm'] as num? ?? 0).toDouble(),
      perimeterMm: (json['perimeterMm'] as num? ?? 0).toDouble(),
      areaMm2: (json['areaMm2'] as num? ?? 0).toDouble(),
      scaleMicronsPerPx: (json['scaleMicronsPerPx'] as num?)?.toDouble(),
      markerSizeMm: (json['markerSizeMm'] as num? ?? 10).toDouble(),
      segments: rawSegments
          .map(PieceSegmentMeasurement.fromJson)
          .toList(growable: false),
      pieceNumberOfDay: json['pieceNumberOfDay'] as int?,
      extraInfo: json['extraInfo'] as String?,
      quickStatus: json['quickStatus'] as String?,
    );
  }
}

enum ConformityStatus { ok, nok }

extension ConformityStatusStorage on ConformityStatus {
  String get storageValue => name;

  static ConformityStatus fromStorage(String? raw) {
    if (raw == 'nok') return ConformityStatus.nok;
    return ConformityStatus.ok;
  }
}

class MeasurementRecord {
  const MeasurementRecord({
    required this.id,
    required this.pieceName,
    required this.createdAt,
    required this.primaryValueMm,
    required this.aiReport,
    required this.aiReportStatus,
    required this.draft,
    this.photoBase64,
    this.thumbnailBase64,
    this.conformityStatus = ConformityStatus.ok,
    this.nonConformityReason,
    this.nonConformityObservation,
  });

  final String id;
  final String pieceName;
  final DateTime createdAt;
  final double primaryValueMm;
  final String aiReport;
  final AiReportStatus aiReportStatus;
  final MeasurementDraft draft;
  final String? photoBase64;
  final String? thumbnailBase64;
  final ConformityStatus conformityStatus;
  final String? nonConformityReason;
  final String? nonConformityObservation;

  bool get isAiReportStreaming =>
      aiReportStatus == AiReportStatus.pending ||
      aiReportStatus == AiReportStatus.generating;

  MeasurementRecord copyWith({
    String? id,
    String? pieceName,
    DateTime? createdAt,
    double? primaryValueMm,
    String? aiReport,
    AiReportStatus? aiReportStatus,
    MeasurementDraft? draft,
    String? photoBase64,
    String? thumbnailBase64,
    bool clearPhotoBase64 = false,
    ConformityStatus? conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
  }) {
    return MeasurementRecord(
      id: id ?? this.id,
      pieceName: pieceName ?? this.pieceName,
      createdAt: createdAt ?? this.createdAt,
      primaryValueMm: primaryValueMm ?? this.primaryValueMm,
      aiReport: aiReport ?? this.aiReport,
      aiReportStatus: aiReportStatus ?? this.aiReportStatus,
      draft: draft ?? this.draft,
      photoBase64: clearPhotoBase64 ? null : (photoBase64 ?? this.photoBase64),
      thumbnailBase64: clearPhotoBase64
          ? null
          : (thumbnailBase64 ?? this.thumbnailBase64),
      conformityStatus: conformityStatus ?? this.conformityStatus,
      nonConformityReason: nonConformityReason ?? this.nonConformityReason,
      nonConformityObservation:
          nonConformityObservation ?? this.nonConformityObservation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pieceName': pieceName,
      'createdAt': createdAt.toIso8601String(),
      'primaryValueMm': primaryValueMm,
      'aiReport': aiReport,
      'aiReportStatus': aiReportStatus.storageValue,
      'photoBase64': photoBase64,
      'thumbnailBase64': thumbnailBase64,
      'draft': draft.toJson(),
      'conformityStatus': conformityStatus.storageValue,
      'nonConformityReason': nonConformityReason,
      'nonConformityObservation': nonConformityObservation,
    };
  }

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) {
    final dynamic draftJson = json['draft'];
    final draftMap = draftJson is Map<String, dynamic>
        ? draftJson
        : const <String, dynamic>{};
    final aiReport = json['aiReport'] as String? ?? '';

    return MeasurementRecord(
      id: json['id'] as String? ?? '',
      pieceName: json['pieceName'] as String? ?? 'Peca sem nome',
      createdAt: _parseDateTime(json['createdAt']),
      primaryValueMm: (json['primaryValueMm'] as num? ?? 0).toDouble(),
      aiReport: aiReport,
      aiReportStatus: AiReportStatusStorage.fromStorage(
        json['aiReportStatus'] as String?,
        aiReport: aiReport,
      ),
      draft: MeasurementDraft.fromJson(draftMap),
      photoBase64: json['photoBase64'] as String?,
      thumbnailBase64: json['thumbnailBase64'] as String?,
      conformityStatus: ConformityStatusStorage.fromStorage(
        json['conformityStatus'] as String?,
      ),
      nonConformityReason: json['nonConformityReason'] as String?,
      nonConformityObservation: json['nonConformityObservation'] as String?,
    );
  }

  static String encodeList(List<MeasurementRecord> records) {
    final payload = records.map((r) => r.toJson()).toList(growable: false);
    return jsonEncode(payload);
  }

  static List<MeasurementRecord> decodeList(String input) {
    final dynamic decoded = jsonDecode(input);
    if (decoded is! List<dynamic>) {
      return const <MeasurementRecord>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MeasurementRecord.fromJson)
        .toList(growable: false);
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
