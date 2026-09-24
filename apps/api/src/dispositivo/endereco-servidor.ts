// G1 — validação do endereço do SERVIDOR da loja que o pareamento entrega ao totem.
//
// O totem obedece a este endereço para TUDO: cardápio, venda, pagamento. Um endereço
// errado (ou malicioso) redireciona o aparelho inteiro, então ele é conferido na entrada
// em vez de ser aceito como texto livre.
export class EnderecoInvalido extends Error {}

/**
 * Normaliza e valida. Aceita `http`/`https`, host e porta; recusa credenciais embutidas,
 * caminho com query/fragmento e qualquer coisa que não seja URL. Devolve sem a barra
 * final para o cliente concatenar o caminho sem duplicar separador.
 */
export function normalizarEnderecoServidor(bruto: string): string {
  const texto = (bruto ?? '').trim();
  if (!texto) throw new EnderecoInvalido('Informe o endereço do servidor.');
  let u: URL;
  try {
    u = new URL(texto);
  } catch {
    throw new EnderecoInvalido(
      'Endereço inválido. Use algo como https://192.168.0.10:3002/api/v1',
    );
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') {
    throw new EnderecoInvalido(
      'O endereço precisa começar com http:// ou https://',
    );
  }
  if (u.username || u.password) {
    throw new EnderecoInvalido('Não coloque usuário e senha no endereço.');
  }
  if (u.search || u.hash) {
    throw new EnderecoInvalido('O endereço não pode ter "?" nem "#".');
  }
  const caminho = u.pathname.replace(/\/+$/, '');
  return `${u.protocol}//${u.host}${caminho}`;
}

/**
 * K2 — certificado PÚBLICO da autoridade do servidor da loja (PEM).
 *
 * Só o que se distribui: o bloco CERTIFICATE. Chave privada é recusada explicitamente —
 * colar a chave aqui a espalharia para todo totem pareado, e ela nunca sai do servidor.
 */
const MAX_PEM = 64 * 1024;

export function normalizarCaPem(bruto: string): string {
  const texto = (bruto ?? '').trim();
  if (!texto)
    throw new EnderecoInvalido('Cole o certificado (ca.pem) do servidor.');
  if (texto.length > MAX_PEM) {
    throw new EnderecoInvalido(
      'Certificado grande demais — confira se colou só o ca.pem.',
    );
  }
  if (/-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(texto)) {
    throw new EnderecoInvalido(
      'Isso é uma CHAVE PRIVADA. Cole só o certificado público (ca.pem).',
    );
  }
  const blocos = texto.match(
    /-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g,
  );
  if (!blocos?.length) {
    throw new EnderecoInvalido(
      'Certificado inválido. Cole o conteúdo do ca.pem, entre BEGIN e END CERTIFICATE.',
    );
  }
  return blocos.join('\n');
}
