import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class ReportExportService {
  static const _brandColor = PdfColor.fromInt(0xFFB71C1C);

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/soufer.png');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Erro ao carregar logo para PDF: $e');
      return null;
    }
  }

  Future<File?> _saveFile(String fileName, List<int> bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      final file = File(tempPath);
      await file.writeAsBytes(bytes, flush: true);

      final params = SaveFileDialogParams(sourceFilePath: file.path);
      final finalPath = await FlutterFileDialog.saveFile(params: params);

      if (finalPath != null) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao exportar arquivo via FlutterFileDialog: $e');
      return null;
    }
  }

  Future<File?> exportSingleRecordPdf(MeasurementRecord record) async {
    final sanitizedName = _sanitizeFileName(record.pieceName);
    final fileName = '$sanitizedName.pdf';

    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final logo = await _loadLogo();

    pw.MemoryImage? imageProvider;
    final imageBase64 = record.photoBase64 ?? record.thumbnailBase64;
    if (imageBase64 != null) {
      try {
        final bytes = base64Decode(imageBase64);
        imageProvider = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logo != null)
                      pw.Container(
                        height: 40,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const pw.EdgeInsets.only(right: 12),
                        decoration: pw.BoxDecoration(
                          color: _brandColor,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SIDERA PREDICT',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 22,
                            color: _brandColor,
                          ),
                        ),
                        pw.Text(
                          'Relatorio Tecnico de Medicao',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      dateFormat.format(record.createdAt.toLocal()),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'ID: ${record.id.substring(0, 8).toUpperCase()}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: _brandColor, indent: 0, endIndent: 0),
            pw.SizedBox(height: 20),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (imageProvider != null)
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      height: 280,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.ClipRRect(
                        horizontalRadius: 4,
                        verticalRadius: 4,
                        child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                if (imageProvider != null) pw.SizedBox(width: 20),

                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSectionTitle('Dados da Peca'),
                      _buildPdfInfoRow('Nome:', record.pieceName),
                      if (record.draft.pieceNumberOfDay != null)
                        _buildPdfInfoRow('Seq. Dia:', record.draft.pieceNumberOfDay.toString()),
                      pw.SizedBox(height: 15),

                      _buildPdfSectionTitle('Dimensoes Gerais'),
                      _buildPdfInfoRow('Largura:', '${record.draft.widthMm.toStringAsFixed(2)} mm'),
                      _buildPdfInfoRow('Altura:', '${record.draft.heightMm.toStringAsFixed(2)} mm'),
                      _buildPdfInfoRow('Perimetro:', '${record.draft.perimeterMm.toStringAsFixed(2)} mm'),
                      _buildPdfInfoRow('Area:', '${record.draft.areaMm2.toStringAsFixed(2)} mm2'),
                      if (record.draft.scaleMicronsPerPx != null)
                        _buildPdfInfoRow('Escala:', '${record.draft.scaleMicronsPerPx!.toStringAsFixed(2)} um/px'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            if (record.draft.segments.isNotEmpty) ...[
              _buildPdfSectionTitle('Segmentos Detalhados'),
              pw.TableHelper.fromTextArray(
                headers: ['Tipo/Label', 'Valor Medido'],
                data: record.draft.segments.map((s) => [s.label, s.displayValue]).toList(),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: _brandColor),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 9),
                columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)},
              ),
              pw.SizedBox(height: 20),
            ],

            _buildPdfSectionTitle('Analise e Resumo da IA'),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey200),
              ),
              child: pw.Text(
                record.aiReport.isEmpty ? 'Nenhum relatorio gerado.' : record.aiReport,
                style: const pw.TextStyle(fontSize: 10, height: 1.4),
              ),
            ),
            
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sidera Predict - Inteligencia Artificial em Visao Computacional',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Documento gerado automaticamente.',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    return _saveFile(fileName, bytes);
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _brandColor,
            ),
          ),
          pw.Container(
            height: 1,
            width: 40,
            color: _brandColor,
            margin: const pw.EdgeInsets.only(top: 2),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<File?> exportSingleRecordExcel(MeasurementRecord record) async {
    final sanitizedName = _sanitizeFileName(record.pieceName);
    final fileName = '$sanitizedName.xlsx';
    final bytes = await _buildExcel([record]);
    return _saveFile(fileName, bytes);
  }

  Future<File?> exportHistoryPdf(List<MeasurementRecord> records) async {
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'Relatorio Geral de Medicoes - $dateStr.pdf';

    final pdfDoc = await _buildPdf(records);
    final bytes = await pdfDoc.save();
    return _saveFile(fileName, bytes);
  }

  Future<File?> exportHistoryExcel(List<MeasurementRecord> records) async {
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'Historico Geral de Medicoes - $dateStr.xlsx';

    final bytes = await _buildExcel(records);
    return _saveFile(fileName, bytes);
  }

  Future<pw.Document> _buildPdf(List<MeasurementRecord> records) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final logo = await _loadLogo();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logo != null)
                  pw.Container(
                    height: 30,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: _brandColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(),
                pw.Text(
                  'Relatorio Consolidado - Sidera Predict',
                  style: pw.TextStyle(color: _brandColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: _brandColor),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
          ),
        ),
        build: (context) {
          final content = <pw.Widget>[
            pw.Text(
              'HISTORICO GERAL DE MEDICOES',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 20,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.Text(
              'Consolidado de todas as peças medidas no periodo.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
          ];

          if (records.isEmpty) {
            content.add(pw.Text('Nenhuma medicao registrada.'));
            return content;
          }

          content.add(
            pw.TableHelper.fromTextArray(
              headers: ['Data/Hora', 'Peca', 'L (mm)', 'A (mm)', 'Area (mm2)'],
              data: records.map((r) => [
                dateFormat.format(r.createdAt.toLocal()),
                r.pieceName,
                r.draft.widthMm.toStringAsFixed(1),
                r.draft.heightMm.toStringAsFixed(1),
                r.draft.areaMm2.toStringAsFixed(0),
              ]).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: _brandColor),
              cellStyle: const pw.TextStyle(fontSize: 8),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(0.8),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(1),
              },
            ),
          );

          content.add(pw.SizedBox(height: 30));
          content.add(
            pw.Row(
              children: [
                pw.Text('DETALHAMENTO POR ITEM', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _brandColor)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.Divider(color: _brandColor, thickness: 0.5)),
              ],
            ),
          );
          content.add(pw.SizedBox(height: 15));

          for (final record in records) {
            pw.MemoryImage? thumbProvider;
            final thumbBase64 = record.thumbnailBase64 ?? record.photoBase64;
            if (thumbBase64 != null) {
              try {
                thumbProvider = pw.MemoryImage(base64Decode(thumbBase64));
              } catch (_) {}
            }

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (thumbProvider != null)
                          pw.Container(
                            width: 80,
                            height: 80,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: pw.Image(thumbProvider, fit: pw.BoxFit.cover),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                record.pieceName.toUpperCase(),
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _brandColor),
                              ),
                              pw.Text(
                                dateFormat.format(record.createdAt.toLocal()),
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Dimensoes: ${record.draft.widthMm.toStringAsFixed(2)} x ${record.draft.heightMm.toStringAsFixed(2)} mm',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                              pw.Text(
                                'Perimetro: ${record.draft.perimeterMm.toStringAsFixed(2)} mm | Area: ${record.draft.areaMm2.toStringAsFixed(0)} mm2',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (record.draft.segments.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text('Segmentos:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.Wrap(
                        spacing: 8,
                        children: record.draft.segments.map((s) => pw.Text(
                          '${s.label}: ${s.displayValue}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        )).toList(),
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey100),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RESUMO IA:',
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            record.aiReport.isEmpty ? 'Sem análise disponível.' : record.aiReport,
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return content;
        },
      ),
    );

    return doc;
  }

  Future<List<int>> _buildExcel(List<MeasurementRecord> records) async {
    final excel = Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final sheet = excel['Medicoes'];
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final headers = <String>[
      'Data/Hora',
      'Peca',
      'Largura (mm)',
      'Altura (mm)',
      'Perimetro (mm)',
      'Area (mm2)',
      'Resumo Técnico (IA)',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#B71C1C'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bottomBorder: Border(borderStyle: BorderStyle.Medium, borderColorHex: ExcelColor.fromHexString('#000000')),
    );

    final cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
    );

    final numberStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
      rightBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
      bottomBorder: Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.fromHexString('#D5D8DC')),
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final rowIndex = i + 1;

      sheet.appendRow(<CellValue>[
        TextCellValue(dateFormat.format(record.createdAt.toLocal())),
        TextCellValue(record.pieceName),
        DoubleCellValue(record.draft.widthMm),
        DoubleCellValue(record.draft.heightMm),
        DoubleCellValue(record.draft.perimeterMm),
        DoubleCellValue(record.draft.areaMm2),
        TextCellValue(record.aiReport.trim().isEmpty ? 'N/A' : record.aiReport),
      ]);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = cellStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = numberStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = numberStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = numberStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = numberStyle;
      
      final reportCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
      reportCell.cellStyle = cellStyle;
    }

    try {
      sheet.setColumnWidth(0, 20);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(2, 15);
      sheet.setColumnWidth(3, 15);
      sheet.setColumnWidth(4, 18);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 60);
    } catch (_) {
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Falha ao gerar bytes do arquivo Excel.');
    }

    return bytes;
  }
}
