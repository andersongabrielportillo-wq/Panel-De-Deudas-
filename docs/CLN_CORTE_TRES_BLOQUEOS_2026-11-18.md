# CL Nexus — corte controlado: tres únicos bloqueos (18 noviembre 2026)

**Estado: NO GO a producción.** Documento operativo; no ejecutar cambios de producción hasta superar las tres condiciones de salida. Esta rama prepara el corte, no lo autoriza. Nunca colocar contraseñas, URL con credenciales, respaldos reales, tokens, llaves de Vault, datos de clientes o sesiones en GitHub o CI.

## 1. Respaldo íntegro y recuperación efectiva (P0 absoluto)

Fuente: Supabase proyecto de producción `josdmjjbnrugiwlwgjky`. Al 18 de noviembre: 1 workspace, 3 integrantes, 1 fila compartida en `public.debts`, 0 filas en `public.transactions`. El checksum previo debe capturarse justo durante el corte, después de congelar cambios; un checksum histórico no reemplaza este paso.

- Revisar en el **Dashboard del proyecto de producción > Database > Backups** si existe backup disponible y si aparece **Restore to a New Project**. No usar restauración SOBRE producción para ensayos.
- Si está disponible: con aprobación explícita del propietario y revisión del costo, restaurar un backup FRESCO en **proyecto nuevo y aislado**. Según Supabase, el clonado copia los esquemas, Auth y la raíz de cifrado necesaria para Vault; **no** copia la configuración de Realtime/Edge Functions/Storage como sistema completo. Desactivar cualquier automatización con efectos externos en el clon ANTES de pruebas de escrituras. No asumir que un backup diario incluye los últimos cambios; congelar y comparar.
- Si no está disponible: preparar backup lógico seguro con la guía oficial Supabase CLI y restaurarlo en entorno aislado. **Crítico:** la contraseña adicional de Deudas está en Supabase Vault; una restauración lógica a otro proyecto con distinta raíz de cifrado puede dejarla ilegible. El material criptográfico se gestiona únicamente mediante los mecanismos oficiales y nunca por chat o repositorio.
- Ejecutar `sql/backup_restore_integridad_PRODUCCION_SOLO_LECTURA.sql` en la fuente, y la misma consulta en el destino aislado; verificar misma fila `__shared_state__`, mismo SHA-256 del payload, miembros/usuarios, estructura, permisos y ausencia de pérdidas. Hacer también copia local cifrada de Deudas por dispositivo y confirmar `cp_pend` y sincronización antes de congelar.
- Conservar el respaldo validado, su ubicación segura y procedimiento de reversión. **No basta** una rama GitHub ni el ensayo con datos ficticios.

Documentación oficial: https://supabase.com/docs/guides/platform/backups y https://supabase.com/docs/guides/platform/clone-project y https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

## 2. Autorización real de Deudas y CL Nexus (P0)

- La producción ya dispone de `public.unlock_debts(text)`, `public.has_debts_unlock()`, `public.lock_debts()` y exactamente un registro de configuración para la contraseña adicional en Vault; no duplicar el sistema.
- Problema comprobado con transacción **READ ONLY** y JWT simulado: una membresía válida lee `__shared_state__` aun cuando `has_debts_unlock()` devuelve falso. Usuario no miembro ve 0 filas. Por ello, **el frontend por sí solo NO basta**.
- Cliente y nombres de RPC adaptados en rama. `DEBT_GATE_ENABLED=false` permanece hasta el corte. Archivo SQL para el corte: `sql/deudas_gate_existing_production_rpc_PREPARADO_NO_EJECUTAR.sql`. Añade políticas RESTRICTIVE a `debts` y `transactions` y falla si existe deriva en RLS/permisos o faltan RPC. Reversión: `sql/deudas_gate_existing_production_rpc_ROLLBACK_NO_EJECUTAR.sql`, que NO restaura datos.
- **NO ejecutar** `sql/deudas_gate_produccion_BORRADOR_NO_EJECUTAR.sql`: es un diseño anterior que crearía otro sistema y puede romper acceso.
- Ejecutar en CLON auténtico con sesiones reales Administrador/Secretaria/no-miembro, llamadas directas REST/RPC, expiración y Realtime. El JWT simulado y CI no sustituyen autenticación por la red.
- Proteger caché local `cp_v2` y cambios offline: no purgar ni migrar automáticamente a ciegas. Revisar política de cifrado/retención y evitar lectura o escritura de datos privados antes del desbloqueo y después del cierre. Sin terminar este trabajo, no activar el gate.
- La tercera cuenta de Deudas no recibe acceso a inventario por defecto: `sql/cl_nexus_roles_provision_PREPARADO_NO_EJECUTAR.sql` exige mapeo explícito de 2 o 3 usuarios autorizados con al menos un admin y una secretaria. No copiar `inv_members` del laboratorio.

## 3. Montaje definitivo en la PWA y datos de inventario (P0)

- Motor reproducible generado desde laboratorio: `sql/cl_nexus_schema_lab_SNAPSHOT_SOLO_ENSAYO_NO_PRODUCCION.sql` (24 tablas, 39 funciones, 3 vistas, 47 índices, 48 FKs, 13 RLS policies y 6 triggers). Ensayado en PostgreSQL 17 con esquema de Deudas y datos ficticios, sin modificar la fila compartida ni miembros. **No aplicar el snapshot directamente a producción** sin clon restaurado, dependencias y auditoría real.
- Interfaz existente `index.html`, `cl-nexus-shell.js`, `cl-nexus-adapter.cjs`, `cl-nexus-reader.cjs` y `cl-nexus-actions.cjs`. El shell está intencionalmente restringido a LAB; la habilitación productiva debe depender de APIs productivas ya instaladas y seguridad comprobada. Mantener un solo login y módulos separados.
- Insumo MERCADERIA: preimportación local derivada SOLO de la hoja MERCADERIA del archivo ya aportado: 190 bloques, 182 nombres distintos, 8 duplicados. Ningún valor de existencia histórica puede tratarse como stock físico confirmado sin revisión. Ubicación Oficina sugerida; garantías y bodega sin imputación supuesta. Ninguna fila se importó.
- Confirmar en clon que operaciones de Inventario/Contratos no alteran Deudas; validar roles HTTP reales y sincronización final antes de cambiar el deployment y el Service Worker. No repetir baterías de laboratorio ya aprobadas sin cambio relevante.

## Orden de corte, único camino seguro

1. Propietario confirma disponibilidad/costo de backup; se obtiene/restaura y valida un clon real (sin tocar origen).
2. En clon: instalar esquema y datos iniciales validados; mapear roles explícitos; alinear las RPC; probar bloqueo completo de API/caché/Realtime y recuperación real.
3. Tomar backup fresco y confirmar sincronización/caché de cada dispositivo; congelar escrituras.
4. Ejecutar backend/RLS y desplegar PWA compatible coordinadamente; probar ambos usuarios reales y acceso denegado sin contraseña.
5. Si algo falla: revertir código/políticas mediante runbook y, si se alteraron datos, usar respaldo probado (no asumir que rollback SQL recupera filas).

**NO GO:** sin respaldo restaurado, sin permisos verdaderos, sin cifrado/control de caché, sin existencias revisadas, sin sesión real o sin autorización expresa del propietario. Producción permanece sin modificaciones en esta fase.
