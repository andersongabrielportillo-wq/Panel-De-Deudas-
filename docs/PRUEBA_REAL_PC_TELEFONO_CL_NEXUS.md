# Prueba real de CL Nexus entre PC y teléfono — protocolo seguro

Estado: **pendiente de ejecución con dos sesiones reales**. Este documento no acredita sincronización ni permisos productivos.

## Antes de comenzar
- Utilizar únicamente el entorno de laboratorio autorizado; confirmar la URL y el proyecto de base de datos de pruebas. No abrir producción ni cambiar `main`.
- Iniciar sesión en PC con Administrador y en teléfono con Secretaria, con **cuentas distintas**. No compartir contraseñas ni tokens en capturas.
- Confirmar que la prueba se realiza con artículos ficticios, identificados por prefijo `PRUEBA-CLN-`, y que ambas sesiones ven la misma base de laboratorio.
- Comprobar conectividad HTTPS en Wi-Fi y datos móviles. Registrar fecha, hora, versión/commit y dispositivos.
- Antes de cada escritura, comprobar que la función está habilitada **solo en laboratorio** y que existe un procedimiento para anular el dato ficticio.

## Secuencia de validación
| ID | Acción | Resultado esperado | Evidencia |
| --- | --- | --- | --- |
| R01 | Administrador inicia sesión en PC | Solo sus módulos autorizados; no se muestra Deudas sin desbloqueo adicional cuando gate esté habilitado | Captura sin datos sensibles |
| R02 | Secretaria inicia sesión en teléfono | Misma separación de módulos y permisos de su rol | Captura |
| R03 | Crear artículo ficticio en laboratorio (si API autorizada) | Aparece una sola vez en inventario; no cambia Deudas | ID ficticio y stock antes/después |
| R04 | Entrada ficticia solicitada por una sesión y aprobada por la otra | Stock aumenta **solo después** de aprobar; historial conserva autor y fecha | IDs de solicitud y movimiento |
| R05 | Registrar traslado Oficina → Bodega | Baja en origen y sube en destino por igual cantidad; total invariable | Existencias por ubicación |
| R06 | Simular dos operaciones simultáneas sobre stock limitado | Una o ambas responden según stock real, nunca queda stock negativo ni duplicados | IDs de operación, resultados |
| R07 | Desconectar teléfono, consultar y reconectar | No se anuncian escrituras sincronizadas que no llegaron al servidor; no se pierden pendientes | Estado antes/después |
| R08 | Cerrar sesión de Secretaria durante una consulta | Ninguna respuesta tardía muestra información privada después de salir | Captura de pantalla final |
| R09 | Probar acceso sin permiso y desbloqueo de Deudas con cuenta autorizada | Servidor rechaza acceso no autorizado; Deudas solo aparece tras autorización adicional | Código HTTP y rol, sin contraseña |
| R10 | Venta ficticia con dos artículos y posterior anulación autorizada | Descuento exacto y restitución exacta una sola vez; motivo obligatorio | IDs de venta/anulación |
| R11 | Repetir solicitud con el mismo `client_op_id` | No se duplica la operación | ID y estado de servidor |
| R12 | Reiniciar PWA en ambos dispositivos | Datos persistentes coinciden con servidor y roles siguen vigentes | Comparación de saldos y stock |

## Criterios de bloqueo de publicación
No publicar si: hay discrepancia de stock, duplicados, datos de Deudas visibles sin permiso, pérdidas de abonos pendientes, fallo de autenticación real, caché antigua sin plan de migración validado, o no existe respaldo y procedimiento de reversión de base de datos.

## Registro de resultados
Completar cada ID con: **PASÓ / FALLÓ / NO EJECUTADO**, hora, usuario/rol, dispositivo, referencia de evidencia y observaciones. No registrar contraseñas, DUI reales ni datos de clientes en el repositorio.

**Nota:** los tests de GitHub Actions son automatizados y aislados; no sustituyen este recorrido real entre dos dispositivos ni la validación de RLS en producción.
