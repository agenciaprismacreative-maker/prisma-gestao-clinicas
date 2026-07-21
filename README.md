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

## Três papéis de acesso

O sistema é dividido em três papéis, definidos pela coluna `role` em `public.users`: `administrador`, `atendente` e `esteticista` (o papel interno `equipe_prisma`, usado pela própria Prisma Creative, enxerga tudo em qualquer clínica).

- **Administrador**: menu completo, incluindo Dashboard, Financeiro, Vendas, Serviços, Equipe e a visão executiva de Desempenho (BI).
- **Atendente**: Pacientes, Agenda completa e Vendas, para tocar o dia a dia comercial e de recepção.
- **Esteticista**: agenda e fila de atendimento apenas dos próprios horários, mais a própria aba de Desempenho (comissões e meta do mês).

Cada página trava o acesso por `data-allowed-roles` no `<body>`, o menu lateral esconde os itens fora do papel do usuário, e o login já redireciona cada pessoa direto para a tela inicial do seu papel. Alterar o papel de alguém só é permitido a um Administrador: existe um trigger no banco (`protect_role_change`) que bloqueia a troca mesmo que alguém tente contornar a tela e chamar a API diretamente.

## Estrutura de pastas

```
index.html            tela de login (autenticação real via Supabase Auth)
dashboard.html         painel com indicadores reais da clínica, menu rápido, anotações e aniversariantes (administrador)
pacientes.html          ficha completa de pacientes: documentos, contato, endereço, origem do lead (inclusive indicação por integrante da equipe), anamnese, pacotes contratados e retorno financeiro (administrador, atendente)
agenda.html            agenda com visão dia / semana / mês, menu de clique direito, bloqueio de horário, vínculo a pacote e ficha rápida do agendamento
atendimento.html        fila de atendimento (por profissional), prontuário, fotos de evolução, remanejamento de horário e tarefa automática de retorno
equipe.html            equipe da clínica, qualificação profissional e quadro de tarefas com detalhe por clique (administrador)
vendas.html            venda de planos: carrinho com múltiplos serviços, desconto e cortesia por item, fluxo pendente → aprovada/cancelada (administrador, atendente)
financeiro.html         transações, comissão com percentual, pacotes (com margem sobre insumos), maquininhas e parcelamento (administrador)
reativacao.html         pacientes elegíveis à reativação e histórico de contatos (administrador)
servicos.html           cadastro de serviços e de insumos, com cálculo de custo e margem (administrador)
bi.html                 visão executiva por área para o Administrador; para Atendente/Esteticista, mostra a própria comissão, indicações e meta do mês
partials/               cabeçalho e menu lateral, incluídos via JavaScript
css/styles.css          folha de estilos única do sistema
js/supabase-client.js    conexão com o projeto Supabase e definição dos papéis e da tela inicial de cada um
js/auth-guard.js        exige sessão ativa e redireciona quem tenta acessar página fora do próprio papel
js/include.js            injeta os fragmentos HTML, popula usuário/clínica no menu e esconde itens fora do papel do usuário
js/currency-mask.js      máscara de valor em reais (com casas decimais) usada nos campos de preço, custo e venda
database/schema.sql      schema completo com RLS por clínica (fonte da verdade, já reflete todas as migrations)
database/grants.sql      permissões de acesso do role authenticated
database/seed.sql        clínica e usuário de teste
database/migrations/     alterações incrementais já aplicadas ao banco em produção, em ordem numérica
docs/                     especificação original, adendo de melhorias e guias de infraestrutura
```

## O que já está pronto

Login e sessão real via Supabase Auth, com três papéis de acesso e redirecionamento automático para a tela inicial de cada um. Cadastro de pacientes com ficha completa: CPF e telefone com máscara, e-mail validado, RG, contato expandido (telefone 2, fixo, Instagram, Facebook), endereço, origem do lead (indicação, redes sociais, Google, Ads, walk-in, indicação por integrante da equipe) com registro de quem indicou, responsável legal, dados complementares (naturalidade, filiação, profissão, prontuário), anamnese estruturada de dezesseis perguntas com pontos de atenção clínica destacados na ficha, e importação em lote por CSV com leitura do cabeçalho (aceita vírgula ou ponto e vírgula, em qualquer ordem de coluna).

A ficha do paciente também mostra os pacotes contratados, com quantas sessões foram agendadas, concluídas, canceladas ou remarcadas em cada um, e o retorno financeiro total já gerado por aquele paciente.

