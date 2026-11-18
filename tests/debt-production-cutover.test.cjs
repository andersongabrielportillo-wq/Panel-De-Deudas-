'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const sql=fs.readFileSync(path.join(__dirname,'../sql/deudas_gate_produccion_BORRADOR_NO_EJECUTAR.sql'),'utf8');
const preflight=fs.readFileSync(path.join(__dirname,'../sql/deudas_preflight_SOLO_LECTURA.sql'),'utf8');
const policyAudit=fs.readFileSync(path.join(__dirname,'../sql/deudas_auditoria_rls_SOLO_LECTURA.sql'),'utf8');
const checklist=fs.readFileSync(path.join(__dirname,'../docs/CORTE_SEGURO_DEUDAS_NO_EJECUTAR.md'),'utf8');

test('production debt gate migration remains explicitly manual and fail-closed',()=>{
 assert.match(sql,/DO NOT RUN ON PRODUCTION/);
 assert.match(sql,/BEGIN;/);
 assert.match(sql,/CREATE POLICY debts_require_extra_unlock ON public\.debts\s+AS RESTRICTIVE FOR ALL TO authenticated/);
 assert.match(sql,/WITH CHECK \(public\.debt_access_valid\(workspace_id\)\)/);
 assert.match(sql,/REVOKE ALL ON ALL TABLES IN SCHEMA debt_gate_secure FROM PUBLIC, anon, authenticated/);
 assert.match(sql,/REVOKE ALL ON SCHEMA debt_gate_secure FROM PUBLIC, anon, authenticated/);
 assert.match(sql,/session_id/);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+debt_gate_secure\.secrets/i,'password hash must not be committed in migration');
});

test('preflight is metadata-only and safe on absent staging tables',()=>{
 assert.match(preflight,/to_regclass\('public\.debts'\)/);
 assert.match(preflight,/to_regclass\('public\.workspaces'\)/);
 assert.match(preflight,/to_regclass\('public\.workspace_members'\)/);
 assert.doesNotMatch(preflight,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE|ALTER|DROP|CREATE)\s+(?:TABLE|FROM|INTO|SCHEMA|POLICY|FUNCTION|ON|public\.)/i);
 assert.doesNotMatch(preflight,/SELECT\s+\*\s+FROM\s+public\.debts/i);
});

test('cutover checklist explicitly blocks schema mismatch and missing backups',()=>{
 assert.match(checklist,/BLOQUEADO/);
 assert.match(checklist,/respaldo.*nube/i);
 assert.match(checklist,/respaldo.*local cifrado/i);
 assert.match(checklist,/NO MIGRAR/);
 assert.match(checklist,/aprobación explícita/i);
});

test('RLS policy audit reads metadata only and checks membership policy shapes',()=>{
 assert.match(policyAudit,/FROM pg_policies/);
 assert.match(policyAudit,/permissive,roles,cmd/);
 assert.match(policyAudit,/has_with_check/);
 assert.doesNotMatch(policyAudit,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE|ALTER|DROP|CREATE)\s+(?:TABLE|FROM|INTO|SCHEMA|POLICY|FUNCTION|ON|public\.)/i);
});

test('malformed or missing JWT session IDs cannot cause an unguarded UUID cast',()=>{
 assert.doesNotMatch(sql,/NULLIF\(auth\.jwt\(\)->>'session_id',''\)\)::uuid/);
 assert.equal((sql.match(/CASE WHEN COALESCE\(\(auth\.jwt\(\)->>'session_id'\) ~\*/g)||[]).length,3);
 assert.equal((sql.match(/\[0-9a-f\]\{12\}\$'\,false\)/g)||[]).length,4,'all UUID patterns must retain closing anchor');
 assert.match(sql,/ELSE NULL END/);
});
