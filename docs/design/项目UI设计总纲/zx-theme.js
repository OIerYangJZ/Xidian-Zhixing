// 西电知行 · 主题 token 生成器（示意实现）。4 套主题 × 浅/深，全部组件只引用 --token。
(function () {
  var THEMES = {
    zhushachi: { zh: '人本·初创', en: 'Humanist · Founding', d: '朱赤、暖白与杏黄',
      light: ['#F7F6F2', '#FFFEFA', '#181816', '#A43B32', '#7E2924', '#D9775F', '#E8B65D'],
      dark: ['#171714', '#20201C', '#F4F1E8', '#E08075', '#F09A8E', '#E89478', '#EBC474'] },
    zhuqing: { zh: '书院·青绿', en: 'Academy · Teal', d: '沉静青绿与纸白',
      light: ['#F3F7F2', '#FFFEF9', '#202A23', '#426F52', '#2D5139', '#71967B', '#D4A955'],
      dark: ['#151A16', '#1D241F', '#F0F4EE', '#91C29C', '#B2D8B9', '#7FAB8A', '#D9B568'] },
    xingrenhuang: { zh: '杏黄·纸韵', en: 'Apricot · Paper', d: '古朴杏黄与墨褐',
      light: ['#FBF6EA', '#FFFEF8', '#30281E', '#94631F', '#694513', '#C38D3B', '#E3B660'],
      dark: ['#1B1812', '#252118', '#F6F0E3', '#E1B665', '#F0CE89', '#D39D4B', '#EAC774'] },
    mozhuxinye: { zh: '墨朱·新页', en: 'Ink Vermilion · New', d: '连续讨论流与墨朱金',
      light: ['#FFFFFF', '#FFFFFF', '#191917', '#AB3E36', '#852E29', '#D87569', '#E6B75D'],
      dark: ['#151513', '#1D1D1B', '#F5F5F0', '#E37D73', '#F0A096', '#F09A8E', '#E9C26E'] }
  };
  function rgb(h) { h = h.replace('#', ''); return [0, 2, 4].map(function (i) { return parseInt(h.substr(i, 2), 16); }); }
  function hex(a) { return '#' + a.map(function (v) { v = Math.max(0, Math.min(255, Math.round(v))); return (v < 16 ? '0' : '') + v.toString(16); }).join('').toUpperCase(); }
  function mix(a, b, t) { var x = rgb(a), y = rgb(b); return hex(x.map(function (v, i) { return v * t + y[i] * (1 - t); })); }
  function rgba(h, a) { var x = rgb(h); return 'rgba(' + x.join(',') + ',' + a + ')'; }
  var GRAIN = "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 .45  0 0 0 0 .38  0 0 0 0 .3  0 0 0 .075 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")";
  function build(key, mode) {
    var T = THEMES[key] || THEMES.zhushachi, dark = mode === 'dark', c = T[dark ? 'dark' : 'light'];
    var page = c[0], surf = c[1], ink = c[2], pri = c[3], act = c[4], coral = c[5], apr = c[6];
    var st = dark ? { success: '#8CC4A2', warning: '#E6BE74', danger: '#F29084', info: '#93BCCC' }
                  : { success: '#44684F', warning: '#8A5A1E', danger: '#97382F', info: '#45687A' };
    var v = {
      '--bg': page,
      '--bg-sunk': dark ? mix('#000000', page, .3) : mix(ink, page, .045),
      '--surface': surf,
      '--raised': dark ? mix(ink, surf, .07) : surf,
      '--glass': rgba(surf, dark ? .74 : .8),
      '--line': mix(ink, surf, dark ? .13 : .1),
      '--line-strong': mix(ink, surf, dark ? .25 : .21),
      '--text': ink,
      '--text-2': mix(ink, surf, dark ? .75 : .8),
      '--text-3': mix(ink, surf, dark ? .6 : .7),
      '--primary': pri,
      '--primary-pressed': act,
      '--on-primary': dark ? mix('#000000', pri, .8) : '#FFFFFF',
      '--primary-soft': mix(pri, surf, dark ? .2 : .1),
      '--primary-glow': rgba(pri, dark ? .28 : .3),
      '--seal': pri,
      '--seal-soft': mix(pri, surf, dark ? .14 : .07),
      '--accent': apr,
      '--accent-soft': mix(apr, surf, dark ? .18 : .24),
      '--accent-ink': dark ? apr : mix('#000000', apr, .5),
      '--coral': coral,
      '--hero': 'linear-gradient(125deg,' + mix(pri, surf, dark ? .24 : .13) + ' 0%,' + mix(apr, surf, dark ? .14 : .2) + ' 52%,' + surf + ' 100%)',
      '--on-danger': dark ? '#1A0F0D' : '#FFFFFF',
      '--on-scrim': '#FFFFFF',
      '--scrim': dark ? 'rgba(0,0,0,.62)' : 'rgba(30,22,16,.42)',
      '--shadow-1': dark ? '0 1px 2px rgba(0,0,0,.5)' : '0 1px 2px rgba(70,45,25,.06),0 2px 10px rgba(70,45,25,.05)',
      '--shadow-2': dark ? '0 18px 48px rgba(0,0,0,.62),0 2px 8px rgba(0,0,0,.4)' : '0 18px 48px rgba(70,45,25,.15),0 3px 10px rgba(70,45,25,.06)'
    };
    ['success', 'warning', 'danger', 'info'].forEach(function (k) { v['--' + k] = st[k]; v['--' + k + '-soft'] = mix(st[k], surf, dark ? .17 : .12); });
    [35, 160, 250, 80, 310, 125].forEach(function (h, i) { v['--ch-' + (i + 1)] = dark ? 'oklch(0.76 0.1 ' + h + ')' : 'oklch(0.55 0.11 ' + h + ')'; });
    return v;
  }
  function toStyle(v) { return Object.keys(v).map(function (k) { return k + ':' + v[k]; }).join(';'); }
  function apply(root, key, grain) {
    if (!root) return;
    var els = [root].concat([].slice.call(root.querySelectorAll('[data-zx]')));
    els.forEach(function (el) {
      var mode = el.getAttribute('data-zx'); if (!mode) return;
      var v = build(el.getAttribute('data-theme') || key, mode);
      Object.keys(v).forEach(function (p) { if (el.style.getPropertyValue(p) !== v[p]) el.style.setProperty(p, v[p]); });
    });
    var g = grain === false ? 'none' : GRAIN;
    if (root.style.getPropertyValue('--grain') !== g) root.style.setProperty('--grain', g);
  }
  window.ZXTheme = { THEMES: THEMES, build: build, apply: apply, toStyle: toStyle, mix: mix, GRAIN: GRAIN, keys: Object.keys(THEMES) };
})();
