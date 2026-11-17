# Auditoría de solo lectura — 2026-11-17

## Alcance y seguridad
Consultas de catálogo PostgreSQL mediante conector Supabase en proyecto `dozcnytevqhoymzqlxah` («Comercial Lopez Pruebas»). No se ejecutaron RPC modificadoras, migraciones, operaciones de inventario, cambios de roles ni despliegues. Proyecto «Panel de Deudas» separado: `josdmjjbnrugiwlwgjky`. `list_branches` del proyecto de pruebas devolvió `[]`.

## Consulta
```sql
select n.nspname,p.proname,p.prosecdef,p.proconfig,
 pg_get_function_identity_arguments(p.oid) args,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_exec,
 has_function_privilege('authenticated',p.oid,'EXECUTE') auth_exec,
 md5(pg_get_functiondef(p.oid)) hash
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and (p.proname like 'inv_%' or p.proname like 'cl2_%')
order by p.proname;
```

## Observaciones verificadas
- 44 funciones coincidentes: 37 `inv_*` y 7 `cl2_*`.
- Ninguna concede EXECUTE al rol `anon` según `has_function_privilege`.
- 36 conceden EXECUTE a `authenticated`; 8 funciones internas no lo conceden.
- 43 usan `SECURITY DEFINER`; `inv_hash_solicitud_venta` no.
- Todas las 44 reportan `proconfig = ["search_path=\\\"\\\""]`.
- Huellas MD5 de funciones críticas (no equivalen a prueba de seguridad):
  - `inv_registrar_movimiento`: `f0233c01f056f0c8f90cdcd24b65d730`
  - `inv_liberar_garantia`: `2605a6d55f0563f4e59f67e59916996c`
  - `inv_registrar_venta`: `08b0b5cf946f2dcdb5c1d19d64348cc8`
  - `inv_anular_venta`: `c3566e118b8116dcf24b31a1ac2b679a`
  - `cl2_sandbox_warranty_release_safe`: `70be4b633ff32d3b204b6da585d9749a`

## Limitaciones y estado
Las concesiones SQL al rol `authenticated` no prueban autorización efectiva por identidad Administrador/Secretaria. No se probaron JWT de ambos usuarios. El proyecto de pruebas es un proyecto independiente, pero no está certificado que carezca de registros reales o dependencias comerciales. No se ejecutaron pruebas modificadoras exhaustivas de entradas, salidas, devoluciones, traslados, garantías, ventas, anulaciones, reparaciones, idempotencia o concurrencia. No se creó infraestructura adicional ni se incurrió en costos deliberados.

**Resultado: INCOMPLETO / NO APROBADO.** Próximos pasos: certificar aislamiento y carácter ficticio de datos y usuarios, verificar permisos efectivos con sesiones reales autorizadas y ejecutar matriz exhaustiva únicamente en entorno validado sin dependencia comercial.
