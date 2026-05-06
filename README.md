# SIDERA PREDICT — Sistema Inteligente de Inspeção Dimensional

---

## 1. Visão Geral do Projeto

O **SIDERA PREDICT** é um sistema inteligente de inspeção dimensional assistida, desenvolvido para aplicação em ambientes industriais, com foco na inspeção de peças metálicas (especialmente perfis cortados) diretamente no chão de fábrica. O projeto utiliza visão computacional baseada em marcadores para garantir precisão e confiabilidade no controle de qualidade, auxiliando o operador na validação dimensional de forma ágil e rastreável.

---

## 2. Motivação e Problema

Na indústria metalúrgica, a conformidade dimensional das peças é crítica para garantir a qualidade do produto final. Os principais problemas enfrentados atualmente incluem:

- **Erros dimensionais** (ex: ângulos fora de especificação, abas fora de medida, geometrias incorretas)
- **Inspeção manual e subjetiva**, dependente da atenção do operador e uso de ferramentas como paquímetros
- **Baixa rastreabilidade** e dificuldade em identificar a origem de falhas
- **Impacto financeiro** devido a retrabalho, devoluções e insatisfação do cliente

O SIDERA PREDICT ataca esses pontos, fornecendo uma ferramenta de medição digital que simplifica a validação e registra cada inspeção.

---

## 3. Público-Alvo

- **Operadores de Máquina:** Necessitam validar rapidamente a conformidade das peças sem interromper o fluxo produtivo.
- **Inspetores de Qualidade:** Demandam ferramentas para garantir a conformidade dimensional, com rastreabilidade e geração de relatórios.
- **Gestores Industriais:** Buscam indicadores de desempenho, redução de custos e melhoria contínua dos processos.

---

## 4. Objetivos do Sistema

O SIDERA PREDICT tem como objetivos principais:

1. Facilitar a inspeção dimensional de peças metálicas utilizando visão computacional e sistema de marcadores.
2. Garantir uma precisão de até **1,5 mm** (tolerância para corte e dobra).
3. Garantir rastreabilidade total dos resultados através de relatórios automáticos.
4. Fornecer feedback ao operador, delegando a comparação final ao julgamento humano assistido.
5. Gerar relatórios históricos exportáveis para Excel, PDF e bancos de dados externos.

---

## 5. Solução Proposta

O sistema consiste em um aplicativo móvel (Flutter) que utiliza:

- **Sistema de Marcadores:** Uma base com quatro marcadores (Ar Markers) específicos que permitem ao software calcular dimensões reais em cm/mm com precisão.
- **Captura Assistida:** O uso dos sensores do celular (giroscópio) garante que o dispositivo mantenha um ângulo de 90º em relação à peça, eliminando distorções de perspectiva.
- **Medição por Imagem:** O app extrai as medidas reais da peça capturada via câmera.
- **Interpretação Humana Assistida:** O operador compara a medida lida pelo app com o desenho técnico da peça.
- **Gerenciamento de Acessos:** Sistema de cadastro e login para garantir a segurança e a rastreabilidade individual de cada inspeção realizada.
- **Geração de Relatórios e Rastreabilidade:** Histórico de medições exportável (Excel/PDF) com identificação automática do responsável (operador autenticado) e armazenamento em banco de dados para auditoria.

---

## 6. Diferenciais Técnicos

- **Precisão Industrial:** Foco em atender a tolerância de 1,5 mm exigida no chão de fábrica.
- **Execução Local (Edge AI):** Processamento rápido diretamente no dispositivo.
- **Escalabilidade Refinada:** Uso de escalas centesimais/milesimais nos marcadores para compensar limitações de resolução.
- **Simplicidade de Uso:** Interface otimizada para o ritmo da produção, reduzindo a dependência de ferramentas manuais.

---

## 7. Estrutura do Projeto

- Documentação acadêmica completa (casos de uso, requisitos, backlog, regras de negócio)
- Código-fonte do aplicativo móvel (Flutter)
- Sistema de relatórios e integração com banco de dados

---

---

---

## 9. Tecnologias Utilizadas

* **Framework:** Flutter (Android/iOS)
* **Visão Computacional:** OpenCV / Native Vision Engine
* **Autenticação:** Firebase Auth
* **Base de Dados:** Firebase / Cloud Firestore
* **Relatórios:** Exportação Excel/PDF / Integração DB
* **Hardware:** Dispositivos móveis (Celulares/Tablets)

---

## 10. Documentação e Padronização

Todos os documentos seguem rastreabilidade:

- RF (Requisitos Funcionais)
- RN (Regras de Negócio)
- RNF (Não Funcionais)
- UC (Casos de Uso)