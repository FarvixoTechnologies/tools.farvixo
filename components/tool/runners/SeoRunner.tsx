'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock, ErrorBox } from '../shared';
import Icon from '../../Icon';

export default function SeoRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const [url, setUrl] = useState('');
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const [keywords, setKeywords] = useState('');
  const [image, setImage] = useState('');
  const [siteName, setSiteName] = useState('');
  const [urlList, setUrlList] = useState('');
  const [disallow, setDisallow] = useState('/admin\n/api');
  const [allowAll, setAllowAll] = useState(true);
  const [sitemapUrl, setSitemapUrl] = useState('');
  const [schemaType, setSchemaType] = useState('Organization');
  const [text, setText] = useState('');
  const [keyword, setKeyword] = useState('');

  const esc = (s: string) => s.replace(/"/g, '&quot;');

  const run = async () => {
    setError('');
    try {
      if (mode === 'analyze') {
        if (!url.trim()) throw new Error('Enter a URL to analyze.');
        setBusy(true);
        const res = await fetch(`/api/seo/analyze?url=${encodeURIComponent(url.trim())}`);
        const json = await res.json();
        setBusy(false);
        if (!json.success) throw new Error(json.error || 'Analysis failed');
        setOutput(json.data.report as string);
      } else if (mode === 'meta') {
        setOutput([
          `<title>${title}</title>`,
          `<meta name="description" content="${esc(desc)}" />`,
          keywords && `<meta name="keywords" content="${esc(keywords)}" />`,
          `<meta name="viewport" content="width=device-width, initial-scale=1" />`,
          `<meta charset="UTF-8" />`,
          url && `<link rel="canonical" href="${url}" />`,
          `<meta name="robots" content="index, follow" />`,
        ].filter(Boolean).join('\n'));
      } else if (mode === 'og') {
        setOutput([
          `<meta property="og:title" content="${esc(title)}" />`,
          `<meta property="og:description" content="${esc(desc)}" />`,
          url && `<meta property="og:url" content="${url}" />`,
          image && `<meta property="og:image" content="${image}" />`,
          siteName && `<meta property="og:site_name" content="${esc(siteName)}" />`,
          `<meta property="og:type" content="website" />`,
          `<meta name="twitter:card" content="summary_large_image" />`,
          `<meta name="twitter:title" content="${esc(title)}" />`,
          `<meta name="twitter:description" content="${esc(desc)}" />`,
          image && `<meta name="twitter:image" content="${image}" />`,
        ].filter(Boolean).join('\n'));
      } else if (mode === 'sitemap') {
        const urls = urlList.split('\n').map((u) => u.trim()).filter(Boolean);
        if (urls.length === 0) throw new Error('Add at least one URL (one per line).');
        const today = new Date().toISOString().slice(0, 10);
        setOutput(
          `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
          urls.map((u) => `  <url>\n    <loc>${u}</loc>\n    <lastmod>${today}</lastmod>\n    <changefreq>weekly</changefreq>\n    <priority>0.8</priority>\n  </url>`).join('\n') +
          `\n</urlset>`,
        );
      } else if (mode === 'robots') {
        const rules = disallow.split('\n').map((d) => d.trim()).filter(Boolean).map((d) => `Disallow: ${d}`).join('\n');
        setOutput(`User-agent: *\n${allowAll ? 'Allow: /\n' : ''}${rules}${sitemapUrl ? `\n\nSitemap: ${sitemapUrl}` : ''}`);
      } else if (mode === 'schema') {
        let schema: Record<string, unknown> = { '@context': 'https://schema.org', '@type': schemaType };
        if (schemaType === 'Organization') schema = { ...schema, name: title, url, logo: image, description: desc };
        else if (schemaType === 'Article') schema = { ...schema, headline: title, description: desc, image, datePublished: new Date().toISOString(), author: { '@type': 'Person', name: siteName || 'Author' } };
        else if (schemaType === 'Product') schema = { ...schema, name: title, description: desc, image, offers: { '@type': 'Offer', price: '0.00', priceCurrency: 'USD' } };
        else if (schemaType === 'LocalBusiness') schema = { ...schema, name: title, description: desc, url, image };
        else if (schemaType === 'FAQPage') schema = { ...schema, mainEntity: [{ '@type': 'Question', name: 'Your question?', acceptedAnswer: { '@type': 'Answer', text: 'Your answer.' } }] };
        setOutput(`<script type="application/ld+json">\n${JSON.stringify(schema, null, 2)}\n</script>`);
      } else if (mode === 'density') {
        const words = text.toLowerCase().match(/[a-zऀ-ॿ]+/g) || [];
        const total = words.length;
        if (total === 0) throw new Error('Paste some content first.');
        const freq = new Map<string, number>();
        for (const w of words) if (w.length > 3) freq.set(w, (freq.get(w) || 0) + 1);
        const top = Array.from(freq.entries()).sort((a, b) => b[1] - a[1]).slice(0, 20);
        let head = `Total words: ${total}\n`;
        if (keyword.trim()) {
          const k = keyword.trim().toLowerCase();
          const kCount = (text.toLowerCase().match(new RegExp(`\\b${k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'g')) || []).length;
          head += `Keyword "${keyword}": ${kCount} times (${((kCount / total) * 100).toFixed(2)}% density)\n`;
        }
        setOutput(head + '\nTop keywords:\n' + top.map(([w, c]) => `${w.padEnd(20)} ${String(c).padStart(4)}  (${((c / total) * 100).toFixed(2)}%)`).join('\n'));
      } else if (mode === 'canonical') {
        if (!url.trim()) throw new Error('Enter a URL.');
        const u = new URL(url.trim());
        u.hash = '';
        u.search = '';
        setOutput(`<link rel="canonical" href="${u.toString()}" />`);
      }
    } catch (e) {
      setBusy(false);
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const needsTitleDesc = ['meta', 'og', 'schema'].includes(mode);

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {(mode === 'analyze' || mode === 'canonical' || needsTitleDesc) && (
          <div className="field"><label>Page URL {needsTitleDesc && '(optional)'}</label><input value={url} placeholder="https://example.com" onChange={(e) => setUrl(e.target.value)} /></div>
        )}
        {needsTitleDesc && (
          <>
            <div className="field"><label>Title / Name</label><input value={title} onChange={(e) => setTitle(e.target.value)} /></div>
            <div className="field"><label>Description</label><textarea value={desc} style={{ minHeight: 70 }} onChange={(e) => setDesc(e.target.value)} /></div>
          </>
        )}
        {mode === 'meta' && <div className="field"><label>Keywords (comma separated)</label><input value={keywords} onChange={(e) => setKeywords(e.target.value)} /></div>}
        {(mode === 'og' || mode === 'schema') && (
          <>
            <div className="field"><label>Image URL</label><input value={image} onChange={(e) => setImage(e.target.value)} /></div>
            <div className="field"><label>{mode === 'og' ? 'Site name' : 'Author / brand'}</label><input value={siteName} onChange={(e) => setSiteName(e.target.value)} /></div>
          </>
        )}
        {mode === 'schema' && (
          <div className="field"><label>Schema type</label>
            <select value={schemaType} onChange={(e) => setSchemaType(e.target.value)}>
              {['Organization', 'Article', 'Product', 'LocalBusiness', 'FAQPage'].map((t) => <option key={t}>{t}</option>)}
            </select></div>
        )}
        {mode === 'sitemap' && (
          <div className="field"><label>URLs (one per line)</label><textarea value={urlList} style={{ minHeight: 150 }} placeholder={'https://example.com/\nhttps://example.com/about'} onChange={(e) => setUrlList(e.target.value)} /></div>
        )}
        {mode === 'robots' && (
          <>
            <label className="checkbox-row"><input type="checkbox" checked={allowAll} onChange={(e) => setAllowAll(e.target.checked)} /> Allow all crawlers</label>
            <div className="field"><label>Disallow paths (one per line)</label><textarea value={disallow} style={{ minHeight: 90 }} onChange={(e) => setDisallow(e.target.value)} /></div>
            <div className="field"><label>Sitemap URL (optional)</label><input value={sitemapUrl} placeholder="https://example.com/sitemap.xml" onChange={(e) => setSitemapUrl(e.target.value)} /></div>
          </>
        )}
        {mode === 'density' && (
          <>
            <div className="field"><label>Content</label><textarea value={text} style={{ minHeight: 160 }} placeholder="Paste your article/content..." onChange={(e) => setText(e.target.value)} /></div>
            <div className="field"><label>Target keyword (optional)</label><input value={keyword} onChange={(e) => setKeyword(e.target.value)} /></div>
          </>
        )}
        {error && <ErrorBox message={error} />}
        <button className="btn btn-primary" disabled={busy} onClick={() => void run()}>
          <Icon name="search" size={15} /> {busy ? 'Analyzing...' : mode === 'analyze' ? 'Analyze Now' : 'Generate Now'}
        </button>
      </div>
      <div>{output ? <OutputBlock text={output} filename={mode === 'sitemap' ? 'sitemap.xml' : mode === 'robots' ? 'robots.txt' : `${tool.slug}.txt`} /> : <div className="output-area" style={{ minHeight: 240, color: 'var(--text-muted)' }}>Output will appear here.</div>}</div>
    </div>
  );
}
