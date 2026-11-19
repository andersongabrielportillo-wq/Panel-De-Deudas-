import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const get=(path)=>readFileSync(join(root,path),'utf8');
const original=get('index.html');
test('cutover build has all deployable static assets and excludes laboratory UI',()=>{
 execFileSync(process.execPath,[join(root,'scripts/build-cln-candidate.mjs')],{cwd:root,stdio:'pipe'});
 const preview=get('dist-cln-candidate/index.html');
 const sw=get('dist-cln-candidate/sw.js');
 assert.match(original,/const DEBT_GATE_ENABLED=false;/,'Original PWA must remain disabled');
 assert.match(preview,/const DEBT_GATE_ENABLED=true;/);
 assert.doesNotMatch(preview,/src="\.\/cl-nexus-shell\.js"/);
 assert.doesNotMatch(preview,/src="\.\/cl-nexus-adapter\.cjs"/);
 assert.doesNotMatch(preview,/cl2_sandbox_list/);
 for(const component of ['clnModuleHub','clnHubInventory','clnHubContracts','clnHubWarranties','debtUnlockScreen','authGate'])
  assert.ok(preview.includes(component),'Missing cutover UI: '+component);
 assert.match(sw,/const CACHE = 'panel-de-deudas-shell-v9-cln-cutover-[0-9a-f]{12}';/);
 assert.doesNotMatch(sw,/cl-nexus-shell\.js|cl-nexus-adapter\.cjs/);
 assert.ok(existsSync(join(root,'dist-cln-candidate/NO_PUBLICAR_HASTA_CORTE_CONTROLADO.txt')));
 const core=sw.match(/const CORE = \[([^\]]+)\];/);
 assert.ok(core,'Candidate SW missing pre-cache list');
 const assets=[...core[1].matchAll(/'(\.\/[^']+)'/g)].map(x=>x[1]);
 assert.ok(assets.includes('./index.html')&&assets.includes('./manifest.webmanifest'));
 for(const asset of assets){
  if(asset==='./')continue;
  assert.ok(existsSync(join(root,'dist-cln-candidate',asset)), 'Missing bundled asset: '+asset);
 }
 const scripts=[...preview.matchAll(/<script\b[^>]*\bsrc=["'](\.\/[^"']+)["']/g)].map(m=>m[1]);
 for(const script of scripts)assert.ok(assets.includes(script),'Missing cached script: '+script);
});
test('candidate package leaves original source and its existing Service Worker unchanged',()=>{
 assert.match(get('index.html'),/const DEBT_GATE_ENABLED=false;/);
 assert.match(get('sw.js'),/const CACHE = 'panel-de-deudas-shell-v8-nexus-adapters';/);
 assert.match(get('sw.js'),/cl-nexus-shell\.js/);
});
