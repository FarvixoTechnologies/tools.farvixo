'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import Icon from '../Icon';
import { useAuth } from '@/components/providers/AuthProvider';

interface Notification {
  id: string;
  type: string;
  title: string;
  body: string | null;
  href: string | null;
  read: boolean;
  created_at: string;
}

function timeAgo(iso: string): string {
  const s = Math.max(1, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return d < 7 ? `${d}d ago` : new Date(iso).toLocaleDateString();
}

const typeIcon: Record<string, string> = {
  system: 'sparkles',
  job: 'check',
  billing: 'briefcase',
  announcement: 'bell',
};

export default function NotificationBell() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<Notification[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    if (!user) return;
    try {
      const res = await fetch('/api/notifications');
      if (!res.ok) return;
      const json = (await res.json()) as {
        success: boolean;
        data?: { notifications: Notification[]; unreadCount: number };
      };
      if (json.success && json.data) {
        setItems(json.data.notifications);
        setUnread(json.data.unreadCount);
      }
    } catch {
      /* offline — ignore */
    }
  }, [user]);

  useEffect(() => {
    if (!user) return;
    void load();
    const t = setInterval(load, 60_000);
    return () => clearInterval(t);
  }, [user, load]);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const toggle = async () => {
    const next = !open;
    setOpen(next);
    if (next) {
      setLoading(items.length === 0);
      await load();
      setLoading(false);
    }
  };

  const markAllRead = async () => {
    setItems((xs) => xs.map((x) => ({ ...x, read: true })));
    setUnread(0);
    try {
      await fetch('/api/notifications', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ all: true }),
      });
    } catch { /* best-effort */ }
  };

  const markOneRead = (id: string) => {
    const item = items.find((x) => x.id === id);
    if (!item || item.read) return;
    setItems((xs) => xs.map((x) => (x.id === id ? { ...x, read: true } : x)));
    setUnread((u) => Math.max(0, u - 1));
    void fetch('/api/notifications', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ids: [id] }),
    }).catch(() => {});
  };

  if (!user) return null;

  return (
    <div className="notif-wrap" ref={wrapRef}>
      <button className="icon-btn" onClick={toggle} aria-label="Notifications" aria-expanded={open}>
        <Icon name="bell" size={17} />
        {unread > 0 && <span className="notif-dot">{unread > 9 ? '9+' : unread}</span>}
      </button>

      {open && (
        <div className="notif-panel glass" role="dialog" aria-label="Notifications">
          <div className="notif-head">
            <b>Notifications</b>
            {unread > 0 && (
              <button className="notif-mark-all" onClick={markAllRead}>Mark all read</button>
            )}
          </div>

          {loading ? (
            <div className="notif-empty"><div className="spinner" /></div>
          ) : items.length === 0 ? (
            <div className="notif-empty">You&apos;re all caught up! 🎉</div>
          ) : (
            <div className="notif-list">
              {items.map((n) => {
                const inner = (
                  <>
                    <span className={`notif-item-icon notif-type-${n.type}`}>
                      <Icon name={typeIcon[n.type] ?? 'bell'} size={14} />
                    </span>
                    <span className="notif-item-body">
                      <span className="notif-item-title">{n.title}</span>
                      {n.body && <span className="notif-item-text">{n.body}</span>}
                      <span className="notif-item-time">{timeAgo(n.created_at)}</span>
                    </span>
                    {!n.read && <span className="notif-unread-dot" aria-label="Unread" />}
                  </>
                );
                return n.href ? (
                  <Link
                    key={n.id}
                    href={n.href}
                    className={`notif-item ${n.read ? '' : 'unread'}`}
                    onClick={() => { markOneRead(n.id); setOpen(false); }}
                  >
                    {inner}
                  </Link>
                ) : (
                  <button
                    key={n.id}
                    className={`notif-item ${n.read ? '' : 'unread'}`}
                    onClick={() => markOneRead(n.id)}
                  >
                    {inner}
                  </button>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
