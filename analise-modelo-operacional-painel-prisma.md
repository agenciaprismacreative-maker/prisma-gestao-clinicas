# Análise do Prisma CRM e aplicação no painel administrativo da Prisma

Documento de referência: *Prisma-CRM-Manual-Administração.pdf* (versão 1.0, 19 de agosto de 2026).

## 1. O que é, de fato, o documento anexado

O PDF não é um manual de boas práticas nem um guia de "como construímos, replique". É uma auditoria técnica e de segurança de outro produto seu, o Prisma CRM (bot de atendimento via WhatsApp com IA), escrita a partir do código-fonte real, com referência arquivo e linha para cada afirmação. O documento cobre duas coisas ao mesmo tempo: a arquitetura operacional do painel administrativo daquele sistema, que é a parte aproveitável como referência de organização, e uma lista de quinze vulnerabilidades reais, classificadas por severidade, incluindo dois achados críticos (XSS armazenado nas campanhas de aviso e reCAPTCHA desativado).

Essa natureza dupla importa porque muda a leitura do pedido original. Replicar o modelo operacional do Prisma CRM não pode significar copiar tudo literalmente: parte do que está documentado é exatamente o oposto de um modelo a seguir, é um catálogo do que evitar. As seções 3 e 4 abaixo separam as duas coisas.

## 2. O modelo operacional do Prisma CRM

O backoffice administrativo daquele sistema (`painel.html`) se organiza em nove seções: Dashboard, Usuários, Licenças, Planos, Webhooks de cobrança, Consumo de IA, Notificações/Avisos, Agentes e Whitelabel/Sistema. A lógica de negócio por trás dessa organização é o que tem valor real para nós:

**Workspace** é a unidade de cliente, equivalente à nossa clínica. Tem dono, plano vinculado e uma data de expiração de licença que controla o acesso.

**Plano** é um catálogo separado, com preço, recursos e limites, vinculado ao workspace por `plan_id`. É importante notar que o plano em si não é o que libera o uso.

**Licença** é o que efetivamente libera ou bloqueia o acesso. Uma chave de ativação única estende `license_expires_at`, e o middleware que protege as rotas do sistema verifica apenas essa data, não o plano. Ou seja, plano e acesso são conceitos separados: o plano define o que o cliente comprou, a licença define se ele pode usar agora.

**Cobrança**, via Asaas, é processada por webhook, respondendo HTTP 200 de imediato (exigência do próprio gateway) e com deduplicação por `ON CONFLICT DO NOTHING` numa tabela de eventos já processados, para nunca aplicar o mesmo pagamento duas vezes.

**Notificações/Avisos** são campanhas que o administrador publica e que aparecem como banner ou sino para os usuários finais, segmentáveis por plano ou público-alvo.

**Whitelabel/Sistema** centraliza marca, e-mail, integrações e parâmetros gerais, com segredos criptografados em repouso.

## 3. O que vale a pena trazer para o nosso sistema

**Separar plano de acesso.** Hoje, em `clinics`, os campos `plan_name`, `plan_value`, `trial_ends_at` e `next_due_date` estão soltos, digitados livremente a cada clínica. Criar uma tabela `plans` (catálogo de planos com nome, valor, recursos e ciclo) e vincular cada clínica a um `plan_id` traria consistência: em vez de redigitar "Plano Essencial, R$297" toda vez, o administrador escolheria de uma lista. O controle de acesso continuaria como já está, baseado em datas (`trial_ends_at`, `next_due_date`, `status`), sem necessidade de chaves de licença como no sistema auditado, que fazem sentido para ativação self-service e não se aplicam ao nosso modelo, onde é o time Prisma que cadastra cada clínica.

**Padrão de idempotência de webhook.** Quando o Asaas for de fato conectado (hoje só há preparação de schema, migration 033), vale seguir exatamente esse padrão: responder rápido, registrar o evento numa tabela própria com `ON CONFLICT DO NOTHING`, e só então processar. Evita cobrança duplicada por reenvio do gateway.

**Central de avisos.** Não existe hoje nenhum canal para a Prisma comunicar algo a todas as clínicas de uma vez (manutenção programada, novidade de produto, cobrança pendente). A ideia de campanhas segmentáveis por plano ou status é boa. A implementação, porém, precisa ser diferente da original, como detalha a seção 4.

