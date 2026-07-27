import * as React from 'react';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';

interface ConfirmDialogProps {
  aberto: boolean;
  titulo: string;
  descricao: string;
  rotuloConfirmar?: string;
  /** Ação assíncrona; se lançar, a mensagem é exibida e o modal permanece. */
  onConfirmar: () => Promise<void>;
  onFechar: () => void;
}

/** Confirmação destrutiva genérica (excluir categoria/produto). */
export function ConfirmDialog({
  aberto,
  titulo,
  descricao,
  rotuloConfirmar = 'Excluir',
  onConfirmar,
  onFechar,
}: ConfirmDialogProps) {
  const [enviando, setEnviando] = React.useState(false);
  const [erro, setErro] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (aberto) setErro(null);
  }, [aberto]);

  async function confirmar() {
    setErro(null);
    setEnviando(true);
    try {
      await onConfirmar();
      onFechar();
    } catch (e) {
      // Mensagem do backend quando disponível (ex.: 409 categoria com produtos).
      const msg =
        (e as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? 'Não foi possível concluir. Tente novamente.';
      setErro(Array.isArray(msg) ? msg.join(' ') : String(msg));
    } finally {
      setEnviando(false);
    }
  }

  return (
    <Dialog
      aberto={aberto}
      onFechar={onFechar}
      titulo={titulo}
      descricao={descricao}
      larguraClasse="max-w-md"
    >
      <div className="space-y-4">
        {erro && (
          <p
            role="alert"
            className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive"
          >
            {erro}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={onFechar}
            disabled={enviando}
          >
            Cancelar
          </Button>
          <Button
            type="button"
            variant="destructive"
            onClick={confirmar}
            disabled={enviando}
          >
            {enviando && <Loader2 className="animate-spin" aria-hidden />}
            {rotuloConfirmar}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
