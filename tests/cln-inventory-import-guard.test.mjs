import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {build,cols,csvParse} from '../scripts/prepare-cln-inventory-import.mjs';
const quote=s=>'"'+String(s).replaceAll('"','""')+'"';
function make(){
 const records=Array.from({length:190},(_,i)=>({
  codigo_bloque:'MERCADERIA-C'+(i+2),
  nombre_fuente:i===0?'CAFETERA "DEMO"':i===1?'CAFETERA "DEMO"':'ITEM FICTICIO '+i,
  duplicado_fuente:i<2?'SI':'NO',
  nombre_aprobado:'ARTICULO DE PRUEBA '+i,
  ubicacion_aprobada:'Oficina',
  cantidad_fisica:'0',
  decision:'IMPORTAR',
  revision_duplicado:i<2?'SEPARADO':'NO_APLICA',
  revisor:'USUARIO DE PRUEBA',
  fecha_aprobacion:'2026-11-18'
 }));
 const hash=createHash('sha256').update(records.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:1).map(r=>r.codigo_bloque+'\t'+r.nombre_fuente+'\t'+r.duplicado_fuente+'\n').join('')).digest('hex');
 const csv=rows=>[cols.join(','),...rows.map(r=>cols.map(c=>quote(r[c])).join(','))].join('\r\n')+'\r\n';
 return {records,hash,csv};
}
test('190 reviewed synthetic entries generate SQL without touching the database',()=>{
 const {records,hash,csv}=make();
 const out=build(csv(records),hash);
 assert.equal(out.approved,190);
 assert.match(out.sql,/BEGIN;/);
 assert.match(out.sql,/COMMIT;/);
 assert.match(out.sql,/Stock no vacío; no se puede repetir carga/);
 assert.match(out.sql,/Roles no autorizados/);
 assert.match(out.sql,/Garantía\/Proveedor no pueden tener stock inicial/);
 assert.doesNotMatch(out.sql,/INSERT INTO (?:auth\.users|public\.debts)/i);
});
test('a pending or incomplete inventory never generates an import',()=>{
 const {records,hash,csv}=make();
 for(const [field,value] of [['decision','PENDIENTE'],['cantidad_fisica',''],['ubicacion_aprobada','Garantía'],['revisor',''],['fecha_aprobacion','2026-02-30']]){
  const testRecords=structuredClone(records);testRecords[0][field]=value;
  assert.throws(()=>build(csv(testRecords),hash),/BLOQUEO/);
 }
 assert.throws(()=>build(csv(records.slice(1)),hash),/190 bloques/);
});
test('source name changes or unresolved duplicates block import',()=>{
 const {records,hash,csv}=make();
 const a=structuredClone(records);a[0].nombre_fuente='NOMBRE CAMBIADO';
 assert.throws(()=>build(csv(a),hash),/catálogo fuente/);
 const b=structuredClone(records);b[0].revision_duplicado='PENDIENTE';
 assert.throws(()=>build(csv(b),hash),/duplicado sin revisión separada/);
 const c=structuredClone(records);c[0].codigo_bloque=records[1].codigo_bloque;
 assert.throws(()=>build(csv(c),hash),/Código repetido/);
});
test('explicit exclusions never seed warehouse stock, while keeping full source audit',()=>{
 const {records,hash,csv}=make();
 records[0].decision='EXCLUIR';records[0].cantidad_fisica='';records[0].ubicacion_aprobada='';
 const result=build(csv(records),hash);
 assert.equal(result.approved,189);
 assert.match(result.sql,/'EXCLUIR'/);
 assert.match(result.sql,/FROM cln_import WHERE decision='IMPORTAR'/);
 records[0].ubicacion_aprobada='Oficina';
 assert.throws(()=>build(csv(records),hash),/excluido con stock/);
});
test('UTF-8 and quoted CSV cell values are parsed safely',()=>{
 const {records,csv}=make();
 const parsed=csvParse(csv(records));
 assert.equal(parsed[0].nombre_fuente,'CAFETERA "DEMO"');
 assert.equal(parsed.length,190);
});
