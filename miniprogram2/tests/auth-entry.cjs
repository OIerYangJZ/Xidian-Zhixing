const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const defer = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return {promise, resolve, reject}; };
const tick = () => new Promise(setImmediate);
function setup(overrides = {}, route = 'pages/profile/auth/index') {
  let definition, nextTimer = 0;
  const timers = new Map(), storage = {}, calls = {create:0, check:0, to:[], back:[], tab:[], cleared:0};
  const app = {globalData:{navTop:48, navHeight:32, navRight:102}};
  const scope = {
    Page: value => {definition = value;}, enterPage() {}, applyThemeAndLanguage() {},
    getApp: () => app, getCurrentPages: () => [{}],
    setTimeout: fn => {timers.set(++nextTimer, fn); return nextTimer;},
    clearTimeout: id => timers.delete(id),
    clearCampusAuthSession: () => {calls.cleared++;},
    createXidianAuthSession: async () => {calls.create++; return {data:{attemptId:'a1', authorizeUrl:'https://ids.xidian.edu.cn/auth?one=1&two=2'}};},
    fetchXidianAuthSession: async () => {calls.check++; return {data:{status:'pending'}};},
    ...overrides,
    wx: {
      getStorageSync: key => storage[key], setStorageSync: (key, value) => {storage[key] = value;},
      navigateTo: options => calls.to.push(options), navigateBack: options => calls.back.push(options),
      switchTab: options => calls.tab.push(options),
      ...overrides.wx
    }
  };
  vm.runInNewContext(read(route+'.js').replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, ''), scope);
  const host = {...definition, data:JSON.parse(JSON.stringify(definition.data)), setData:require('./support/set-data.cjs')};
  return {host, calls, storage, timers, app, flush() {const pending = [...timers.values()]; timers.clear(); pending.forEach(fn => fn());}};
}

