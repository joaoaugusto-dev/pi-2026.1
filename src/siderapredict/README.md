# Sidera Predict MVP

MVP mobile em Flutter para medicao dimensional com OpenCV (C++ via FFI), historico em Firestore via REST, geracao de relatorio por IA local (Ollama) e exportacao em PDF + Excel.

## Fluxo de telas implementado

1. Splash Screen (2s)
2. Home (`NOVA MEDICAO` e `HISTORICO`)
3. Camera (preview com overlay de nivel e enquadramento do board ChArUco)
4. Processamento (spinner)
5. Validacao (imagem, valor principal e lista de medidas)
6. Historico (lista com data/hora/valor e exportacao)

## Backend de medicao

- Escala metrica calibrada por board **ChArUco 18x12** com quadrados de **15 mm** e marcadores internos de **11 mm**.
- Retificacao de perspectiva e deteccao de contorno da peca.
- Classificacao de segmentos em:
	- Aresta
	- Semicirculo
	- Furo
- Saida auxiliar em JSON com arestas, raios, area, perimetro e escala em um/px.

## Configuracao (sem Firebase CLI)

Use `--dart-define` para configurar Firestore REST e Ollama:

```bash
flutter run \
	--dart-define=FIRESTORE_PROJECT_ID=seu-projeto \
	--dart-define=FIRESTORE_API_KEY=sua-api-key \
	--dart-define=FIRESTORE_COLLECTION=measurementHistory \
	--dart-define=OLLAMA_BASE_URL=http://10.0.2.2:11434 \
	--dart-define=OLLAMA_MODEL=llama3.1
```

Observacoes:
- Em emulador Android, `10.0.2.2` aponta para localhost da maquina host.
- Se Firestore nao estiver configurado, o app usa cache local para historico.

## Exportacao

- PDF consolidado com tabela e resumo tecnico.
- Excel (`.xlsx`) com abas de Historico e Resumo.

Os arquivos sao gerados em pasta de documentos do app e compartilhados via acao de exportacao na tela de Historico.

## Build validado

- `flutter analyze` sem issues.
- `flutter build apk --debug --no-pub` concluido com sucesso.
