'use client';

import { useAuth } from '@/components/providers/AuthProvider';

const plans = [
  { id: 'free', name: 'Free', price: '$0', features: ['5 jobs/day per tool', '500 MB storage', '10 AI messages/day', '25 MB file limit'] },
  { id: 'pro', name: 'Pro', price: '$9/mo', features: ['Unlimited jobs', '100 GB storage', 'Unlimited AI', '2 GB files', 'No watermarks', 'Batch processing'] },
];

export default function BillingPage() {
  const { user } = useAuth();

  return (
    <div>
      <h1 className="dash-title">Billing</h1>
      <p className="muted mb-6">Current plan: <b>{user?.plan === 'pro' ? 'Pro 👑' : user?.plan === 'enterprise' ? 'Enterprise' : 'Free'}</b></p>
      <div className="billing-grid">
        {plans.map((p) => (
          <div key={p.id} className={`billing-card glass ${user?.plan === p.id ? 'active' : ''}`}>
            <h3>{p.name}</h3>
            <div className="billing-price">{p.price}</div>
            <ul>{p.features.map((f) => <li key={f}>✓ {f}</li>)}</ul>
            {p.id === 'pro' && user?.plan === 'free' && (
              <button className="btn btn-primary w-full" disabled title="Connect Stripe in production">
                Upgrade to Pro (Stripe)
              </button>
            )}
            {user?.plan === p.id && <span className="billing-current">Current plan</span>}
          </div>
        ))}
      </div>
      <p className="muted mt-6">Connect STRIPE_SECRET_KEY in Vercel to enable live checkout.</p>
    </div>
  );
}
