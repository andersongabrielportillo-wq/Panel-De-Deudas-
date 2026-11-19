import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const root=new URL('../',import.meta.url);
test('build isolated PWA cutover candidate without modifying live index',()=>{
 const original=readFileSync(new URL('../index.html',import.meta.url),'utf8');
 execFileSync(process.execPath,[new URL('../scripts/build-cln-candidate.mjs',import.meta.url).pathname],{cwd:new URL('../',import.meta.url).pathname,stdio:'pipe'});
 const preview=readFileSync(new URL('../dist-cln-candidate/index.html',import.meta.url),'utf8');
 assert.match(original,/const DEBT_GATE_ENABLED=false;/);
 assert.match(preview,/const DEBT_GATE_ENABLED=true;/);
 assert.equal(preview,original.replace('const DEBT_GATE_ENABLED=false;','const DEBT_GATE_ENABLED=true;'));
 for(const component of ['clnModuleHub','clnHubInventory','clnHubContracts','clnHubWarranties','debtUnlockScreen','authGate'])
  assert.ok(preview.includes(component));
});
