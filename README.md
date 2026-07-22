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

## Migrations pendentes de aplicar no Supabase (ação necessária)

O arquivo `database/schema.sql` é sempre a fonte da verdade do estado final esperado do banco, mas ele **não roda sozinho** no Supabase de produção: cada migration em `database/migrations/` precisa ser colada e executada manualmente no SQL Editor do painel do Supabase, em ordem numérica, uma vez cada. Todas são idempotentes (seguro rodar mais de uma vez), então na dúvida é sempre seguro rodar de novo. Se uma tela der erro do tipo "column ... does not exist", "table ... not found in schema cache" ou "more than one relationship was found", quase sempre é uma migration que ainda não rodou nesse banco, não um bug de código.

Para reduzir o número de arquivos para rodar, tudo o que está pendente foi agrupado em só 2 arquivos, nesta ordem:

1. **`database/migrations/011_a_014_consolidado.sql`**
2. **`database/migrations/015_a_019_consolidado.sql`** (o arquivo `015_a_018_consolidado.sql` antigo ainda existe na pasta, mas está substituído por este — use o `015_a_019`)

Basta abrir o SQL Editor do Supabase, colar o conteúdo inteiro do arquivo 1, rodar, depois colar o conteúdo inteiro do arquivo 2 e rodar. Os erros abaixo (todos já reportados em algum momento) são exatamente a mesma causa — essas duas migrations ainda não rodaram nesse banco — e todos somem ao rodar os 2 arquivos acima:

- "Could not find the 'accent_color' column of 'clinic_settings'"
- "Could not find the table 'public.clinic_expenses'"
- "Could not find the 'appointment_id' column of 'patient_photos'"
- Metas, ranking e "Atendimentos por profissional" aparecendo vazios ou como "Sem profissional" no BI
- Lista de integrantes sumindo em Equipe
- "Erro ao criar acesso: For security purposes, you can only request this after X seconds" é diferente: não é migration, é o próprio Supabase limitando a criação de contas muito seguidas (proteção contra abuso). Some sozinho depois de esperar o tempo indicado.

Regra geral daqui para frente: só é preciso rodar um novo arquivo SQL quando uma mudança de tela também mexe no banco (nova coluna, nova tabela) — isso é sinalizado explicitamente na entrega. Mudanças de layout, texto ou comportamento de interface não exigem nada no Supabase.

## Três papéis de acesso

O sistema é dividido em três papéis, definidos pela coluna `role` em `public.users`: `administrador`, `atendente` e `esteticista` (o papel interno `equipe_prisma`, usado pela própria Prisma Creative, enxerga tudo em qualquer clínica).

- **Administrador**: menu completo, incluindo Dashboard, Financeiro, Vendas, Serviços, Equipe, Estoque e a visão executiva de Desempenho (BI), com custos, folha e lucro.
- **Atendente**: Pacientes, Agenda completa, Vendas, Desempenho e um Dashboard básico (própria agenda do dia, anotações e aniversariantes).
- **Esteticista**: agenda e fila de atendimento apenas dos próprios horários, Vendas (pode criar uma venda, que segue para aprovação do Administrador), Desempenho (comissões, meta do mês e ranking visual da equipe) e o mesmo Dashboard básico do Atendente.

Quando um Atendente ou Esteticista cria uma venda, ela nasce como "pendente" e só conta no faturamento, na meta e na comissão de quem a criou depois que um Administrador aprova (aba Vendas, ação Aprovar). O botão "Nova venda" fica disponível tanto em Vendas quanto como atalho na tela de Atendimento.

Cada página trava o acesso por `data-allowed-roles` no `<body>`, o menu lateral esconde os itens fora do papel do usuário, e o login já redireciona cada pessoa direto para a tela inicial do seu papel. Alterar o papel de alguém só é permitido a um Administrador: existe um trigger no banco (`protect_role_change`) que bloqueia a troca mesmo que alguém tente contornar a tela e chamar a API diretamente.

