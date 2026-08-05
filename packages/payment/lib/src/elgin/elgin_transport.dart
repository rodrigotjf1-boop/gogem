/// Ponte para o IDH ElginTef. No Android é um MethodChannel que dispara o Intent
/// `com.elgin.e1.digitalhub.TEF` (putExtra + startActivityForResult) e devolve a
/// string JSON do campo `retorno` do onActivityResult. Mantém o pacote puro: o
/// app injeta a impl nativa; os testes injetam um fake.
abstract interface class ElginTefTransport {
  /// Executa uma função do IDH passando os `extras` (exatamente os putExtra:
  /// funcao, valor, parcelas, financiamento, nsu, data…) e devolve o JSON cru do
  /// `retorno`. Lança em falha de comunicação com o pinpad/IDH.
  Future<String> executar(Map<String, String> extras);

  /// IDH instalado/ativo no dispositivo? (alimenta o healthCheck/telemetria).
  Future<bool> disponivel();
}
