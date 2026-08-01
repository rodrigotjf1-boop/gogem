import * as React from 'react';
import { Loader2, Plus, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { ImageUploadTile } from '@/components/ui/image-upload';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { usePodeEscrever } from '@/auth/auth-context';
import { mensagemDeErro } from '@/lib/publicacao';
import {
  useAparencia,
  useSalvarAparencia,
  type Aparencia,
  type AparenciaInput,
  type DescansoMidia,
} from '@/lib/aparencia';

/**
 * Paletas recomendadas por preset ("estilo do totem"). Escolher um preset com
 * paleta aplica a cara completa em 1 clique (o lojista ainda pode ajustar as
 * cores depois). 'padrao'/'brasa' não forçam paleta (mantêm o que o lojista tem).
 */
const PALETA_PRESET: Partial<Record<Aparencia['temaPreset'], Partial<Aparencia>>> =
  {
    burger: {
      corPrimaria: '#F5A623',
      corDestaque: '#E03A2F',
      corFundo: '#0E0C0B',
      corPainel: '#1C1815',
      raio: 16,
      fonteDisplay: 'Montserrat',
    },
  };

/**
 * Configurações → Aparência do totem (Fase 6). O lojista personaliza cores,
 * marca, tela de descanso, vitrine e animações; o totem aplica no próximo sync.
 * Só gerente+ salva (RBAC no servidor). O render é do app do totem.
 */
export default function ConfiguracoesPage() {
  const podeEscrever = usePodeEscrever();
  const { data, isLoading } = useAparencia();
  const salvar = useSalvarAparencia();
  const [form, setForm] = React.useState<Aparencia | null>(null);
  const [erro, setErro] = React.useState<string | null>(null);
  const [ok, setOk] = React.useState(false);

  React.useEffect(() => {
    if (data && !form) setForm(data);
  }, [data, form]);

  function set<K extends keyof Aparencia>(k: K, v: Aparencia[K]) {
    setForm((f) => (f ? { ...f, [k]: v } : f));
    setOk(false);
  }

  /** Troca o preset e, se houver paleta recomendada, aplica tudo de uma vez. */
  function aplicarPreset(v: Aparencia['temaPreset']) {
    const pal = PALETA_PRESET[v];
    setForm((f) => (f ? { ...f, temaPreset: v, ...(pal ?? {}) } : f));
    setOk(false);
  }

  async function onSalvar() {
    if (!form) return;
    setErro(null);
    // Monta o payload SÓ com os campos editáveis. O GET devolve o registro
    // inteiro (id, tenantId, createdAt, updatedAt) e o DTO de update tem
    // whitelist — mandar esses extras dá 400 ("property ... should not exist").
    const input: AparenciaInput = {
      corPrimaria: form.corPrimaria,
      corDestaque: form.corDestaque,
      corFundo: form.corFundo,
      corPainel: form.corPainel,
      raio: form.raio,
      nomeLoja: form.nomeLoja,
      logoUrl: form.logoUrl,
      fonteDisplay: form.fonteDisplay,
      temaPreset: form.temaPreset,
      descansoTipo: form.descansoTipo,
      descansoIntervaloSeg: form.descansoIntervaloSeg,
      descansoMidias: form.descansoMidias,
      chamada: form.chamada,
      precoIsca: form.precoIsca,
      estiloCard: form.estiloCard,
      animacoes: form.animacoes,
    };
    try {
      await salvar.mutateAsync(input);
      setOk(true);
    } catch (e) {
      setErro(mensagemDeErro(e));
    }
  }

  if (isLoading || !form) {
    return (
      <div className="flex justify-center py-20 text-muted-foreground">
        <Loader2 className="size-6 animate-spin" aria-hidden />
      </div>
    );
  }

  return (
    <section className="mx-auto max-w-4xl space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Configurações · Aparência</h1>
        <p className="text-sm text-muted-foreground">
          Personalize o visual do totem. As mudanças chegam ao totem no próximo
          sync (sem precisar republicar o cardápio).
        </p>
      </header>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {/* Cores & marca */}
        <Card>
          <CardContent className="space-y-4 p-5">
            <h2 className="font-display font-semibold">Cores & marca</h2>
            <div className="grid grid-cols-2 gap-3">
              <CorField label="Primária (CTA/preço)" value={form.corPrimaria} onChange={(v) => set('corPrimaria', v)} />
              <CorField label="Destaque (positivo)" value={form.corDestaque} onChange={(v) => set('corDestaque', v)} />
              <CorField label="Fundo" value={form.corFundo} onChange={(v) => set('corFundo', v)} />
              <CorField label="Painel" value={form.corPainel} onChange={(v) => set('corPainel', v)} />
            </div>
            <div className="space-y-1">
              <Label htmlFor="ap-raio">Raio dos cantos: {form.raio}px</Label>
              <input
                id="ap-raio"
                type="range"
                min={0}
                max={40}
                value={form.raio}
                onChange={(e) => set('raio', Number(e.target.value))}
                className="w-full accent-[hsl(var(--primary))]"
              />
            </div>
            <div className="space-y-1">
              <Label htmlFor="ap-nome">Nome da loja</Label>
              <Input id="ap-nome" value={form.nomeLoja ?? ''} onChange={(e) => set('nomeLoja', e.target.value)} placeholder="MISTER BURGERS" />
            </div>
            <div className="space-y-1">
              <Label>Logo da loja</Label>
              <ImageUploadTile value={form.logoUrl} onChange={(u) => set('logoUrl', u)} />
            </div>
            <SelectField
              label="Fonte display"
              value={form.fonteDisplay}
              options={['Tektur', 'Poppins', 'Montserrat']}
              onChange={(v) => set('fonteDisplay', v as Aparencia['fonteDisplay'])}
            />
            <SelectField
              label="Estilo do totem"
              value={form.temaPreset}
              options={['padrao', 'brasa', 'burger']}
              rotulos={{
                padrao: 'Padrão GoGeM',
                brasa: 'Brasa (steakhouse)',
                burger: 'Burger House (hambúrguer)',
              }}
              onChange={(v) =>
                aplicarPreset(v as Aparencia['temaPreset'])
              }
            />
            {PALETA_PRESET[form.temaPreset] && (
              <p className="text-xs text-muted-foreground">
                Este estilo já aplicou a paleta recomendada — ajuste as cores
                acima se quiser.
              </p>
            )}
          </CardContent>
        </Card>

        {/* Descanso + vitrine + animações */}
        <Card>
          <CardContent className="space-y-4 p-5">
            <h2 className="font-display font-semibold">Tela de descanso</h2>
            <SelectField
              label="Tipo"
              value={form.descansoTipo}
              options={['padrao', 'carrossel']}
              rotulos={{ padrao: 'Padrão GoGeM', carrossel: 'Carrossel (mídia da loja)' }}
              onChange={(v) => set('descansoTipo', v as Aparencia['descansoTipo'])}
            />
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label htmlFor="ap-chamada">Chamada</Label>
                <Input id="ap-chamada" value={form.chamada} onChange={(e) => set('chamada', e.target.value)} placeholder="TOQUE PARA PEDIR" />
              </div>
              <div className="space-y-1">
                <Label htmlFor="ap-int">Intervalo (s)</Label>
                <Input id="ap-int" inputMode="numeric" value={String(form.descansoIntervaloSeg)} onChange={(e) => set('descansoIntervaloSeg', Number(e.target.value.replace(/\D/g, '')) || 6)} />
              </div>
            </div>
            <div className="space-y-1">
              <Label htmlFor="ap-isca">Preço-isca (opcional)</Label>
              <Input id="ap-isca" value={form.precoIsca ?? ''} onChange={(e) => set('precoIsca', e.target.value)} placeholder="combos a partir de R$ 19,90" />
            </div>
            {form.descansoTipo === 'carrossel' && (
              <MidiasEditor
                midias={form.descansoMidias}
                onChange={(m) => set('descansoMidias', m)}
              />
            )}

            <h2 className="pt-2 font-display font-semibold">Vitrine & animações</h2>
            <SelectField
              label="Estilo do card"
              value={form.estiloCard}
              options={['cheia', 'lateral']}
              rotulos={{ cheia: 'Foto-cheia', lateral: 'Foto-lateral' }}
              onChange={(v) => set('estiloCard', v as Aparencia['estiloCard'])}
            />
            <SelectField
              label="Animações"
              value={form.animacoes}
              options={['cheio', 'reduzido', 'off']}
              rotulos={{ cheio: 'Cheio', reduzido: 'Reduzido', off: 'Desligado' }}
              onChange={(v) => set('animacoes', v as Aparencia['animacoes'])}
            />
            <p className="text-xs text-muted-foreground">
              Em totens fracos (ex.: Tinker Board) o app já reduz efeitos
              automaticamente; "Reduzido/Desligado" força globalmente.
            </p>
          </CardContent>
        </Card>
      </div>

      {erro && (
        <p role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {erro}
        </p>
      )}
      <div className="flex items-center justify-end gap-3">
        {ok && <span className="text-sm text-success">Aparência salva.</span>}
        {podeEscrever && (
          <Button variant="primary" onClick={onSalvar} disabled={salvar.isPending}>
            {salvar.isPending && <Loader2 className="animate-spin" aria-hidden />}
            Salvar aparência
          </Button>
        )}
      </div>
    </section>
  );
}

function CorField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="space-y-1">
      <Label>{label}</Label>
      <div className="flex items-center gap-2">
        <input
          type="color"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          aria-label={label}
          className="size-9 shrink-0 cursor-pointer rounded border border-input bg-transparent p-0.5"
        />
        <Input value={value} onChange={(e) => onChange(e.target.value)} className="font-mono" />
      </div>
    </div>
  );
}

