# Prisma · Sistema de Gestão para Clínicas de Estética

Sistema descrito em `docs/especificacao-sistema.pdf`, com as evoluções registradas em `docs/adendo-especificacao-2026-07.md`. Interface em HTML, CSS e JavaScript puro, com Alpine.js para reatividade, conforme a stack definida na seção 3 do documento original. Já conectado a um projeto real no Supabase (banco de dados, autenticação e Storage), publicado no Vercel.

## Como visualizar localmente

O menu lateral e o cabeçalho são carregados por fetch() a partir de `partials/`, então o projeto precisa rodar por um servidor local, não pode ser aberto direto com duplo clique no arquivo.

```
npx serve
```

ou

```
python3 -m http.server 8000
```

Depois acesse `http://localhost:8000` e entre com um usuário já cadastrado em Authentication → Users no painel do Supabase.

## Duas visões de acesso

O sistema é dividido em duas visões, definidas pelo papel (`role`) do usuário em `public.users`:

- **Administrador** (papéis `gestor`, `financeiro` e `equipe_prisma`): acesso ao menu completo — Dashboard, Pacientes, Agenda, Equipe e tarefas, Atendimento, Financeiro, Pós-venda, Serviços e BI.
- **Funcionário/esteticista** (papéis `recepcao` e `profissional`): acesso restrito a Agenda (só os próprios horários) e Atendimento (só a própria fila do dia). Um funcionário que tentar acessar uma página exclusiva de administrador pela URL é redirecionado automaticamente para Atendimento.

Essa separação é de experiência (menu e filtro de dados na tela). O RLS do banco continua isolando os dados por clínica; não há, por enquanto, uma trava de banco por papel dentro da mesma clínica.

## Estrutura de pastas

```
index.html            tela de login (autenticação real via Supabase Auth)
dashboard.html         painel com indicadores da clínica (administrador)
pacientes.html          ficha completa de pacientes: documentos, contato, endereço, origem do lead, anamnese (administrador)
agenda.html            agenda com visão dia / semana / mês, menu de clique direito e bloqueio de horário
atendimento.html        fila de atendimento, prontuário, fotos de evolução e remanejamento de horário
equipe.html            equipe da clínica, qualificação profissional e quadro de tarefas (administrador)
financeiro.html         transações, comissões e pacotes de sessão (administrador)
reativacao.html         pacientes elegíveis à reativação e histórico de contatos (administrador)
servicos.html           cadastro, edição e remoção de serviços (administrador)
bi.html                 BI executivo por área: Comercial, Estoque, Fidelização, Financeiro, Marketing, Operacional (administrador)
partials/               cabeçalho e menu lateral, incluídos via JavaScript
css/styles.css          folha de estilos única do sistema
js/supabase-client.js    conexão com o projeto Supabase e definição das visões (PRISMA_STAFF_ROLES)
js/auth-guard.js        exige sessão ativa e redireciona funcionário de páginas exclusivas de administrador
js/include.js            injeta os fragmentos HTML, popula usuário/clínica no menu e esconde itens fora da visão do usuário
database/schema.sql      schema completo com RLS por clínica (fonte da verdade, já reflete todas as migrations)
database/grants.sql      permissões de acesso do role authenticated
database/seed.sql        clínica e usuário de teste
database/migrations/     alterações incrementais já aplicadas ao banco em produção, em ordem numérica
docs/                     especificação original, adendo de melhorias e guias de infraestrutura
```

## O que já está pronto

Login e sessão real via Supabase Auth, com duas visões de acesso (administrador e funcionário). Cadastro de pacientes com ficha completa: CPF e telefone com máscara, e-mail validado, RG, contato expandido (telefone 2, fixo, Instagram, Facebook), endereço, origem do lead (indicação, redes sociais, Google, Ads, walk-in) com registro de quem indicou, responsável legal, dados complementares (naturalidade, filiação, profissão, prontuário), anamnese estruturada de dezesseis perguntas com pontos de atenção clínica destacados na ficha, e importação em lote por CSV.

Agenda com visão diária (colunas por profissional), semanal e mensal, navegação entre períodos, busca de paciente no agendamento, menu de clique direito sobre um horário livre (incluir agendamento, bloquear horário, gerenciar bloqueios, imprimir) e bloqueio de horário (feriado, folga, manutenção). Funcionário vê só a própria agenda.

Atendimento e prontuário, com fila do dia (filtrada por profissional para a visão Funcionário), registro de evolução por sessão, upload de fotos para o Supabase Storage com nome de arquivo sanitizado, opção de remover foto antes de concluir, conclusão automática do agendamento e remanejamento de horário direto da fila.

Equipe com vínculo de novos integrantes (a partir de um usuário já criado no Supabase Auth), edição de papel e qualificação profissional (registro profissional, especialidades, biografia), além de um quadro de tarefas em três colunas.

Serviços com cadastro, edição e remoção do catálogo de procedimentos (nome, duração, preço, intervalo de retorno).

Financeiro com lançamentos de pagamento, venda de pacote e comissão, e controle de pacotes de sessão por paciente.

Pós-venda e reativação, calculando quem já passou do intervalo de retorno esperado por procedimento e permitindo registrar contato manual enquanto a integração automática não existe.

BI executivo, visível só para Administrador, com indicadores calculados a partir dos dados reais em seis áreas: Comercial (pacientes, novos cadastros, ticket médio, conversão, origem dos leads), Estoque (ainda não implementado), Fidelização (candidatos à reativação, contatos registrados, comparecimento), Financeiro (faturamento por período e por forma de pagamento, pacotes ativos), Marketing (origem dos pacientes, leads em aberto, conversão de leads) e Operacional (agendamentos do dia, comparecimento, tarefas pendentes, atendimentos por profissional).

## O que ainda falta

A integração real com WhatsApp via Z-API (que vai automatizar a confirmação de agendamento, os lembretes e a régua de reativação hoje registrada manualmente), a análise evolutiva por IA na ficha do paciente (mencionada no adendo, usando o histórico de atendimentos que já está sendo gravado), e a atualização do dashboard para consumir dados reais de faturamento e comparecimento em vez dos números de exemplo que ainda restam ali. O módulo de Estoque (insumos, quantidades, valores investidos, código de barras, estoque mínimo/máximo) ficou como próxima etapa, por decisão do cliente. A tela de Configurações também segue como próximo módulo de menu a construir.

## Identidade visual

Paleta provisória (verde petróleo como cor primária, dourado como destaque), pensada para transmitir cuidado e profissionalismo. Ajustável assim que houver uma identidade visual definitiva da Prisma Creative para o sistema.
