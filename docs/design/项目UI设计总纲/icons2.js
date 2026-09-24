// 西电知行 · 正式图标集 v3。24 × 24 网格，2px 安全边距，描边 1.6 圆头圆角；每个图标 = 线稿层 + 同色填充层（默认 20%，选中 35%，实心 100%）。
// 关键线：圆 r=8 · 方 16×16 圆角 2.5 · 竖 14×17 · 横 17×13。导出：ZXI2.svg(key,{fill,color,size}) 返回独立 SVG 字符串。
(function () {
  var D = {
    treehole: ['<path d="M12 3.6c3.2 0 5.8 2.5 5.8 5.6 0 .8-.2 1.6-.5 2.3a3.8 3.8 0 0 1-1.8 6.7h-2V21h-3v-2.8h-2a3.8 3.8 0 0 1-1.8-6.7 5.5 5.5 0 0 1-.5-2.3c0-3.1 2.6-5.6 5.8-5.6z"/><ellipse cx="12" cy="12.6" rx="1.7" ry="2.3"/>', '<path d="M12 3.6c3.2 0 5.8 2.5 5.8 5.6 0 .8-.2 1.6-.5 2.3a3.8 3.8 0 0 1-1.8 6.7h-7a3.8 3.8 0 0 1-1.8-6.7 5.5 5.5 0 0 1-.5-2.3c0-3.1 2.6-5.6 5.8-5.6z"/>'],
    campus: ['<path d="M3.2 9.4L12 4.5l8.8 4.9z"/><path d="M6 12v5.5M10 12v5.5M14 12v5.5M18 12v5.5M4.5 17.5h15M3.5 20.5h17"/>', '<path d="M3.2 9.4L12 4.5l8.8 4.9z"/>'],
    ai: ['<path d="M10.5 4l1.6 4.4 4.4 1.6-4.4 1.6-1.6 4.4-1.6-4.4L4.5 10l4.4-1.6z"/><path d="M17.5 14.2l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>', '<path d="M10.5 4l1.6 4.4 4.4 1.6-4.4 1.6-1.6 4.4-1.6-4.4L4.5 10l4.4-1.6z"/><path d="M17.5 14.2l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>'],
    chat: ['<path d="M4.5 7A2.5 2.5 0 0 1 7 4.5h10A2.5 2.5 0 0 1 19.5 7v7.5A2.5 2.5 0 0 1 17 17h-5.2l-4.3 3.3V17H7a2.5 2.5 0 0 1-2.5-2.5z"/><path d="M8.5 9.3h7M8.5 12.3h4.2"/>', '<path d="M4.5 7A2.5 2.5 0 0 1 7 4.5h10A2.5 2.5 0 0 1 19.5 7v7.5A2.5 2.5 0 0 1 17 17h-5.2l-4.3 3.3V17H7a2.5 2.5 0 0 1-2.5-2.5z"/>'],
    user: ['<circle cx="12" cy="8.2" r="3.8"/><path d="M5 20a7 7 0 0 1 14 0z"/>', '<circle cx="12" cy="8.2" r="3.8"/><path d="M5 20a7 7 0 0 1 14 0z"/>'],
    home: ['<path d="M4.5 10.2L12 4.5l7.5 5.7V19a1 1 0 0 1-1 1h-4v-5.5h-5V20h-4a1 1 0 0 1-1-1z"/>', '<path d="M4.5 10.2L12 4.5l7.5 5.7V19a1 1 0 0 1-1 1h-4v-5.5h-5V20h-4a1 1 0 0 1-1-1z"/>'],
    search: ['<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/>', '<circle cx="11" cy="11" r="6.5"/>'],
    bell: ['<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 21h4"/>', '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/>'],
    comment: ['<path d="M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H12l-4.5 3.5v-3.5h-1a2 2 0 0 1-2-2z"/>', '<path d="M4.5 6.5a2 2 0 0 1 2-2h11a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H12l-4.5 3.5v-3.5h-1a2 2 0 0 1-2-2z"/>'],
    users: ['<circle cx="9" cy="8.8" r="3.3"/><path d="M3 19.5a6 6 0 0 1 12 0z"/><path d="M15.8 5.6a3.3 3.3 0 0 1 0 6.4M17.5 19.5H21a5.7 5.7 0 0 0-3.6-5.3"/>', '<circle cx="9" cy="8.8" r="3.3"/><path d="M3 19.5a6 6 0 0 1 12 0z"/>'],
    userPlus: ['<circle cx="10" cy="8.2" r="3.6"/><path d="M3.5 20a6.5 6.5 0 0 1 13 0z"/><path d="M19 8v6M16 11h6"/>', '<circle cx="10" cy="8.2" r="3.6"/><path d="M3.5 20a6.5 6.5 0 0 1 13 0z"/>'],
    plus: ['<path d="M12 5v14M5 12h14"/>'],
    close: ['<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'],
    back: ['<path d="M14.5 5.5L8 12l6.5 6.5"/>'],
    chevron: ['<path d="M9.5 5.5L16 12l-6.5 6.5"/>'],
    down: ['<path d="M6.5 9.5L12 15l5.5-5.5"/>'],
    up: ['<path d="M6.5 14.5L12 9l5.5 5.5"/>'],
    more: ['<circle cx="5.5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="18.5" cy="12" r="1.3" fill="currentColor"/>'],
    moreV: ['<circle cx="12" cy="5.5" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="18.5" r="1.3" fill="currentColor"/>'],
    heart: ['<path d="M12 19.5s-7.5-4.4-7.5-10A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 7.5 2.5c0 5.6-7.5 10-7.5 10z"/>', '<path d="M12 19.5s-7.5-4.4-7.5-10A4.3 4.3 0 0 1 12 7a4.3 4.3 0 0 1 7.5 2.5c0 5.6-7.5 10-7.5 10z"/>'],
    star: ['<path d="M12 4.2l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 16.6l-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z"/>', '<path d="M12 4.2l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 16.6l-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z"/>'],
    share: ['<path d="M12 14.5v-10M8.3 8.2L12 4.5l3.7 3.7"/><path d="M8 11H6.5A1.5 1.5 0 0 0 5 12.5v5A1.5 1.5 0 0 0 6.5 19h11a1.5 1.5 0 0 0 1.5-1.5v-5a1.5 1.5 0 0 0-1.5-1.5H16"/>', '<path d="M5 12.5A1.5 1.5 0 0 1 6.5 11h11a1.5 1.5 0 0 1 1.5 1.5v5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 17.5z"/>'],
    pin: ['<path d="M9.2 4.5h5.6l-.9 4.8 3 3.2H7.1l3-3.2z"/><path d="M12 12.5v7"/>', '<path d="M9.2 4.5h5.6l-.9 4.8 3 3.2H7.1l3-3.2z"/>'],
    link: ['<path d="M10.2 13.8a3.8 3.8 0 0 0 5.4 0l2.9-2.9a3.8 3.8 0 0 0-5.4-5.4l-1 1"/><path d="M13.8 10.2a3.8 3.8 0 0 0-5.4 0l-2.9 2.9a3.8 3.8 0 0 0 5.4 5.4l1-1"/>'],
    copy: ['<rect x="8.5" y="8.5" width="11" height="11" rx="2"/><path d="M15.5 8.5v-2a2 2 0 0 0-2-2h-7a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h2"/>', '<rect x="8.5" y="8.5" width="11" height="11" rx="2"/>'],
    trash: ['<path d="M4.5 7h15M9.5 7V5h5v2M6.5 7l.9 12a1.5 1.5 0 0 0 1.5 1.4h6.2a1.5 1.5 0 0 0 1.5-1.4l.9-12M10 11v5.5M14 11v5.5"/>', '<path d="M6.5 7l.9 12a1.5 1.5 0 0 0 1.5 1.4h6.2a1.5 1.5 0 0 0 1.5-1.4l.9-12z"/>'],
    edit: ['<path d="M5 19h3.8L18.6 9.2a2.1 2.1 0 0 0-3-3L5.8 16z"/><path d="M13.8 8l2.9 2.9"/>', '<path d="M5 19h3.8L18.6 9.2a2.1 2.1 0 0 0-3-3L5.8 16z"/>'],
    send: ['<path d="M4.5 11.6l15-7.1-5.2 15-3-6.2z"/><path d="M11.3 13.3l3.4-3.4"/>', '<path d="M4.5 11.6l15-7.1-5.2 15-3-6.2z"/>'],
    check: ['<path d="M5.5 12.5l4.2 4.2 8.8-9.4"/>'],
    checkAll: ['<path d="M3 12.8l4 4 8.2-9"/><path d="M11.8 16.3l.5.5 8.7-9.3"/>'],
    flag: ['<path d="M6 20.5v-16"/><path d="M6 5h11.5l-2.2 4 2.2 4H6"/>', '<path d="M6 5h11.5l-2.2 4 2.2 4H6z"/>'],
    block: ['<circle cx="12" cy="12" r="8"/><path d="M6.4 6.4l11.2 11.2"/>', '<circle cx="12" cy="12" r="8"/>'],
    eye: ['<path d="M3 12s3.3-6 9-6 9 6 9 6-3.3 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/>', '<circle cx="12" cy="12" r="2.6"/>'],
    eyeOff: ['<path d="M9.9 6.3A9 9 0 0 1 12 6c5.7 0 9 6 9 6a15 15 0 0 1-2.6 3.3M6.3 7.8C4.1 9.5 3 12 3 12s3.3 6 9 6c1.4 0 2.6-.3 3.7-.8M10.2 10.2a2.6 2.6 0 0 0 3.6 3.6M4.5 4.5l15 15"/>'],
    lock: ['<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/><path d="M8.2 10.5V8a3.8 3.8 0 0 1 7.6 0v2.5M12 14.5v2"/>', '<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/>'],
    globe: ['<circle cx="12" cy="12" r="8"/><path d="M4 12h16M12 4c2.4 2.3 2.4 13.7 0 16M12 4c-2.4 2.3-2.4 13.7 0 16"/>', '<circle cx="12" cy="12" r="8"/>'],
    emoji: ['<circle cx="12" cy="12" r="8"/><path d="M8.8 13.8c1.6 1.8 4.8 1.8 6.4 0"/><circle cx="9.3" cy="9.8" r="1" fill="currentColor"/><circle cx="14.7" cy="9.8" r="1" fill="currentColor"/>', '<circle cx="12" cy="12" r="8"/>'],
    image: ['<rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.5"/><path d="M20 15.5L15.5 11 7 19"/>', '<rect x="4" y="5" width="16" height="14" rx="2.5"/>'],
    camera: ['<path d="M4 8.5a2 2 0 0 1 2-2h2l1.5-2h5l1.5 2h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.3"/>', '<path d="M4 8.5a2 2 0 0 1 2-2h2l1.5-2h5l1.5 2h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/>'],
    hash: ['<path d="M9.5 4.5L8 19.5M16 4.5l-1.5 15M5 9h15M4 15h15"/>'],
    at: ['<circle cx="12" cy="12" r="3.3"/><path d="M15.3 12v1.3a2.5 2.5 0 0 0 5 0V12a8.3 8.3 0 1 0-3.3 6.6"/>', '<circle cx="12" cy="12" r="3.3"/>'],
    tag: ['<path d="M4 12.2V5.5A1.5 1.5 0 0 1 5.5 4h6.7l8 8-8.2 8.2z"/><circle cx="8.5" cy="8.5" r="1.4"/>', '<path d="M4 12.2V5.5A1.5 1.5 0 0 1 5.5 4h6.7l8 8-8.2 8.2z"/>'],
    filter: ['<path d="M4.5 6.5h15M7.5 12h9M10.5 17.5h3"/>'],
    sliders: ['<path d="M4 7h9M18 7h2M4 17h3M12 17h8"/><circle cx="15.5" cy="7" r="2.3"/><circle cx="9.5" cy="17" r="2.3"/>', '<circle cx="15.5" cy="7" r="2.3"/><circle cx="9.5" cy="17" r="2.3"/>'],
    sort: ['<path d="M7.5 5v14M4.5 16l3 3 3-3M16.5 19V5M13.5 8l3-3 3 3"/>'],
    list: ['<rect x="4.5" y="5" width="15" height="5" rx="1.5"/><rect x="4.5" y="14" width="15" height="5" rx="1.5"/>', '<rect x="4.5" y="5" width="15" height="5" rx="1.5"/>'],
    grid: ['<rect x="4.5" y="4.5" width="6" height="6" rx="1.8"/><rect x="13.5" y="4.5" width="6" height="6" rx="1.8"/><rect x="4.5" y="13.5" width="6" height="6" rx="1.8"/><rect x="13.5" y="13.5" width="6" height="6" rx="1.8"/>', '<rect x="4.5" y="4.5" width="6" height="6" rx="1.8"/><rect x="13.5" y="13.5" width="6" height="6" rx="1.8"/>'],
    refresh: ['<path d="M19.2 12a7.2 7.2 0 1 1-2.1-5.1"/><path d="M19.4 4.5v4h-4"/>'],
    undo: ['<path d="M9 5L4.5 9.5 9 14"/><path d="M4.5 9.5H14a5 5 0 0 1 0 10h-3"/>'],
    reply: ['<path d="M10 7l-5 5 5 5"/><path d="M5 12h8.5a6 6 0 0 1 6 6v1"/>'],
    forward: ['<path d="M14 7l5 5-5 5"/><path d="M19 12h-8.5a6 6 0 0 0-6 6v1"/>'],
    select: ['<rect x="4.5" y="4.5" width="15" height="15" rx="3"/><path d="M8.5 12.2l2.5 2.5 4.6-4.9"/>', '<rect x="4.5" y="4.5" width="15" height="15" rx="3"/>'],
    info: ['<circle cx="12" cy="12" r="8"/><path d="M12 11v5"/><circle cx="12" cy="8.2" r=".6" fill="currentColor"/>', '<circle cx="12" cy="12" r="8"/>'],
    alert: ['<circle cx="12" cy="12" r="8"/><path d="M12 8v4.8"/><circle cx="12" cy="15.8" r=".6" fill="currentColor"/>', '<circle cx="12" cy="12" r="8"/>'],
    clock: ['<circle cx="12" cy="12" r="8"/><path d="M12 8v4.2l2.8 1.8"/>', '<circle cx="12" cy="12" r="8"/>'],
    history: ['<path d="M4.6 12a7.4 7.4 0 1 0 2.2-5.2L4.5 9"/><path d="M4.5 4.8V9h4.2M12 8.5V12l2.5 1.6"/>'],
    calendar: ['<rect x="4" y="5.5" width="16" height="14.5" rx="2.5"/><path d="M4 10h16M9 3.5v4M15 3.5v4"/>', '<path d="M4 8a2.5 2.5 0 0 1 2.5-2.5h11A2.5 2.5 0 0 1 20 8v2H4z"/>'],
    table: ['<rect x="4" y="4.5" width="16" height="15" rx="2.5"/><path d="M4 9.5h16M9.5 9.5v10M4 14.5h16"/>', '<path d="M4 7a2.5 2.5 0 0 1 2.5-2.5h11A2.5 2.5 0 0 1 20 7v2.5H4z"/>'],
    exam: ['<path d="M7 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/><path d="M14 3.5V8h4.5M9 14l2 2 4-4"/>', '<path d="M7 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/>'],
    doc: ['<path d="M7 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/><path d="M14 3.5V8h4.5M8.5 12.5h7M8.5 16h5"/>', '<path d="M7 3.5h7l4.5 4.5v11a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z"/>'],
    map: ['<path d="M4 6.3l5-1.8 6 2 5-1.8v13l-5 1.8-6-2-5 1.8z"/><path d="M9 4.5v13M15 6.5v13"/>', '<path d="M9 4.5l6 2v13l-6-2z"/>'],
    mapPin: ['<path d="M12 20.5s-6-5.6-6-10.5a6 6 0 0 1 12 0c0 4.9-6 10.5-6 10.5z"/><circle cx="12" cy="10" r="2.2"/>', '<path d="M12 20.5s-6-5.6-6-10.5a6 6 0 0 1 12 0c0 4.9-6 10.5-6 10.5z"/>'],
    building: ['<path d="M5.5 20.5v-15A1.5 1.5 0 0 1 7 4h6.5A1.5 1.5 0 0 1 15 5.5v15M15 10h3a1.5 1.5 0 0 1 1.5 1.5v9M3.5 20.5h17M8.5 8h3.5M8.5 11.5h3.5M8.5 15h3.5"/>', '<path d="M5.5 20.5v-15A1.5 1.5 0 0 1 7 4h6.5A1.5 1.5 0 0 1 15 5.5v15z"/>'],
    wifi: ['<path d="M4 9.5a11.5 11.5 0 0 1 16 0M7 12.8a7.2 7.2 0 0 1 10 0M9.8 16a3.2 3.2 0 0 1 4.4 0"/><circle cx="12" cy="19" r=".9" fill="currentColor"/>'],
    flask: ['<path d="M9.5 3.5h5M10 3.5V9l-5 9a1.8 1.8 0 0 0 1.6 2.6h10.8A1.8 1.8 0 0 0 19 18l-5-9V3.5M7.3 14h9.4"/>', '<path d="M7.3 14h9.4l2.3 4a1.8 1.8 0 0 1-1.6 2.6H6.6A1.8 1.8 0 0 1 5 18z"/>'],
    idcard: ['<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><circle cx="9" cy="11" r="2"/><path d="M6 15.5a3 3 0 0 1 6 0M14.5 10h3M14.5 13h3"/>', '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/>'],
    key: ['<circle cx="8" cy="15.5" r="3.5"/><path d="M10.5 13L19 4.5M16 7.5l2.5 2.5M13.8 9.7l2 2"/>', '<circle cx="8" cy="15.5" r="3.5"/>'],
    shield: ['<path d="M12 3.5l7 2.8v5c0 4.7-3.2 7.9-7 9.4-3.8-1.5-7-4.7-7-9.4v-5z"/><path d="M9 12l2.1 2.1 4-4.2"/>', '<path d="M12 3.5l7 2.8v5c0 4.7-3.2 7.9-7 9.4-3.8-1.5-7-4.7-7-9.4v-5z"/>'],
    server: ['<rect x="4.5" y="4.5" width="15" height="6.5" rx="2"/><rect x="4.5" y="13" width="15" height="6.5" rx="2"/><path d="M8 7.8h.01M8 16.2h.01M11.5 7.8h4M11.5 16.2h4"/>', '<rect x="4.5" y="4.5" width="15" height="6.5" rx="2"/><rect x="4.5" y="13" width="15" height="6.5" rx="2"/>'],
    external: ['<path d="M13.5 4.5h6v6M19.5 4.5L11 13M17 14v4a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 5 18V9a1.5 1.5 0 0 1 1.5-1.5h4"/>'],
    download: ['<path d="M12 4.5v10M8.2 11l3.8 3.8 3.8-3.8"/><path d="M5 16.5V18a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 19 18v-1.5"/>'],
    logout: ['<path d="M13.5 4.5H7A1.5 1.5 0 0 0 5.5 6v12A1.5 1.5 0 0 0 7 19.5h6.5"/><path d="M10.5 12H20M17 8.8l3.2 3.2-3.2 3.2"/>', '<path d="M13.5 4.5H7A1.5 1.5 0 0 0 5.5 6v12A1.5 1.5 0 0 0 7 19.5h6.5z"/>'],
    moon: ['<path d="M19 14.6A7.6 7.6 0 0 1 9.4 5a7.6 7.6 0 1 0 9.6 9.6z"/>', '<path d="M19 14.6A7.6 7.6 0 0 1 9.4 5a7.6 7.6 0 1 0 9.6 9.6z"/>'],
    sun: ['<circle cx="12" cy="12" r="3.8"/><path d="M12 3.5v1.8M12 18.7v1.8M3.5 12h1.8M18.7 12h1.8M6 6l1.3 1.3M16.7 16.7L18 18M6 18l1.3-1.3M16.7 7.3L18 6"/>', '<circle cx="12" cy="12" r="3.8"/>'],
    swatch: ['<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><circle cx="16.5" cy="16.5" r="3.5"/>', '<rect x="4" y="4" width="7" height="7" rx="2"/><circle cx="16.5" cy="16.5" r="3.5"/>'],
    book: ['<path d="M5 5.5A1.5 1.5 0 0 1 6.5 4H17a1 1 0 0 1 1 1v12H7a2 2 0 0 0-2 2z"/><path d="M5 19a2 2 0 0 0 2 2h11v-4M9 8h5"/>', '<path d="M5 5.5A1.5 1.5 0 0 1 6.5 4H17a1 1 0 0 1 1 1v12H7a2 2 0 0 0-2 2z"/>'],
    mail: ['<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="M4.5 7.5l7.5 5.5 7.5-5.5"/>', '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/>'],
    fire: ['<path d="M12 20.5c-3.7 0-6.3-2.5-6.3-5.9 0-3.4 2.9-5.4 3.4-8.9 2 1.4 3 2.9 3 4.9.9-.7 1.4-1.8 1.5-3 2.4 1.9 4.7 4.4 4.7 7.2 0 3.2-2.5 5.7-6.3 5.7z"/>', '<path d="M12 20.5c-3.7 0-6.3-2.5-6.3-5.9 0-3.4 2.9-5.4 3.4-8.9 2 1.4 3 2.9 3 4.9.9-.7 1.4-1.8 1.5-3 2.4 1.9 4.7 4.4 4.7 7.2 0 3.2-2.5 5.7-6.3 5.7z"/>'],
    quote: ['<path d="M5 17.5c0-4 1.3-7 4.7-9M13 17.5c0-4 1.3-7 4.7-9"/><circle cx="7.3" cy="15.3" r="2.3"/><circle cx="15.3" cy="15.3" r="2.3"/>', '<circle cx="7.3" cy="15.3" r="2.3"/><circle cx="15.3" cy="15.3" r="2.3"/>'],
    markdown: ['<rect x="3" y="6" width="18" height="12" rx="2.5"/><path d="M6.5 15V9l2.5 3 2.5-3v6M16.5 9v6M14.5 13l2 2 2-2"/>', '<rect x="3" y="6" width="18" height="12" rx="2.5"/>'],
    cloud: ['<path d="M7 18.5a4 4 0 0 1-.6-8A5.5 5.5 0 0 1 17 9a4.5 4.5 0 0 1 .5 9.5z"/><path d="M9.5 14l2 2 3.5-3.5"/>', '<path d="M7 18.5a4 4 0 0 1-.6-8A5.5 5.5 0 0 1 17 9a4.5 4.5 0 0 1 .5 9.5z"/>']
  };
  var TABS = ['treehole', 'campus', 'ai', 'chat', 'user'];
  function inner(k, fillOpacity) {
    var d = D[k]; if (!d) return '';
    return (d[1] ? '<g fill="currentColor" stroke="none" style="fill-opacity:' + fillOpacity + '">' + d[1] + '</g>' : '') + d[0];
  }
  function svg(k, o) {
    o = o || {}; var fo = o.fill == null ? .2 : o.fill, c = o.color || 'currentColor', s = o.size || 24;
    var d = D[k]; if (!d) return '';
    var body = (d[1] && fo > 0 ? '<g fill="' + c + '" fill-opacity="' + fo + '" stroke="none">' + d[1] + '</g>' : '') + d[0].replace(/currentColor/g, c);
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + s + '" height="' + s + '" viewBox="0 0 24 24" fill="none" stroke="' + c + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>';
  }
  var cache = null;
  function mk(R, k, solid) {
    return R.createElement('svg', {
      viewBox: '0 0 24 24', width: '1em', height: '1em', fill: 'none', stroke: 'currentColor',
      strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round',
      style: { display: 'block', flex: 'none' }, dangerouslySetInnerHTML: { __html: inner(k, solid ? '1' : 'var(--duo,.2)') }
    });
  }
  var api = {
    D: D, TABS: TABS, keys: Object.keys(D), svg: svg,
    make: function (R) {
      if (cache) return cache;
      var m = {};
      Object.keys(D).forEach(function (k) { m[k] = mk(R, k, false); if (D[k][1]) m[k + 'F'] = mk(R, k, true); });
      return (cache = m);
    }
  };
  window.ZXI2 = api; window.ZXI3 = api;
})();
