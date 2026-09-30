const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const strip = source => source.replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '').replace(/^export /gm, '');
const helperSource = read('utils/campus_workbench.js');
const exportedNames = [...helperSource.matchAll(/export const (\w+)/g)].map(match => match[1]);
const helpers = { baseUrl: 'http://127.0.0.1:18080' };
vm.runInNewContext(strip(helperSource) + ';Object.assign(this, {' + exportedNames.join(',') + '});', helpers);
function page(mocks = {}) {
  let definition;
  vm.runInNewContext(strip(read('pages/campus/index.js')), {
    ...require('./support/motion-context.cjs')(mocks),
    ...helpers, Page: value => { definition = value; },
    requireLoginPage: () => true, avatarInitial: value => value.slice(0, 1), ...mocks
  });
  return { ...definition, data: JSON.parse(JSON.stringify(definition.data)), setData(update, callback) { Object.assign(this.data, update); if (callback) callback(); } };
}
const services = [
  {id:'course',slug:'classtable',name:'课表',kind:'schedule',groupId:'study',actions:[{type:'calendar'}]},
  {id:'score',slug:'score',name:'成绩单',groupId:'study',actions:[{type:'external',url:'https://ehall.xidian.edu.cn/new/index.html'}]},
  {id:'pay',slug:'electricity',name:'宿舍电费',groupId:'life',actions:[{type:'external',url:'https://pay.xidian.edu.cn/'}]},
  {id:'old',slug:'space',name:'空间预约',groupId:'life',actions:[{type:'external',url:'http://libspace.xidian.edu.cn/'}]},
  {id:'placeholder',slug:'sport',name:'体育信息',groupId:'study',actions:[{type:'notice'}]}
];
test('campus layout overrides native button width and uses separate equal-width slots', () => {
  const css = read('pages/campus/index.wxss');
  const markup = read('pages/campus/index.wxml');
  assert.match(css, /\.campus-page button \{[^}]*min-width:0;[^}]*margin:0 !important/);
  for (const selector of ['week-day','shortcut','editor-service','all-services-link']) {
    assert.match(css, new RegExp('\\.' + selector + ' \\{[^}]*width:100% !important'));
  }
  for (const selector of ['campus-customize-button','search-clear','editor-close','order-button','reset-button']) {
    assert.match(css, new RegExp('\\.' + selector + ' \\{[^}]*width:\\d+px !important'));
  }
  assert.match(css, /\.heading-action, \.section-icon-button \{[^}]*flex:0 0 40px;[^}]*width:40px !important/);
  assert.match(css, /\.week-slot \{[^}]*flex:1 1 0%;[^}]*min-width:0/);
  assert.match(css, /\.shortcut-slot \{[^}]*flex:0 0 25%/);
  assert.match(css, /\.shortcut \{[^}]*height:100px/);
  assert.match(css, /\.shortcut-name \{[^}]*-webkit-line-clamp:2;[^}]*max-height:34px;[^}]*overflow:hidden/);
  assert.match(css, /\.editor-service-slot \{[^}]*flex:0 0 50%/);
  assert.match(css, /\.workbench-tab \{[^}]*width:0 !important/);
  assert.match(css, /\.save-layout \{[^}]*width:0 !important/);
  assert.match(css, /\.text-command \{[^}]*width:auto !important/);
  assert.match(css, /\.category \{[^}]*width:auto !important/);
  assert.match(markup, /class="week-slot">\s*<button[^>]*data-date="{{item.date}}"[^>]*bindtap="selectDay"/);
  assert.match(markup, /class="shortcut-slot"><button[^>]*data-id="{{item.id}}"[^>]*bindtap="openService"/);
  assert.match(markup, /class="editor-service-slot"><button[^>]*data-id="{{item.id}}"[^>]*bindtap="toggleShortcut"/);
  assert.match(css, /\.empty-schedule \{ display:flex; align-items:center/);
  assert.match(css, /\.week-day\.selected \{ background:var\(--app-accent-soft\)/);
});
test('service catalog distinguishes native, official web, browser-only and unavailable entries', () => {
  const rows = helpers.prepareCampusServices(services);
  assert.equal(rows[0].isSchedule, true);
  assert.equal(rows[1].modeLabel, '学校服务');
  assert.equal(rows[3].modeLabel, '浏览器打开');
  assert.equal(rows[4].modeLabel, '暂未接入');
  assert.equal(rows[4].usable, false);
  assert.equal(helpers.filterCampusServices(rows, 'life', '电费').length, 1);
  assert.equal(helpers.filterCampusServices(rows, 'study', '电费').length, 0);
});
test('campus URL safety retains HTTPS school restrictions and rejects deceptive hosts', () => {
  for (const url of ['https://xidian.edu.cn','https://a.xidian.edu.cn/path','http://127.0.0.1:18080/auth']) assert.equal(helpers.canOpenCampusUrl(url), true);
  for (const url of ['http://xidian.edu.cn','https://xidian.edu.cn.evil.test','https://evil.test@xidian.edu.cn','javascript:alert(1)','https://evil.test']) assert.equal(helpers.canOpenCampusUrl(url), false);
});
test('saved shortcut order is stable, missing IDs are removed, and an empty list stays empty', () => {
  const rows = helpers.prepareCampusServices(services);
  const prefs = helpers.readCampusPreferences({shortcutIds:['pay','score','pay','gone'],compact:true,showSchedule:false}, rows);
  assert.equal(JSON.stringify(prefs.shortcutIds), JSON.stringify(['pay','score']));
  assert.equal(prefs.compact, true);
  assert.equal(prefs.showSchedule, false);
  assert.equal(helpers.readCampusPreferences({shortcutIds:[]}, rows).shortcutIds.length, 0);
  assert.equal(helpers.readCampusPreferences(null, rows).shortcutIds.includes('placeholder'), false);
});
test('school clock and event progress remain correct independently of host timezone', () => {
  const clock = helpers.schoolClock(Date.parse('2026-09-26T16:30:00Z'));
  assert.equal(clock.date, '2026-09-27');
  assert.equal(clock.minutes, 30);
  const model = helpers.buildCampusDay([
    {id:'later',source:'examSchedules',startTime:'13:00',endTime:'14:00'},
    {id:'now',source:'courseSchedules',startTime:'09:00',endTime:'10:00'},
    {id:'ended',source:'experimentSchedules',startTime:'08:00',endTime:'09:00'}
  ], '2026-09-27', {date:'2026-09-27',minutes:570});
  assert.equal(model.focus.id, 'now');
  assert.equal(model.focus.progress, 50);
  assert.equal(model.focusLabel, '正在进行');
  assert.equal(model.rows[0].ended, true);
  assert.equal(model.rows[2].tone, 'exam');
  assert.equal(helpers.buildCampusDay([], '2026-09-27', clock).focus, null);
});
test('a failed schedule request does not disable the successful services module', async () => {
  const p = page({
    getCampusServices: async () => ({data:services}),
    getCalendarSchedules: async () => { throw new Error('日历失败'); },
    getUserInfo: async () => ({data:{id:'u1',nickname:'同学'}}),
    wx: {getStorageSync: () => null}
  });
  await p.loadData();
  assert.equal(p.data.services.length, services.length);
  assert.equal(p.data.serviceError, '');
  assert.equal(p.data.scheduleError, '日历失败');
  assert.equal(p.data.loading, false);
  assert.equal(p._loadPromise, null);
});
test('one calendar request supplies the date strip and the selected day timeline', async () => {
  const date = helpers.schoolClock().date;
  const queries = [];
  const p = page({
    getCampusServices: async () => ({data:services}),
    getCalendarSchedules: async query => {queries.push(query); return {data:{days:[{date,items:[{id:'c1',title:'课程',startTime:'09:00',endTime:'10:00',source:'courseSchedules'}]}]}};},
    getUserInfo: async () => ({data:{id:'u1'}}), wx: {getStorageSync: () => null}
  });
  await p.loadData();
  assert.equal(p.data.scheduleError, '');
  assert.equal(p.data.scheduleCount, 1);
  assert.equal(queries.length, 1);
  assert.equal(queries[0].startDate, date);
  assert.equal(queries[0].source, 'all');
  assert.equal(queries[0].days, 7);
  assert.equal(p.data.weekDays[0].count, 1);
});
test('custom layout edits are transactional, ordered and scoped to the account', () => {
  const stored = {}, hidden = [];
  const p = page({wx:{getStorageSync:key => stored[key],setStorageSync:(key,value) => {stored[key]=value;},showToast(){},hideKeyboard(){}}});
  p._preferenceKey = 'campusWorkbench:u1';
  p.getTabBar = () => ({setData:value => hidden.push(value.modalHidden)});
  p.setData({services:helpers.prepareCampusServices(services)});
  p.restorePreferences();
  p.openCustomizer();
  p.toggleShortcut({currentTarget:{dataset:{id:'pay'}}});
  p.closeCustomizer();
  assert.ok(p.data.shortcutIds.includes('pay'));
  assert.equal(Object.keys(stored).length, 0);
  p.openCustomizer();
  p.moveShortcut({currentTarget:{dataset:{index:2,direction:-1}}});
  p.toggleScheduleDisplay({detail:{value:false}});
  p.saveLayout();
  assert.equal(stored['campusWorkbench:u1'].shortcutIds[1], 'pay');
  assert.equal(stored['campusWorkbench:u1'].showSchedule, false);
  assert.equal(p.data.customizing, false);
  assert.equal(hidden.at(-1), false);
  p._preferenceKey = 'campusWorkbench:u2';
  p.restorePreferences();
  assert.equal(p.data.showSchedule, true);
});
test('shortcut limit is enforced and refresh cleanup runs after failure', async () => {
  let notice = '';
  const p = page({wx:{showToast:args => {notice=args.title;}}});
  p.setData({services:Array.from({length:9},(_,i)=>({id:'s'+i,usable:true})),draftShortcutIds:Array.from({length:8},(_,i)=>'s'+i)});
  p.toggleShortcut({currentTarget:{dataset:{id:'s8'}}});
  assert.equal(p.data.draftShortcutIds.length, 8);
  assert.match(notice, /8/);
  p.loadData = async () => {throw new Error('failed');};
  await assert.rejects(p.refreshData(), /failed/);
  assert.equal(p.data.refreshing, false);
});
test('native and official service routing removes intermediate generic detail pages', () => {
  const navigations = [], webTargets = [], modals = [];
  const p = page({
    openAppTarget: target => {webTargets.push(target);return true;},
    wx:{navigateTo:args=>navigations.push(args.url),showModal:args=>modals.push(args)}
  });
  p.setData({services:helpers.prepareCampusServices(services),selectedDate:'2026-09-26'});
  const event = id => ({currentTarget:{dataset:{id}}});
  p.openService(event('score'));
  assert.equal(navigations.length, 0);
  assert.equal(webTargets[0].url, services[1].actions[0].url);
  p.openService(event('course'));
  assert.match(navigations[0], /service-detail\/index\?id=course/);
  assert.match(navigations[0], /startDate=2026-09-26/);
  p.openService(event('old'));
  assert.equal(modals[0].confirmText, '复制链接');
  p.openService(event('placeholder'));
  assert.equal(modals[1].showCancel, false);
});

