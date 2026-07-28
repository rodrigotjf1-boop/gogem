import * as React from 'react';
import { ImagePlus, Loader2, Trash2 } from 'lucide-react';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { centavosParaReais, reaisParaCentavos } from '@/lib/money';
import {
  codigoPdvRegem,
  useAtualizarProduto,
  useCriarProduto,
  useUploadImagem,
  type Categoria,
  type ExternalRef,
  type Produto,
  type ProdutoInput,
} from '@/lib/catalogo';

/** Limite espelhado do backend (POST /midia): 5 MB, imagens comuns. */
const MAX_BYTES = 5 * 1024 * 1024;
const TIPOS_ACEITOS = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

const schema = z.object({
  nome: z.string().trim().min(1, 'Informe o nome do produto'),
  precoCentavos: z
    .number({ invalid_type_error: 'Preço inválido' })
    .int()
    .min(0, 'O preço não pode ser negativo'),
});

interface ProdutoDialogProps {
  aberto: boolean;
  onFechar: () => void;
  categorias: Categoria[];
  /** Presente = edição; ausente = criação. */
  produto?: Produto;
}

/** Formulário de criar/editar produto, incluindo o de-para PDV do Regem (§4). */
export function ProdutoDialog({
  aberto,
  onFechar,
  categorias,
  produto,
}: ProdutoDialogProps) {
  const editando = Boolean(produto);
  const criar = useCriarProduto();
  const atualizar = useAtualizarProduto();
  const upload = useUploadImagem();
  const inputFotoRef = React.useRef<HTMLInputElement>(null);

  const [nome, setNome] = React.useState('');
  const [descricao, setDescricao] = React.useState('');
  const [preco, setPreco] = React.useState('');
  const [disponivel, setDisponivel] = React.useState(true);
  const [categoriaId, setCategoriaId] = React.useState('');
  const [codigoPdv, setCodigoPdv] = React.useState('');
  const [imagemUrl, setImagemUrl] = React.useState<string | null>(null);
  const [erros, setErros] = React.useState<Record<string, string>>({});
  const [erroGeral, setErroGeral] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (!aberto) return;
    setNome(produto?.nome ?? '');
    setDescricao(produto?.descricao ?? '');
    setPreco(produto ? centavosParaReais(produto.precoCentavos) : '');
    setDisponivel(produto?.disponivel ?? true);
    setCategoriaId(produto?.categoriaId ?? '');
    setCodigoPdv(produto ? (codigoPdvRegem(produto) ?? '') : '');
    setImagemUrl(produto?.imagemUrl ?? null);
    setErros({});
    setErroGeral(null);
  }, [aberto, produto]);

  const enviando = criar.isPending || atualizar.isPending;

  async function onEscolherFoto(e: React.ChangeEvent<HTMLInputElement>) {
    const arquivo = e.target.files?.[0];
    e.target.value = ''; // permite reescolher o mesmo arquivo
    if (!arquivo) return;
    setErros((x) => ({ ...x, foto: '' }));
    if (!TIPOS_ACEITOS.includes(arquivo.type)) {
      setErros((x) => ({ ...x, foto: 'Use JPG, PNG, WEBP ou GIF.' }));
      return;
    }
    if (arquivo.size > MAX_BYTES) {
      setErros((x) => ({ ...x, foto: 'A imagem deve ter até 5 MB.' }));
      return;
    }
    try {
      const url = await upload.mutateAsync(arquivo);
      setImagemUrl(url);
    } catch {
      setErros((x) => ({
        ...x,
        foto: 'Não foi possível subir a imagem. Tente novamente.',
      }));
    }
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErroGeral(null);

    const centavos = reaisParaCentavos(preco);
    const parsed = schema.safeParse({
      nome,
      precoCentavos: centavos ?? Number.NaN,
    });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setErros({
        nome: f.nome?.[0] ?? '',
        preco: f.precoCentavos?.[0] ?? '',
      });
      return;
    }
    setErros({});

    // De-para PDV: só monta o ref do Regem quando há código informado.
    const cod = codigoPdv.trim();
    const externalRefs: ExternalRef[] = cod
      ? [{ sistema: 'regem', codigo_pdv: cod }]
      : [];

    const input: ProdutoInput = {
      nome: parsed.data.nome,
      descricao: descricao.trim() || undefined,
      precoCentavos: parsed.data.precoCentavos,
      disponivel,
      imagemUrl,
      categoriaId: categoriaId || undefined,
      externalRefs,
    };

    try {
      if (produto) {
        await atualizar.mutateAsync({ id: produto.id, input });
      } else {
        await criar.mutateAsync(input);
      }
      onFechar();
    } catch {
      setErroGeral('Não foi possível salvar o produto. Tente novamente.');
    }
  }

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={editando ? 'Editar produto' : 'Novo produto'}
      descricao="Preço em reais; o código PDV liga o produto ao Regem."
    >
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="prod-nome">Nome</Label>
          <Input
            id="prod-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="X-Salada"
            disabled={enviando}
            aria-invalid={Boolean(erros.nome)}
            autoFocus
          />
          {erros.nome && (
            <p className="text-xs text-destructive">{erros.nome}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label>Foto do produto</Label>
          <div className="flex items-center gap-4">
            <div className="flex size-20 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-input bg-muted">
              {imagemUrl ? (
                <img
                  src={imagemUrl}
                  alt="Prévia da foto do produto"
                  className="size-full object-cover"
                />
              ) : (
                <ImagePlus
                  className="size-6 text-muted-foreground"
                  aria-hidden
                />
              )}
            </div>
            <div className="flex flex-col gap-2">
              <input
                ref={inputFotoRef}
                type="file"
                accept="image/jpeg,image/png,image/webp,image/gif"
                className="sr-only"
                onChange={onEscolherFoto}
                disabled={enviando || upload.isPending}
              />
              <div className="flex flex-wrap gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => inputFotoRef.current?.click()}
                  disabled={enviando || upload.isPending}
                >
                  {upload.isPending ? (
                    <Loader2 className="animate-spin" aria-hidden />
                  ) : (
                    <ImagePlus aria-hidden />
                  )}
                  {imagemUrl ? 'Trocar foto' : 'Adicionar foto'}
                </Button>
                {imagemUrl && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => setImagemUrl(null)}
                    disabled={enviando || upload.isPending}
                  >
                    <Trash2 aria-hidden />
                    Remover
                  </Button>
                )}
              </div>
              <p className="text-xs text-muted-foreground">
                JPG, PNG, WEBP ou GIF, até 5 MB. Boas fotos dão vontade de
                consumir.
              </p>
            </div>
          </div>
          {erros.foto && <p className="text-xs text-destructive">{erros.foto}</p>}
        </div>

        <div className="space-y-2">
          <Label htmlFor="prod-descricao">Descrição</Label>
          <Textarea
            id="prod-descricao"
            value={descricao}
            onChange={(e) => setDescricao(e.target.value)}
            placeholder="Pão, hambúrguer, salada e queijo."
            disabled={enviando}
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="prod-preco">Preço (R$)</Label>
            <Input
              id="prod-preco"
              inputMode="decimal"
              value={preco}
              onChange={(e) => setPreco(e.target.value)}
              placeholder="25,90"
              disabled={enviando}
              aria-invalid={Boolean(erros.preco)}
            />
            {erros.preco && (
              <p className="text-xs text-destructive">{erros.preco}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="prod-categoria">Categoria</Label>
            <select
              id="prod-categoria"
              value={categoriaId}
              onChange={(e) => setCategoriaId(e.target.value)}
              disabled={enviando}
              className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="">Sem categoria</option>
              {categorias.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.nome}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="space-y-2">
          <Label htmlFor="prod-codigo-pdv">Código PDV (Regem)</Label>
          <Input
            id="prod-codigo-pdv"
            value={codigoPdv}
            onChange={(e) => setCodigoPdv(e.target.value)}
            placeholder="PROD-001"
            disabled={enviando}
            className="font-mono"
          />
          <p className="text-xs text-muted-foreground">
            Liga este produto ao Regem pelo <code>codigo</code> do PDV. Deixe em
            branco se ainda não houver.
          </p>
        </div>

        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={disponivel}
            onChange={(e) => setDisponivel(e.target.checked)}
            disabled={enviando}
            className="size-4 rounded border-input accent-[hsl(var(--primary))]"
          />
          Disponível para venda
        </label>

        {erroGeral && (
          <p
            role="alert"
            className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
          >
            {erroGeral}
          </p>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <Button
            type="button"
            variant="outline"
            onClick={onFechar}
            disabled={enviando}
          >
            Cancelar
          </Button>
          <Button type="submit" variant="primary" disabled={enviando}>
            {enviando && <Loader2 className="animate-spin" aria-hidden />}
            {editando ? 'Salvar' : 'Criar produto'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
