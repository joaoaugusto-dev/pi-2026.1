# Requisitos Funcionais — SIDERA PREDICT

---

**RF01 — Acesso Imediato**
O sistema deve permitir acesso imediato ao aplicativo, sem necessidade de login, para não impactar o ritmo da produção.
Critério: O tempo de inicialização não deve exceder 3 segundos.

**RF02 — Identificação da Inspeção**
O sistema deve permitir identificar a peça que será medida para registro.
Critério: Nº da leitura - Data da Leitura.

**RF03 — Sistema de Marcadores (Calibração)**
O sistema deve utilizar uma base com 4 marcadores específicos para calibrar a escala da imagem e converter pixels em milímetros/centímetros.
Critério: Detecção automática dos 4 marcadores na imagem capturada.

**RF04 — Orientação de Captura**
O sistema deve orientar o operador visualmente para garantir que a foto seja tirada em um faceamento a 90º e com enquadramento correto.
Critério: Indicadores visuais de nível/alinhamento na tela.

**RF05 — Captura de Imagem da Peça**
O sistema deve capturar imagem da peça (frontal) via câmera do dispositivo.
Critério: Captura para medição.

**RF06 — Medição Dimensional por Visão Computacional**
O sistema deve calcular as medidas reais da peça a partir da imagem capturada, utilizando o sistema de marcadores como referência.
Critério: Precisão de +/- 1,5 mm.

**RF07 — Exibição de Medidas em Tempo Real**
O sistema deve exibir na tela as dimensões extraídas (comprimentos, ângulos, diâmetros) sobrepostas à imagem da peça.
Critério: Visualização clara para comparação humana.

**RF08 — Validação Humana Assistida**
O sistema deve permitir que o operador compare as medidas exibidas com o desenho técnico físico ou digital e marque a peça como "Conforme" ou "Não Conforme".
Critério: Botões dedicados para OK/NOK.

**RF09 — Registro Automático dos Resultados**
O sistema deve registrar automaticamente os resultados de inspeção, associando data/hora, as medidas extraídas e o nome do operador autenticado (responsável).
Critério: Sincronização com banco de dados em nuvem e preenchimento automático do campo "Responsável".

**RF10 — Geração de Histórico de Medições**
O sistema deve manter um histórico acessível de todas as medições realizadas.
Critério: Visualização em lista.

**RF11 — Exportação de Dados (Relatórios)**
O sistema deve permitir a exportação dos dados de inspeção para formatos externos como Excel (XLSX) e PDF.
Critério: Exportação rápida via interface do app.

**RF12 — Uso fácil e intuitivo**
O sistema deve ser de fácil e intuitivo uso até para operadores com pouca experiência em tecnologia.
Critério: Interface limpa e fluxos simplificados.

**RF13 — Cadastro de Usuário**
O sistema deve permitir que novos usuários se cadastrem para acessar funcionalidades personalizadas e rastreabilidade.
Critério: Coleta de Nome, E-mail, Matrícula e Senha.

**RF14 — Autenticação de Usuário**
O sistema deve permitir que usuários realizem login para acessar o sistema.
Critério: Login via E-mail ou Matrícula e Senha.

**RF15 — Gerenciamento de Sessão**
O sistema deve manter o usuário conectado entre utilizações do aplicativo, evitando logins repetitivos.
Critério: Persistência de token de autenticação.