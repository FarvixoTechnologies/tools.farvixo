import type { Metadata } from 'next';
import Icon from '@/components/Icon';
import AllToolsExplorer from '@/components/tools/AllToolsExplorer';
import { tools } from '@/data/tools';

export const metadata: Metadata = {
  title: `All Tools (${tools.length}) — Farvixo Tools`,
  description:
    'Browse all 139+ free online tools: PDF, Image, Video, Audio, AI, Developer, Text, SEO, Business, Government and more. Search, drop a file to find matching tools, pin favorites.',
};

export default function AllToolsPage() {
  return (
    <div className="container" style={{ paddingBottom: 64 }}>
      <div className="cat-hero">
        <div className="cat-hero-inner">
          <span className="cat-hero-icon" style={{ background: 'var(--brand-gradient)' }}><Icon name="grid" size={30} /></span>
          <div>
            <h1>All Tools <span className="gradient-text">({tools.length})</span></h1>
            <p>Search, speak, ya file drop karo — sahi tool khud mil jayega. Pin favorites, sab free.</p>
          </div>
        </div>
      </div>

      <AllToolsExplorer />
    </div>
  );
}
