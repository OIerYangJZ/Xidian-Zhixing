const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.resolve(__dirname,'../config/env.js'),'utf8').replace(/^export /gm,'')+';this.result={envConfig,baseUrl,envName};';
function resolve(build,platform,config={}){
 const scope={require:()=>({env:'auto',devtoolsBaseUrl:'http://127.0.0.1:18080',lanBaseUrl:'http://192.168.0.2:18080',prodBaseUrl:'https://campus.example',...config}),wx:{getAccountInfoSync:()=>({miniProgram:{envVersion:build}}),getDeviceInfo:()=>({platform})}};
 vm.runInNewContext(source,scope);return scope.result;
}
test('development retains devtools and local device connections',()=>{
 assert.equal(resolve('develop','devtools').envConfig.name,'devtools');
 assert.equal(resolve('develop','ios').envConfig.name,'lan');
});
test('trial and release always select HTTPS production, never the development LAN',()=>{
 for(const build of ['trial','release'])for(const platform of ['ios','android','devtools'])for(const env of ['auto','lan','devtools','prod']){
  const result=resolve(build,platform,{env});assert.equal(result.baseUrl,'https://campus.example');assert.equal(result.envConfig.name,'prod');
 }
});
test('missing or insecure production configuration fails explicitly instead of using local addresses',()=>{
 assert.throws(()=>resolve('release','ios',{prodBaseUrl:''}),/生产 API 地址未配置/);
 assert.throws(()=>resolve('trial','android',{prodBaseUrl:'http://campus.example'}),/必须使用 HTTPS/);
});
