'use client';

import { useCallback, useState } from 'react';
import dynamic from 'next/dynamic';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';
import { useAuth } from '../providers/AuthProvider';
import { trackEvent } from '@/lib/analytics-client';
import type { ShareFile } from './ShareModal';
import ProUpgradePrompt from './ProUpgradePrompt';

const ShareModal = dynamic(() => import('./ShareModal'), { ssr: false });

function isPro(plan?: string): boolean {
  return plan === 'pro' || plan === 'enterprise';
}

export interface FabRailProps {
  file?: ShareFile | null;
  toolSlug?: string;
  onFilesPasted?: (files: File[]) => void;
  onCloudImport?: (files: File[]) => void;
}

export default function FabRail({ file, toolSlug, onFilesPasted }: FabRailProps) {
  const { toast } = useUI();
  const { user } = useAuth();
  const pro = isPro(user?.plan);
  const [shareOpen, setShareOpen] = useState(false);
  const [upgradeFeature, setUpgradeFeature] = useState<string | null>(null);
  const [cloudBusy, setCloudBusy] = useState<'google' | 'dropbox' | null>(null);

  const pasteFromClipboard = useCallback(async () => {
    try {
      const items = await navigator.clipboard.read();
      const picked: File[] = [];
      for (const item of items) {
        const type = item.types.find((t) => t.startsWith('image/') || t === 'application/pdf' || t === 'text/plain');
        if (!type) continue;
        const blob = await item.getType(type);
        if (type === 'text/plain') {
          const text = await blob.text();
          picked.push(new File([text], `pasted-${Date.now()}.txt`, { type: 'text/plain' }));
        } else {
          const ext = type.split('/')[1]?.replace('jpeg', 'jpg') ?? 'bin';
          picked.push(new File([blob], `pasted-${Date.now()}.${ext}`, { type }));
        }
      }
      if (picked.length === 0) {
        toast('No image, PDF, or text found in clipboard', 'error');
        return;
      }
      onFilesPasted?.(picked);
      trackEvent('fab_clipboard_paste', { toolSlug, count: picked.length }, user?.id);
      toast(`Pasted ${picked.length} file(s) from clipboard ✓`);
    } catch {
      toast('Clipboard access denied', 'error');
    }
  }, [onFilesPasted, toast, toolSlug, user?.id]);

  const copyDirectLink = useCallback(async () => {
    if (!file) {
      toast('Process a file first to copy a link', 'error');
      return;
    }
    const url = URL.createObjectURL(file.blob);
    await navigator.clipboard.writeText(url);
    toast('Temporary blob link copied (local only) ✓');
    trackEvent('share_copied', { toolSlug, local: true }, user?.id);
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
  }, [file, toast, toolSlug, user?.id]);

  const cloudAction = useCallback(async (provider: 'google' | 'dropbox', exportMode: boolean) => {
    if (!pro) {
      setUpgradeFeature(provider === 'google' ? 'Google Drive' : 'Dropbox');
      return;
    }
    setCloudBusy(provider);
    try {
      if (exportMode && file) {
        const res = await fetch(`/api/cloud/${provider}/export`, {
          method: 'POST',
          headers: {
            'Content-Type': file.blob.type || 'application/octet-stream',
            'x-file-name': file.name,
          },
          body: file.blob,
        });
        const json = (await res.json()) as { success: boolean; error?: string };
        if (!res.ok || !json.success) {
          if (res.status === 401) {
            window.location.href = `/api/cloud/${provider}/auth?returnTo=${encodeURIComponent(window.location.pathname)}`;
            return;
          }
          throw new Error(json.error || 'Export failed');
        }
        toast(`Uploaded to ${provider === 'google' ? 'Google Drive' : 'Dropbox'} ✓`);
        trackEvent('fab_cloud_export', { provider, toolSlug }, user?.id);
      } else {
        window.location.href = `/api/cloud/${provider}/auth?returnTo=${encodeURIComponent(window.location.pathname)}`;
      }
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Cloud action failed', 'error');
    } finally {
      setCloudBusy(null);
    }
  }, [file, pro, toast, toolSlug, user?.id]);

  const handleGoogle = () => {
    if (file) void cloudAction('google', true);
    else void cloudAction('google', false);
  };

  const handleDropbox = () => {
    if (file) void cloudAction('dropbox', true);
    else void cloudAction('dropbox', false);
  };

  return (
    <>
      <div className="fab-rail" role="toolbar" aria-label="Quick actions">
        <button
          className={`fab-btn ${!pro ? 'fab-btn-locked' : ''}`}
          onClick={() => (file ? setShareOpen(true) : toast('Process a file first', 'error'))}
          aria-label="Share link"
          title={pro ? 'Share Link' : 'Share Link (Pro)'}
        >
          <Icon name="link" size={20} />
          {!pro && <span className="fab-lock" aria-hidden><Icon name="lock" size={10} /></span>}
        </button>

        <button
          className={`fab-btn ${!pro ? 'fab-btn-locked' : ''}`}
          onClick={handleGoogle}
          disabled={cloudBusy === 'google'}
          aria-label="Google Drive"
          title={pro ? 'Google Drive' : 'Google Drive (Pro)'}
        >
          <Icon name="cloud" size={20} />
          {!pro && <span className="fab-lock" aria-hidden><Icon name="lock" size={10} /></span>}
        </button>

        <button
          className={`fab-btn ${!pro ? 'fab-btn-locked' : ''}`}
          onClick={handleDropbox}
          disabled={cloudBusy === 'dropbox'}
          aria-label="Dropbox"
          title={pro ? 'Dropbox' : 'Dropbox (Pro)'}
        >
          <Icon name="folder" size={20} />
          {!pro && <span className="fab-lock" aria-hidden><Icon name="lock" size={10} /></span>}
        </button>

        <button
          className="fab-btn"
          onClick={() => void pasteFromClipboard()}
          aria-label="Paste from clipboard"
          title="Paste from Clipboard"
        >
          <Icon name="clipboard" size={20} />
        </button>

        {file && (
          <button
            className="fab-btn"
            onClick={() => void copyDirectLink()}
            aria-label="Copy link"
            title="Copy Link"
          >
            <Icon name="copy" size={20} />
          </button>
        )}
      </div>

      {file && shareOpen && (
        <ShareModal open={shareOpen} onClose={() => setShareOpen(false)} file={file} toolSlug={toolSlug} />
      )}

      {upgradeFeature && (
        <ProUpgradePrompt onClose={() => setUpgradeFeature(null)} feature={upgradeFeature} />
      )}
    </>
  );
}
