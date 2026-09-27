const { PHASE_DEVELOPMENT_SERVER } = require('next/constants');

/**
 * The site ships as a static export (`out/`) that the existing Nginx serves in
 * place of the Flutter web bundle; everything dynamic comes from the Python
 * backend under /api.  There is no Node process in production.
 *
 * `next dev` cannot use `output: 'export'` together with rewrites, so the dev
 * server instead proxies /api to a locally running backend, which keeps the
 * browser same-origin exactly as it is behind Nginx.
 */
module.exports = (phase) => {
  /** @type {import('next').NextConfig} */
  const config = {
    // Pages export as `feed.html` and Nginx resolves `/feed` with
    // `try_files $uri $uri.html`.  A trailing-slash layout would redirect
    // /api/... in dev and break the /p/<id> links already shared.
    experimental: {
      scrollRestoration: true,
    },
    images: {
      // No image optimizer without a Node server; resized variants come from
      // GET /api/storage/<key>?w= (see src/lib/backend/image.ts).
      unoptimized: true,
    },
  };

  if (phase === PHASE_DEVELOPMENT_SERVER) {
    const backend = process.env.ZX_BACKEND_URL || 'http://127.0.0.1:8080';
    config.rewrites = async () => [{ source: '/api/:path*', destination: `${backend}/api/:path*` }];
    return config;
  }

  return { ...config, output: 'export' };
};