**Disciplina de auditoria.** O sistema auditado tem uma tabela `audit_logs` no schema e não a usa em nenhuma rota sensível, isso é listado como falha (severidade média) no próprio documento. É o padrão certo para nós aplicarmos de verdade: registrar quem alterou o quê no painel interno da Prisma, quando o alvo é uma ação sensível (mudança de status ou plano de uma clínica, exclusão de clínica, ajuste manual de pagamento). Isso conecta diretamente com a arquitetura de eventos que já está represada no backlog (tarefas de `event_logs` e `emit_event()`, ainda pendentes).

## 4. O que não deve ser replicado

O próprio documento classifica estes pontos como falhas de segurança. Listo os de maior severidade e, ao lado, a situação real do nosso sistema:

**XSS armazenado ao renderizar avisos via `innerHTML` sem escapar o conteúdo (crítico).** Se formos construir a central de avisos da seção 3, o texto da campanha precisa ser renderizado como texto puro (`x-text` do Alpine, por exemplo), nunca injetado como HTML. Conferi o código atual: as duas únicas ocorrências de `innerHTML` no projeto estão em `js/include.js`, carregando os parciais estáticos do próprio site (header, sidebar), não conteúdo digitado por um administrador. Não temos esse problema hoje, e a central de avisos precisa nascer sem ele.

**Token de sessão caseiro, sem expiração e sem revogação (alto).** Não se aplica a nós. Index.html, acesso-administrativo.html e admin-clinicas.html usam Supabase Auth nativo (`signInWithPassword`, `signInWithOAuth`, `onAuthStateChange`, `signOut`), que já emite JWT com expiração e renovação automática, e tem um `signOut` real. É uma vantagem estrutural que já temos de fábrica.

**RLS decorativo, porque o backend conecta com a service role e ignora as políticas (médio).** Também não se aplica da mesma forma. Não temos um backend próprio que fale com o banco por fora das políticas: o navegador conversa direto com o Supabase, autenticado, e a RLS baseada em `auth_clinic_id()` e `auth_is_prisma_team()` é a camada real de proteção, não decorativa.

**CORS totalmente aberto e execução de comando de shell a partir de rota HTTP (ambos altos).** Não se aplicam, porque não existe um servidor Express nosso recebendo requisições livres, o projeto é HTML estático mais Supabase.

**RBAC binário, sem trava contra auto-rebaixamento e sem auditoria (médio).** Aqui a comparação é mais matizada. Nosso controle já é mais granular que um booleano único (`esteticista`, `atendente`, `administrador`, `equipe_prisma`, sempre escopado por `clinic_id` via RLS), mas ainda não temos auditoria de troca de papel nem trava contra um `equipe_prisma` remover a própria conta. É um ponto real de atenção, ligado ao item de auditoria da seção 3.

## 5. O que não se aplica ao nosso domínio

Consumo e créditos de IA, agentes MCP, reconexão forçada de WhatsApp via Docker e 2FA fazem parte do Prisma CRM porque ele é um produto de atendimento via bot. Nenhum tem correspondência direta no sistema de gestão de clínicas. A única exceção que vale registrar como ideia independente, não como algo vindo do documento, é 2FA para contas `equipe_prisma`, dado o nível de acesso que elas têm sobre todas as clínicas. Fica como sugestão à parte, não como item do roadmap abaixo.

## 6. Estado atual do painel interno da Prisma (`admin-clinicas.html`)

Hoje o painel tem quatro seções: Dashboard, Clínicas (listagem e detalhe, com gestão de acessos por clínica já implementada), Planos e pagamentos (cobrança manual por clínica, com campos prontos para integração futura com o Asaas) e Personalização (marca da tela de login). Não existe catálogo de planos, central de avisos, trilha de auditoria nem uma visão de usuários que atravesse todas as clínicas de uma vez.

## 7. Proposta de roadmap

Quatro módulos independentes entre si, cada um endereçando uma lacuna real identificada acima:

**a) Catálogo de Planos.** Nova tabela `plans`, tela de CRUD, e a aba Planos e pagamentos passa a referenciar um plano do catálogo em vez de texto livre por clínica.

**b) Central de Avisos.** Campanhas que a Prisma publica para as clínicas, com segmentação por status ou plano, renderizadas com segurança (texto puro, não HTML).

**c) Trilha de auditoria.** Registro de ações administrativas sensíveis do painel Prisma, aproveitando a arquitetura de eventos já planejada e ainda não construída.

**d) Visão global de usuários.** Lista única de todos os usuários de todas as clínicas, hoje só acessível entrando clínica por clínica.
