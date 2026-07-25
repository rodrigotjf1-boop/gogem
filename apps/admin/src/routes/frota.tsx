import { Radio } from 'lucide-react';
import { PagePlaceholder } from '@/components/page-placeholder';

export default function FrotaPage() {
  return (
    <PagePlaceholder
      title="Frota"
      description="Telemetria dos totens: heartbeat, papel/pinpad, fila de reimpressão e OTA."
      icon={Radio}
      sprint="S5"
    />
  );
}
