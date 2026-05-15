# Sidera Predict

Aplicativo mobile Flutter para inspecao dimensional de pecas usando camera,
visao computacional com OpenCV em C++ via FFI, historico em Supabase e geracao
de relatorios tecnicos com IA via Ollama.

## Funcionalidades

- Autenticacao com Supabase Auth.
- Cadastro e login por e-mail ou matricula.
- Captura de imagem pela camera do dispositivo.
- Overlay de enquadramento e nivel durante a captura.
- Processamento nativo com OpenCV para calibracao, retificacao e medicao.
- Validacao da medicao pelo operador com status conforme/nao conforme.
- Historico persistido em Supabase com cache local.
- Relatorio tecnico por IA usando endpoint Ollama.
- Exportacao de registros individuais ou historico consolidado em PDF e Excel.
- Tema claro, tema escuro e modo de alto contraste.

## Fluxo principal

1. Splash.
2. Login ou cadastro.
3. Menu principal.
4. Nova medicao.
5. Captura pela camera.
6. Processamento da imagem.
7. Validacao da peca e informacoes do operador.
8. Salvamento no historico.
9. Exportacao ou consulta posterior.

## Stack

- Flutter / Dart.
- Provider para estado e injecao de dependencias.
- Supabase Flutter, Supabase Auth, Postgres e Realtime.
- OpenCV Android SDK integrado ao build Android.
- C++ nativo com CMake para o motor de visao.
- Ollama API para resumo tecnico.
- `pdf`, `excel` e `flutter_file_dialog` para exportacao.
- `shared_preferences` para preferencias de tema.

## Estrutura do projeto

```text
lib/
  app/
    config/              Configuracao via .env
    core/
      services/          Supabase, Ollama, medicao, exportacao e preferencias
      theme/             Temas e identidade visual
      utils/             Utilitarios da aplicacao
      widgets/           Componentes compartilhados
    features/
      auth/              Login, cadastro e viewmodels de autenticacao
      inspection/        Captura, analise, validacao e modelo de medicao
      menu/              Menu principal
      reports/           Historico e exportacoes
      settings/          Configuracoes de aparencia e conta
      splash/            Tela inicial e redirecionamento
    routes/              Rotas e argumentos de navegacao
native_lib/              Codigo C++ do motor de visao e CMake
OpenCV-android-sdk/      SDK Android do OpenCV usado pelo build
android/                 Projeto Android Flutter/Gradle
assets/                  Icones e imagens da marca
```

## Requisitos

- Flutter compativel com Dart `^3.11.3`.
- Android SDK e NDK configurados.
- Java 17.
- Projeto Supabase configurado.
- OpenCV Android SDK disponivel em `OpenCV-android-sdk/` ou via variavel
  `OpenCV_DIR`.
- Um endpoint Ollama acessivel publicamente por HTTPS, se a geracao de relatorio
  por IA for usada.

## Configuracao

A aplicacao carrega configuracoes do arquivo `.env` na raiz do projeto. Crie o
arquivo com as chaves abaixo:

```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-chave-anon
SUPABASE_MEASUREMENTS_TABLE=measurement_records
SUPABASE_IMAGES_BUCKET=measurement-images
OLLAMA_BASE_URL=https://seu-endpoint-ollama.example.com
OLLAMA_MODEL=llama3.1
```

Observacoes:

- `SUPABASE_URL` e `SUPABASE_ANON_KEY` conectam o app ao projeto Supabase.
- `SUPABASE_MEASUREMENTS_TABLE` deve existir no `.env` e apontar para a
  tabela criada no script SQL.
- `SUPABASE_IMAGES_BUCKET` deve existir no `.env` e apontar para o bucket
  criado no script SQL.
- `OLLAMA_BASE_URL` deve ser uma URL publica HTTPS.
- Para o Ollama, URLs com `localhost`, IP interno, rede local ou HTTP simples
  sao recusadas pela validacao da aplicacao.
- `OLLAMA_MODEL` deve existir no servidor Ollama configurado.
- Se alguma configuracao estiver ausente ou invalida, o app falha na
  inicializacao com erro explicito.

## Supabase

O projeto usa Supabase Auth para login/cadastro e Postgres para persistencia do
historico. Antes de executar o app contra um projeto novo, rode o script:

```text
supabase/schema.sql
```

Esse script cria:

- `profiles`: perfil do usuario, e-mail e matricula.
- `measurement_records`: historico de medicoes por usuario.
- bucket privado `measurement-images`: fotos das medicoes no Storage.
- RPCs `email_for_matricula`, `is_matricula_available` e
  `is_email_available`.
- Politicas RLS/Storage para cada usuario acessar apenas seus proprios
  registros e imagens.

O login por matricula consulta o e-mail via RPC e depois autentica normalmente
pelo Supabase Auth.

Durante a geracao do relatorio por IA, o app mostra o texto em streaming apenas
em memoria/localmente. O Supabase recebe o registro uma unica vez, depois que o
relatorio termina e as imagens sao enviadas ao Storage.

## OpenCV e motor nativo

O build Android compila a biblioteca `vision_engine` a partir de `native_lib/`.
O CMake procura o OpenCV nesta ordem:

1. Variavel de ambiente `OpenCV_DIR`.
2. Caminho local `OpenCV-android-sdk/sdk/native/jni`.

Se o SDK nao estiver presente, adicione-o no caminho esperado ou exporte
`OpenCV_DIR` antes do build.

A calibracao usa marcadores ArUco/ChArUco no campo de visao. O motor nativo
considera marcadores de 11 mm para calcular a escala da imagem.

## Como executar

Instale as dependencias:

```bash
flutter pub get
```

Execute em um dispositivo ou emulador Android:

```bash
flutter run
```

Rodar analise estatica:

```bash
flutter analyze
```

Gerar APK debug:

```bash
flutter build apk --debug
```

Gerar APK release:

```bash
flutter build apk --release
```

## Exportacao

A tela de historico permite exportar:

- PDF individual da medicao.
- Excel individual da medicao.
- PDF consolidado do historico.
- Excel consolidado do historico.

Os arquivos sao montados em diretorio temporario e salvos pelo seletor nativo do
Android.

## Medidas geradas

O modelo de medicao armazena:

- Imagem original e imagem processada.
- Sucesso da calibracao e deteccao do objeto.
- Largura, altura, perimetro e area.
- Escala em micrometros por pixel, quando disponivel.
- Segmentos identificados, como arestas, furos, semicirculos, chanfros,
  diametros, slots, espacamentos e angulos.
- Status de conformidade informado pelo operador.
- Relatorio tecnico gerado por IA ou fallback local.

## Notas de desenvolvimento

- A orientacao da aplicacao e bloqueada em retrato.
- O historico usa Supabase com cache local em arquivo JSON.
- As fotos ficam no Supabase Storage; o banco guarda apenas caminhos e payload
  final otimizado, sem base64.
- Preferencias de tema ficam em `SharedPreferences`.
- A exportacao usa `assets/soufer.png` como logo no PDF.
- O pacote Android e `br.com.siderapredict.siderapredict`.
