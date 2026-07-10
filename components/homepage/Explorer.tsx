'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import Icon from '../Icon';
import ToolCard from '../ToolCard';
import { sidebarEntries, categories } from '@/data/categories';
import { tools, homepageToolSlugs, getTool } from '@/data/tools';

const PAGE = 15;

export default function Explorer() {
  const [active, setActive] = useState('');
  const [sort, setSort] = useState('popular');
  const [view, setView] = useState<'grid' | 'list'>('grid');
  const [shown, setShown] = useState(PAGE);

  const list = useMemo(() => {
    let l = active ? tools.filter((t) => t.category === active) : [...tools];
    if (!active && sort === 'popular') {
      // Homepage default: mockup's exact 15 cards first, then the rest
      const featured = homepageToolSlugs.map((s) => getTool(s)!).filter(Boolean);
      const featuredSet = new Set(homepageToolSlugs);
      l = [...featured, ...l.filter((t) => !featuredSet.has(t.slug))];
    } else if (sort === 'popular') {
      l.sort((a, b) => (b.badge === 'popular' ? 1 : 0) - (a.badge === 'popular' ? 1 : 0));
    } else if (sort === 'az') {
      l.sort((a, b) => a.name.localeCompare(b.name));
    } else if (sort === 'new') {
      l.sort((a, b) => (b.badge === 'new' ? 1 : 0) - (a.badge === 'new' ? 1 : 0));
    }
    return l;
  }, [active, sort]);

  const activeCat = categories.find((c) => c.slug === active);
  const visible = list.slice(0, shown);
  const exhausted = shown >= list.length;

  return (
    <section className="container explorer" id="tools">
      {/* Sidebar */}
      <aside className="sidebar glass" aria-label="Browse by category">
        <h3>Browse by Category</h3>
        {sidebarEntries.map((e) => (
          <button
            key={e.label}
            className={`sidebar-item ${active === e.slug ? 'active' : ''}`}
            onClick={() => { setActive(e.slug); setShown(PAGE); }}
          >
            <Icon name={e.icon} size={16} />
            <span className="side-label">{e.label} {e.badge && <span className="pill pill-nav-new">NEW</span>}</span>
            <span className="side-count">{e.count}</span>
          </button>
        ))}
        <Link href="/tools" className="sidebar-item" style={{ marginTop: 6, color: 'var(--brand-primary-hover)' }}>
          <Icon name="grid" size={16} /> <span className="side-label">All Categories</span>
        </Link>
      </aside>

      {/* Grid panel */}
      <div>
        <div className="explorer-head">
          <div>
            <h2>{activeCat ? activeCat.name : 'All Tools'} <span>({activeCat ? list.length : '150+'})</span></h2>
            <p className="explorer-sub">Discover and use powerful tools for all your needs.</p>
          </div>
          <div className="explorer-controls">
            <select className="select-control" value={active} onChange={(e) => { setActive(e.target.value); setShown(PAGE); }} aria-label="Filter by category">
              <option value="">All Categories</option>
              {categories.map((c) => (<option key={c.slug} value={c.slug}>{c.name}</option>))}
            </select>
            <select className="select-control" value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort tools">
              <option value="popular">Sort by: Popular</option>
              <option value="az">Sort by: A → Z</option>
              <option value="new">Sort by: Newest</option>
            </select>
            <div className="view-toggle">
              <button className={view === 'grid' ? 'active' : ''} onClick={() => setView('grid')} aria-label="Grid view"><Icon name="grid" size={15} /></button>
              <button className={view === 'list' ? 'active' : ''} onClick={() => setView('list')} aria-label="List view"><Icon name="list" size={15} /></button>
            </div>
          </div>
        </div>

        <div className={`tool-grid ${view === 'list' ? 'list-view' : ''}`}>
          {visible.map((t) => (<ToolCard key={t.slug} tool={t} />))}
        </div>

        <div className="load-more-wrap">
          {exhausted ? (
            <span className="muted" style={{ fontSize: 14 }}>You&apos;ve seen all {list.length} tools ✓</span>
          ) : (
            <button className="btn btn-ghost" onClick={() => setShown((s) => s + PAGE)}>
              <Icon name="refresh" size={15} /> Load More Tools
            </button>
          )}
        </div>
      </div>
    </section>
  );
}
