export type AdminNavItem = {
  href: string;
  label: string;
  icon: string;
  description?: string;
};

export type AdminNavSection = {
  title: string;
  items: AdminNavItem[];
};

/** Farvixo Admin System v3.0 — full nav (working routes only). */
export const adminNavSections: AdminNavSection[] = [
  {
    title: 'Core Dashboard',
    items: [
      { href: '/admin', label: 'Dashboard', icon: 'grid', description: 'KPIs & overview' },
      { href: '/admin/analytics', label: 'Analytics', icon: 'zap', description: 'Usage charts & stats' },
      { href: '/admin/reports', label: 'Reports', icon: 'table', description: 'Export CSV reports' },
      { href: '/admin/system', label: 'System Health', icon: 'shield-check', description: 'Health & environment' },
      { href: '/admin/maintenance', label: 'Live / Maintenance', icon: 'shield', description: 'Maintenance mode & flags' },
    ],
  },
  {
    title: 'User Management',
    items: [
      { href: '/admin/users', label: 'Users', icon: 'users', description: 'Roles, bans, plans' },
      { href: '/admin/sessions', label: 'Sessions & Devices', icon: 'users', description: 'Login history & devices' },
      { href: '/admin/team', label: 'Roles & Admins', icon: 'users', description: 'Admin team' },
      { href: '/admin/create-admin', label: 'Create Admin', icon: 'user-square', description: 'Provision admin' },
    ],
  },
  {
    title: 'AI Management',
    items: [
      { href: '/admin/ai', label: 'Models & Usage', icon: 'sparkles', description: 'Providers, tokens, costs' },
    ],
  },
  {
    title: 'Tool Management',
    items: [
      { href: '/admin/tools', label: 'Tools', icon: 'settings', description: 'Enable / disable' },
      { href: '/admin/categories', label: 'Categories', icon: 'folder', description: 'Categories' },
      { href: '/admin/jobs', label: 'Jobs & Usage', icon: 'database', description: 'Job queue' },
      { href: '/admin/files', label: 'Storage Files', icon: 'database', description: 'Files & jobs' },
    ],
  },
  {
    title: 'Content',
    items: [
      { href: '/admin/blog', label: 'Blogs', icon: 'file-text', description: 'Blog CMS' },
      { href: '/admin/notifications', label: 'Notifications', icon: 'bell', description: 'Broadcasts' },
      { href: '/admin/ads', label: 'Banners & Ads', icon: 'play', description: 'Ad zones' },
      { href: '/admin/email-templates', label: 'Email Templates', icon: 'mail', description: 'Templates' },
      { href: '/admin/newsletter', label: 'Campaigns', icon: 'mail', description: 'Newsletter' },
    ],
  },
  {
    title: 'Subscription & Finance',
    items: [
      { href: '/admin/subscriptions', label: 'Subscriptions', icon: 'briefcase', description: 'Stripe' },
      { href: '/admin/pricing', label: 'Plans', icon: 'crown', description: 'Pricing' },
      { href: '/admin/credits', label: 'Wallet & Credits', icon: 'zap', description: 'Credits ledger' },
      { href: '/admin/promo', label: 'Promo Codes', icon: 'crown', description: 'Coupons & gifts' },
      { href: '/admin/api-keys', label: 'API Keys', icon: 'key', description: 'Developer keys' },
    ],
  },
  {
    title: 'Support',
    items: [
      { href: '/admin/tickets', label: 'Tickets', icon: 'mail', description: 'Support queue' },
      { href: '/admin/contact', label: 'Contact Messages', icon: 'mail', description: 'Contact inbox' },
    ],
  },
  {
    title: 'Security & Audit',
    items: [
      { href: '/admin/security', label: 'Blocked IPs', icon: 'shield', description: 'IP bans & failed logins' },
      { href: '/admin/audit', label: 'Audit Logs', icon: 'shield', description: 'Admin actions' },
      { href: '/admin/search', label: 'Search Logs', icon: 'search', description: 'Search queries' },
      { href: '/admin/profile', label: 'My Profile', icon: 'user-square', description: 'Account' },
    ],
  },
  {
    title: 'Remote Config',
    items: [
      { href: '/admin/features', label: 'Feature Flags', icon: 'zap', description: 'App flags' },
      { href: '/admin/settings', label: 'App Config', icon: 'settings', description: 'Site settings' },
    ],
  },
];

export const adminQuickLinks: AdminNavItem[] = (() => {
  const seen = new Set<string>();
  return adminNavSections
    .flatMap((s) => s.items)
    .filter((item) => {
      if (item.href === '/admin/profile') return false;
      if (seen.has(item.href)) return false;
      seen.add(item.href);
      return true;
    });
})();

export function isAdminPathActive(pathname: string, href: string): boolean {
  if (href === '/admin') return pathname === '/admin';
  return pathname === href || pathname.startsWith(`${href}/`);
}
