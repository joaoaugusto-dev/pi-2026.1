import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class AiReportChunk {
  const AiReportChunk({required this.fullText, required this.isDone});

  final String fullText;
  final bool isDone;
}

class OllamaReportService {
  OllamaReportService({
    required this.baseUrl,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String model;
  final http.Client _client;

  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  Stream<AiReportChunk> streamReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required ConformityStatus conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async* {
    if (!isConfigured) {
      throw StateError(
        'Configure OLLAMA_BASE_URL publico HTTPS e OLLAMA_MODEL no .env',
      );
    }

    final prompt = _buildPrompt(
      pieceName: pieceName,
      draft: draft,
      createdAt: createdAt,
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
      responsavel: responsavel,
    );
    final request = http.Request('POST', Uri.parse('$baseUrl/api/generate'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, dynamic>{
        'model': model,
        'stream': true,
        'prompt': prompt,
      });

    final buffer = StringBuffer();

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw StateError('Falha HTTP ${response.statusCode} ao gerar relatorio');
    }

    await for (final line
        in response.stream
            .timeout(const Duration(seconds: 15))
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) {
        continue;
      }

      dynamic payload;
      try {
        payload = jsonDecode(line);
      } catch (_) {
        continue;
      }

      if (payload is! Map<String, dynamic>) {
        continue;
      }

      final token = payload['response'];
      if (token is String && token.isNotEmpty) {
        buffer.write(token);
        yield AiReportChunk(
          fullText: _sanitizeAiReport(buffer.toString(), isPartial: true),
          isDone: false,
        );
      }

      if (payload['done'] == true) {
        final text = _sanitizeAiReport(buffer.toString());
        if (text.isEmpty) {
          throw StateError('Resposta vazia do Ollama');
        }
        yield AiReportChunk(fullText: text, isDone: true);
        return;
      }
    }

    final text = _sanitizeAiReport(buffer.toString());
    if (text.isEmpty) {
      throw StateError('Fluxo interrompido antes de finalizar resposta');
    }

    yield AiReportChunk(fullText: text, isDone: true);
  }

  Future<String> generateReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required ConformityStatus conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) async {
    if (!isConfigured) {
      return _fallbackReport(
        pieceName,
        draft,
        createdAt,
        'Configure `OLLAMA_BASE_URL` publico HTTPS e `OLLAMA_MODEL` no `.env`',
      );
    }

    final prompt = _buildPrompt(
      pieceName: pieceName,
      draft: draft,
      createdAt: createdAt,
      conformityStatus: conformityStatus,
      nonConformityReason: nonConformityReason,
      nonConformityObservation: nonConformityObservation,
      responsavel: responsavel,
    );

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'model': model,
              'stream': false,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 400) {
        return _fallbackReport(
          pieceName,
          draft,
          createdAt,
          'Falha HTTP ${response.statusCode}',
        );
      }

      final dynamic payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final raw = payload['response'];
        if (raw is String && raw.trim().isNotEmpty) {
          return _sanitizeAiReport(raw);
        }
      }
    } catch (_) {}

    return _fallbackReport(pieceName, draft, createdAt, 'Ollama indisponivel');
  }

  String _buildPrompt({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required ConformityStatus conformityStatus,
    String? nonConformityReason,
    String? nonConformityObservation,
    String? responsavel,
  }) {
    final segments = draft.segments
        .map((s) => '- **${s.label}**: **${s.displayValue}**')
        .join('\n');
    final measurementDate = _formatDate(createdAt);
    final measurementTime = _formatTime(createdAt);
    final pieceNumber = draft.pieceNumberOfDay?.toString() ?? 'n/a';

    return '''
Você é um Assistente Técnico especializado em documentação de medições.
Sua tarefa é sintetizar os dados da peça "$pieceName" em um resumo claro e objetivo.

Contexto:
- Peça: $pieceName (Nº $pieceNumber do dia)
- Data/Hora: $measurementDate às $measurementTime
- Responsável: ${responsavel ?? 'Não informado'}
- Status Registrado pelo Operador: **${conformityStatus == ConformityStatus.ok ? 'CONFORME' : 'NÃO CONFORME'}**
${conformityStatus == ConformityStatus.nok ? '- Motivo da Reprovação (Informado): **$nonConformityReason**' : ''}
${conformityStatus == ConformityStatus.nok && nonConformityObservation != null ? '- Observação do Operador: $nonConformityObservation' : ''}

Dados de Medição:
- Dimensões Principais: **${draft.widthMm.toStringAsFixed(3)}** x **${draft.heightMm.toStringAsFixed(3)}** mm
- Perímetro: **${draft.perimeterMm.toStringAsFixed(2)}** mm | Área: **${draft.areaMm2.toStringAsFixed(2)}** mm²
- Amostra de Segmentos:
$segments

Instruções Cruciais:
1. NÃO JULGUE: Você não sabe quais são as tolerâncias da peça. Jamais diga que uma medida está "errada", "fora do padrão" ou "incorreta".
2. RESUMO OBJETIVO: Descreva a peça e o registro de forma informativa, não avaliativa.
3. NÃO REPITA TUDO: Não liste todas as medidas individuais. Foque na visão geral.

Estrutura do Relatório:
## 1. Resumo da Peça
(Uma frase descrevendo a peça e o status do registro efetuado pelo operador)

## 2. Destaques da Geometria
(Descreva as características principais da peça, como dimensões externas e complexidade dos contornos, sem citar se estão certas ou erradas)

## 3. Informações de Registro
(Resuma os dados de data, hora e observações do operador de forma limpa)

Regras:
- NÃO use introduções como "Aqui está o relatório".
- NÃO dê opiniões ou recomendações técnicas.
- Use Markdown simples.
- Mantenha um tom neutro e profissional.
''';
  }

  String buildFallbackReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
    required String reason,
  }) {
    return _fallbackReport(pieceName, draft, createdAt, reason);
  }

  String _fallbackReport(
    String pieceName,
    MeasurementDraft draft,
    DateTime createdAt,
    String reason,
  ) {
    final data = _formatDate(createdAt);
    final hora = _formatTime(createdAt);
    final infoExtra = draft.extraInfo ?? '-';
    final resumoRapido = draft.quickStatus ?? 'n/a';
    final segmentosResumo = draft.segments.isEmpty
        ? 'Nenhum segmento classificado.'
        : '${draft.segments.length} segmento(s) identificado(s).';

    return '''
## 1. Resumo da Medição
- Peça: $pieceName
- Status: $resumoRapido
- Data: $data ($hora)

## 2. Alerta de Sistema
- **Relatório Simplificado**: Ocorreu uma falha na geração via IA ($reason).
- Valide as medidas manualmente abaixo.

## 3. Detalhamento Técnico
- Medida Principal: **${draft.primaryValueMm.toStringAsFixed(3)} mm**
- Segmentos: $segmentosResumo
- Info Extra: $infoExtra

## 4. Ação Recomendada
- Validar visualmente a imagem processada antes de aprovar a peça.
- Repetir a captura se houver dúvida de calibração ou contorno.
''';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _sanitizeAiReport(String raw, {bool isPartial = false}) {
    var text = raw.replaceAll('\r\n', '\n').trimLeft();

    text = text
        .replaceAllMapped(
          RegExp(
            r'^##\s*(dados medidos|medidas coletadas|medidas|dimensoes medidas)\s*$',
            multiLine: true,
            caseSensitive: false,
          ),
          (_) => '',
        )
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();

    if (isPartial) {
      return text;
    }

    if (!text.contains('## ')) {
      return '''
## 1. Resumo da Medição
$text
'''
          .trim();
    }

    return text;
  }
}
