const LAYER_EXIT_MS = 200;

export function enterPage(page, { animate = true } = {}) {
  if (!animate) return;
  page.setData({
    pageMotion: page.data.pageMotion === 'motion-enter-a' ? 'motion-enter-b' : 'motion-enter-a',
    contentMotion: page.data.contentMotion === 'motion-body-a' ? 'motion-body-b' : 'motion-body-a'
  });
}

export function enterContent(page, update = {}, direction = 0, callback) {
  const variant = (page.data.contentMotion || '').endsWith('-a') ? 'b' : 'a';
  const motion = direction ? `motion-panel-${direction > 0 ? 'next' : 'previous'}-${variant}` : `motion-body-${variant}`;
  page.setData({ ...update, contentMotion: motion }, callback);
}

// Keep closing layers mounted until their CSS exit finishes. Reopening cancels
// both the old timer and its cleanup, so a stale exit cannot close a new layer.
export function cancelLayerExit(host, key) {
  const pending = host._layerExits && host._layerExits[key];
  if (pending) clearTimeout(pending.timer);
  if (host._layerExits) delete host._layerExits[key];
  if (host.data[key + 'Leaving']) host.setData({ [key + 'Leaving']: false });
}

export function retainLayerExit(host, key, afterExit, wasOpen = host.data[key]) {
  if (!wasOpen) return;
  cancelLayerExit(host, key);
  if (!host._layerExits) host._layerExits = {};
  const pending = {};
  host._layerExits[key] = pending;
  host.setData({ [key + 'Leaving']: true });
  pending.timer = setTimeout(() => {
    if (host._layerExits[key] !== pending) return;
    delete host._layerExits[key];
    host.setData({ [key + 'Leaving']: false });
    if (afterExit) afterExit();
  }, LAYER_EXIT_MS);
}

export function clearLayerMotion(host) {
  const updates = {};
  for (const key of Object.keys(host._layerExits || {})) {
    clearTimeout(host._layerExits[key].timer);
    updates[key + 'Leaving'] = false;
  }
  host._layerExits = {};
  if (Object.keys(updates).length) host.setData(updates);
}
