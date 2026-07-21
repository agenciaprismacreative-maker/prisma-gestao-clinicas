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

## Estrutura de pastas

```
index.html            tela de login (autenticação real via Supabase Auth)
dashboard.html         painel com indicadores da clínica
pacientes.html          cadastro completo de pacientes, importação CSV, anamnese estruturada
agenda.html            agenda diária por profissional
atendimento.html        fila de atendimento, prontuário e fotos de evolução
equipe.html            equipe da clínica e quadro de tarefas
financeiro.html         transações, comissões e pacotes de sessão
reativacao.html         pacientes elegíveis à reativação e histórico de contatos
partials/               cabeçalho e menu lateral, incluídos via JavaScript
css/styles.css          folha de estilos única do sistema
js/supabase-client.js    conexão com o projeto Supabase (URL e chave pública)
js/auth-guard.js        protege as páginas internas, exige sessão ativa
js/include.js            injeta os fragmentos HTML, popula usuário/clínica no menu e inicia o Alpine.js
database/schema.sql      schema completo (12 tabelas) com RLS por clínica
database/grants.sql      permissões de acesso do role authenticated
database/seed.sql        clínica e usuário de teste
database/migrations/     alterações incrementais ao schema já aplicado
docs/                     especificação original, adendo de melhorias e guias de infraestrutura
```

## O que já está pronto

Login e sessão real via Supabase Auth. Cadastro de pacientes com CPF e telefone com máscara, e-mail validado, anamnese estruturada de dezesseis perguntas com pontos de atenção clínica destacados na ficha, e importação em lote por CSV. Agenda com colunas por profissional real da clínica, criação de agendamento e navegação entre dias. Atendimento e prontuário, com fila do dia, registro de evolução por sessão, upload de fotos para o Supabase Storage e conclusão automática do agendamento. Equipe com vínculo de novos integrantes (a partir de um usuário já criado no Supabase Auth) e edição de papel, além de um quadro de tarefas em três colunas. Financeiro com lançamentos de pagamento, venda de pacote e comissão, e controle de pacotes de sessão por paciente. Pós-venda e reativação, calculando quem já passou do intervalo de retorno esperado por procedimento e permitindo registrar contato manual enquanto a integração automática não existe.

## O que ainda falta

Três pendências técnicas separadas do restante: a integração real com WhatsApp via Z-API (que vai automatizar a confirmação de agendamento, os lembretes e a régua de reativação hoje registrada manualmente), a análise evolutiva por IA na ficha do paciente (mencionada no adendo, usando o histórico de atendimentos que já está sendo gravado), e a atualização do dashboard para consumir dados reais de faturamento e comparecimento em vez dos números de exemplo que ainda restam ali. A tela de Configurações também segue como próximo módulo de menu a construir.

## Identidade visual

Paleta provisória (verde petróleo como cor primária, dourado como destaque), pensada para transmitir cuidado e profissionalismo. Ajustável assim que houver uma identidade visual definitiva da Prisma Creative para o sistema.
