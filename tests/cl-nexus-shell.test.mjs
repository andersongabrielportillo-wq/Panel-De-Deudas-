import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const html=readFileSync('index.html','utf8');
const shell=readFileSync('cl-nexus-shell.js','utf8');
const sw=readFileSync('sw.js','utf8');
test('shell mounted once on integration branch',()=>{assert.equal(html.split('src="./cl-nexus-shell.js"').length-1,1)});
test('shell gated by existing authenticated privateApp',()=>{assert.match(shell,/function authenticated\(\)/);assert.match(shell,/!app\.hidden&&!app\.inert/)});
test('modules have desktop and mobile navigation',()=>{for(const m of ['inventario','garantias','contratos'])assert.ok(shell.includes("['"+m+"'"));assert.match(shell,/const bottom=\$\('bnav'\)/)});
test('shell cannot write debt state or call remote APIs',()=>{for(const prohibited of ['localStorage','fetch(','\.from(','\.rpc(','SUPABASE_KEY','__shared_state__','cp_v2'])assert.ok(!shell.includes(prohibited),prohibited)});
test('existing debt backend and service worker remain present',()=>{assert.match(html,/const SUPABASE_URL=/);assert.match(html,/function cloudSnapshot/);assert.match(sw,/SKIP_WAITING/)});

test('read-only adapter is loaded before shell',()=>{assert.ok(html.indexOf('src="./cl-nexus-adapter.cjs"')<html.indexOf('src="./cl-nexus-shell.js"'))});
test('production cannot enable laboratory RPC queries',()=>{assert.match(shell,/CLNexusRuntime\.origin!==LAB_ORIGIN/);assert.match(html,/window\.CLNexusRuntime=Object\.freeze/)});

test('private data are cleared on logout and module switching',()=>{assert.match(shell,/function hideSensitive\(\)/);assert.match(shell,/function clear\(\)\{closeAdapter\(\);hideSensitive\(\)/);assert.match(shell,/if\(active!==id\)\{closeAdapter\(\);hideSensitive\(\)\}/)});
test('operation responses cannot render in a different module',()=>{assert.match(shell,/active===operationModule&&authenticated\(\)/)});
test('form numeric fields enforce numeric input',()=>{assert.match(shell,/inp\.type='number'/);assert.match(shell,/inp\.min='0'/)});

test('exit movement has null destination before RPC',()=>{assert.match(shell,/values\.tipo==='salida'&&!values\.destino\.trim\(\)\)values\.destino=null/)});
test('idempotency key rotates when form payload changes',()=>{assert.match(shell,/form\.dataset\.opFingerprint!==fingerprint/);assert.match(shell,/delete form\.dataset\.opFingerprint/)});

test('staging permission check uses real authenticated JWT and nonexistent request',()=>{const stage=readFileSync('staging/index.html','utf8');assert.match(stage,/id="checkPermissions"/);assert.match(stage,/accessToken\(s\)/);assert.match(stage,/00000000-0000-4000-8000-000000000000/);assert.match(stage,/inv_revisar_entrada/);assert.match(stage,/authEpoch!==epoch/)});

test('staging concurrency only calls isolated sandbox and requires confirmation',()=>{const stage=readFileSync('staging/index.html','utf8');assert.match(stage,/cl2_sandbox_test_sale/);assert.match(stage,/Promise\.allSettled\(\[run\(\),run\(\)\]\)/);assert.match(stage,/confirm\("¿Ejecutar DOS ventas simultáneas/);assert.match(stage,/authEpoch!==epoch/)});

test('debt security draft requires server-side unlock on every CRUD policy',()=>{const sql=readFileSync('docs/sql/debt-gate-review-only.sql','utf8');for(const operation of ['SELECT','INSERT','UPDATE','DELETE'])assert.match(sql,new RegExp('FOR '+operation+' TO authenticated'));assert.equal((sql.match(/public\.debt_access_valid\(workspace_id\)/g)||[]).length,5);assert.match(sql,/extensions\.crypt\(p_password,v_hash\)/);assert.match(sql,/session_id/);assert.match(sql,/No lanzar excepción: eso revertiría el contador/)});

test('service worker caches both CL Nexus scripts in a versioned release',()=>{assert.match(sw,/\.\/cl-nexus-adapter\.cjs/);assert.match(sw,/\.\/cl-nexus-shell\.js/);assert.match(sw,/panel-de-deudas-shell-v5-debt-encrypted-backup-preparacion/)});
test('service worker does not intercept Supabase or cross-origin traffic',()=>{assert.match(sw,/url\.origin !== self\.location\.origin/);assert.match(sw,/req\.method !== 'GET'/)});
