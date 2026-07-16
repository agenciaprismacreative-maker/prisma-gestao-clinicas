# Prisma · Sistema de Gestão para Clínicas de Estética

Esboço visual do sistema descrito em `docs/especificacao-sistema.pdf`. Interface em HTML, CSS e JavaScript puro, com Alpine.js para reatividade, conforme a stack definida na seção 3 do documento. Ainda sem conexão com banco de dados: os dados exibidos são fictícios, de uma clínica de demonstração chamada "Clínica Alma Estética".

## Como visualizar

O menu lateral e o cabeçalho são carregados por fetch() a partir de `partials/`, então o projeto precisa rodar por um servidor local, não pode ser aberto direto com duplo clique no arquivo. Dentro da pasta do projeto, rode um dos comandos abaixo e acesse o endereço indicado no terminal.

```
npx serve
```

ou

```
python3 -m http.server 8000
```

Depois acesse `http://localhost:8000` (ou a porta indicada) e entre por `index.html`.

## Estrutura de pastas

```
index.html          tela de login
dashboard.html       painel com indicadores da clínica
pacientes.html        lista de pacientes e ficha individual
agenda.html          agenda diária por profissional
partials/             cabeçalho e menu lateral, incluídos via JavaScript
css/styles.css        folha de estilos única do sistema
js/include.js          script que injeta os fragmentos HTML e inicia o Alpine.js
docs/                   especificação original e guia de criação de contas
```

## O que já está pronto

Login, dashboard com indicadores e confirmações via WhatsApp, lista e ficha de pacientes (com comparador de evolução e histórico) e a visão diária da agenda por profissional, com os status de confirmado, aguardando, sem resposta, faltou e cancelado. O menu lateral já mostra os demais módulos do sistema (equipe e tarefas, atendimento, financeiro, pós-venda, configurações), marcados como "em breve", para dar a visão do produto completo.

## O que ainda falta

Todas as telas acima são estáticas: os dados estão escritos diretamente no HTML ou em um pequeno array dentro de cada página, sem conexão real com banco de dados. As próximas etapas, seguindo a ordem da seção 8 da especificação, são: criar o schema no Supabase, conectar login e dados reais, depois construir atendimento e prontuário, equipe e tarefas, financeiro e estoque.

## Identidade visual

Paleta provisória (verde petróleo como cor primária, dourado como destaque), pensada para transmitir cuidado e profissionalismo. Ajustável assim que houver uma identidade visual definitiva da Prisma Creative para o sistema.
