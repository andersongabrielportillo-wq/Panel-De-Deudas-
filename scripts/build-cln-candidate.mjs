// CL Nexus: build an OFFLINE cutover candidate without deploying or modifying production.
// Never run this output as the production PWA until backup, Auth/Vault checks and database RLS cutover are confirmed.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
const root=new URL('../',import.meta.url);
const from=p=>readFileSync(new URL(p,root),'utf8');
const index=from('index.html');
const sql=from('sql/deudas_gate_existing_production_rpc_PREPARADO_NO_EJECUTAR.sql');
const shell=from('cl-nexus-shell.js');
const declaration='const DEBT_GATE_ENABLED=false;';
const occurrences=index.split(declaration).length-1;
if(occurrences!==1)throw Error('Expected exactly one disabled Deudas gate. Refuse ambiguous build.');
for(const required of [
 "rpcNames:{unlock:'unlock_debts',verify:'has_debts_unlock',lock:'lock_debts'}",
 'await debtGate.verify()',
 'await debtController.verify()',
 'authSessionGeneration++',
 'showModuleHub(true)',
 'CLNexusActions.createNexusActions',
 'CLNexusReader.createNexusReader'
]){
 if(!index.includes(required))throw Error('Missing required cutover client code: '+required);
}
for(const required of [
 'AS RESTRICTIVE FOR ALL TO authenticated',
 'USING (public.has_debts_unlock())',
 'WITH CHECK (public.has_debts_unlock())',
 'ON public.debts',
 'ON public.transactions',
 'Deudas secret is not decryptable: abort'
]){
 if(!sql.includes(required))throw Error('Missing database protection: '+required);
}
if(!shell.includes('origin!==LAB_ORIGIN'))throw Error('Laboratory shell is not isolated.');
const candidate=index.replace(declaration,'const DEBT_GATE_ENABLED=true;');
if(candidate===index || candidate.includes(declaration))throw Error('Gate not enabled in preview');
const target=join(process.cwd(),'dist-cln-candidate');
mkdirSync(target,{recursive:true});
writeFileSync(join(target,'index.html'),candidate,'utf8');
console.log('CLN cutover candidate generated locally: not deployed');
