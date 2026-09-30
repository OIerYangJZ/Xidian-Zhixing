const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
module.exports = (timers = {}) => {
  const scope = { setTimeout, clearTimeout, ...timers };
  const source = fs.readFileSync(path.resolve(__dirname, '../../utils/motion.js'), 'utf8').replace(/^export /gm, '');
  vm.runInNewContext(source + ';this.api={enterPage,enterContent,retainLayerExit,cancelLayerExit,clearLayerMotion};', scope);
  return scope.api;
};
