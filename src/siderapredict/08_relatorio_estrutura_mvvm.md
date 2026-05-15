# Documento 08 - Relatório de Estrutura do Projeto com Foco em MVVM

## Objetivo

Este relatório apresenta a estrutura do projeto **Sidera Predict** com foco na arquitetura **MVVM (Model-View-ViewModel)**. O objetivo é servir como material de estudo e apoio para apresentação ao professor, explicando como as responsabilidades foram separadas dentro da aplicação Flutter.

## Visão Geral do Projeto

O **Sidera Predict** é um aplicativo mobile desenvolvido em **Flutter** para inspeção dimensional de peças industriais. A aplicação usa:

- **Firebase Auth** para autenticação.
- **Cloud Firestore** para persistência do histórico.
- **OpenCV em C++ via FFI** para processamento de imagem.
- **Ollama** para geração de relatórios técnicos por IA.
- **Provider + ChangeNotifier** para gerenciamento de estado.

O fluxo principal da aplicação é:

1. Splash.
2. Login ou cadastro.
3. Menu principal.
4. Captura da imagem da peça.
5. Processamento da imagem.
6. Validação da medição.
7. Salvamento no histórico.
8. Exportação ou consulta posterior.

## Estrutura do Projeto

A organização principal está dentro da pasta `lib/app/`:

```text
lib/
  main.dart
  app/
    config/
    core/
      services/
      theme/
      utils/
      viewmodel/
      widgets/
    features/
      auth/
        view/
        viewmodel/
      inspection/
        data/
        model/
        view/
        viewmodel/
      menu/
        view/
        viewmodel/
      reports/
        view/
        viewmodel/
      settings/
        view/
        viewmodel/
      splash/
        view/
        viewmodel/
    routes/
```

## Papel de Cada Camada

### `main.dart`

É o ponto de entrada da aplicação. Faz a inicialização de:

- Firebase
- `.env`
- câmeras do dispositivo
- preferências locais

Depois disso, chama `SideraPredictApp`, em [lib/main.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/main.dart).

### `app/sidera_predict_app.dart`

Essa classe monta a aplicação e injeta os ViewModels globais com `Provider`. Nela aparecem:

- `InspectionViewModel`
- `SettingsViewModel`
- `AuthViewModel`

Além disso, o método `_buildViewModel` monta dependências importantes como:

- `MeasurementService`
- `MeasurementRepository`
- `FirestoreService`
- `OllamaReportService`
- `ReportExportService`

Isso mostra que a aplicação usa **injeção de dependência manual**, o que ajuda na separação de responsabilidades e na testabilidade.

## Como o MVVM aparece no projeto

### Conceito

No padrão **MVVM**:

- **Model** representa os dados e regras do domínio.
- **View** representa a interface visual.
- **ViewModel** faz a ponte entre tela e lógica, expondo estado e ações.

No projeto, essa separação é bem visível.

### 1. Model

Os modelos concentram os dados da aplicação.

Exemplo principal:

- [lib/app/features/inspection/model/measurement_record.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/model/measurement_record.dart)

Esse arquivo define:

- `MeasurementDraft`
- `MeasurementRecord`
- enums de status e tipos de medição
- serialização para persistência

Ou seja, o Model descreve o que é uma medição, seus atributos e seu formato de armazenamento.

### 2. View

As Views ficam nas pastas `view/` de cada feature.

Exemplos:

- [lib/app/features/auth/view/login_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/auth/view/login_page.dart)
- [lib/app/features/inspection/view/scanner_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/view/scanner_page.dart)
- [lib/app/features/inspection/view/processing_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/view/processing_page.dart)
- [lib/app/features/inspection/view/validation_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/view/validation_page.dart)
- [lib/app/features/reports/view/history_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/reports/view/history_page.dart)

Essas telas usam `context.watch<ViewModel>()` para observar estado, em vez de implementar a lógica diretamente.

Exemplo claro: a `LoginPage` lê o `LoginViewModel` e apenas liga os widgets aos controladores, validadores e ações do ViewModel.

### 3. ViewModel

Os ViewModels ficam nas pastas `viewmodel/` e normalmente herdam de `ChangeNotifier`.

Exemplos:

- `AuthViewModel`
- `LoginViewModel`
- `SignupViewModel`
- `SplashViewModel`
- `MainMenuViewModel`
- `ScannerViewModel`
- `ProcessingViewModel`
- `ValidationViewModel`
- `InspectionViewModel`
- `HistoryViewModel`
- `SettingsViewModel`

Esses ViewModels concentram:

- estado da tela
- regras de interação
- validações
- chamadas para serviços e repositórios
- notificações de atualização com `notifyListeners()`

## Exemplo prático do MVVM no projeto

### Caso 1: Login

#### View

A tela [login_page.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/auth/view/login_page.dart) apenas:

- monta os campos de entrada
- liga botões ao ViewModel
- mostra indicador de carregamento com base no estado

