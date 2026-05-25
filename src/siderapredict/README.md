# Sidera Predict

Aplicativo mobile Flutter para inspeção dimensional de peças usando câmera,
visão computacional com OpenCV em C++ via FFI, histórico em Supabase e geração
de relatórios técnicos com IA via Ollama.

## Funcionalidades

- Autenticação com Supabase Auth.
- Cadastro e login por e-mail ou matrícula.
- Captura de imagem pela câmera do dispositivo.
- Overlay de enquadramento e nível durante a captura.
- Processamento nativo com OpenCV para calibração, retificação e medição.
- Validação da medição pelo operador com status conforme/não conforme.
- Histórico persistido em Supabase com cache local.
- Relatório técnico por IA usando endpoint Ollama.
- Exportação de registros individuais ou histórico consolidado em PDF e Excel.
- Tema claro, tema escuro e modo de alto contraste.

## Fluxo principal

1. Splash.
2. Login ou cadastro.
3. Menu principal.
4. Nova medição.
5. Captura pela câmera.
6. Processamento da imagem.
7. Validação da peça e informações do operador.
8. Salvamento no histórico.
9. Exportação ou consulta posterior.

## Validação com o público

O projeto foi validado com o público da empresa Soufer em uma reunião via
Google Meet com o gerente de inspeção de qualidade. Nessa validação, foram
realizados diversos testes e cenários de uso, reforçando a aderência da
solução ao contexto real de aplicação.

## Stack

- Flutter / Dart.
- Provider para estado e injeção de dependências.
- Supabase Flutter, Supabase Auth, Postgres e Realtime.
- OpenCV Android SDK integrado ao build Android.
- C++ nativo com CMake para o motor de visão.
- Ollama API para resumo técnico.
- `pdf`, `excel` e `flutter_file_dialog` para exportação.
- `shared_preferences` para preferências de tema.

## Estrutura do projeto

```text
lib/
  app/
    config/              Configuração via .env
    core/
      services/          Supabase, Ollama, medição, exportação e preferências
      theme/             Temas e identidade visual
      utils/             Utilitários da aplicação
      widgets/           Componentes compartilhados
    features/
      auth/              Login, cadastro e viewmodels de autenticação
      inspection/        Captura, análise, validação e modelo de medição
      menu/              Menu principal
      reports/           Histórico e exportações
      settings/          Configurações de aparência e conta
      splash/            Tela inicial e redirecionamento
    routes/              Rotas e argumentos de navegação
native_lib/              Código C++ do motor de visão e CMake
OpenCV-android-sdk/      SDK Android do OpenCV usado pelo build
android/                 Projeto Android Flutter/Gradle
assets/                  Ícones e imagens da marca
```

## Requisitos

- Flutter compatível com Dart `^3.11.3`.
- Android SDK e NDK configurados.
- Java 17.
- Projeto Supabase configurado.
- OpenCV Android SDK disponível em `OpenCV-android-sdk/` ou via variável
  `OpenCV_DIR`.
- Um endpoint Ollama acessível publicamente por HTTPS, se a geração de relatório
  por IA for usada.

## Configuração

A aplicação carrega configurações do arquivo `.env` na raiz do projeto. Crie o
arquivo com as chaves abaixo:

```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua-chave-anon
SUPABASE_MEASUREMENTS_TABLE=measurement_records
SUPABASE_IMAGES_BUCKET=measurement-images
OLLAMA_BASE_URL=https://seu-endpoint-ollama.example.com
OLLAMA_MODEL=llama3.1
```

Observações:

- `SUPABASE_URL` e `SUPABASE_ANON_KEY` conectam o app ao projeto Supabase.
- `SUPABASE_MEASUREMENTS_TABLE` deve existir no `.env` e apontar para a
  tabela criada no script SQL.
- `SUPABASE_IMAGES_BUCKET` deve existir no `.env` e apontar para o bucket
  criado no script SQL.
- `OLLAMA_BASE_URL` deve ser uma URL pública HTTPS.
- Para o Ollama, URLs com `localhost`, IP interno, rede local ou HTTP simples
  são recusadas pela validação da aplicação.
- `OLLAMA_MODEL` deve existir no servidor Ollama configurado.
- Se alguma configuração estiver ausente ou inválida, o app falha na
  inicialização com erro explícito.

## Supabase

O projeto usa Supabase Auth para login/cadastro e Postgres para persistência do
histórico. Antes de executar o app contra um projeto novo, rode o script:

```text
supabase/schema.sql
```

Esse script cria:

- `profiles`: perfil do usuário, e-mail e matrícula.
- `measurement_records`: histórico de medições por usuário.
- bucket privado `measurement-images`: fotos das medições no Storage.
- RPCs `email_for_matricula`, `is_matricula_available` e
  `is_email_available`.
- Políticas RLS/Storage para cada usuário acessar apenas seus próprios
  registros e imagens.

O login por matrícula consulta o e-mail via RPC e depois autentica normalmente
pelo Supabase Auth.

Durante a geração do relatório por IA, o app mostra o texto em streaming apenas
em memória/localmente. O Supabase recebe o registro uma única vez, depois que o
relatório termina e as imagens são enviadas ao Storage.

## OpenCV e motor nativo

O build Android compila a biblioteca `vision_engine` a partir de `native_lib/`.
O CMake procura o OpenCV nesta ordem:

1. Variável de ambiente `OpenCV_DIR`.
2. Caminho local `OpenCV-android-sdk/sdk/native/jni`.

Se o SDK não estiver presente, adicione-o no caminho esperado ou exporte
`OpenCV_DIR` antes do build.

A calibração usa marcadores ArUco/ChArUco no campo de visão. O motor nativo
considera marcadores de 11 mm para calcular a escala da imagem.

## Como executar

Instale as dependências:

```bash
flutter pub get
```

Execute em um dispositivo ou emulador Android:

```bash
flutter run
```

Executar análise estática:

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

## Exportação

A tela de histórico permite exportar:

- PDF individual da medição.
- Excel individual da medição.
- PDF consolidado do histórico.
- Excel consolidado do histórico.

Os arquivos são montados em diretório temporário e salvos pelo seletor nativo do
Android.

## Medidas geradas

O modelo de medição armazena:

- Imagem original e imagem processada.
- Sucesso da calibração e detecção do objeto.
- Largura, altura, perímetro e área.
- Escala em micrômetros por pixel, quando disponível.
- Segmentos identificados, como arestas, furos, semicírculos, chanfros,
  diâmetros, slots, espaçamentos e ângulos.
- Status de conformidade informado pelo operador.
- Relatório técnico gerado por IA ou fallback local.

## Notas de desenvolvimento

- A orientação da aplicação é bloqueada em retrato.
- O histórico usa Supabase com cache local em arquivo JSON.
- As fotos ficam no Supabase Storage; o banco guarda apenas caminhos e payload
  final otimizado, sem base64.
- Preferências de tema ficam em `SharedPreferences`.
- A exportação usa `assets/soufer.png` como logo no PDF.
- O pacote Android é `br.com.siderapredict.siderapredict`.
