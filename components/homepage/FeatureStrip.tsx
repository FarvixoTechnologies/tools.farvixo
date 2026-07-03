import Icon from '../Icon';

const features = [
  { icon: 'sparkles', title: 'AI Powered', desc: 'Smart AI tools to boost your productivity' },
  { icon: 'plane', title: 'Blazing Fast', desc: 'Lightning-fast processing for all your tasks' },
  { icon: 'shield-check', title: 'Secure & Private', desc: 'Your data is 100% safe and encrypted' },
  { icon: 'cloud', title: 'Cloud Storage', desc: 'Save and access your files anywhere' },
  { icon: 'ban', title: 'No Ads', desc: 'Pure experience, no interruptions' },
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
