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

## Transferencia Vault al proyecto temporal: API aceptada (19/11/2026)

- El propietario ejecutó **en su PC**, sin entregar token ni secretos, el PowerShell de traslado de pgsodium. La captura devuelve `TRANSFERENCIA ACEPTADA POR LA API DE SUPABASE` tras consultar el proyecto original y enviar la clave **exclusivamente al temporal** `mwtvmmbmudlswblwcnyj`. Las verificaciones de permisos anteriores fueron HTTP 200 en origen, destino y `GET /pgsodium`. **No se han copiado registros Auth ni Vault ni se ha demostrado descifrado después de restaurar; el resultado del PUT por sí solo no constituye recuperación integral.**
- Comprobación posterior de estado: producción `josdmjjbnrugiwlwgjky` `ACTIVE_HEALTHY`, temporal `ACTIVE_HEALTHY`, laboratorio `dozcnytevqhoymzqlxah` `INACTIVE`. Consulta SQL solo lectura del temporal: **0 usuarios Auth, 0 secretos Vault, no existen las tablas de Deudas**. El origen mantiene 3 Auth, 3 miembros, 1 fila de Deudas, 0 movimientos, md5 de Deudas `cae1aed74556ce96dde7f673e33d4668` y Vault descifrable en ORIGEN.
- **Siguiente paso seguro:** ejecutar en el equipo del propietario un preflight local **sin transferencias ni escrituras** que detecte `supabase`, Docker, `pg_restore` y existencia/integridad del .dump. Si existen las herramientas, proceder con un respaldo fresco (la guía oficial `supabase db dump --db-url ...` en roles/schema/data, NO la variante `--remote` usada en un asistente anterior) y un plan de restauración aislada sin sobrescribir esquemas administrados por Supabase a ciegas.
- **Barrera de seguridad:** NO ejecutar el dump crudo `pg_restore` completo contra el clon gestionado; incluye esquemas internos de Supabase. El siguiente cambio con escritura será solamente en el proyecto TEMPORAL después de validar el método y su conexión; NUNCA a producción. No publicar CL Nexus hasta las tres sesiones HTTP reales y comprobación de Vault descifrable en el destino.

## Preflight local tras traslado de clave (19 noviembre 2026)

- El usuario ejecutó **CLN_Preflight_Restauracion_Auth_Vault_SOLO_LECTURA.ps1** en Windows y compartió solo sus resultados (sin respaldos ni secretos): **Supabase CLI 3.2.0 SÍ; pg_restore SÍ; Docker Desktop/comando NO detectado; respaldo .dump SÍ, 441291 bytes, pg_restore --list legible**. Catálogo del backup incluye `auth.users`, `vault.secrets` cifrados, `public.debts` y `public.workspace_members`.
- **SHA-256 del archivo local no coincide con la referencia de la copia revisada anteriormente.** No inferir automáticamente corrupción: un backup distinto puede ser íntegro, pero no constituye una copia binariamente idéntica. Conciliar el contenido comercial y, para un corte definitivo, generar respaldo fresco.
- La guía oficial `Backup and Restore using the CLI` **requiere Docker Desktop** para `supabase db dump --db-url ...`; esta utilidad genera roles/schema/data con filtros especiales. **NO ejecutar `pg_restore` indiscriminadamente contra el proyecto temporal**: un dump crudo de `pg_dump -Fc` incluye objetos internos administrados que podrían crear conflictos.
- **Comprobación estructural adicional SIN escrituras:** se compararon en SQL los 76 atributos de columnas para `auth.users`, `auth.identities`, `auth.sessions`, `auth.refresh_tokens` y `vault.secrets` entre origen y temporal. No se detectaron columnas faltantes, columnas adicionales ni incompatibilidades de tipo o nulabilidad. Esto apoya el plan de importación, pero NO equivale a restauración ni a prueba de login.
- Próximo paso en la PC del propietario: comprobar/instalar e iniciar Docker Desktop desde fuente oficial y confirmar que `docker version` responde correctamente. Luego preparar, **sin exponer contraseñas en el chat ni logs**, las copias `roles.sql`, `schema.sql`, `data.sql` mediante comandos oficiales y ensayar importación exclusiva al TEMPORAL en una transacción con `ON_ERROR_STOP`. Completar `Auth/Vault` + pruebas HTTP reales de los tres usuarios ANTES de publicar.
- Los tres proyectos mantienen sus roles: producción activa intacta, LAB pausado, recuperación temporal aislada activa. No hubo importaciones ni modificación de origen en esta etapa.

