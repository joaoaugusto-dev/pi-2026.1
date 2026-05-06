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
- **UC02 — Registrar Não Conformidade:** Detalhamento do motivo de reprovação.
- **UC03 — Consultar Histórico e Exportar:** Consulta de medições passadas e exportação de dados.
- **UC04 — Realizar Cadastro:** Criação de conta com validação em tempo real.
- **UC05 — Realizar Login:** Acesso seguro com identificador unificado.

---

## 📌 Requisitos Funcionais do MVP

- **RF01:** Acesso rápido ao app.
- **RF05:** Captura de imagem da peça.
- **RF06:** Medição via visão computacional com sistema de marcadores.
- **RF09:** Registro automático de resultados.
- **RF11:** Exportação de relatórios (Excel/PDF).
- **RF12:** Uso fácil e intuitivo.
- **RF13:** Cadastro de Usuário (Validação em tempo real).
- **RF14:** Login Unificado (E-mail ou Matrícula).

---

## ⚠️ Observação Importante

- **Tolerância Alvo:** 1,5 mm (adequada para processos de corte e dobra).
- **Foco:** Peças físicas metálicas reais (chanfros, furos, semicírculos) para demonstração final.

---