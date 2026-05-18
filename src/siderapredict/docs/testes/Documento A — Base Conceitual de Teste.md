# Documento A — Base Conceitual de Teste

**Projeto:** Sidera Predict  
**Tecnologia:** Flutter  
**Arquitetura:** MVVM  
**Norma aplicada:** ISO/IEC/IEEE 29119-1  

## 1. Sistema sob teste

Aplicativo Flutter de medição industrial com visão computacional (OpenCV), relatórios gerados por IA (Ollama) e autenticação via Supabase.

## 2. Itens de teste

- AuthViewModel
- ProcessingViewModel (lógica de mensagens)
- MeasurementRecord / MeasurementDraft (modelos)
- FakeAuthService
- Fluxo Cadastro → Login
- Fluxo Login → Menu Principal
- Ciclo de vida do relatório IA (pending → generating → completed)

## 3. Escopo

- Login
- Cadastro
- Processamento de medição (IA — 3 etapas)
- Submit de novo relatório (validação + conformidade)
- Snackbars de falha na medição (marcadores ArUco)
- Serialização de dados (JSON)
- Testes de unidade
- Testes de integração

## 4. Fora de escopo

- Supabase (banco de dados real)
- OpenCV / FFI nativo
- Câmera e sensores
- Segurança e criptografia
- Performance e carga

## 5. Requisitos

RF01 — O usuário deve conseguir se cadastrar com nome, matrícula, e-mail e senha.  
RF02 — O sistema deve impedir cadastro com e-mail duplicado.  
RF03 — O sistema deve impedir cadastro com matrícula duplicada.  
RF04 — O sistema deve verificar disponibilidade de matrícula e e-mail.  
RF05 — O usuário deve conseguir fazer login com e-mail/matrícula e senha.  
RF06 — O sistema deve impedir login com credenciais inválidas.  
RF07 — O sistema deve exibir mensagem ao falhar calibração ArUco.  
RF08 — O sistema deve exibir mensagem quando a peça não for encontrada.  
RF09 — O relatório IA deve passar pelas etapas: Na Fila → Gerando → Concluído.  
RF10 — O sistema deve permitir salvar medição com dados válidos.  
RF11 — O sistema deve registrar conformidade (OK/NOK) com motivo de reprovação.  
RF12 — Os dados devem ser serializáveis em JSON sem perda.  

## 6. Condições de teste

CT01 — Validar login com credenciais válidas  
CT02 — Validar login com senha incorreta  
CT03 — Validar login com usuário inexistente  
CT04 — Validar estado de loading durante login  
CT05 — Validar cadastro com dados válidos  
CT06 — Validar cadastro com e-mail duplicado  
CT07 — Validar cadastro com matrícula duplicada  
CT08 — Validar verificação de matrícula disponível  
CT09 — Validar verificação de e-mail disponível  
CT10 — Validar status "Na Fila" da IA  
CT11 — Validar status "Gerando" da IA  
CT12 — Validar status "Concluído" da IA  
CT13 — Validar mensagem de falha na calibração ArUco  
CT14 — Validar mensagem de peça não encontrada  
CT15 — Validar mensagem padrão (imagem nula)  
CT16 — Validar mensagem personalizada de erro  
CT17 — Validar draft válido para salvar  
CT18 — Validar draft sem calibração (inválido)  
CT19 — Validar criação de registro completo  
CT20 — Validar draft sem peça encontrada (inválido)  
CT21 — Validar conformidade OK  
CT22 — Validar conformidade NOK com motivo  
CT23 — Validar copyWith mantendo dados  
CT24 — Validar serialização JSON ida e volta  

## 7. Tipos de teste

- Teste de Unidade
- Teste de Integração

## 8. Riscos

R01 — Login inválido permitir acesso ao sistema  
R02 — Navegação não funcionar após login/cadastro  
R03 — Cadastro aceitar dados duplicados  
R04 — Mensagens de erro não serem exibidas ao usuário  
R05 — Estado do ViewModel ficar inconsistente  
R06 — Relatório IA ficar preso em status "gerando"  
R07 — Dados de medição serem perdidos na serialização  
R08 — Medição inválida ser salva no sistema  
