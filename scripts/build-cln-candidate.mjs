// CL Nexus controlled release candidate: BUILD ONLY, never deploy automatically.
// It intentionally has a different cache version and excludes sandbox-only modules.
import {readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join,resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const source=path=>readFileSync(join(root,path),'utf8');
const original=source('index.html');
const sql=source('sql/deudas_gate_existing_production_rpc_PREPARADO_NO_EJECUTAR.sql');
const sw=source('sw.js');
const declaration='const DEBT_GATE_ENABLED=false;';
if(original.split(declaration).length!==2)throw Error('Expected exactly one disabled Deudas gate');
for(const required of [
 "rpcNames:{unlock:'unlock_debts',verify:'has_debts_unlock',lock:'lock_debts'}",
 'await debtGate.verify()','await debtController.verify()',
 'authSessionGeneration++','showModuleHub(true)',
 'CLNexusActions.createNexusActions','CLNexusReader.createNexusReader'
])if(!original.includes(required))throw Error('Missing required PWA protection: '+required);
for(const required of [
 'AS RESTRICTIVE FOR ALL TO authenticated',
 'USING (public.has_debts_unlock())','WITH CHECK (public.has_debts_unlock())',
 'ON public.debts','ON public.transactions',
 'Deudas secret is not decryptable: abort'
])if(!sql.includes(required))throw Error('Missing coordinated database protection: '+required);
const labScriptNames=['cl-nexus-adapter.cjs','cl-nexus-shell.js'];
let candidate=original.replace(declaration,'const DEBT_GATE_ENABLED=true;');
for(const file of labScriptNames){
 const tag='<script src="./'+file+'"></script>';
 if(!candidate.includes(tag))throw Error('Expected sandbox-only script: '+file);
 candidate=candidate.replace(tag,'');
}
if(candidate.includes(declaration))throw Error('The release candidate is not gated');
if(candidate.includes('cl2_sandbox_list'))throw Error('Sandbox RPC leaked into release candidate');
const coreMatch=sw.match(/const CORE = \[([^\]]+)\];/);
if(!coreMatch)throw Error('Service Worker CORE list missing');
const core=[...coreMatch[1].matchAll(/'(\.\/[^']+)'/g)].map(m=>m[1]).filter(p=>!labScriptNames.includes(p.slice(2)));
if(!core.includes('./index.html')||!core.includes('./manifest.webmanifest'))throw Error('Core PWA assets missing');
const scripts=[...candidate.matchAll(/<script\b[^>]*\bsrc=["'](\.\/[^"']+)["']/g)].map(m=>m[1]);
for(const script of scripts)if(!core.includes(script))throw Error('PWA script not cached or bundled: '+script);
const all=[...new Set(core.filter(p=>p!=='./').map(p=>p.slice(2)))];
for(const p of all)if(p.includes('..')||p.startsWith('/')||p.includes('\\'))throw Error('Unsafe asset path: '+p);
if(!all.includes('icons/icon-192.png')||!all.includes('icons/icon-512.png'))throw Error('Required PWA icons missing');
const marker=sw.match(/const CACHE = '([^']+)';/);
if(!marker)throw Error('Service Worker cache marker missing');
// Bind cache revision to actual application/asset contents so old clients do not cache an outdated gate.
const hash=createHash('sha256').update(candidate);
for(const file of all.filter(x=>x!=='index.html'))hash.update(file).update(readFileSync(join(root,file)));
const revision=hash.digest('hex').slice(0,12);
const cache='panel-de-deudas-shell-v9-cln-cutover-'+revision;
let releaseSw=sw.replace(marker[0],"const CACHE = '"+cache+"';");
const coreLiteral='const CORE = ['+core.map(s=>"'"+s+"'").join(', ')+'];';
releaseSw=releaseSw.replace(coreMatch[0],coreLiteral);
if(releaseSw.includes("'./cl-nexus-shell.js'")||releaseSw.includes("'./cl-nexus-adapter.cjs'"))throw Error('Lab asset remains in Service Worker');
const target=join(root,'dist-cln-candidate');
mkdirSync(target,{recursive:true});
writeFileSync(join(target,'index.html'),candidate,'utf8');
writeFileSync(join(target,'sw.js'),releaseSw,'utf8');
for(const file of all){
 if(file==='index.html')continue;
 mkdirSync(dirname(join(target,file)),{recursive:true});
 copyFileSync(join(root,file),join(target,file));
}
writeFileSync(join(target,'NO_PUBLICAR_HASTA_CORTE_CONTROLADO.txt'),
 'CL NEXUS CANDIDATO OFFLINE. No subir a main ni desplegar hasta validar respaldo integral Auth/Vault, RLS, cuentas reales, inventario y aprovisionamiento. La clave adicional es obligatoria: usar solo con migracion RLS coordinada. La rama original NO se modifica.\n','utf8');
console.log('PASS: candidate assembled with '+all.length+' core assets, cache '+cache+'; no production deployment');
