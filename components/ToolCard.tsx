import Link from 'next/link';
import Icon from './Icon';
import { getCategory } from '@/data/categories';
import type { Tool } from '@/data/tools';

export default function ToolCard({ tool }: { tool: Tool }) {
  const cat = getCategory(tool.category);
  const accent = `var(--${cat?.accent || 'brand-primary'})`;
  return (
    <Link href={`/tools/${tool.category}/${tool.slug}`} className="tool-card">
      <span className="tool-icon" style={{ background: accent }}>
        <Icon name={tool.icon} size={21} />
      </span>
      {(tool.badge === 'new' || tool.badge === 'ai') && (
        <span className="tool-badge">
          <span className={`pill ${tool.badge === 'new' ? 'pill-new' : 'pill-ai'}`}>{tool.badge.toUpperCase()}</span>
        </span>
      )}
      <span className="tool-name">{tool.name}</span>
      <span className="tool-desc">{tool.description}</span>
      <span className="tool-foot">
        <span className="tool-tag">{tool.badge === 'popular' ? 'Popular' : cat?.shortName}</span>
        <span className="tool-arrow"><Icon name="arrow-right" size={14} /></span>
      </span>
    </Link>
  );
}
