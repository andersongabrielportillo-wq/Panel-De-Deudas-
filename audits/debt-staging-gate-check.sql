-- CL Nexus / Deudas: comprobación estructural de seguridad en LABORATORIO.
-- Solo lectura. No simula sesiones JWT ni sustituye pruebas API autenticadas.
WITH ops(command,policy_name) AS (
 VALUES ('r','debt_lab_read'),('a','debt_lab_insert'),
        ('w','debt_lab_update'),('d','debt_lab_delete')
), actual AS (
 SELECT p.polcmd,p.polname,
        coalesce(pg_get_expr(p.polqual,p.polrelid),'') AS using_expr,
        coalesce(pg_get_expr(p.polwithcheck,p.polrelid),'') AS check_expr
 FROM pg_policy p WHERE p.polrelid='debt_gate_lab.debts'::regclass
)
SELECT ops.command,ops.policy_name,
 CASE WHEN ops.command IN ('r','d') THEN position('debt_lab_access_valid(workspace_id)' in actual.using_expr)>0
      WHEN ops.command='a' THEN position('debt_lab_access_valid(workspace_id)' in actual.check_expr)>0
      WHEN ops.command='w' THEN position('debt_lab_access_valid(workspace_id)' in actual.using_expr)>0
                               AND position('debt_lab_access_valid(workspace_id)' in actual.check_expr)>0
 END AS gate_required
FROM ops LEFT JOIN actual ON actual.polcmd=ops.command AND actual.polname=ops.policy_name
ORDER BY ops.command;
SELECT p.proname,
       p.prosecdef AS security_definer,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
       p.proconfig AS function_settings
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('debt_lab_unlock','debt_lab_lock','debt_lab_access_valid')
ORDER BY p.proname;
SELECT count(*) AS lab_workspace_count,
 (SELECT count(*) FROM debt_gate_lab.members m WHERE m.workspace_id='558d6109-b592-4c75-a6ef-2f4143ef64ec') AS authorized_members,
 (SELECT count(*) FROM debt_gate_lab.secrets s WHERE s.workspace_id='558d6109-b592-4c75-a6ef-2f4143ef64ec') AS configured_passwords
FROM debt_gate_lab.workspaces w WHERE w.id='558d6109-b592-4c75-a6ef-2f4143ef64ec';
-- Antes de la publicación: verificar con JWT reales el acceso denegado sin desbloqueo,
-- desbloqueo, lectura, escritura, revocación al cerrar sesión, expiración y realtime.
