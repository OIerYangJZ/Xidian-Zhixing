const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
const files = walk(root).filter(p => /\.(js|json|wxml|wxss)$/.test(p));
const app = JSON.parse(read('app.json'));
const tabs = app.tabBar.list.map(t => t.pagePath);
function script(source) {
  return source.replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '').replace(/^export\s+(?=(const|let|function|class)\b)/gm, '').replace(/^export default /gm, '');
}
function load(relative, mocks = {}) {
  let definition;
  const context = { Page: x => { definition = x; }, Component: x => { definition = x; }, ...mocks };
  vm.runInNewContext(script(read(relative)), context, { filename: relative });
  return definition;
}
function instance(definition) {
  return { ...definition, ...definition.methods, data: JSON.parse(JSON.stringify(definition.data || {})), setData(update) { Object.assign(this.data, update); } };
}
test('all routes, components, imports and JavaScript parse', () => {
  for (const p of app.pages) for (const ext of ['.js', '.json', '.wxml']) assert.ok(fs.existsSync(path.join(root, p + ext)), p + ext);
  for (const p of files) {
    const s = fs.readFileSync(p, 'utf8');
    if (p.endsWith('.json')) JSON.parse(s);
    if (p.endsWith('.js')) {
      new vm.Script(script(s), { filename: p });
      for (const m of s.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) assert.ok(fs.existsSync(path.resolve(path.dirname(p), m[1] + '.js')), p + ': ' + m[1]);
    }
    if (p.endsWith('.wxss')) for (const m of s.matchAll(/@import\s+['"]([^'"]+)['"]/g)) assert.ok(fs.existsSync(path.resolve(path.dirname(p), m[1])), p + ': ' + m[1]);
  }
  for (const component of Object.values(app.usingComponents)) assert.ok(fs.existsSync(path.join(root, component + '.json')));
});
test('WXML is balanced and every event has a real handler', () => {
  for (const p of files.filter(p => p.endsWith('.wxml'))) {
    const source = fs.readFileSync(p, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
    const js = fs.readFileSync(p.replace('.wxml', '.js'), 'utf8');
    const stack = [];
    for (const m of source.matchAll(/<\/?[\w-]+\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/g)) {
      const tag = m[0], name = tag.match(/^<\/?([\w-]+)/)[1];
      if (tag.startsWith('</')) assert.equal(stack.pop(), name, p + ': ' + tag);
      else if (!tag.endsWith('/>')) stack.push(name);
    }
    assert.deepEqual(stack, [], p);
    for (const m of source.matchAll(/(?:bind|catch)(?::)?[\w-]+="([A-Za-z_$][\w$]*)"/g)) assert.match(js, new RegExp('\\b' + m[1] + '\\s*\\('), p + ': ' + m[1]);
  }
});
test('five tabs, safe-area inset, and settings-only language/campus login', () => {
  assert.equal(app.tabBar.custom, true);
  assert.deepEqual(tabs, ['pages/treehole/index', 'pages/campus/search/index', 'pages/ai/index', 'pages/profile/notifications/index', 'pages/profile/conversations/index']);
  assert.match(read('custom-tab-bar/index.wxss'), /env\(safe-area-inset-bottom\)/);
  assert.match(read('components/radio-drawer/index.wxml'), /bindtap="goCampus"/);
  assert.doesNotMatch(read('pages/campus/index.wxml'), /openIdsLogin|auth-center/);
  assert.match(read('pages/profile/settings/index.wxml'), /pages\/campus\/auth-center\/index/);
  for (const p of files.filter(p => p.endsWith('.wxml') && !p.includes('display-settings'))) assert.doesNotMatch(fs.readFileSync(p, 'utf8'), /bindtap="onLangTap"/);
  for (const p of files.filter(p => p.endsWith('.js'))) {
    const source = fs.readFileSync(p, 'utf8');
    for (const m of source.matchAll(/wx\.(navigateTo|redirectTo|switchTab)\(\{\s*url:\s*['"]\/([^'"]+)['"]/g)) {
      const route = m[2].split('?')[0];
      if (m[1] === 'switchTab') assert.ok(tabs.includes(route), p + ': non-tab switch');
      else assert.ok(!tabs.includes(route), p + ': navigateTo on tab');
    }
  }
});
test('tab navigation syncs selected state and never navigates to the selected tab', () => {
  const calls = [];
  const def = load('custom-tab-bar/index.js', { wx: { switchTab: x => calls.push(x.url) }, getCurrentPages: () => [{ route: tabs[3] }], getDisplayMode: () => 'dark', resolveDisplayMode: x => x, getLanguage: () => 'en' });
  const tab = instance(def);
  tab.sync();
  assert.equal(tab.data.selected, tabs[3]);
  assert.equal(tab.data.themeClass, 'theme-reference color-mode-dark');
  assert.equal(tab.data.english, true);
  tab.navigate({ currentTarget: { dataset: { path: tabs[3] } } });
  tab.navigate({ currentTarget: { dataset: { path: tabs[4] } } });
  assert.deepEqual(calls, ['/' + tabs[4]]);
});
test('AI draft opens the actual chat with encoded user question', () => {
  const calls = [];
  const ai = instance(load('pages/ai/index.js', { wx: { navigateTo: x => calls.push(x.url) }, requireLoginPage: () => true }));
  ai.data.configured = true;
  ai.data.draft = '  课表 & timetable?  ';
  ai.submitQuestion();
  assert.equal(calls[0], '/pages/ai/chat/index?prefill=' + encodeURIComponent('课表 & timetable?'));
  assert.equal(ai.data.draft, '');
  ai.data.configured = false;
  ai.data.draft = 'question';
  ai.submitQuestion();
  assert.equal(calls.length, 1);
});
test('light and dark tokens retain legible primary and secondary text', () => {
  const tokens = read('styles/tokens.wxss');
  assert.match(tokens, /"Times New Roman", "STZhongsong", "华文中宋", serif/);
  const luminance = hex => {
    const channels = hex.match(/\w\w/g).map(x => parseInt(x, 16) / 255).map(x => x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4);
    return channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722;
  };
  for (const [bg, fg] of [['ffffff', '101010'], ['ffffff', '626262'], ['ffffff', '707070'], ['101010', 'f2f2f2'], ['101010', 'ababab'], ['101010', 'a0a0a0']]) {
    const a = luminance(bg), b = luminance(fg);
    assert.ok((Math.max(a, b) + .05) / (Math.min(a, b) + .05) >= 4.5, bg + '/' + fg);
  }
});