test('changing accounts clears the old agenda and rejects an in-flight old account response', async () => {
  let token = 'one', resolveFirst, count = 0;
  const date = helpers.schoolClock().date;
  const p = page({
    wx:{getStorageSync:key=>key==='token'?token:null},
    getCampusServices:async()=>({data:services}),
    getUserInfo:async()=>({data:{id:token}}),
    getCalendarSchedules:()=>++count===1?new Promise(resolve=>{resolveFirst=resolve;}):Promise.resolve({data:{days:[{date,items:[]}]}})
  });
  p.syncAccount();
  p.setData({weekDays:[{date,items:[{id:'old'}]}],userInfo:{id:'one'}});
  const first = p.loadData();
  token = 'two';
  p.syncAccount();
  assert.equal(p.data.userInfo, null);
  assert.equal(p.data.weekDays.length, 0);
  await p.loadData();
  assert.equal(p._preferenceKey, 'campusWorkbench:two');
  resolveFirst({data:{days:[{date,items:[{id:'old',startTime:'09:00',endTime:'10:00'}]}]}});
  await first;
  assert.equal(p.data.userInfo.id, 'two');
  assert.equal(p.data.scheduleCount, 0);
});

test('profile failure disables layout saving explicitly and does not reuse an old account key', async () => {
  const notices = [];
  const p = page({
    wx:{getStorageSync:()=>null,showToast:args=>notices.push(args.title)},
    getCampusServices:async()=>({data:services}),
    getUserInfo:async()=>{throw new Error('账户失败');},
    getCalendarSchedules:async()=>({data:{days:[]}})
  });
  p._preferenceKey = 'campusWorkbench:old';
  await p.loadData();
  assert.equal(p._preferenceKey, null);
  assert.equal(p.data.profileError, '账户失败');
  p.saveLayout();
  assert.equal(notices.length, 1);
});

