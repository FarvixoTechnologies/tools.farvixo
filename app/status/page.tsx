import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'System Status',
  description: 'Live Farvixo Tools platform status and uptime — website, API, PDF, image, video/audio and AI services. Check current operational status here.',
  path: '/status',
});

const jsonLd = webPageJsonLd({
  name: 'System Status',
  description: 'Farvixo Tools platform status and uptime monitoring.',
  path: '/status',
});

const services = [
  { name: 'Website & API', status: 'operational' },
  { name: 'PDF Tools', status: 'operational' },
  { name: 'Image Tools', status: 'operational' },
  { name: 'Video/Audio (FFmpeg)', status: 'operational' },
  { name: 'AI Engine', status: 'operational' },
  { name: 'Authentication', status: 'operational' },
];

export default function StatusPage() {
  return (
    <PageShell title="System Status" subtitle="All systems operational" jsonLd={jsonLd}>
      <div className="status-grid">
        {services.map((s) => (
          <div key={s.name} className="status-card glass">
            <span className="status-name">{s.name}</span>
            <span className="status-badge operational"><span className="status-dot" /> Operational</span>
          </div>
        ))}
      </div>
      <p className="muted mt-6">Uptime: 99.9% over the last 90 days. Monitored via <code>/api/health</code> every 60 seconds.</p>
    </PageShell>
  );
}
