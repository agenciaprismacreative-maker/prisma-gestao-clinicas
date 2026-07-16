# Guia de criação de contas de infraestrutura

Referente à especificação técnica do sistema de gestão para clínicas de estética (Prisma Creative, julho de 2026). Siga esta ordem, porque cada conta depende, em parte, da anterior.

## 1. GitHub (repositório do código)

O Vercel publica o site direto do repositório, então o GitHub vem primeiro.

1. Crie uma conta em github.com, caso ainda não tenha.
2. Crie um novo repositório privado, com o nome sugerido `prisma-gestao-clinicas`.
3. Não é necessário adicionar nada além do README nesse momento. Os arquivos serão enviados a partir da pasta local já conectada a este projeto.
4. Guarde o endereço do repositório (algo como `github.com/seu-usuario/prisma-gestao-clinicas`).

## 2. Supabase (banco de dados, autenticação e storage)

1. Crie uma conta em supabase.com, de preferência já usando o login do GitHub, o que facilita a integração posterior.
2. Crie uma nova organização, se solicitado, e em seguida um novo projeto. Sugestão de nome: `prisma-clinicas`.
3. Escolha a região mais próxima do Brasil disponível (em geral, São Paulo ou outra região da América do Sul).
4. Defina uma senha forte para o banco de dados e guarde essa senha em um local seguro. Ela não aparece novamente depois de criada.
5. Assim que o projeto for criado, mude o plano de Free para Pro. O documento já registrou o motivo: o plano gratuito pausa o projeto após uma semana sem uso, o que inviabiliza uma clínica em operação.
6. Dentro do projeto, acesse Project Settings, depois API. Guarde três informações, que serão necessárias para o código conversar com o banco:
   - Project URL
   - anon public key
   - service_role key (esta é sensível: nunca deve aparecer no código do front-end, apenas nas Edge Functions do servidor, conforme a seção 6 do documento).

## 3. Vercel (hospedagem)

1. Crie uma conta em vercel.com, também de preferência usando o login do GitHub.
2. Ainda não é necessário importar o repositório. Esse passo acontece quando já houver código para publicar, o que vem em uma etapa seguinte deste projeto.
3. O plano gratuito é suficiente para o volume previsto (poucas clínicas), conforme a estimativa de custo da seção 3 do documento.

## 4. Z-API (integração com WhatsApp)

1. Acesse z-api.io e crie uma conta.
2. Escolha um plano entre R$ 55 e R$ 99 mensais, conforme o documento.
3. Será necessário um número de WhatsApp ativo e disponível exclusivamente para o sistema (não pode ser um número já usado no WhatsApp pessoal ou comercial comum), porque a conexão acontece via QR Code, no mesmo princípio do WhatsApp Web.
4. Após conectar o número, guarde o Instance ID e o Token, que aparecem no painel da Z-API. Esses dados entram nas Edge Functions do Supabase para o envio e recebimento de mensagens.

## Checklist de credenciais a guardar

Ao final dos quatro cadastros, você deve ter em mãos: endereço do repositório GitHub, Project URL do Supabase, anon key do Supabase, service_role key do Supabase, senha do banco Supabase, e Instance ID e Token da Z-API.

Não é necessário me enviar esses dados agora. Quando o projeto avançar para a etapa de conexão com o banco de dados e o WhatsApp, aviso exatamente qual credencial é necessária em cada ponto, e nenhuma chave sensível deve ser compartilhada em texto simples fora do ambiente seguro do projeto.