test('invalid event times never produce progress or a false all-finished state', () => {
  const model=helpers.buildCampusDay([{id:'missing',startTime:'25:80',endTime:''}], '2026-09-26', {date:'2026-09-26',minutes:600});
  assert.equal(model.focus.current, false);
  assert.equal(model.focus.progress, 0);
  assert.equal(model.focusLabel, '今日安排');
});

test('native timetable opens the selected date week, while exam lists keep the selected date', async () => {
  for (const slug of ['classtable','exam']) {
    let definition, query;
    vm.runInNewContext(strip(read('pages/campus/service-detail/index.js')), {
      Page:value=>{definition=value;},
      getCampusServiceDetail:async()=>({data:{id:slug,slug,name:'日程',kind:'schedule',calendarSource:slug==='exam'?'examSchedules':'academic'}}),
      getCalendarSchedules:async params=>{query=params;return {data:{startDate:params.startDate,days:[]}};}
    });
    const p={...definition,data:JSON.parse(JSON.stringify(definition.data)),setData(update){Object.assign(this.data,update);}};
    p.data.selectedWeekStartDate='2026-09-26';
    await p.loadData();
    assert.equal(query.startDate, slug==='exam'?'2026-09-26':'2026-09-21');
    assert.equal(query.days, slug==='exam'?31:7);
    assert.equal(p.data.errorMessage, '');
  }
});

