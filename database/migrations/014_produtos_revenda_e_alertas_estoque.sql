-- ============================================================================
-- Migration 014: separa Insumos (uso clínico interno) de Produtos de revenda
-- (vendáveis ao paciente, com preço de venda e margem), adiciona validade
-- para alertas de vencimento, e permite que uma venda tenha itens de produto
-- além de itens de serviço.
-- Seguro rodar mais de uma vez.
-- ============================================================================

-- Todo produto/insumo cadastrado até hoje continua sendo tratado como
-- "insumo" (uso clínico) por padrão — nada muda para quem já usa o sistema.
alter table public.products
  add column if not exists product_type text not null default 'insumo' check (product_type in ('insumo', 'revenda'));
alter table public.products
  add column if not exists sale_price numeric(10, 2);
alter table public.products
  add column if not exists expiry_date date;

-- Uma venda passa a poder ter itens de serviço OU de produto de revenda.
-- service_id deixa de ser obrigatório; product_id é o par nullable dele,
-- com uma regra garantindo que toda linha tenha exatamente um dos dois.
alter table public.sale_items alter column service_id drop not null;
alter table public.sale_items
  add column if not exists product_id uuid references public.products (id) on delete restrict;

alter table public.sale_items drop constraint if exists sale_items_service_or_product_check;
alter table public.sale_items
  add constraint sale_items_service_or_product_check
  check (
    (service_id is not null and product_id is null) or
    (service_id is null and product_id is not null)
  );

create index if not exists idx_sale_items_product on public.sale_items (product_id);

-- Rastreia, no histórico de movimentações de estoque, qual venda gerou a
-- saída (quando o produto vendido é de revenda), da mesma forma que já
-- existe o consumo automático vinculado a atendimento.
alter table public.stock_movements
  add column if not exists sale_id uuid references public.sales (id) on delete set null;

create index if not exists idx_stock_movements_sale on public.stock_movements (sale_id);
