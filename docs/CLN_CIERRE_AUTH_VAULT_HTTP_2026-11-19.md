# CL Nexus — cierre Auth/Vault y HTTP real (19 noviembre 2026)

**Estado: NO PUBLICAR TODAVÍA.** Se trabaja únicamente en la rama de integración. Ningún comando de este documento ejecuta una migración automáticamente.

## Pausa de laboratorio ejecutada con autorización (19 noviembre 2026)

- **Autorización explícita del propietario:** pausar TEMPORALMENTE solo el proyecto de LAB `Comercial Lopez Pruebas` para preparar ensayo real de recuperación Auth/Vault; NO borrar laboratorio, NO tocar producción.
- Acción efectiva `mcp__Supabase__pause_project` sobre el proyecto existente de LAB `dozcnytevqhoymzqlxah`: `success=true`. Verificación posterior de `get_project`: **`INACTIVE`**.
- Verificación simultánea de `Panel de Deudas` original `josdmjjbnrugiwlwgjky`: **`ACTIVE_HEALTHY`**. No se ejecutó SQL modificador, migración, borrado ni despliegue en producción.
- Supabase documenta que un proyecto pausado se puede **reanudar desde el panel con datos y configuración previos**, dentro de **90 días** de la pausa. Ref: https://supabase.com/docs/guides/platform/free-project-pausing
- Solo hay una organización accesible para el usuario, denominada `Panel de Deudas`, y todavía debe confirmar que será la organización de destino del ensayo. Verificar tarifa con `get_cost` antes de crear proyecto; NO aceptar un cobro no autorizado.
- Proyecto temporal de recuperación todavía **NO creado**; no se ha restaurado Auth/Vault ni extraído/copied ninguna clave raíz. NO-GO de publicación sigue vigente.
- Al terminar el ensayo de restauración: antes de reactivar LAB puede ser necesario retirar el proyecto temporal creado; **no eliminar ningún proyecto** sin nueva autorización explícita del propietario.

## Proyecto temporal creado con tarifa confirmada de USD 0 (19/11/2026)

- **Organización autorizada por el propietario:** `Panel de Deudas` (`cnvcdmwswsomivlafpok`).
- `get_organization` confirmó `plan=free`. `get_cost(type=project)` devolvió **amount=0, recurrence=monthly**. No se aceptó ningún cargo distinto de cero. El flujo de creación solicitó confirmación incluso para USD 0, que se obtuvo con `confirm_cost(0,monthly,project)`.
- `create_project` creó **CL Nexus Recuperacion Auth Vault TEMPORAL** con ID `mwtvmmbmudlswblwcnyj` en `us-west-1` (región disponible de la herramienta). `get_project` verificó `ACTIVE_HEALTHY`, Postgres 17.12.
- Comprobación de origen: `Panel de Deudas` `josdmjjbnrugiwlwgjky` está `ACTIVE_HEALTHY` (sin escrituras ni migraciones); `Comercial Lopez Pruebas` `dozcnytevqhoymzqlxah` permanece `INACTIVE` sin eliminarse.
- Revisión inicial del clon temporal mediante `SELECT`: `auth.users=0`, existe esquema Vault, `public.debts` y `public.inv_items` todavía no existen. **NO SE HA RESTAURADO NINGÚN BACKUP NI TRANSFERIDO LA CLAVE RAÍZ DE VAULT; la recuperación aún NO está aprobada**.
- Para preparar el traslado de clave sin enviarla a ChatGPT ni GitHub, se entregó al propietario el PowerShell local `CLN_Transferir_Clave_Vault_SOLO_TEMPORAL.ps1`. Su única operación modificadora es `PUT https://api.supabase.com/v1/projects/mwtvmmbmudlswblwcnyj/pgsodium` (GET desde producción, NUNCA escritura a producción), usando PAT solicitado de forma privada en Windows y sin imprimir ni guardar secretos. Requiere ejecución y validación por propietario; **no se ha ejecutado**.
- **Cuidado al importar**: el anterior `Panel_De_Deudas.dump` se creó con `pg_dump -Fc` y contiene esquemas internos de Supabase; no aplicar `pg_restore` íntegro sobre un Supabase nuevo sin revisar conflictos de roles/Auth. La ruta soportada por el proveedor usa `supabase db dump` filtrado `roles.sql`, `schema.sql`, `data.sql` + `psql --single-transaction` y el procedimiento separado de la clave de Vault. Documentación: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- Después de restaurar de verdad: ejecutar `sql/cln_auth_vault_recovery_check_SOLO_LECTURA.sql` **en el TEMPORAL** y exigir mismo hash de Deudas, 3 usuarios Auth y Vault descifrable; completar logins HTTP reales de las tres cuentas contra el TEMPORAL. NO reutilizar llaves API ni tokens de producción en la candidata.

## 1. Auth y Vault: evidencia verificada del proyecto original

