# Regras de Negócio — SIDERA PREDICT

---

**RN01 — Interpretação Humana Assistida**
O sistema fornece as medições precisas via imagem, mas a decisão final de conformidade (OK/NOK) cabe ao operador através da comparação com o desenho técnico.
Justificativa: Simplifica o processamento e evita erros de interpretação automática de desenhos complexos.

**RN02 — Tolerância Industrial Alvo**
O sistema deve ser calibrado para atender a uma tolerância de **1,5 mm**. Medições com variação superior a esta margem devem ser revisadas.
Justificativa: Padrão aceitável para processos de corte e dobra na indústria metalúrgica.

**RN03 — Obrigatoriedade do Sistema de Marcadores**
Toda medição dimensional deve ser realizada utilizando a base de 4 marcadores físicos para garantir a escala correta da imagem.
Justificativa: Elimina distorções causadas pela distância focal da câmera.

**RN04 — Estabilidade de Captura (Suporte Físico)**
Para garantir a precisão de 1,5 mm, o dispositivo deve ser mantido em um faceamento a 90º em relação à peça.
Justificativa: Evita distorções de perspectiva que invalidam a medição.

**RN05 — Rastreabilidade Total**
Toda medição realizada pelo aplicativo deve ser registrada no banco de dados, independentemente do resultado (conforme ou não conforme).
Justificativa: Garante dados para auditoria e melhoria contínua do processo.

**RN06 — Exportação de Dados**
Os dados do histórico de medições devem ser exportáveis para Excel e PDF para análise e integração com sistemas de gestão da fábrica.
Justificativa: Facilita a análise de KPIs de produção.

---