test('login preview reserves capsule space and loads no authentication requests before consent', () => {
  const {host, calls} = setup();
  host.onLoad(); host.onShow();
  assert.equal(host.data.navTop,48); assert.equal(host.data.navRight,102);
  assert.equal(host.data.canGoBack,false); assert.equal(calls.create,0); assert.equal(calls.check,0);
});
test('login click locks repeated taps and preserves the whole official authorization URL', async () => {
  const pending=defer(); let creates=0;
  const {host,calls}=setup({createXidianAuthSession:()=>{creates++; return pending.promise;}});
  const request=host.handlePrimary();
  assert.equal(host.data.phase,'connecting'); assert.equal(host.data.submitting,true);
  await host.handlePrimary(); assert.equal(creates,1);
  pending.resolve({data:{attemptId:'a1',authorizeUrl:'https://ids.xidian.edu.cn/login?a=1&next=%2F'}});
  await request;
  assert.equal(host.data.phase,'opening');
  assert.equal(calls.to[0].url,'/pages/campus/webview/index?url='+encodeURIComponent(host.data.authorizeUrl));
  assert.equal(host._awaitingOfficialReturn,true);
});
test('navigation failure unlocks retry and reuses the existing session', async () => {
  const {host,calls}=setup();
  await host.handleLogin(); calls.to[0].fail({errMsg:'navigation failed'});
  assert.equal(host.data.phase,'error'); assert.equal(host.data.submitting,false);
  assert.equal(host.data.errorMessage,'navigation failed');
  assert.equal(host._awaitingOfficialReturn,false);
  await host.handlePrimary(); assert.equal(calls.create,1); assert.equal(calls.to.length,2);
});
test('returning from official authentication checks once and retains a pending session', async () => {
  const {host,calls}=setup(); await host.handleLogin();
  host.onShow(); host.onShow(); await tick();
  assert.equal(calls.check,1); assert.equal(host.data.phase,'pending');
  await host.handlePrimary(); assert.equal(calls.create,1); assert.equal(calls.to.length,2);
});
test('network failures are inline and retry the failed operation', async () => {
  let failing=true;
  const {host,calls}=setup({createXidianAuthSession:async()=>{if(failing)throw new Error('offline'); return {data:{attemptId:'a',authorizeUrl:'https://ids.xidian.edu.cn'}};}});
  await host.handlePrimary(); assert.equal(host.data.errorMessage,'offline'); assert.equal(host.data.submitting,false);
  failing=false; await host.handlePrimary(); assert.equal(calls.to.length,1);
  const checking=setup({fetchXidianAuthSession:async()=>{throw new Error('timeout');}});
  checking.host.setData({attemptId:'kept',authorizeUrl:'https://ids.xidian.edu.cn'});
  await checking.host.checkAuthenticationResult();
  assert.equal(checking.host.data.retryAction,'check'); assert.equal(checking.host.data.attemptId,'kept');
  assert.equal(checking.storage.token,undefined);
});
test('failed identity verification clears the rejected session and never creates a local token', async () => {
  const {host,storage}=setup({fetchXidianAuthSession:async()=>({data:{status:'failed',message:'expired'}})});
  host.setData({attemptId:'old',authorizeUrl:'https://ids.xidian.edu.cn'});
  await host.checkAuthenticationResult();
  assert.equal(host.data.phase,'error'); assert.equal(host.data.attemptId,''); assert.equal(storage.token,undefined);
});
test('expired sessions require a fresh login; other checking failures can be explicitly restarted', async () => {
  const {host,calls}=setup({fetchXidianAuthSession:async()=>{throw {statusCode:404,data:{message:'登录请求不存在或已过期'}};}});
  host.setData({attemptId:'expired',authorizeUrl:'https://ids.xidian.edu.cn/old'});
  await host.checkAuthenticationResult();
  assert.equal(host.data.retryAction,'login'); assert.equal(host.data.attemptId,'');
  await host.handlePrimary(); assert.equal(calls.create,1);
  const other=setup();
  other.host.setData({attemptId:'bad-session',authorizeUrl:'https://ids.xidian.edu.cn/old'});
  other.host.showFailure(new Error('invalid response'),'check');
  await other.host.restartLogin();
  assert.equal(other.calls.create,1); assert.equal(other.host.data.attemptId,'a1');
});
test('success stores the returned token and chooses root or stack navigation explicitly', async () => {
  for(const stack of [1,2]) {
    const {host,calls,storage,timers,flush,app}=setup({
      getCurrentPages:()=>Array(stack).fill({}),
      fetchXidianAuthSession:async()=>({data:{status:'authenticated',token:'verified-token'}})
    });
    host.setData({attemptId:'a',authorizeUrl:'https://ids.xidian.edu.cn'});
    await host.checkAuthenticationResult();
    assert.equal(storage.token,'verified-token'); assert.equal(app.globalData.hasToken,true);
    assert.equal(calls.cleared,1); assert.equal(host.data.phase,'success'); assert.equal(timers.size,1);
    flush();
    assert.equal(calls.tab.length,stack===1?1:0); assert.equal(calls.back.length,stack===2?1:0);
    const navigation=(stack===1?calls.tab:calls.back)[0];
    navigation.fail({errMsg:'unable to open'});
    assert.equal(host.data.retryAction,'enter');
    await host.handlePrimary();
    assert.equal((stack===1?calls.tab:calls.back).length,2);
    assert.equal(calls.create,0);
  }
});
test('late login responses cannot update a closed page or navigate away from the current screen', async () => {
  for(const operation of ['create','check']) {
    const pending=defer();
    const {host,calls,storage,timers}=setup(operation==='create'?{createXidianAuthSession:()=>pending.promise}:{fetchXidianAuthSession:()=>pending.promise});
    if(operation==='check') host.setData({attemptId:'a'});
    const request=operation==='create'?host.handleLogin():host.checkAuthenticationResult();
    host.onUnload();
    host.setData=()=>assert.fail('detached write');
    pending.resolve({data:{attemptId:'a',authorizeUrl:'https://ids.xidian.edu.cn',status:'authenticated',token:'must-not-save'}});
    await request;
    assert.equal(calls.to.length,0); assert.equal(storage.token,undefined); assert.equal(timers.size,0);
  }
});
test('unloading during success cancels deferred navigation', async () => {
  const {host,calls,timers,flush}=setup({fetchXidianAuthSession:async()=>({data:{status:'authenticated',token:'token'}})});
  host.setData({attemptId:'a'}); await host.checkAuthenticationResult();
  host.onUnload(); assert.equal(timers.size,0); flush(); assert.equal(calls.tab.length,0);
});
test('unavailable school authentication stays visible and cannot be mistaken for success', async () => {
  const {host,storage,calls}=setup({createXidianAuthSession:async()=>{throw {statusCode:503,data:{message:'学校统一身份认证尚未启用'}};}});
  await host.handlePrimary();
  assert.equal(host.data.phase,'error');
  assert.equal(host.data.errorMessage,'学校统一身份认证尚未启用');
  assert.equal(host.data.submitting,false);
  assert.equal(storage.token,undefined); assert.equal(calls.to.length,0);
});
test('legal links open matching content and are locked during authentication', () => {
  const {host,calls}=setup();
  host.goTerms(); host.goPrivacy();
  assert.deepEqual(calls.to.map(item=>item.url.split('type=')[1]),['user-agreement','privacy-policy']);
  host.setPhase('connecting'); host.goTerms(); host.goPrivacy();
  assert.equal(calls.to.length,2);
});

