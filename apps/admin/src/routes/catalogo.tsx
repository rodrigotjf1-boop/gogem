import { BookOpen } from 'lucide-react';
import { PagePlaceholder } from '@/components/page-placeholder';

export default function CatalogoPage() {
  return (
    <PagePlaceholder
      title="Catálogo"
      description="Categorias, produtos, complementos, preços e disponibilidade da loja."
      icon={BookOpen}
      sprint="S1–S2"
    />
  );
}
