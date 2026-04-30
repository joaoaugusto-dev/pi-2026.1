## 🎯 Objetivo do MVP

Validar a medição dimensional assistida por imagem em ambiente real, garantindo precisão industrial e rastreabilidade básica.

---

## ✅ Funcionalidades Essenciais

- **Captura da peça via câmera:** Orientação visual para enquadramento ideal.
- **Sistema de Marcadores:** Uso de 4 marcadores físicos para calibração de escala e precisão.
- **Extração de medidas:** Cálculo automático de comprimentos, ângulos e diâmetros a partir da imagem.
- **Interpretação Humana Assistida:** Comparação manual das medidas extraídas com o desenho técnico (Blueprint).
- **Geração de Relatórios:** Histórico de medições exportável para Excel, PDF ou acessível via interface.
- **Registro de Inspeção:** Armazenamento automático em banco de dados (Firebase).

---

## 📌 Casos de Uso do MVP

- **UC01 — Inspecionar Peça (Dimensional Assistida):** O operador utiliza o app para medir a peça e valida com o desenho.
- **UC02 — Analisar Não Conformidade:** Registro de desvios identificados pelo operador.
- **UC03 — Registrar Inspeção:** Salvamento automático de dados/resultados.
- **UC04 — Visualizar Histórico:** Consulta de medições passadas e exportação de dados.

---

## 📌 Requisitos Funcionais do MVP

- **RF01:** Acesso rápido ao app.
- **RF05:** Captura de imagem da peça.
- **RF06:** Medição via visão computacional com sistema de marcadores.
- **RF12:** Registro automático de resultados.
- **RF13:** Sistema de Marcadores (Base de calibração).
- **RF14:** Exportação de relatórios (Excel/PDF).
- **RF15:** Uso fácil e intuitivo até pra operadores com pouca experiência em tecnologia.

---

## ⚠️ Observação Importante

- **Tolerância Alvo:** 1,5 mm (adequada para processos de corte e dobra).
- **Foco:** Peças físicas metálicas reais (chanfros, furos, semicírculos) para demonstração final.

---