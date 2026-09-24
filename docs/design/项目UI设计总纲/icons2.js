// 西电知行 · 双色线性图标（示意）。24 网格，1.6 描边 + 20% 同色填充层；--duo 可调填充浓度。正式版需重绘并随包分发。
(function () {
  var D = {
    search: ['<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.2 4.2"/>', '<circle cx="11" cy="11" r="6.5"/>'],
    bell: ['<path d="M6.2 16.2V11a5.8 5.8 0 0 1 11.6 0v5.2l1.4 1.8H4.8z"/><path d="M10 20.3a2.1 2.1 0 0 0 4 0"/>', '<path d="M6.2 16.2V11a5.8 5.8 0 0 1 11.6 0v5.2l1.4 1.8H4.8z"/>'],
    chat: ['<path d="M6.5 4.5h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H11l-4.5 3.6v-3.6h0a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2z"/><path d="M8.5 9.5h7M8.5 12.5h4.5"/>', '<path d="M6.5 4.5h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H11l-4.5 3.6v-3.6a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2z"/>'],
    sliders: ['<path d="M4 7h9M18 7h2M4 17h3M12 17h8"/><circle cx="15.5" cy="7" r="2.3"/><circle cx="9.5" cy="17" r="2.3"/>', '<circle cx="15.5" cy="7" r="2.3"/><circle cx="9.5" cy="17" r="2.3"/>'],
    plus: ['<path d="M12 5v14M5 12h14"/>'],
    close: ['<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'],
    back: ['<path d="M14.5 5.5L8 12l6.5 6.5"/>'],
    chevron: ['<path d="M9.5 5.5L16 12l-6.5 6.5"/>'],
    down: ['<path d="M6.5 9.5L12 15l5.5-5.5"/>'],
    more: ['<circle cx="5.5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="18.5" cy="12" r="1.3" fill="currentColor"/>'],
    heart: ['<path d="M12 19.6s-7.2-4.3-7.2-9.8A4.1 4.1 0 0 1 12 7.2a4.1 4.1 0 0 1 7.2 2.6c0 5.5-7.2 9.8-7.2 9.8z"/>', '<path d="M12 19.6s-7.2-4.3-7.2-9.8A4.1 4.1 0 0 1 12 7.2a4.1 4.1 0 0 1 7.2 2.6c0 5.5-7.2 9.8-7.2 9.8z"/>'],
    comment: ['<path d="M5 6.5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-5l-4.2 3.5V15.5H7a2 2 0 0 1-2-2z"/>', '<path d="M5 6.5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-5l-4.2 3.5V15.5H7a2 2 0 0 1-2-2z"/>'],
    star: ['<path d="M12 4.2l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 16.6l-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z"/>', '<path d="M12 4.2l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 16.6l-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z"/>'],
    share: ['<path d="M12 14.5V4.5M8.3 8.2L12 4.5l3.7 3.7"/><path d="M8 11H6.5a1.5 1.5 0 0 0-1.5 1.5v5A1.5 1.5 0 0 0 6.5 19h11a1.5 1.5 0 0 0 1.5-1.5v-5a1.5 1.5 0 0 0-1.5-1.5H16"/>', '<path d="M5 12.5A1.5 1.5 0 0 1 6.5 11h11a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 17.5z"/>'],
    pin: ['<path d="M9.2 4.5h5.6l-.9 4.8 3 3.2H7.1l3-3.2z"/><path d="M12 12.5v7"/>', '<path d="M9.2 4.5h5.6l-.9 4.8 3 3.2H7.1l3-3.2z"/>'],
    home: ['<path d="M4.5 10.2L12 4.5l7.5 5.7V19a1 1 0 0 1-1 1h-4v-5.5h-5V20h-4a1 1 0 0 1-1-1z"/>', '<path d="M4.5 10.2L12 4.5l7.5 5.7V19a1 1 0 0 1-1 1h-4v-5.5h-5V20h-4a1 1 0 0 1-1-1z"/>'],
    campus: ['<path d="M2.8 9.2L12 4.6l9.2 4.6L12 13.8z"/><path d="M6.8 11.4v4.8c3.1 2.3 7.3 2.3 10.4 0v-4.8M21.2 9.2v5"/>', '<path d="M2.8 9.2L12 4.6l9.2 4.6L12 13.8z"/>'],
    ai: ['<path d="M11 3.8l1.7 5 5 1.7-5 1.7-1.7 5-1.7-5-5-1.7 5-1.7z"/><path d="M18 15v4.5M15.8 17.2h4.4"/>', '<path d="M11 3.8l1.7 5 5 1.7-5 1.7-1.7 5-1.7-5-5-1.7 5-1.7z"/>'],
    user: ['<circle cx="12" cy="8.2" r="3.7"/><path d="M4.8 19.8a7.2 7.2 0 0 1 14.4 0z"/>', '<circle cx="12" cy="8.2" r="3.7"/><path d="M4.8 19.8a7.2 7.2 0 0 1 14.4 0z"/>'],
    users: ['<circle cx="9" cy="9" r="3.3"/><path d="M3 19a6 6 0 0 1 12 0z"/><path d="M15.8 5.8a3.3 3.3 0 0 1 0 6.4M17.5 19H21a5.7 5.7 0 0 0-3.6-5.3"/>', '<circle cx="9" cy="9" r="3.3"/><path d="M3 19a6 6 0 0 1 12 0z"/>'],
    filter: ['<path d="M4.5 6.5h15M7.5 12h9M10.5 17.5h3"/>'],
    list: ['<rect x="4.5" y="5" width="15" height="5" rx="1.5"/><rect x="4.5" y="14" width="15" height="5" rx="1.5"/>', '<rect x="4.5" y="5" width="15" height="5" rx="1.5"/>'],
    image: ['<rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.5"/><path d="M20 15.5l-4.5-4.5L7 19"/>', '<rect x="4" y="5" width="16" height="14" rx="2.5"/>'],
    hash: ['<path d="M9.5 4.5L8 19.5M16 4.5l-1.5 15M5 9h15M4 15h15"/>'],
    lock: ['<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/><path d="M8.2 10.5V8a3.8 3.8 0 0 1 7.6 0v2.5M12 14.5v2"/>', '<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/>'],
    globe: ['<circle cx="12" cy="12" r="8"/><path d="M4 12h16M12 4c2.4 2.3 2.4 13.7 0 16M12 4c-2.4 2.3-2.4 13.7 0 16"/>', '<circle cx="12" cy="12" r="8"/>'],
    emoji: ['<circle cx="12" cy="12" r="8"/><path d="M8.8 13.8c1.6 1.8 4.8 1.8 6.4 0"/><circle cx="9.3" cy="9.8" r="1" fill="currentColor"/><circle cx="14.7" cy="9.8" r="1" fill="currentColor"/>', '<circle cx="12" cy="12" r="8"/>'],
    send: ['<path d="M4.5 11.6L19.5 4.5l-5.2 15-3-6.2z"/><path d="M11.3 13.3l3.4-3.4"/>', '<path d="M4.5 11.6L19.5 4.5l-5.2 15-3-6.2z"/>'],
    check: ['<path d="M5.5 12.5l4.2 4.2 8.8-9.4"/>'],
    flag: ['<path d="M6 20.5V4.5"/><path d="M6 5h11.5l-2.2 4 2.2 4H6"/>', '<path d="M6 5h11.5l-2.2 4 2.2 4H6z"/>'],
    link: ['<path d="M10.2 13.8a3.8 3.8 0 0 0 5.4 0l2.9-2.9a3.8 3.8 0 0 0-5.4-5.4l-1 1"/><path d="M13.8 10.2a3.8 3.8 0 0 0-5.4 0l-2.9 2.9a3.8 3.8 0 0 0 5.4 5.4l1-1"/>'],
    copy: ['<rect x="8.5" y="8.5" width="11" height="11" rx="2"/><path d="M15.5 8.5v-2a2 2 0 0 0-2-2h-7a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h2"/>', '<rect x="8.5" y="8.5" width="11" height="11" rx="2"/>'],
    trash: ['<path d="M4.5 7h15M9.5 7V5.2h5V7M6.5 7l.9 12a1.5 1.5 0 0 0 1.5 1.4h6.2a1.5 1.5 0 0 0 1.5-1.4l.9-12"/>', '<path d="M6.5 7l.9 12a1.5 1.5 0 0 0 1.5 1.4h6.2a1.5 1.5 0 0 0 1.5-1.4l.9-12z"/>'],
    eye: ['<path d="M3 12s3.3-6 9-6 9 6 9 6-3.3 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/>', '<circle cx="12" cy="12" r="2.6"/>'],
    logout: ['<path d="M13.5 4.5H7a1.5 1.5 0 0 0-1.5 1.5v12A1.5 1.5 0 0 0 7 19.5h6.5"/><path d="M10.5 12h9.5M17 8.8l3.2 3.2-3.2 3.2"/>', '<path d="M13.5 4.5H7a1.5 1.5 0 0 0-1.5 1.5v12A1.5 1.5 0 0 0 7 19.5h6.5z"/>'],
    moon: ['<path d="M19 14.6A7.6 7.6 0 0 1 9.4 5a7.6 7.6 0 1 0 9.6 9.6z"/>', '<path d="M19 14.6A7.6 7.6 0 0 1 9.4 5a7.6 7.6 0 1 0 9.6 9.6z"/>'],
    calendar: ['<rect x="4" y="5.5" width="16" height="14.5" rx="2.5"/><path d="M4 10h16M9 3.5v4M15 3.5v4"/>', '<path d="M4 8a2.5 2.5 0 0 1 2.5-2.5h11A2.5 2.5 0 0 1 20 8v2H4z"/>'],
    map: ['<path d="M4 6.3l5-1.8 6 2 5-1.8v13l-5 1.8-6-2-5 1.8z"/><path d="M9 4.5v13M15 6.5v13"/>', '<path d="M9 4.5l6 2v13l-6-2z"/>'],
    mail: ['<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="M4.5 7.5l7.5 5.5 7.5-5.5"/>', '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/>'],
    shield: ['<path d="M12 3.5l7 2.8v5c0 4.7-3.2 7.9-7 9.4-3.8-1.5-7-4.7-7-9.4v-5z"/><path d="M9 12l2.1 2.1 4-4.2"/>', '<path d="M12 3.5l7 2.8v5c0 4.7-3.2 7.9-7 9.4-3.8-1.5-7-4.7-7-9.4v-5z"/>'],
    download: ['<path d="M12 4.5v10M8.2 11L12 14.8 15.8 11"/><path d="M5 16.5v1.5a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 19 18v-1.5"/>'],
    refresh: ['<path d="M19.2 12a7.2 7.2 0 1 1-2.1-5.1"/><path d="M19.4 4.5v4h-4"/>'],
    alert: ['<circle cx="12" cy="12" r="8"/><path d="M12 8v4.8"/><circle cx="12" cy="15.8" r=".6" fill="currentColor"/>', '<circle cx="12" cy="12" r="8"/>'],
    swatch: ['<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><circle cx="16.5" cy="16.5" r="3.5"/>', '<rect x="4" y="4" width="7" height="7" rx="2"/><circle cx="16.5" cy="16.5" r="3.5"/>'],
    book: ['<path d="M5 5.5A1.5 1.5 0 0 1 6.5 4H17a1 1 0 0 1 1 1v12H7a2 2 0 0 0-2 2z"/><path d="M5 19a2 2 0 0 0 2 2h11v-4M9 8h5"/>', '<path d="M5 5.5A1.5 1.5 0 0 1 6.5 4H17a1 1 0 0 1 1 1v12H7a2 2 0 0 0-2 2z"/>'],
    block: ['<circle cx="12" cy="12" r="8"/><path d="M6.4 6.4l11.2 11.2"/>', '<circle cx="12" cy="12" r="8"/>'],
    edit: ['<path d="M5 19h3.8L18.6 9.2a2.1 2.1 0 0 0-3-3L5.8 16z"/><path d="M13.8 8l2.9 2.9"/>', '<path d="M5 19h3.8L18.6 9.2a2.1 2.1 0 0 0-3-3L5.8 16z"/>'],
    fire: ['<path d="M12 20.5c-3.7 0-6.3-2.5-6.3-5.9 0-3.4 2.9-5.4 3.4-8.9 2 1.4 3 2.9 3 4.9.9-.7 1.4-1.8 1.5-3 2.4 1.9 4.7 4.4 4.7 7.2 0 3.2-2.5 5.7-6.3 5.7z"/>', '<path d="M12 20.5c-3.7 0-6.3-2.5-6.3-5.9 0-3.4 2.9-5.4 3.4-8.9 2 1.4 3 2.9 3 4.9.9-.7 1.4-1.8 1.5-3 2.4 1.9 4.7 4.4 4.7 7.2 0 3.2-2.5 5.7-6.3 5.7z"/>'],
    clock: ['<circle cx="12" cy="12" r="8"/><path d="M12 8v4.2l2.8 1.8"/>', '<circle cx="12" cy="12" r="8"/>'],
    quote: ['<path d="M5 17.5c0-4 1.3-7 4.7-9M13 17.5c0-4 1.3-7 4.7-9"/><circle cx="7.3" cy="15.3" r="2.3"/><circle cx="15.3" cy="15.3" r="2.3"/>', '<circle cx="7.3" cy="15.3" r="2.3"/><circle cx="15.3" cy="15.3" r="2.3"/>']
  };
  var cache = null;
  function mk(R, k, solid) {
    var d = D[k];
    var html = (d[1] ? '<g fill="currentColor" stroke="none" style="fill-opacity:' + (solid ? '1' : 'var(--duo,.2)') + '">' + d[1] + '</g>' : '') + d[0];
    return R.createElement('svg', {
      viewBox: '0 0 24 24', width: '1em', height: '1em', fill: 'none', stroke: 'currentColor',
      strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round',
      style: { display: 'block', flex: 'none' }, dangerouslySetInnerHTML: { __html: html }
    });
  }
  window.ZXI2 = {
    make: function (R) {
      if (cache) return cache;
      var m = {};
      Object.keys(D).forEach(function (k) { m[k] = mk(R, k, false); if (D[k][1]) m[k + 'F'] = mk(R, k, true); });
      return (cache = m);
    }
  };
})();
