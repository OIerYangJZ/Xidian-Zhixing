// Copy to env.local.js. The real file is ignored by Git.
const localConfig = {
  // Local development: auto | devtools | lan
  // Production upload: prod
  env: 'prod',
  devtoolsBaseUrl: 'http://localhost:8080',
  lanBaseUrl: 'http://192.0.2.10:8080',
  prodBaseUrl: 'https://your-production-domain.example',
};

module.exports = localConfig;
