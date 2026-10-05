# Sua Atualização

App instalável (PWA) ligado ao Supabase. Publicado pela Vercel a partir deste repositório.

## Arquivos

- `index.html`: o app inteiro.
- `supabase.js`: biblioteca de conexão com o Supabase.
- `sw.js`: faz o app abrir sem internet.
- `manifest.webmanifest` e os arquivos `icon-*.png` e `apple-touch-icon.png`: instalação na tela inicial.
- `vercel.json`: ajustes de cache para as atualizações chegarem aos clientes.

Todos os arquivos ficam na raiz do repositório, sem pastas.

## Como publicar uma versão nova

1. No repositório, clique em "Add file" e depois em "Upload files".
2. Arraste os arquivos novos (os que tiverem o mesmo nome são substituídos).
3. Confirme em "Commit changes". A Vercel publica sozinha em cerca de um minuto.

Sempre que o `index.html` mudar, o `sw.js` vem junto com o número de `VERSION` atualizado.
