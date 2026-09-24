import {
  EnderecoInvalido,
  normalizarCaPem,
  normalizarEnderecoServidor,
} from './endereco-servidor';

// O totem obedece a este endereço para TUDO — cardápio, venda e pagamento. Se entrar
// errado, o aparelho inteiro vai para o lugar errado.
describe('endereço do servidor (G1)', () => {
  it('aceita IP da rede local com porta e caminho', () => {
    expect(normalizarEnderecoServidor('https://192.168.0.10:3002/api/v1')).toBe(
      'https://192.168.0.10:3002/api/v1',
    );
    expect(
      normalizarEnderecoServidor('http://servidor.loja.local:3002/api/v1'),
    ).toBe('http://servidor.loja.local:3002/api/v1');
  });

  it('tira espaços e a barra final (o cliente concatena o caminho)', () => {
    expect(
      normalizarEnderecoServidor('  https://10.0.0.5:3002/api/v1//  '),
    ).toBe('https://10.0.0.5:3002/api/v1');
  });

  it('recusa o que não é endereço', () => {
    for (const ruim of ['', '   ', 'servidor da loja', '192.168.0.10:3002']) {
      expect(() => normalizarEnderecoServidor(ruim)).toThrow(EnderecoInvalido);
    }
  });

  it('recusa protocolo que não seja http/https', () => {
    for (const ruim of [
      'ftp://192.168.0.10',
      'file:///c:/x',
      'javascript:alert(1)',
    ]) {
      expect(() => normalizarEnderecoServidor(ruim)).toThrow(EnderecoInvalido);
    }
  });

  it('recusa credencial embutida e query/fragmento', () => {
    expect(() =>
      normalizarEnderecoServidor('https://u:p@192.168.0.10/api'),
    ).toThrow();
    expect(() =>
      normalizarEnderecoServidor('https://192.168.0.10/api?x=1'),
    ).toThrow();
    expect(() =>
      normalizarEnderecoServidor('https://192.168.0.10/api#a'),
    ).toThrow();
  });
});

describe('certificado da autoridade do servidor (K2)', () => {
  const cert = [
    '-----BEGIN CERTIFICATE-----',
    'MIIBkTCB+wIJAKZ1Q2example',
    '-----END CERTIFICATE-----',
  ].join('\n');

  it('aceita o PEM e devolve só os blocos de certificado', () => {
    expect(normalizarCaPem(`lixo antes\n${cert}\nlixo depois`)).toBe(cert);
  });

  it('aceita cadeia com mais de um certificado', () => {
    expect(normalizarCaPem(`${cert}\n${cert}`)).toBe(`${cert}\n${cert}`);
  });

  it('RECUSA chave privada (ela nunca sai do servidor)', () => {
    const chave = '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----';
    expect(() => normalizarCaPem(chave)).toThrow(/CHAVE PRIVADA/);
    expect(() => normalizarCaPem(`${cert}\n${chave}`)).toThrow(/CHAVE PRIVADA/);
  });

  it('recusa vazio e texto que não é certificado', () => {
    expect(() => normalizarCaPem('')).toThrow(EnderecoInvalido);
    expect(() => normalizarCaPem('o certificado do servidor')).toThrow(
      EnderecoInvalido,
    );
  });

  it('recusa arquivo absurdamente grande', () => {
    expect(() => normalizarCaPem('x'.repeat(70_000))).toThrow(/grande demais/);
  });
});
