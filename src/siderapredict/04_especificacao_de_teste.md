# Documento 04 - Especificação de Teste

## Estrutura

**Feature: Auth**
- Splash.
- Login.
- Cadastro.
- Disponibilidade de e-mail e matrícula.
- Logout.

**Feature: Inspection**
- Processamento de imagem.
- Salvamento de medição.
- Histórico.
- Exclusão.
- Nome automático de peça.

**Feature: Reports**
- Formatação de histórico.
- Decodificação de imagem.

**Feature: Settings**
- Tema escuro.
- Alto contraste.

**Feature: Shared Widgets**
- Campo de senha.
- Regras de senha.
- Botão primário.

## Mapeamento

| Condição | Caso de Teste | Arquivo |
| :--- | :--- | :--- |
| CT01 | TC01 - Login válido | `test/viewmodel/auth_view_model_test.dart` |
| CT02 | TC02 - Login inválido | `test/viewmodel/auth_view_model_test.dart` |
| CT03 | TC03 - Cadastro válido | `test/viewmodel/auth_view_model_test.dart` |
| CT04 | TC04 - Cadastro duplicado | `test/viewmodel/auth_view_model_test.dart` |
| CT05 | TC05 - Matrícula/e-mail indisponíveis | `test/viewmodel/auth_view_model_test.dart` |
| CT06 | TC06 - Logout | `test/viewmodel/auth_view_model_test.dart` |
| CT07 | TC07 - Validação de login | `test/viewmodel/login_signup_view_model_test.dart` |
| CT08 | TC08 - Ação de login | `test/viewmodel/login_signup_view_model_test.dart` |
| CT09 | TC09 - Validação de cadastro | `test/viewmodel/login_signup_view_model_test.dart` |
| CT10 | TC10 - Força de senha | `test/viewmodel/login_signup_view_model_test.dart` |
| CT11 | TC11 - Ação de cadastro | `test/viewmodel/login_signup_view_model_test.dart` |
| CT12 | TC12 - Formatação de segmentos | `test/model/measurement_record_test.dart` |
| CT13 | TC13 - JSON de draft | `test/model/measurement_record_test.dart` |
| CT14 | TC14 - JSON de registro e status IA | `test/model/measurement_record_test.dart` |
| CT15 | TC15 - Payload nativo válido | `test/service/measurement_service_test.dart` |
| CT16 | TC16 - Payload nativo inválido | `test/service/measurement_service_test.dart` |
| CT17 | TC17 - Processamento válido | `test/viewmodel/inspection_view_model_test.dart` |
| CT18 | TC18 - Falha de processamento | `test/viewmodel/inspection_view_model_test.dart` |
| CT19 | TC19 - Salvamento inválido | `test/viewmodel/inspection_view_model_test.dart` |
| CT20 | TC20 - Salvamento válido | `test/viewmodel/inspection_view_model_test.dart` |
| CT21 | TC21 - Histórico e nome automático | `test/viewmodel/inspection_view_model_test.dart` |
| CT22 | TC22 - Rollback de exclusão | `test/viewmodel/inspection_view_model_test.dart` |
| CT23 | TC23 - Mensagens de processamento | `test/viewmodel/secondary_view_models_test.dart` |
| CT24 | TC24 - Validação NOK e salvamento | `test/viewmodel/secondary_view_models_test.dart` |
| CT25 | TC25 - Mensagem técnica de validação | `test/viewmodel/secondary_view_models_test.dart` |
| CT26 | TC26 - Histórico e base64 | `test/viewmodel/secondary_view_models_test.dart` |
| CT27 | TC27 - Temas exclusivos | `test/viewmodel/secondary_view_models_test.dart` |
| CT28 | TC28 - Campo de senha | `test/widget/core_widgets_test.dart` |
| CT29 | TC29 - Regras de senha | `test/widget/core_widgets_test.dart` |
| CT30 | TC30 - Botão primário | `test/widget/core_widgets_test.dart` |
| CT31 | TC31 - Splash com sessão autenticada | `test/viewmodel/splash_view_model_test.dart` |
| CT32 | TC32 - Splash com falha na sessão | `test/viewmodel/splash_view_model_test.dart` |
