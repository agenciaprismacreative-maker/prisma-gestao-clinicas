-- 030: sale_items.product_name (snapshot do nome do produto) + FK
-- product_id passa de ON DELETE RESTRICT para ON DELETE SET NULL.
--
-- Antes, remover um produto do estoque que já tinha sido vendido alguma
-- vez travava com erro de violação de chave estrangeira, porque o nome do
-- item exibido em Vendas dependia só do JOIN ao vivo com products.name.
-- Na prática, quase todo produto realmente usado esbarrava nisso -- daí o
-- "botão remover não funciona".
--
-- Agora o nome do produto é gravado no próprio sale_item no momento da
-- venda (snapshot, igual já se faz com preço/quantidade/total). Assim o
-- produto pode ser removido do estoque sem perder a legibilidade do
-- histórico de vendas: o item continua mostrando o nome de quando foi
-- vendido, mesmo depois que o produto some do cadastro.

alter table public.sale_items add column if not exists product_name text;

update public.sale_items si
set product_name = p.name
from public.products p
where si.product_id = p.id and si.product_name is null;

-- A constraint original exigia service_id XOR product_id. Como product_id
-- agora pode virar NULL (produto removido) mesmo numa linha que sempre foi
-- de produto, o que identifica "essa linha é de produto" passa a ser
-- product_id OU product_name preenchido (nunca os dois vazios ao mesmo
-- tempo numa linha sem service_id).
alter table public.sale_items drop constraint if exists sale_items_service_or_product_check;
alter table public.sale_items add constraint sale_items_service_or_product_check check (
  (service_id is not null and product_id is null and product_name is null)
  or
  (service_id is null and (product_id is not null or product_name is not null))
);

alter table public.sale_items drop constraint if exists sale_items_product_id_fkey;
alter table public.sale_items add constraint sale_items_product_id_fkey
  foreign key (product_id) references public.products (id) on delete set null;
