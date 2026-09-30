const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname,'..');
const read = file => fs.readFileSync(path.join(root,file),'utf8');
const plain = value => JSON.parse(JSON.stringify(value));
const flush = () => new Promise(resolve=>setImmediate(resolve));
const deferred = () => { let resolve,reject; const promise = new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject}; };
const copyScope = {};
vm.runInNewContext(read('utils/settings_copy.js').replace('export const','const')+';this.settingsText=settingsText;',copyScope);
const baseProfile = {
  id:'u1',nickname:'Test',alias:'Alias',avatarUrl:'',backgroundImageUrl:'',studentId:'12345678',email:'test@stu.xidian.edu.cn',
  college:'CS',major:'Computing',bio:'',gender:'',verified:true,userLevel:2,userLevelLabel:'Level 2',isLevelOneUser:false,
  levelUpgradeRequest:null,accountCancellationRequest:null,
  allowStrangerDm:true,showContactable:true,notifyComment:true,notifyReply:true,notifyLike:true,notifyFavorite:true,notifyReportResult:true,notifySystem:true
};
function setup(route, overrides={}) {
  let def;
  const storage={token:'account-a',displayMode:'system'};
  const calls={navigation:[],modals:[],writes:[],intervals:[],cleared:[]};
  const wx={
    getStorageSync:key=>storage[key],
    setStorageSync(key,value){storage[key]=value;calls.writes.push([key,plain(value)]);},
    showToast(){},showModal:async options=>{calls.modals.push(options);return {confirm:true};},
    navigateTo:async options=>calls.navigation.push(options),navigateBack:async options=>calls.navigation.push({back:options}),
    switchTab:async options=>calls.navigation.push(options),reLaunch:async options=>calls.navigation.push(options),
    pageScrollTo:options=>calls.navigation.push(options),
    getAccountInfoSync:()=>({miniProgram:{version:'1.2.3',envVersion:'release'}}),
    chooseImage:async()=>({tempFilePaths:['/temp/image.png']}),
    ...overrides.wx
  };
  const scope={
    ...require('./support/motion-context.cjs')(),
    Page:value=>{def=value;},Component:value=>{def=value;},wx,
    getCurrentPages:()=>[{},{}],getApp:()=>({globalData:{navTop:48,navHeight:32,navRight:102}}),
    requireLoginPage:()=>true,
    applyThemeAndLanguage(page){page.setData({currentLanguage:storage.language || 'zh-CN',themeClass:'theme-reference color-mode-light'});},
    getDisplayMode:()=>storage.displayMode,
    setLanguage:value=>wx.setStorageSync('language',value),
    settingsText:copyScope.settingsText,
    avatarInitial:value=>value.slice(0,1),formatTime:value=>value,
    getUserInfo:async()=>({data:plain(baseProfile)}),
    getBlocks:async()=>[{id:'u2',nickname:'Blocked',avatarInitial:'B'}],
    unblockUserGlobally:async()=>({ok:true}),
    updatePrivacy:async()=>({ok:true}),updateNotificationPreferences:async()=>({ok:true}),
    submitCancellationRequest:async()=>({id:'c1',status:'pending'}),
    submitLevelUpgradeRequest:async()=>({id:'l1',status:'pending'}),
    getMyFeedbacks:async()=>[],submitFeedback:async()=>({id:'f1'}),
    fetchAiModels:async()=>({configured:true,model:'qwen-test',models:['qwen-test']}),
    createCampusSchoolnetCaptcha:async()=>({data:{attemptId:'school-1',imageBase64:'abc',imageContentType:'image/png'}}),
    createDormWaterCaptcha:async()=>({data:{sessionId:'water-1',imageBase64:'def',imageContentType:'image/png'}}),
    sendDormWaterSms:async()=>({data:{status:'smsSent'}}),
    loginCampusSchoolnet:async()=>({data:{status:'authenticated'}}),
    loginDormWater:async()=>({data:{status:'authenticated'}}),
    CAMPUS_AUTH_STATE_KEY:'campusAuthStates',
    uploadAvatarImage:async()=>({avatarUrl:'/uploads/avatar.png'}),
    uploadBackgroundImage:async()=>({url:'/uploads/background.png'}),
    updateProfile:async payload=>({ok:true,...baseProfile,...payload}),
    logout:async()=>({ok:true}),clearLocalSession(){calls.cleared.push('session');delete storage.token;},
    setInterval(fn){calls.intervals.push(fn);return calls.intervals.length;},clearInterval(){},
    ...overrides
  };
  scope.wx=wx;
  const source=read(route+'.js').replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm,'');
  vm.runInNewContext(source,scope,{filename:route});
  const page={...def,...def.methods,data:plain(def.data),
    setData(patch,callback){for(const [key,value] of Object.entries(patch)){const parts=key.split('.');let target=this.data;while(parts.length>1){const p=parts.shift();target=target[p];}target[parts[0]]=value;}if(callback)callback();}
  };
  page.data.c=copyScope.settingsText('zh-CN');
  return {page,storage,calls,wx,def};
}
const field=(key,value)=>({currentTarget:{dataset:{key}},detail:{value}});
const tap=(key,value)=>({currentTarget:{dataset:{[key]:value}}});
const profileRoute=name=>'pages/profile/'+name+'/index';

