# Backlog do Produto — SIDERA PREDICT

---

## Épico 1: Medição Assistida por Imagem (Foco MVP)
**Contexto:** Garantir medições precisas e rápidas no chão de fábrica usando visão computacional e marcadores.

- **US01 — Sistema de Marcadores (Escala)**
  - Como sistema, desejo detectar 4 marcadores físicos para estabelecer a escala real da imagem.
  - Critério: Conversão precisa de pixels para mm/cm.

- **US02 — Medição de Geometrias Básicas**
  - Como operador, desejo que o sistema meça automaticamente comprimentos e ângulos.
  - Critério: Exibição clara das medidas sobre a imagem.

- **US03 — Orientação de Nível e Ângulo**
  - Como operador, desejo ser avisado se o celular não estiver a 90º da peça.
  - Critério: Indicador visual de alinhamento.

- **US04 — Interface de Medição Rápida**
  - Como operador, desejo capturar a foto e ver os resultados em poucos segundos.
  - Critério: Processamento local rápido (Edge Computing).

---

## Épico 2: Registro e Relatórios (Foco MVP)
**Contexto:** Garantir que os dados de qualidade sejam armazenados e fáceis de auditar.

- **US05 — Salvamento em Banco de Dados (Firebase)**
  - Como sistema, desejo salvar cada inspeção automaticamente na nuvem.
  - Critério: Data, medidas e nome do responsável (rastreabilidade).

- **US06 — Histórico de Inspeções no App**
  - Como inspetor, desejo visualizar uma lista das últimas peças medidas.
  - Critério: Visualização em lista.

- **US07 — Exportação para Excel e PDF**
  - Como gestor, desejo exportar os dados gerados em arquivo Excel ou PDF para análise e entendimento.
  - Critério: Download de arquivo XLSX/PDF.

---

## Épico 3: Autenticação e Perfil
**Contexto:** Gerenciar o acesso dos operadores e garantir a personalização e segurança dos dados.

- **US08 — Cadastro de Operadores**
  - Como novo operador, desejo criar uma conta com meus dados profissionais (matrícula).
  - Critério: Registro no Firebase e validação de duplicidade.

- **US09 — Login Flexível (E-mail ou Matrícula)**
  - Como operador, desejo entrar no sistema usando minha matrícula ou e-mail.
  - Critério: Autenticação bem-sucedida e persistência da sessão.

---