Agenda com visão diária (colunas por profissional), semanal e mensal, navegação entre períodos, busca de paciente no agendamento (com o resumo dos serviços contratados em aberto), menu de clique direito sobre um horário livre nas visões dia e semana (incluir agendamento, bloquear horário, gerenciar bloqueios, imprimir), ficha rápida ao clicar num agendamento existente e bloqueio de horário (feriado, folga, manutenção). Esteticista vê só a própria agenda.

Atendimento e prontuário, com fila do dia (filtrada por profissional para a visão Esteticista), registro de evolução por sessão, upload de fotos para o Supabase Storage com nome de arquivo sanitizado, opção de remover foto antes de concluir, remanejamento de horário direto da fila, consumo automático de sessão de pacote ao concluir um atendimento vinculado a um, e criação automática de uma tarefa de retorno quando o serviço atendido tem intervalo de retorno definido.

Equipe com cadastro de novos integrantes direto na plataforma (nome, e-mail e senha geram a conta e o acesso na hora), edição de papel e qualificação profissional (registro profissional, especialidades, biografia), e um quadro de tarefas em três colunas com detalhe completo ao clicar em qualquer card.

Venda de planos: carrinho com vários serviços na mesma venda, quantidade de sessões e desconto (ou cortesia) por item, cálculo do valor total, forma de pagamento com parcelamento e maquininha. A venda entra como pendente e só depois de aprovada é que gera os pacotes de sessão no cadastro do paciente e o lançamento no financeiro, evitando fuga de caixa.

Serviços com cadastro de procedimentos (nome, duração, preço, intervalo de retorno) e de insumos (custo unitário, unidade de medida, código de barras), vínculo de insumos a cada serviço com quantidade usada, e cálculo automático do custo estimado e da margem.

Financeiro com lançamentos de pagamento, venda de pacote e comissão (com percentual, valor base e cálculo automático do valor da comissão), pacotes com valor total, custo de insumos e margem por paciente, cadastro de maquininhas com taxa por parcela, parcelamento no cartão de crédito com estimativa de valor líquido recebido, e pagamento dividido em mais de uma forma na mesma venda.

Dashboard com indicadores reais (ocupação da agenda, taxa de comparecimento, ticket médio, agendamentos sem confirmação), faturamento estimado do dia comparando o previsto (agendado) com o realizado (lançado no financeiro), agenda do dia, menu rápido de atalhos, bloco de anotações manuais da clínica e aniversariantes do dia (ou os próximos, quando não há nenhum hoje).

Pós-venda e reativação, calculando quem já passou do intervalo de retorno esperado por procedimento e permitindo registrar contato manual enquanto a integração automática não existe.

Desempenho (BI): para o Administrador, visão executiva por área com indicadores reais em Comercial (pacientes, novos cadastros, ticket médio, conversão, origem dos leads), Estoque (ainda não implementado), Fidelização (candidatos à reativação, contatos registrados, comparecimento), Financeiro (faturamento por período e por forma de pagamento, pacotes ativos), Marketing (origem dos pacientes, leads em aberto, conversão de leads), Operacional (agendamentos do dia, comparecimento, tarefas pendentes, atendimentos por profissional) e Metas da equipe (meta, realizado e indicações de cada integrante, com edição da meta do mês). Para Atendente e Esteticista, a mesma página mostra só a própria meta do mês, o realizado, as comissões e as indicações de novos pacientes.

## O que ainda falta

A integração real com WhatsApp via Z-API (que vai automatizar a confirmação de agendamento, os lembretes e a régua de reativação hoje registrada manualmente) e a análise evolutiva por IA na ficha do paciente (mencionada no adendo, usando o histórico de atendimentos que já está sendo gravado). O módulo de Estoque completo (quantidades em mão, entradas e saídas, estoque mínimo/máximo, preço de venda em embalagem) e um relatório detalhado de tempo de atendimento e consumo de insumo por profissional (para compor o BI) seguem como próxima etapa, por decisão do cliente. A tela de Configurações também segue como próximo módulo de menu a construir, e é onde faria sentido centralizar o cadastro de maquininhas hoje disponível dentro do Financeiro.

## Identidade visual

Paleta provisória (verde petróleo como cor primária, dourado como destaque), pensada para transmitir cuidado e profissionalismo. Ajustável assim que houver uma identidade visual definitiva da Prisma Creative para o sistema.
