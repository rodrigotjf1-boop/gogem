import { UploadCloud } from 'lucide-react';
import { PagePlaceholder } from '@/components/page-placeholder';

export default function PublicarPage() {
  return (
    <PagePlaceholder
      title="Publicar"
      description="Publicação versionada do cardápio (menu_versions) para os totens."
      icon={UploadCloud}
      sprint="S1–S2"
    />
  );
}