## Estrutura de pastas

```
index.html            tela de login (autenticação real via Supabase Auth)
dashboard.html         painel com indicadores reais da clínica, menu rápido, anotações e aniversariantes (administrador)
pacientes.html          ficha completa de pacientes: documentos, contato, endereço, origem do lead (inclusive indicação por integrante da equipe), anamnese, pacotes contratados e retorno financeiro (administrador, atendente)
agenda.html            agenda com visão dia / semana / mês, menu de clique direito, bloqueio de horário, vínculo a pacote e ficha rápida do agendamento
atendimento.html        fila de atendimento (por profissional), prontuário, fotos de evolução, remanejamento de horário e de profissional (com motivo quando troca quem atende) e tarefa automática de retorno
equipe.html            equipe da clínica, qualificação profissional e quadro de tarefas com detalhe por clique (administrador)
vendas.html            venda de planos: carrinho com múltiplos serviços, desconto e cortesia por item, fluxo pendente → aprovada/cancelada com motivo (administrador, atendente, esteticista)
financeiro.html         transações, comissão com percentual, pacotes (com margem sobre insumos), maquininhas e parcelamento (administrador)
reativacao.html         pacientes elegíveis à reativação e histórico de contatos (administrador)
servicos.html           cadastro de serviços e de insumos, com cálculo de custo e margem (administrador)
estoque.html            controle de insumos (uso clínico) e produtos de revenda (preço de venda e margem) separados por aba: quantidade em mão nunca fica negativa, mínimo/máximo e validade com alerta persistente na própria página e no Dashboard, entradas e saídas, histórico de movimentações e custo por procedimento (administrador)
bi.html                 visão executiva por área para o Administrador (incluindo ranking de metas com pódio e gráficos mês a mês); para Atendente/Esteticista, mostra a própria comissão, indicações, clientes atendidos e meta do mês
configuracoes.html      identidade visual, tema claro/escuro, regras de agendamento, senha de gerente e permissão de visualização do desempenho pela equipe (administrador)
partials/               cabeçalho (busca de paciente, lembretes e atalho de novo paciente) e menu lateral, incluídos via JavaScript
css/styles.css          folha de estilos única do sistema
js/supabase-client.js    conexão com o projeto Supabase e definição dos papéis e da tela inicial de cada um
js/auth-guard.js        exige sessão ativa e redireciona quem tenta acessar página fora do próprio papel
js/include.js            injeta os fragmentos HTML, popula usuário/clínica no menu, aplica as configurações da clínica (logotipo, tema, visibilidade do BI) e esconde itens fora do papel do usuário
js/topbar.js            saudação com nome + data/hora (em vez do título repetido da página), busca de paciente, central de lembretes e atalhos de nova venda/novo paciente no cabeçalho
js/currency-mask.js      máscara de valor em reais (com casas decimais) usada nos campos de preço, custo e venda
js/confirm-dialog.js    modal de confirmação estilizado (confirmDialog), substitui o window.confirm() nativo em toda ação de remover/aprovar/cancelar
database/schema.sql      schema completo com RLS por clínica (fonte da verdade, já reflete todas as migrations)
database/grants.sql      permissões de acesso do role authenticated
database/seed.sql        clínica e usuário de teste
database/migrations/     alterações incrementais já aplicadas ao banco em produção, em ordem numérica
docs/                     especificação original, adendo de melhorias e guias de infraestrutura
```

## O que já está pronto

Login e sessão real via Supabase Auth, com três papéis de acesso e redirecionamento automático para a tela inicial de cada um. Cadastro de pacientes com ficha completa: CPF, telefone e e-mail obrigatórios e validados, RG, contato expandido (telefone 2, fixo, Instagram, Facebook), endereço, origem do lead (indicação de paciente, indicação de funcionário, redes sociais, Google, Ads, walk-in) com registro de quem indicou, responsável legal, dados complementares (naturalidade, filiação, profissão, prontuário), anamnese estruturada de dezesseis perguntas com pontos de atenção clínica destacados na ficha, e importação em lote por CSV com leitura do cabeçalho (aceita vírgula ou ponto e vírgula, em qualquer ordem de coluna). O cadastro é feito por um assistente sequencial com barra de progresso (etapa por etapa, com nome, CPF, telefone e e-mail obrigatórios antes de avançar), em vez de abas soltas.

