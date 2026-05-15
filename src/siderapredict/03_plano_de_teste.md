# Documento 03 - Plano de Teste

**Projeto:** SideraPredict  
**Norma:** ISO/IEC/IEEE 29119-3  
**Tipo:** Teste funcional automatizado

## 1. Objetivo

Definir a abordagem, os recursos e a estratégia para executar os testes do app após a aplicação estrita de MVVM e a reorganização dos nomes dos arquivos.

## 2. Escopo

Serão testadas as funcionalidades:
- Login.
- Splash.
- Cadastro.
- Validação de campos.
- Processamento de medição.
- Salvamento de medição.
- Histórico.
- Validação OK/NOK.
- Configurações de tema.
- Widgets reutilizáveis.

Não serão testadas:
- Integração real com Firebase.
- Execução real de câmera.
- Execução real de OpenCV nativo.
- Integração real com Ollama.
- Performance.
- Segurança.

## 3. Itens de Teste

- AuthViewModel.
- SplashViewModel.
- LoginViewModel.
- SignupViewModel.
- MeasurementService.
- MeasurementDraft.
- MeasurementRecord.
- InspectionViewModel.
- ProcessingViewModel.
- ValidationViewModel.
- HistoryViewModel.
- SettingsViewModel.
- AuthTextField.
- PasswordRequirementsWidget.
- PrimaryActionButton.

## 4. Estratégia de Teste

- Testes de unidade para ViewModels.
- Testes de unidade para modelos e serviços.
- Testes de componente para widgets.
- Fakes para dependências externas.
- Sem backend real.
- Sem dispositivo físico.

## 5. Ambiente de Teste

- Flutter SDK.
- Dart SDK.
- `flutter test`.
- Sistema local de arquivos apenas para código e testes.

## 6. Critérios de Entrada

- Código compila.
- MVVM aplicado.
- Dependências externas isoladas.
- Casos de teste documentados.

## 7. Critérios de Saída

- Todos os casos TC01 a TC30 executados.
- Falhas corrigidas ou registradas.
- Registro de execução preenchido.
- Relatório final produzido.

## 8. Riscos

- Divergência entre mensagens esperadas e mensagens de UI.
- Dependências nativas não simuladas corretamente.
- Regressão em imports após renomeação de arquivos.
- Regras voltarem para Pages em mudanças futuras.
