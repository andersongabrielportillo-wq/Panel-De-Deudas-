-- ETAPA 1 instalada en producción. NO EJECUTAR ETAPA 2 sin despliegue coordinado.
-- PREPARACION. NO EJECUTAR EN PRODUCCION HASTA QUE LA NUEVA PWA ESTE LISTA.
-- Requiere Vault: deudas_access_password. No contiene contraseñas.
-- Etapa 1: instalar funciones/tablas sin modificar RLS existente.
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;
create table if not exists app_private.debt_unlocks (
 user_id uuid not null,
 session_id uuid not null,
 expires_at timestamptz not null,
 primary key (user_id, session_id)
);
create table if not exists app_private.debt_attempts (
 user_id uuid primary key,
 failed_count integer not null default 0,
 window_started_at timestamptz not null default now(),
 blocked_until timestamptz
);
revoke all on all tables in schema app_private from public, anon, authenticated;
alter table app_private.debt_unlocks enable row level security;
alter table app_private.debt_attempts enable row level security;
create or replace function public.unlock_debts(p_password text)
returns boolean language plpgsql security definer
set search_path = '' as $$
declare
 v_uid uuid := auth.uid();
 v_sid uuid;
 v_secret text;
 v_attempt app_private.debt_attempts%rowtype;
begin
 if v_uid is null then raise exception 'Autenticacion requerida'; end if;
 begin v_sid := (auth.jwt()->>'session_id')::uuid;
 exception when others then raise exception 'Sesion invalida'; end;
 if v_sid is null then raise exception 'Sesion requerida'; end if;
 if not exists (select 1 from auth.sessions s where s.id=v_sid and s.user_id=v_uid) then raise exception 'Sesion no activa'; end if;
 if not exists (select 1 from public.workspace_members where user_id=v_uid) then
   raise exception 'No autorizado';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 7291));
 select * into v_attempt from app_private.debt_attempts where user_id=v_uid;
 if v_attempt.blocked_until > now() then return false; end if;
 select decrypted_secret into v_secret from vault.decrypted_secrets
 where name='deudas_access_password' limit 1;
 if v_secret is null then raise exception 'Acceso no configurado'; end if;
 if p_password is not null and
    encode(extensions.digest(convert_to(p_password,'UTF8'),'sha256'),'hex') =
    encode(extensions.digest(convert_to(v_secret,'UTF8'),'sha256'),'hex') then
   insert into app_private.debt_unlocks(user_id,session_id,expires_at)
   values(v_uid,v_sid,now()+interval '15 minutes')
   on conflict(user_id,session_id) do update set expires_at=excluded.expires_at;
   delete from app_private.debt_attempts where user_id=v_uid;
   return true;
 end if;
 insert into app_private.debt_attempts(user_id,failed_count,window_started_at,blocked_until)
 values(v_uid,1,now(),null)
 on conflict(user_id) do update
 set failed_count=case when app_private.debt_attempts.window_started_at < now()-interval '15 minutes'
                      then 1 else app_private.debt_attempts.failed_count+1 end,
 window_started_at=case when app_private.debt_attempts.window_started_at < now()-interval '15 minutes'
                      then now() else app_private.debt_attempts.window_started_at end,
 blocked_until=case when app_private.debt_attempts.window_started_at >= now()-interval '15 minutes'
                        and app_private.debt_attempts.failed_count+1 >= 5
                    then now()+interval '15 minutes' else null end;
 return false;
end $$;
revoke all on function public.unlock_debts(text) from public, anon;
grant execute on function public.unlock_debts(text) to authenticated;

create or replace function public.has_debts_unlock()
returns boolean language sql stable security definer
set search_path = '' as $$
 select auth.uid() is not null
 and nullif(auth.jwt()->>'session_id','') is not null
 and exists (
 select 1 from app_private.debt_unlocks u
 where u.user_id=auth.uid()
 and u.session_id=(auth.jwt()->>'session_id')::uuid
 and u.expires_at > now()
 and exists (select 1 from auth.sessions s where s.id=u.session_id and s.user_id=u.user_id)
 )
$$;
revoke all on function public.has_debts_unlock() from public, anon;
grant execute on function public.has_debts_unlock() to authenticated;

create or replace function public.lock_debts()
returns void language plpgsql security definer
set search_path = '' as $$
begin
 delete from app_private.debt_unlocks
 where user_id=auth.uid()
 and session_id=(auth.jwt()->>'session_id')::uuid;
end $$;
revoke all on function public.lock_debts() from public, anon;
grant execute on function public.lock_debts() to authenticated;

