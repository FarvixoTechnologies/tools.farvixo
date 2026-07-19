/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  eslint: { ignoreDuringBuilds: true },
  webpack: (config) => {
    config.resolve.alias = { ...config.resolve.alias, canvas: false, encoding: false };
    return config;
  },
  async headers() {
    return [
      // Flutter web (localhost) + mobile clients calling Tools APIs.
      {
        source: '/api/:path*',
        headers: [
          { key: 'Access-Control-Allow-Origin', value: '*' },
          {
            key: 'Access-Control-Allow-Methods',
            value: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          },
          {
            key: 'Access-Control-Allow-Headers',
            value: 'Authorization, Content-Type, Accept',
          },
          { key: 'Access-Control-Max-Age', value: '86400' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
        ],
      },
      {
        source: '/(.*)',
        headers: [
          // Required for ffmpeg.wasm multithreading (SharedArrayBuffer)
          { key: 'Cross-Origin-Opener-Policy', value: 'same-origin' },
          { key: 'Cross-Origin-Embedder-Policy', value: 'credentialless' },
          // Security hardening
          // Note: script-src stays open — tool engines load WASM/scripts from
          // CDNs (unpkg, jsdelivr) and call external AI/image APIs at runtime.
          // CSP below hardens only what can't break those engines.
          {
            key: 'Content-Security-Policy',
            value: "object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'; upgrade-insecure-requests",
          },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(self), geolocation=(), payment=()' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains' },
        ],
      },
    ];
  },
};

export default nextConfig;
