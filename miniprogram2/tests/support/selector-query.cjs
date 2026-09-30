module.exports = function createSelectorQuery() {
  return {
    in() { return this; },
    select() { return this; },
    fields() { return this; },
    boundingClientRect() { return this; },
    exec() {}
  };
};
