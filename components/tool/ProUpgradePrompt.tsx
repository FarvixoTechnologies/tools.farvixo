'use client';

import Link from 'next/link';
import Icon from '../Icon';

export default function ProUpgradePrompt({
  onClose,
  feature,
}: {
  onClose: () => void;
  feature: string;
}) {
  return (
    <div className="share-modal-overlay" style={{ zIndex: 150 }} onClick={onClose}>
      <div className="share-modal glass pro-upgrade-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Upgrade to Pro">
        <button className="icon-btn share-modal-close" onClick={onClose} aria-label="Close">
          <Icon name="x" size={18} />
        </button>
        <span className="pill pill-pro"><Icon name="crown" size={12} /> PRO</span>
        <h3>Unlock {feature}</h3>
        <p className="muted share-modal-sub">
          Upgrade to Pro for secure share links, cloud storage sync, password protection, and unlimited AI tools.
        </p>
        <Link href="/dashboard/billing" className="btn btn-gold w-full" onClick={onClose}>
          <Icon name="crown" size={15} /> Upgrade to Pro
        </Link>
        <button className="btn btn-ghost w-full mt-2" onClick={onClose}>Maybe later</button>
      </div>
    </div>
  );
}
