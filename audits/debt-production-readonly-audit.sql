-- CL Nexus / Deudas: auditoría de seguridad, SOLO LECTURA.
-- Ejecutar en el proyecto Supabase seleccionado. No cambia políticas ni datos.
-- NO sustituye pruebas con sesiones reales.
select current_database() as database_name;
select c.relname as table_name,c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('debts','workspace_members')
  and c.relkind in ('r','p')
order by c.relname;
select c.relname as table_name,p.polname as policy_name,p.polcmd as command,
       pg_get_expr(p.polqual,p.polrelid) as using_expression,
       pg_get_expr(p.polwithcheck,p.polrelid) as check_expression
from pg_policy p join pg_class c on c.oid=p.polrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='debts'
order by p.polcmd,p.polname;
select p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
and (p.proname like 'debt_%' or p.proname='is_workspace_member')
order by p.proname;
-- Interpretación: membresía no equivale a autorización por contraseña adicional.
-- Antes del corte: comprobar revocación de sesión, RLS CRUD, caché offline,
-- respaldo, concurrencia, canales realtime y sincronización PC/teléfono.
-- No activar DEBT_GATE_ENABLED hasta tener RPC productivas, RLS y pruebas reales.
