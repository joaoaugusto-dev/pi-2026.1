# Inspector AI - Flutter + Ollama + OpenCV ArUco

Aplicativo para validacao dimensional guiada por IA:

1. A primeira foto obrigatoria e do desenho tecnico.
2. O modelo `qwen2.5vl:3b` (via Ollama) gera o roteiro de validacao em etapas.
3. O app pede uma etapa por tela, orientando o angulo/vista da foto real da peca.
4. O Android nativo (OpenCV) mede com ArUco e compara com as cotas esperadas.

## Arquitetura

- Flutter UI: fluxo de captura, validacao e relatorio final.
- Ollama Service: analisa o desenho tecnico e retorna JSON estrito com etapas.
- OpenCV Native Bridge (Kotlin):
	- `aruco_2d`: mede em mm com escala por ArUco (23 mm).
	- `angle_profile`: mede angulo de dobra em foto de perfil.

## Requisitos

- Flutter SDK instalado.
- Android Studio/SDK e JDK 17 ou 21.
- Servidor Ollama acessivel pela rede do celular.
- Modelo carregado no Ollama:

```bash
ollama pull qwen2.5vl:3b
```

## Configuracao do Ollama

No servidor Ubuntu, exponha o Ollama na rede local e garanta firewall liberado para `11434`.

Exemplo de URL no app:

```text
http://192.168.0.10:11434
```

## Como rodar

```bash
flutter pub get
flutter run
```

## Fluxo de uso no app

1. Capture a foto do desenho tecnico.
2. Gere o roteiro de validacao com IA.
3. Siga as etapas uma por vez (cada etapa pede foto especifica).
4. O app mede e aprova/reprova cada etapa com tolerancia.
5. Veja o relatorio final com status geral.

## Observacoes de precisao

- Em `aruco_2d`, os 4 ArUco devem estar totalmente visiveis.
- Para dobra/angulo, fotografe o perfil da peca conforme a instrucao da etapa.
- Iluminacao uniforme reduz erro de segmentacao (contorno/linhas).
