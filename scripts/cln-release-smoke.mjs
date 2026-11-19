import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const read=p=>fs.readFileSync(p,'utf8');
const html=read('index.html'),sw=read('sw.js'),manifest=JSON.parse(read('manifest.webmanifest'));
assert.match(html,/const DEBT_GATE_ENABLED=true;/);
assert.doesNotMatch(html,/const DEBT_GATE_ENABLED=false;/);
assert.match(html,/https:\/\/josdmjjbnrugiwlwgjky\.supabase\.co/);
for(const id of ['clnModuleHub','clnHubInventory','clnHubWarranties','clnHubContracts','debtUnlockScreen','clnHubHttpAudit','authGate'])assert.ok(html.includes(id), 'Missing UI '+id);
for(const bad of ['src="./cl-nexus-shell.js"','src="./cl-nexus-adapter.cjs"','cl2_sandbox_list'])assert.ok(!html.includes(bad), 'Lab-only asset leaked '+bad);
const coreSection=sw.match(/const CORE = \[([^\]]+)\];/)?.[1];
assert.ok(coreSection,'SW core pre-cache missing');
const core=[...coreSection.matchAll(/'(\.\/[^']+)'/g)].map(x=>x[1]);
const scripts=[...html.matchAll(/<script\b[^>]*\bsrc=["'](\.\/[^"']+)["']/g)].map(x=>x[1]);
for(const script of scripts)assert.ok(core.includes(script)&&fs.existsSync(script),'Missing script or cache entry: '+script);
for(const asset of core)if(asset!=='./')assert.ok(fs.existsSync(asset),'Missing core asset '+asset);
assert.match(sw,/panel-de-deudas-shell-v10-login-unico-20261119/);
assert.match(sw,/if \(url\.origin !== self\.location\.origin\) return/);
for(const needed of ['./cl-nexus-reader.cjs','./cl-nexus-actions.cjs','./debt-gate-client.cjs','./debt-module-controller.cjs','./cln-http-auth-probe.cjs'])assert.ok(core.includes(needed));
assert.equal(manifest.start_url,'./');
assert.equal(manifest.scope,'./');
assert.match(manifest.name,/CL Nexus/);
assert.match(html,/rpcNames:\{unlock:'unlock_debts',verify:'has_debts_unlock',lock:'lock_debts'\}/);
assert.match(html,/CLNHttpAuthProbe\.probe\(\{client:SB\}\)/);
assert.match(html,/actions\.execute\("renameItem"/);

assert.match(html,/id="clnModuleHub"[^>]*class="cln-workspace"/);
assert.doesNotMatch(html,/<h2>Panel de módulos<\/h2>/);
assert.match(html,/function showModuleHub\(yes\)[^\n]*void openIndependentModule\("clnHubInventory"\)/);
assert.match(html,/document\.getElementById\("authLogin"\)\.onclick=async/);
assert.match(html,/SB\.auth\.signInWithPassword\(\{email,password\}\)/);
assert.match(html,/document\.getElementById\("debtUnlockButton"\)\.onclick=async/);
assert.match(html,/await debtController\.open\(password\)/);

assert.match(html,/COMERCIAL LÓPEZ · PANEL DE GESTIÓN/);
assert.match(html,/cln-session-chip/);
assert.match(html,/id="clnModuleHub"[^>]*class="cln-workspace"/);
assert.match(html,/id="clnModuleChoices"[^>]*aria-label="Secciones de CL Nexus"/);
assert.match(html,/name===id\)\)/);
assert.match(html,/await debtController\.open\(password\)/);
// Comprueba el JavaScript embebido además de los archivos externos.
const embeddedScripts=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(match=>match[1]).filter(code=>code.trim());
assert.ok(embeddedScripts.length>=3,'Expected app and PWA inline scripts');
for(const [index,code] of embeddedScripts.entries())assert.doesNotThrow(()=>new vm.Script(code,{filename:'index-inline-'+index+'.js'}),'JavaScript inline invalid');
for(const label of ['Existencias','Entradas','Traslados','Ventas','Artículos','Liberación','Devoluciones','Reparaciones','Clientes','Vendedores','Contratos','Primas']){
 assert.ok(html.includes('["'+label+'",['),'Missing sub-tab '+label);
}
assert.match(html,/function arrangeNexusSections\(groups,epoch\)/);
assert.match(html,/panel\.setAttribute\("role","tabpanel"\)/);
assert.match(html,/button\.setAttribute\("role","tab"\)/);
assert.match(html,/panels\[i\]\.hidden=!active;panels\[i\]\.inert=!active/);
assert.match(html,/arrangeNexusSections\(sectionLayout,token\)/);
console.log('PASS: original visual tokens, accessible CL Nexus nested tabs and parsed inline JS, one login, protected Deudas. No deployment performed.');