test('consolidated routes remove redundant screens and preserve direct notification entry',()=>{
  const app=JSON.parse(read('app.json'));
  for(const page of ['display-settings','notification-settings']){
    assert.ok(!app.pages.includes(profileRoute(page)));
    assert.ok(!fs.existsSync(path.join(root,profileRoute(page)+'.js')));
  }
  assert.match(read(profileRoute('notifications')+'.js'),/privacy\/index\?section=notifications/);
  assert.doesNotMatch(read(profileRoute('account-security')+'.js'),/handleLogout|auth-center/);
  assert.doesNotMatch(read(profileRoute('about')+'.js'),/checkUpdate|无需更新/);
});

test('theme and language are immediate settings without navigation',()=>{
  const {page,storage,calls}=setup(profileRoute('settings'));
  page.refreshPreferences();
  page.onModeTap(tap('mode','dark'));
  page.onLanguageChange({detail:{value:'1'}});
  assert.equal(storage.displayMode,'dark');
  assert.equal(storage.language,'en');
  assert.equal(page.data.c.settings,'Settings');
  assert.equal(calls.navigation.length,0);
});

test('logout clears local account state only after server success; cancellation keeps session',async()=>{
  const {page,calls,storage}=setup(profileRoute('settings'));
  await page.handleLogout();
  assert.deepEqual(calls.cleared,['session']);
  assert.equal(storage.token,undefined);
  const rejected=setup(profileRoute('settings'),{logout:async()=>{throw Error('offline');}});
  await rejected.page.handleLogout();
  assert.equal(rejected.calls.cleared.length,0);
  assert.ok(rejected.page.data.logoutError);
  const cancelled=setup(profileRoute('settings'),{wx:{showModal:async()=>({confirm:false})}});
  await cancelled.page.handleLogout();
  assert.equal(cancelled.storage.token,'account-a');
});

test('privacy sends only the changed field and independent rapid toggles cannot overwrite each other',async()=>{
  const a=deferred(),b=deferred(),sent=[];
  const {page}=setup(profileRoute('privacy'),{updatePrivacy:payload=>{sent.push(plain(payload));return a.promise;},updateNotificationPreferences:payload=>{sent.push(plain(payload));return b.promise;}});
  page.onShow();await flush();
  const first=page.savePreference('allowStrangerDm',false);
  const second=page.savePreference('notifyLike',false);
  await page.savePreference('allowStrangerDm',true);
  assert.deepEqual(sent,[{allowStrangerDm:false},{notifyLike:false}]);
  b.resolve({});await second;a.resolve({});await first;
  assert.equal(page.data.values.allowStrangerDm,false);
  assert.equal(page.data.values.notifyLike,false);
  assert.equal(page._pending,0);
});

test('failed preference rolls back visibly, retries the intended value, and rejects malformed reads',async()=>{
  let fail=true;
  const {page}=setup(profileRoute('privacy'),{updatePrivacy:async()=>{if(fail)throw Error('offline');}});
  page.onShow();await flush();
  await page.savePreference('showContactable',false);
  assert.equal(page.data.values.showContactable,true);
  assert.ok(page.data.saveErrors.showContactable);
  fail=false;page.retrySave(tap('key','showContactable'));await flush();
  assert.equal(page.data.values.showContactable,false);
  assert.equal(page.data.saveErrors.showContactable,'');
  const malformed=setup(profileRoute('privacy'),{getUserInfo:async()=>({data:{}})});
  await malformed.page.loadProfile();
  assert.ok(malformed.page.data.errorMessage);
  assert.equal(malformed.page.data.loading,false);
});

