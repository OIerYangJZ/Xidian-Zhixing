const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
function setup(file,overrides={}) {
 let def,sequence=0;const timers=new Map(),cleared=[];
 const clock={setTimeout(fn){const id=++sequence;timers.set(id,fn);return id;},clearTimeout(id){cleared.push(id);timers.delete(id);}};
 const motion=require('./support/motion-context.cjs')(clock);
 const scope={...motion,...clock,Page:v=>{def=v;},Component:v=>{def=v;},...overrides,wx:{createSelectorQuery:require('./support/selector-query.cjs'),...overrides.wx}};
 if(file)vm.runInNewContext(read(file).replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm,''),scope);
 const host={...def,...def?.methods,data:JSON.parse(JSON.stringify(def?.data||{})),setData:require('./support/set-data.cjs')};
 return {host,def,motion,timers,cleared,flush(){const pending=[...timers.values()];timers.clear();pending.forEach(fn=>fn());}};
}
test('internal pages opt into motion without losing drafts or stacking animations on native transitions',()=>{
 const pages=JSON.parse(read('app.json')).pages;
 for(const page of pages.filter(p=>!p.includes('/webview/'))){
  assert.match(read(page+'.js'),/onShow\([^)]*\)\s*\{\s*enterPage\(this(?:, \{ animate: false \})?\)/,page);
  assert.match(read(page+'.wxml'),/^<view class="{{pageMotion}} /,page);
 }
 const {host,motion}=setup();host.data={draft:'kept',selected:'c1'};
 motion.enterPage(host);assert.equal(host.data.pageMotion,'motion-enter-a');motion.enterPage(host);assert.equal(host.data.pageMotion,'motion-enter-b');
 assert.equal(host.data.draft,'kept');assert.equal(host.data.selected,'c1');
});
test('page motion never transforms a fixed-position ancestor and leaves no persistent animation layer',()=>{
 const css=read('styles/motion.wxss');
 for(const name of ['page-reveal-a','page-reveal-b']){
  const rule=css.match(new RegExp('@keyframes '+name+'[^@]*'))[0];assert.doesNotMatch(rule,/transform|filter|perspective/);
 }
 assert.doesNotMatch(css,/\.motion-enter-[ab]\.motion-enter-[ab][^{]*\{[^}]*both/);
 assert.match(css,/prefers-reduced-motion/);
 assert.match(css,/\.is-leaving \{ opacity:0; \}/);
});
test('exit retains a layer for 200ms then cleans its data once',()=>{
 const {host,motion,flush}=setup();host.data.open=true;let cleanup=0;
 motion.retainLayerExit(host,'open',()=>cleanup++);host.setData({open:false});
 assert.equal(host.data.openLeaving,true);assert.equal(cleanup,0);flush();assert.equal(host.data.openLeaving,false);assert.equal(cleanup,1);
});
test('reopening during exit cancels the old cleanup, even if an old timer fires',()=>{
 const {host,motion,timers,flush}=setup();host.data.open=true;let cleanup=0;
 motion.retainLayerExit(host,'open',()=>cleanup++);const stale=[...timers.values()][0];host.data.open=false;
 motion.cancelLayerExit(host,'open');host.data.open=true;stale();flush();assert.equal(host.data.open,true);assert.equal(host.data.openLeaving,false);assert.equal(cleanup,0);
});
test('page exit cancels pending layer cleanup without detached setData',()=>{
 const {host,motion,timers}=setup();host.data.open=true;motion.retainLayerExit(host,'open');const stale=[...timers.values()][0];motion.clearLayerMotion(host);
 host.setData=()=>assert.fail('detached update');stale();assert.equal(timers.size,0);
});
test('AI cancel preserves the current sheet during fade, reopening shows only the new title',()=>{
 const {host,flush}=setup('pages/ai/index.js');
 host.data.conversations=[{id:'a',title:'First'},{id:'b',title:'Second'}];
 const tap=id=>({currentTarget:{dataset:{id}}});
 host.openConversationMenu(tap('a'));host.beginRenameConversation();host.closeConversationMenu();
 assert.equal(host.data.conversationMenuMode,'rename');assert.equal(host.data.selectedConversationTitle,'First');
 host.openConversationMenu(tap('b'));flush();assert.equal(host.data.conversationMenuOpen,true);assert.equal(host.data.selectedConversationTitle,'Second');
 host.onHide();assert.equal(host.data.conversationMenuOpenLeaving,false);
});
test('AI sidebar close respects the native capsule across phone widths',()=>{
 for(const width of [320,390,430,768]){
  const {host}=setup('pages/ai/index.js',{wx:{getWindowInfo:()=>({windowWidth:width})},getApp:()=>({globalData:{navTop:48,navHeight:32,navRight:102}})});
  host.initCustomNav();assert.ok(Math.min(width*.84,330)-host.data.sidebarCloseRight<=width-102);
 }
});
test('tag detail has deterministic back behavior both from a stack and from a shared entry',()=>{
 for(const count of [1,2]){
  const calls=[];const {host}=setup('pages/campus/tag-posts/index.js',{sharePost(){},getCurrentPages:()=>Array(count).fill({}),wx:{navigateBack:()=>calls.push('back'),switchTab:()=>calls.push('home')}});
  host.goBack();assert.deepEqual(calls,[count===1?'home':'back']);
 }
});
test('drawer ignores an async response after it closes',async()=>{
 let resolve;const profile=new Promise(r=>{resolve=r;});
 const {host,def}=setup('components/radio-drawer/index.js',{getLanguage:()=> 'zh',avatarInitial:v=>v.slice(0,1),getUserInfo:()=>profile,getConversations:async()=>[],getCurrentPages:()=>[],wx:{}});
 host.data.open=true;const pending=host.loadDrawerData();host.data.open=false;def.observers.open.call(host,false);resolve({data:{nickname:'Old'}});await pending;assert.equal(host.data.profile,null);
});
test('drawer has no close icon and a deliberate left swipe closes without intercepting vertical scrolling',()=>{
 let event;
 const {host,def}=setup('components/radio-drawer/index.js',{getApp:()=>({globalData:{navTop:48,navHeight:32}})});
 def.lifetimes.attached.call(host);
 assert.equal(host.data.navTop,48);assert.equal(host.data.navHeight,32);
 host.triggerEvent=value=>{event=value;};host.close();assert.equal(event,'close');
 const template=read('components/radio-drawer/index.wxml');
 assert.match(template,/<scroll-view class="drawer-scroll"/);
 assert.doesNotMatch(template,/closeRight|drawer-safe|drawer-close/);
 const css=read('components/radio-drawer/index.wxss');
 assert.match(css,/\.drawer-scroll \{[^}]*flex:1; min-height:0;/);
 event=null;host.onPanelTouchStart({touches:[{clientX:200,clientY:160}]});host.onPanelTouchEnd({changedTouches:[{clientX:190,clientY:300}]});assert.equal(event,null);
 host.onPanelTouchStart({touches:[{clientX:200,clientY:160}]});host.onPanelTouchEnd({changedTouches:[{clientX:100,clientY:170}]});assert.equal(event,'close');
});
test('AI cancel and confirmation labels have explicit two-axis centering',()=>{
 const css=read('pages/ai/index.wxss');
 assert.match(css,/\.ai-menu-cancel, \.ai-menu-buttons button \{[^}]*display:flex; align-items:center; justify-content:center;/);
 assert.match(read('pages/ai/index.wxml'),/class="ai-menu-cancel"[^>]*><text>取消<\/text>/);
});
test('root tabs and native chat navigation do not replay whole-page fades or move fixed composers',()=>{
 const {host,motion}=setup();let writes=0;host.setData=()=>writes++;
 motion.enterPage(host,{animate:false});motion.enterPage(host,{animate:false});assert.equal(writes,0);
 for(const route of ['treehole','campus','ai','profile/notifications','profile/conversations','profile/chat']){
  assert.match(read('pages/'+route+'/index.js'),/enterPage\(this, \{ animate: false \}\)/);
 }
});
test('filter selection and directional content motion are committed together, with repeat taps ignored',()=>{
 const {host}=setup('pages/profile/notifications/index.js');
 host.data.items=[{id:'a',type:'like'},{id:'b',type:'reply'}];const updates=[];
 host.setData=function(update){updates.push(update);Object.assign(this.data,update);};
 const tap=filter=>({currentTarget:{dataset:{filter}}});host.switchFilter(tap('replies'));
 assert.equal(updates.length,1);assert.equal(updates[0].activeFilter,'replies');assert.equal(host.data.displayedItems.length,1);assert.match(host.data.contentMotion,/motion-panel-next/);
 host.switchFilter(tap('replies'));assert.equal(updates.length,1);
 host.switchFilter(tap('all'));assert.equal(updates.length,2);assert.equal(host.data.displayedItems.length,2);assert.match(host.data.contentMotion,/motion-panel-previous/);
});
test('campus keeps both panels mounted and does not reload services during local tab switches',()=>{
 const {host}=setup('pages/campus/index.js',{CAMPUS_GROUPS:[]});
 host.setData=function(update,callback){Object.assign(this.data,update);if(callback)callback();};
 host.switchView({currentTarget:{dataset:{view:'services'}}});assert.equal(host.data.activeView,'services');assert.match(host.data.contentMotion,/motion-panel-next/);assert.equal(host.data.scrollAnchor,'workbench-top');
 const template=read('pages/campus/index.wxml');assert.match(template,/hidden="{{activeView !== 'today'}}"/);assert.match(template,/hidden="{{activeView !== 'services'}}"/);
});
test('latest feed starts while another tab is loading, and stale responses cannot overwrite selection',async()=>{
 const requests=[];const {host}=setup('pages/treehole/index.js',{sharePost(){},getPostsPage:params=>new Promise(resolve=>requests.push({params,resolve})),attachDisplayImages:post=>post});
 host.hydrateFeedImages=async()=>{};
 const first=host.fetchPosts();assert.equal(requests.length,1);
 host.onHomeTabTap({currentTarget:{dataset:{tab:'latest'}}});assert.equal(requests.length,2);assert.equal(requests[1].params.sort,'latest');
 requests[1].resolve({items:[{id:'latest'}],page:1,total:1,hasMore:false});await new Promise(setImmediate);
 requests[0].resolve({items:[{id:'old'}],page:1,total:1,hasMore:false});await first;
 assert.equal(host.data.activeHomeTab,'latest');assert.equal(host.getFeed().posts[0].id,'latest');assert.equal(host.getFeed().loading,false);
 assert.equal(host.getFeed('hot').posts[0].id,'old');
 host.onHomeTabTap({currentTarget:{dataset:{tab:'latest'}}});assert.equal(requests.length,2);
});
test('home touch tracking does not trigger a render on every tap',()=>{
 const {host}=setup('pages/treehole/index.js',{sharePost(){}});let writes=0;host.setData=()=>writes++;
 host.onTouchStart({touches:[{clientX:180,clientY:50}]});host.onTouchEnd({changedTouches:[{clientX:180,clientY:50}]});assert.equal(writes,0);
});
test('club and organization tabs are blank placeholders with no post requests or publishing controls',async()=>{
 let requests=0,stopped=0;
 const {host}=setup('pages/treehole/index.js',{sharePost(){},getPostsPage:()=>{requests++;},wx:{stopPullDownRefresh:()=>stopped++}});
 const tap=tab=>({currentTarget:{dataset:{tab}}});
 for(const [tab,index] of [['clubs',3],['organizations',4]]){
  host.setFeedState('hot',{posts:[{id:'old'}],errorMessage:'old error'});host.onHomeTabTap(tap(tab));
  assert.equal(host.data.activeHomeTabIndex,index);assert.equal(Object.hasOwn(host.data,'homeTabScrollTarget'),false);
  assert.equal(host.getFeed().posts.length,0);assert.equal(host.getFeed().loading,false);assert.equal(host.getFeed().errorMessage,'');
  assert.equal(host.getFeed().hasMore,false);assert.equal(host.data.showPublishButton,false);assert.equal(host.data.showBackToTop,false);
  await host.onReachBottom();await host.refreshFeed({stopPageRefresh:true});await host.retryFeed();
  host.selectCollege({currentTarget:{dataset:{college:{id:'cs'}}}});
  assert.equal(requests,0);assert.equal(host.getFeed().activeCollege,null);
  host.onScroll({currentTarget:{dataset:{tab}},detail:{scrollTop:0}});assert.equal(host.data.showPublishButton,false);
 }
 assert.equal(stopped,2);const motion=host.data.contentMotion;host.onHomeTabTap(tap('organizations'));assert.equal(host.data.contentMotion,motion);
});
test('a post response arriving after entering a placeholder cannot fill it',async()=>{
 let resolve;const {host}=setup('pages/treehole/index.js',{sharePost(){},getPostsPage:()=>new Promise(r=>{resolve=r;}),attachDisplayImages:post=>post});
 host.hydrateFeedImages=async()=>{};const pending=host.fetchPosts();
 host.onHomeTabTap({currentTarget:{dataset:{tab:'clubs'}}});resolve({items:[{id:'late'}],page:1,total:1,hasMore:false});await pending;
 assert.equal(host.data.activeHomeTab,'clubs');assert.equal(host.getFeed().posts.length,0);assert.equal(host.getFeed().loading,false);
 assert.equal(host.getFeed('hot').posts[0].id,'late');
});
test('returning from an empty tab loads the requested feed and animates in the correct direction',async()=>{
 const requests=[];const {host}=setup('pages/treehole/index.js',{sharePost(){},getPostsPage:async params=>{requests.push(params);return {items:[],page:1,total:0,hasMore:false};},attachDisplayImages:post=>post});
 host.hydrateFeedImages=async()=>{};const tap=tab=>({currentTarget:{dataset:{tab}}});
 host.onHomeTabTap(tap('organizations'));host.onHomeTabTap(tap('latest'));await new Promise(setImmediate);
 assert.equal(requests.length,1);assert.equal(requests[0].sort,'latest');assert.equal(host.data.activeHomeTabIndex,2);
 assert.equal(host.data.showPublishButton,true);assert.equal(host.getFeed().loading,false);
 host.onHomeTabTap(tap('clubs'));host.onHomeTabTap(tap('colleges'));assert.equal(requests.length,1);assert.equal(host.data.activeHomeTabIndex,1);
});
test('home uses a persistent native pager without adding a second content animation or switching timer',()=>{
 const {host,timers}=setup('pages/treehole/index.js',{sharePost(){}});
 host.onHomeTabTap({currentTarget:{dataset:{tab:'clubs'}}});assert.equal(timers.size,0);
 assert.match(read('pages/treehole/index.wxml'),/<swiper id="home-pager"[^>]*current="{{activeHomeTabIndex}}" duration="420"/);
 assert.doesNotMatch(read('pages/treehole/index.wxml'),/motion-content|contentMotion/);
 assert.match(read('styles/section-tabs.wxss'),/\.42s cubic-bezier\(\.22,\.68,\.24,1\)/);
 assert.match(read('styles/motion.wxss'),/panel-next-a \.36s cubic-bezier\(\.22,\.68,\.24,1\)/);
});
test('chat first load scrolls after rendering without a timer or entrance scroll animation',async()=>{
 const calls=[];const {host,timers}=setup('pages/profile/chat/index.js',{getConversationMessages:async()=>[{id:'m1',createdAt:'2026-09-27T10:00:00Z',content:'Hello',fromMe:false}],wx:{pageScrollTo:args=>calls.push(args)}});
 host.data.conversationId='c1';await host.loadMessages();assert.equal(host.data.loading,false);assert.equal(calls.length,1);assert.equal(calls[0].duration,0);assert.equal(calls[0].selector,'#bottom-anchor');assert.equal(timers.size,0);
 host.scrollToBottom();assert.equal(calls[1].duration,160);
 host.onHide();host.scrollToBottom();assert.equal(calls.length,2);
});
test('chat ignores a load response after unloading',async()=>{
 let resolve;const {host}=setup('pages/profile/chat/index.js',{getConversationMessages:()=>new Promise(r=>{resolve=r;}),wx:{pageScrollTo:()=>assert.fail('scroll after unload')}});
 host.data.conversationId='c1';const pending=host.loadMessages();host.onUnload();resolve([{id:'late'}]);await pending;assert.equal(host.data.messages.length,0);
});
test('rapid conversation taps open only one chat, and a failed navigation can retry',()=>{
 const calls=[];const {host}=setup('pages/profile/conversations/index.js',{wx:{navigateTo:args=>calls.push(args)}});
 host.data.conversations=[{id:'c1',name:'Peer'}];const tap={currentTarget:{dataset:{index:0}}};host.openChat(tap);host.openChat(tap);assert.equal(calls.length,1);calls[0].fail();host.openChat(tap);assert.equal(calls.length,2);
});
test('inboxes preserve loaded empty/list states during refresh but never carry them to another account',async()=>{
 for(const route of ['notifications','conversations']){
  let token='a';const pending=[];const get=()=>new Promise(resolve=>pending.push(resolve));
  const {host}=setup('pages/profile/'+route+'/index.js',{requireLoginPage:()=>true,resolveUrl:x=>x,formatTime:x=>x,getNotifications:get,getConversations:get,wx:{getStorageSync:()=>token}});
  const result=id=>route==='notifications'?{items:id?[{id,type:'reply'}]:[],unreadCount:0}:id?[{id,name:'Peer'}]:[];
  const list=()=>route==='notifications'?host.data.items:host.data.conversations;
  let p=host.loadData();pending.shift()(result());await p;
  p=host.loadData();assert.equal(host.data.loading,false);pending.shift()(result('a'));await p;assert.equal(list()[0].id,'a');
  const old=host.loadData();assert.equal(host.data.loading,false);assert.equal(list()[0].id,'a');
  token='b';p=host.loadData();assert.equal(host.data.loading,true);assert.equal(list().length,0);
  pending.shift()(result('old'));await old;assert.equal(list().length,0);pending.shift()(result('b'));await p;assert.equal(list()[0].id,'b');
 }
});
test('same-account inbox refresh responses cannot arrive out of order',async()=>{
 for(const route of ['notifications','conversations']){
  const pending=[];const get=()=>new Promise(resolve=>pending.push(resolve));
  const {host}=setup('pages/profile/'+route+'/index.js',{requireLoginPage:()=>true,resolveUrl:x=>x,formatTime:x=>x,getNotifications:get,getConversations:get,wx:{getStorageSync:()=> 'account'}});
  const result=id=>route==='notifications'?{items:[{id,type:'reply'}],unreadCount:0}:[{id,name:'Peer'}];
  const old=host.loadData(),recent=host.loadData();pending[1](result('recent'));await recent;pending[0](result('old'));await old;
  assert.equal((route==='notifications'?host.data.items:host.data.conversations)[0].id,'recent');
 }
});
test('theme synchronization does not resend identical translations on every tab show',()=>{
 let mode='light',lang='zh-CN',writes=0,translations=0;
 const scope={getLanguage:()=>lang,getTranslation:()=>{translations++;return {label:lang};},wx:{getStorageSync:()=>mode,setNavigationBarColor(){},setBackgroundColor(){}}};
 vm.runInNewContext(read('utils/theme_i18n.js').replace(/^import[^\n]*\n/,'').replace(/^export /gm,'')+';this.apply=applyThemeAndLanguage;',scope);
 const page={data:{},setData(update){writes++;Object.assign(this.data,update);}};
 scope.apply(page);scope.apply(page);assert.equal(writes,1);assert.equal(translations,1);
 mode='dark';scope.apply(page);assert.equal(writes,2);assert.equal(translations,1);assert.equal(page.data.resolvedDisplayMode,'dark');
 lang='en';scope.apply(page);assert.equal(writes,3);assert.equal(translations,2);assert.equal(page.data.t.label,'en');
});
test('forward picker ignores requests after leaving and prevents duplicate sends',async()=>{
 let resolve,sent=0;let pending=new Promise(r=>{resolve=r;});
 const {host}=setup('pages/profile/chat/index.js',{avatarInitial:v=>v.slice(0,1),getConversations:()=>pending,sendConversationMessage:()=>{sent++;return pending;},wx:{showToast(){}}});
 const opening=host.openForwardPicker({content:'hello'});host.onHide();resolve([{id:'b',name:'Peer'}]);await opening;assert.equal(host.data.showForwardPicker,false);
 pending=new Promise(r=>{resolve=r;});host.data.forwardTargets=[{id:'b'}];host._forwardMessage={content:'hello'};host.data.showForwardPicker=true;
 const tap={currentTarget:{dataset:{index:0}}};const first=host.chooseForwardTarget(tap);await host.chooseForwardTarget(tap);assert.equal(sent,1);resolve({});await first;assert.equal(host.data.showForwardPicker,false);
});
test('timetable opens complete course details without shortening names or locations',()=>{
 let modal;const {host}=setup('pages/campus/service-detail/index.js',{wx:{showModal:options=>{modal=options;}}});
 host.data.calendarGrid={blocks:[{title:'Long course name',date:'2026-09-27',startTime:'08:30',endTime:'10:05',location:'Building C room 302',teacher:'Teacher'}]};
 host.showScheduleItem({currentTarget:{dataset:{index:0}}});assert.equal(modal.title,'Long course name');assert.match(modal.content,/2026-09-27\n08:30 - 10:05\nBuilding C room 302\nTeacher/);assert.equal(modal.showCancel,false);
});
test('composer handles direct entry and does not stack discard dialogs or leave during publishing',()=>{
 const calls=[];let modal;const {host}=setup('pages/campus/create-post/index.js',{getCurrentPages:()=>[{}],wx:{switchTab:args=>calls.push(args.url),showModal:args=>{modal=args;calls.push('confirm');}}});
 host.confirmDiscard();assert.deepEqual(calls,['/pages/treehole/index']);host.data.content='Draft';host.confirmDiscard();host.confirmDiscard();assert.equal(calls.filter(x=>x==='confirm').length,1);modal.success({confirm:false});modal.complete();assert.equal(host.data.content,'Draft');host.data.isPublishing=true;host.confirmDiscard();assert.equal(calls.length,2);
});
