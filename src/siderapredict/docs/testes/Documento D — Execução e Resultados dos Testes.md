# Documento D — Execução e Resultados dos Testes

Projeto: Sidera Predict  
Tecnologia: Flutter  
Arquitetura: MVVM com Provider  
Norma aplicada: ISO/IEC/IEEE 29119  
Tipo de teste:

- Unidade
- Integração lógica
- Integração de UI

## 1. Objetivo

Registrar a execução dos testes implementados no projeto Flutter, documentando os resultados obtidos, falhas encontradas e análise final do comportamento do sistema.

## 2. Ambiente de Execução

Ambiente utilizado:

- Flutter SDK
- Dart SDK
- flutter_test
- integration_test

Arquitetura:

- MVVM
- Provider
- FakeAuthService
- Models e ViewModels isolados

## 3. Estrutura dos Testes Executados

```
test/
fakes/
fake_auth_service.dart
fake_measurement_service.dart
fake_measurement_repository.dart
viewmodel/
auth_view_model_test.dart
processing_view_model_test.dart
validation_view_model_test.dart
integration/
fluxo_completo_test.dart

integration_test/
auth_flow_test.dart
full_inspection_flow_test.dart
```

## 4. Execução dos Testes

Testes unitários e integração lógica:

```bash
flutter test test/ --reporter expanded
```

Testes de integração de UI:

```bash
flutter test integration_test
```

Resultado da execução atual: o comando `flutter test integration_test` foi executado com dispositivo/emulador compatível e retornou 5 testes aprovados.

## 5. Resultados dos Testes Unitários

| Caso | Objetivo | Resultado Esperado | Resultado Obtido | Status |
|------|----------|--------------------|-------------------|--------|
| TC01 | Login com credenciais válidas | Login realizado | Login realizado | Aprovado |
| TC02 | Login com senha errada | Mensagem de erro | Mensagem exibida | Aprovado |
| TC03 | Login com usuário inexistente | Mensagem de erro | Mensagem exibida | Aprovado |
| TC04 | Estado de loading | Estado consistente | Estado consistente | Aprovado |
| TC05 | Cadastro válido | Cadastro realizado | Cadastro realizado | Aprovado |
| TC06 | Cadastro com e-mail duplicado | Bloqueio cadastro | Bloqueio realizado | Aprovado |
| TC07 | Cadastro com matrícula duplicada | Bloqueio cadastro | Bloqueio realizado | Aprovado |
| TC08 | Verificação de matrícula | true/false correto | true/false correto | Aprovado |
| TC09 | Verificação de e-mail | true/false correto | true/false correto | Aprovado |
| TC10 | IA na fila | pending | pending | Aprovado |
| TC11 | IA gerando | generating | generating | Aprovado |
| TC12 | IA concluída | completed | completed | Aprovado |
| TC13 | Falha na calibração ArUco | Mensagem de erro | Mensagem exibida | Aprovado |
| TC14 | Peça não encontrada | Mensagem de erro | Mensagem exibida | Aprovado |
| TC15 | Imagem nula | Mensagem padrão | Mensagem exibida | Aprovado |
| TC16 | Imagem nula com lastError | Mensagem personalizada | Mensagem exibida | Aprovado |
| TC17 | Draft válido | Medição válida | Medição válida | Aprovado |
| TC18 | Draft sem calibração | Medição inválida | Medição inválida | Aprovado |
| TC19 | Registro completo | Campos preenchidos | Campos preenchidos | Aprovado |
| TC20 | Draft sem peça | Medição inválida | Medição inválida | Aprovado |
| TC21 | Conformidade OK | Sem motivo de reprovação | Sem motivo de reprovação | Aprovado |
| TC22 | Conformidade NOK | Motivo registrado | Motivo registrado | Aprovado |
| TC23 | copyWith | Dados preservados | Dados preservados | Aprovado |
| TC24 | JSON ida e volta | Sem perda de dados | Sem perda de dados | Aprovado |
| TC25 | Cadastro → Login | Usuário autenticado | Usuário autenticado | Aprovado |
| TC26 | Login inválido → retry | Falha e depois sucesso | Falha e depois sucesso | Aprovado |
| TC27 | Cadastro duplicado → login original | Duplicado rejeitado | Duplicado rejeitado | Aprovado |
| TC28 | Ciclo de IA | pending → generating → completed | Ciclo validado | Aprovado |
| TC29 | Serialização de lista | Registros restaurados | Registros restaurados | Aprovado |

