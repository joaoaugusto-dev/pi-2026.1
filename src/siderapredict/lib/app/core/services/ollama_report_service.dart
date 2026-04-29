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

  Future<String> buildReport({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
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
    } catch (_) {
    }

    return _fallbackReport(pieceName, draft, createdAt, 'Ollama indisponivel');
  }

  String _buildPrompt({
    required String pieceName,
    required MeasurementDraft draft,
    required DateTime createdAt,
  }) {
    final segments = draft.segments
        .map((s) => '${s.label}: ${s.displayValue} [${s.type.storageValue}]')
        .join('\n');
    final measurementDate = _formatDate(createdAt);
    final measurementTime = _formatTime(createdAt);
    final pieceNumber = draft.pieceNumberOfDay?.toString() ?? 'n/a';

    return '''
Voce e um inspetor dimensional industrial.
Gere um relatorio tecnico curto, claro e objetivo em portugues brasileiro para a peca "$pieceName".

Contexto da inspecao:
- Data da inspecao: $measurementDate
- Hora da inspecao: $measurementTime
- Numero da peca do dia: $pieceNumber

Dados medidos:
- Largura: ${draft.widthMm.toStringAsFixed(3)} mm
- Altura: ${draft.heightMm.toStringAsFixed(3)} mm
- Perimetro: ${draft.perimeterMm.toStringAsFixed(3)} mm
- Altura: ${draft.areaMm2.toStringAsFixed(3)} mm2
- Escala estimada: ${draft.scaleMicronsPerPx?.toStringAsFixed(3) ?? 'n/a'} micrometros/px
- Segmentos:\n$segments

Estruture a resposta em 3 partes com titulos:
1) Resumo da medicao
2) Analise tecnica
3) Recomendacoes de processo

Regras obrigatorias:
- Use apenas Markdown simples com titulos `##` e listas com `-`.
- Nao repita a lista completa de medidas brutas na resposta.
- Cite valores numericos apenas quando forem importantes para a conclusao.
- Nao recrie uma secao de "dados medidos", "medidas coletadas" ou equivalente.
- Mantenha cada secao curta, com no maximo 3 bullets.
- Evite introducoes, conclusoes genericas e frases de preenchimento.
- No resumo, mencione a data da inspecao e o numero da peca do dia quando disponiveis.
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
    final numeroPeca = draft.pieceNumberOfDay != null
        ? draft.pieceNumberOfDay.toString()
        : 'n/a';
    final infoExtra = draft.extraInfo ?? '-';
    final resumoRapido = draft.quickStatus ?? 'n/a';
    final segmentosResumo = draft.segments.isEmpty
        ? 'Nenhum segmento classificado.'
        : '${draft.segments.length} segmento(s) identificado(s).';

    return '''
## Resumo da medicao
- Peca: $pieceName
- Data: $data
- Peca do dia: $numeroPeca
- Status: $resumoRapido

## Analise tecnica
- Medida principal: ${draft.primaryValueMm.toStringAsFixed(3)} mm
- Informacoes extras: $infoExtra
- Segmentos: $segmentosResumo

## Recomendacoes de processo
- Validar visualmente a imagem processada antes de aprovar a peca.
- Repetir a captura se houver duvida de calibracao ou contorno.
- Observacao: relatorio sintetico gerado em modo fallback ($reason) as $hora.
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
            r'^[-*]\s*(largura|altura|per[ií]metro|area|área|escala estimada|segmentos medidos|medidas coletadas|dados medidos)\s*:.*(?:\n|$)',
            multiLine: true,
            caseSensitive: false,
          ),
          (_) => '',
        )
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
## Resumo da medicao
$text
'''
          .trim();
    }

    return text;
  }
}
