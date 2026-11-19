// PRIVATE OFFLINE converter for the latest INVENTARIO INICIAL 2026(3).xlsx -> MERCADERIA only.
// Generates a PRODUCT CATALOG; no quantities, sales, vendors, history, warranty, or stock records.
// No database connections here. Source CSV stays on owner's machine; never commit generated SQL.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {csvParse} from './prepare-cln-inventory-import.mjs';
const FINGERPRINT='d6cfa1e2dad5ef9d0c9ba5f5b6186b984084ffd7e02447878048ec0268fa6cdd';
const quote=x=>"'"+String(x).replaceAll("'","''")+"'";
function buildCatalog(csv,expectedFingerprint=FINGERPRINT){
 const rows=csvParse(csv);
 if(rows.length!==190)throw Error('CATALOGO BLOQUEADO: MERCADERIA (3) debe contener 190 bloques');
 const seen=new Set();
 for(const r of rows){
  if(!/^MERCADERIA-C\d+$/.test(r.codigo_bloque)||seen.has(r.codigo_bloque))
   throw Error('CATALOGO BLOQUEADO: código inválido o duplicado '+r.codigo_bloque);
  if(!['SI','NO'].includes(r.duplicado_fuente))throw Error('CATALOGO BLOQUEADO: marca de duplicado inválida');
  seen.add(r.codigo_bloque);
 }
 const manifest=rows.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:a.codigo_bloque>b.codigo_bloque?1:0)
  .map(r=>r.codigo_bloque+'\t'+r.nombre_fuente.trim()+'\t'+r.duplicado_fuente+'\n').join('');
 if(createHash('sha256').update(manifest).digest('hex')!==expectedFingerprint)
  throw Error('CATALOGO BLOQUEADO: archivo fuente diferente de MERCADERIA 2026(3)');
 let unnamed=0;
 const tuples=rows.map(r=>{
  const original=r.nombre_fuente.trim();
  if(/[\x00-\x1f]/.test(original))throw Error('CATALOGO BLOQUEADO: caracter de control en '+r.codigo_bloque);
  if(original.length>200)throw Error('CATALOGO BLOQUEADO: nombre excesivo');
  const name=original || ('NOMBRE PENDIENTE · '+r.codigo_bloque);
  if(!original)unnamed++;
  return '('+quote(r.codigo_bloque)+','+quote(name)+')';
 });
 const sql=[
  '-- CL Nexus MERCADERIA (3), archivo PRIVADO generado desde CSV real. NUNCA subir a GitHub.',
  '-- SOLO CATALOGO: no se asignan existencias físicas desconocidas, movimientos ni vendedores.',
  '-- Los cinco nombres faltantes se representan con NOMBRE PENDIENTE + código original; corregir dentro de la PWA.',
  '-- NO ejecutar hasta la restauracion y el ensayo de corte integral. La prueba CI solo usa datos sinteticos.',
  'BEGIN;',
  "SET LOCAL lock_timeout = '5s';",
  "SET LOCAL statement_timeout = '60s';",
  'LOCK TABLE public.inv_items,public.inv_stock IN SHARE ROW EXCLUSIVE MODE;',
  'CREATE TEMP TABLE cln_catalog(legacy_key text PRIMARY KEY, nombre text NOT NULL) ON COMMIT DROP;',
  'INSERT INTO cln_catalog(legacy_key,nombre) VALUES',
  tuples.join(',\n')+';',
  'DO $guard$ BEGIN',
  " IF (SELECT count(*) FROM public.inv_members WHERE rol='admin')<>3 OR (SELECT count(*) FROM public.inv_members)<>3 THEN RAISE EXCEPTION 'Los 3 administradores de Deudas deben estar autorizados antes de importar'; END IF;",
  " IF (SELECT count(*) FROM cln_catalog)<>190 THEN RAISE EXCEPTION 'Catalogo no contiene 190 bloques'; END IF;",
  " IF EXISTS(SELECT 1 FROM public.inv_items) OR EXISTS(SELECT 1 FROM public.inv_stock) THEN RAISE EXCEPTION 'Catalogo o stock existentes: se prohíbe la importación repetida'; END IF;",
  " IF NOT EXISTS(SELECT 1 FROM public.inv_locations WHERE id=1 AND nombre='Oficina') THEN RAISE EXCEPTION 'No existe la ubicacion Oficina'; END IF;",
  " IF EXISTS(SELECT 1 FROM cln_catalog WHERE btrim(nombre)='') THEN RAISE EXCEPTION 'Nombre vacío'; END IF;",
  'END $guard$;',
  'INSERT INTO public.inv_items(legacy_key,nombre_original,categoria,estado) SELECT legacy_key,nombre,NULL,\'activo\' FROM cln_catalog;',
  'DO $verify$ BEGIN',
  " IF (SELECT count(*) FROM public.inv_items)<>190 OR EXISTS(SELECT 1 FROM public.inv_stock) THEN RAISE EXCEPTION 'Catalogo no validado o stock no autorizado'; END IF;",
  " IF EXISTS(SELECT legacy_key FROM cln_catalog EXCEPT SELECT legacy_key FROM public.inv_items) THEN RAISE EXCEPTION 'Faltan códigos de origen'; END IF;",
  'END $verify$;',
  'COMMIT;'
 ].join('\n')+'\n';
 return {sql,items:rows.length,unnamed};
}
if(process.argv[1]?.endsWith('prepare-cln-catalog-2026-3.mjs')){
 try{
  if(process.argv.length!==4||!process.argv[3].endsWith('.clncatalog.sql'))throw Error('Uso: node scripts/prepare-cln-catalog-2026-3.mjs entrada.csv salida.clncatalog.sql');
  const result=buildCatalog(fs.readFileSync(process.argv[2],'utf8'));
  fs.writeFileSync(process.argv[3],result.sql,{flag:'wx',mode:0o600});
  console.log('CATALOGO PRIVADO PREPARADO: '+result.items+' artículos, '+result.unnamed+' sin nombre, CERO existencias creadas. NO EJECUTADO.');
 }catch(e){console.error(e.message);process.exitCode=1}
}
export {buildCatalog};
