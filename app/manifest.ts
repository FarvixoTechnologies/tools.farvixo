import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Farvixo Tools',
    short_name: 'Farvixo',
    description: '139+ free online AI & productivity tools — PDF, Image, Video, Audio, Developer & more.',
    start_url: '/?source=pwa',
    display: 'standalone',
    background_color: '#0D0D12',
    theme_color: '#6C4DFF',
    icons: [
      { src: '/farvixo-logo.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
    ],
  };
}