function SelectField({
  label,
  value,
  options,
  rotulos,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  rotulos?: Record<string, string>;
  onChange: (v: string) => void;
}) {
  const id = React.useId();
  return (
    <div className="space-y-1">
      <Label htmlFor={id}>{label}</Label>
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {options.map((o) => (
          <option key={o} value={o}>
            {rotulos?.[o] ?? o}
          </option>
        ))}
      </select>
    </div>
  );
}

function MidiasEditor({
  midias,
  onChange,
}: {
  midias: DescansoMidia[];
  onChange: (m: DescansoMidia[]) => void;
}) {
  function patch(i: number, campo: keyof DescansoMidia, valor: string) {
    const novo = [...midias];
    novo[i] = { ...novo[i], [campo]: valor };
    onChange(novo);
  }

  return (
    <div className="space-y-2">
      <Label>Mídias do carrossel</Label>
      <div className="flex flex-wrap gap-3">
        {midias.map((m, i) => (
          <div
            key={i}
            className="w-40 space-y-2 rounded-lg border border-border p-2"
          >
            <ImageUploadTile
              value={m.url || null}
              onChange={(url) => {
                const novo = [...midias];
                if (url) novo[i] = { ...novo[i], url };
                else novo.splice(i, 1);
                onChange(novo);
              }}
            />
            {/* Legendas do slide (F3) — opcionais. */}
            <Input
              aria-label={`Chapéu do slide ${i + 1}`}
              value={m.kicker ?? ''}
              onChange={(e) => patch(i, 'kicker', e.target.value)}
              placeholder="Chapéu (ex.: Na brasa)"
              className="h-8 text-xs"
            />
            <Input
              aria-label={`Título do slide ${i + 1}`}
              value={m.titulo ?? ''}
              onChange={(e) => patch(i, 'titulo', e.target.value)}
              placeholder="Título"
              className="h-8 text-xs"
            />
            <Input
              aria-label={`Subtítulo do slide ${i + 1}`}
              value={m.subtitulo ?? ''}
              onChange={(e) => patch(i, 'subtitulo', e.target.value)}
              placeholder="Subtítulo"
              className="h-8 text-xs"
            />
          </div>
        ))}
        <button
          type="button"
          onClick={() => onChange([...midias, { url: '', tipo: 'imagem' }])}
          className="flex size-24 flex-col items-center justify-center gap-1 rounded-lg border border-dashed border-input text-xs text-muted-foreground hover:border-primary hover:text-foreground"
        >
          <Plus className="size-5" aria-hidden />
          Adicionar
        </button>
      </div>
      {midias.length === 0 && (
        <p className="flex items-center gap-1 text-xs text-muted-foreground">
          <Trash2 className="size-3" aria-hidden /> sem mídias — o carrossel cai no
          padrão GoGeM.
        </p>
      )}
    </div>
  );
}
