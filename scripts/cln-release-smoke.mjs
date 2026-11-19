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
assert.match(sw,/panel-de-deudas-shell-v12-buscador-vendedores-20261119/);
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
assert.match(html,/function arrangeNexusSections\(groups,epoch,initialLabel/);
assert.match(html,/panel\.setAttribute\("role","tabpanel"\)/);
assert.match(html,/button\.setAttribute\("role","tab"\)/);
assert.match(html,/panels\[i\]\.hidden=!active;panels\[i\]\.inert=!active/);
assert.match(html,/arrangeNexusSections\(sectionLayout,token,id===/);

for(const id of ['clnHubInventory','clnHubSales','clnHubContracts','clnHubSellers','clnHubWarranties','clnHubDebts'])
 assert.match(html,new RegExp('id="'+id+'"'),'Main menu missing '+id);
assert.match(html,/function clnEnhanceArticleSearch\(container\)/);
assert.match(html,/input\.setAttribute\("role","combobox"\)/);
assert.match(html,/select\.clnPickerRefresh/);
assert.match(html,/article\.nombre/);
assert.match(html,/cln-item-catalog/);
assert.match(html,/cln-seller-grid/);
assert.match(html,/id="cln-mobile-upgrade"/);
assert.match(html,/if\(id==="clnHubSellers"\)await refreshSellerList\(\)/);
assert.match(html,/id==="clnHubSales"\?"Ventas"/);
assert.doesNotMatch(html,/option\.textContent=article\.nombre\+\(article\.codigo/);
// UI regression: Contracts must not request a forbidden empty-client search.
assert.doesNotMatch(html,/await nexusReader\.list\("contracts"\);/);
assert.match(html,/nexusReader\.list\("contracts",term\)/);
assert.match(html,/SB\.rpc\("inv_detalle_contrato",\{p_contrato_id:requested\}\)/);
assert.match(html,/detalle_id:line\.detalle_id/);
assert.match(html,/location_id:Number\(line\.location\.value\)/);
assert.match(html,/SB\.rpc\("inv_resumen_vendedor"/);
assert.match(html,/SB\.rpc\("inv_historial_vendedor"/);
assert.match(html,/if\(clnHubDetail\.contains\(wrap\)\)clnEnhanceArticleSearch\(wrap\)/);
assert.doesNotMatch(html,/Ubicaciones JSON/);
assert.match(html,/cln-catalog-search/);
console.log('PASS: original visual tokens, accessible CL Nexus nested tabs and parsed inline JS, one login, protected Deudas. No deployment performed.');