#### ViewModel

No login existem dois níveis:

- [login_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/auth/viewmodel/login_view_model.dart), mais próximo da tela
- [auth_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/auth/viewmodel/auth_view_model.dart), mais global

O `LoginViewModel` concentra:

- `formKey`
- controladores dos campos
- validações
- ação do botão

Já o `AuthViewModel` concentra:

- `isLoading`
- `errorMessage`
- `userName`
- métodos `login`, `signUp`, `logout`

Ele conversa com:

- [lib/app/core/services/auth_service.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/core/services/auth_service.dart)

#### Service

O `AuthService` faz a comunicação real com o Firebase Auth e Firestore.

Resumo do fluxo:

1. A View captura o clique.
2. O `LoginViewModel` valida os campos e delega para o `AuthViewModel`.
3. O `AuthViewModel` chama o serviço.
4. O serviço acessa Firebase.
5. O ViewModel atualiza estado.
6. A View reage automaticamente.

### Caso 2: Inspeção e medição

Esse é o melhor exemplo da arquitetura do projeto.

#### ViewModel central

O [inspection_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/viewmodel/inspection_view_model.dart) funciona como o núcleo da feature de inspeção.

Ele controla:

- `currentDraft`
- `history`
- `isProcessing`
- `isSaving`
- `isLoadingHistory`
- `lastError`

Também expõe operações como:

- `processCapturedImage`
- `saveCurrentDraft`
- `loadHistory`
- `exportHistoryPdf`
- `deleteRecordById`

#### Service de processamento

O [measurement_service.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/core/services/measurement_service.dart) recebe o resultado bruto da ponte nativa (`NativeVisionBridge`) e transforma isso em um `MeasurementDraft`.

Em outras palavras:

- o código nativo processa a imagem
- o service converte o payload em objeto de domínio
- o ViewModel usa esse objeto para atualizar a aplicação

#### Repository

O [measurement_repository.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/data/measurement_repository.dart) centraliza acesso a dados e integra:

- cache local
- Firestore
- exportação
- geração de relatório por IA

Isso é importante porque evita que o ViewModel tenha lógica de infraestrutura demais.

## Organização das features em MVVM

O projeto está dividido por funcionalidade, o que é um ponto forte arquitetural:

- `auth/`: autenticação
- `inspection/`: captura, processamento, validação e histórico de medição
- `menu/`: navegação principal
- `reports/`: consulta e exportação
- `settings/`: preferências
- `splash/`: decisão inicial de navegação

Essa divisão por feature melhora:

- manutenção
- escalabilidade
- localização de código
- separação de responsabilidades

## Como as rotas reforçam o MVVM

O [app_router.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/routes/app_router.dart) cria o ViewModel certo para cada tela.

Exemplo:

- `LoginPage` recebe `LoginViewModel`
- `ProcessingPage` recebe `ProcessingViewModel`
- `ValidationPage` recebe `ValidationViewModel`
- `HistoryPage` recebe `HistoryViewModel`

Isso é importante porque cada tela passa a ter um estado próprio e uma lógica própria.

## Papel dos Services no desenho arquitetural

Os services representam a camada de integração técnica.

Exemplos:

- `AuthService`: autenticação e leitura de usuário
- `FirestoreService`: persistência no banco
- `MeasurementService`: processamento de imagem
- `SettingsService`: preferências locais
- `ReportExportService`: exportação de PDF/Excel
- `OllamaReportService`: geração de relatório por IA

No projeto, os services não são a camada visual nem a camada de domínio da tela. Eles prestam suporte ao ViewModel.

## Pontos fortes do MVVM no projeto

### 1. Separação clara entre tela e lógica

As Pages ficam majoritariamente focadas em:

- layout
- widgets
- ligação com ações do ViewModel

As regras ficam nos ViewModels.

### 2. Testabilidade

Os testes mostram bem essa vantagem.

Exemplos:

- [test/viewmodel/inspection_view_model_test.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/test/viewmodel/inspection_view_model_test.dart)
- [test/viewmodel/secondary_view_models_test.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/test/viewmodel/secondary_view_models_test.dart)
- [test/viewmodel/splash_view_model_test.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/test/viewmodel/splash_view_model_test.dart)

Os testes conseguem validar:

- processamento
- salvamento
- mensagens de erro
- validação de conformidade
- regras de tema
- navegação inicial

Isso funciona bem porque a lógica está concentrada nos ViewModels e serviços falsos podem ser usados nos testes.

### 3. Reuso de estado

O `InspectionViewModel` é compartilhado entre várias telas da inspeção. Isso permite que o fluxo de captura, processamento, validação e histórico mantenha continuidade de estado.

### 4. Separação entre dado e infraestrutura

O Model representa os dados.
O Repository e os Services lidam com persistência, IA, exportação e processamento.
O ViewModel orquestra isso para a View.

## Ponto importante para comentar ao professor

