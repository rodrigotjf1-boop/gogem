import { Download } from 'lucide-react';
import { PagePlaceholder } from '@/components/page-placeholder';

export default function ImportarPage() {
  return (
    <PagePlaceholder
      title="Importar"
      description="Importação de produtos do Regem por código PDV (external_refs) e CSV."
      icon={Download}
      sprint="S1–S2"
    />
  );
}
