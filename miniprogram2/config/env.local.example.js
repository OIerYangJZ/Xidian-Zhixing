// Copy to env.local.js. The real file is ignored by Git.
const localConfig = {
  // Local development: auto | devtools | lan
  // Production upload: prod
  env: 'prod',
  devtoolsBaseUrl: 'http://127.0.0.1:3002',
  lanBaseUrl: 'http://192.0.2.10:3002',
  prodBaseUrl: 'https://zhixing.xidian.edu.cn',
};

module.exports = localConfig;
