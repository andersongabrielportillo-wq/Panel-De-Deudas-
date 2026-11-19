// Synthetic 190-item catalog fixture for disposable CI only. No real business data.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {cols} from '../../scripts/prepare-cln-inventory-import.mjs';
import {buildCatalog} from '../../scripts/prepare-cln-catalog-2026-3.mjs';
const rows=Array.from({length:190},(_,i)=>({
 codigo_bloque:'MERCADERIA-C'+(i+2),
 nombre_fuente:i<5?'':i<10?'FICTICIO DUPLICADO':'FICTICIO ITEM '+i,
 duplicado_fuente:i>=5&&i<10?'SI':'NO',
 nombre_aprobado:'',ubicacion_aprobada:'',cantidad_fisica:'',decision:'PENDIENTE',
 revision_duplicado:'PENDIENTE',revisor:'',fecha_aprobacion:''
}));
const sha=createHash('sha256').update(rows.slice().sort((a,b)=>a.codigo_bloque<b.codigo_bloque?-1:1)
 .map(r=>r.codigo_bloque+'\t'+r.nombre_fuente+'\t'+r.duplicado_fuente+'\n').join('')).digest('hex');
const csv=[cols.join(','),...rows.map(r=>cols.map(k=>'"'+String(r[k]).replaceAll('"','""')+'"').join(','))].join('\n')+'\n';
const out=buildCatalog(csv,sha);
if(!process.argv[2]?.endsWith('.clncatalog.sql'))throw Error('Synthetic .clncatalog.sql destination required');
fs.writeFileSync(process.argv[2],out.sql,{flag:'wx'});
console.log('SYNTHETIC CATALOG: '+out.items+' names, '+out.unnamed+' pending, zero quantity entries');
