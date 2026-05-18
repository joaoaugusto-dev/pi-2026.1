# Documento D — Resultados dos Testes

**Projeto:** Sidera Predict  
**Tecnologia:** Flutter  
**Arquitetura:** MVVM  
**Data de Execução:** 17/05/2026  
**Executor:** Equipe ADS — 3º Semestre  

## 1. Resumo da Execução

| Métrica | Valor |
|---------|-------|
| Total de testes planejados | 29 |
| Total de testes executados | 29 |
| Total de testes aprovados | ✅ 29 |
| Total de testes reprovados | ❌ 0 |
| Taxa de aprovação | **100%** |
| Tempo de execução | < 1 segundo |

## 2. Comando de Execução

```bash
flutter test test/ --reporter expanded
```

## 3. Saída do Terminal

```
00:00 +1:  TC01 — Login com credenciais válidas retorna sucesso
00:00 +2:  TC02 — Login com senha errada retorna erro
00:00 +3:  TC03 — Login com usuário inexistente retorna erro
00:00 +4:  TC04 — isLoading é false antes e depois do login
00:00 +5:  TC05 — Cadastro com dados válidos retorna sucesso
00:00 +6:  TC06 — Cadastro com e-mail duplicado retorna erro
00:00 +7:  TC07 — Cadastro com matrícula duplicada retorna erro
00:00 +8:  TC08 — Verificação de matrícula disponível
00:00 +9:  TC09 — Verificação de e-mail disponível
00:00 +10: TC10 — Status 'Na Fila' quando registro é criado
00:00 +11: TC11 — Status 'Gerando' durante processamento da IA
00:00 +12: TC12 — Status 'Concluído' após IA finalizar
00:00 +13: TC13 — Falha na calibração ArUco (marcadores não detectados)
00:00 +14: TC14 — Peça não encontrada no centro da prancheta
00:00 +15: TC15 — Imagem nula retorna mensagem padrão de erro
00:00 +16: TC16 — Imagem nula com lastError personalizado
00:00 +17: TC17 — Draft válido permite salvar medição
00:00 +18: TC18 — Draft sem calibração não permite salvar
00:00 +19: TC19 — MeasurementRecord criado com dados completos
00:00 +20: TC20 — Draft sem peça encontrada é inválido
00:00 +21: TC21 — Registro OK não tem motivo de reprovação
00:00 +22: TC22 — Registro NOK registra motivo
00:00 +23: TC23 — copyWith altera conformidade mantendo dados
00:00 +24: TC24 — Registro converte para JSON e volta sem perda
00:00 +25: TC25 — Cadastro → Login → Verificar usuário logado
00:00 +26: TC26 — Login inválido e re-tentativa com dados corretos
00:00 +27: TC27 — Cadastro duplicado e depois login com conta original
00:00 +28: TC28 — Criar registro e verificar ciclo de status da IA
00:00 +29: TC29 — Serializar lista de registros e restaurar
00:00 +29: All tests passed!
```

## 4. Resultados Detalhados — Login

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC01 | Login com credenciais válidas | ✅ Aprovado | `userName` retornou "João" corretamente |
| TC02 | Login com senha errada | ✅ Aprovado | `errorMessage` contém "Credenciais inválidas" |
| TC03 | Login com usuário inexistente | ✅ Aprovado | `errorMessage` presente conforme esperado |
| TC04 | Estado de loading | ✅ Aprovado | `isLoading` = `false` antes e depois |

## 5. Resultados Detalhados — Cadastro

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC05 | Cadastro com dados válidos | ✅ Aprovado | `userName` = "Maria" |
| TC06 | E-mail duplicado | ✅ Aprovado | Erro contendo "e-mail" |
| TC07 | Matrícula duplicada | ✅ Aprovado | Erro contendo "matrícula" |
| TC08 | Matrícula disponível | ✅ Aprovado | `true` para livre, `false` para ocupada |
| TC09 | E-mail disponível | ✅ Aprovado | `true` para livre, `false` para ocupado |