test('switching account during preference save rejects old results and preserves new pending count',async()=>{
  const pending=deferred(),next=deferred();let count=0;
  const {page,storage}=setup(profileRoute('privacy'),{updatePrivacy:()=>++count===1?pending.promise:next.promise});
  page.onShow();await flush();
  const old=page.savePreference('showContactable',false);
  storage.token='account-b';page.onShow();await flush();
  const current=page.savePreference('allowStrangerDm',false);
  pending.reject(Error('old failure'));await old;
  assert.equal(page._pending,1);
  assert.equal(page.data.values.showContactable,true);
  next.resolve({});await current;assert.equal(page._pending,0);
});

test('notification gear scrolls to unified notification controls exactly once',async()=>{
  const {page,calls}=setup(profileRoute('privacy'));
  page.onLoad({section:'notifications'});page.onShow();await flush();
  assert.equal(calls.navigation[0].selector,'#settings-interactions');
  assert.equal(calls.navigation[0].offsetTop,-92);
  await page.loadProfile();assert.equal(calls.navigation.length,1);
});

test('account upgrade reason is optional and pending requests cannot be duplicated',async()=>{
  const sent=[];
  const {page}=setup(profileRoute('account-security'),{submitLevelUpgradeRequest:async p=>{sent.push(plain(p));return {id:'r1',status:'pending'};}});
  page.onShow();await flush();page.openRequest(tap('type','upgrade'));await page.submitRequest();
  assert.deepEqual(sent,[{reason:''}]);
  assert.equal(page.data.profile.levelUpgradeRequest.status,'pending');
  page.openRequest(tap('type','upgrade'));assert.equal(page.data.formType,'');
});

test('deletion needs confirmation and failed submit keeps optional reason',async()=>{
  const {page,calls}=setup(profileRoute('account-security'),{submitCancellationRequest:async()=>{throw Error('offline');}});
  page.onShow();await flush();page.openRequest(tap('type','cancellation'));page.onReasonInput({detail:{value:'my reason'}});
  await page.submitRequest();assert.equal(calls.modals.length,1);
  assert.equal(page.data.reason,'my reason');assert.ok(page.data.submitError);
  assert.equal(page.data.submitting,false);
});

test('feedback preserves draft on errors and guards edits/double submission while pending',async()=>{
  const pending=deferred();let calls=0;
  const {page}=setup(profileRoute('feedback'),{submitFeedback:()=>{calls++;return pending.promise;}});
  page.onShow();page.onContentInput({detail:{value:'Please improve the timetable'}});
  const submitted=page.submitFeedback();
  page.onContentInput({detail:{value:'lost edit'}});
  await page.submitFeedback();
  assert.equal(calls,1);assert.equal(page.data.content,'Please improve the timetable');
  pending.reject(Error('offline'));await submitted;
  assert.ok(page.data.submitError);assert.equal(page.data.content,'Please improve the timetable');
});

test('successful feedback stays on same page, clears submitted draft and shows records',async()=>{
  const {page,calls}=setup(profileRoute('feedback'));
  page.onShow();page.onContentInput({detail:{value:'Feedback'}});
  await page.submitFeedback();await flush();
  assert.equal(page.data.tab,'records');assert.equal(page.data.submitted,true);
  assert.equal(page.data.content,'');assert.equal(calls.navigation.length,0);
});

test('blocked account removal needs confirmation and errors stay on the affected row',async()=>{
  const pending=deferred();let removed=0;
  const {page}=setup(profileRoute('privacy/blocklist'),{unblockUserGlobally:()=>{removed++;return pending.promise;}});
  await page.loadBlocks();
  const first=page.onUnblockTap(tap('id','u2'));await flush();await page.onUnblockTap(tap('id','u2'));
  assert.equal(removed,1);
  pending.reject(Error('offline'));await first;
  assert.equal(page.data.blocks.length,1);assert.ok(page.data.errors.u2);assert.equal(page.data.pending.u2,false);
});

test('AI failure is explicit and never reuses a stale enabled model',async()=>{
  const {page}=setup(profileRoute('ai-settings'),{fetchAiModels:async()=>{throw Error('offline');}});
  page.setData({configured:true,model:'old'});
  await page.refresh();
  assert.equal(page.data.configured,false);assert.equal(page.data.model,'');assert.ok(page.data.errorMessage);
});

test('late campus captcha cannot cross services or a changed identifier',async()=>{
  const old=deferred();
  const {page}=setup('pages/campus/auth-center/index',{createCampusSchoolnetCaptcha:()=>old.promise});
  page.onShow();await flush();
  const request=page.refreshCaptcha();
  page.switchSystem(tap('system','dormWater'));
  await page.refreshCaptcha();
  old.resolve({data:{attemptId:'old',imageBase64:'stale',imageContentType:'image/png'}});await request;
  assert.equal(page.data.captchaId,'water-1');
  page.switchSystem(tap('system','schoolnet'));
  await page.refreshCaptcha();page.onFieldInput(field('studentId','new-id'));
  assert.equal(page.data.captchaId,'');assert.equal(page.data.captchaSrc,'');
});

