# Guia de publicação no Vercel

O repositório Git já foi inicializado localmente, com todos os arquivos do esboço commitados. Faltam três blocos, todos feitos por você, porque envolvem login em contas pessoais.

## 1. Criar o repositório no GitHub

1. Acesse github.com e crie uma conta, caso ainda não tenha.
2. Acesse github.com/new.
3. Nome do repositório: `prisma-gestao-clinicas`.
4. Marque como **Private**.
5. Não marque a opção de criar README, .gitignore ou licença. O repositório precisa nascer vazio, porque o conteúdo já existe localmente.
6. Clique em "Create repository" e copie a URL HTTPS que aparece na tela seguinte, algo como `https://github.com/seu-usuario/prisma-gestao-clinicas.git`.

## 2. Enviar o código do computador para o GitHub

Abra o Terminal do Mac (não precisa ser por aqui, é mais seguro rodar direto na sua máquina) e execute, um de cada vez, dentro da pasta do projeto:

```
cd "/Users/lairtonjunior/Documents/Prisma - software"
git branch -M main
git remote add origin https://github.com/agenciaprismacreative-maker/prisma-gestao-clinicas.git
git push -u origin main
```

Se o terminal pedir usuário e senha, o GitHub não aceita mais a senha da conta diretamente: use seu usuário normal e, no campo de senha, cole um token de acesso pessoal. Para gerar um: Settings da conta (clique na sua foto) → Developer settings → Personal access tokens → Generate new token (classic) → marque o escopo "repo" → Generate token → copie o valor (ele só aparece uma vez).

## 3. Publicar no Vercel

1. Acesse vercel.com e crie uma conta escolhendo "Continue with GitHub", para já vincular as duas contas.
2. No painel, clique em "Add New" e depois "Project".
3. Selecione o repositório `prisma-gestao-clinicas` na lista. Se ele não aparecer, clique em "Adjust GitHub App Permissions" e autorize o acesso.
4. Nas configurações do projeto: Framework Preset pode ficar em "Other", Build Command vazio, Output Directory como raiz. O projeto é HTML estático, sem etapa de build, então não há nada a configurar além disso.
5. Clique em "Deploy" e aguarde. Como são só arquivos estáticos, o processo é rápido.
6. Ao final, o Vercel gera um endereço público, algo como `prisma-gestao-clinicas.vercel.app`, já acessível de qualquer navegador, celular incluído.

## 4. Fluxo para as próximas atualizações

Sempre que o projeto avançar (novas telas, ajustes), o ciclo é:

```
git add -A
git commit -m "descrição curta da mudança"
git push
```

O Vercel detecta o push automaticamente e republica o site em menos de um minuto, sem nenhum passo manual adicional. Esse é o comportamento descrito na seção 3 da especificação original.
