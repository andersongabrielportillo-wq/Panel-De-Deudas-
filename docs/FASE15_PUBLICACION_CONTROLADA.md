# Fase 15 — Puertas de publicación controlada

Estado: **NO PUBLICAR AUN**. Este documento prepara la salida, no autoriza cambios a producción.

## Evidencia automatizada
- PostgreSQL 16 temporal con funciones auténticas copiadas desde staging, datos ficticios: ventas, stock, rollback, idempotencia, dos ubicaciones y permisos de secretaria.
- Concurrencia: ejecutar `tests/postgres/concurrencia_*.sql` con dos sesiones paralelas y revisar el job `postgres-motor-autentico`. No marcar aprobado hasta CI verde.
- GitHub Actions Node 22: exigir todos los jobs verdes para el SHA exacto del candidato.
- El esquema de pruebas es una reconstrucción mínima compatible, **no una restauración completa de staging**.

## Puertas pendientes antes de producción
1. Validar JWT firmados reales de admin, secretaria, empleado y usuario ajeno en un entorno aislado.
2. Probar seguridad del módulo Deudas **en backend**, incluida contraseña adicional y autorización en cada RPC; la contraseña visual sola no protege los datos.
3. Integrar navegación, autenticación y cierre de sesión de la PWA completa; verificar sincronización en dos dispositivos y Service Worker.
4. Probar anulación de venta, prima recibida/pendiente, historial y recuperación de sesión.
5. Auditar RLS, EXECUTE y acceso directo en el entorno de despliegue.
6. Crear y comprobar restauración de backup, registrar migraciones aplicadas, rollback y ventana de mantenimiento.
7. Verificar sección Vendedores vacía en nueva UI; no importar nombres de artículos ni borrar vendedores históricos.
8. Aprobación explícita del usuario para fusionar rama y ejecutar migraciones; no modificar proyectos existentes sin permiso.

## Secuencia propuesta
- Preparación: congelar commit SHA, ejecutar CI, capturar evidencias y respaldo.
- Preflight: confirmar proyecto destino por ID, revisar esquema y permisos, ejecutar auditorías solo lectura.
- Staging autorizado: aplicar siete migraciones 15I, 15AE, 15J, 15K, 15N, 15P, 15Q en orden; ejecutar `tests/15x_verificacion_postmigracion_solo_lectura.sql`.
- Smoke test con datos ficticios: login, vendedor manual, cliente, borrador, confirmación, existencias, prima, historial, anulación.
- Go/no-go: aprobar solo si todas las puertas están verdes y hay rollback probado.
- Publicación controlada: respaldo, ventana, migración, despliegue PWA, validación por admin y secretaria, monitoreo.
- Reversión: ante falla, detener operaciones nuevas, restaurar artefacto anterior y seguir procedimiento probado de recuperación de base; **no** asumir que revertir código deshace ventas o migraciones.

## Límites
No se ha aplicado ninguna migración a inventario poblado ni a Deudas producción. No se crean ramas Supabase de pago. No publicar ni fusionar automáticamente.
