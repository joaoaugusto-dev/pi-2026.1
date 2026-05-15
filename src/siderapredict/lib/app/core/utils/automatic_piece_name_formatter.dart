String buildAutomaticPieceName({
  required int pieceNumberOfDay,
  required DateTime date,
  String? employeeName,
}) {
  final localDate = date.toLocal();
  final day = localDate.day.toString().padLeft(2, '0');
  final month = localDate.month.toString().padLeft(2, '0');
  final year = localDate.year.toString();

  final baseName = 'Peça $pieceNumberOfDay - $day/$month/$year';
  if (employeeName != null && employeeName.trim().isNotEmpty) {
    return '$baseName - ${employeeName.trim()}';
  }
  return baseName;
}