## 6. Simulação de Falha

Foi prevista uma simulação de falha alterando propositalmente o valor esperado de um teste de validação.

Objetivo da simulação:

- Demonstrar funcionamento do framework de teste
- Demonstrar diferença entre resultado esperado e obtido
- Demonstrar comportamento de falhas automatizadas

Resultado da simulação:

Esperado pelo teste:

```text
"Preencha os campos obrigatórios."
```

Resultado obtido:

```text
"Campo obrigatório"
```

Resultado do Teste:

```text
Reprovado
```

## 7. Análise dos Resultados

Os testes unitários e de integração lógica validaram corretamente:

- Regras de negócio
- Validações
- Mensagens
- Estados dos ViewModels
- Serialização dos Models
- Ciclo de estados da IA

## 8. Benefícios Observados

A arquitetura MVVM permitiu:

- Isolamento da lógica
- Facilidade de teste
- Reutilização
- Separação entre UI e negócio

A utilização de FakeAuthService permitiu:

- Independência de backend real
- Execução rápida
- Previsibilidade dos resultados

## 9. Problemas Encontrados

Nenhuma falha funcional foi encontrada durante os testes oficiais em `test/`.

Durante a implementação dos testes de integração de UI foram encontrados ajustes de automação:

- O botão final do cadastro ficava parcialmente coberto pelo teclado em execução automatizada; a ação foi ajustada para envio pelo `TextInputAction.done`.
- O fluxo completo exigiu uma rota de câmera simulada para evitar dependência de hardware.
- O fluxo completo passou a controlar o serviço fake de IA para validar deterministicamente os estados `pending`, `generating` e `completed`.

Após os ajustes, `flutter test integration_test` foi executado com sucesso.

## 10. Conclusão Final

Os testes executados demonstraram que o sistema atende aos requisitos funcionais definidos inicialmente.

Os testes unitários validaram corretamente os ViewModels e Models isoladamente.

A utilização da ISO/IEC/IEEE 29119 permitiu organizar:

- Conceitos
- Processo
- Técnicas
- Execução
- Documentação de forma estruturada e rastreável

## 11. Estatísticas Finais

| Tipo | Quantidade |
|------|------------|
| Testes planejados em `test/` | 29 |
| Testes executados em `test/` | 29 |
| Testes aprovados em `test/` | 29 |
| Testes reprovados em `test/` | 0 |
| Testes planejados em `integration_test/` | 5 |
| Testes executados em `integration_test/` | 5 |
| Testes aprovados em `integration_test/` | 5 |
| Testes reprovados em `integration_test/` | 0 |
| Falhas simuladas | 1 |

## 12. Resultados dos Testes de Integração de UI

| Caso | Objetivo | Resultado Esperado | Resultado Obtido | Status |
|------|----------|--------------------|-------------------|--------|
| IT-TC25 | Cadastro e navegação | Menu Principal exibido | Menu Principal exibido | Aprovado |
| IT-TC26 | Login com campos vazios | Validações exibidas | Validações exibidas | Aprovado |
| IT-TC27 | Login inválido | Mensagem de erro e sem navegação | Mensagem de erro e sem navegação | Aprovado |
| IT-TC28 | Login válido | Menu Principal exibido | Menu Principal exibido | Aprovado |
| IT-TC29 | Fluxo completo com modos, medição, anotação, IA e histórico | Registro salvo, anotado e IA `pending → generating → completed` | Registro salvo, anotado e IA `pending → generating → completed` | Aprovado |
