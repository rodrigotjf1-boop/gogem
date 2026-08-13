import * as React from 'react';
import { BarChart3, Ban, Loader2, ShoppingBag, TrendingUp } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import { formatarBRL } from '@/lib/money';
import {
  useCancelarPedido,
  usePedidos,
  useProdutos,
  useRelatorioHorarios,
  useRelatorioPagamentos,
  useResumo,
  type FaturamentoCard,
  type PedidoRelatorio,
  type PedidoStatus,
} from '@/lib/relatorios';

/** Datas padrão: 1º dia do mês corrente até hoje (YYYY-MM-DD). */
function periodoPadrao(): { de: string; ate: string } {
  const hoje = new Date();
  const primeiro = new Date(hoje.getFullYear(), hoje.getMonth(), 1);
  return { de: iso(primeiro), ate: iso(hoje) };
}

function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`;
}

const ROTULO_STATUS: Record<PedidoStatus, string> = {
  pendente: 'Pendente',
  enviado: 'Enviado',
  falha: 'Falha',
  cancelado: 'Cancelado',
};

const MOTIVOS = [
  'Falta de saldo',
  'Instabilidade bancária',
  'Pedido em duplicidade',
  'Outro',
] as const;

/** Relatórios (Fase 7): faturamento, pedidos, ranking de produtos, cancelamento. */
export default function RelatoriosPage() {
  const padrao = React.useMemo(periodoPadrao, []);
  const [de, setDe] = React.useState(padrao.de);
  const [ate, setAte] = React.useState(padrao.ate);
  const [status, setStatus] = React.useState<PedidoStatus | 'todos'>('todos');
  const [aba, setAba] = React.useState<
    'pedidos' | 'produtos' | 'pagamentos' | 'horarios'
  >('pedidos');

  // Presets de período: define de/ate pros últimos N dias (até hoje).
  function ultimosDias(dias: number) {
    const hoje = new Date();
    const ini = new Date(hoje);
    ini.setDate(ini.getDate() - (dias - 1));
    setDe(iso(ini));
    setAte(iso(hoje));
  }

  return (
    <section className="mx-auto max-w-5xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Relatórios</h1>
        <p className="text-sm text-muted-foreground">
          Faturamento, pedidos por totem e ranking de produtos. Valores de
          pedidos concretizados (enviados ao Regem).
        </p>
      </header>

      <ResumoCards />

      {/* Filtros */}
      <div className="flex flex-wrap items-end gap-3 rounded-lg border border-border bg-card p-4">
        <div className="space-y-1">
          <Label htmlFor="rel-de">De</Label>
          <Input
            id="rel-de"
            type="date"
            value={de}
            max={ate}
            onChange={(e) => setDe(e.target.value)}
            className="w-40"
          />
        </div>
        <div className="space-y-1">
          <Label htmlFor="rel-ate">Até</Label>
          <Input
            id="rel-ate"
            type="date"
            value={ate}
            min={de}
            onChange={(e) => setAte(e.target.value)}
            className="w-40"
          />
        </div>
        <div className="flex flex-wrap items-center gap-1 self-end">
          <Button variant="outline" size="sm" onClick={() => ultimosDias(1)}>
            Hoje
          </Button>
          <Button variant="outline" size="sm" onClick={() => ultimosDias(7)}>
            Última semana
          </Button>
          <Button variant="outline" size="sm" onClick={() => ultimosDias(30)}>
            Último mês
          </Button>
        </div>
        {aba === 'pedidos' && (
          <div className="space-y-1">
            <Label htmlFor="rel-status">Status</Label>
            <select
              id="rel-status"
              value={status}
              onChange={(e) => setStatus(e.target.value as PedidoStatus | 'todos')}
              className="flex h-10 w-44 rounded-md border border-input bg-background px-3 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="todos">Todos</option>
              <option value="enviado">Enviado</option>
              <option value="cancelado">Cancelado</option>
              <option value="falha">Falha</option>
              <option value="pendente">Pendente</option>
            </select>
          </div>
        )}
      </div>

      {/* Abas */}
      <div className="flex flex-wrap gap-1 border-b border-border" role="tablist">
        <TabButton ativo={aba === 'pedidos'} onClick={() => setAba('pedidos')}>
          Pedidos
        </TabButton>
        <TabButton ativo={aba === 'produtos'} onClick={() => setAba('produtos')}>
          Ranking de produtos
        </TabButton>
        <TabButton
          ativo={aba === 'pagamentos'}
          onClick={() => setAba('pagamentos')}
        >
          Por pagamento
        </TabButton>
        <TabButton ativo={aba === 'horarios'} onClick={() => setAba('horarios')}>
          Por horário
        </TabButton>
      </div>

      {aba === 'pedidos' && (
        <PedidosTabela
          de={de}
          ate={ate}
          status={status === 'todos' ? undefined : status}
        />
      )}
      {aba === 'produtos' && <ProdutosTabela de={de} ate={ate} />}
      {aba === 'pagamentos' && <PagamentosTabela de={de} ate={ate} />}
      {aba === 'horarios' && <HorariosBloco de={de} ate={ate} />}
    </section>
  );
}

function TabButton({
  ativo,
  onClick,
  children,
}: {
  ativo: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={ativo}
      onClick={onClick}
      className={
        'border-b-2 px-4 py-2 text-sm font-medium transition-colors ' +
        (ativo
          ? 'border-primary text-primary'
          : 'border-transparent text-muted-foreground hover:text-foreground')
      }
    >
      {children}
    </button>
  );
}

function ResumoCards() {
  const { data, isLoading } = useResumo();
  if (isLoading || !data) {
    return (
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Card key={i} className="h-24 animate-pulse bg-secondary/40" />
        ))}
      </div>
    );
  }
  const deltaPct = variacao(data.mesAtual.totalCentavos, data.mesAnterior.totalCentavos);
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <ResumoCard titulo="Hoje" card={data.hoje} icone={<TrendingUp className="size-4" aria-hidden />} />
      <ResumoCard titulo="Últimos 7 dias" card={data.semana} />
      <ResumoCard
        titulo="Mês atual"
        card={data.mesAtual}
        rodape={
          deltaPct == null ? undefined : (
            <span className={deltaPct >= 0 ? 'text-success' : 'text-destructive'}>
              {deltaPct >= 0 ? '▲' : '▼'} {Math.abs(deltaPct)}% vs mês anterior
            </span>
          )
        }
      />
      <ResumoCard titulo="Mês anterior" card={data.mesAnterior} />
    </div>
  );
}

function ResumoCard({
  titulo,
  card,
  icone,
  rodape,
}: {
  titulo: string;
  card: FaturamentoCard;
  icone?: React.ReactNode;
  rodape?: React.ReactNode;
}) {
  return (
    <Card className="p-4">
      <div className="flex items-center justify-between text-xs font-medium uppercase tracking-wide text-muted-foreground">
        <span>{titulo}</span>
        {icone}
      </div>
      <p className="mt-1 font-mono text-xl font-bold">{formatarBRL(card.totalCentavos)}</p>
      <p className="text-xs text-muted-foreground">
        {card.pedidos} {card.pedidos === 1 ? 'pedido' : 'pedidos'} · ticket{' '}
        {formatarBRL(card.ticketMedioCentavos)}
      </p>
      {rodape && <p className="mt-1 text-xs font-medium">{rodape}</p>}
    </Card>
  );
}

/** Variação percentual (arredondada) do atual sobre o anterior; null se base 0. */
function variacao(atual: number, anterior: number): number | null {
  if (anterior <= 0) return null;
  return Math.round(((atual - anterior) / anterior) * 100);
}

function PedidosTabela({
  de,
  ate,
  status,
}: {
  de: string;
  ate: string;
  status?: PedidoStatus;
}) {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading, isError, refetch } = usePedidos({ de, ate, status });
  const [cancelando, setCancelando] = React.useState<PedidoRelatorio | null>(null);

  if (isLoading) return <Carregando texto="Carregando pedidos…" />;
  if (isError) return <ErroBloco onRetry={() => refetch()} />;
  if (!data || data.length === 0)
    return (
      <VazioBloco
        icone={<ShoppingBag className="size-5" aria-hidden />}
        titulo="Nenhum pedido no período"
        texto="Ajuste as datas ou o status para ver os pedidos."
      />
    );

  return (
    <>
      <div className="overflow-x-auto rounded-lg border border-border">
        <table className="w-full text-sm">
          <caption className="sr-only">Pedidos do período</caption>
          <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
            <tr>
              <th className="px-4 py-2 font-medium">Data/hora</th>
              <th className="px-4 py-2 font-medium">Totem</th>
              <th className="px-4 py-2 font-medium">Cliente</th>
              <th className="px-4 py-2 font-medium">Itens</th>
              <th className="px-4 py-2 font-medium">Pagamento</th>
              <th className="px-4 py-2 text-right font-medium">Total</th>
              <th className="px-4 py-2 font-medium">Status</th>
              {podeEscrever && <th className="px-4 py-2 text-right font-medium">Ações</th>}
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.map((p) => (
              <tr key={p.id} className="hover:bg-secondary/30">
                <td className="whitespace-nowrap px-4 py-2 font-mono text-xs">
                  {dataHora(p.criadoEm)}
                  {p.senha != null && (
                    <span className="ml-1 text-muted-foreground">#{p.senha}</span>
                  )}
                </td>
                <td className="px-4 py-2">{p.dispositivo ?? '—'}</td>
                <td className="px-4 py-2">{p.cliente ?? '—'}</td>
                <td className="px-4 py-2">{p.itens}</td>
                <td className="px-4 py-2">
                  {p.formas.length ? (
                    <div className="flex flex-wrap gap-1">
                      {p.formas.map((f, i) => (
                        <Badge key={i} variant="outline">
                          {f}
                        </Badge>
                      ))}
                    </div>
                  ) : (
                    '—'
                  )}
                </td>
                <td className="whitespace-nowrap px-4 py-2 text-right font-mono">
                  {formatarBRL(p.totalCentavos)}
                </td>
                <td className="px-4 py-2">
                  <StatusBadge status={p.status} motivo={p.canceladoMotivo} />
                </td>
                {podeEscrever && (
                  <td className="px-4 py-2 text-right">
                    {p.status === 'enviado' && (
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={`Cancelar pedido ${p.senha ?? p.id}`}
                        onClick={() => setCancelando(p)}
                      >
                        <Ban className="size-4 text-destructive" aria-hidden />
                        Cancelar
                      </Button>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <CancelarDialog
        pedido={cancelando}
        onFechar={() => setCancelando(null)}
      />
    </>
  );
}

function StatusBadge({
  status,
  motivo,
}: {
  status: PedidoStatus;
  motivo: string | null;
}) {
  if (status === 'enviado') return <Badge variant="success">Enviado</Badge>;
  if (status === 'cancelado')
    return (
      <span className="inline-flex flex-col">
        <Badge variant="muted">Cancelado</Badge>
        {motivo && <span className="mt-0.5 text-[11px] text-muted-foreground">{motivo}</span>}
      </span>
    );
  if (status === 'falha') return <Badge variant="outline">Falha</Badge>;
  return <Badge variant="outline">{ROTULO_STATUS[status]}</Badge>;
}

function ProdutosTabela({ de, ate }: { de: string; ate: string }) {
  const { data, isLoading, isError, refetch } = useProdutos({ de, ate });
  if (isLoading) return <Carregando texto="Calculando ranking…" />;
  if (isError) return <ErroBloco onRetry={() => refetch()} />;
  if (!data || data.length === 0)
    return (
      <VazioBloco
        icone={<BarChart3 className="size-5" aria-hidden />}
        titulo="Sem vendas no período"
        texto="O ranking usa apenas pedidos enviados ao Regem."
      />
    );

  const maior = data[0]?.quantidade || 1;
  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-sm">
        <caption className="sr-only">Ranking de produtos por quantidade</caption>
        <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
          <tr>
            <th className="px-4 py-2 font-medium">#</th>
            <th className="px-4 py-2 font-medium">Produto</th>
            <th className="px-4 py-2 font-medium">Código PDV</th>
            <th className="px-4 py-2 text-right font-medium">Qtd.</th>
            <th className="px-4 py-2 text-right font-medium">Pedidos</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {data.map((p, i) => (
            <tr key={p.codigoPdv} className="hover:bg-secondary/30">
              <td className="px-4 py-2 font-mono text-muted-foreground">{i + 1}</td>
              <td className="px-4 py-2">
                <div className="font-medium">{p.nome}</div>
                <div className="mt-1 h-1.5 w-32 overflow-hidden rounded-full bg-secondary">
                  <div
                    className="h-full rounded-full bg-primary"
                    style={{ width: `${Math.max(4, (p.quantidade / maior) * 100)}%` }}
                  />
                </div>
              </td>
              <td className="px-4 py-2 font-mono text-xs text-muted-foreground">
                {p.codigoPdv}
              </td>
              <td className="px-4 py-2 text-right font-mono font-semibold">{p.quantidade}</td>
              <td className="px-4 py-2 text-right font-mono text-muted-foreground">
                {p.pedidos}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PagamentosTabela({ de, ate }: { de: string; ate: string }) {
  const { data, isLoading, isError, refetch } = useRelatorioPagamentos({
    de,
    ate,
  });
  if (isLoading) return <Carregando texto="Somando por forma de pagamento…" />;
  if (isError) return <ErroBloco onRetry={() => refetch()} />;
  if (!data || data.length === 0)
    return (
      <VazioBloco
        icone={<BarChart3 className="size-5" aria-hidden />}
        titulo="Sem vendas no período"
        texto="Usa apenas pedidos enviados ao Regem."
      />
    );

  const total = data.reduce((s, r) => s + r.totalCentavos, 0) || 1;
  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-sm">
        <caption className="sr-only">Vendas por forma de pagamento</caption>
        <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
          <tr>
            <th className="px-4 py-2 font-medium">Forma</th>
            <th className="px-4 py-2 text-right font-medium">Pedidos</th>
            <th className="px-4 py-2 text-right font-medium">Total</th>
            <th className="px-4 py-2 text-right font-medium">%</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {data.map((r) => (
            <tr
              key={`${r.forma}·${r.bandeira ?? ''}`}
              className="hover:bg-secondary/30"
            >
              <td className="px-4 py-2">
                <span className="font-medium capitalize">{r.forma}</span>
                {r.bandeira && (
                  <span className="ml-2 text-xs text-muted-foreground">
                    {r.bandeira}
                  </span>
                )}
              </td>
              <td className="px-4 py-2 text-right font-mono text-muted-foreground">
                {r.pedidos}
              </td>
              <td className="px-4 py-2 text-right font-mono font-semibold">
                {formatarBRL(r.totalCentavos)}
              </td>
              <td className="px-4 py-2 text-right font-mono text-muted-foreground">
                {Math.round((r.totalCentavos / total) * 100)}%
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function HorariosBloco({ de, ate }: { de: string; ate: string }) {
  const { data, isLoading, isError, refetch } = useRelatorioHorarios({
    de,
    ate,
  });
  const [modo, setModo] = React.useState<'grafico' | 'tabela'>('grafico');
  if (isLoading) return <Carregando texto="Distribuindo por horário…" />;
  if (isError) return <ErroBloco onRetry={() => refetch()} />;
  const horas = data ?? [];
  if (horas.every((h) => h.pedidos === 0))
    return (
      <VazioBloco
        icone={<BarChart3 className="size-5" aria-hidden />}
        titulo="Sem vendas no período"
        texto="Usa apenas pedidos enviados ao Regem."
      />
    );

  const maior = Math.max(...horas.map((h) => h.totalCentavos), 1);
  return (
    <div className="space-y-3">
      <div className="flex justify-end gap-1">
        <Button
          variant={modo === 'grafico' ? 'primary' : 'outline'}
          size="sm"
          onClick={() => setModo('grafico')}
        >
          Gráfico
        </Button>
        <Button
          variant={modo === 'tabela' ? 'primary' : 'outline'}
          size="sm"
          onClick={() => setModo('tabela')}
        >
          Tabela
        </Button>
      </div>

      {modo === 'grafico' ? (
        <div className="overflow-x-auto rounded-lg border border-border p-4">
          <div className="flex h-56 min-w-[640px] items-end gap-1">
            {horas.map((h) => (
              <div
                key={h.hora}
                className="flex flex-1 flex-col items-center gap-1"
                title={`${String(h.hora).padStart(2, '0')}h · ${h.pedidos} pedido(s) · ${formatarBRL(h.totalCentavos)}`}
              >
                <div
                  className="w-full rounded-t bg-primary"
                  style={{
                    height: `${Math.max(2, (h.totalCentavos / maior) * 100)}%`,
                  }}
                />
                <span className="text-[10px] text-muted-foreground">
                  {String(h.hora).padStart(2, '0')}
                </span>
              </div>
            ))}
          </div>
          <p className="mt-2 text-xs text-muted-foreground">
            Faturamento por hora do dia (fuso de Brasília).
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-lg border border-border">
          <table className="w-full text-sm">
            <caption className="sr-only">Vendas por horário</caption>
            <thead className="bg-secondary/50 text-left text-xs uppercase tracking-wide text-muted-foreground">
              <tr>
                <th className="px-4 py-2 font-medium">Hora</th>
                <th className="px-4 py-2 text-right font-medium">Pedidos</th>
                <th className="px-4 py-2 text-right font-medium">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {horas
                .filter((h) => h.pedidos > 0)
                .map((h) => (
                  <tr key={h.hora} className="hover:bg-secondary/30">
                    <td className="px-4 py-2 font-mono">
                      {String(h.hora).padStart(2, '0')}h
                    </td>
                    <td className="px-4 py-2 text-right font-mono text-muted-foreground">
                      {h.pedidos}
                    </td>
                    <td className="px-4 py-2 text-right font-mono font-semibold">
                      {formatarBRL(h.totalCentavos)}
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function CancelarDialog({
  pedido,
  onFechar,
}: {
  pedido: PedidoRelatorio | null;
  onFechar: () => void;
}) {
  const cancelar = useCancelarPedido();
  const [motivo, setMotivo] = React.useState<string>(MOTIVOS[0]);
  const [outro, setOutro] = React.useState('');
  const [erro, setErro] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (pedido) {
      setMotivo(MOTIVOS[0]);
      setOutro('');
      setErro(null);
    }
  }, [pedido]);

  async function onConfirmar() {
    if (!pedido) return;
    const texto = motivo === 'Outro' ? outro.trim() : motivo;
    if (!texto) {
      setErro('Descreva o motivo do cancelamento.');
      return;
    }
    try {
      await cancelar.mutateAsync({ id: pedido.id, motivo: texto });
      onFechar();
    } catch {
      setErro('Não foi possível cancelar. Tente novamente.');
    }
  }

  return (
    <Dialog
      aberto={Boolean(pedido)}
      onFechar={onFechar}
      titulo="Cancelar pedido"
      descricao="O pedido é marcado como cancelado no GoGeM. A baixa no Regem/impressão é feita à parte."
      larguraClasse="max-w-md"
    >
      <div className="space-y-4">
        <div className="space-y-1">
          <Label htmlFor="cancel-motivo">Motivo</Label>
          <select
            id="cancel-motivo"
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {MOTIVOS.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </select>
        </div>
        {motivo === 'Outro' && (
          <div className="space-y-1">
            <Label htmlFor="cancel-outro">Descreva</Label>
            <Input
              id="cancel-outro"
              value={outro}
              onChange={(e) => setOutro(e.target.value)}
              placeholder="Motivo do cancelamento"
              autoFocus
            />
          </div>
        )}
        {erro && <p className="text-xs text-destructive">{erro}</p>}
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={onFechar} disabled={cancelar.isPending}>
            Voltar
          </Button>
          <Button variant="primary" onClick={onConfirmar} disabled={cancelar.isPending}>
            {cancelar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Confirmar cancelamento
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

function Carregando({ texto }: { texto: string }) {
  return (
    <div className="flex items-center gap-2 py-10 text-sm text-muted-foreground" role="status">
      <Loader2 className="size-4 animate-spin" aria-hidden />
      {texto}
    </div>
  );
}

function ErroBloco({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="rounded-lg border border-border bg-card p-6 text-sm">
      <p className="text-destructive">Não foi possível carregar.</p>
      <Button variant="outline" size="sm" className="mt-3" onClick={onRetry}>
        Tentar novamente
      </Button>
    </div>
  );
}

function VazioBloco({
  icone,
  titulo,
  texto,
}: {
  icone: React.ReactNode;
  titulo: string;
  texto: string;
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-lg border border-dashed border-border py-16 text-center">
      <div className="flex size-12 items-center justify-center rounded-full bg-secondary text-primary">
        {icone}
      </div>
      <p className="font-display font-semibold">{titulo}</p>
      <p className="max-w-sm text-sm text-muted-foreground">{texto}</p>
    </div>
  );
}

/** ISO → "dd/mm hh:mm" pt-BR. */
function dataHora(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}
