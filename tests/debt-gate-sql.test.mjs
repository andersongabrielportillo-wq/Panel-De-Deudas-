import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../docs/sql/debt-gate-review-only.sql',import.meta.url),'utf8');
test('corte RLS requiere hashes para todos los workspaces',()=>{
 assert.match(sql,/SELECT DISTINCT workspace_id FROM public\.workspace_members/);
 assert.match(sql,/NOT EXISTS \(SELECT 1 FROM debt_private\.secrets/);
 assert.match(sql,/CORTE CANCELADO: % workspace\(s\) sin hash/);
});
test('corte RLS rechaza políticas desconocidas antes de reemplazar las existentes',()=>{
 const guard=sql.indexOf('CORTE CANCELADO: existen');
 const drop=sql.indexOf('DROP POLICY IF EXISTS members_read_debts');
 assert.ok(guard>=0&&drop>guard);
 assert.match(sql,/policyname NOT IN \('members_read_debts'/);
});
test('las cuatro operaciones de Deudas requieren acceso desbloqueado',()=>{
 for(const action of ['SELECT','INSERT','UPDATE','DELETE']){
  assert.match(sql,new RegExp('FOR '+action+' TO authenticated'));
 }
 const gates=(sql.match(/public\.debt_access_valid\(workspace_id\)/g)||[]).length;
 assert.ok(gates>=6);
});
test('no se concede acceso anónimo a funciones de desbloqueo',()=>{
 for(const fn of ['debt_unlock','debt_lock','debt_access_valid'])
  assert.match(sql,new RegExp('REVOKE ALL ON FUNCTION public\\.'+fn+'\\('));
});
