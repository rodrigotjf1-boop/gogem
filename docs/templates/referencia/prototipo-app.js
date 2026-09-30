/* GoGem · protótipo de autoatendimento — 5 temas, fluxo completo */
(function () {
'use strict';
const IMG = window.__IMG__;
const im = k => (IMG[k] ? IMG[k].uri : '');

/* ---------------------------------------------------------------- dados (exemplo) */
const CATS = [
  { id: 'combos', pt: 'Combos', en: 'Combos', es: 'Combos', img: 'scene_meal' },
  { id: 'burgers', pt: 'Burgers', en: 'Burgers', es: 'Hamburguesas', img: 'c_double' },
  { id: 'porcoes', pt: 'Porções', en: 'Sides', es: 'Porciones', img: 'c_fries' },
  { id: 'bebidas', pt: 'Bebidas', en: 'Drinks', es: 'Bebidas', img: 'p_shake' },
  { id: 'sobremesas', pt: 'Sobremesas', en: 'Desserts', es: 'Postres', img: 'p_sundae' },
];
const P = [
  { id: 'cb-duplo', cat: 'combos', name: 'Combo Duplo Bacon', desc: 'Duplo Bacon + batata média + bebida à escolha', price: 52.9, old: 62.7, photo: 'scene_meal', stack: ['c_double', 'c_fries'], combo: true, tag: 'top' },
  { id: 'cb-costela', cat: 'combos', name: 'Combo Costela', desc: 'Costela Defumada + batata média + bebida à escolha', price: 64.9, old: 76.7, photo: 'scene_hand', stack: ['c_costela', 'c_fries'], combo: true, tag: 'new' },
  { id: 'cb-casal', cat: 'combos', name: 'Combo Casal', desc: '2 Clássicos da Casa + batata grande + 2 bebidas', price: 89.9, old: 104.5, photo: 'scene_trio', stack: ['c_bacon', 'c_cheddar', 'c_fries'], combo: true },
  { id: 'duplo', cat: 'burgers', name: 'Duplo Bacon', desc: '2 blends de 120 g, cheddar inglês, bacon crocante e maionese da casa', price: 42.9, cut: 'c_double', photo: 'hero_double', burger: true, tag: 'top' },
  { id: 'costela', cat: 'burgers', name: 'Costela Defumada', desc: 'Costela desfiada por 12 h, cheddar cremoso, cebola crispy e picles', price: 46.9, cut: 'c_costela', photo: 'scene_hand', burger: true, tag: 'new' },
  { id: 'classico', cat: 'burgers', name: 'Clássico da Casa', desc: 'Blend de 160 g, queijo prato, alface, tomate e molho especial', price: 32.9, cut: 'c_bacon', photo: 'scene_classic', burger: true },
  { id: 'cheddar', cat: 'burgers', name: 'Cheddar & Cebola', desc: 'Blend de 160 g, cheddar, cebola roxa e ketchup defumado', price: 36.9, cut: 'c_cheddar', photo: 'scene_cheddar', burger: true },
  { id: 'onion', cat: 'burgers', name: 'Smash Onion', desc: '2 smash de 90 g, cebola na chapa, queijo prato e picles', price: 29.9, cut: 'c_onion', photo: 'scene_rustic', burger: true },
  { id: 'chicken', cat: 'burgers', name: 'Crispy Chicken', desc: 'Sobrecoxa empanada, alface americana, tomate e maionese de ervas', price: 34.9, cut: 'c_chicken', burger: true },
  { id: 'veggie', cat: 'burgers', name: 'Veggie da Horta', desc: 'Grão-de-bico e legumes, rúcula, tomate e maionese verde', price: 33.9, cut: 'c_veggie', burger: true, tag: 'veg' },
  { id: 'big', cat: 'burgers', name: 'Big Brasa', desc: 'Blend de 200 g, queijo prato, tomate e ketchup da casa', price: 39.9, cut: 'c_big', burger: true, soldout: true },
  { id: 'fritas', cat: 'porcoes', name: 'Batata frita', desc: 'Corte ondulado, sal e alecrim · porção média', price: 14.9, cut: 'c_fries', photo: 'scene_fries', side: true },
  { id: 'nachos', cat: 'porcoes', name: 'Nachos com cheddar', desc: 'Tortilhas crocantes com cheddar cremoso quente', price: 19.9, photo: 'p_nachos', side: true },
  { id: 'shake', cat: 'bebidas', name: 'Milkshake de morango', desc: '400 ml, morango fresco e chantilly', price: 18.9, photo: 'p_shake', drink: true, tag: 'top' },
  { id: 'hibisco', cat: 'bebidas', name: 'Chá gelado de hibisco', desc: '500 ml, com limão e hortelã', price: 11.9, photo: 'p_hibisco', drink: true },
  { id: 'manga', cat: 'bebidas', name: 'Smoothie de manga', desc: '400 ml, manga batida com iogurte', price: 15.9, photo: 'p_manga', drink: true },
  { id: 'mocha', cat: 'bebidas', name: 'Shake de café', desc: '400 ml, café gelado, leite e calda de chocolate', price: 16.9, photo: 'p_mocha', drink: true },
  { id: 'matcha', cat: 'bebidas', name: 'Matcha gelado', desc: '400 ml, matcha com leite vaporizado', price: 15.9, photo: 'p_matcha', drink: true },
  { id: 'sundae', cat: 'sobremesas', name: 'Sundae de morango', desc: 'Sorvete de baunilha, morangos e chantilly', price: 12.9, photo: 'p_sundae', dessert: true, tag: 'top' },
  { id: 'vulcao', cat: 'sobremesas', name: 'Bolo vulcão', desc: 'Chocolate 70% com recheio cremoso', price: 16.9, photo: 'p_vulcao', dessert: true },
  { id: 'cheesecake', cat: 'sobremesas', name: 'Cheesecake basco', desc: 'Fatia cremosa com casquinha caramelizada', price: 17.9, photo: 'p_cheesecake', dessert: true },
  { id: 'cookie', cat: 'sobremesas', name: 'Cookie de chocolate', desc: 'Massa amanteigada e gotas de chocolate', price: 8.9, photo: 'p_cookie', dessert: true },
  { id: 'casquinha', cat: 'sobremesas', name: 'Casquinha', desc: 'Sorvete de morango na casquinha crocante', price: 6.9, photo: 'p_casquinha', dessert: true },
];
const byId = id => P.find(p => p.id === id);
const COMBO_ADD = 14, COMBO_SAVE = 9.8;
const SIDE_OPTS = [{ id: 'fritas', add: 0 }, { id: 'nachos', add: 3 }];
const DRINK_OPTS = [{ id: 'hibisco', add: 0 }, { id: 'manga', add: 2 }, { id: 'mocha', add: 3 }, { id: 'shake', add: 5 }];
const EXTRAS = [{ id: 'bacon', name: 'Bacon extra', price: 4 }, { id: 'cheddar', name: 'Cheddar extra', price: 3 }, { id: 'ovo', name: 'Ovo na chapa', price: 3 }, { id: 'crispy', name: 'Cebola crispy', price: 3 }];
const REMOVES = ['Sem cebola', 'Sem picles', 'Sem tomate', 'Sem molho'];

/* ---------------------------------------------------------------- textos */
const T = {
  pt: { start: 'Toque para começar', here: 'Comer aqui', go: 'Para levar', cancel: 'Cancelar', back: 'Voltar', steps: ['Cardápio', 'Sacola', 'Identificação', 'Pagamento'],
    bag: 'Sua sacola', items: n => n === 1 ? '1 item' : n + ' itens', seeBag: 'Ver sacola', empty: 'Sua sacola está vazia', add: 'Adicionar', soldout: 'Esgotado',
    top: 'Mais pedido', new: 'Novo', veg: 'Vegetariano', makeCombo: 'Transforme em combo', comboSub: 'Batata + bebida', save: v => 'economize ' + v,
    side: 'Acompanhamento', drink: 'Bebida', extras: 'Turbine seu lanche', remove: 'Tirar algum ingrediente?', qty: 'Quantidade',
    recTitle: 'Combina com seu pedido', recSub: 'Sugestões pensadas para o que você escolheu', more: 'Adicionar mais', checkout: 'Finalizar pedido',
    subtotal: 'Subtotal', total: 'Total', saved: v => 'Você economizou ' + v + ' com combos',
    cpfT: 'CPF na nota?', cpfS: 'Opcional. Informe se quiser a nota fiscal no seu nome.', skip: 'Pular', cont: 'Continuar', invalid: 'CPF inválido, confira os números', valid: 'CPF válido', clear: 'Limpar',
    nameT: 'Como podemos te chamar?', nameS: 'Seu nome aparece no painel e é chamado quando o pedido ficar pronto.', namePh: 'Digite seu nome', space: 'espaço',
    payT: 'Como você quer pagar?', payK: v => 'Último passo, ' + v, pix: 'Pix', pixS: 'Aprovação na hora pelo app do banco', credit: 'Crédito', creditS: 'Aproxime, insira ou passe na maquininha', debit: 'Débito', debitS: 'Aproxime, insira ou passe na maquininha', cash: 'Dinheiro', cashS: 'Seu pedido vai para o caixa e você paga lá', fastest: 'Mais rápido', summary: 'Resumo do pedido',
    pixT: 'Escaneie com o app do seu banco', pixS2: 'Abra o app, escolha Pix › Pagar com QR Code', expires: 'Expira em', waiting: 'Aguardando pagamento', approved: 'Pagamento aprovado', change: 'Trocar forma de pagamento',
    cardT: 'Use a maquininha abaixo', cardS: 'Aproxime o cartão ou celular, ou insira o cartão', processing: 'Processando…',
    doneT: 'Pedido confirmado!', doneCash: 'Pedido enviado!', cashNote: 'Dirija-se ao caixa para pagar', yourNo: 'Sua senha', callYou: n => 'Vamos chamar <strong>' + n + '</strong> no painel quando estiver pronto.', eta: 'Tempo estimado: 12 min', receipt: 'Retire seu comprovante', newOrder: 'Fazer novo pedido', backIn: s => 'Voltando ao início em ' + s + ' s',
    idleT: 'Ainda está aí?', idleS: s => 'Seu pedido será cancelado em ' + s + ' segundos.', idleYes: 'Continuar pedido', idleNo: 'Cancelar pedido',
    upComboT: 'Que tal fazer combo?', upComboS: 'Batata média + bebida por apenas', yesCombo: 'Quero combo', noThanks: 'Não, obrigado',
    upDessT: 'Uma sobremesa pra fechar?', upDessS: 'Toque para adicionar. Dá pra tirar depois.', noDessert: 'Seguir sem sobremesa',
    a11y: 'Modo acessível', a11yOn: 'Modo acessível ativado: toda a tela desceu para perto de você.', a11yOff: 'Desativar',
    customize: 'Personalizar', added: 'Adicionado à sacola', sent: 'Pedido enviado à cozinha', eatHere: 'Comer aqui', takeAway: 'Para levar', edit: 'Editar', cpfNote: 'CPF na nota' },
  en: { start: 'Tap to start', here: 'Eat here', go: 'Take away', cancel: 'Cancel', back: 'Back', steps: ['Menu', 'Bag', 'Details', 'Payment'],
    bag: 'Your bag', items: n => n === 1 ? '1 item' : n + ' items', seeBag: 'View bag', empty: 'Your bag is empty', add: 'Add', soldout: 'Sold out',
    top: 'Best seller', new: 'New', veg: 'Vegetarian', makeCombo: 'Make it a meal', comboSub: 'Fries + drink', save: v => 'save ' + v,
    side: 'Side', drink: 'Drink', extras: 'Add extras', remove: 'Remove anything?', qty: 'Quantity',
    recTitle: 'Goes well with your order', recSub: 'Picked for what you chose', more: 'Add more', checkout: 'Checkout',
    subtotal: 'Subtotal', total: 'Total', saved: v => 'You saved ' + v + ' with meals',
    cpfT: 'Tax ID on receipt?', cpfS: 'Optional. Add it if you need an invoice in your name.', skip: 'Skip', cont: 'Continue', invalid: 'Invalid number, please check', valid: 'Valid number', clear: 'Clear',
    nameT: 'What should we call you?', nameS: 'Your name shows on the pickup screen when your order is ready.', namePh: 'Type your name', space: 'space',
    payT: 'How would you like to pay?', payK: v => 'Last step, ' + v, pix: 'Pix', pixS: 'Instant approval in your bank app', credit: 'Credit', creditS: 'Tap, insert or swipe on the terminal', debit: 'Debit', debitS: 'Tap, insert or swipe on the terminal', cash: 'Cash', cashS: 'Your order goes to the counter and you pay there', fastest: 'Fastest', summary: 'Order summary',
    pixT: 'Scan with your bank app', pixS2: 'Open your app and choose Pix › Pay with QR Code', expires: 'Expires in', waiting: 'Waiting for payment', approved: 'Payment approved', change: 'Change payment method',
    cardT: 'Use the terminal below', cardS: 'Tap your card or phone, or insert the card', processing: 'Processing…',
    doneT: 'Order confirmed!', doneCash: 'Order sent!', cashNote: 'Please pay at the counter', yourNo: 'Your number', callYou: n => 'We will call <strong>' + n + '</strong> on the screen when it is ready.', eta: 'Estimated time: 12 min', receipt: 'Take your receipt', newOrder: 'Start a new order', backIn: s => 'Back to start in ' + s + ' s',
    idleT: 'Still there?', idleS: s => 'Your order will be cancelled in ' + s + ' seconds.', idleYes: 'Keep ordering', idleNo: 'Cancel order',
    upComboT: 'Make it a meal?', upComboS: 'Medium fries + drink for just', yesCombo: 'Yes, make it a meal', noThanks: 'No, thanks',
    upDessT: 'Something sweet to finish?', upDessS: 'Tap to add. You can remove it later.', noDessert: 'Continue without dessert',
    a11y: 'Accessible mode', a11yOn: 'Accessible mode on: the screen moved down closer to you.', a11yOff: 'Turn off',
    customize: 'Customize', added: 'Added to bag', sent: 'Order sent to the kitchen', eatHere: 'Eat here', takeAway: 'Take away', edit: 'Edit', cpfNote: 'Tax ID' },
  es: { start: 'Toca para empezar', here: 'Comer aquí', go: 'Para llevar', cancel: 'Cancelar', back: 'Volver', steps: ['Menú', 'Bolsa', 'Datos', 'Pago'],
    bag: 'Tu bolsa', items: n => n === 1 ? '1 ítem' : n + ' ítems', seeBag: 'Ver bolsa', empty: 'Tu bolsa está vacía', add: 'Agregar', soldout: 'Agotado',
    top: 'Más pedido', new: 'Nuevo', veg: 'Vegetariano', makeCombo: 'Hazlo combo', comboSub: 'Papas + bebida', save: v => 'ahorra ' + v,
    side: 'Acompañamiento', drink: 'Bebida', extras: 'Agrega extras', remove: '¿Quitar algún ingrediente?', qty: 'Cantidad',
    recTitle: 'Combina con tu pedido', recSub: 'Sugerencias para lo que elegiste', more: 'Agregar más', checkout: 'Finalizar pedido',
    subtotal: 'Subtotal', total: 'Total', saved: v => 'Ahorraste ' + v + ' con combos',
    cpfT: '¿Documento en la factura?', cpfS: 'Opcional. Infórmalo si necesitas factura a tu nombre.', skip: 'Omitir', cont: 'Continuar', invalid: 'Número inválido, revísalo', valid: 'Número válido', clear: 'Borrar',
    nameT: '¿Cómo te llamamos?', nameS: 'Tu nombre aparece en la pantalla cuando el pedido esté listo.', namePh: 'Escribe tu nombre', space: 'espacio',
    payT: '¿Cómo quieres pagar?', payK: v => 'Último paso, ' + v, pix: 'Pix', pixS: 'Aprobación inmediata en tu app del banco', credit: 'Crédito', creditS: 'Acerca, inserta o desliza en la terminal', debit: 'Débito', debitS: 'Acerca, inserta o desliza en la terminal', cash: 'Efectivo', cashS: 'Tu pedido va a la caja y pagas allí', fastest: 'Más rápido', summary: 'Resumen del pedido',
    pixT: 'Escanea con tu app del banco', pixS2: 'Abre la app y elige Pix › Pagar con QR', expires: 'Expira en', waiting: 'Esperando el pago', approved: 'Pago aprobado', change: 'Cambiar forma de pago',
    cardT: 'Usa la terminal de abajo', cardS: 'Acerca la tarjeta o el celular, o inserta la tarjeta', processing: 'Procesando…',
    doneT: '¡Pedido confirmado!', doneCash: '¡Pedido enviado!', cashNote: 'Dirígete a la caja para pagar', yourNo: 'Tu número', callYou: n => 'Llamaremos a <strong>' + n + '</strong> en la pantalla cuando esté listo.', eta: 'Tiempo estimado: 12 min', receipt: 'Retira tu comprobante', newOrder: 'Hacer nuevo pedido', backIn: s => 'Volviendo al inicio en ' + s + ' s',
    idleT: '¿Sigues ahí?', idleS: s => 'Tu pedido se cancelará en ' + s + ' segundos.', idleYes: 'Seguir pidiendo', idleNo: 'Cancelar pedido',
    upComboT: '¿Lo hacemos combo?', upComboS: 'Papas medianas + bebida por solo', yesCombo: 'Quiero combo', noThanks: 'No, gracias',
    upDessT: '¿Un postre para cerrar?', upDessS: 'Toca para agregar. Puedes quitarlo después.', noDessert: 'Seguir sin postre',
    a11y: 'Modo accesible', a11yOn: 'Modo accesible activado: la pantalla bajó más cerca de ti.', a11yOff: 'Desactivar',
    customize: 'Personalizar', added: 'Agregado a la bolsa', sent: 'Pedido enviado a la cocina', eatHere: 'Comer aquí', takeAway: 'Para llevar', edit: 'Editar', cpfNote: 'Documento' },
};

/* ---------------------------------------------------------------- estado */
const S = { theme: 'brasa', lang: 'pt', mode: 'here', screen: 'attract', cart: [], cpf: '', name: '', pay: null, orderNo: 0, modal: null, a11y: false, dessertAsked: false, edit: null, payStage: 0 };
let uid = 1;
const t = k => T[S.lang][k];
const brl = v => 'R$ ' + v.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function lineUnit(l) {
  const p = byId(l.pid); let v = p.price;
  if (l.combo) { v += p.combo ? 0 : COMBO_ADD; v += (SIDE_OPTS.find(o => o.id === l.combo.side) || {}).add || 0; v += (DRINK_OPTS.find(o => o.id === l.combo.drink) || {}).add || 0; }
  for (const e of EXTRAS) v += (l.extras[e.id] || 0) * e.price;
  return v;
}
const cartCount = () => S.cart.reduce((a, l) => a + l.qty, 0);
const cartTotal = () => S.cart.reduce((a, l) => a + lineUnit(l) * l.qty, 0);
const cartSaved = () => S.cart.reduce((a, l) => a + (l.combo ? (byId(l.pid).combo ? (byId(l.pid).old - byId(l.pid).price) : COMBO_SAVE) * l.qty : 0), 0);
function lineDesc(l) {
  const out = [];
  if (l.combo) out.push((byId(l.pid).combo ? '' : 'Combo: ') + byId(l.combo.side).name + ' + ' + byId(l.combo.drink).name);
  for (const e of EXTRAS) if (l.extras[e.id]) out.push('+ ' + (l.extras[e.id] > 1 ? l.extras[e.id] + '× ' : '') + e.name);
  out.push(...l.removed);
  return out;
}

/* ---------------------------------------------------------------- ícones */
const IC = {
  back: '<path d="M15 18l-6-6 6-6"/>', close: '<path d="M18 6L6 18M6 6l12 12"/>', plus: '<path d="M12 5v14M5 12h14"/>', minus: '<path d="M5 12h14"/>',
  trash: '<path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/>', bag: '<path d="M5 8h14l-1 12H6L5 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
  card: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M2.5 10h19M6.5 15h4"/>', cash: '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.8"/><path d="M6 9.5v5M18 9.5v5"/>',
  pix: '<path d="M12 2.8l4.2 4.2-4.2 4.2L7.8 7z"/><path d="M12 12.8l4.2 4.2-4.2 4.2-4.2-4.2z"/><path d="M2.8 12l4.2-4.2 4.2 4.2-4.2 4.2z"/><path d="M12.8 12l4.2-4.2 4.2 4.2-4.2 4.2z"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', printer: '<path d="M7 9V3h10v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M7 14h10v7H7z"/>',
  tap: '<path d="M9 11V5.5a1.5 1.5 0 0 1 3 0V11"/><path d="M12 10.5a1.5 1.5 0 0 1 3 0V12a1.5 1.5 0 0 1 3 0v3.5A5.5 5.5 0 0 1 12.5 21h-1a5 5 0 0 1-4-2L4.6 15a1.6 1.6 0 0 1 2.4-2.1L9 15"/>',
  access: '<circle cx="12" cy="4.5" r="1.8"/><path d="M5 8.5l7 1.5 7-1.5M12 10v5l-3 6M12 15l3 6"/>', dine: '<path d="M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10"/><path d="M17 21V3c-2 1-3 4-3 8h3"/>',
  takeaway: '<path d="M6 8h12l-1.2 13H7.2L6 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><path d="M10 13h4"/>', flame: '<path d="M12 22c4 0 7-2.8 7-7 0-3.5-2.4-5.6-3.6-8.5-.9 1.9-2 2.8-3.4 3-.2-3-1.6-5.6-4-7.5.3 4-3 6.2-3 11 0 4.2 3 9 7 9z"/>',
  star: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>', clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  backspace: '<path d="M21 5H9l-6 7 6 7h12z"/><path d="M12.5 9.5l5 5M17.5 9.5l-5 5"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>', user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.5 4.5-7 8-7s7 2.5 8 7"/>',
  id: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2.2"/><path d="M5.8 16c.6-1.6 1.8-2.4 3.2-2.4s2.6.8 3.2 2.4M14.5 10h4M14.5 13.5h3"/>',
  spark: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8"/>', leaf: '<path d="M5 19c0-8 5-14 15-14 0 10-6 15-14 15"/><path d="M5 19l8-8"/>',
  wave: '<path d="M8.5 8.5a5 5 0 0 1 0 7M12 5a10 10 0 0 1 0 14M15.5 2a15 15 0 0 1 0 20"/>', globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.8 3 2.8 15 0 18M12 3c-2.8 3-2.8 15 0 18"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16v4z"/>', chev: '<path d="M9 6l6 6-6 6"/>', receipt: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
};
const ic = (n, s = 40, w = 2.2) => `<svg class="ic" viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${IC[n]}</svg>`;

/* ---------------------------------------------------------------- temas */
const THEMES = {
  brasa: {
    name: 'Brasa 2.0', store: 'Brasa', status: 'Atualizada',
    tag: 'Steakhouse premium com fogo de verdade',
    concept: 'A foto do burger entre chamas domina a tela de descanso, com zoom lento e brasas subindo em tempo real. O cardápio fica escuro e aconchegante, com fotos recortadas iluminadas por um brilho quente.',
    motion: ['Brasas animadas subindo sobre a foto', 'Zoom cinematográfico lento na foto de abertura', 'Promoções que se alternam no rodapé', 'Produto sobe em tela cheia com a foto ampliada'],
    palette: ['#120E0C', '#2A221D', '#EC7433', '#F4B63F', '#F7EFE6'], fonts: 'DM Serif Display + Manrope', refs: 'Madero, Outback, hamburguerias premium',
    logo: s => `<div class="logo lg-brasa" style="--s:${s}">${ic('flame', 52 * s, 2)}<div><b>BRASA</b><small>BURGER &amp; STEAK</small></div></div>`,
    product: 'full',
  },
  vitrine: {
    name: 'Vitrine', store: 'mordida.', status: 'Nova',
    tag: 'Cardápio em vídeo, no estilo stories',
    concept: 'Cada produto ocupa a tela inteira com a foto em close, como um story. O cliente desliza pelo cardápio, e o texto e os botões flutuam em vidro fosco por cima da comida.',
    motion: ['Tela de descanso em stories com barra de progresso', 'Troca de fotos com zoom e fade', 'Cardápio em rolagem vertical com encaixe por produto', 'Painel de produto em vidro fosco sobre a foto'],
    palette: ['#0A0A0A', '#1E1E1E', '#FF5B2E', '#FFD23F', '#FFFFFF'], fonts: 'Syne + Onest', refs: 'Stories do Instagram, iFood, TikTok',
    logo: s => `<div class="logo lg-vitrine" style="--s:${s}"><b>mordida<i>.</i></b></div>`,
    product: 'sheet',
  },
  estudio: {
    name: 'Estúdio', store: 'forma', status: 'Nova',
    tag: 'Clean, claro e com produtos flutuando',
    concept: 'Fundo claro de estúdio fotográfico, com os lanches recortados flutuando sobre discos de cor. Um carrossel gira os destaques e os cards inclinam levemente quando tocados, como um app de produto premium.',
    motion: ['Produtos flutuando com sombra que respira', 'Carrossel de destaques com troca de cor de fundo', 'Cards com inclinação 3D ao toque', 'Produto abre girando para o centro'],
    palette: ['#EEF1F5', '#FFFFFF', '#2F55F4', '#FFC83D', '#0E1A2B'], fonts: 'Sora + Figtree', refs: 'Apple Store, Sweetgreen, apps de delivery premium',
    logo: s => `<div class="logo lg-estudio" style="--s:${s}"><span class="lg-dot"></span><b>forma</b><small>burger studio</small></div>`,
    product: 'center',
  },
  neon: {
    name: 'Neon 2.0', store: 'NEON/', status: 'Atualizada',
    tag: 'Noite urbana, energia de fliperama',
    concept: 'Texto correndo em faixas pela tela, anel de luz girando em volta do burger e letreiro que pisca. O cardápio vira um mosaico de fotos com bordas de neon, feito para o público jovem e a madrugada.',
    motion: ['Faixas de texto correndo em sentidos opostos', 'Anel de neon girando em volta do produto', 'Letreiro com cintilação de neon', 'Borda luminosa animada no destaque do cardápio'],
    palette: ['#07070C', '#1C1C2A', '#C8FF2E', '#FF3EA5', '#F4F4FA'], fonts: 'Unbounded + Rubik', refs: 'Taco Bell, smash burgers de rua, arcades',
    logo: s => `<div class="logo lg-neon" style="--s:${s}"><b>NEON<i>/</i></b><small>SMASH CLUB</small></div>`,
    product: 'full',
  },
  diner: {
    name: 'Diner 58', store: 'Diner 58', status: 'Nova',
    tag: 'Lanchonete americana dos anos 50',
    concept: 'Letreiro com lâmpadas que acendem em sequência, piso quadriculado correndo e milkshake em destaque. O cardápio parece a lousa de um diner, com fotos redondas e preços em selos vermelhos.',
    motion: ['Lâmpadas do letreiro acendendo em sequência', 'Faixa quadriculada em movimento', 'Fotos redondas balançando', 'Selo de preço que gira ao adicionar'],
    palette: ['#FFF4E2', '#FFFFFF', '#D3202A', '#8FD5C7', '#2A1512'], fonts: 'Bungee + Yellowtail + Nunito', refs: 'Johnny Rockets, Steak n Shake, diners americanos',
    logo: s => `<div class="logo lg-diner" style="--s:${s}"><b>Diner</b><i>58</i><small>BURGERS · SHAKES</small></div>`,
    product: 'center',
  },
};

/* ---------------------------------------------------------------- helpers de marcação */
function pimg(p, cls = '') {
  if (p.combo) return `<div class="stack ${cls}">${p.stack.map((k, i) => `<img src="${im(k)}" alt="" class="st st${i}">`).join('')}</div>`;
  if (p.cut) return `<img class="cut ${cls}" src="${im(p.cut)}" alt="${esc(p.name)}">`;
  return `<img class="ph ${cls}" src="${im(p.photo)}" alt="${esc(p.name)}">`;
}
function tagHtml(p) {
  if (p.soldout) return `<span class="tag tag-out">${t('soldout')}</span>`;
  if (p.tag === 'top') return `<span class="tag tag-top">${ic('star', 22, 2.4)}${t('top')}</span>`;
  if (p.tag === 'new') return `<span class="tag tag-new">${t('new')}</span>`;
  if (p.tag === 'veg') return `<span class="tag tag-veg">${ic('leaf', 22, 2.4)}${t('veg')}</span>`;
  return '';
}
const catName = c => c[S.lang];
const itemsOf = cid => P.filter(p => p.cat === cid);
function qtyCtl(act, id, n, size = '') {
  return `<div class="qty ${size}"><button type="button" class="qb" data-act="${act}" data-id="${id}" data-d="-1" aria-label="Diminuir">${ic('minus', 34, 2.8)}</button><span class="qn">${n}</span><button type="button" class="qb qb-plus" data-act="${act}" data-id="${id}" data-d="1" aria-label="Aumentar">${ic('plus', 34, 2.8)}</button></div>`;
}
function langPills() {
  return `<div class="langs">${['pt', 'en', 'es'].map(l => `<button type="button" class="lp ${S.lang === l ? 'on' : ''}" data-act="lang" data-id="${l}">${l.toUpperCase()}</button>`).join('')}<button type="button" class="lp lp-ic ${S.a11y ? 'on' : ''}" data-act="a11y" aria-label="${t('a11y')}">${ic('access', 34, 2)}</button></div>`;
}
function topbar(step, back) {
  const th = THEMES[S.theme];
  return `<header class="tb">
    <div class="tb-row">${th.logo(0.78)}
      <div class="tb-act">
        <button type="button" class="tbb tbb-ic ${S.a11y ? 'on' : ''}" data-act="a11y" aria-label="${t('a11y')}">${ic('access', 34, 2)}</button>
        ${back ? `<button type="button" class="tbb" data-act="go" data-id="${back}">${ic('back', 30, 2.6)}${t('back')}</button>` : ''}
        <button type="button" class="tbb tbb-x" data-act="reset">${ic('close', 28, 2.6)}${t('cancel')}</button>
      </div></div>
    ${step != null ? `<div class="steps">${t('steps').map((s, i) => `<div class="stp ${i < step ? 'done' : ''} ${i === step ? 'cur' : ''}"><span class="stp-bar"><i></i></span><span class="stp-l">${i < step ? ic('check', 22, 3) : (i + 1) + '.'} ${s}</span></div>`).join('')}</div>` : ''}
  </header>`;
}
function cartBar() {
  const n = cartCount();
  return `<div class="cbar-wrap"><button type="button" class="cbar ${n ? '' : 'is-empty'}" data-act="go" data-id="cart" id="cartBtn" ${n ? '' : 'disabled'}>
    <span class="cbar-ic">${ic('bag', 54, 2)}<b class="cbar-n" id="cartN">${n}</b></span>
    <span class="cbar-t"><small>${n ? t('bag') + ' · ' + t('items')(n) : t('empty')}</small><strong id="cartTotal">${brl(cartTotal())}</strong></span>
    <span class="cbar-go">${t('seeBag')}${ic('arrow', 32, 2.6)}</span></button></div>`;
}
function addBtn(p, cls = '') {
  if (p.soldout) return `<span class="addb addb-out ${cls}">${t('soldout')}</span>`;
  return `<button type="button" class="addb ${cls}" data-act="open" data-id="${p.id}" aria-label="${t('add')} ${esc(p.name)}">${ic('plus', 38, 3)}</button>`;
}

/* ---------------------------------------------------------------- telas: descanso */
function attract_brasa() {
  return `<div class="scr att att-brasa" data-act="startAny">
    <div class="kb"><img src="${im('hero_flame')}" alt="Burgers na brasa" class="kb-img"></div>
    <canvas class="embers" id="embers" width="1080" height="1920"></canvas>
    <div class="br-shade"></div>
    <div class="att-top">${THEMES.brasa.logo(1)}${langPills()}</div>
    <div class="br-copy">
      <span class="eyebrow">${ic('flame', 30, 2)} Grelhado na brasa · feito na hora</span>
      <h1>Fogo alto.<br><em>Sabor que marca.</em></h1>
      <div class="ticker" id="ticker"><span class="tk on"><b>Combo Duplo Bacon</b> ${brl(52.9)}</span><span class="tk"><b>Nova Costela Defumada</b> ${brl(46.9)}</span><span class="tk"><b>Milkshake de morango</b> ${brl(18.9)}</span></div>
    </div>
    <div class="att-bottom">
      <div class="tap-hint"><span class="tap-ring"></span>${ic('tap', 44, 2)}${t('start')}</div>
      <div class="att-btns"><button type="button" class="btn primary xl" data-act="start" data-id="here">${ic('dine', 44)}${t('here')}</button><button type="button" class="btn ghost xl" data-act="start" data-id="go">${ic('takeaway', 44)}${t('go')}</button></div>
    </div></div>`;
}
const VIT_SLIDES = [
  { img: 'hero_double', k: 'Mais pedido', h: 'Duplo<br>Bacon', p: 42.9 },
  { img: 'scene_hand', k: 'Novidade', h: 'Costela<br>Defumada', p: 46.9 },
  { img: 'p_shake', k: 'Pra acompanhar', h: 'Milkshake<br>de morango', p: 18.9 },
  { img: 'scene_trio', k: 'Pra dividir', h: 'Combo<br>Casal', p: 89.9 },
];
function attract_vitrine() {
  return `<div class="scr att att-vitrine" data-act="startAny">
    ${VIT_SLIDES.map((s, i) => `<div class="vs ${i === 0 ? 'on' : ''}" data-i="${i}"><img src="${im(s.img)}" alt=""><div class="vs-scrim"></div></div>`).join('')}
    <div class="vs-bars">${VIT_SLIDES.map((s, i) => `<span class="vb"><i class="${i === 0 ? 'run' : ''}"></i></span>`).join('')}</div>
    <div class="att-top">${THEMES.vitrine.logo(1.1)}${langPills()}</div>
    <div class="vs-copy">${VIT_SLIDES.map((s, i) => `<div class="vc ${i === 0 ? 'on' : ''}"><span class="vc-k">${s.k}</span><h1>${s.h}</h1><span class="vc-p">${brl(s.p)}</span></div>`).join('')}</div>
    <div class="att-bottom glass">
      <div class="tap-hint">${ic('tap', 44, 2)}${t('start')}</div>
      <div class="att-btns"><button type="button" class="btn primary xl" data-act="start" data-id="here">${ic('dine', 44)}${t('here')}</button><button type="button" class="btn glassb xl" data-act="start" data-id="go">${ic('takeaway', 44)}${t('go')}</button></div>
    </div></div>`;
}
const EST_SHOW = [
  { k: 'c_double', c: '#2F55F4', n: 'Duplo Bacon', p: 42.9 }, { k: 'c_costela', c: '#FFC83D', n: 'Costela Defumada', p: 46.9 },
  { k: 'c_fries', c: '#FF7A59', n: 'Batata frita', p: 14.9 }, { k: 'c_chicken', c: '#7BC8A4', n: 'Crispy Chicken', p: 34.9 },
];
function attract_estudio() {
  return `<div class="scr att att-estudio" data-act="startAny">
    <div class="att-top">${THEMES.estudio.logo(1.1)}${langPills()}</div>
    <div class="es-copy"><h1>Monte.<br>Toque.<br><span>Saboreie.</span></h1><p>Burgers artesanais montados na hora, do seu jeito.</p></div>
    <div class="es-stage">
      ${EST_SHOW.map((s, i) => `<div class="es-disc ${i === 0 ? 'on' : ''}" style="--c:${s.c}"></div>`).join('')}
      ${EST_SHOW.map((s, i) => `<div class="es-item ${i === 0 ? 'on' : ''}"><img src="${im(s.k)}" alt=""><span class="es-shadow"></span></div>`).join('')}
      <div class="es-label">${EST_SHOW.map((s, i) => `<div class="el ${i === 0 ? 'on' : ''}"><b>${s.n}</b><span>${brl(s.p)}</span></div>`).join('')}</div>
      <div class="es-dots">${EST_SHOW.map((s, i) => `<i class="${i === 0 ? 'on' : ''}"></i>`).join('')}</div>
    </div>
    <div class="att-bottom">
      <div class="tap-hint">${ic('tap', 44, 2)}${t('start')}</div>
      <div class="att-btns"><button type="button" class="btn primary xl" data-act="start" data-id="here">${ic('dine', 44)}${t('here')}</button><button type="button" class="btn soft xl" data-act="start" data-id="go">${ic('takeaway', 44)}${t('go')}</button></div>
    </div></div>`;
}
function attract_neon() {
  const row = (txt, dir, cls) => `<div class="mq ${dir} ${cls}"><div class="mq-in">${(txt + ' ').repeat(6)}</div><div class="mq-in" aria-hidden="true">${(txt + ' ').repeat(6)}</div></div>`;
  return `<div class="scr att att-neon" data-act="startAny">
    <div class="mqs" aria-hidden="true">${row('SMASH ✦ BACON ✦ CHEDDAR ✦', 'l', 'o1')}${row('FOME DE MADRUGADA ✦', 'r', 'o2')}${row('SMASH ✦ BACON ✦ CHEDDAR ✦', 'l', 'fill')}${row('ABERTO ATÉ 4H ✦', 'r', 'o2')}${row('SMASH ✦ BACON ✦ CHEDDAR ✦', 'l', 'o1')}${row('PEDE AÍ ✦ PEDE AÍ ✦', 'r', 'o2')}</div>
    <div class="scan"></div>
    <div class="att-top">${THEMES.neon.logo(1.15)}${langPills()}</div>
    <div class="ne-stage"><div class="ne-ring"></div><div class="ne-ring r2"></div><img src="${im('c_double')}" alt="Duplo Bacon" class="ne-burger">
      <div class="ne-sticker"><small>COMBO DA NOITE</small><b>${brl(52.9)}</b></div></div>
    <div class="att-bottom">
      <h1 class="ne-h flick">PEDE AÍ.</h1>
      <div class="tap-hint"><span class="blink"></span>${t('start').toUpperCase()}</div>
      <div class="att-btns"><button type="button" class="btn primary xl" data-act="start" data-id="here">${ic('dine', 44)}${t('here')}</button><button type="button" class="btn ghost xl" data-act="start" data-id="go">${ic('takeaway', 44)}${t('go')}</button></div>
    </div></div>`;
}
function bulbs(n, cls) { let s = ''; for (let i = 0; i < n; i++) s += `<i style="--i:${i}"></i>`; return `<div class="bulbs ${cls}">${s}</div>`; }
function attract_diner() {
  return `<div class="scr att att-diner" data-act="startAny">
    <div class="att-top">${langPills()}</div>
    <div class="dn-sign">${bulbs(22, 'bt')}${bulbs(22, 'bb')}${bulbs(9, 'bl')}${bulbs(9, 'br')}
      <span class="dn-open">Aberto</span><b class="dn-name">Diner</b><span class="dn-58">58</span><small>BURGERS · SHAKES · FRITAS</small></div>
    <div class="dn-pics">
      <div class="dn-pic p1"><img src="${im('p_shake')}" alt="Milkshake"><span class="dn-price">${brl(18.9)}</span></div>
      <div class="dn-pic p2"><img src="${im('scene_classic')}" alt="Burger"><span class="dn-price">${brl(32.9)}</span></div>
      <div class="dn-pic p3"><img src="${im('p_sundae')}" alt="Sundae"><span class="dn-price">${brl(12.9)}</span></div>
    </div>
    <p class="dn-slogan">Milkshake batido na hora<br>desde a primeira mordida.</p>
    <div class="att-bottom">
      <div class="tap-hint neon-script">${t('start')}</div>
      <div class="att-btns"><button type="button" class="btn primary xl" data-act="start" data-id="here">${ic('dine', 44)}${t('here')}</button><button type="button" class="btn mint xl" data-act="start" data-id="go">${ic('takeaway', 44)}${t('go')}</button></div>
    </div>
    <div class="checker"></div></div>`;
}

/* ---------------------------------------------------------------- telas: cardápio */
function menu_brasa() {
  const rail = CATS.map((c, i) => `<button type="button" class="rail-b ${S.cat === c.id ? 'on' : ''}" data-act="cat" data-id="${c.id}"><span class="rail-i"><img src="${im(c.img)}" alt=""></span>${catName(c)}</button>`).join('');
  const promos = P.filter(p => p.combo);
  const sec = CATS.map(c => `<section class="msec" id="sec-${c.id}" data-cat="${c.id}"><h2>${catName(c)}</h2><div class="grid2">${itemsOf(c.id).map(p => `
    <article class="card ${p.soldout ? 'out' : ''}" data-act="${p.soldout ? '' : 'open'}" data-id="${p.id}">
      <div class="card-img ${p.cut || p.combo ? 'is-cut' : 'is-ph'}">${pimg(p)}${tagHtml(p)}</div>
      <h3>${p.name}</h3><p>${p.desc}</p>
      <div class="card-f"><span class="price">${brl(p.price)}${p.old ? `<s>${brl(p.old)}</s>` : ''}</span>${addBtn(p)}</div>
    </article>`).join('')}</div></section>`).join('');
  return `<div class="scr menu menu-brasa">${topbar(0)}
    <div class="mb-body"><nav class="rail" aria-label="Categorias">${rail}</nav>
      <div class="mscroll" id="mscroll" data-scroll="menu">
        <div class="promo-car" id="promoCar">${promos.map((p, i) => `<div class="pc ${i === 0 ? 'on' : ''}" data-act="open" data-id="${p.id}"><img src="${im(p.photo)}" alt=""><div class="pc-scrim"></div><div class="pc-t"><span>${p.tag === 'new' ? 'Novidade' : 'Combo da casa'}</span><b>${p.name}</b><em>${brl(p.price)} <s>${brl(p.old)}</s></em></div></div>`).join('')}<div class="pc-dots">${promos.map((p, i) => `<i class="${i === 0 ? 'on' : ''}"></i>`).join('')}</div></div>
        ${sec}<div class="mpad"></div></div></div>
    ${cartBar()}</div>`;
}
function menu_vitrine() {
  const chips = CATS.map(c => `<button type="button" class="vchip ${S.cat === c.id ? 'on' : ''}" data-act="cat" data-id="${c.id}">${catName(c)}</button>`).join('');
  const list = CATS.map(c => itemsOf(c.id).map((p, i) => `
    <article class="vcard ${p.soldout ? 'out' : ''} ${p.photo ? 'has-ph' : 'no-ph'}" data-cat="${c.id}" ${i === 0 ? `id="sec-${c.id}"` : ''}>
      <div class="vcard-bg">${p.photo ? `<img src="${im(p.photo)}" alt="${esc(p.name)}" class="vph">` : `<div class="vcolor"></div><img src="${im(p.cut)}" alt="${esc(p.name)}" class="vcut">`}</div>
      <div class="vcard-scrim"></div>
      <div class="vcard-t">${tagHtml(p)}<span class="vcat">${catName(c)}</span><h2>${p.name}</h2><p>${p.desc}</p>
        <div class="vcard-f"><span class="vprice">${brl(p.price)}${p.old ? `<s>${brl(p.old)}</s>` : ''}</span>
        ${p.soldout ? `<span class="btn glassb md">${t('soldout')}</span>` : `<button type="button" class="btn glassb md" data-act="open" data-id="${p.id}">${t('customize')}</button><button type="button" class="btn primary md" data-act="quick" data-id="${p.id}">${ic('plus', 34, 3)}${t('add')}</button>`}</div></div>
    </article>`).join('')).join('');
  return `<div class="scr menu menu-vitrine">
    <div class="vfeed" id="mscroll" data-scroll="menu">${list}</div>
    <div class="vtop">${topbar(0)}<nav class="vchips" aria-label="Categorias">${chips}</nav></div>
    ${cartBar()}</div>`;
}
function menu_estudio() {
  const feat = [byId('duplo'), byId('costela'), byId('chicken'), byId('fritas')];
  const colors = ['#2F55F4', '#FFC83D', '#7BC8A4', '#FF7A59'];
  const pills = CATS.map(c => `<button type="button" class="epill ${S.cat === c.id ? 'on' : ''}" data-act="cat" data-id="${c.id}"><img src="${im(c.img)}" alt="">${catName(c)}</button>`).join('');
  const sec = CATS.map(c => `<section class="msec" id="sec-${c.id}" data-cat="${c.id}"><h2>${catName(c)}<span>${itemsOf(c.id).length}</span></h2><div class="grid3">${itemsOf(c.id).map((p, i) => `
    <article class="ecard tilt ${p.soldout ? 'out' : ''}" data-act="${p.soldout ? '' : 'open'}" data-id="${p.id}" style="--c:${colors[i % 4]}">
      <div class="ecard-img ${p.cut || p.combo ? 'is-cut' : 'is-ph'}"><span class="edisc"></span>${pimg(p)}</div>${tagHtml(p)}
      <h3>${p.name}</h3><div class="card-f"><span class="price">${brl(p.price)}</span>${addBtn(p, 'sm')}</div>
    </article>`).join('')}</div></section>`).join('');
  return `<div class="scr menu menu-estudio">${topbar(0)}
    <div class="mscroll" id="mscroll" data-scroll="menu">
      <div class="efeat" id="efeat">${feat.map((p, i) => `<div class="ef" style="--c:${colors[i]}" data-act="open" data-id="${p.id}"><div class="ef-t"><span>${i === 0 ? t('top') : i === 1 ? t('new') : 'Destaque'}</span><b>${p.name}</b><em>${brl(p.price)}</em><span class="ef-cta">${t('add')} ${ic('arrow', 28, 2.6)}</span></div><img src="${im(p.cut)}" alt="" class="ef-img"></div>`).join('')}</div>
      <nav class="epills" aria-label="Categorias">${pills}</nav>
      ${sec}<div class="mpad"></div></div>
    ${cartBar()}</div>`;
}
function menu_neon() {
  const tabs = CATS.map(c => `<button type="button" class="ntab ${S.cat === c.id ? 'on' : ''}" data-act="cat" data-id="${c.id}">${catName(c)}</button>`).join('');
  const sec = CATS.map(c => { const items = itemsOf(c.id); return `<section class="msec" id="sec-${c.id}" data-cat="${c.id}"><h2><span>//</span> ${catName(c)}</h2><div class="bento">${items.map((p, i) => {
    const big = i === 0; const wide = !big && i === items.length - 1 && items.length % 2 === 0;
    return `<article class="ntile ${big ? 'big' : ''} ${wide ? 'wide' : ''} ${p.soldout ? 'out' : ''} ${p.cut && !p.combo ? 'is-cut' : 'is-ph'}" data-act="${p.soldout ? '' : 'open'}" data-id="${p.id}">
      ${big ? '<span class="glow"></span>' : ''}<div class="ntile-in">
      <div class="ntile-img">${p.combo ? `<img src="${im(p.photo)}" alt="" class="ph">` : pimg(p)}</div>${tagHtml(p)}
      <div class="ntile-t"><h3>${p.name}</h3>${big ? `<p>${p.desc}</p>` : ''}<div class="card-f"><span class="price">${brl(p.price)}</span>${addBtn(p, 'sq')}</div></div></div></article>`; }).join('')}</div></section>`; }).join('');
  return `<div class="scr menu menu-neon">${topbar(0)}
    <nav class="ntabs" aria-label="Categorias">${tabs}</nav>
    <div class="mscroll" id="mscroll" data-scroll="menu">
      <div class="nhero" data-act="open" data-id="cb-duplo"><span class="glow"></span><div class="nhero-in"><div class="nhero-t"><small>COMBO DA NOITE · ATÉ 4H</small><b>DUPLO BACON + BATATA + BEBIDA</b><em>${brl(52.9)} <s>${brl(62.7)}</s></em></div><img src="${im('c_double')}" alt="" class="nh1"><img src="${im('c_fries')}" alt="" class="nh2"></div></div>
      ${sec}<div class="mpad"></div></div>
    ${cartBar()}</div>`;
}
function menu_diner() {
  const tabs = CATS.map(c => `<button type="button" class="jbtn ${S.cat === c.id ? 'on' : ''}" data-act="cat" data-id="${c.id}"><span class="jl"></span>${catName(c)}</button>`).join('');
  const sec = CATS.map(c => `<section class="msec" id="sec-${c.id}" data-cat="${c.id}"><h2><span>★</span> ${catName(c)} <span>★</span></h2><div class="dlist">${itemsOf(c.id).map(p => `
    <article class="drow ${p.soldout ? 'out' : ''}" data-act="${p.soldout ? '' : 'open'}" data-id="${p.id}">
      <div class="dcirc"><img src="${im(p.photo || p.cut)}" alt="${esc(p.name)}" class="${p.photo ? 'ph' : 'cutc'}"></div>
      <div class="drow-t"><div class="drow-h"><h3>${p.name}</h3><span class="dots"></span></div><p>${p.desc}</p>${tagHtml(p)}</div>
      <div class="drow-r"><span class="dprice">${brl(p.price)}</span>${addBtn(p)}</div>
    </article>`).join('')}</div></section>`).join('');
  return `<div class="scr menu menu-diner">
    <div class="dn-head">${bulbs(18, 'hb')}${topbar(0)}</div>
    <nav class="jbox" aria-label="Categorias">${tabs}</nav>
    <div class="mscroll" id="mscroll" data-scroll="menu">
      <div class="dspecial" data-act="open" data-id="cb-duplo"><div class="ds-t"><span class="neon-script">Especial do dia</span><b>Combo Duplo Bacon</b><p>Burger duplo, batata e milkshake ou bebida à escolha</p><em>${brl(52.9)}</em></div><div class="ds-img"><img src="${im('scene_meal')}" alt=""></div></div>
      ${sec}<div class="mpad"></div></div>
    ${cartBar()}</div>`;
}

/* ---------------------------------------------------------------- modal de produto */
function productModal() {
  const e = S.edit, p = byId(e.pid);
  const unit = lineUnit(e), total = unit * e.qty;
  const isBurger = p.burger, isCombo = p.combo;
  const optRow = (label, opts, key) => `<div class="opt"><span class="lbl">${label}</span><div class="opt-g">${opts.map(o => { const q = byId(o.id); const on = e.combo && e.combo[key] === o.id; return `<button type="button" class="oc ${on ? 'on' : ''}" data-act="optPick" data-k="${key}" data-id="${o.id}" aria-pressed="${on}"><span class="oc-i"><img src="${im(q.photo || q.cut)}" alt=""></span><span class="oc-n">${q.name}</span><span class="oc-p">${o.add ? '+ ' + brl(o.add) : 'incluso'}</span>${on ? `<span class="oc-c">${ic('check', 24, 3.2)}</span>` : ''}</button>`; }).join('')}</div></div>`;
  let body = '';
  if (isBurger) {
    body += `<button type="button" class="combo-t ${e.combo ? 'on' : ''}" data-act="toggleCombo" aria-pressed="${!!e.combo}">
      <span class="ct-img"><img src="${im('c_fries')}" alt="" class="ct1"><img src="${im('p_hibisco')}" alt="" class="ct2"></span>
      <span class="ct-t"><small>${t('makeCombo')}</small><b>${t('comboSub')}</b><em>+ ${brl(COMBO_ADD)} <span>${t('save')(brl(COMBO_SAVE))}</span></em></span>
      <span class="sw"><i></i></span></button>`;
    if (e.combo) body += `<div class="combo-opts">${optRow(t('side'), SIDE_OPTS, 'side')}${optRow(t('drink'), DRINK_OPTS, 'drink')}</div>`;
    body += `<div class="blk"><span class="lbl">${t('extras')}</span>${EXTRAS.map(x => `<div class="xrow"><div><b>${x.name}</b><span>+ ${brl(x.price)}</span></div>${qtyCtl('extra', x.id, e.extras[x.id] || 0, 'sm')}</div>`).join('')}</div>`;
    body += `<div class="blk"><span class="lbl">${t('remove')}</span><div class="chips">${REMOVES.map(r => { const on = e.removed.includes(r); return `<button type="button" class="chip ${on ? 'on' : ''}" data-act="rm" data-id="${esc(r)}" aria-pressed="${on}">${on ? ic('check', 26, 3) : ''}${r}</button>`; }).join('')}</div></div>`;
  } else if (isCombo) {
    body += `<div class="combo-opts">${optRow(t('side'), SIDE_OPTS, 'side')}${optRow(t('drink'), DRINK_OPTS, 'drink')}</div>`;
  }
  const hero = p.cut ? `<img src="${im(p.cut)}" alt="${esc(p.name)}" class="pm-cut">` : `<img src="${im(p.photo)}" alt="${esc(p.name)}" class="pm-ph">`;
  return `<div class="ov" data-act="closeModal"></div>
  <div class="pm pm-${THEMES[S.theme].product}" role="dialog" aria-label="${esc(p.name)}">
    <div class="pm-hero ${p.cut ? 'is-cut' : 'is-ph'}">${hero}<button type="button" class="pm-x" data-act="closeModal" aria-label="Fechar">${ic('close', 40, 2.8)}</button>${tagHtml(p)}</div>
    <div class="pm-body" data-scroll="pm">
      <div class="pm-head"><h2>${p.name}</h2><p>${p.desc}</p><span class="price big">${brl(p.price)}${p.old ? `<s>${brl(p.old)}</s>` : ''}</span></div>
      ${body}
    </div>
    <div class="pm-foot">${qtyCtl('eqty', 'x', e.qty, 'lg')}<button type="button" class="btn primary lg grow" data-act="addEdit" id="addBtn">${ic('bag', 40)}${t('add')} · <span class="tabnum">${brl(total)}</span></button></div>
  </div>`;
}
function upsellCombo() {
  return `<div class="ov"></div><div class="up up-combo" role="dialog" aria-label="${t('upComboT')}">
    <div class="up-img"><img src="${im('c_fries')}" alt="" class="u1"><img src="${im('p_hibisco')}" alt="" class="u2"><span class="up-badge">+ ${brl(COMBO_ADD)}</span></div>
    <h2>${t('upComboT')}</h2><p>${t('upComboS')} <b>${brl(COMBO_ADD)}</b> · ${t('save')(brl(COMBO_SAVE))}</p>
    <div class="up-btns"><button type="button" class="btn ghost lg" data-act="upNo">${t('noThanks')}</button><button type="button" class="btn primary lg grow" data-act="upCombo">${ic('check', 38, 3)}${t('yesCombo')}</button></div></div>`;
}
function upsellDessert() {
  const ds = ['sundae', 'vulcao', 'cookie'].map(byId);
  return `<div class="ov"></div><div class="up up-dess" role="dialog" aria-label="${t('upDessT')}">
    <h2>${t('upDessT')}</h2><p>${t('upDessS')}</p>
    <div class="up-grid">${ds.map(p => { const inCart = S.cart.some(l => l.pid === p.id); return `<button type="button" class="upd ${inCart ? 'on' : ''}" data-act="upAddDessert" data-id="${p.id}"><img src="${im(p.photo)}" alt=""><b>${p.name}</b><span>${brl(p.price)}</span><i>${inCart ? ic('check', 30, 3) : ic('plus', 30, 3)}</i></button>`; }).join('')}</div>
    <button type="button" class="btn primary lg" data-act="upDessDone">${S.cart.some(l => byId(l.pid).dessert) ? t('cont') : t('noDessert')}${ic('arrow', 36, 2.6)}</button></div>`;
}
function idleModal(sec) {
  return `<div class="ov"></div><div class="up up-idle" role="alertdialog" aria-label="${t('idleT')}">
    <div class="idle-ring"><svg viewBox="0 0 120 120"><circle cx="60" cy="60" r="52" class="ir-bg"/><circle cx="60" cy="60" r="52" class="ir-fg" style="stroke-dashoffset:${327 * (1 - sec / 15)}"/></svg><b id="idleSec">${sec}</b></div>
    <h2>${t('idleT')}</h2><p id="idleTxt">${t('idleS')(sec)}</p>
    <div class="up-btns"><button type="button" class="btn ghost lg" data-act="reset">${t('idleNo')}</button><button type="button" class="btn primary lg grow" data-act="idleStay">${t('idleYes')}</button></div></div>`;
}

/* ---------------------------------------------------------------- sacola */
function recs() {
  const has = f => S.cart.some(l => byId(l.pid)[f] || (l.combo && (f === 'drink' || f === 'side')));
  const pool = [];
  if (!has('drink')) pool.push('shake', 'manga', 'mocha');
  if (!S.cart.some(l => byId(l.pid).dessert)) pool.push('sundae', 'vulcao', 'cheesecake');
  if (!has('side')) pool.push('fritas', 'nachos');
  pool.push('nachos', 'cookie', 'shake', 'casquinha');
  const out = []; for (const id of pool) if (!out.includes(id) && !S.cart.some(l => l.pid === id)) out.push(id);
  return out.slice(0, 3).map(byId);
}
function screen_cart() {
  const lines = S.cart.map(l => { const p = byId(l.pid); return `<div class="cl" id="cl-${l.uid}">
      <div class="cl-img ${p.cut || p.combo ? 'is-cut' : 'is-ph'}">${pimg(p)}</div>
      <div class="cl-t"><div class="cl-h"><b>${p.name}</b><span class="tabnum">${brl(lineUnit(l) * l.qty)}</span></div>
        ${lineDesc(l).map(d => `<small>${d}</small>`).join('')}
        <div class="cl-f"><button type="button" class="tbb sm" data-act="delLine" data-id="${l.uid}">${ic('trash', 26, 2.2)}</button>${qtyCtl('lqty', l.uid, l.qty, 'sm')}</div></div></div>`; }).join('');
  const sv = cartSaved();
  return `<div class="scr cart">${topbar(1, 'menu')}
    <div class="body" data-scroll="cart">
      <div class="h-row"><h1>${t('bag')}</h1><span class="muted">${t('items')(cartCount())}</span></div>
      ${S.cart.length ? `<div class="clist">${lines}</div>` : `<div class="empty">${ic('bag', 90, 1.6)}<b>${t('empty')}</b><button type="button" class="btn primary lg" data-act="go" data-id="menu">${t('more')}</button></div>`}
      ${S.cart.length ? `<div class="recs"><div class="recs-h">${ic('spark', 38, 2)}<div><h2>${t('recTitle')}</h2><p>${t('recSub')}</p></div></div>
        <div class="recs-g">${recs().map(p => `<div class="rc"><div class="rc-img ${p.cut ? 'is-cut' : 'is-ph'}">${pimg(p)}</div><b>${p.name}</b><div class="rc-f"><span class="price">${brl(p.price)}</span><button type="button" class="addb" data-act="quick" data-id="${p.id}" aria-label="${t('add')} ${esc(p.name)}">${ic('plus', 36, 3)}</button></div></div>`).join('')}</div></div>` : ''}
    </div>
    <div class="foot">
      ${sv > 0 ? `<div class="saved">${ic('star', 28, 2.4)}${t('saved')(brl(sv))}</div>` : ''}
      <div class="tot"><span>${t('total')}</span><b class="tabnum" id="cartTot">${brl(cartTotal())}</b></div>
      <div class="foot-btns"><button type="button" class="btn ghost lg" data-act="go" data-id="menu">${t('more')}</button><button type="button" class="btn primary lg grow" data-act="checkout" ${S.cart.length ? '' : 'disabled'}>${t('checkout')}${ic('arrow', 36, 2.6)}</button></div>
    </div></div>`;
}

/* ---------------------------------------------------------------- CPF */
function cpfValid(d) {
  if (d.length !== 11 || /^(\d)\1+$/.test(d)) return false;
  const calc = n => { let s = 0; for (let i = 0; i < n; i++) s += +d[i] * (n + 1 - i); const r = (s * 10) % 11; return r === 10 ? 0 : r; };
  return calc(9) === +d[9] && calc(10) === +d[10];
}
function cpfMask(d) {
  const f = (d + '___________').slice(0, 11);
  const s = f.slice(0, 3) + '.' + f.slice(3, 6) + '.' + f.slice(6, 9) + '-' + f.slice(9, 11);
  return s.split('').map(c => c === '_' ? '<i>_</i>' : c).join('');
}
function screen_cpf() {
  const d = S.cpf, full = d.length === 11, ok = full && cpfValid(d);
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'del'];
  return `<div class="scr form">${topbar(2, 'cart')}
    <div class="body">
      <div class="f-ic">${ic('id', 64, 1.8)}<span class="pill-opt">Opcional</span></div>
      <h1>${t('cpfT')}</h1><p class="sub">${t('cpfS')}</p>
      <div class="field ${full ? (ok ? 'ok' : 'err') : ''}"><span class="fv tabnum">${cpfMask(d)}</span></div>
      <div class="fmsg ${full ? (ok ? 'ok' : 'err') : ''}">${full ? (ok ? ic('check', 30, 3) + t('valid') : t('invalid')) : 'Ex.: 529.982.247-25'}</div>
      <div class="keypad">${keys.map(k => `<button type="button" class="key ${k === 'del' || k === 'C' ? 'fn' : ''}" data-act="cpfKey" data-id="${k}" aria-label="${k === 'del' ? 'Apagar' : k === 'C' ? t('clear') : k}">${k === 'del' ? ic('backspace', 50, 2.2) : k === 'C' ? t('clear') : k}</button>`).join('')}</div>
    </div>
    <div class="foot"><div class="foot-btns"><button type="button" class="btn ghost lg" data-act="cpfSkip">${t('skip')}</button><button type="button" class="btn primary lg grow" data-act="cpfNext" ${d.length === 0 || ok ? '' : 'disabled'}>${t('cont')}${ic('arrow', 36, 2.6)}</button></div></div></div>`;
}
function screen_name() {
  const rows = ['QWERTYUIOP', 'ASDFGHJKLÇ', 'ZXCVBNM'];
  const ok = S.name.trim().length >= 2;
  return `<div class="scr form">${topbar(2, 'cpf')}
    <div class="body">
      <div class="f-ic">${ic('user', 64, 1.8)}</div>
      <h1>${t('nameT')}</h1><p class="sub">${t('nameS')}</p>
      <div class="field name"><span class="fv">${S.name ? esc(S.name) : `<em>${t('namePh')}</em>`}<span class="caret"></span></span><small class="cnt tabnum">${S.name.length}/12</small></div>
      <div class="kb-keys">${rows.map((r, i) => `<div class="kr">${r.split('').map(k => `<button type="button" class="key k" data-act="nameKey" data-id="${k}">${k}</button>`).join('')}${i === 2 ? `<button type="button" class="key k fn wide" data-act="nameKey" data-id="del" aria-label="Apagar">${ic('backspace', 46, 2.2)}</button>` : ''}</div>`).join('')}
        <div class="kr"><button type="button" class="key k space" data-act="nameKey" data-id=" ">${t('space')}</button></div></div>
    </div>
    <div class="foot"><div class="foot-btns"><button type="button" class="btn primary lg grow" data-act="go" data-id="pay" ${ok ? '' : 'disabled'}>${t('cont')}${ic('arrow', 36, 2.6)}</button></div></div></div>`;
}
function screen_pay() {
  const opts = [['pix', 'pix', t('pix'), t('pixS'), true], ['credit', 'card', t('credit'), t('creditS')], ['debit', 'card', t('debit'), t('debitS')], ['cash', 'cash', t('cash'), t('cashS')]];
  return `<div class="scr pay">${topbar(3, 'name')}
    <div class="body">
      <span class="kick">${t('payK')(esc(S.name.trim() || 'Rodrigo'))}</span><h1>${t('payT')}</h1>
      <div class="popts">${opts.map(([id, icn, n, s, fast], i) => `<button type="button" class="po ${fast ? 'hi' : ''}" data-act="pay" data-id="${id}" style="--d:${i * 70}ms"><span class="po-ic">${ic(icn, 66, 1.9)}</span><span class="po-t"><b>${n}${fast ? `<em>${t('fastest')}</em>` : ''}</b><small>${s}</small></span>${ic('chev', 44, 2.4)}</button>`).join('')}</div>
      <div class="sumbox"><span class="lbl">${t('summary')}</span>${S.cart.map(l => `<div class="sr"><span>${l.qty}× ${byId(l.pid).name}</span><span class="tabnum">${brl(lineUnit(l) * l.qty)}</span></div>`).join('')}
        <div class="sr tot"><span>${t('total')}</span><b class="tabnum">${brl(cartTotal())}</b></div>
        <div class="sr meta">${ic('receipt', 26, 2)}${S.cpf ? t('cpfNote') + ': ' + S.cpf.slice(0, 3) + '.***.***-' + S.cpf.slice(9) + ' · ' : ''}${S.mode === 'here' ? t('eatHere') : t('takeAway')}</div></div>
    </div></div>`;
}
function qrSvg() {
  const n = 29; let seed = 247; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const c = []; for (let r = 0; r < n; r++) { c.push([]); for (let k = 0; k < n; k++) c[r].push(rnd() < .47); }
  const fp = (r0, c0) => { for (let r = -1; r < 8; r++) for (let k = -1; k < 8; k++) { const rr = r0 + r, cc = c0 + k; if (rr < 0 || cc < 0 || rr >= n || cc >= n) continue; c[rr][cc] = r >= 0 && r <= 6 && k >= 0 && k <= 6 && (r === 0 || r === 6 || k === 0 || k === 6 || (r >= 2 && r <= 4 && k >= 2 && k <= 4)); } };
  fp(0, 0); fp(0, n - 7); fp(n - 7, 0);
  let rects = ''; for (let r = 0; r < n; r++) for (let k = 0; k < n; k++) if (c[r][k]) rects += `<rect x="${k}" y="${r}" width="1.03" height="1.03"/>`;
  return `<svg viewBox="-2 -2 ${n + 4} ${n + 4}" role="img" aria-label="QR Code Pix de exemplo"><rect x="-2" y="-2" width="${n + 4}" height="${n + 4}" fill="#fff"/><g fill="#111">${rects}</g></svg>`;
}
function screen_pix() {
  const ok = S.payStage === 2;
  return `<div class="scr pix">${topbar(3, ok ? null : 'pay')}
    <div class="body center">
      <span class="kick">${ic('pix', 32, 2)} Pix</span><h1>${t('pixT')}</h1><p class="sub">${t('pixS2')}</p>
      <div class="qr ${ok ? 'ok' : ''}">${qrSvg()}<span class="qr-scan"></span><span class="qr-c c1"></span><span class="qr-c c2"></span><span class="qr-c c3"></span><span class="qr-c c4"></span>
        <div class="qr-ok">${ic('check', 140, 3)}<b>${t('approved')}</b></div></div>
      <div class="pix-total"><small>${t('total')}</small><b class="tabnum">${brl(cartTotal())}</b></div>
      <div class="pix-st">${ok ? '' : `<span class="timer">${ic('clock', 32, 2.2)}${t('expires')} <b class="tabnum" id="pixTimer">05:00</b></span><span class="wait"><i></i><i></i><i></i>${t('waiting')}</span>`}</div>
    </div>
    <div class="foot">${ok ? '' : `<div class="foot-btns"><button type="button" class="btn ghost lg grow" data-act="go" data-id="pay">${t('change')}</button><button type="button" class="btn soft lg" data-act="simPay" title="Simula a confirmação do banco">Simular aprovação</button></div>`}</div></div>`;
}
function screen_card() {
  const st = S.payStage;
  return `<div class="scr cardpay">${topbar(3, st ? null : 'pay')}
    <div class="body center">
      <span class="kick">${ic('card', 32, 2)} ${S.pay === 'credit' ? t('credit') : t('debit')}</span><h1>${st === 2 ? t('approved') : t('cardT')}</h1><p class="sub">${st === 1 ? t('processing') : st === 2 ? '' : t('cardS')}</p>
      <div class="pos st${st}">
        <div class="pos-dev"><div class="pos-scr">${st === 2 ? ic('check', 90, 3) : st === 1 ? '<span class="spin"></span>' : `<b class="tabnum">${brl(cartTotal())}</b><small>${S.pay === 'credit' ? 'CRÉDITO' : 'DÉBITO'}</small>`}</div><div class="pos-keys">${'123456789'.split('').map(k => `<i>${k}</i>`).join('')}</div></div>
        <div class="pos-card"><span class="chipc"></span><span class="cnum">•••• •••• •••• 4417</span></div>
        <div class="waves">${ic('wave', 120, 1.6)}</div>
      </div>
      <div class="arrow-down">${ic('arrow', 60, 2.4)}</div>
    </div>
    <div class="foot">${st ? '' : `<div class="foot-btns"><button type="button" class="btn ghost lg grow" data-act="go" data-id="pay">${t('change')}</button></div>`}</div></div>`;
}
function screen_done() {
  const cash = S.pay === 'cash';
  const r = S.cart.map(l => `<div class="rr"><span>${l.qty}x ${byId(l.pid).name.toUpperCase()}</span><span>${brl(lineUnit(l) * l.qty).replace('R$ ', '')}</span></div>`).join('');
  return `<div class="scr done">
    <canvas class="confetti" id="confetti" width="1080" height="1920"></canvas>
    <header class="done-top">${THEMES[S.theme].logo(0.9)}</header>
    <div class="body center">
      <div class="big-check">${ic(cash ? 'cash' : 'check', 130, 3)}</div>
      <span class="kick">${cash ? t('cashNote') : t('approved')}</span>
      <h1>${cash ? t('doneCash') : t('doneT')}</h1>
      <div class="ticket"><small>${t('yourNo')}</small><b class="tabnum" id="orderNo">000</b><p>${t('callYou')(esc((S.name.trim() || 'Rodrigo').toUpperCase()))}</p><span class="eta">${ic('clock', 30, 2)}${t('eta')}</span></div>
      <div class="printer"><div class="slot"></div><div class="paper"><b>${THEMES[S.theme].store.toUpperCase()}</b><span>SENHA ${String(S.orderNo).padStart(3, '0')} · ${S.mode === 'here' ? 'COMER AQUI' : 'PARA LEVAR'}</span>${r}<div class="rr t"><span>TOTAL</span><span>${brl(cartTotal()).replace('R$ ', '')}</span></div><span>${cash ? 'PAGAR NO CAIXA' : 'PAGO VIA ' + (S.pay === 'pix' ? 'PIX' : S.pay === 'credit' ? 'CRÉDITO' : 'DÉBITO')}</span></div></div>
      <div class="sent">${ic('check', 26, 3)}${t('sent')} · Regem</div>
    </div>
    <div class="foot"><button type="button" class="btn soft lg" data-act="reset">${t('newOrder')}</button><small class="muted center-t" id="backIn">${t('backIn')(20)}</small></div></div>`;
}

/* ---------------------------------------------------------------- render */
const SCREENS = {
  attract: () => ({ brasa: attract_brasa, vitrine: attract_vitrine, estudio: attract_estudio, neon: attract_neon, diner: attract_diner })[S.theme](),
  menu: () => ({ brasa: menu_brasa, vitrine: menu_vitrine, estudio: menu_estudio, neon: menu_neon, diner: menu_diner })[S.theme](),
  cart: screen_cart, cpf: screen_cpf, name: screen_name, pay: screen_pay, pix: screen_pix, card: screen_card, done: screen_done,
};
let kiosk, screenEl, modalEl, fxEl, timers = [], raf = 0, idleLast = Date.now(), idleSec = 0;
function clearTimers() { timers.forEach(clearInterval); timers.forEach(clearTimeout); timers = []; cancelAnimationFrame(raf); raf = 0; }
function render(anim) {
  const scrolls = {};
  screenEl.querySelectorAll('[data-scroll]').forEach(el => scrolls[el.dataset.scroll] = el.scrollTop);
  screenEl.innerHTML = SCREENS[S.screen]();
  screenEl.querySelectorAll('[data-scroll]').forEach(el => { if (!anim && scrolls[el.dataset.scroll] != null) el.scrollTop = scrolls[el.dataset.scroll]; });
  if (anim) { screenEl.classList.remove('enter'); void screenEl.offsetWidth; screenEl.classList.add('enter'); }
  kiosk.classList.toggle('a11y', S.a11y);
  document.dispatchEvent(new CustomEvent('gogem:screen', { detail: S.screen }));
}
function go(scr) {
  clearTimers(); S.screen = scr; S.modal = null; modalEl.innerHTML = ''; modalEl.className = '';
  if (scr === 'menu' && !S.cat) S.cat = S.theme === 'vitrine' ? 'burgers' : 'combos';
  render(true); after();
}
function openModal(kind, extra) {
  S.modal = kind; modalEl.className = 'on m-' + kind;
  modalEl.innerHTML = kind === 'product' ? productModal() : kind === 'upCombo' ? upsellCombo() : kind === 'upDessert' ? upsellDessert() : idleModal(extra);
  modalEl.classList.remove('enter'); void modalEl.offsetWidth; modalEl.classList.add('enter');
}
function refreshModal() {
  const b = modalEl.querySelector('[data-scroll]'); const st = b ? b.scrollTop : 0;
  modalEl.innerHTML = S.modal === 'product' ? productModal() : S.modal === 'upDessert' ? upsellDessert() : modalEl.innerHTML;
  const nb = modalEl.querySelector('[data-scroll]'); if (nb) nb.scrollTop = st;
}
function closeModal() { S.modal = null; modalEl.className = ''; modalEl.innerHTML = ''; }

/* ---------------------------------------------------------------- pós-render: animações por tela */
function after() {
  const scr = S.screen;
  if (scr === 'attract') {
    if (S.theme === 'brasa') { embers(); cycle('.tk', 3200); }
    if (S.theme === 'vitrine') vitrineStories();
    if (S.theme === 'estudio') { cycle('.es-disc', 3000); cycle('.es-item', 3000); cycle('.el', 3000); cycle('.es-dots i', 3000); }
  }
  if (scr === 'menu') {
    if (S.theme === 'brasa') { cycle('.pc', 3800); cycle('.pc-dots i', 3800); }
    if (S.theme === 'estudio') autoScrollFeat();
    scrollSpy(); scrollToCat(S.cat, true);
  }
  if (scr === 'pix') pixFlow();
  if (scr === 'card') cardFlow();
  if (scr === 'done') doneFlow();
}
function cycle(sel, ms) {
  const els = () => screenEl.querySelectorAll(sel); let i = 0;
  timers.push(setInterval(() => { const e = els(); if (!e.length) return; e[i % e.length].classList.remove('on'); i++; e[i % e.length].classList.add('on'); }, ms));
}
function vitrineStories() {
  let i = 0; const n = VIT_SLIDES.length;
  timers.push(setInterval(() => {
    const vs = screenEl.querySelectorAll('.vs'), vc = screenEl.querySelectorAll('.vc'), vb = screenEl.querySelectorAll('.vb i');
    vs[i].classList.remove('on'); vc[i].classList.remove('on'); vb[i].classList.remove('run'); vb[i].classList.add('full');
    i = (i + 1) % n; if (i === 0) vb.forEach(b => b.classList.remove('full'));
    vs[i].classList.add('on'); vc[i].classList.add('on'); vb[i].classList.add('run');
  }, 4200));
}
function autoScrollFeat() {
  const f = screenEl.querySelector('#efeat'); if (!f) return; let i = 0;
  timers.push(setInterval(() => { if (!f.isConnected) return; i = (i + 1) % 4; const c = f.children[i]; f.scrollTo({ left: c.offsetLeft - 48, behavior: 'smooth' }); }, 3500));
}
function scrollSpy() {
  const sc = screenEl.querySelector('#mscroll'); if (!sc) return;
  let tick = false;
  sc.addEventListener('scroll', () => {
    if (tick) return; tick = true;
    requestAnimationFrame(() => {
      tick = false; const secs = sc.querySelectorAll('[data-cat]'); let cur = null;
      const top = sc.getBoundingClientRect().top; const k = kioskScale();
      secs.forEach(s => { if ((s.getBoundingClientRect().top - top) / k < 260) cur = s.dataset.cat; });
      if (cur && cur !== S.cat) { S.cat = cur; screenEl.querySelectorAll('[data-act="cat"]').forEach(b => b.classList.toggle('on', b.dataset.id === cur)); const on = screenEl.querySelector('[data-act="cat"].on'); if (on && on.parentElement.scrollWidth > on.parentElement.clientWidth) on.parentElement.scrollTo({ left: on.offsetLeft - 60, behavior: 'smooth' }); }
    });
  }, { passive: true });
}
function scrollToCat(id, instant) {
  const sc = screenEl.querySelector('#mscroll'), s = screenEl.querySelector('#sec-' + id); if (!sc || !s) return;
  if (instant && id === 'combos') return;
  const k = kioskScale(); const off = (s.getBoundingClientRect().top - sc.getBoundingClientRect().top) / k + sc.scrollTop - (S.theme === 'vitrine' ? 0 : 12);
  sc.scrollTo({ top: off, behavior: instant ? 'auto' : 'smooth' });
}
function kioskScale() { return kiosk.getBoundingClientRect().width / 1080 || 1; }

/* brasas */
function embers() {
  const cv = screenEl.querySelector('#embers'); if (!cv) return; const cx = cv.getContext('2d');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const ps = Array.from({ length: 90 }, () => spawn(true));
  function spawn(init) { return { x: 200 + Math.random() * 680, y: init ? 700 + Math.random() * 1200 : 1500 + Math.random() * 400, r: 1.5 + Math.random() * 3.5, vy: .6 + Math.random() * 1.8, vx: (Math.random() - .5) * .6, life: 0, max: 380 + Math.random() * 500, ph: Math.random() * 6 }; }
  function step() {
    cx.clearRect(0, 0, 1080, 1920); cx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < ps.length; i++) {
      const p = ps[i]; p.life++; p.y -= p.vy; p.x += p.vx + Math.sin((p.life + p.ph * 50) / 40) * .5;
      const a = Math.max(0, 1 - p.life / p.max);
      if (a <= 0 || p.y < 200) { ps[i] = spawn(false); continue; }
      const g = cx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 4);
      g.addColorStop(0, `rgba(255,214,140,${a})`); g.addColorStop(.35, `rgba(255,120,40,${a * .7})`); g.addColorStop(1, 'rgba(255,80,20,0)');
      cx.fillStyle = g; cx.beginPath(); cx.arc(p.x, p.y, p.r * 4, 0, 7); cx.fill();
    }
    if (!reduce) raf = requestAnimationFrame(step);
  }
  step();
}
/* pix / cartão / confirmação */
function pixFlow() {
  if (S.payStage === 2) return;
  let s = 300; const el = () => screenEl.querySelector('#pixTimer');
  timers.push(setInterval(() => { s--; const e = el(); if (e) e.textContent = String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0'); }, 1000));
  timers.push(setTimeout(approvePix, 9000));
}
function approvePix() { clearTimers(); S.payStage = 2; render(false); timers.push(setTimeout(() => finish(), 1900)); }
function cardFlow() {
  if (S.payStage !== 0) return;
  timers.push(setTimeout(() => { S.payStage = 1; render(false); timers.push(setTimeout(() => { S.payStage = 2; render(false); timers.push(setTimeout(finish, 1700)); }, 2200)); }, 3800));
}
function finish() { S.orderNo = 100 + Math.floor(Math.random() * 800); go('done'); }
function doneFlow() {
  const no = screenEl.querySelector('#orderNo'); let v = 0; const target = S.orderNo;
  timers.push(setInterval(() => { v = Math.min(target, v + Math.ceil(target / 24)); if (no) no.textContent = String(v).padStart(3, '0'); }, 40));
  let b = 20; timers.push(setInterval(() => { b--; const e = screenEl.querySelector('#backIn'); if (e) e.textContent = t('backIn')(b); if (b <= 0) reset(); }, 1000));
  confetti();
}
function confetti() {
  const cv = screenEl.querySelector('#confetti'); if (!cv || matchMedia('(prefers-reduced-motion: reduce)').matches) return; const cx = cv.getContext('2d');
  const th = THEMES[S.theme].palette; const cols = [th[2], th[3], th[4], '#ffffff'];
  const ps = Array.from({ length: 170 }, () => ({ x: 540 + (Math.random() - .5) * 200, y: 620, vx: (Math.random() - .5) * 26, vy: -10 - Math.random() * 22, r: Math.random() * 6.28, vr: (Math.random() - .5) * .3, w: 12 + Math.random() * 16, h: 8 + Math.random() * 10, c: cols[Math.floor(Math.random() * cols.length)] }));
  let f = 0;
  (function step() {
    cx.clearRect(0, 0, 1080, 1920); f++;
    ps.forEach(p => { p.vy += .55; p.vx *= .99; p.x += p.vx; p.y += p.vy; p.r += p.vr; cx.save(); cx.translate(p.x, p.y); cx.rotate(p.r); cx.fillStyle = p.c; cx.globalAlpha = Math.max(0, 1 - f / 220); cx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h * Math.abs(Math.cos(p.r * 2))); cx.restore(); });
    if (f < 230) raf = requestAnimationFrame(step);
  })();
}

/* ---------------------------------------------------------------- carrinho: ações */
function newEdit(pid) {
  const p = byId(pid);
  return { pid, qty: 1, combo: p.combo ? { side: 'fritas', drink: 'hibisco' } : null, extras: {}, removed: [] };
}
function sameLine(a, b) { return a.pid === b.pid && JSON.stringify(a.combo) === JSON.stringify(b.combo) && JSON.stringify(a.extras) === JSON.stringify(b.extras) && a.removed.join() === b.removed.join(); }
function pushLine(e) {
  const ex = S.cart.find(l => sameLine(l, e));
  if (ex) { ex.qty += e.qty; return ex; }
  const l = { uid: uid++, pid: e.pid, qty: e.qty, combo: e.combo ? { ...e.combo } : null, extras: { ...e.extras }, removed: [...e.removed] };
  S.cart.push(l); return l;
}
function flyFrom(srcEl, src) {
  const btn = screenEl.querySelector('#cartBtn .cbar-ic') || screenEl.querySelector('.tot'); if (!srcEl || !btn) { bump(); return; }
  const k = kioskScale(), kr = kiosk.getBoundingClientRect(), a = srcEl.getBoundingClientRect(), b = btn.getBoundingClientRect();
  const x0 = (a.left - kr.left) / k, y0 = (a.top - kr.top) / k, w = Math.min(a.width / k, 360), h = w * (a.height / a.width || 1);
  const x1 = (b.left - kr.left) / k + b.width / k / 2 - 30, y1 = (b.top - kr.top) / k + b.height / k / 2 - 30;
  const f = document.createElement('img'); f.src = src; f.className = 'fly'; fxEl.appendChild(f);
  f.style.cssText = `left:${x0}px;top:${y0}px;width:${w}px;height:${h}px`;
  f.animate([{ transform: 'translate(0,0) scale(1)', opacity: 1 }, { transform: `translate(${(x1 - x0) * .5}px,${(y1 - y0) * .5 - 260}px) scale(.55)`, opacity: 1, offset: .55 }, { transform: `translate(${x1 - x0}px,${y1 - y0}px) scale(.12)`, opacity: .4 }],
    { duration: 820, easing: 'cubic-bezier(.5,0,.3,1)' }).onfinish = () => { f.remove(); bump(); };
}
function bump() { const n = screenEl.querySelector('#cartBtn'); if (n) { n.classList.remove('bump'); void n.offsetWidth; n.classList.add('bump'); } toast(t('added')); }
function toast(msg) { const e = document.createElement('div'); e.className = 'toast'; e.innerHTML = ic('check', 30, 3) + msg; fxEl.appendChild(e); setTimeout(() => e.remove(), 1700); }
function refreshCartUI() { if (S.screen === 'menu') render(false); else if (S.screen === 'cart') render(false); }

/* ---------------------------------------------------------------- eventos */
const ACT = {
  startAny: (el, ev) => { if (ev.target.closest('.langs,button')) return; S.mode = 'here'; go('menu'); },
  start: el => { S.mode = el.dataset.id; go('menu'); },
  lang: el => { S.lang = el.dataset.id; render(false); if (S.screen === 'attract') { clearTimers(); after(); } },
  a11y: () => { S.a11y = !S.a11y; kiosk.classList.toggle('a11y', S.a11y); screenEl.querySelectorAll('[data-act="a11y"]').forEach(b => b.classList.toggle('on', S.a11y)); },
  go: el => go(el.dataset.id),
  reset: () => reset(),
  cat: el => { S.cat = el.dataset.id; screenEl.querySelectorAll('[data-act="cat"]').forEach(b => b.classList.toggle('on', b.dataset.id === S.cat)); scrollToCat(S.cat); },
  open: el => { const p = byId(el.dataset.id); if (!p || p.soldout) return; S.edit = newEdit(p.id); S.lastSrc = el.closest('article,.pc,.ef,.nhero,.dspecial,.vcard') ; openModal('product'); },
  quick: el => {
    const p = byId(el.dataset.id); if (p.combo || p.burger) { S.edit = newEdit(p.id); openModal('product'); return; }
    pushLine(newEdit(p.id)); const card = el.closest('.vcard,.rc,article'); const img = card && card.querySelector('img');
    const r = img ? img.getBoundingClientRect() : null;
    refreshCartUI(); flyFrom(r ? { getBoundingClientRect: () => r } : null, im(p.cut || p.photo));
  },
  closeModal: (el, ev) => { if (el.classList.contains('ov') && ev.target !== el) return; closeModal(); },
  eqty: el => { S.edit.qty = Math.max(1, S.edit.qty + +el.dataset.d); refreshModal(); },
  extra: el => { const x = el.dataset.id; S.edit.extras[x] = Math.max(0, Math.min(3, (S.edit.extras[x] || 0) + +el.dataset.d)); if (!S.edit.extras[x]) delete S.edit.extras[x]; refreshModal(); },
  rm: el => { const r = el.dataset.id, a = S.edit.removed; const i = a.indexOf(r); i >= 0 ? a.splice(i, 1) : a.push(r); refreshModal(); },
  toggleCombo: () => { S.edit.combo = S.edit.combo ? null : { side: 'fritas', drink: 'hibisco' }; refreshModal(); },
  optPick: el => { S.edit.combo[el.dataset.k] = el.dataset.id; refreshModal(); },
  addEdit: () => {
    const e = S.edit, p = byId(e.pid); const heroImg = modalEl.querySelector('.pm-hero img');
    const r = heroImg ? heroImg.getBoundingClientRect() : null;
    const l = pushLine(e); S.lastLine = l.uid; closeModal(); refreshCartUI();
    const ghost = r ? { getBoundingClientRect: () => r } : null; flyFrom(ghost, im(p.cut || p.photo));
    if (p.burger && !e.combo) timers.push(setTimeout(() => openModal('upCombo'), 950));
  },
  upNo: () => closeModal(),
  upCombo: () => { const l = S.cart.find(x => x.uid === S.lastLine); if (l) { const ex = S.cart.find(x => x !== l && sameLine(x, { ...l, combo: { side: 'fritas', drink: 'hibisco' } })); l.combo = { side: 'fritas', drink: 'hibisco' }; if (ex) { ex.qty += l.qty; S.cart = S.cart.filter(x => x !== l); } } closeModal(); refreshCartUI(); toast(t('makeCombo') + ' ✓'); },
  lqty: el => { const l = S.cart.find(x => x.uid === +el.dataset.id); l.qty += +el.dataset.d; if (l.qty <= 0) return ACT.delLine({ dataset: { id: l.uid } }); render(false); },
  delLine: el => { const id = +el.dataset.id; const row = screenEl.querySelector('#cl-' + id); const done = () => { S.cart = S.cart.filter(x => x.uid !== id); render(false); }; if (row) { row.classList.add('bye'); setTimeout(done, 320); } else done(); },
  checkout: () => { if (!S.cart.length) return; if (!S.dessertAsked && !S.cart.some(l => byId(l.pid).dessert)) { S.dessertAsked = true; openModal('upDessert'); } else go('cpf'); },
  upAddDessert: el => { const id = el.dataset.id; const i = S.cart.findIndex(l => l.pid === id); if (i >= 0) S.cart.splice(i, 1); else pushLine(newEdit(id)); refreshModal(); render(false); },
  upDessDone: () => { closeModal(); go('cpf'); },
  cpfKey: el => { const k = el.dataset.id; if (k === 'del') S.cpf = S.cpf.slice(0, -1); else if (k === 'C') S.cpf = ''; else if (S.cpf.length < 11) S.cpf += k; render(false); },
  cpfSkip: () => { S.cpf = ''; go('name'); },
  cpfNext: () => go('name'),
  nameKey: el => { const k = el.dataset.id; if (k === 'del') S.name = S.name.slice(0, -1); else if (S.name.length < 12 && !(k === ' ' && (!S.name || S.name.endsWith(' ')))) S.name += k; render(false); },
  pay: el => { S.pay = el.dataset.id; S.payStage = 0; if (S.pay === 'pix') go('pix'); else if (S.pay === 'cash') finish(); else go('card'); },
  simPay: () => approvePix(),
  idleStay: () => { idleLast = Date.now(); closeModal(); },
};
function reset() {
  clearTimers(); Object.assign(S, { mode: 'here', cart: [], cpf: '', name: '', pay: null, modal: null, dessertAsked: false, edit: null, payStage: 0, cat: null, a11y: false });
  go('attract');
}
function onClick(ev) {
  idleLast = Date.now();
  let el = ev.target.closest('[data-act]');
  while (el && !el.dataset.act) el = el.parentElement && el.parentElement.closest('[data-act]');
  if (!el || !kiosk.contains(el) || el.disabled) return;
  const f = ACT[el.dataset.act]; if (f) { ev.stopPropagation(); f(el, ev); press(el); }
}
function press(el) { if (el.matches('button,.card,.ecard,.ntile,.drow,.po')) { el.classList.remove('pressed'); void el.offsetWidth; el.classList.add('pressed'); } }

/* idle */
function idleLoop() {
  setInterval(() => {
    if (S.screen === 'attract' || S.screen === 'done' || S.screen === 'pix' || S.screen === 'card') { idleLast = Date.now(); return; }
    if (S.modal === 'idle') { idleSec--; const b = modalEl.querySelector('#idleSec'), tx = modalEl.querySelector('#idleTxt'), c = modalEl.querySelector('.ir-fg'); if (b) b.textContent = idleSec; if (tx) tx.textContent = t('idleS')(idleSec); if (c) c.style.strokeDashoffset = 327 * (1 - idleSec / 15); if (idleSec <= 0) reset(); return; }
    if (Date.now() - idleLast > 60000) { idleSec = 15; openModal('idle', 15); }
  }, 1000);
}

/* tilt (Estúdio) */
function tilt(ev) {
  if (S.theme !== 'estudio') return; const c = ev.target.closest && ev.target.closest('.tilt'); if (!c) return;
  const r = c.getBoundingClientRect(); const x = (ev.clientX - r.left) / r.width - .5, y = (ev.clientY - r.top) / r.height - .5;
  c.style.setProperty('--rx', (-y * 10).toFixed(2) + 'deg'); c.style.setProperty('--ry', (x * 12).toFixed(2) + 'deg');
}
function untilt(ev) { const c = ev.target.closest && ev.target.closest('.tilt'); if (c) { c.style.setProperty('--rx', '0deg'); c.style.setProperty('--ry', '0deg'); } }

/* ---------------------------------------------------------------- API para a moldura */
window.GoGem = {
  THEMES, S,
  setTheme(k) { S.theme = k; kiosk.className = 'kiosk t-' + k + (S.a11y ? ' a11y' : ''); const scr = S.screen; clearTimers(); if (scr === 'menu') S.cat = k === 'vitrine' ? 'burgers' : 'combos'; if (S.modal === 'product') { closeModal(); } render(true); after(); },
  jump(scr) {
    if (['cart', 'cpf', 'name', 'pay', 'pix', 'card', 'done'].includes(scr) && !S.cart.length) {
      pushLine({ pid: 'duplo', qty: 1, combo: { side: 'fritas', drink: 'shake' }, extras: { bacon: 1 }, removed: ['Sem cebola'] });
      pushLine({ pid: 'classico', qty: 1, combo: null, extras: {}, removed: [] });
    }
    if (['pay', 'pix', 'card', 'done'].includes(scr) && !S.name) S.name = 'Rodrigo';
    if (scr === 'card' && !['credit', 'debit'].includes(S.pay)) S.pay = 'credit';
    if (scr === 'pix') S.pay = 'pix';
    if (scr === 'done') { if (!S.pay) S.pay = 'pix'; S.orderNo = S.orderNo || 247; }
    S.payStage = 0;
    if (scr === 'product') { go('menu'); S.edit = newEdit('duplo'); S.edit.combo = { side: 'fritas', drink: 'shake' }; openModal('product'); return; }
    if (scr === 'upsell') { go('cart'); openModal('upDessert'); return; }
    go(scr);
  },
  reset,
  mount(root) {
    kiosk = root; kiosk.className = 'kiosk t-' + S.theme;
    kiosk.innerHTML = '<div id="screen" class="screen"></div><div id="modal"></div><div id="fx"></div><div class="a11y-top"><span>' + ic('access', 44, 2) + '</span><p></p><button type="button" data-act="a11y" class="btn soft md"></button></div>';
    screenEl = kiosk.querySelector('#screen'); modalEl = kiosk.querySelector('#modal'); fxEl = kiosk.querySelector('#fx');
    kiosk.addEventListener('click', ev => { onClick(ev); }, true);
    kiosk.addEventListener('pointermove', tilt); kiosk.addEventListener('pointerout', untilt);
    const syncA = () => { const p = kiosk.querySelector('.a11y-top p'), b = kiosk.querySelector('.a11y-top button'); p.textContent = t('a11yOn'); b.textContent = t('a11yOff'); };
    document.addEventListener('gogem:screen', syncA);
    go('attract'); idleLoop(); syncA();
  },
};
})();
