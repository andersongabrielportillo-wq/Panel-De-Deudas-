import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createRequire} from 'node:module';
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
assert.match(sw,/panel-de-deudas-shell-v16-inventario-impresion-20261120/);
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
assert.match(html,/function showModuleHub\(yes\)\{/);
assert.match(html,/void openIndependentModule\("clnHubInventory"\)/);
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
assert.match(html,/if\(id==="clnHubSellers"&&refreshSellerList\)await refreshSellerList\(\)/);
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

/* Auth regression: no apparent second login while restoring an existing session. */
assert.equal((html.match(/id="authLogin"/g)||[]).length,1,'Only one primary login');
assert.equal((html.match(/id="authGate"/g)||[]).length,1,'Only one primary auth gate');
for(const required of [
 '<div id="authGate" hidden inert>',
 '<div id="clnBoot" role="status"',
 'async function ensureAuthenticatedWorkspace(session)',
 'if(authConnection?.uid===uid)return authConnection.promise',
 'if(authConnectedUid===uid&&SB_WID&&debtController)',
 'showSessionRecovery(e)',
 'session&&["INITIAL_SESSION","SIGNED_IN","TOKEN_REFRESHED"].includes(event)'
])assert.ok(html.includes(required),'Auth regression: missing '+required);
assert.ok(!html.includes('await SB.auth.signOut();gate(true,e.message'),'Never log out an authenticated user for a transient workspace load failure');
const coordinatorStart=html.indexOf('let authConnection=null,authConnectedUid=null;');
const coordinatorEnd=html.indexOf('// Manual encrypted backup',coordinatorStart);
assert.ok(coordinatorStart>0&&coordinatorEnd>coordinatorStart,'Session coordinator missing');
const coordinator=html.slice(coordinatorStart,coordinatorEnd);
let connectionCalls=0;
let finishConnection;
const holdConnection=new Promise(resolve=>{finishConnection=resolve});
const authSandbox={
 SB_UID:null,SB_WID:null,debtController:null,authSessionGeneration:0,
 connectCloud:async()=>{connectionCalls++;await holdConnection;authSandbox.SB_WID='ws-1';authSandbox.debtController={};},
 gate:()=>{},document:{},moduleHub:{},debtScreen:{},hidePrivate:()=>{}
};
vm.runInNewContext(coordinator+'\nglobalThis.testEnsure=ensureAuthenticatedWorkspace;',authSandbox);
const liveSession={user:{id:'user-1'}};
const attemptA=authSandbox.testEnsure(liveSession);
const attemptB=authSandbox.testEnsure(liveSession);
assert.equal(connectionCalls,1,'Two auth events initiated two cloud connections');
finishConnection();
assert.equal(await attemptA,true);
assert.equal(await attemptB,true);
assert.equal(await authSandbox.testEnsure(liveSession),true);
assert.equal(connectionCalls,1,'Returning to Inventory initialized another sign-in');
assert.ok(html.includes('id="debtBackToNexus"'),'Missing Deudas to Inventario navigation');
assert.ok(html.includes('const locked=await debtController.lock();'),'Must revoke Deudas before returning to Inventario');
assert.ok(html.includes('if(locked)showModuleHub(true);'),'Return to Nexus must keep global login');

/* Los contratos usan siempre identificadores de cliente y vendedor del servidor. */
assert.match(html,/const clientName=field\("Nombre completo del cliente","text",true\)/);
assert.match(html,/const clientDui=field\("DUI del cliente/);
assert.match(html,/const vendor=field\("Nombre del vendedor","text",true\)/);
assert.match(html,/nexusReader\.list\("contracts",duiDigits\)/);
assert.match(html,/matchingClient\.nombre/);
assert.match(html,/const matches=contractSellers\.filter/);
assert.match(html,/const inventory=await nexusReader\.list\("contractInventory"\)/);
assert.match(html,/await actions\.execute\("createSeller",\{p_nombre:sellerEntered\}\)/);
assert.match(html,/await actions\.execute\("createContract",params\)/);
assert.match(html,/params\.p_cliente_id=matchingClient\.id/);
assert.match(html,/params\.p_vendedor_id=String\(createdVendor\)/);
assert.match(html,/sellerList\.append\(list,report\)/);
assert.match(html,/const sellers=await nexusReader\.list\("contractSellers"\)/);
assert.match(html,/SB\.rpc\("inv_historial_vendedor"/);
assert.match(html,/DUI terminado en/);
assert.match(html,/SB\.rpc\("inv_ficha_cliente",\{p_cliente_id:data\.cliente_id\}\)/);
assert.match(html,/const foundSeller=manualSellers\.find\(item=>item\.id===data\.vendedor_id\)/);
assert.match(html,/identity\.textContent="Cliente: "/);
assert.doesNotMatch(html,/p_vendedor_id:vendor\.value/);
const testRequire=createRequire(import.meta.url);
const identityActions=testRequire('../cl-nexus-actions.cjs');
const identityReader=testRequire('../cl-nexus-reader.cjs');
const rpcCalls=[];
const testClient={rpc:async(name,args)=>{
 rpcCalls.push({name,args});
 if(name==='inv_catalogo_vendedores_manual')return {data:[{id:'11111111-1111-4111-8111-111111111111',nombre:'Vendedor de prueba'}],error:null};
 if(name==='inv_catalogo_articulos_contratos')return {data:[{id:'33333333-3333-4333-8333-333333333333',nombre:'Artículo de prueba',categoria:'Prueba'}],error:null};
 if(name==='inv_buscar_clientes')return {data:[{id:'22222222-2222-4222-8222-222222222222',nombre:'Cliente de prueba',dui_mostrado:'*****1234',telefono:''}],error:null};
 return {data:'11111111-1111-4111-8111-111111111111',error:null};
}};
const testActions=identityActions.createNexusActions({client:testClient,authorized:()=>true});
await testActions.execute('createClient',{
 p_nombre:'Cliente de prueba',p_dui:'012345678',
 p_direccion:'',p_ubicacion:'',p_telefono:'',p_vivienda:null,
 p_lugar_trabajo:'',p_telefono_trabajo:'',p_referencias:[]
});
assert.equal(rpcCalls.at(-1).name,'inv_crear_cliente');
assert.equal(rpcCalls.at(-1).args.p_vivienda,null);
await testActions.execute('createContract',{
 p_numero:'C-PRUEBA',p_cliente_id:'22222222-2222-4222-8222-222222222222',
 p_vendedor_id:'11111111-1111-4111-8111-111111111111',
 p_fecha:'2026-11-19',p_modalidad:'credito',p_frecuencia:'mensual',p_plan:'normal',
 p_cuota:null,p_saldo_inicial:null,p_fecha_plan:null,p_ruta:'',p_dia_cobro:'',
 p_receptor_alterno:'',p_comision:0,p_prima:0,p_prima_recibida:false,
 p_detalles:[{item_id:'33333333-3333-4333-8333-333333333333',cantidad:1,precio_credito_unitario:12,comision_linea:0}],
 p_observaciones:''
});
assert.equal(rpcCalls.at(-1).name,'inv_crear_contrato_borrador');
assert.equal(rpcCalls.at(-1).args.p_cliente_id,'22222222-2222-4222-8222-222222222222');
assert.equal(rpcCalls.at(-1).args.p_vendedor_id,'11111111-1111-4111-8111-111111111111');
const testReader=identityReader.createNexusReader({client:testClient,authorized:()=>true});
const testSellers=await testReader.list('contractSellers');
assert.equal(rpcCalls.at(-1).name,'inv_catalogo_vendedores_manual');
assert.equal(testSellers[0].nombre,'Vendedor de prueba');
const testClients=await testReader.list('contracts','012345678');
assert.equal(rpcCalls.at(-1).name,'inv_buscar_clientes');
assert.equal(rpcCalls.at(-1).args.p_busqueda,'012345678');
const contractItems=await testReader.list('contractInventory');
assert.equal(rpcCalls.at(-1).name,'inv_catalogo_articulos_contratos');
assert.equal(Array.isArray(contractItems),true);
assert.equal(testClients[0].dui_mostrado,'*****1234');

// Vendors regression: refreshSellerList must be declared in the same scope
// as the first-load call, not solely inside if(kind==="contracts").
const moduleStart=html.indexOf('async function openIndependentModule(id){');
const moduleEnd=html.indexOf('for(const id of Object.keys(clnHubViews))',moduleStart);
assert.ok(moduleStart>=0 && moduleEnd>moduleStart,'CL Nexus module function missing');
const moduleCode=html.slice(moduleStart,moduleEnd);
const layoutDecl=moduleCode.indexOf('let sectionLayout=null;');
const sellersDecl=moduleCode.indexOf('let refreshSellerList=null;');
const contractBranch=moduleCode.indexOf('if(kind==="contracts"){');
const sellersDefinition=moduleCode.indexOf('refreshSellerList=async function(){');
const grouping=moduleCode.lastIndexOf('arrangeNexusSections(sectionLayout,token,');
const initialLoad=moduleCode.indexOf('if(id==="clnHubSellers"&&refreshSellerList)await refreshSellerList();');
assert.ok(layoutDecl>=0 && sellersDecl>layoutDecl && sellersDecl<contractBranch,'refreshSellerList declared inside conditional instead of module scope');
assert.ok(sellersDefinition>contractBranch,'Vendors loader not assigned in Contracts branch');
assert.ok(grouping>sellersDefinition && initialLoad>grouping,'Vendors load must run after section grouping');
assert.ok(!moduleCode.includes('if(id==="clnHubSellers")await refreshSellerList();'),'Unprotected out-of-scope Vendors loader call');
const sellerBranch=moduleCode.slice(contractBranch,grouping);
assert.match(sellerBranch,/sellerButton\.onclick=refreshSellerList/);
assert.match(sellerBranch,/const sellers=await nexusReader\.list\("contractSellers"\)/);
assert.match(moduleCode,/sectionLayout=\[\["Contratos",/);
assert.match(moduleCode,/\["Vendedores",\[sellerForm,sellerButton,sellerList\]\]/);

/* Inventario completo: botón visible únicamente en Inventario, con impresión real sin filtrar la lista. */
assert.match(html,/if\(id==="clnHubInventory"\)\{\s*const printButton=document\.createElement\("button"\)/);
assert.match(html,/printButton\.textContent="Imprimir inventario"/);
assert.match(html,/window\.print\(\)/);
assert.match(html,/window\.addEventListener\("afterprint"/);
assert.match(html,/body>\*:not\(#clnPrintableInventory\)/);
assert.match(html,/thead\{display:table-header-group\}/);
assert.match(html,/Sin registrar significa que no se ha confirmado la existencia/);
const printStart=html.indexOf('printButton.onclick=()=>{');
const printEnd=html.indexOf('     const tools=document.createElement("div");',printStart);
assert.ok(printStart>=0&&printEnd>printStart,'Missing Inventory print handler');
const printSource=html.slice(printStart,printEnd);
assert.match(printSource,/rows\.forEach\(\(article,index\)=>/,'Must print full inventory, not visible slice');
assert.ok(!printSource.includes('rows.slice('),'Print must not truncate catalog');
class PrintElement {
 constructor(tag){this.tagName=tag;this.children=[];this.textContent='';this.id='';this.parentNode=null;this.attrs={}}
 setAttribute(name,value){this.attrs[name]=value}
 append(...elements){for(const element of elements){element.parentNode=this;this.children.push(element)}}
 remove(){if(this.parentNode){this.parentNode.children=this.parentNode.children.filter(x=>x!==this)}}
}
const printBody=new PrintElement('body');
const printDocument={
 body:printBody,
 createElement:tag=>new PrintElement(tag),
 getElementById:id=>printBody.children.find(el=>el.id===id)||null
};
const printButton={onclick:null};
const testInventory=Array.from({length:190},(_,index)=>({
 nombre:'Producto '+String(index+1),
 oficina:index===0?'':(index===1?'0':'3'),
 bodega:index===0?'4':(index===1?'0':'2'),
 codigo:'CELDA_XL_NO_IMPRIMIR'
}));
let printInvocations=0;
const printScope={
 printButton,document:printDocument,window:{print:()=>printInvocations++},
 rows:testInventory,token:1,nexusViewEpoch:1,moduleHub:{hidden:false},
 SB_UID:'authorized-user',SB_WID:'authorized-workspace',
 status:{textContent:''}
};
vm.runInNewContext(printSource,printScope);
assert.equal(typeof printButton.onclick,'function');
printButton.onclick();
assert.equal(printInvocations,1,'Expected native print dialog');
const printSheet=printDocument.getElementById('clnPrintableInventory');
assert.ok(printSheet,'Report not generated');
const table=printSheet.children.find(el=>el.tagName==='table');
const bodyRows=table.children.find(el=>el.tagName==='tbody').children;
assert.equal(bodyRows.length,190,'Print must include all 190 catalog items');
assert.equal(bodyRows[0].children[1].textContent,'Producto 1');
assert.equal(bodyRows[0].children[2].textContent,'Sin registrar');
assert.equal(bodyRows[0].children[4].textContent,'—','Unregistered Oficina is not numeric zero');
assert.equal(bodyRows[1].children[2].textContent,'0');
assert.equal(bodyRows[1].children[4].textContent,'0','Confirmed zero stays zero');
assert.equal(bodyRows[189].children[4].textContent,'5');
const printableText=node=>[node.textContent,...node.children.flatMap(child=>[printableText(child)])].join(' ');
assert.ok(!printableText(printSheet).includes('CELDA_XL_NO_IMPRIMIR'),'Excel provenance must never appear in printable report');
printScope.moduleHub.hidden=true;
printButton.onclick();
assert.equal(printInvocations,1,'Hidden module cannot initiate printing');
console.log('PASS: original visual tokens, accessible CL Nexus nested tabs and parsed inline JS, one login, protected Deudas. No deployment performed.');
