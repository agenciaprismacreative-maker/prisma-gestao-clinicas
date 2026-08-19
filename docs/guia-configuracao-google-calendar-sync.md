# Configurar a sincronização com o Google Calendar

Tudo o que dá para construir por código já está pronto e no ar: as tabelas no banco, a Edge Function que fala com o Google, o botão "Conectar Google Calendar" na Agenda. Faltam só alguns ajustes que só você consegue fazer, porque exigem acesso ao Google Cloud Console e ao painel do Supabase com login da conta da Prisma. Sem eles, o botão de conectar aparece, mas a conexão não completa.

São quatro passos.

## 1. Habilitar a Google Calendar API

O login "Continuar com Google" já usa um projeto no Google Cloud Console (foi configurado quando vocês criaram esse login). A sincronização da Agenda reaproveita o mesmo projeto e o mesmo Client ID/Secret -- não precisa criar nada novo do zero.

1. Entre em [console.cloud.google.com](https://console.cloud.google.com) com a conta Google usada para configurar o login.
2. Confirme que está no projeto certo (o mesmo que aparece em Supabase → Authentication → Providers → Google).
3. Vá em **APIs e serviços → Biblioteca**, procure por "Google Calendar API" e clique em **Ativar**.

Sem isso, toda tentativa de sincronizar um agendamento falha com erro de API não habilitada.

## 2. Configurar os segredos da Edge Function

A função que conversa com o Google (`sync-calendar-event`) precisa do Client ID e do Client Secret do mesmo OAuth client do passo 1.

1. No Google Cloud Console, vá em **APIs e serviços → Credenciais** e abra o OAuth 2.0 Client ID que o Supabase usa. Copie o **Client ID** e o **Client Secret**.
2. No painel do Supabase, vá em **Edge Functions → sync-calendar-event → Secrets** (ou Project Settings → Edge Functions → Secrets, dependendo da versão do painel) e adicione:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` não precisam ser configurados -- toda Edge Function já recebe os dois automaticamente.

## 3. Habilitar "manual linking" no Supabase Auth

Conectar o Google Calendar usa `linkIdentity()`, um recurso do Supabase Auth que adiciona a conta Google à sessão de quem já está logado (sem trocar de usuário -- importante para quem faz login na Prisma com e-mail e senha, não com Google). Esse recurso vem desligado por padrão.

1. No painel do Supabase, vá em **Authentication → Configuration → Sign In / Providers** (ou **Authentication → Settings**, dependendo da versão).
2. Ative a opção de permitir vinculação manual de identidades (**"Allow manual linking"**).

Sem isso, o clique em "Conectar com o Google" volta com erro de vinculação desativada.

## 4. Decidir o status de publicação do app no Google

Esse é o único passo que envolve uma escolha real, então vale explicar o porquê.

O escopo que a sincronização pede (`calendar.events`, para poder criar/editar eventos) é classificado pelo Google como **escopo sensível**. Isso não significa que algo está errado -- é a categoria padrão para qualquer app que lê ou escreve dados de calendário. Só significa que existe uma tela de aviso até o app passar por revisão do Google.

Duas opções, no Google Cloud Console → **APIs e serviços → Tela de consentimento OAuth**:

**Opção A -- deixar em "Testing" (padrão atual).**
Só quem estiver na lista de "Test users" consegue conectar. Você precisaria adicionar manualmente o e-mail Google de cada profissional antes de ele conseguir conectar a própria agenda, limitado a 100 contas. O Google também documenta que, nesse modo, o refresh token tem validade curta (a autorização pode expirar em poucos dias e pedir para reconectar) -- inconveniente para um recurso que deve ficar sincronizando no dia a dia.

**Opção B -- mudar para "In production", sem enviar para verificação (recomendado por agora).**
Qualquer profissional consegue conectar a própria conta, sem precisar estar numa lista. Aparece uma tela do Google avisando "app não verificado", e a pessoa clica em "Avançado" → "Acessar Prisma (não seguro)" para prosseguir -- isso acontece só uma vez, no momento de conectar, não em cada uso depois. A limitação real dessa opção é um teto de **100 contas Google no total, para sempre**, que já autorizaram o app (não é por dia nem por clínica, é vitalício até vocês verificarem).

Pelo tamanho atual da operação, a Opção B é a mais prática: sem o problema do token expirando toda hora, e o teto de 100 profissionais conectados dá margem para crescer bastante antes de precisar do próximo passo.

**Passo futuro, quando estiver perto de 100 profissionais conectados (ou quiser tirar o aviso "não verificado"):** submeter o app para a verificação de escopo sensível do Google (Cloud Console → OAuth → Verification Center). Exige site público com política de privacidade no mesmo domínio, mais um vídeo curto mostrando o fluxo de autorização. O Google informa um prazo de até 10 dias úteis. Não é urgente para o lançamento -- é um ajuste de quando a base de profissionais conectados crescer.

## Depois de configurar

Com os 4 passos feitos, o teste é simples: entrar na Agenda com um usuário profissional, clicar em "Conectar Google Calendar", passar pela tela de consentimento do Google e autorizar. Ao voltar, o botão deve mostrar "Google Calendar conectado". Qualquer agendamento criado, remarcado ou cancelado a partir daí aparece automaticamente no Google Calendar dessa pessoa.

Lembrete sobre o desenho da sincronização: ela é de mão única (Prisma → Google). Mudanças feitas direto no Google (mover um evento, apagar) não voltam para a Prisma -- a Prisma continua sendo a fonte de verdade da agenda.

---

**Fontes consultadas para as regras de verificação do Google:**
- [Sensitive scope verification -- Google for Developers](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Identity Linking -- Supabase Docs](https://supabase.com/docs/guides/auth/auth-identity-linking)