function homeSetup(overrides={}) {
  const context=setup({sharePost(){},requireLoginPage:()=>true,...overrides},'pages/treehole/index');
  const counts={profile:0,colleges:0,feed:0};
  context.host.initCustomNav=()=>{};
  context.host.loadUserInfo=async()=>{counts.profile++;};
  context.host.loadCollegeOptions=async()=>{counts.colleges++;};
  context.host.fetchPosts=async()=>{counts.feed++; context.host.setFeedState('hot',{initialized:true});};
  return {...context,counts};
}
test('home initialization resumes after login and never refetches on ordinary tab returns', async () => {
  let loggedIn=false;
  const {host,counts}=homeSetup({requireLoginPage:()=>loggedIn});
  host.onLoad(); await host.onShow(); assert.equal(counts.profile,0);
  loggedIn=true; await host.onShow();
  assert.deepEqual(counts,{profile:1,colleges:1,feed:1});
  await host.onShow(); assert.equal(counts.feed,1);
});
test('home initialization deduplicates concurrent shows and exposes retriable errors', async () => {
  const {host,counts}=homeSetup(); const pending=defer();
  host.loadUserInfo=()=>{counts.profile++;return pending.promise;};
  const first=host.onShow(); await host.onShow();
  assert.equal(counts.profile,1);
  pending.reject(new Error('unavailable')); await first;
  assert.equal(host.data.bootstrapError,'unavailable'); assert.equal(host._homeInitialized,undefined);
  host.loadUserInfo=async()=>{counts.profile++;};
  await host.initializeHome(); assert.equal(host.data.bootstrapError,''); assert.equal(counts.feed,1);
});
test('home initialization cannot start a feed request after unloading', async () => {
  const {host,counts}=homeSetup(); const pending=defer(); host.loadUserInfo=()=>pending.promise;
  const request=host.onShow(); host.onUnload(); pending.resolve(); await request; assert.equal(counts.feed,0);
});
test('formal entry has no photo dependency and preserves accessible true request states', () => {
  assert.equal(fs.existsSync(path.join(root,'assets/xidian-plaza.jpg')),false);
  assert.doesNotMatch(read('pages/profile/auth/index.wxml'),/<image|photo|摄影|遇见同频/);
  assert.doesNotMatch(read('pages/profile/auth/index.js'),/photoState|retryPhoto|goPhotoCredit/);
  assert.match(read('pages/profile/auth/index.wxml'),/role="status" aria-live="polite"/);
  assert.match(read('pages/profile/auth/index.wxml'),/disabled="\{\{submitting\}\}"/);
  assert.match(read('pages/profile/auth/index.wxss'),/prefers-reduced-motion/);
  assert.doesNotMatch(read('pages/profile/auth/index.js'),/showLoading|hideLoading|Math.random/);
  assert.match(read('pages/treehole/index.wxml'),/class="feed-skeleton"/);
  assert.match(read('pages/treehole/index.wxss'),/prefers-reduced-motion:reduce/);
});
