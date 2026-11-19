import fs from 'node:fs';
import {createHash} from 'node:crypto';
// OFFLINE guard: read private CSV, write private SQL only after 190 explicit decisions.
// The SQL is for a restored clone rehearsal before any production operation.
const sha='d6cfa1e2dad5ef9d0c9ba5f5b6186b984084ffd7e02447878048ec0268fa6cdd';
const cols=['codigo_bloque','nombre_fuente','duplicado_fuente','nombre_aprobado','ubicacion_aprobada','cantidad_fisica','decision','revision_duplicado','revisor','fecha_aprobacion'];
function csvParse(input){
 let records=[],row=[],field='',inside=false,s=input.replace(/^\uFEFF/,'');
 for(let i=0;i<s.length;i++){
  let c=s[i];if(inside){if(c==='"'){if(s[i+1]==='"'){field+='"';i++}else inside=false}else field+=c;continue}
  if(c==='"'){if(field)throw Error('CSV incorrecto');inside=true}
  else if(c===','){row.push(field);field=''}
  else if(c==='\r'||c==='\n'){if(c==='\r'&&s[i+1]==='\n')i++;row.push(field);if(row.some(x=>x!==''))records.push(row);row=[];field=''}
  else field+=c;
 }
 if(inside)throw Error('CSV incompleto');if(row.length||field){row.push(field);records.push(row)}
 if(!records.length||records.some(r=>r.length!==cols.length)||cols.some((c,i)=>records[0][i]!==c))throw Error('Encabezados o columnas CSV incorrectos');
 return records.slice(1).map(r=>Object.fromEntries(cols.map((c,i)=>[c,r[i]])));
}
const sqlQ=s=>"'"+s.replace(/'/g,"''")+"'";
function build(input){
 const rows=csvParse(input);if(rows.length!==190)throw Error('BLOQUEO: se requieren 190 bloques');
 const keys=new Set();for(const r of rows){if(!/^MERCADERIA-C\d+$/.test(r.codigo_bloque)||keys.has(r.codigo_bloque))throw Error('Código repetido: '+r.codigo_bloque);keys.add(r.codigo_bloque);}
 const locked=rows.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:1).map(r=>r.codigo_bloque+'\t'+r.nombre_fuente.trim()+'\t'+r.duplicado_fuente+'\n').join('');
 if(createHash('sha256').update(locked).digest('hex')!==sha)throw Error('BLOQUEO: catálogo fuente diferente de MERCADERIA 2026(3)');
 let approved=0;
 const tuples=rows.map(r=>{
  if(!['IMPORTAR','EXCLUIR'].includes(r.decision)||r.revisor.trim().length<3||!/^\d{4}-\d\d-\d\d$/.test(r.fecha_aprobacion))throw Error('BLOQUEO: aprobación incompleta: '+r.codigo_bloque);
  if([r.nombre_aprobado,r.revisor].some(s=>/[\x00-\x1f]/.test(s)))throw Error('Caracteres inválidos');
  let name='NULL',location='NULL',qty='NULL';
  if(r.decision==='IMPORTAR'){
   if(!r.nombre_aprobado.trim()||!['Oficina','Bodega'].includes(r.ubicacion_aprobada)||!/^(0|[1-9]\d*)$/.test(r.cantidad_fisica)||!Number.isSafeInteger(Number(r.cantidad_fisica)))throw Error('BLOQUEO: nombre, ubicación o cantidad física: '+r.codigo_bloque);
   if(r.revision_duplicado!==(r.duplicado_fuente==='SI'?'SEPARADO':'NO_APLICA'))throw Error('BLOQUEO: duplicado sin revisión separada: '+r.codigo_bloque);
   name=sqlQ(r.nombre_aprobado.trim());location=r.ubicacion_aprobada==='Oficina'?'1':'2';qty=r.cantidad_fisica;approved++;
  }else if(r.cantidad_fisica.trim()||r.ubicacion_aprobada.trim())throw Error('BLOQUEO: excluido con stock: '+r.codigo_bloque);
  return '('+[sqlQ(r.codigo_bloque),name,location,qty,sqlQ(r.decision),sqlQ(r.revisor.trim())].join(',')+')';
 });
 if(!approved)throw Error('BLOQUEO: ningún artículo aprobado');
 const lines=[
 '-- CL Nexus / archivo PRIVADO: NO PUBLICAR. Solo ejecutar después de ensayar recuperación y autenticar roles.',
 'BEGIN;',"SET LOCAL lock_timeout='5s';",'LOCK TABLE public.inv_items,public.inv_stock IN SHARE ROW EXCLUSIVE MODE;',
 'CREATE TEMP TABLE cln_import (legacy_key text PRIMARY KEY,nombre text,location_id smallint,cantidad integer,decision text,revisor text) ON COMMIT DROP;',
 'INSERT INTO cln_import(legacy_key,nombre,location_id,cantidad,decision,revisor) VALUES',tuples.join(',\n')+';',
 'DO $guard$ BEGIN',
 "IF (SELECT count(*) FROM cln_import)<>190 THEN RAISE EXCEPTION 'MERCADERIA incompleta'; END IF;",
 "IF EXISTS(SELECT 1 FROM public.inv_items) OR EXISTS(SELECT 1 FROM public.inv_stock) THEN RAISE EXCEPTION 'Stock no vacío; no se puede repetir carga'; END IF;",
 "IF NOT EXISTS(SELECT 1 FROM public.inv_members WHERE rol='admin') OR NOT EXISTS(SELECT 1 FROM public.inv_members WHERE rol='secretaria') THEN RAISE EXCEPTION 'Roles no autorizados'; END IF;",
 "IF (SELECT count(*) FROM public.inv_locations WHERE id IN (1,2))<>2 THEN RAISE EXCEPTION 'Ubicaciones incompletas'; END IF;",
 'END $guard$;',
 "INSERT INTO public.inv_items(nombre_original,legacy_key) SELECT nombre,legacy_key FROM cln_import WHERE decision='IMPORTAR';",
 "INSERT INTO public.inv_stock(item_id,location_id,cantidad) SELECT i.id,s.location_id,s.cantidad FROM cln_import s JOIN public.inv_items i ON i.legacy_key=s.legacy_key WHERE s.decision='IMPORTAR';",
 'DO $verify$ DECLARE n integer; total bigint; BEGIN',
 "SELECT count(*),coalesce(sum(cantidad),0) INTO n,total FROM cln_import WHERE decision='IMPORTAR';",
 "IF (SELECT count(*) FROM public.inv_items)<>n OR (SELECT count(*) FROM public.inv_stock)<>n OR (SELECT coalesce(sum(cantidad),0) FROM public.inv_stock)<>total THEN RAISE EXCEPTION 'Verificación fallida'; END IF;",
 "IF EXISTS(SELECT 1 FROM public.inv_stock WHERE location_id NOT IN (1,2)) THEN RAISE EXCEPTION 'Garantía/Proveedor no pueden tener stock inicial'; END IF;",
 'END $verify$;','COMMIT;'
 ];
 return {sql:lines.join('\n')+'\n',approved};
}
if(process.argv[1]?.endsWith('prepare-cln-inventory-import.mjs')){
 try{if(process.argv.length!==4||!process.argv[3].endsWith('.clnimport.sql'))throw Error('Uso: node scripts/prepare-cln-inventory-import.mjs entrada.csv salida.clnimport.sql');
 const result=build(fs.readFileSync(process.argv[2],'utf8'));fs.writeFileSync(process.argv[3],result.sql,{flag:'wx',mode:0o600});console.log('Preparado para ENSAYO (NO EJECUTADO): '+result.approved+' artículos.');}
 catch(e){console.error(e.message);process.exitCode=1}
}
export {build,csvParse,cols};