test('campus navigation uses root tab routing and preserves legacy search page query parameters', () => {
  const calls=[];
  let navigate;
  vm.runInNewContext(strip(read('utils/navigation.js'))+';this.navigate=openAppTarget;', {wx:{switchTab:args=>calls.push(['tab',args.url]),navigateTo:args=>calls.push(['page',args.url])},set navigate(value){navigate=value;}});
  navigate({path:'/pages/campus/index'});
  navigate({path:'/pages/campus/search/index?keyword=test'});
  assert.deepEqual(calls,[['tab','/pages/campus/index'],['page','/pages/campus/search/index?keyword=test']]);
});

test('malformed module data is reported rather than leaving the workbench stuck loading', async () => {
  const p=page({
    wx:{getStorageSync:()=>null},
    getCampusServices:async()=>({data:{wrong:'shape'}}),
    getCalendarSchedules:async()=>({data:{days:[{date:'2026-09-26',items:null}]}}),
    getUserInfo:async()=>({data:{id:'u1'}})
  });
  await p.loadData();
  assert.ok(p.data.serviceError);
  assert.equal(p.data.scheduleError, '日程响应格式无效');
  assert.equal(p.data.loading, false);
});

test('week reload reports failure and ignores an older response after a newer week is selected', async () => {
  let definition, resolveFirst, calls=0;
  vm.runInNewContext(strip(read('pages/campus/service-detail/index.js')), {
    Page:value=>{definition=value;},
    getCalendarSchedules:params=>++calls===1?new Promise(resolve=>{resolveFirst=resolve;}):Promise.resolve({data:{startDate:params.startDate,days:[]}})
  });
  const p={...definition,data:JSON.parse(JSON.stringify(definition.data)),setData(update){Object.assign(this.data,update);}};
  p.setData({service:{kind:'schedule',calendarSource:'academic'},selectedWeekStartDate:'2026-09-21'});
  const first=p.reloadCalendar();
  p.data.selectedWeekStartDate='2026-09-28';
  await p.reloadCalendar();
  resolveFirst({data:{startDate:'2026-09-21',days:[]}});
  await first;
  assert.equal(p.data.calendar.startDate,'2026-09-28');
  assert.equal(p.data.loading,false);
  let failureDefinition;
  vm.runInNewContext(strip(read('pages/campus/service-detail/index.js')), {
    Page:value=>{failureDefinition=value;},getCalendarSchedules:async()=>{throw new Error('周历请求失败');}
  });
  const failed={...failureDefinition,data:{service:{kind:'schedule'}},setData(update){Object.assign(this.data,update);}};
  await failed.reloadCalendar();
  assert.equal(failed.data.errorMessage,'周历请求失败');
  assert.equal(failed.data.loading,false);
  assert.doesNotMatch(read('pages/campus/service-detail/index.wxml'), /class="schedule-nav" wx:if/);
});
