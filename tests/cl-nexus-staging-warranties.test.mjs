import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const html=readFileSync(new URL('../staging/index.html',import.meta.url),'utf8');
test('warranty staging exposes three operations only to signed-in test sessions',()=>{
 for(const id of ['warrantyLab','warrantyItem','warrantyQty','warrantyReason','warrantyRequestId','requestWarranty','approveWarranty','rejectWarranty','warrantyResult'])assert.ok(html.includes('id="'+id+'"'),id);
 assert.ok(html.includes('PROJECT="dozcnytevqhoymzqlxah"'));
 assert.ok(html.includes('if(!s||view!=="garantias")return'));
 assert.ok(html.includes('const token=await accessToken(s)'));
 assert.ok(html.includes('session!==s||authEpoch!==epoch||seq!==ticket'));
});
test('warranty writes use authenticated RPC and never debt or production tables',()=>{
 assert.ok(html.includes('rpc="inv_solicitar_devolucion"'));
 assert.ok(html.includes('rpc="inv_revisar_devolucion"'));
 assert.ok(html.includes('p_aprobar:kind==="approve"'));
 assert.ok(html.includes('"Authorization":"Bearer "+token'));
 assert.ok(html.includes('confirm("¿Confirmás esta operación exclusivamente sobre datos ficticios'));
 assert.ok(html.includes('/service_role|sb_secret_/i.test(k)'));
});
