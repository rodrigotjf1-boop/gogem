import * as React from 'react';
import { ImagePlus, Loader2, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useUploadImagem } from '@/lib/catalogo';

/** Limite espelhado do backend (POST /midia): 5 MB, imagens comuns. */
const MAX_BYTES = 5 * 1024 * 1024;
const TIPOS = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

/**
 * ImageUploadTile — padrão de upload de imagem do projeto (mockup Regem): só o
 * quadrado com "+"; clicar abre o seletor de arquivo. Com imagem, mostra a
 * prévia + um "×" para remover. Sem botão "enviar imagem" separado. Reutilizar
 * em qualquer tela/modal que suba imagem.
 */
export function ImageUploadTile({
  value,
  onChange,
  disabled,
  className,
}: {
  value: string | null;
  onChange: (url: string | null) => void;
  disabled?: boolean;
  className?: string;
}) {
  const upload = useUploadImagem();
  const inputRef = React.useRef<HTMLInputElement>(null);
  const [erro, setErro] = React.useState<string | null>(null);
  const ocupado = disabled || upload.isPending;

  async function onEscolher(e: React.ChangeEvent<HTMLInputElement>) {
    const arquivo = e.target.files?.[0];
    e.target.value = ''; // permite reescolher o mesmo arquivo
    if (!arquivo) return;
    setErro(null);
    if (!TIPOS.includes(arquivo.type)) {
      setErro('Use JPG, PNG, WEBP ou GIF.');
      return;
    }
    if (arquivo.size > MAX_BYTES) {
      setErro('A imagem deve ter até 5 MB.');
      return;
    }
    try {
      onChange(await upload.mutateAsync(arquivo));
    } catch {
      setErro('Não foi possível subir a imagem. Tente novamente.');
    }
  }

  return (
    <div className={cn('space-y-1', className)}>
      <div className="relative size-24">
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={ocupado}
          aria-label={value ? 'Trocar imagem' : 'Adicionar imagem'}
          className="flex size-24 items-center justify-center overflow-hidden rounded-lg border border-dashed border-input bg-muted transition-colors hover:border-primary hover:bg-secondary/40 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {upload.isPending ? (
            <Loader2 className="size-6 animate-spin text-muted-foreground" aria-hidden />
          ) : value ? (
            <img src={value} alt="" className="size-full object-cover" />
          ) : (
            <ImagePlus className="size-7 text-muted-foreground" aria-hidden />
          )}
        </button>
        {value && !ocupado && (
          <button
            type="button"
            onClick={() => onChange(null)}
            aria-label="Remover imagem"
            className="absolute -right-2 -top-2 flex size-6 items-center justify-center rounded-full border border-border bg-card text-destructive shadow-sm hover:bg-destructive hover:text-destructive-foreground"
          >
            <X className="size-3.5" aria-hidden />
          </button>
        )}
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          className="sr-only"
          onChange={onEscolher}
          disabled={ocupado}
        />
      </div>
      <p className="text-xs text-muted-foreground">JPG, PNG, WEBP ou GIF · até 5 MB</p>
      {erro && <p className="text-xs text-destructive">{erro}</p>}
    </div>
  );
}
