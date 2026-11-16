# Fase 15 — Montaje PWA, autenticación y sincronización

**Estado:** pruebas de montaje con cliente simulado preparadas; integración en la PWA publicada y pruebas reales entre dispositivos **pendientes**. No modificar proyectos existentes.

## Hallazgos del código inspeccionado
- `prototipos/selector-modulos.html` es una **vista previa**, no navegación funcional; Inventario y Deudas abren diálogos informativos.
- `prototipos/contratos-montaje-staging.js` recibe un cliente Supabase ya autenticado, comprueba `auth.getUser()`, permiso RPC `inv_catalogo_vendedores_manual`, vuelve a comprobar identidad y escucha cambios de sesión.
- Al cerrar sesión o cambiar usuario desmonta contratos y limpia el contenedor. No llama a `signOut` global.
- `tests/pwa-montaje-autenticacion.test.mjs` cubre separación entre contenedores, renovación de token, cierre sin cerrar sesión global, revocación RPC y selector no funcional. **Son mocks; no sustituyen JWT firmados ni dispositivos reales.**

## Pruebas de autenticación necesarias
1. Una sola pantalla de login para los módulos, misma identidad de usuario y sin compartir contraseñas en código.
2. Admin y Secretaria: permisos para registrar entradas y operaciones autorizadas de contratos; empleado/ajeno: denegación en RPC y RLS.
3. Cambiar de cuenta mientras hay una RPC pendiente: descartar respuestas tardías y borrar datos sensibles de la pantalla.
4. Cerrar sesión en un módulo: cerrar sesión global una vez, limpiar ambos módulos y suscripciones. Desmontar solo contratos no debe cerrar sesión global.
5. Deudas: exigir contraseña adicional **verificada en servidor**, y denegar consultas/API sin autorización de módulo, aunque se manipule la interfaz.
6. Probar refresh/expiración de token y reconexión con JWT reales.

## Pruebas de sincronización (dos dispositivos o dos navegadores autenticados)
1. Iniciar sesión con las cuentas de prueba A y B, verificar aislamiento de roles.
2. Crear artículo/movimiento autorizado en A; observar cambio en B sin recargar.
3. Registrar venta ficticia en A; observar **un solo descuento** en ambas pantallas y movimiento correspondiente.
4. Hacer dos solicitudes concurrentes de confirmación: un solo descuento y una sola venta.
5. Desconectar B, operar en A, reconectar B; verificar reconciliación con servidor y ausencia de duplicados.
6. Cerrar sesión en A durante una petición; no mostrar datos del usuario anterior ni resucitar pantallas con respuesta tardía.
7. Publicar nueva versión de Service Worker en entorno aislado; confirmar actualización sin reinstalar y sin pérdida de datos.
8. Comprobar copia de seguridad y restauración antes de autorizar despliegue.

## Criterios de aceptación
- Capturar fecha, commit SHA, entorno, rol, dispositivo, resultado y evidencia de cada caso.
- No usar datos de clientes reales ni credenciales productivas.
- No declarar la sincronización real aprobada con pruebas Node de cliente simulado.
- No fusionar a main ni aplicar migraciones hasta superar seguridad Deudas, JWT, pruebas de dos dispositivos y respaldo.