## 6. Resultados Detalhados — IA (3 Etapas)

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC10 | Status "Na Fila" | ✅ Aprovado | `pending` + `isAiReportStreaming == true` |
| TC11 | Status "Gerando" | ✅ Aprovado | `generating` + `isAiReportStreaming == true` |
| TC12 | Status "Concluído" | ✅ Aprovado | `completed` + `isAiReportStreaming == false` + relatório preenchido |

## 7. Resultados Detalhados — Snackbars de Falha

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC13 | Calibração ArUco falhou | ✅ Aprovado | Mensagem contém "calibração" e "ArUco" |
| TC14 | Peça não encontrada | ✅ Aprovado | Mensagem contém "não encontrada" |
| TC15 | Imagem nula (padrão) | ✅ Aprovado | Mensagem contém "processar" |
| TC16 | Imagem nula com lastError | ✅ Aprovado | Retorna exatamente o erro informado |

## 8. Resultados Detalhados — Submit de Relatório

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC17 | Draft válido | ✅ Aprovado | `isValidMeasurement == true` |
| TC18 | Draft sem calibração | ✅ Aprovado | `isValidMeasurement == false` |
| TC19 | Registro completo | ✅ Aprovado | Todos os campos preenchidos |
| TC20 | Draft sem peça | ✅ Aprovado | `isValidMeasurement == false` |
| TC21 | Conformidade OK | ✅ Aprovado | `nonConformityReason == null` |
| TC22 | Conformidade NOK | ✅ Aprovado | Motivo = "Rebarba" |
| TC23 | copyWith | ✅ Aprovado | Apenas `conformityStatus` alterado |
| TC24 | JSON ida e volta | ✅ Aprovado | Todos os campos restaurados |

## 9. Resultados Detalhados — Integração

| TC | Descrição | Resultado | Observação |
|----|-----------|-----------|------------|
| TC25 | Cadastro → Login | ✅ Aprovado | Usuário autenticado com nome correto |
| TC26 | Login inválido → Retry | ✅ Aprovado | 1ª falha, 2ª sucesso |
| TC27 | Cadastro duplicado → Login original | ✅ Aprovado | Duplicado rejeitado, original funciona |
| TC28 | Ciclo IA completo | ✅ Aprovado | pending → generating → completed |
| TC29 | Serializar lista | ✅ Aprovado | 3 registros restaurados sem perda |

## 10. Análise dos Riscos

| Risco | Status | Evidência |
|-------|--------|-----------|
| R01 — Login inválido permitir acesso | ✅ Mitigado | TC02, TC03 comprovam rejeição |
| R02 — Navegação não funcionar | ✅ Mitigado | TC25 comprova fluxo cadastro→login |
| R03 — Cadastro aceitar duplicados | ✅ Mitigado | TC06, TC07, TC27 comprovam rejeição |
| R04 — Mensagens não exibidas | ✅ Mitigado | TC13-TC16 comprovam mensagens corretas |
| R05 — Estado inconsistente | ✅ Mitigado | TC04 comprova `isLoading` consistente |
| R06 — IA presa em "gerando" | ✅ Mitigado | TC10-TC12, TC28 comprovam ciclo completo |
| R07 — Dados perdidos na serialização | ✅ Mitigado | TC24, TC29 comprovam integridade |
| R08 — Medição inválida salva | ✅ Mitigado | TC18, TC20 comprovam rejeição |

## 11. Conclusão

Todos os 29 casos de teste planejados foram executados com sucesso, resultando em **100% de aprovação**. Os riscos identificados no Documento A foram mitigados e evidenciados pelos resultados dos testes.

O sistema Sidera Predict atende aos requisitos funcionais testados (RF01 a RF12) conforme definido na Base Conceitual de Teste.

**Parecer final:** ✅ **Aprovado para uso.**
