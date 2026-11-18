-- READ ONLY: inspect debt RLS policy structure, never customer data.
-- Compare the returned commands and roles to the expected four authenticated
-- PERMISSIVE membership policies before testing the restrictive gate policy.
SELECT policyname,permissive,roles,cmd,
       (qual IS NOT NULL) AS has_using,
       (with_check IS NOT NULL) AS has_with_check
FROM pg_policies
WHERE schemaname='public' AND tablename='debts'
ORDER BY cmd,policyname;
-- Expected before cutover: SELECT/INSERT/UPDATE/DELETE, authenticated only,
-- membership-based USING / WITH CHECK as appropriate. Review the policy
-- expressions separately before proceeding. No production mutation.
