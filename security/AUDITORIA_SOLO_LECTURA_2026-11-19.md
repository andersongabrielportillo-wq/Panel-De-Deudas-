# Auditoría segura — 2026-11-19 (parcial, NO APROBADA)

## Alcance
Solo consultas de metadatos PostgreSQL, sin DML, sin autenticación simulada, sin invocación de RPC modificadoras. No se alteraron proyectos ni se publicaron cambios.

## Inventario de proyectos (Supabase list_projects)
- Comercial Lopez Pruebas: dozcnytevqhoymzqlxah — INACTIVE. No se reactivó por incertidumbre de costos y dependencias.
- Panel de Deudas: josdmjjbnrugiwlwgjky — ACTIVE_HEALTHY. Se consultaron solo metadatos.
- CL Nexus Recuperacion Auth Vault TEMPORAL: mwtvmmbmudlswblwcnyj — ACTIVE_HEALTHY, creado 2026-11-19 03:30:10 UTC. Proyecto adicional detectado; no asumir que es sandbox de movimientos ni que es libre de datos reales.

## Consulta exacta ejecutada en los dos proyectos activos
```sql
select n.nspname as schema, count(*) as functions,
 count(*) filter(where p.prosecdef) as security_definer,
 count(*) filter(where has_function_privilege('anon',p.oid,'EXECUTE')) as anon_executable,
 count(*) filter(where has_function_privilege('authenticated',p.oid,'EXECUTE')) as authenticated_executable
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','sandbox')
group by 1 order by 1;
```

## Resultados
| Proyecto | Esquema | Funciones | SECURITY DEFINER | EXECUTE anon | EXECUTE authenticated |
|---|---|---:|---:|---:|---:|
| CL Nexus Recuperacion Auth Vault TEMPORAL | public | 37 | 36 | 0 | 29 |
| Panel de Deudas | public | 43 | 42 | 0 | 35 |

Nota: el rol SQL authenticated no equivale a una prueba de permisos efectivos de los perfiles Administrador y Secretaria. Estos conteos tampoco certifican la seguridad de los cuerpos de las funciones.

## Bloqueos y próximos controles
1. El proyecto de pruebas dedicado está INACTIVE; no reactivarlo sin garantía de costo cero y confirmación de no dependencia comercial.
2. El proyecto temporal Auth/Vault NO se considera automáticamente un sandbox de inventario: falta demostrar aislamiento, datos ficticios y ausencia de dependencia comercial.
3. Faltan pruebas JWT reales de Administrador/Secretaria y escenarios de rechazo.
4. Faltan ciclos completos de entradas, salidas, traslados, devoluciones, ajustes, garantías, ventas, anulaciones, concurrencia e idempotencia.
5. Auditoría de cuerpos y privilegios de funciones críticas continúa pendiente.

**Resultado general: INCOMPLETO / NO APROBADO.** No se modificó producción, no se ejecutaron movimientos, no se creó infraestructura ni se autorizó gasto.
