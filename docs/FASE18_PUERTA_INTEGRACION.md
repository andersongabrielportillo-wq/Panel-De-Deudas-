# Fase 18 — Puerta de integración de CL Nexus (sin despliegue)

Estado: **NO APROBADA PARA PRODUCCIÓN**. Documento de verificación; no activa ni fusiona módulos.

## Evidencia validada
- Cliente `laboratorio/conectado-lectura.html`: inicio de sesión con proyecto de pruebas fijado; consulta RPC `cl2_sandbox_list` cada 5 segundos. No es WebSocket/Reatime ni PWA final.
- Usuario verificó en PC y teléfono aparición automática de artículo ficticio y cambio de 1 a 2 unidades.
- Motor `cl2_sandbox_test_sale`: dos solicitudes paralelas contra 1 unidad: una registrada y una rechazada por insuficiencia; saldo 0 y una venta.
- Reintento con mismo `client_op_id`: `already_registered`; identificador reutilizado con cantidad distinta: error; saldo inalterado.
- Tablas sandbox de concurrencia y miembros con RLS; RPC del sandbox concedidas a `authenticated`, no a `anon`.

## Bloqueantes de integración
1. **Deudas**: el laboratorio permite leer deudas ficticias a un miembro autenticado sin segunda contraseña. No reutilizar esta RPC para datos reales. Diseñar verificación adicional del lado del servidor y aplicarla a todas las API de Deudas, no solo a la interfaz.
2. **Autenticación real**: probar sesiones reales admin, secretaria y usuario sin membresía; verificar denegación de operaciones no autorizadas y cierre de sesión. Las pruebas SQL con contexto JWT simulado NO reemplazan estas pruebas.
3. **Inventario**: enlazar componentes de CL Nexus con API de inventario autorizadas y transaccionales; no reemplazar el motor existente por datos de maqueta.
4. **Multibodega y garantías**: validar entradas, salidas, traslados, ajustes, devoluciones pendientes y liberación idempotente; rechazar destinos inválidos.
5. **Sincronización**: validar escritura desde clientes reales, actualización de otros dispositivos, expiración/renovación de sesión y reconexión. Polling cada 5 segundos no equivale a Realtime.
6. **PWA existente**: preservar módulo Deudas, login único, datos, rutas, service worker y manifest; probar actualización sin reinstalación y sin borrar caché/datos del usuario.
7. **Despliegue**: respaldos comprobados, plan de reversión, pruebas de regresión, revisión de cambios, aprobación explícita antes de fusionar o publicar.

## Reglas de aislamiento
- Laboratorio exclusivamente en Supabase **Comercial Lopez Pruebas** (`dozcnytevqhoymzqlxah`).
- No tocar proyecto de producción, no cambiar rama `main`, no fusionar PR ni publicar GitHub Pages sin aprobación expresa.
- No guardar credenciales ni claves privadas en el repositorio. Solo claves publicables en cliente de laboratorio.

## Próxima prueba
Crear harness de integración con usuarios ficticios autenticados que ejercite permisos por RPC y errores de autorización, y luego montar interfaz detrás del login de la rama de integración. Registrar resultados verificables antes de declarar Fase 18 aprobada.
