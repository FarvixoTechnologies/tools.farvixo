import Icon from '../Icon';

const features = [
  { icon: 'grid', title: '150+ Tools', desc: 'All in One Place' },
  { icon: 'sparkles', title: 'AI Powered', desc: 'Smart & Intelligent' },
  { icon: 'zap', title: 'Blazing Fast', desc: 'Lightning Speed' },
  { icon: 'shield-check', title: 'Secure & Private', desc: 'Your Data is Safe' },
  { icon: 'cloud', title: 'Cloud Ready', desc: 'Work Anywhere' },
  { icon: 'code', title: 'Developer Friendly', desc: 'API & Integrations' },
];

export default function FeatureStrip() {
  return (
    <div className="container">
      <div className="feature-strip glass">
        {features.map((f) => (
          <div key={f.title} className="feature">
            <span className="feature-icon"><Icon name={f.icon} size={21} /></span>
            <b>{f.title}</b>
            <p>{f.desc}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
