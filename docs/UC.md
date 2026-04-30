# Casos de Uso — Sistema de Inspeção Dimensional

---

## UC01 — Inspecionar Peça Dimensionalmente (Assistida)
**Descrição:** Permite ao operador medir uma peça utilizando a câmera e compará-la visualmente com o desenho técnico.

**Atores:** Operador, Sistema

**Pré-condições:**
- A peça está posicionada sobre a base de marcadores.
- O dispositivo está fixado no suporte a 90º.

**Fluxo Principal:**
1. O operador abre o aplicativo.
2. Identifica a peça que será medida.
3. O sistema orienta o enquadramento da peça e dos 4 marcadores na tela.
4. O operador captura a imagem.
5. O sistema processa os marcadores, estabelece a escala e calcula as dimensões reais (ângulos, abas, diâmetros).
6. O sistema exibe as medidas sobrepostas à imagem da peça.
7. O operador compara os valores exibidos com o desenho técnico da peça.
8. O operador seleciona o status da peça: "Conforme" (OK) ou "Não Conforme" (NOK).
9. O sistema registra automaticamente a inspeção no banco de dados.

**Fluxos Alternativos:**
- 5a. Caso os marcadores não sejam detectados, o sistema solicita nova captura.

**Pós-condições:**
- Os dados da medição e o status final são salvos para rastreabilidade.

### Diagramas
![Diagrama de atividades UC01](diagrams/UC01_activities.png)
![Diagrama de sequência UC01](diagrams/UC01_sequence.png)

---

## UC02 — Registrar Não Conformidade
**Descrição:** Permite detalhar o motivo pelo qual uma peça foi reprovada.

**Atores:** Operador, Sistema

**Pré-condições:**
- Uma medição foi realizada e o status "Não Conforme" foi selecionado.

**Fluxo Principal:**
1. O sistema solicita ao operador o motivo da reprovação (ex: Ângulo incorreto, Aba fora de medida).
2. O operador seleciona o motivo ou escreve uma breve observação.
3. O sistema vincula esse motivo ao registro da inspeção.

**Pós-condições:**
- O registro de não conformidade fica disponível no histórico para análise.

### Diagramas
![Diagrama de atividades UC02](diagrams/UC02_activities.png)
![Diagrama de sequência UC02](diagrams/UC02_sequence.png)

---

## UC03 — Consultar Histórico e Exportar Relatórios
**Descrição:** Permite visualizar as inspeções passadas e gerar arquivos para análise externa.

**Atores:** Gestor, Inspetor de Qualidade

**Pré-condições:**
- Existem inspeções registradas no sistema.

**Fluxo Principal:**
1. O usuário acessa a tela de Histórico.
2. O sistema exibe a lista de inspeções realizadas.
4. O usuário seleciona a opção "Exportar para Excel" ou "Exportar para PDF".
5. O sistema gera e disponibiliza o arquivo de relatório.

**Pós-condições:**
- Relatório exportado com sucesso.

### Diagramas
![Diagrama de atividades UC03](diagrams/UC03_activities.png)
![Diagrama de sequência UC03](diagrams/UC03_sequence.png)

---
