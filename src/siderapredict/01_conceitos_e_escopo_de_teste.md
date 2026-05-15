# Documento 01 - Conceitos e Escopo de Teste

**Projeto:** SideraPredict  
**Tecnologia:** Flutter  
**Arquitetura:** MVVM com Provider para injeção de dependência  
**Norma base:** ISO/IEC/IEEE 29119-1

## 1. Item de Teste

O item de teste deste ciclo é o aplicativo SideraPredict após a reorganização MVVM e a renomeação dos arquivos. O foco é validar o comportamento das ViewModels, modelos, serviços de medição e widgets críticos sem depender de Firebase, câmera real, OpenCV real, permissões nativas ou API externa.

## 2. Escopo

Serão testados:
- Autenticação por ViewModel com sucesso, falha e logout.
- Saída da SplashPage conforme sessão autenticada ou falha de autenticação.
- Cadastro por ViewModel com validação, senha forte e sucesso.
- Conversão de payload nativo em medições.
- Serialização de registros e status de IA.
- Processamento, salvamento, histórico, exclusão e sugestão de nome de peça.
- Validação de conformidade OK/NOK.
- Formatação de histórico e imagem base64.
- Alternância de tema escuro e alto contraste.
- Componentes visuais reutilizáveis sem regra de negócio na Page.

## 3. Fora de Escopo

Não serão testados neste ciclo:
- Firebase real.
- Firestore real.
- Câmera física.
- Biblioteca OpenCV nativa real.
- Ollama/API real.
- Salvamento real via seletor nativo de arquivos.
- Performance.
- Segurança.
- Acessibilidade completa.
- Execução em múltiplos dispositivos físicos.

## 4. Glossário

**Item de teste:** unidade, componente ou fluxo do app validado por caso de teste.  
**Base de teste:** requisitos funcionais observados no app e nas ViewModels.  
**Condição de teste:** comportamento que precisa ser verificado.  
**Caso de teste:** conjunto de entrada, ação e resultado esperado.  
**Teste de unidade:** teste isolado de modelo, serviço ou ViewModel.  
**Teste de componente:** teste de widget reutilizável.  
**Fake:** substituto controlado para dependências reais.  
**Evidência:** saída registrada pela execução automatizada.

## 5. Base de Teste

RF01 - O sistema deve autenticar credenciais válidas.  
RF02 - O sistema deve rejeitar credenciais inválidas com mensagem funcional.  
RF03 - O sistema deve cadastrar usuários válidos.  
RF04 - O sistema deve bloquear e-mail ou matrícula duplicados.  
RF05 - O sistema deve encerrar sessão e limpar dados em memória.  
RF06 - O sistema deve validar campos de login e cadastro.  
RF07 - O sistema deve exigir senha forte no cadastro.  
RF08 - O sistema deve transformar payload nativo em medição estruturada.  
RF09 - O sistema deve identificar medições inválidas.  
RF10 - O sistema deve serializar registros de medição.  
RF11 - O sistema deve processar, salvar e carregar histórico.  
RF12 - O sistema deve preservar histórico se uma exclusão falhar.  
RF13 - O sistema deve validar conformidade OK/NOK.  
RF14 - O sistema deve formatar histórico, datas e imagens.  
RF15 - O sistema deve alternar temas de forma consistente.  
RF16 - O sistema deve manter ações de widgets delegadas à ViewModel.
RF17 - O sistema deve sair da SplashPage após a inicialização.

## 6. Condições de Teste

CT01 a CT06 - AuthViewModel.  
CT07 a CT11 - LoginViewModel e SignupViewModel.  
CT12 a CT14 - Modelos de medição.  
CT15 a CT16 - MeasurementService.  
CT17 a CT22 - InspectionViewModel.  
CT23 - ProcessingViewModel.  
CT24 a CT25 - ValidationViewModel.  
CT26 - HistoryViewModel.  
CT27 - SettingsViewModel.  
CT28 a CT30 - Widgets reutilizáveis.
CT31 a CT32 - SplashViewModel.
