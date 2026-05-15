String buildAutomaticPieceName({
  required int pieceNumberOfDay,
  required DateTime date,
}) {
  final localDate = date.toLocal();
  final day = localDate.day.toString().padLeft(2, '0');
  final month = localDate.month.toString().padLeft(2, '0');
  final year = localDate.year.toString();
  return 'Peça $pieceNumberOfDay - $day/$month/$year';
}
