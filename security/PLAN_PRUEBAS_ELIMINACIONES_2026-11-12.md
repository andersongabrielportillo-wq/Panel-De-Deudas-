# Comercial López 2 — plan de pruebas de autorización y eliminación (solo sandbox)
Fecha: 2026-11-12. Estado: ESPECIFICACIÓN; NO IMPLEMENTADO NI APROBADO.

## Permisos aprobados por el usuario
- Administrador: registrar movimientos, aprobar entradas, gestionar devoluciones y garantías, registrar/anular ventas, crear vendedores, eliminar registros e históricos, administrar usuarios y permisos.
- Secretaria: las mismas operaciones excepto administrar usuarios y permisos.
- Eliminación: una advertencia adicional de confirmación, sin contraseña adicional.

## Condiciones de seguridad obligatorias
1. Ejecutar únicamente sobre datos ficticios en un entorno separado. No tocar public.inv_* existentes, deudas reales, permisos reales ni producción.
2. No usar DELETE directo desde el cliente. Diseñar RPC de eliminación autorizada, con comprobación server-side de membresía, tipo y objeto, transacción atómica, integridad referencial y bitácora protegida. El cuadro de confirmación del frontend NO es autorización.
3. No eliminar la bitácora. Registrar actor, fecha, tipo, identificador, motivo y cambios compensatorios, con acceso restringido.
4. Para históricos de ventas, movimientos y abonos, verificar recálculo cronológico, stock, garantías, saldos y reportes. Bloquear borrado si no puede garantizarse consistencia.
5. Evitar doble eliminación, concurrencia, reintentos y cambios parciales; exigir idempotencia y pruebas de rollback.

## Matriz de pruebas pendientes
- Admin/Secretaria: operaciones permitidas exitosas, con sesiones de prueba reales; Secretaria: administración de usuarios DENEGADA; usuario no miembro y anon: TODAS denegadas.
- Entradas: solicitar, aprobar, rechazar; salidas: stock suficiente e insuficiente; traslados: destinos válidos e inválidos.
- Devoluciones: solicitud, revisión, rechazo y aprobación; garantía: envío, liberación, doble liberación, destino inválido.
- Reparaciones: crear, enviar, resolver, repetir operación; ventas: registrar, anular, anular dos veces, devolver antes de anular.
- Eliminaciones: registros simples e históricos, integridad de saldos/stock, bitácora, autorización, confirmación UI, concurrencia y rollback.
- Sincronización: dos sesiones/dispositivos; alta, modificación, anulación, eliminación, reconexión, duplicados y cambio de sesión.

## Hallazgos verificados hasta ahora
- Las 12 tablas principales inv_* tienen RLS activado.
- Las 13 RPC principales de inventario requieren autenticación y contienen controles de roles; esto es inspección estática, no prueba efectiva por usuario.
- No hay DELETE directo para authenticated en las 12 tablas principales, ni RPC pública de borrado permanente detectada. La nueva función no existe todavía.
- Ninguna tabla inv_* estaba en la publicación supabase_realtime al momento de la consulta. Falta determinar si hay otro mecanismo de refresco y verificar dos clientes.
- Las pruebas previas de cantidades y matriz de roles fueron simulaciones temporales; NO validan las RPC reales.

## Criterio de aprobación
Marcar LISTO únicamente cuando cada caso tenga ejecución reproducible, resultado esperado/real, evidencia y no haya fallos críticos. Preparar cambios en rama feature, nunca merge ni despliegue sin autorización explícita.
