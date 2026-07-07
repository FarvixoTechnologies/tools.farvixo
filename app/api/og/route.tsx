import { ImageResponse } from 'next/og';

export const runtime = 'edge';

/** Branded 1200×630 Open Graph image, generated per tool/category on demand. */
export function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const title = (searchParams.get('title') || 'ToolNest').slice(0, 80);
  const subtitle = (searchParams.get('subtitle') || 'One Platform. Infinite Tools.').slice(0, 70);
  const badge = (searchParams.get('badge') || '').slice(0, 12);

  return new ImageResponse(
    (
      <div
        style={{
          width: '1200px',
          height: '630px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '72px',
          background: 'linear-gradient(135deg, #0A0A12 0%, #1a1030 55%, #2a1245 100%)',
          fontFamily: 'sans-serif',
        }}
      >
        {/* Brand row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '18px' }}>
          <div
            style={{
              width: '64px',
              height: '64px',
              borderRadius: '18px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '34px',
              background: 'linear-gradient(135deg, #7C3AED, #C026D3)',
            }}
          >
            ⬡
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ color: '#F5F5FA', fontSize: '30px', fontWeight: 800 }}>ToolNest</span>
            <span style={{ color: '#A0A0B8', fontSize: '16px' }}>One Platform. Infinite Tools.</span>
          </div>
          {badge ? (
            <span
              style={{
                marginLeft: '16px',
                color: '#fff',
                fontSize: '18px',
                fontWeight: 700,
                letterSpacing: '1px',
                padding: '8px 18px',
                borderRadius: '999px',
                background: 'linear-gradient(135deg, #7C3AED, #C026D3)',
              }}
            >
              {badge}
            </span>
          ) : null}
        </div>

        {/* Title block */}
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <span style={{ color: '#8B5CF6', fontSize: '26px', fontWeight: 600, marginBottom: '14px' }}>{subtitle}</span>
          <span style={{ color: '#F5F5FA', fontSize: '78px', fontWeight: 800, lineHeight: 1.05 }}>{title}</span>
        </div>

        {/* Footer strip */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '28px', color: '#A0A0B8', fontSize: '24px' }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>✓ Free forever</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>🔒 100% Private</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>⚡ No sign-up</span>
        </div>
      </div>
    ),
    { width: 1200, height: 630 },
  );
}
