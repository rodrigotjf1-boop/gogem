import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_models.dart';

class Carrinho {
  const Carrinho({this.itens = const []});
  final List<ItemCarrinho> itens;
  int get totalCentavos => itens.fold<int>(0, (s, i) => s + i.totalCentavos);
  int get totalItens => itens.fold<int>(0, (s, i) => s + i.quantidade);
  bool get vazio => itens.isEmpty;
}

class CartNotifier extends Notifier<Carrinho> {
  @override
  Carrinho build() => const Carrinho();

  void adicionar(ItemCarrinho item) =>
      state = Carrinho(itens: [...state.itens, item]);

  void remover(String linhaId) => state =
      Carrinho(itens: [for (final i in state.itens) if (i.linhaId != linhaId) i]);

  void alterarQuantidade(String linhaId, int q) {
    if (q <= 0) return remover(linhaId);
    state = Carrinho(itens: [
      for (final i in state.itens) i.linhaId == linhaId ? i.comQuantidade(q) : i
    ]);
  }

  void limpar() => state = const Carrinho();
}

final cartProvider = NotifierProvider<CartNotifier, Carrinho>(CartNotifier.new);

/// Dados transientes do checkout: CPF (opcional), tipo de consumo
/// ('local' comer aqui | 'viagem') e nome do cliente (opcional, F4).
class CheckoutState {
  const CheckoutState({
    this.cpf = '',
    this.consumo = 'local',
    this.cliente = '',
  });
  final String cpf;
  final String consumo;
  final String cliente;

  CheckoutState copyWith({String? cpf, String? consumo, String? cliente}) =>
      CheckoutState(
        cpf: cpf ?? this.cpf,
        consumo: consumo ?? this.consumo,
        cliente: cliente ?? this.cliente,
      );
}

class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();
  void setCpf(String cpf) => state = state.copyWith(cpf: cpf);
  void setConsumo(String consumo) => state = state.copyWith(consumo: consumo);
  void setCliente(String cliente) => state = state.copyWith(cliente: cliente);
  void limpar() => state = const CheckoutState();
}

final checkoutProvider =
    NotifierProvider<CheckoutNotifier, CheckoutState>(CheckoutNotifier.new);