## Camino sin Docker — respaldos selectivos, sin tocar producción

- Decisión del propietario: **continuar sin instalar Docker**. `pg_restore` local puede inspeccionar el archivo `.dump` en modo de solo lectura; la restauración directa COMPLETA de un archivo `pg_dump -Fc` sobre Supabase gestionado está prohibida por el riesgo de duplicar los esquemas internos de Auth/Vault.
- Comprobación SOLO LECTURA de la base original: `auth.users=3`, `auth.identities=3`, `vault.secrets=1`, `public.debts=1`, huella MD5 `cae1aed74556ce96dde7f673e33d4668`. El clon temporal no contiene usuarios ni secretos hasta importar datos.
- Se generó y entregó al propietario `CLN_Preparar_Restauracion_Selectiva_SIN_DOCKER_SOLO_LECTURA.ps1`. En Windows, usando solo `pg_restore --list`, exige que el backup contenga exactamente una entrada de `TABLE DATA` para cada una de las **7 tablas**: `auth.users`, `auth.identities`, `vault.secrets`, `public.workspaces`, `public.workspace_members`, `public.debts`, `public.transactions`. Emite un informe sin datos privados y un archivo local de índices TOC no ejecutado. No pide token, contraseña o conexión.
- **Nunca migrar sesiones antiguas ni intentos/desbloqueos temporales**: excluir `auth.sessions`, `auth.refresh_tokens`, `auth.one_time_tokens`, `auth.mfa_factors` (no hay MFA de origen) y `app_private.debt_unlocks`, `app_private.debt_attempts`. Las tres personas tendrán que iniciar sesión de nuevo contra el clon con Auth original recuperada.
- **El script NO importa**, NO copia hashes de contraseñas a GitHub/ChatGPT y NO valida la estructura completa ni PK/FK/policies; requiere revisar el resultado y preparar un procedimiento de importación transaccional que instale antes las **tablas/funciones/políticas personalizadas** del proyecto original y deshabilite triggers solo en el destino cuando corresponda.
- El SHA-256 de la copia local difiere de un respaldo previo; no asumir equivalencia. Después de recuperar hay que cotejar contenidos en clon con la consulta solo lectura de origen e iniciar las tres sesiones HTTP reales. Mantener PWA en NO-GO hasta verificar Vault descifrable, controles RLS y copia funcional.

## Compatibilidad adicional del clon temporal (SQL read-only)

- Se compararon los **esquemas Auth/Vault existentes** entre origen y temporal: `auth.users` tiene las mismas **3 constraints, 15 índices y ningún trigger personalizado**; `auth.identities` tiene **3 constraints, 4 índices y ningún trigger personalizado**; `vault.secrets` tiene **1 constraint, 2 índices y ningún trigger personalizado**. Las definiciones de constraints e índices comparadas coincidieron, además de las 76 columnas ya contrastadas.
- La comparación NO revisa el contenido del `.dump` local ni implica que un `pg_restore` directo sea seguro. Tampoco valida extensiones de Vault, hash de contraseña ni login con sesión HTTP. La importación selectiva sólo avanzará cuando el propietario haya generado el informe del archivo local de siete bloques y se haya examinado la estructura personalizada de `public`/`app_private`.
- El backup `.dump` NO debe compartirse ni cargarse al repositorio. El informe preparado `CLN_INFORME_PARA_COMPARTIR_SIN_SECRETOS.txt` no incluye filas, contraseñas o claves.

## Siete bloques del respaldo verificados, conteos reales pendientes (19/11/2026)