test('campus SMS guards double taps, tracks cooldown, and phone edits invalidate sent state',async()=>{
  const pending=deferred();let sent=0;
  const {page}=setup('pages/campus/auth-center/index',{sendDormWaterSms:()=>{sent++;return pending.promise;}});
  page.onLoad({system:'dormWater'});page.onShow();await flush();
  await page.refreshCaptcha();
  page.onFieldInput(field('phone','13800138000'));page.onFieldInput(field('imageCode','1234'));
  const request=page.sendDormWaterCode();
  await page.sendDormWaterCode();assert.equal(sent,1);
  pending.resolve({});await request;
  assert.equal(page.data.smsRemaining,60);assert.equal(page.data.smsSent,true);
  await page.sendDormWaterCode();assert.equal(sent,1);
  page.onFieldInput(field('phone','13900139000'));assert.equal(page.data.smsSent,false);
  page.onUnload();
});

test('campus verification stores only masked history, never passwords or codes',async()=>{
  const submitted=[];
  const {page,calls,storage}=setup('pages/campus/auth-center/index',{loginCampusSchoolnet:async(...args)=>{submitted.push(args);return {data:{status:'authenticated'}};}});
  page.onShow();await flush();await page.refreshCaptcha();
  page.onFieldInput(field('password','secret-password'));page.onFieldInput(field('imageCode','1234'));
  await page.submitAuth();
  assert.equal(submitted.length,1);
  assert.equal(page.data.password,'');assert.equal(page.data.captchaId,'');
  assert.equal(storage.campusAuthStates.schoolnet.studentId,'12****78');
  assert.doesNotMatch(JSON.stringify(calls.writes),/secret-password|1234/);
  page.onUnload();
});

test('changing accounts does not retain campus credentials or accept old identity responses',async()=>{
  const old=deferred();let loads=0;
  const {page,storage}=setup('pages/campus/auth-center/index',{getUserInfo:()=>++loads===1?old.promise:Promise.resolve({data:{studentId:'new-user'}})});
  page.onShow();page.setData({password:'old-secret',phone:'13800138000'});
  storage.token='new-account';page.onShow();await flush();
  old.resolve({data:{studentId:'old-user'}});await flush();
  assert.equal(page.data.studentId,'new-user');assert.equal(page.data.password,'');assert.equal(page.data.phone,'');
});

test('profile fields survive upload/show and saving them never overwrites the saved background',async()=>{
  const patches=[];
  const {page}=setup(profileRoute('edit-profile'),{updateProfile:async payload=>{patches.push(plain(payload));return {ok:true,...baseProfile,...payload};}});
  page.onShow();await flush();
  page.onFieldInput(field('bio','Draft bio'));
  await page.chooseBackground();page.onShow();await flush();
  assert.equal(page.data.form.bio,'Draft bio');
  assert.equal(page.data.backgroundPreview,'/uploads/background.png');
  assert.deepEqual(patches[0],{backgroundImageUrl:'/uploads/background.png'});
  await page.saveProfile();
  assert.equal(patches[1].bio,'Draft bio');assert.ok(!('backgroundImageUrl' in patches[1]));
  assert.equal(page.data.dirty,false);assert.equal(page.data.saved,true);
});

test('profile upload failure keeps the previous media and exposes an error; cancellation is not failure',async()=>{
  const broken=setup(profileRoute('edit-profile'),{updateProfile:async()=>{throw Error('offline');}});
  broken.page.onShow();await flush();
  broken.page.setData({backgroundPreview:'/old.png'});await broken.page.chooseBackground();
  assert.equal(broken.page.data.backgroundPreview,'/old.png');assert.ok(broken.page.data.mediaError);
  const cancel=setup(profileRoute('edit-profile'),{wx:{chooseImage:async()=>{throw {errMsg:'chooseImage:fail cancel'};}}});
  cancel.page.onShow();await flush();await cancel.page.chooseAvatar();
  assert.equal(cancel.page.data.mediaError,'');assert.equal(cancel.page.data.uploadingAvatar,false);
});

