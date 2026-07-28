/// Estado consolidado da impressora.
///
/// ⚠️ MÁSCARAS DE BITS (TM-T88 series) — validar no bench da F4-hardware:
/// DLE EOT 1: bit3 (0x08) = offline
/// DLE EOT 2: bit2 (0x04) = tampa aberta · bit5 (0x20) = parada por fim de papel
/// DLE EOT 3: bit3 (0x08) = erro de guilhotina (autorrecuperável)
/// DLE EOT 4: bits 2-3 (0x0C) = papel acabando (near-end) · bits 5-6 (0x60) = SEM papel
/// ASB (4 bytes): b1 bit3 (0x08) = offline · b1 bit5 (0x20) = tampa ·
///                b3 bits 0-1 (0x03) = near-end · b3 bits 2-3 (0x0C) = SEM papel
class PrinterStatus {
  const PrinterStatus({
    this.online = true,
    this.tampaAberta = false,
    this.semPapel = false,
    this.pertoDoFim = false,
    this.erroGuilhotina = false,
  });

  final bool online;
  final bool tampaAberta;
  final bool semPapel;
  final bool pertoDoFim;
  final bool erroGuilhotina;

  /// REGRA DE OURO (CLAUDE.md): nunca iniciar pagamento sem isto true.
  bool get prontaParaVenda => online && !tampaAberta && !semPapel;

  String? get motivoBloqueio {
    if (semPapel) return 'sem papel';
    if (tampaAberta) return 'tampa aberta';
    if (!online) return 'impressora offline';
    return null;
  }

  static PrinterStatus fromDleEot({
    required int printer,
    required int offlineCause,
    required int error,
    required int paper,
  }) =>
      PrinterStatus(
        online: (printer & 0x08) == 0,
        tampaAberta: (offlineCause & 0x04) != 0,
        semPapel: (paper & 0x60) != 0 || (offlineCause & 0x20) != 0,
        pertoDoFim: (paper & 0x0C) != 0,
        erroGuilhotina: (error & 0x08) != 0,
      );

  static PrinterStatus fromAsb(List<int> b) {
    assert(b.length >= 4);
    return PrinterStatus(
      online: (b[0] & 0x08) == 0,
      tampaAberta: (b[0] & 0x20) != 0,
      pertoDoFim: (b[2] & 0x03) != 0,
      semPapel: (b[2] & 0x0C) != 0,
    );
  }

  @override
  String toString() =>
      'PrinterStatus(online:$online tampa:$tampaAberta semPapel:$semPapel '
      'nearEnd:$pertoDoFim guilhotina:$erroGuilhotina)';
}
