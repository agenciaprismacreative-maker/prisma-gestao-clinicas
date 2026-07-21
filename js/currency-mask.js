// Máscara de valores monetários (R$), com casas decimais, para uso em
// qualquer input de preço/custo/valor do sistema. Segue o mesmo padrão dos
// helpers de máscara já usados em pacientes.html (maskPhone, maskCpf etc.):
// o campo guarda o texto formatado ("R$ 1.234,56") e o valor numérico só é
// extraído (parseCurrencyToNumber) no momento de montar o payload de envio.

function maskCurrencyInput(value) {
  const digits = (value || '').toString().replace(/\D/g, '');
  if (!digits) return '';
  const cents = parseInt(digits, 10);
  const reais = cents / 100;
  return reais.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

function parseCurrencyToNumber(masked) {
  if (masked === null || masked === undefined || masked === '') return null;
  if (typeof masked === 'number') return masked;
  const digits = masked.toString().replace(/\D/g, '');
  if (!digits) return null;
  return parseInt(digits, 10) / 100;
}

function numberToCurrencyInput(value) {
  if (value === null || value === undefined || value === '') return '';
  return Number(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
