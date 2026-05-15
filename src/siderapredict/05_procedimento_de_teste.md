# Documento 05 - Procedimento de Teste

## Sequência Geral

1. Executar testes de modelos.
2. Executar testes de serviços.
3. Executar testes de autenticação.
4. Executar testes de inspeção.
5. Executar testes de ViewModels secundárias.
6. Executar testes de widgets.
7. Registrar resultados.
8. Emitir relatório final.

## Sequência Detalhada

**Passo 1:** Executar TC12 a TC14 para modelos de medição.  
**Passo 2:** Executar TC15 a TC16 para MeasurementService.  
**Passo 3:** Executar TC01 a TC11 e TC31 a TC32 para splash, autenticação e cadastro.  
**Passo 4:** Executar TC17 a TC22 para inspeção e histórico.  
**Passo 5:** Executar TC23 a TC27 para processamento, validação, histórico e configurações.  
**Passo 6:** Executar TC28 a TC30 para widgets reutilizáveis.  
**Passo 7:** Conferir falhas, corrigir e reexecutar.  
**Passo 8:** Registrar evidência no Documento 06.

## Comando de Execução

```bash
flutter test
```

## Resultado Esperado

Todos os 32 casos devem ser executados e aprovados sem uso de Firebase real, câmera real, OpenCV real ou API externa.
