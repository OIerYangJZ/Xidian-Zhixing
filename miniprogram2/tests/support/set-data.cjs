module.exports = function setData(update, callback) {
  for (const [path, value] of Object.entries(update)) {
    const keys = path.replace(/\[(\d+)\]/g, '.$1').split('.');
    let target = this.data;
    for (const key of keys.slice(0, -1)) target = target[key];
    target[keys[keys.length - 1]] = value;
  }
  if (callback) callback.call(this);
};