A ficha do paciente também mostra os pacotes contratados (sem repetição de serviço, com sessões agendadas, concluídas, canceladas e remarcadas em cada um), o retorno financeiro total já gerado, a galeria de fotos de evolução com comparador antes/depois, os amigos indicados por aquele paciente (quando a indicação gerou outra venda) e um botão para agendar um novo atendimento direto da ficha.

Agenda com visão diária (colunas por profissional), semanal e mensal, navegação entre períodos, filtro por profissional (clicando no nome da coluna na visão diária ou pelo seletor no topo, válido nas três visões), busca de paciente digitando o nome, vínculo direto a um pacote em aberto do paciente (sem repetir a mesma informação em dois lugares), aviso ao vivo no próprio formulário quando o profissional escolhido já tem atendimento marcado no mesmo horário, menu de clique direito sobre um horário livre ou sobre um dia inteiro (incluir agendamento, bloquear horário, gerenciar bloqueios, ver agenda do dia, imprimir), ficha rápida ao clicar num agendamento existente com opção de reagendar ou cancelar com motivo, e bloqueio de horário (feriado, folga, manutenção). Esteticista vê só a própria agenda. Bloqueio de duplo agendamento do mesmo profissional no mesmo horário e formato de exibição do nome do paciente (completo, primeiro nome ou nome e sobrenome) são configuráveis na tela de Configurações.

Atendimento e prontuário, com fila do dia (filtrada por profissional para a visão Esteticista), registro de evolução por sessão, upload de fotos para o Supabase Storage com nome de arquivo sanitizado, opção de remover foto antes de concluir, remanejamento de horário e/ou profissional direto da fila (exige motivo quando troca quem vai atender), vínculo (ou correção do vínculo) a um pacote de sessões no momento da conclusão, consumo automático de sessão de pacote e de insumos do estoque ao concluir um atendimento, e criação automática de uma tarefa de retorno quando o serviço atendido tem intervalo de retorno definido.

Equipe com cadastro de novos integrantes direto na plataforma (nome, e-mail e senha geram a conta e o acesso na hora), função (Esteticista/Atendente) separada do acesso de administrador — que agora é concedido por uma caixinha própria, "Conceder acesso de administrador", em vez de virar um papel à parte — remoção/reativação de acesso sem apagar o histórico da pessoa (vendas, comissões e atendimentos continuam intactos), salário e qualificação profissional (registro profissional, especialidades, biografia), busca de paciente digitando o nome ao criar uma tarefa vinculada, e um quadro de tarefas em três colunas com detalhe completo ao clicar em qualquer card.

Vendas com carrinho de vários serviços na mesma venda (ou preenchido de uma vez a partir de um modelo de pacote cadastrado no Financeiro), quantidade de sessões e desconto (ou cortesia) por item, desconto percentual sobre o total do plano, até duas formas de pagamento combinadas na mesma venda com parcelamento e maquininha, origem da venda estruturada (indicação de paciente ou de funcionário, com percentual de comissão), e um comprovante em PDF com layout mais organizado (cabeçalho com a cor da marca, dados fiscais, vendedor) que abre em pré-visualização antes de baixar. A venda entra como pendente e só depois de aprovada é que gera os pacotes de sessão no cadastro do paciente, o lançamento no financeiro (já atribuído a quem criou a venda, para fins de meta e comissão) e, quando indicada por um funcionário, o lançamento automático da comissão. Cancelamento de uma venda pendente exige descrever o motivo. Esteticista também pode criar vendas (com atalho na tela de Atendimento), que seguem para aprovação do administrador como qualquer outra.

