import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'ToolNest — AI Tools Platform',
    short_name: 'ToolNest',
    description: '120+ free online tools powered by AI — PDF, Image, Video, Audio, Developer & more.',
    start_url: '/?source=pwa',
    display: 'standalone',
    background_color: '#0A0A12',
    theme_color: '#7C3AED',
    icons: [
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
      { src: '/icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  };
}