- Proyecto original: `josdmjjbnrugiwlwgjky`. Organización en Supabase **Free**; existen **2 proyectos activos**: Panel de Deudas y Comercial Lopez Pruebas.
- Auditoría de producción de solo lectura: **3 Auth usuarios, 3 miembros, 1 deuda compartida, 0 transacciones**, Vault posee exactamente un `deudas_access_password` descifrable **en el proyecto de origen**. Huella comercial actual `cae1aed74556ce96dde7f673e33d4668`.
- El respaldo local del propietario `Panel_De_Deudas.dump` contiene datos de Auth y Vault; las cuatro tablas comerciales ya fueron restauradas y cotejadas, pero **Auth/Vault nunca se restauraron íntegramente en un destino equivalente**.
- Nueva comprobación `sql/cln_auth_vault_recovery_check_SOLO_LECTURA.sql` devuelve en origen `recovered_auth_vault_structural_ready=true`, `real_http_logins_approved=false`, `cutover_authorized=false`.
- La **clave raíz de Vault no viene en dumps**. El proyecto original debe mantenerse ACTIVO. La documentación oficial exige copiar la clave raíz a un nuevo proyecto en restauración manual con el API de Management; NO registrar ni enviar esa clave ni el PAT en GitHub/ChatGPT. Restauraciones de mismo proyecto conservan la clave; `Restore to new project` gestionado también la copia, pero requiere plan de pago/backup físico.
- **Salida Free sin destruir laboratorio:** con aprobación explícita del usuario, pausar TEMPORALMENTE `Comercial Lopez Pruebas` (NO borrar) para liberar uno de los dos cupos activos gratuitos. Crear un proyecto nuevo aislado para RESTAURACIÓN MANUAL y confirmar que Supabase ofrece coste $0. NO iniciar operaciones que cobren sin aprobación.
- Antes de usar el nuevo proyecto: verificar respaldo actualizado, transferencia manual privada de la clave raíz siguiendo docs oficiales, Auth configurada, políticas/roles y datos restaurados; ejecutar SQL de comparación, después 3 logins reales HTTP al clon. No sobreescribir nunca Lab o producción con `pg_restore`.
- Tras ensayar, borrar solo proyecto TEMPORAL con aprobación, reanudar LAB y conservar el original.

## 2. HTTP real: pruebas ya realizadas y pendientes

- Probeta `scripts/cln-http-anon-production-readonly.mjs` usó la **publishable key pública** contra la API real original (sin JWT): PASS. No se pueden leer `debts`, `transactions` o `workspaces` y no se puede ejecutar `has_debts_unlock` como anon. No se hicieron escrituras.
- Nuevo `cln-http-auth-probe.cjs` + botón **Verificar seguridad HTTP** en la candidata PWA. Usa SOLO el cliente Supabase ya autenticado del navegador; no requiere tokens ni contraseñas en chat. `auth.getUser()`, `rpc(has_debts_unlock)`, REST `debts` solo COUNT, `rpc(inv_catalogo_articulos_admin)`, `rpc(inv_catalogo_vendedores)`; no hace escrituras. Comprueba 0 filas visibles de Deudas cuando está bloqueado, 1 cuando está desbloqueado, 190 artículos y lectura del catálogo.
- Para validar **3 sesiones HTTP reales**, debe ejecutarse primero en CLON restaurado de extremo a extremo: login de las tres cuentas, bloqueado/0, desbloquear con contraseña adicional en la propia app/1, bloquear/0, salir, reiniciar sesión. No compartir tokens, contraseñas ni capturas que los incluyan. El laboratorio usó JWT simulado en SQL anteriormente; **eso NO es HTTP real**.
- En producción todavía no hay políticas RESTRICTIVE de Deudas ni funciones de inventario; botón de diagnóstico disponible SOLO en versión candidata, sin publicación.
- Los SQL de corte y rollback del gate `sql/deudas_gate_existing_production_rpc_*.sql` están ensayados en PostgreSQL descartable. Revertir políticas vuelve a la seguridad PREVIA (solo membresía), no recupera datos; volver inmediatamente a la PWA anterior y evaluar el estado de cachés, NO borrar datos locales pendientes.
- Antes de publicar, revisar el cache local `cp_v2` de cada dispositivo: el hecho de que la API RLS bloquee datos NO cifra automáticamente contenido local antiguo. Prohibido purgar pendientes antes de conciliar y respaldar.

## 3. Compuerta final coordinada

1. **NO GO**: hasta completar restauración/Auth/Vault real aislada y los tres inicios de sesión HTTP, con prueba de la contraseña adicional, datos intactos y estado de caché.
2. Backup fresco y huella comercial actual de origen, revisión de clientes offline/sincronización sin repetir pruebas antiguas inútilmente.
3. Congelar escrituras, instalar esquemas y roles 3 admin, solo catálogo de MERCADERIA (3) SIN stock ficticio. Activar RPC, políticas RESTRICTIVE y PWA compatible en secuencia coordinada.
4. Ejecutar inmediatamente botón HTTP por las tres cuentas y confirmar resultados sin datos privados; probar bloqueo/unlock y ventas denegadas sin stock.
5. En fallo: detener despliegue, revertir PWA + políticas y restablecer servicio. Nunca asumir que rollback SQL constituye restore integral.

**Fuentes oficiales:** 
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/guides/database/vault#key-portability-and-migration
- https://supabase.com/docs/guides/platform/clone-project
- https://supabase.com/docs/guides/platform/billing-on-supabase
