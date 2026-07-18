export type AdminNavItem = {
  href: string;
  label: string;
  icon: string;
  description?: string;
  /** Permission required to see this item. Omit = always visible to any admin. */
  permission?: string;
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
      { href: '/admin/analytics', label: 'Analytics', icon: 'zap', description: 'Usage charts & stats', permission: 'system.read' },
      { href: '/admin/reports', label: 'Reports', icon: 'table', description: 'Export CSV reports', permission: 'system.read' },
      { href: '/admin/system', label: 'System Health', icon: 'shield-check', description: 'Health & environment', permission: 'system.read' },
      { href: '/admin/maintenance', label: 'Live / Maintenance', icon: 'shield', description: 'Maintenance mode & flags', permission: 'system.read' },
    ],
  },
  {
    title: 'User Management',
    items: [
      { href: '/admin/users', label: 'Users', icon: 'users', description: 'Roles, bans, plans', permission: 'users.read' },
      { href: '/admin/sessions', label: 'Sessions & Devices', icon: 'users', description: 'Login history & devices', permission: 'security.read' },
      { href: '/admin/team', label: 'Roles & Admins', icon: 'users', description: 'Admin team', permission: 'roles.read' },
      { href: '/admin/create-admin', label: 'Create Admin', icon: 'user-square', description: 'Provision admin', permission: 'roles.invite' },
    ],
  },
  {
    title: 'AI Management',
    items: [
      { href: '/admin/ai', label: 'Models & Usage', icon: 'sparkles', description: 'Providers, tokens, costs', permission: 'ai.read' },
    ],
  },
  {
    title: 'Tool Management',
    items: [
      { href: '/admin/tools', label: 'Tools', icon: 'settings', description: 'Enable / disable', permission: 'tools.read' },
      { href: '/admin/categories', label: 'Categories', icon: 'folder', description: 'Categories', permission: 'tools.read' },
      { href: '/admin/jobs', label: 'Jobs & Usage', icon: 'database', description: 'Job queue', permission: 'tools.read' },
      { href: '/admin/files', label: 'Storage Files', icon: 'database', description: 'Files & jobs', permission: 'tools.read' },
    ],
  },
  {
    title: 'Content',
    items: [
      { href: '/admin/blog', label: 'Blogs', icon: 'file-text', description: 'Blog CMS', permission: 'content.read' },
      { href: '/admin/notifications', label: 'Notifications', icon: 'bell', description: 'Broadcasts', permission: 'content.read' },
      { href: '/admin/ads', label: 'Banners & Ads', icon: 'play', description: 'Ad zones', permission: 'content.read' },
      { href: '/admin/email-templates', label: 'Email Templates', icon: 'mail', description: 'Templates', permission: 'content.read' },
      { href: '/admin/newsletter', label: 'Campaigns', icon: 'mail', description: 'Newsletter', permission: 'content.read' },
    ],
  },
  {
    title: 'Subscription & Finance',
    items: [
      { href: '/admin/subscriptions', label: 'Subscriptions', icon: 'briefcase', description: 'Stripe', permission: 'billing.read' },
      { href: '/admin/pricing', label: 'Plans', icon: 'crown', description: 'Pricing', permission: 'billing.read' },
      { href: '/admin/credits', label: 'Wallet & Credits', icon: 'zap', description: 'Credits ledger', permission: 'billing.read' },
      { href: '/admin/promo', label: 'Promo Codes', icon: 'crown', description: 'Coupons & gifts', permission: 'billing.read' },
      { href: '/admin/api-keys', label: 'API Keys', icon: 'key', description: 'Developer keys', permission: 'system.read' },
    ],
  },
  {
    title: 'Support',
    items: [
      { href: '/admin/tickets', label: 'Tickets', icon: 'mail', description: 'Support queue', permission: 'support.read' },
      { href: '/admin/contact', label: 'Contact Messages', icon: 'mail', description: 'Contact inbox', permission: 'support.read' },
    ],
  },
  {
    title: 'Security & Audit',
    items: [
      { href: '/admin/security', label: 'Blocked IPs', icon: 'shield', description: 'IP bans & failed logins', permission: 'security.read' },
      { href: '/admin/audit', label: 'Audit Logs', icon: 'shield', description: 'Admin actions', permission: 'security.read' },
      { href: '/admin/search', label: 'Search Logs', icon: 'search', description: 'Search queries', permission: 'security.read' },
      { href: '/admin/profile', label: 'My Profile', icon: 'user-square', description: 'Account' },
    ],
  },
  {
    title: 'Remote Config',
    items: [
      { href: '/admin/features', label: 'Feature Flags', icon: 'zap', description: 'App flags', permission: 'system.read' },
      { href: '/admin/settings', label: 'App Config', icon: 'settings', description: 'Site settings', permission: 'system.read' },
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

/** Drop items the current admin lacks permission for, then drop empty sections. */
export function visibleNavSections(can: (perm: string) => boolean): AdminNavSection[] {
  return adminNavSections
    .map((s) => ({ ...s, items: s.items.filter((i) => !i.permission || can(i.permission)) }))
    .filter((s) => s.items.length > 0);
}

export function isAdminPathActive(pathname: string, href: string): boolean {
  if (href === '/admin') return pathname === '/admin';
  return pathname === href || pathname.startsWith(`${href}/`);
}
