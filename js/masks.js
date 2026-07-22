// Máscaras de documentos e endereço reutilizáveis (CNPJ, RG, CEP) e busca de
// endereço por CEP via ViaCEP. Segue o mesmo padrão dos helpers de máscara
// já usados em pacientes.html (maskPhone, maskCpf, maskCep), que mantém suas
// próprias cópias por já existirem antes deste arquivo. Use este arquivo em
// qualquer tela nova que precise de máscara de CNPJ, RG ou CEP.

function maskCnpj(value) {
  let v = (value || '').replace(/\D/g, '').slice(0, 14);
  v = v.replace(/(\d{2})(\d)/, '$1.$2');
  v = v.replace(/(\d{3})(\d)/, '$1.$2');
  v = v.replace(/(\d{3})(\d)/, '$1/$2');
  v = v.replace(/(\d{4})(\d)/, '$1-$2');
  return v;
}

// RG não tem padrão nacional único, mas a maioria dos estados segue o
// agrupamento 2-3-3-1 (o último dígito verificador pode ser X). Formata
// nesse padrão para dar consistência visual ao campo.
function maskRg(value) {
  let v = (value || '').toString().toUpperCase().replace(/[^0-9X]/g, '').slice(0, 9);
  v = v.replace(/(\d{2})(\d)/, '$1.$2');
  v = v.replace(/(\d{3})(\d)/, '$1.$2');
  v = v.replace(/(\d{3})([\dX])$/, '$1-$2');
  return v;
}

function maskCep(value) {
  let v = (value || '').replace(/\D/g, '').slice(0, 8);
  if (v.length > 5) return v.replace(/(\d{5})(\d{0,3})/, '$1-$2');
  return v;
}

// Busca endereço por CEP no ViaCEP. Retorna null se o CEP não tiver 8
// dígitos, não existir, ou a busca falhar (chamador decide como avisar).
async function fetchCepAddress(cep) {
  const digits = (cep || '').replace(/\D/g, '');
  if (digits.length !== 8) return null;
  try {
    const res = await fetch('https://viacep.com.br/ws/' + digits + '/json/');
    const data = await res.json();
    if (!res.ok || data.erro) return null;
    return {
      street: data.logradouro || '',
      neighborhood: data.bairro || '',
      city: data.localidade || '',
      state: data.uf || ''
    };
  } catch (err) {
    return null;
  }
}

window.maskCnpj = maskCnpj;
window.maskRg = maskRg;
window.maskCep = maskCep;
window.fetchCepAddress = fetchCepAddress;
