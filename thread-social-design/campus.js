/* Campus prototype: mirrors service routing, without making authenticated requests. */
(() => {
 const root=document.querySelector('#view-campus');
 // Paired copy is local to this page; the shared language setting remains the only switch.
 const t=(zh,en)=>`<span data-user-content class="c-copy"><span lang="zh-CN">${zh}</span><span lang="en">${en}</span></span>`;
 const icons={school:'M3 21h18M5 21V9h14v12M3 9l9-6 9 6ZM9 21v-6h6v6',calendar:'M4 5h16v16H4ZM4 10h16M8 2v5m8-5v5',book:'M12 5v16M3 3c4-1 6 0 9 2 3-2 5-3 9-2v16c-4-1-6 0-9 2-3-2-5-3-9-2Z',life:'M12 3c0 0-7 8-7 12a7 7 0 0 0 14 0c0-4-7-12-7-12Z',tool:'M4 4h6v6H4Zm10 0h6v6h-6ZM4 14h6v6H4Zm10 0h6v6h-6Z',key:'M14 8a5 5 0 1 1-10 0 5 5 0 0 1 10 0Zm-1 4 8 8m-3-3 3-3m-6 0 3-3',chevron:'m9 5 7 7-7 7',back:'M20 12H4m7-7-7 7 7 7',search:'M21 21l-5-5M18 10a8 8 0 1 1-16 0 8 8 0 0 1 16 0',external:'M14 3h7v7m0-7L10 14M10 3H3v18h18v-7'};
 const icon=n=>`<svg class="c-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${icons[n]}"></path></svg>`;
 const groups=[['学习事务','Academics','book'],['校园生活','Campus life','life'],['校务办理','Administration','school'],['工具入口','Tools','tool']];
 // Names and group structure follow the existing campus catalogue.
 const services=[
 ['classtable',0,'课表','Class schedule','课程、考试与实验周历','Weekly classes, exams and labs','calendar'],
 ['score',0,'成绩单','Grades','学期成绩与学分','Term grades and credits'],
 ['exam',0,'考试安排','Exams','考试时间、考场与座位','Times, rooms and seats','calendar'],
 ['experiment',0,'实验安排','Labs','实验日程与地点','Lab sessions and locations','calendar'],
 ['empty-classroom',0,'空闲教室','Free classrooms','按校区、楼宇和时段查询','Search by campus, building and time'],
 ['attendance',0,'考勤','Attendance','签到、作业与学习进度','Check-ins, assignments and progress'],
 ['sport',0,'体育','Physical education','体育课程与体测成绩','PE courses and fitness results'],
 ['electricity',1,'宿舍电费','Dorm electricity','电量余额与缴费入口','Balance and payment portal'],
 ['dorm-water',1,'宿舍水机','Dorm water dispenser','设备与取水服务','Devices and water dispensing','auth'],
 ['library',1,'图书馆','Library','借阅、续借与座位','Loans, renewals and seats'],
 ['school-card',1,'校园卡','Campus card','余额与交易记录','Balance and transactions'],
 ['schoolnet',1,'校园网','Campus network','套餐、流量与在线设备','Plans, data and online devices','auth'],
 ['map',1,'校园地图','Campus map','学校官方 GIS 导航','Official university GIS navigation','map'],
 ['building-map',1,'楼宇地图','Building floor plans','教室、办公室与设施','Classrooms, offices and facilities'],
 ['places',1,'校园地点','Campus places','食堂、图书馆与服务点','Dining, libraries and services'],
 ['student-info',2,'学期与住宿信息','Term and housing info','学期、个人资料与住宿地址','Term, student and housing details'],
 ['payment',2,'校园缴费','Payments','电费与校内费用','Electricity and campus charges'],
 ['drinking-water',2,'桶装水','Water delivery','学校送水服务','University water delivery'],
 ['repair',2,'后勤报修','Facility repairs','宿舍与楼宇设施报修','Dorm and building maintenance'],
 ['space-reservation',2,'空间预约','Space booking','图书馆与校园空间','Library and campus spaces'],
 ['leave',2,'请销假','Leave requests','请假申请与返校登记','Leave and return requests'],
 ['creative',2,'创新创业','Innovation contests','竞赛、项目与报名','Contests, projects and registration'],
 ['physics-helper',3,'物理实验计算','Physics lab calculator','物理实验计算工具','Physics lab calculation tools'],
 ['mobile-portal',3,'移动门户','Mobile portal','学校移动服务入口','University mobile services'],
 ['venue-reservation',3,'场馆预约','Sports venue booking','场馆时段与预约记录','Available slots and bookings'],
 ['wecom',3,'学校企业微信','University WeCom','学校企业微信服务','University WeCom services'],
 ['official-miniprogram',3,'学校小程序','University mini program','学校官方小程序入口','Official university mini program'],
 ['service-hall',3,'校园服务大厅','Other campus services','更多校内办事入口','More university services'],
 ['remote-access',3,'校外访问','Off-campus access','访问校园网络资源','Access campus network resources'],
 ['self-print',3,'自助打印','Self-service printing','成绩单与证明材料','Transcripts and certificates'],
 ['campus-email',3,'校园邮箱','Campus email','学生邮箱服务','Student email services'],
 ['genuine-software',3,'正版软件','Licensed software','学校软件资源','University software resources'],
 ['club-suggestion',3,'学生社团','Student clubs','浏览社团与申请加入','Explore clubs and apply'],
 ['schedule-reminder',3,'日程提醒','Schedule reminders','查看今天和本周安排','Today and this week','calendar']
 ];
 let group=0,query='',day=0,week=0,jumps=0;
 const header=(zh,en,back=false)=>back?`<header class="t-head"><button class="c-back" data-campus-home aria-label="Back">${icon('back')}</button></header>`:'';
 const shell=(head,content)=>`<div class="t-column">${head}<div class="t-panel c-panel">${content}</div><p class="c-preview">${t('交互设计稿 · 未连接校园系统','Interactive prototype · Campus systems are not connected')}</p></div>`;
 function list(){const entries=services.filter(s=>(query||s[1]===group)&&[s[2],s[3],s[4],s[5]].join(' ').toLowerCase().includes(query.toLowerCase()));root.querySelector('.c-services').innerHTML=entries.map(s=>`<button class="c-service" data-service="${s[0]}">${icon(s[6]==='calendar'?'calendar':groups[s[1]][2])}<span><strong>${t(s[2],s[3])}</strong><small>${t(s[4],s[5])}</small></span>${icon('chevron')}</button>`).join('')||`<p class="c-empty">${t('没有找到相关服务','No matching services')}</p>`;}
 function home(){root.innerHTML=shell(header('校园','Campus'),`<section class="c-section"><div class="c-line"><h2>${t('今日日程','Today')}</h2><button class="t-outline" data-service="classtable">${t('查看周历','Weekly view')}</button></div><p class="c-empty">${t('尚未同步课表、考试与实验安排','Classes, exams and labs have not been synced yet')}</p></section><section class="c-section"><h2>${t('校园服务','Campus services')}</h2><label class="c-search">${icon('search')}<input aria-label="Search" placeholder="Search"></label></section><div class="c-tabs" role="tablist">${groups.map((g,i)=>`<button role="tab" aria-selected="${i===group}" data-group="${i}">${t(g[0],g[1])}</button>`).join('')}</div><div class="c-services"></div><section class="c-section c-dino"><span>${t('课间休息 · 离线小游戏','Take a break · Offline mini game')}</span><button data-jump>${t('跳跃','Jump')} <span data-jumps>${jumps}</span></button></section>`);query='';list();root.querySelector('.c-search input').oninput=e=>{query=e.target.value;list();};}
 function calendar(s){const start=new Date(2026,8,14+week*7);const dates=Array.from({length:7},(_,i)=>{const d=new Date(start);d.setDate(d.getDate()+i);return d;});root.innerHTML=shell(header(s[2],s[3],true),`<section class="c-section"><div class="c-line"><button class="c-back" data-week="-1" aria-label="Previous week">${icon('back')}</button><h2>${start.getFullYear()} / ${start.getMonth()+1} / ${start.getDate()}</h2><button class="c-back" data-week="1" aria-label="Next week">${icon('chevron')}</button></div><div class="c-days">${dates.map((d,i)=>`<button data-day="${i}" aria-pressed="${day===i}">${t(['一','二','三','四','五','六','日'][i],['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i])}<span>${d.getDate()}</span></button>`).join('')}</div><div class="c-line"><strong>${dates[day].getMonth()+1} / ${dates[day].getDate()}</strong><span class="c-muted">${t('未同步','Not synced')}</span></div><p class="c-empty">${t('尚无同步日程。此处将显示时间、地点与课程信息。','No synced schedule. Times, locations and course details will appear here.')}</p><p class="c-muted">${t('日期切换为设计预览，不代表真实教务数据。','Date navigation is a design preview, not live academic data.')}</p></section>`);root.querySelectorAll('[data-week]').forEach(b=>b.onclick=()=>{week+=Number(b.dataset.week);calendar(s);});root.querySelectorAll('[data-day]').forEach(b=>b.onclick=()=>{day=Number(b.dataset.day);calendar(s);});}
 function auth(kind){authRoot.innerHTML=`<section class="c-section"><p class="c-muted">${t('两个服务独立认证；设计稿不会提交或保存账号信息。','These services authenticate separately. This prototype does not submit or save credentials.')}</p></section>${['schoolnet','dorm-water'].map(id=>`<section class="c-section"><button class="c-auth" data-auth-kind="${id}">${icon('key')}<span><strong>${id==='schoolnet'?t('校园网自服务','Campus network self-service'):t('宿舍水机','Dorm water dispenser')}</strong><p class="c-muted">${t('未登录','Signed out')}</p></span>${icon('chevron')}</button>${kind===id?`<form class="c-form">${(id==='schoolnet'?[['学号','Student ID'],['查询密码','Query password'],['图形验证码','Image verification code']]:[['手机号','Phone number'],['图形验证码','Image verification code'],['短信验证码','SMS code']]).map(([zh,en],i)=>`<label class="c-field">${t(zh,en)}<input type="${id==='schoolnet'&&i===1?'password':'text'}" autocomplete="off"></label>`).join('')}<p class="c-muted">${t('验证码与登录需连接校园系统后使用。','Verification and sign-in require a campus system connection.')}</p><button type="submit" class="t-outline">${t('登录预览','Preview sign-in')}</button><p class="c-muted" role="status" data-auth-status></p></form>`:''}</section>`).join('')}`;authRoot.querySelectorAll('[data-auth-kind]').forEach(b=>b.onclick=()=>auth(b.dataset.authKind));authRoot.querySelector('form')?.addEventListener('submit',e=>{e.preventDefault();authRoot.querySelector('[data-auth-status]').innerHTML=t('仅展示登录流程，未发起认证。','Preview only. No authentication request was sent.');});}
 function service(s){if(s[6]==='calendar'){calendar(s);return;}if(s[6]==='auth'){document.dispatchEvent(new CustomEvent('reference-route',{detail:'settings'}));loginSettings.open=true;auth(s[0]);return;}root.innerHTML=shell(header(s[2],s[3],true),`<section class="c-section"><h2>${t(s[2],s[3])}</h2><p class="c-muted">${t(s[4],s[5])}</p></section><section class="c-section">${s[6]==='map'?`<a class="c-primary" href="https://gis.xidian.edu.cn/#/home?campus=21047" target="_blank" rel="noopener">${t('打开学校导航','Open university map')}</a>`:`<p>${t('通过学校官方系统办理','Continue in the official university system')}</p><p class="c-muted">${t('此设计稿保留服务入口；正式版使用服务目录返回的操作与链接。','This prototype preserves the service entry. The live app uses actions and links returned by the service catalogue.')}</p>`}</section>`);}
 root.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;if(b.hasAttribute('data-campus-home'))home();if(b.dataset.service)service(services.find(s=>s[0]===b.dataset.service));if(b.hasAttribute('data-group')){group=Number(b.dataset.group);root.querySelectorAll('[data-group]').forEach(x=>x.setAttribute('aria-selected',String(x===b)));list();}if(b.hasAttribute('data-jump')){jumps++;root.querySelector('[data-jumps]').textContent=jumps;b.animate([{transform:'translateY(0)'},{transform:'translateY(-9px)'},{transform:'translateY(0)'}],{duration:260});}});
 const loginSettings=document.createElement('details');
 loginSettings.className='c-login-settings';
 loginSettings.innerHTML=`<summary>${icon('key')}<span>${t('校园系统登录','Campus system sign-in')}</span>${icon('chevron')}</summary><div data-campus-auth-content></div>`;
 document.querySelector('#view-settings .t-settings-content').append(loginSettings);
 const authRoot=loginSettings.querySelector('[data-campus-auth-content]');
 auth();
 home();
})();
