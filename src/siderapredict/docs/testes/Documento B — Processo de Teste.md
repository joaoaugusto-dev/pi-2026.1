# Documento B — Processo de Teste

**Projeto:** Sidera Predict  
**Tecnologia:** Flutter  
**Arquitetura:** MVVM  
**Norma aplicada:** ISO/IEC/IEEE 29119-2  

## 1. Estratégia de Teste

- Testes de unidade (ViewModels e Models)
- Testes de integração (fluxos completos entre componentes)
- Uso de FakeAuthService (substituição do Supabase)
- Teste de lógica pura (sem dependência de BuildContext)

## 2. Ambiente de Teste

- Flutter SDK
- Dart SDK 3.11+
- `flutter_test` (nativo do SDK)
- `integration_test` (SDK Flutter)
- Sem dependências externas (sem mockito, sem build_runner)

## 3. Critérios de Entrada

- Projeto funcional e compilável
- ViewModels implementados (AuthViewModel, ProcessingViewModel, ValidationViewModel)
- Models implementados (MeasurementRecord, MeasurementDraft)
- FakeAuthService implementado
- Documento A concluído

## 4. Critérios de Saída

- Todos os 29 testes de unidade/integração lógica executados
- Todos os 5 testes de integração de UI executados em dispositivo/emulador
- Todos os testes aprovados
- Resultados registrados no Documento D
- Nenhum teste reprovado

## 5. Ordem de Execução

1. Testar AuthViewModel — Login (TC01 a TC04)
2. Testar AuthViewModel — Cadastro (TC05 a TC09)
3. Testar IA — Status do Relatório (TC10 a TC12)
4. Testar Snackbars — Falha na Medição (TC13 a TC16)
5. Testar Submit de Relatório — Validação (TC17 a TC20)
6. Testar Submit de Relatório — Conformidade (TC21 a TC23)
7. Testar Submit de Relatório — Serialização (TC24)
8. Testar Integração — Fluxos Completos (TC25 a TC29)
9. Testar Integração de UI — Auth Flow e Fluxo Completo (integration_test TC25 a TC29)

## 6. Implementação

```
test/
├── fakes/
│   ├── fake_auth_service.dart
│   ├── fake_measurement_service.dart
│   └── fake_measurement_repository.dart
├── viewmodel/
│   ├── auth_view_model_test.dart
│   ├── processing_view_model_test.dart
│   └── validation_view_model_test.dart
└── integration/
    └── fluxo_completo_test.dart

integration_test/
├── auth_flow_test.dart
└── full_inspection_flow_test.dart
```

## 7. Controle

| Métrica | Quantidade |
|---------|-----------|
| Planejados em `test/` | 29 |
| Executados em `test/` | 29 |
| Aprovados em `test/` | 29 |
| Planejados em `integration_test/` | 5 |
| Executados em `integration_test/` | 5 |
| Aprovados em `integration_test/` | 5 |
| Reprovados | 0 |

## 8. Execução

```bash
# Todos os testes
flutter test test/

# Com saída detalhada
flutter test test/ --reporter expanded

# Arquivo específico
flutter test test/viewmodel/auth_view_model_test.dart

# Testes de integração com dispositivo conectado
flutter test integration_test
```

## 9. Conclusão

Encerrar após execução completa e análise dos resultados registrados no Documento D.
