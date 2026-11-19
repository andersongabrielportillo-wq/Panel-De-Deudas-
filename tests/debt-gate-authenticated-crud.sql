-- Disposable CI only. Authenticated-role RLS CRUD: denied when locked, allowed after unlock.
-- Requires the synthetic fixture, gate migration and synthetic secret from prior CI steps.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT set_config('request.jwt.claims','{"session_id":"00000000-0000-0000-0000-000000000008"}',false);
DO $$
DECLARE changed integer; rejected boolean:=false;
BEGIN
 BEGIN
   INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
   VALUES('ci-write-denied','00000000-0000-0000-0000-000000000001','{}',
   '00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'Locked INSERT was allowed'; END IF;
 UPDATE public.debts SET data='{"modified":true}' WHERE id='ci-debt-1';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>0 THEN RAISE EXCEPTION 'Locked UPDATE changed rows'; END IF;
 DELETE FROM public.debts WHERE id='ci-debt-1';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>0 THEN RAISE EXCEPTION 'Locked DELETE changed rows'; END IF;
END $$;
SELECT public.debt_unlock('00000000-0000-0000-0000-000000000001','synthetic-password');
DO $$
DECLARE changed integer;
BEGIN
 INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
 VALUES('ci-write-allowed','00000000-0000-0000-0000-000000000001','{"new":true}',
 '00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 UPDATE public.debts SET data='{"modified":true}',updated_by='00000000-0000-0000-0000-000000000002'
 WHERE id='ci-write-allowed';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'Unlocked UPDATE failed'; END IF;
 DELETE FROM public.debts WHERE id='ci-write-allowed';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'Unlocked DELETE failed'; END IF;
END $$;
SELECT public.debt_lock('00000000-0000-0000-0000-000000000001');
DO $$
DECLARE rejected boolean:=false; changed integer;
BEGIN
 BEGIN
   INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
   VALUES('ci-write-relocked','00000000-0000-0000-0000-000000000001','{}',
   '00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'Relocked INSERT was allowed'; END IF;
 UPDATE public.debts SET data='{}' WHERE id='ci-debt-1';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>0 THEN RAISE EXCEPTION 'Relocked UPDATE changed rows'; END IF;
 DELETE FROM public.debts WHERE id='ci-debt-1';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>0 THEN RAISE EXCEPTION 'Relocked DELETE changed rows'; END IF;
END $$;
RESET ROLE;
