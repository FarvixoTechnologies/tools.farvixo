import Link from 'next/link';
import Icon from '../Icon';
import BrandLogo from '../BrandLogo';

const explore = [
  { label: 'All Tools', href: '/tools' },
  { label: 'AI Tools', href: '/tools/ai', badge: 'NEW' },
  { label: 'PDF Tools', href: '/tools/pdf' },
  { label: 'Image Tools', href: '/tools/image' },
  { label: 'Video Tools', href: '/tools/video' },
  { label: 'Audio Tools', href: '/tools/audio' },
  { label: 'Developer Tools', href: '/tools/developer' },
  { label: 'Text Tools', href: '/tools/text' },
  { label: 'Business Tools', href: '/tools/business' },
  { label: 'Converter Tools', href: '/tools/file-converter' },
];

const features = [
  { label: 'AI Assistant', href: '/tools/ai/ai-chat' },
  { label: 'Bulk Processing', href: '/dashboard/billing' },
  { label: 'Cloud Storage', href: '/dashboard' },
  { label: 'File Converter', href: '/tools/file-converter' },
  { label: 'Batch Tools', href: '/dashboard/billing' },
  { label: 'Recently Added', href: '/tools/ai' },
  { label: 'Popular Tools', href: '/tools' },
  { label: 'Trending Tools', href: '/tools' },
  { label: 'Tool Collections', href: '/tools' },
  { label: 'Keyboard Shortcuts', href: '/help' },
];

const resources = [
  { label: 'Blog', href: '/blog' },
  { label: 'Help Center', href: '/help' },
  { label: 'How It Works', href: '/how-it-works' },
  { label: 'Video Tutorials', href: '/help' },
  { label: 'API Documentation', href: '/developers' },
  { label: 'Developer API', href: '/developers' },
  { label: 'Status Page', href: '/status' },
  { label: 'Community', href: '/contact' },
  { label: 'Changelog', href: '/blog' },
];

const company = [
  { label: 'About Us', href: '/about' },
  { label: 'Careers', href: '/contact', badge: "We're Hiring" },
  { label: 'Contact Us', href: '/contact' },
  { label: 'Press Kit', href: '/about' },
  { label: 'Partners', href: '/contact' },
  { label: 'Affiliate Program', href: '/contact' },
];

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div>
            <div className="logo">
              <BrandLogo variant="logo" alt="" className="logo-img" width={38} height={38} />
              <BrandLogo variant="wordmark" alt="Farvixo" className="logo-wordmark" width={132} height={34} />
            </div>
            <p className="footer-desc">Farvixo Tools is a modern AI-powered productivity platform offering 150+ online tools for developers, creators, businesses, students, and professionals worldwide.</p>
            <div className="social-row">
              {[
                ['facebook', 'https://www.facebook.com/farvixo'],
                ['twitter', 'https://twitter.com/farvixo'],
                ['linkedin', 'https://www.linkedin.com/company/farvixo'],
                ['youtube', 'https://www.youtube.com/@farvixo'],
                ['instagram', 'https://www.instagram.com/farvixo'],
                ['github', 'https://github.com/farvixo'],
              ].map(([s, url]) => (
                <a key={s} href={url} target="_blank" rel="noopener noreferrer" className="social-icon" aria-label={`Farvixo on ${s}`}><Icon name={s} size={15} /></a>
              ))}
            </div>
          </div>

          <div>
            <h3>Explore</h3>
            <ul>
              {explore.map((e) => (
                <li key={e.label}>
                  <Link href={e.href}>{e.label}{e.badge && <span className="pill pill-nav-new">{e.badge}</span>}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3>Top Features</h3>
            <ul>{features.map((f) => (<li key={f.label}><Link href={f.href}>{f.label}</Link></li>))}</ul>
          </div>

          <div>
            <h3>Resources</h3>
            <ul>{resources.map((r) => (<li key={r.label}><Link href={r.href}>{r.label}</Link></li>))}</ul>
          </div>

          <div>
            <h3>Company</h3>
            <ul>
              {company.map((c) => (
                <li key={c.label}>
                  <Link href={c.href}>{c.label}{c.badge && <span className="pill pill-hiring">{c.badge}</span>}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h3>Get Farvixo App</h3>
            <div className="store-grid">
              <button type="button" className="store-btn" aria-label="Download on the App Store — coming soon"><Icon name="download" size={16} /><span>Download on the<b>App Store</b></span></button>
              <button type="button" className="store-btn" aria-label="Get it on Google Play — coming soon"><Icon name="play" size={16} /><span>Get it on<b>Google Play</b></span></button>
              <button type="button" className="store-btn" aria-label="Download for Windows — coming soon"><Icon name="grid" size={16} /><span>Download for<b>Windows</b></span></button>
              <button type="button" className="store-btn" aria-label="Download for macOS — coming soon"><Icon name="hexagon" size={16} /><span>Download for<b>macOS</b></span></button>
            </div>
            <div className="trust-panel">
              <h4><Icon name="shield-check" size={15} /> Trusted &amp; Secure</h4>
              <ul>
                <li><Icon name="check" size={12} /> 256-bit SSL Encrypted</li>
                <li><Icon name="check" size={12} /> <Link href="/gdpr">GDPR Compliant</Link></li>
                <li><Icon name="check" size={12} /> <Link href="/security">Your Data is 100% Safe</Link></li>
                <li><Icon name="check" size={12} /> No Ads, Ever</li>
              </ul>
            </div>
          </div>
        </div>

        <div className="footer-bottom">
          <span>© 2026 Farvixo Technologies. All Rights Reserved.</span>
          <span>Made with ❤️ by Farvixo Team</span>
          <div className="footer-bottom-right">
            <Link href="/sitemap">Sitemap</Link>
            <Link href="/privacy-policy">Privacy</Link>
            <Link href="/terms-of-service">Terms</Link>
            <Link href="/status">Status<span className="status-dot" /></Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
