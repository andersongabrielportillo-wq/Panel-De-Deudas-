import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {buildCatalog} from '../scripts/prepare-cln-catalog-2026-3.mjs';
import {cols} from '../scripts/prepare-cln-inventory-import.mjs';
function fixture(){
 const rows=Array.from({length:190},(_,i)=>({
  codigo_bloque:'MERCADERIA-C'+(i+2),
  nombre_fuente:i<5?'':i<10?'ARTICULO FICTICIO REPETIDO':'ARTICULO FICTICIO '+i,
  duplicado_fuente:i>=5&&i<10?'SI':'NO',
  nombre_aprobado:'',ubicacion_aprobada:'',cantidad_fisica:'',
  decision:'PENDIENTE',revision_duplicado:'PENDIENTE',revisor:'',fecha_aprobacion:''
 }));
 const sha=createHash('sha256').update(rows.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:1)
  .map(r=>r.codigo_bloque+'\t'+r.nombre_fuente+'\t'+r.duplicado_fuente+'\n').join('')).digest('hex');
 const csv=rr=>[cols.join(','),...rr.map(r=>cols.map(k=>'"'+String(r[k]).replaceAll('"','""')+'"').join(','))].join('\n')+'\n';
 return {rows,sha,csv};
}
test('Catalog-only cutover preserves 190 items, 5 missing names and source duplicates without manufacturing stock',()=>{
 const {rows,sha,csv}=fixture();
 const out=buildCatalog(csv(rows),sha);
 assert.equal(out.items,190);
 assert.equal(out.unnamed,5);
 assert.equal((out.sql.match(/NOMBRE PENDIENTE/g)||[]).length,5+1 /* code comment */);
 assert.equal((out.sql.match(/ARTICULO FICTICIO REPETIDO/g)||[]).length,5);
 assert.match(out.sql,/INSERT INTO public\.inv_items/);
 assert.doesNotMatch(out.sql,/INSERT INTO public\.inv_stock/);
 assert.doesNotMatch(out.sql,/INSERT INTO (?:public\.)?debts/i);
 assert.match(out.sql,/EXISTS\(SELECT 1 FROM public\.inv_stock\)/);
 assert.match(out.sql,/Los 3 administradores de Deudas deben estar autorizados/);
});
test('Catalog-only generator rejects source tampering, missing rows and duplicate codes',()=>{
 const {rows,sha,csv}=fixture();
 const badName=structuredClone(rows);badName[9].nombre_fuente='ALTERADO';
 assert.throws(()=>buildCatalog(csv(badName),sha),/CATALOGO BLOQUEADO/);
 assert.throws(()=>buildCatalog(csv(rows.slice(1)),sha),/190 bloques/);
 const duplicate=structuredClone(rows);duplicate[4].codigo_bloque=duplicate[3].codigo_bloque;
 assert.throws(()=>buildCatalog(csv(duplicate),sha),/código inválido o duplicado/);
});
test('Catalog source fingerprint detects reordering-insensitive but content-sensitive changes',()=>{
 const {rows,sha,csv}=fixture();
 const result=buildCatalog(csv(rows.toReversed()),sha);
 assert.equal(result.items,190);
});