- El propietario ejecutó en su PC el preparador selectivo sin Docker. Los siete resultados `auth.users`, `auth.identities`, `vault.secrets`, `public.workspaces`, `public.workspace_members`, `public.debts` y `public.transactions` dieron **OK** (una entrada TOC de `TABLE DATA` por cada tabla). Se creó la lista LOCAL `CLN_SELECCION_7_BLOQUES_DATOS_NO_EJECUTAR.toc`, sin exportar filas privadas. El respaldo ocupa **441291 bytes** y **su SHA-256 difiere** de la copia anteriormente registrada: no se puede aún asumir equivalencia de contenidos.
- El origen activo registra por `SELECT` de solo lectura los conteos esperados: `auth.users=3`, `auth.identities=3`, `vault.secrets=1`, `public.workspaces=1`, `public.workspace_members=3`, `public.debts=1`, `public.transactions=0`. El clon sigue separado, sin restauración aplicada.
- Siguiente prueba SIN Docker: script local `CLN_Validar_Contenido_7_Tablas_SIN_DOCKER_SOLO_LECTURA.ps1`. Usa el TOC generado y `pg_restore --data-only --use-list` **sin conectar a una base**; consume los `COPY ... FROM stdin` en memoria para contar filas y descartar todos sus valores. No escribe SQL ni lee tokens. Compara los conteos del respaldo contra los del origen; si difieren se bloquea el ensayo. Los resultados coincidentes **no bastarán** por sí solos para probar hashes de contraseñas, huella de Deudas, restauración de Vault ni inicios de sesión HTTP.
- Para restauración se requiere después: esquema comercial seguro del proyecto original en el clon, `psql` con conexión únicamente al proyecto temporal, copia selectiva de tablas sin sesiones ni tokens antiguos y ensayo real del descifrado, RLS y sesiones HTTP. **No ejecutar automáticamente el TOC ni el archivo SQL completo de pg_restore contra un Supabase administrado**.

## Diagnóstico de archivo de respaldo — selección --use-list fallida (19/11/2026)

- El propietario verificó el .dump en Windows: los **7 TABLE DATA** están en el índice. Sin embargo, los validadores V1 y V2 no pudieron leer ningún bloque COPY: pg_restore con --use-list devolvió **exit 1**, **0/7 cabeceras y 0/7 cierres**. NO se ejecutó restauración ni escritura.
- Este error, por sí solo, **no permite determinar** si falla la lista TOC, un argumento de pg_restore, el archivo comprimido o su contenido. El SHA de esta copia no coincide con la referencia del respaldo anterior; por lo tanto no se ha validado la integridad de los registros.
- Se entregó el validador local CLN_Validar_7_Tablas_V3_SIN_TOC_SOLO_LECTURA.ps1, que prueba una ruta diferente del TOC: usa pg_restore --data-only --schema=<schema> --table=<table> por separado, captura únicamente conteos o categorías de error y no muestra filas ni secretos. No utiliza -d/--dbname, conexión, Docker, tokens ni escribe SQL. Opción -n -t documentada por PostgreSQL 17: https://www.postgresql.org/docs/17/app-pgrestore.html
- El resultado de V3 determinará si la falla era específica del --use-list o si el problema está en el archivo/lector. Si V3 también falla, no iterar ciegamente: revisar versión y error de PostgreSQL con diagnóstico seguro o generar respaldo nuevo desde el original.
- NO GO hasta restaurar en el proyecto temporal, validar descifrado Vault, integridad de Deudas, tres cuentas Auth y pruebas HTTP/RLS.

## Comprobación directa del respaldo aceptada en Windows (19/11/2026)

- El propietario ejecutó el comando local directo `pg_restore --data-only --schema=auth --table=users --file=NUL "$archivo"` desde PowerShell. Resultado comprobado en captura: `pg_restore (PostgreSQL) 18.7`, **código final 0**, sin importaciones ni conexión. Esto demuestra que el lector procesa la selección sin fallar cuando descarta la salida; **no demuestra que contenga tres filas**.
- Los validadores V2/V3 que intentaron leer la salida mediante `.NET ProcessStartInfo` fallaron con exit 1. Ya no se deben repetir: su mecanismo de invocación/captura difiere del comando directo exitoso. No se ha probado que el dump esté corrupto.
- Se preparó **un único comprobador local con invocación PowerShell directa**, `CLN_Conteo_7_Tablas_Comando_Directo_SOLO_LECTURA.ps1`, sin `-L`, sin `.NET ProcessStartInfo`, sin salida persistida, sin conexiones. Captura SQL nativo en RAM (sin imprimirlo), comprueba presencia y cierre de cada bloque COPY y los conteos esperados 3/3/1/1/3/1/0; descarta la salida a continuación. **Aún no se ha ejecutado en Windows.**
- Proyecto temporal revisado tras ese diagnóstico: **0 usuarios Auth, 0 filas Vault**; original **ACTIVE_HEALTHY**; LAB **INACTIVE**. No iniciar importación hasta conseguir conteos y revisar dependencias del esquema.
- Importante: `pg_restore -f NUL` confirma solamente que el proceso terminó sin error, no coteja contenido; todavía no equivale a recuperación integral de Auth/Vault ni a pruebas HTTP.

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
