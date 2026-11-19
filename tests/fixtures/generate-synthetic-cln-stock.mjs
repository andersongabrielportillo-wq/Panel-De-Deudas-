// Synthetic test fixture only: fake articles / fake reviewer / fake quantities.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {build,cols} from '../../scripts/prepare-cln-inventory-import.mjs';
const lines=Array.from({length:190},(_,i)=>({
 codigo_bloque:'MERCADERIA-C'+(i+2),
 nombre_fuente:'FAKE_ITEM_'+i,
 duplicado_fuente:i<2?'SI':'NO',
 nombre_aprobado:'ARTICULO FICTICIO '+(i<2?'DUPLICADO':i),
 ubicacion_aprobada:i<95?'Oficina':'Bodega',
 cantidad_fisica:'2',
 decision:'IMPORTAR',
 revision_duplicado:i<2?'SEPARADO':'NO_APLICA',
 revisor:'CI SINTETICO',
 fecha_aprobacion:'2026-11-18'
}));
const hash=createHash('sha256').update(lines.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:1).map(r=>r.codigo_bloque+'\t'+r.nombre_fuente+'\t'+r.duplicado_fuente+'\n').join('')).digest('hex');
const csv=[cols.join(','),...lines.map(r=>cols.map(c=>'"'+String(r[c]).replaceAll('"','""')+'"').join(','))].join('\n')+'\n';
const prepared=build(csv,hash);
if(prepared.approved!==190)throw Error('Expected 190 synthetic items');
const dest=process.argv[2];
if(!dest||!dest.endsWith('.clnimport.sql'))throw Error('Provide only synthetic SQL destination');
fs.writeFileSync(dest,prepared.sql,{flag:'wx'});
console.log('Prepared completely fake 190-row CL Nexus import for isolated PostgreSQL test');
