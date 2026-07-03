'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';
import { useAuth } from '@/components/providers/AuthProvider';

export default function BottomNav() {
  const pathname = usePathname();
  const { openAI } = useUI();
  const { user } = useAuth();

  const historyHref = user ? '/dashboard/history' : '/login';
  const accountHref = user ? '/dashboard' : '/login';

  const isActive = (href: string) =>
    href === '/' ? pathname === '/' : pathname.startsWith(href);

  return (
    <nav className="bottom-nav" aria-label="Mobile navigation">
      <Link href="/" className={`bottom-nav-item ${isActive('/') ? 'active' : ''}`}>
        <Icon name="home" size={20} />
        <span>Home</span>
      </Link>
      <Link href="/tools" className={`bottom-nav-item ${isActive('/tools') ? 'active' : ''}`}>
        <Icon name="grid" size={20} />
        <span>Tools</span>
      </Link>
      <button className="bottom-nav-fab" onClick={openAI} aria-label="Open AI Assistant">
        <Icon name="sparkles" size={22} />
      </button>
      <Link href={historyHref} className={`bottom-nav-item ${isActive('/dashboard/history') ? 'active' : ''}`}>
        <Icon name="clock" size={20} />
        <span>History</span>
      </Link>
      <Link href={accountHref} className={`bottom-nav-item ${pathname === '/dashboard' || isActive('/login') ? 'active' : ''}`}>
        <Icon name="user" size={20} />
        <span>Account</span>
      </Link>
    </nav>
  );
}
