import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Farvixo Tools',
    short_name: 'Farvixo',
    description: '150+ free online AI & productivity tools — PDF, Image, Video, Audio, Developer & more.',
    start_url: '/?source=pwa',
    display: 'standalone',
    background_color: '#0D0D12',
    theme_color: '#6C4DFF',
    icons: [
      { src: '/farvixo-logo.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
    categories: ['utilities', 'productivity'],
    orientation: 'any',
    shortcuts: [
      { name: 'All Tools', url: '/tools', description: 'Browse all 150+ tools' },
      { name: 'PDF Tools', url: '/tools/pdf', description: 'Convert, merge, compress PDFs' },
      { name: 'AI Chat', url: '/tools/ai/ai-chat', description: 'Chat with the Farvixo AI assistant' },
      { name: 'Image Compressor', url: '/tools/image/image-compressor', description: 'Compress images in your browser' },
    ],
  };
}
