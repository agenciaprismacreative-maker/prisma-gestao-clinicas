/* ===================================================================
   Prisma · classificação visual de nível de estoque, reutilizada em todo
   lugar que lista produtos/insumos para seleção (Vendas, Estoque, Serviços).

   Regra: "zerado" quando a quantidade é 0 (ou menos); "minimo" quando já
   está no mínimo cadastrado ou abaixo dele; "baixo" quando está acima do
   mínimo mas perto dele (até 20% acima); "normal" caso contrário ou quando
   o produto não tem mínimo cadastrado.
   =================================================================== */

function stockStatus(product) {
  const qty = Number((product && product.stock_quantity) || 0);
  const hasMin = product && product.min_stock_quantity !== null && product.min_stock_quantity !== undefined && product.min_stock_quantity !== '';
  const min = hasMin ? Number(product.min_stock_quantity) : null;
  if (qty <= 0) return 'zerado';
  if (min !== null && qty <= min) return 'minimo';
  if (min !== null && qty <= min * 1.2) return 'baixo';
  return 'normal';
}

function stockStatusColor(status) {
  if (status === 'zerado' || status === 'minimo') return 'var(--color-danger)';
  if (status === 'baixo') return '#B8912F';
  return '';
}

// Sufixo textual para complementar a cor (acessibilidade e clareza), ex.:
// "Ácido hialurônico (estoque baixo: 3)".
function stockStatusLabel(product) {
  const status = stockStatus(product);
  const qty = Number((product && product.stock_quantity) || 0);
  if (status === 'zerado') return ' (sem estoque)';
  if (status === 'minimo') return ' (estoque no mínimo: ' + qty + ')';
  if (status === 'baixo') return ' (estoque baixo: ' + qty + ')';
  return '';
}

window.stockStatus = stockStatus;
window.stockStatusColor = stockStatusColor;
window.stockStatusLabel = stockStatusLabel;
