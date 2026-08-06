/**
 * Catálogo de conectores do GoGeM (Fase 2). O GoGeM é uma API aberta de
 * integrações: cada conector declara seus campos de configuração e quais são
 * segredos (nunca voltam crus ao front). Novos conectores (iFood, Anota Aí…)
 * entram aqui + um handler no IntegracaoService.
 */

/** Um campo de configuração de um conector. */
export interface ConectorCampo {
  key: string;
  label: string;
  /** Segredo: mascarado nas respostas; em branco no upsert = mantém o guardado. */
  secret: boolean;
  /** Dica de UI (placeholder/ajuda). */
  ajuda?: string;
  /** true = validação de URL no front. */
  url?: boolean;
  /** Opcional: não conta para "configurado"/ativação (ex.: device do Point). */
  opcional?: boolean;
}

/** Metadados de um conector. */
export interface Conector {
  tipo: string;
  nome: string;
  descricao: string;
  /** false = aparece como "em breve" (não editável/testável ainda). */
  disponivel: boolean;
  /** Suporta importar catálogo do sistema externo? */
  importaCatalogo: boolean;
  campos: ConectorCampo[];
}

export const CONECTORES: Record<string, Conector> = {
  regem: {
    tipo: 'regem',
    nome: 'Regem',
    descricao:
      'ERP da família DMS. Importa o catálogo por código PDV e recebe as ' +
      'vendas do totem (autenticação por token de sincronização).',
    disponivel: true,
    importaCatalogo: true,
    campos: [
      {
        key: 'apiBase',
        label: 'URL da API',
        secret: false,
        url: true,
        ajuda: 'ex.: https://api.dmsregem.com/api/v1',
      },
      {
        key: 'token',
        label: 'Token de sincronização',
        secret: true,
        ajuda: 'Token do equipamento "servidor local" no Regem (X-Sync-Token).',
      },
    ],
  },
  mercadopago: {
    tipo: 'mercadopago',
    nome: 'Mercado Pago (PIX)',
    descricao:
      'PIX por QR no totem, sem homologação. As credenciais ficam no servidor ' +
      '(nunca no app); o cliente paga escaneando o QR. Sem configurar, o totem ' +
      'usa o modo sandbox (QR de teste que aprova sozinho).',
    disponivel: true,
    importaCatalogo: false,
    campos: [
      {
        key: 'accessToken',
        label: 'Access token',
        secret: true,
        ajuda:
          'Mercado Pago → Suas integrações → Credenciais. Produção começa com ' +
          'APP_USR-…; teste com TEST-….',
      },
      {
        key: 'deviceId',
        label: 'ID da maquininha Point (modo PDV)',
        secret: false,
        opcional: true,
        ajuda:
          'Só para cobrar CARTÃO na Point Smart. ID do dispositivo pareado na ' +
          'conta (ex.: PAX_A910__SMARTPOS…). Vazio = só PIX por QR.',
      },
    ],
  },
  open_delivery: {
    tipo: 'open_delivery',
    nome: 'Open Delivery',
    descricao:
      'Padrão aberto de integração de delivery (catálogo + pedidos). ' +
      'Contrato em packages/contracts — conector em construção.',
    disponivel: false,
    importaCatalogo: true,
    campos: [
      { key: 'baseUrl', label: 'URL base', secret: false, url: true },
      { key: 'clientId', label: 'Client ID', secret: false },
      { key: 'clientSecret', label: 'Client secret', secret: true },
    ],
  },
};

/** Placeholder devolvido no lugar de um segredo já preenchido. */
export const SECRET_MASK = '••••••••';
