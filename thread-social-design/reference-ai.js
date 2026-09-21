/* New reference replaces the former rail on every view. No remote services. */
(() => {
  const paths={
    campus:'M3 21h18M5 21V9h14v12M3 9l9-6 9 6ZM9 21v-6h6v6M8 12h.01M16 12h.01',
    home:'M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z',
    ai:'M12 2 15 9 22 12 15 15 12 22 9 15 2 12 9 9Z',
    search:'M21 21l-5-5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0',
    bell:'M5 17h14l-1-9a6 6 0 0 0-12 0ZM9 20a3 3 0 0 0 6 0',
    follow:'M14 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0M3 21c0-6 3-9 7-9s7 3 7 9ZM21 7v8m-4-4h8',
    chat:'M4 17a10 10 0 1 1 4 4l-6 1Z',
    bookmark:'M5 2h14v21l-7-5-7 5Z',
    rocket:'M8 16 4 12C8 5 14 2 22 2c0 8-3 14-10 18l-4-4ZM13 6l5 5M5 16l-2 6 6-2M6 10H1l5-5h4M15 18v5l5-5v-5',
    premium:'m12 2 3 2 4 0 1 4 2 3-2 3-1 4-4 1-3 2-3-2-4-1-1-4-2-3 2-3 1-4 4 0Zm-5 9 3 3 6-6',
    person:'M15 5a3 3 0 1 1-6 0 3 3 0 0 1 6 0M3 21c0-6 4-9 9-9s9 3 9 9Z',
    more:'M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0M7 12h.01M12 12h.01M17 12h.01',
    expand:'M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5',
    history:'M3 3v5h5M3.6 8a9 9 0 1 1-.4 7M12 7v5l3 2',
    ghost:'M6 10a6 6 0 0 1 12 0v6l3 3-4 1-3-1-2 2-2-2-3 1-4-1 3-3ZM9 10v1m6-1v1',
    attach:'M8 10v7a4 4 0 0 0 8 0V6a3 3 0 0 0-6 0v10a1 1 0 0 0 2 0V8',
    bolt:'m13 2-9 12h7l-1 8 10-13h-7Z',
    down:'m7 10 5 5 5-5',
    wave:'M3 10v4m4-8v12m5-16v20m5-17v14m4-10v6',
    video:'M3 5h12v14H3a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm12 5 7-4v12l-7-4',
    image:'m7 3 11-1 3 3 1 11M3 7l12-2 3 14-12 2Zm3 9 3-5 7 5M7 9h.01',
    brush:'m9 14 10-12 3 3-12 11ZM9 14c-4-3-7 0-7 6 6 0 9-2 7-6Z',
    news:'M3 4h18v16H3Zm4 4h3v4H7Zm7 0h3m-3 4h3M7 16h10'
  };
  const icon=(name)=>`<span class="x-icon"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name]}"></path></svg></span>`;
  const navItems=[['home','主页','home'],['search','探索','search'],['campus','Campus','campus'],['bell','通知','notifications'],['follow','关注','following'],['chat','聊天','messages'],['ai','AI','ai'],['bookmark','历史','bookmarks'],['person','个人资料','profile']];
  document.body.classList.add('reference-shell','light');
  document.body.classList.remove('ref-dark');
  const rail=document.querySelector('.rail');
  rail.innerHTML=`<button class="x-brand" aria-label="主页" data-route="home"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18.9 1.2H22l-6.8 7.8L23.2 23h-6.3L12 14.5 4.6 23H1.4l9.2-10.7L.8 1.2h6.5l4.4 7.4Zm-1.1 19.9h1.8L6.2 3.1H4.3Z"/></svg></button><nav class="x-navigation" aria-label="主导航">${navItems.map(([i,label,route])=>`<button class="x-nav" data-route="${route}">${i==='grok'?'<span class="x-icon grok-nav-mark"></span>':icon(i)}${i==='bell'?'<span class="badge-count" style="left:38px;top:10px">8</span>':''}<span>${label}</span></button>`).join('')}</nav><button class="x-post" data-compose>发帖</button><button class="x-account" data-account><span class="x-account-avatar"></span><span><strong>Zavier</strong><small>@Xaverll</small></span><span class="ellipsis">···</span></button>`;
  document.querySelector('#view-ai').innerHTML=`<header class="grok-top"><button data-expand aria-label="全屏">${icon('expand')}</button><button data-history>${icon('history')}历史</button><button data-private aria-pressed="false">${icon('ghost')}私密</button></header><div class="grok-center"><div class="grok-logo" role="img" aria-label="Grok"></div><form class="grok-question"><button type="button" class="attach" aria-label="添加附件">${icon('attach')}</button><input aria-label="询问 Grok" placeholder="随便问点什么" autocomplete="off"><button type="button" class="mode-button" aria-label="选择模型模式">${icon('bolt')}<span>快速</span>${icon('down')}</button><button type="submit" class="voice-button" aria-label="发送问题">${icon('wave')}</button></form><div class="grok-shortcuts">${[['video','创建视频'],['image','创建图片'],['brush','编辑图片'],['news','最新新闻']].map(([i,t])=>`<button data-prompt="${t}">${icon(i)}${t}</button>`).join('')}</div><div class="grok-transcript" hidden></div></div><input type="file" id="grok-file" hidden>`;
  const aiLogo=document.querySelector('.grok-logo');
  aiLogo.className='ai-wordmark';
  aiLogo.setAttribute('aria-label','AI');
  aiLogo.innerHTML=icon('ai')+'<span>AI</span>';
  document.querySelector('.grok-question input').setAttribute('aria-label','询问 AI');
  function dimensions(){const scale=document.documentElement.clientWidth/1996;document.documentElement.style.setProperty('--ref-scale',scale);document.documentElement.style.setProperty('--ref-height',`${innerHeight/scale}px`);}
  // Angular, monochrome lightning mark; inherits the active theme's ink.
  rail.querySelector('.x-brand svg').innerHTML='<path fill-rule="evenodd" d="M14.5 1 3 14h8L9.5 23 22 9h-8ZM13 6.1 7.8 12H13l-.6 5.7L17.5 11H12Z"/>';
  dimensions();addEventListener('resize',dimensions);
  function route(name){
    if(name==='settings-campus'){name='settings';document.querySelector('.c-login-settings').open=true;}
    if(name==='compose'){document.querySelector('#compose-modal').classList.add('open');return;}
    if(name==='more'){menu();return;}
    const target=document.getElementById('view-'+name);
    if(!target){toast('此页面设计尚未完成');return;}
    document.querySelectorAll('.view').forEach(x=>x.classList.toggle('active',x===target));
    document.querySelectorAll('.x-nav').forEach(x=>{if(x.dataset.route===name)x.setAttribute('aria-current','page');else x.removeAttribute('aria-current');});
    document.body.classList.toggle('ai-active',name==='ai');
    document.querySelector('#top-title').textContent=navItems.find(x=>x[2]===name)?.[1]||'设置';
    history.replaceState(null,'','#'+name);window.scrollTo(0,0);
  }
  rail.addEventListener('click',e=>{const b=e.target.closest('[data-route]');if(b)route(b.dataset.route);if(e.target.closest('[data-compose]'))document.querySelector('#compose-modal').classList.add('open');if(e.target.closest('[data-account]'))menu();});
  function menu(){const old=document.querySelector('.x-popover');if(old){old.remove();return;}const el=document.createElement('div');el.className='x-popover';el.innerHTML='<button data-theme>切换浅色 / 深色</button><button data-settings>设置与隐私</button><button data-close>关闭</button>';document.body.append(el);el.onclick=e=>{if(e.target.closest('[data-theme]')){const dark=document.body.classList.toggle('ref-dark');document.body.classList.toggle('light',!dark);localStorage.setItem('reference-theme',dark?'dark':'light');}if(e.target.closest('[data-settings]'))route('settings');el.remove();};}
  function toast(message){document.querySelector('.x-toast')?.remove();const el=document.createElement('div');el.className='x-toast';el.textContent=message;document.body.append(el);setTimeout(()=>el.remove(),3500);}
  const ai=document.querySelector('#view-ai'),question=ai.querySelector('input');
  ai.querySelector('[data-history]').onclick=()=>{const old=ai.querySelector('.grok-drawer');if(old){old.remove();return;}const drawer=document.createElement('aside');drawer.className='grok-drawer';drawer.innerHTML='<h2>历史</h2><p>还没有对话记录</p><button>关闭</button>';drawer.querySelector('button').onclick=()=>drawer.remove();ai.append(drawer);};
  ai.querySelector('[data-private]').onclick=e=>{const b=e.currentTarget;const selected=b.getAttribute('aria-pressed')!=='true';b.setAttribute('aria-pressed',selected?'true':'false');b.innerHTML=icon('ghost')+(selected?'私密已开启':'私密');};
  ai.querySelector('[data-expand]').onclick=()=>{document.querySelector('.rail').hidden=!document.querySelector('.rail').hidden;toast('全屏预览切换');};
  ai.querySelector('.attach').onclick=()=>ai.querySelector('#grok-file').click();
  ai.querySelector('#grok-file').onchange=e=>{if(e.target.files[0])toast('已选择 '+e.target.files[0].name);};
  ai.querySelector('.mode-button').onclick=e=>{const b=e.currentTarget;const thinking=b.dataset.mode!=='thinking';b.dataset.mode=thinking?'thinking':'fast';b.querySelector('span:not(.x-icon)').textContent=thinking?'思考':'快速';};
  ai.querySelectorAll('[data-prompt]').forEach(b=>b.onclick=()=>{question.value=window.i18n.translate(b.dataset.prompt)+(window.i18n.language==='zh'?'：':': ');question.focus();});
  ai.querySelector('form').onsubmit=e=>{e.preventDefault();if(!question.value.trim()){question.focus();return;}const box=ai.querySelector('.grok-transcript');box.hidden=false;box.replaceChildren();const strong=document.createElement('strong');strong.textContent=question.value;const p=document.createElement('p');p.textContent='这是交互设计预览，尚未连接 AI 服务。';box.append(strong,p);};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'){document.querySelector('.x-popover')?.remove();ai.querySelector('.grok-drawer')?.remove();}});
  document.addEventListener('reference-route',e=>route(e.detail));
  addEventListener('hashchange',()=>route(location.hash.slice(1)||'ai'));
  if(localStorage.getItem('reference-theme')==='dark'){document.body.classList.add('ref-dark');document.body.classList.remove('light');}
  route(location.hash.slice(1)||'ai');
})();
