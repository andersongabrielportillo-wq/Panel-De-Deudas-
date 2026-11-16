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