O projeto segue **MVVM de forma prática**, mas **não é MVVM puro em sentido acadêmico**.

### Por quê?

Alguns ViewModels ainda recebem `BuildContext` e executam ações diretamente ligadas à interface, como:

- navegação com `Navigator`
- `SnackBar`
- `showDialog`
- `showModalBottomSheet`

Exemplos disso aparecem em:

- [lib/app/features/auth/viewmodel/login_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/auth/viewmodel/login_view_model.dart)
- [lib/app/features/settings/viewmodel/settings_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/settings/viewmodel/settings_view_model.dart)
- [lib/app/features/inspection/viewmodel/validation_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/inspection/viewmodel/validation_view_model.dart)
- [lib/app/features/reports/viewmodel/history_view_model.dart](/home/joao/development/projetos/pi-2026.1/src/siderapredict/lib/app/features/reports/viewmodel/history_view_model.dart)

### Como explicar isso bem

Uma forma segura de apresentar é dizer:

> O projeto usa MVVM como base principal para separar interface, estado e lógica de negócio. Porém, em alguns pontos adota uma abordagem pragmática, deixando navegação e feedback visual dentro de certos ViewModels para simplificar o fluxo das telas.

Essa explicação é tecnicamente honesta e mostra maturidade arquitetural.

## Exemplo de fluxo completo para apresentar

Um fluxo muito bom para explicar em sala é o da medição:

1. `ScannerPage` mostra a câmera.
2. `ScannerViewModel` controla captura, flash e nível.
3. Após capturar, a rota vai para `ProcessingPage`.
4. `ProcessingViewModel` manda o `InspectionViewModel` processar a imagem.
5. `InspectionViewModel` chama `MeasurementService`.
6. `MeasurementService` usa a ponte nativa do OpenCV.
7. O resultado vira `MeasurementDraft`.
8. `ValidationPage` exibe os dados.
9. `ValidationViewModel` coleta nome da peça e conformidade.
10. `InspectionViewModel` salva usando `MeasurementRepository`.
11. O repositório persiste localmente, sincroniza com Firestore e dispara geração de relatório por IA.

Esse fluxo mostra muito bem as responsabilidades de cada camada.

## Resumo da Arquitetura

Em termos simples:

- **View**: mostra a tela.
- **ViewModel**: controla estado e comportamento da tela.
- **Model**: representa os dados.
- **Service/Repository**: integra com Firebase, OpenCV, exportação e IA.

## Conclusão

O projeto possui uma estrutura organizada, modular e coerente com o padrão MVVM. A arquitetura adotada facilita manutenção, testes e evolução da aplicação. O uso de `Provider` com `ChangeNotifier`, aliado à divisão por features, torna o código compreensível e bem distribuído.

O ponto mais forte para destacar ao professor é que:

- a lógica principal não está nas telas;
- os ViewModels concentram estado e comportamento;
- os Models representam o domínio;
- os Services e Repositories isolam integração e persistência.

Ao mesmo tempo, vale mostrar maturidade ao reconhecer que a implementação é um **MVVM prático**, com alguns elementos de navegação e feedback visual ainda presentes em ViewModels.

## Perguntas prováveis do professor

### 1. Onde está o MVVM no projeto?

Resposta curta:

> O MVVM aparece na separação entre as `Pages`, que cuidam da interface, os `ViewModels`, que controlam estado e fluxo, e os `Models`, que representam os dados. A integração com Firebase, OpenCV e exportação fica em services e repository.

### 2. Por que usar `Provider` com `ChangeNotifier`?

Resposta curta:

> Porque é uma forma simples e eficaz de expor estado reativo para as telas. Quando o ViewModel muda, ele chama `notifyListeners()` e a View é reconstruída automaticamente.

### 3. Qual é o ViewModel mais importante do sistema?

Resposta curta:

> O `InspectionViewModel`, porque ele centraliza o fluxo principal da aplicação: processamento da imagem, armazenamento do rascunho, histórico, exportação e salvamento.

### 4. O projeto segue MVVM puro?

Resposta curta:

> Não totalmente. A base é MVVM, mas alguns ViewModels ainda fazem navegação e exibem mensagens visuais. Então a arquitetura é melhor descrita como um MVVM prático.

### 5. Qual a vantagem prática dessa arquitetura?

Resposta curta:

> A lógica fica fora das telas, o sistema fica mais testável e a manutenção melhora porque cada camada tem uma responsabilidade mais clara.

## Resposta curta para falar em apresentação

Se você quiser explicar oralmente de forma resumida, pode usar algo próximo disso:

> O projeto foi organizado em Flutter usando MVVM com Provider. As Views ficam responsáveis pela interface, os ViewModels controlam estado, validação e fluxo, os Models representam as medições e entidades do sistema, e os Services/Repositories fazem integração com Firebase, OpenCV, cache local, exportação e IA. Isso deixa o projeto mais modular, testável e fácil de manter.
