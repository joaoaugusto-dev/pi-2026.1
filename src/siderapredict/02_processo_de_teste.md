# Documento 02 - Processo de Teste

**Projeto:** SideraPredict  
**Tecnologia:** Flutter  
**Arquitetura:** MVVM  
**Norma base:** ISO/IEC/IEEE 29119-2

## 1. Planejamento de Teste

## 1.1 Estratégia

Serão utilizados:
- Testes de unidade para ViewModels.
- Testes de unidade para modelos.
- Testes de unidade para serviços puros.
- Testes de componente para widgets reutilizáveis.
- Fakes para AuthService, MeasurementService, MeasurementRepository e NativeVisionBridge.

Não serão utilizados:
- Backend real.
- Firebase real.
- Câmera real.
- OpenCV real.
- Teste visual pixel a pixel.

## 1.2 Ambiente

- Flutter SDK.
- Dart SDK.
- `flutter_test`.
- `shared_preferences` com mock local.
- Execução por `flutter test`.

## 1.3 Critérios de Entrada

- Refatoração MVVM aplicada.
- Arquivos renomeados e imports ajustados.
- ViewModels responsáveis por ações e decisões.
- Dependências externas substituíveis por fakes.
- Casos TC01 a TC30 definidos.

## 1.4 Critérios de Saída

- Todos os testes automatizados executados.
- Falhas registradas.
- Relatório final produzido.
- `flutter test` sem falhas.

## 2. Monitoramento e Controle

Total planejado: 32 casos.  
Executados: 32 casos.  
Aprovados: 32 casos.  
Reprovados: 0 casos.

## 3. Análise de Teste

As condições de teste foram derivadas dos fluxos principais do app e dos pontos de risco da arquitetura MVVM:
- Autenticação e cadastro.
- Saída da splash.
- Processamento e persistência de medições.
- Histórico e exportação lógica.
- Validação de conformidade.
- Configurações visuais.
- Widgets compartilhados.

## 4. Projeto de Teste

Cada condição CT foi transformada em um caso TC correspondente, mantendo nomes explícitos nos arquivos de teste para facilitar rastreabilidade.

## 5. Ordem de Execução

1. Executar testes de modelos.
2. Executar testes de serviços.
3. Executar testes de ViewModels.
4. Executar testes de widgets.
5. Registrar resultados.
6. Atualizar relatório.

## 6. Implementação

Arquivos principais:
- `test/helpers/sidera_test_fakes.dart`
- `test/model/measurement_record_test.dart`
- `test/service/measurement_service_test.dart`
- `test/viewmodel/auth_view_model_test.dart`
- `test/viewmodel/login_signup_view_model_test.dart`
- `test/viewmodel/splash_view_model_test.dart`
- `test/viewmodel/inspection_view_model_test.dart`
- `test/viewmodel/secondary_view_models_test.dart`
- `test/widget/core_widgets_test.dart`

## 7. Execução

Comando:

```bash
flutter test
```
