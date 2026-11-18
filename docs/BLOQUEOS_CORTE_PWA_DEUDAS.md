# CL Nexus — bloqueos de corte detectados en index.html

Revisión de la rama de integración (18-11-2026). **No publicar ni activar la puerta de Deudas todavía.**

## Hallazgos confirmados en código

1. `const DEBT_GATE_ENABLED=false;` mantiene desactivado el nuevo control en la PWA. Esto es intencional mientras producción no tenga migración.
2. `createDebtGate({client:SB,workspaceId:SB_WID})` usa por defecto las RPC `debt_lab_*`. El cliente ya admite el conjunto definitivo, pero el punto de montaje **aún no selecciona** explícitamente `{unlock:'debt_unlock',verify:'debt_access_valid',lock:'debt_lock'}`. Al activar el flag sin corregir esto fallaría.
3. La suscripción `postgres_changes` de `public.debts` recibe el evento antes de llamar `debtController.verify()`. **No asumir que la verificación posterior protege el payload recibido.** Debe comprobarse el comportamiento real de Realtime con RLS y sesiones bloqueadas, sin exponer datos en el mensaje.
4. `cloudSnapshot` hace comprobación local con `isUnlocked()`; la autorización definitiva depende de la RLS del servidor, que aún no está desplegada.
5. El código advierte explícitamente que la migración/cifrado de caché local requiere revisión antes de activar el corte.

## Orden obligatorio para el cierre

- Ensayar migración SQL completa en clon aislado con tablas y políticas compatibles con producción.
- Corregir el punto de montaje de RPC definitivas, sin activar `DEBT_GATE_ENABLED` en la rama publicada.
- Validar con pruebas automatizadas y navegador el comportamiento de bloqueo, caducidad y logout.
- Ensayar Realtime desde dos sesiones reales (una autorizada y otra bloqueada); verificar **recepción de payload**, no solo renderizado.
- Revisar caché local, escrituras pendientes, respaldos y restauración.
- Coordinar despliegue del backend y frontend y exigir aprobación expresa del usuario para producción.

**Estado:** revisión de código realizada; pruebas Realtime de extremo a extremo pendientes. No se ha tocado producción.