Serviços com cadastro de procedimentos (nome, duração, preço, intervalo de retorno) e de insumos (custo unitário, unidade de medida, código de barras), vínculo de insumos a cada serviço com quantidade usada, e cálculo automático do custo estimado e da margem.

Estoque com cadastro de insumos (quantidade em mão, mínimo e máximo), alerta de itens abaixo do mínimo, registro de entrada (com custo unitário, que atualiza o custo de referência do insumo) e de saída (com motivo), consumo automático de insumo ao concluir um atendimento, histórico completo de movimentações, valor em estoque atual e valor investido histórico, e painel de custo por procedimento.

Financeiro com lançamentos de pagamento, venda de pacote e comissão (com percentual, valor base e cálculo automático do valor da comissão), modelos de pacote reutilizáveis (nome, descrição e serviços com quantidade, para preencher o carrinho de Vendas rapidamente), cadastro de maquininhas com taxa por parcela, parcelamento no cartão de crédito com estimativa de valor líquido recebido, busca de paciente digitando o nome, e pagamento dividido em mais de uma forma na mesma venda.

Dashboard com indicadores reais (ocupação da agenda, taxa de comparecimento, ticket médio, agendamentos sem confirmação), faturamento estimado do dia comparando o previsto (agendado) com o realizado (lançado no financeiro), ranking do mês (pódio de quem está liderando em vendas), agenda do dia, menu rápido de atalhos, bloco de anotações públicas ou direcionadas a um funcionário específico, e aniversariantes do dia (ou os próximos, quando não há nenhum hoje).

Pós-venda e reativação, calculando quem já passou do intervalo de retorno esperado por procedimento e permitindo registrar contato manual enquanto a integração automática não existe.

Desempenho (BI): para o Administrador, visão executiva por área com indicadores reais em Comercial (pacientes, novos cadastros, ticket médio, conversão, origem dos leads, gráfico de novos pacientes mês a mês), Estoque (insumos cadastrados, itens abaixo do mínimo, valor em estoque, atalho para a tela completa), Fidelização (candidatos à reativação, contatos registrados, comparecimento), Financeiro (faturamento por período e por forma de pagamento, pacotes ativos, gráfico de faturamento mês a mês), Marketing (origem dos pacientes, leads em aberto, conversão de leads, e um aviso de funcionalidade futura para integração com Meta Ads), Operacional (agendamentos do dia, comparecimento, tarefas pendentes, atendimentos por profissional) e Metas da equipe (ranking de metas com pódio e coroa para quem está liderando, clientes atendidos e indicações de cada integrante, ranking de procedimentos mais executados, e edição da meta do mês). Para Atendente e Esteticista, a mesma página mostra só a própria meta do mês, o realizado, a posição no ranking, as comissões, os clientes atendidos e as indicações de novos pacientes.

Configurações (somente Administrador): logotipo da clínica, tema claro ou escuro, bloqueio de duplo agendamento, formato de exibição do nome do paciente na agenda, senha de gerente exigida para autorizar desconto e/ou cortesia, e permissão de visualização da aba Desempenho pela equipe.

## O que ainda falta

A integração real com WhatsApp via Z-API (que vai automatizar a confirmação de agendamento, os lembretes e a régua de reativação hoje registrada manualmente), a análise evolutiva por IA na ficha do paciente (mencionada no adendo, usando o histórico de atendimentos que já está sendo gravado) e a integração de fato com o Meta Ads no BI (hoje é só um aviso de funcionalidade futura). Um relatório detalhado de tempo de atendimento por profissional (para compor o BI) segue como próxima etapa, por decisão do cliente.

## Identidade visual

Paleta provisória (verde petróleo como cor primária, dourado como destaque), pensada para transmitir cuidado e profissionalismo. Ajustável assim que houver uma identidade visual definitiva da Prisma Creative para o sistema.
