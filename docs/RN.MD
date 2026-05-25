# Regras de Negócio — SIDERA PREDICT

---

**RN01 — Interpretação Humana Assistida**
O sistema fornece as medições precisas via imagem, mas a decisão final de conformidade (OK/NOK) cabe ao operador, por meio da comparação com o desenho técnico.
Justificativa: Simplifica o processamento e evita erros de interpretação automática de desenhos complexos.

**RN02 — Tolerância Industrial Alvo**
O sistema deve ser calibrado para atender a uma tolerância de **1,5 mm**. Medições com variação superior a esta margem devem ser revisadas.
Justificativa: Padrão aceitável para processos de corte e dobra na indústria metalúrgica.

**RN03 — Obrigatoriedade do Sistema de Marcadores**
Toda medição dimensional deve ser realizada utilizando a base de 4 marcadores físicos para garantir a escala correta da imagem.
Justificativa: Elimina distorções causadas pela distância focal da câmera.

**RN04 — Estabilidade de Captura (Suporte Físico)**
Para garantir a precisão de 1,5 mm, o dispositivo deve ser mantido alinhado a 90º em relação à peça.
Justificativa: Evita distorções de perspectiva que invalidam a medição.

**RN05 — Rastreabilidade Total**
Toda medição realizada pelo aplicativo deve ser registrada no banco de dados, vinculando obrigatoriamente o nome do operador responsável (usuário autenticado), independentemente do resultado (conforme ou não conforme).
Justificativa: Garante dados para auditoria, identificação de responsáveis e melhoria contínua do processo por meio da IA.

**RN06 — Exportação de Dados**
Os dados do histórico de medições devem ser exportáveis para Excel e PDF para análise e integração com sistemas de gestão da fábrica.
Justificativa: Facilita a análise de KPIs de produção.

**RN07 — Unicidade de Identificadores**
Não é permitido o cadastro de dois usuários com o mesmo e-mail ou a mesma matrícula.
Justificativa: Garante a integridade e rastreabilidade individual das inspeções.

**RN08 — Validação de Senha em Tempo Real**
As senhas devem possuir no mínimo 8 caracteres e a confirmação deve ser validada visualmente no momento da digitação.
Justificativa: Melhora a experiência do usuário (UX) e garante que o operador não cometa erros durante o cadastro.

---
