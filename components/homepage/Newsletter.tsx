'use client';

import { useState } from 'react';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';

export default function Newsletter() {
  const { toast } = useUI();
  const [email, setEmail] = useState('');

  const subscribe = async () => {
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      toast('Please enter a valid email address', 'error');
      return;
    }
    try {
      const res = await fetch('/api/newsletter/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, source: 'homepage' }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error || 'Subscription failed');
      const subs: string[] = JSON.parse(localStorage.getItem('farvixo_newsletter') || '[]');
      if (!subs.includes(email)) subs.push(email);
      localStorage.setItem('farvixo_newsletter', JSON.stringify(subs));
      setEmail('');
      toast('🎉 Subscribed! Welcome to the Farvixo loop.', 'success');
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Subscription failed', 'error');
    }
  };

  return (
    <div className="container">
      <div className="newsletter glass">
        <span className="newsletter-icon"><Icon name="mail" size={24} /></span>
        <div className="newsletter-text">
          <h2>Stay in the Loop with <span>Farvixo</span></h2>
          <p>Get the latest tools, new features, productivity tips and exclusive content straight to your inbox.</p>
        </div>
        <div className="newsletter-form">
          <div className="newsletter-row">
            <div className="newsletter-input">
              <Icon name="mail" size={15} />
              <input
                type="email"
                value={email}
                placeholder="Enter your email address"
                onChange={(e) => setEmail(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && subscribe()}
                aria-label="Email address"
              />
            </div>
            <button className="btn btn-primary" onClick={subscribe}>Subscribe Now <Icon name="send" size={14} /></button>
          </div>
          <span className="newsletter-note"><Icon name="check" size={13} /> No spam. Unsubscribe anytime.</span>
        </div>
      </div>
    </div>
  );
}
