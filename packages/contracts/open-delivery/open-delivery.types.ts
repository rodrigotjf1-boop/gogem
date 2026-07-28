/**
 * Contrato Open Delivery (v1) que o GoGeM expõe/consome como conector.
 *
 * Superfície PÚBLICA para terceiros — espelha o padrão de mercado (Open
 * Delivery / iFood Catalog): `Merchant → Category → Item → OptionGroup →
 * Option`, de-para por `externalCode` (= nosso `codigo_pdv`). Dinheiro em REAIS
 * decimais (o GoGeM converte de/para centavos na borda).
 *
 * Este arquivo é o CONTRATO (tipos). O conector é um follow-up; até lá o Open
 * Delivery aparece como "em breve" na tela de Integrações.
 */

/** Valor monetário no padrão Open Delivery (reais decimais). */
export interface ODMoney {
  value: number;
  currency: 'BRL';
}

export type ODItemStatus = 'AVAILABLE' | 'UNAVAILABLE';

/** Loja/merchant. */
export interface ODMerchant {
  id: string;
  name: string;
  externalCode?: string;
}

export interface ODCategory {
  id: string;
  name: string;
  index: number;
  externalCode?: string;
}

/** Opção de um grupo (equivale a ComplementoOpcao). */
export interface ODOption {
  id: string;
  name: string;
  /** De-para com o PDV/ERP (= codigo_pdv). Ausente = opção informativa. */
  externalCode?: string;
  price: ODMoney;
  status: ODItemStatus;
  index: number;
}

/** Grupo de opções/etapa (equivale a ComplementoGrupo). */
export interface ODOptionGroup {
  id: string;
  name: string;
  min: number;
  max: number | null;
  index: number;
  options: ODOption[];
}

/** Item vendável (equivale a Produto). */
export interface ODItem {
  id: string;
  name: string;
  description?: string;
  /** De-para com o PDV/ERP (= codigo_pdv). */
  externalCode?: string;
  categoryId: string;
  price: ODMoney;
  status: ODItemStatus;
  imageUrl?: string;
  optionGroups: ODOptionGroup[];
}

/** Catálogo completo do merchant. */
export interface ODCatalog {
  merchant: ODMerchant;
  categories: ODCategory[];
  items: ODItem[];
}

// ── Pedidos (ingest) ────────────────────────────────────────────────────────

export type ODOrderStatus =
  | 'PLACED'
  | 'CONFIRMED'
  | 'PREPARING'
  | 'READY'
  | 'DISPATCHED'
  | 'CONCLUDED'
  | 'CANCELLED';

export interface ODOrderItemOption {
  externalCode?: string;
  name: string;
  quantity: number;
  price: ODMoney;
}

export interface ODOrderItem {
  externalCode?: string;
  name: string;
  quantity: number;
  price: ODMoney;
  options?: ODOrderItemOption[];
  observations?: string;
}

export interface ODOrderPayment {
  method: string;
  value: ODMoney;
}

export interface ODOrder {
  id: string;
  displayId: string;
  merchantId: string;
  status: ODOrderStatus;
  createdAt: string;
  customer?: { name?: string; document?: string };
  items: ODOrderItem[];
  payments: ODOrderPayment[];
  total: ODMoney;
}

/** Evento entregue via long-polling (pedido novo/atualizado/cancelado). */
export interface ODEvent {
  id: string;
  type: 'ORDER_PLACED' | 'ORDER_CANCELLED' | 'ORDER_STATUS_CHANGED';
  orderId: string;
  createdAt: string;
}