test('settings header reserves native controls and asks before discarding a draft',async()=>{
  const {page,calls,def}=setup('components/settings-header/index');
  def.lifetimes.attached.call(page);
  assert.equal(page.data.navRight,102);
  page.setData({confirmLeaveMessage:'Unsaved changes'});
  await page.goBack();
  assert.equal(calls.modals.length,1);assert.equal(calls.navigation.length,1);
  page.setData({busy:true});await page.goBack();assert.equal(calls.navigation.length,1);
});

test('root ignores a late profile response from the previously logged-in account',async()=>{
  const old=deferred();let reads=0;
  const {page,storage}=setup(profileRoute('settings'),{getUserInfo:()=>++reads===1?old.promise:Promise.resolve({data:{...baseProfile,id:'u2',nickname:'Second'}})});
  page.onShow();storage.token='account-b';page.onShow();await flush();
  old.resolve({data:baseProfile});await flush();
  assert.equal(page.data.userInfo.id,'u2');
});

test('a pending logout cannot clear a newer login or navigate to another settings page',async()=>{
  const pending=deferred();
  const {page,storage,calls}=setup(profileRoute('settings'),{logout:()=>pending.promise});
  const request=page.handleLogout();await flush();
  page.navigateTo(tap('url','/pages/profile/about/index'));assert.equal(calls.navigation.length,0);
  storage.token='new-login';pending.resolve({});await request;
  assert.equal(storage.token,'new-login');assert.equal(calls.cleared.length,0);
});

test('campus local-record removal is confirmed once and does not claim a server logout',async()=>{
  const confirmation=deferred();let dialogs=0;
  const {page,storage}=setup('pages/campus/auth-center/index',{wx:{showModal:()=>{dialogs++;return confirmation.promise;}}});
  storage.campusAuthStates={schoolnet:{studentId:'12****78',updatedAt:'test',status:'authenticated'}};
  page.onShow();await flush();
  const request=page.clearCurrentState();await page.clearCurrentState();
  assert.equal(dialogs,1);assert.equal(page.data.clearingRecord,true);
  confirmation.resolve({confirm:true});await request;
  assert.equal(storage.campusAuthStates.schoolnet,undefined);assert.equal(page.data.activeState,null);
  assert.equal(page.data.clearingRecord,false);
});

test('backgrounding campus auth clears secrets but preserves the SMS verification session',()=>{
  const {page}=setup('pages/campus/auth-center/index');
  page.setData({password:'secret',smsCode:'123456',captchaId:'session',smsSent:true,phone:'13800138000'});
  page.onHide();
  assert.equal(page.data.password,'');assert.equal(page.data.smsCode,'');
  assert.equal(page.data.captchaId,'session');assert.equal(page.data.smsSent,true);
});

test('profile adopts server-normalized values and rejects a malformed save response',async()=>{
  const normalized=setup(profileRoute('edit-profile'),{updateProfile:async p=>({ok:true,...p,nickname:'Canonical',college:'计算机学院'})});
  normalized.page.onShow();await flush();normalized.page.onFieldInput(field('nickname','Input'));
  await normalized.page.saveProfile();
  assert.equal(normalized.page.data.form.nickname,'Canonical');assert.equal(normalized.page.data.form.college,'计算机学院');
  const broken=setup(profileRoute('edit-profile'),{updateProfile:async()=>({})});
  broken.page.onShow();await flush();broken.page.onFieldInput(field('bio','Keep my draft'));
  await broken.page.saveProfile();
  assert.equal(broken.page.data.dirty,true);assert.equal(broken.page.data.form.bio,'Keep my draft');assert.ok(broken.page.data.saveError);
});

test('account request history uses the actual review-note field for each request kind',()=>{
  const {page}=setup(profileRoute('account-security'));
  page.setProfile({...baseProfile,levelUpgradeRequest:{id:'l1',status:'rejected',adminNote:'Upgrade note'},accountCancellationRequest:{id:'c1',status:'rejected',reviewNote:'Deletion note'}});
  assert.equal(page.data.requests[0].reviewNote,'Upgrade note');
  assert.equal(page.data.requests[1].reviewNote,'Deletion note');
});

test('leaving a draft can be cancelled and an entry opened without a stack returns home',async()=>{
  const stay=setup('components/settings-header/index',{wx:{showModal:async()=>({confirm:false})}});
  stay.page.setData({confirmLeaveMessage:'Draft'});
  await stay.page.goBack();assert.equal(stay.calls.navigation.length,0);
  const direct=setup('components/settings-header/index',{getCurrentPages:()=>[{}]});
  await direct.page.goBack();assert.equal(direct.calls.navigation[0].url,'/pages/treehole/index');
});
