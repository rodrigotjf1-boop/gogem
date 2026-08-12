import * as React from 'react';
import { Loader2 } from 'lucide-react';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { ImageUploadTile } from '@/components/ui/image-upload';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  useAtualizarCategoria,
  useCriarCategoria,
  type Categoria,
} from '@/lib/catalogo';

const schema = z.object({
  nome: z.string().trim().min(1, 'Informe o nome da categoria'),
  ordem: z
    .number({ invalid_type_error: 'Informe um número' })
    .int('Use um número inteiro')
    .min(0, 'A ordem não pode ser negativa'),
});

interface CategoriaDialogProps {
  aberto: boolean;
  onFechar: () => void;
  /** Presente = edição; ausente = criação. */
  categoria?: Categoria;
}

/** Formulário de criar/editar categoria (valida com zod, grava na API real). */
export function CategoriaDialog({
  aberto,
  onFechar,
  categoria,
}: CategoriaDialogProps) {
  const editando = Boolean(categoria);
  const criar = useCriarCategoria();
  const atualizar = useAtualizarCategoria();

  const [nome, setNome] = React.useState('');
  const [ordem, setOrdem] = React.useState('0');
  const [imagemUrl, setImagemUrl] = React.useState<string | null>(null);
  const [emoji, setEmoji] = React.useState('');
  const [cor, setCor] = React.useState('');
  const [erros, setErros] = React.useState<Record<string, string>>({});
  const [erroGeral, setErroGeral] = React.useState<string | null>(null);

  // Repopula os campos sempre que abrir (novo ou edição).
  React.useEffect(() => {
    if (!aberto) return;
    setNome(categoria?.nome ?? '');
    setOrdem(String(categoria?.ordem ?? 0));
    setImagemUrl(categoria?.imagemUrl ?? null);
    setEmoji(categoria?.emoji ?? '');
    setCor(categoria?.cor ?? '');
    setErros({});
    setErroGeral(null);
  }, [aberto, categoria]);

  const enviando = criar.isPending || atualizar.isPending;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErroGeral(null);
    const parsed = schema.safeParse({ nome, ordem: Number(ordem) });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setErros({ nome: f.nome?.[0] ?? '', ordem: f.ordem?.[0] ?? '' });
      return;
    }
    setErros({});
    const input = {
      ...parsed.data,
      imagemUrl,
      emoji: emoji.trim() || null,
      cor: cor.trim() || null,
    };
    try {
      if (categoria) {
        await atualizar.mutateAsync({ id: categoria.id, input });
      } else {
        await criar.mutateAsync(input);
      }
      onFechar();
    } catch {
      setErroGeral('Não foi possível salvar a categoria. Tente novamente.');
    }
  }

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={editando ? 'Editar categoria' : 'Nova categoria'}
      descricao="Categorias organizam os produtos no cardápio do totem."
    >
      <form className="space-y-4" onSubmit={onSubmit} noValidate>
        <div className="space-y-2">
          <Label htmlFor="cat-nome">Nome</Label>
          <Input
            id="cat-nome"
            value={nome}
            onChange={(e) => setNome(e.target.value)}
            placeholder="Bebidas"
            disabled={enviando}
            aria-invalid={Boolean(erros.nome)}
            autoFocus
          />
          {erros.nome && (
            <p className="text-xs text-destructive">{erros.nome}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="cat-ordem">Ordem de exibição</Label>
          <Input
            id="cat-ordem"
            type="number"
            min={0}
            step={1}
            value={ordem}
            onChange={(e) => setOrdem(e.target.value)}
            disabled={enviando}
            aria-invalid={Boolean(erros.ordem)}
            className="max-w-32"
          />
          <p className="text-xs text-muted-foreground">Menor aparece primeiro.</p>
          {erros.ordem && (
            <p className="text-xs text-destructive">{erros.ordem}</p>
          )}
        </div>

        <div className="space-y-2">
          <Label>Imagem da categoria</Label>
          <ImageUploadTile
            value={imagemUrl}
            onChange={setImagemUrl}
            disabled={enviando}
          />
          <p className="text-xs text-muted-foreground">
            Aparece na roleta do totem. Sem imagem, usa o emoji abaixo.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-2">
            <Label htmlFor="cat-emoji">Emoji</Label>
            <Input
              id="cat-emoji"
              value={emoji}
              onChange={(e) => setEmoji(e.target.value)}
              placeholder="🍔"
              maxLength={16}
              disabled={enviando}
              className="max-w-24 text-2xl"
            />
            <p className="text-xs text-muted-foreground">Sem imagem.</p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="cat-cor">Cor de destaque</Label>
            <div className="flex items-center gap-2">
              <input
                id="cat-cor"
                type="color"
                value={cor || '#E2A340'}
                onChange={(e) => setCor(e.target.value)}
                disabled={enviando}
                className="h-9 w-12 cursor-pointer rounded border border-input bg-transparent"
                aria-label="Cor de destaque da categoria"
              />
              <Input
                value={cor}
                onChange={(e) => setCor(e.target.value)}
                placeholder="#E03A2F"
                maxLength={9}
                disabled={enviando}
                className="max-w-28"
              />
              {cor && (
                <button
                  type="button"
                  onClick={() => setCor('')}
                  disabled={enviando}
                  className="text-xs text-muted-foreground underline"
                >
                  limpar
                </button>
              )}
            </div>
            <p className="text-xs text-muted-foreground">Opcional.</p>
          </div>
        </div>

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
            {editando ? 'Salvar' : 'Criar categoria'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
