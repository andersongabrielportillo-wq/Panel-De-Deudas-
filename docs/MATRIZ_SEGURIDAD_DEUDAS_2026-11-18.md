# CL Nexus — matriz de seguridad ejecutada (18 noviembre 2026)

**Ámbito:** proyecto Supabase de laboratorio `dozcnytevqhoymzqlxah`. **No** es una certificación de producción.

## Pruebas SQL verificadas
| Caso | Esperado | Observado | Estado |
|---|---|---|---|
| Lectura sin desbloqueo | 0 filas | 0 | PASA |
| Lectura con desbloqueo vigente | 1 fila ficticia | 1 | PASA |
| Otra sesión del mismo usuario | 0 filas | 0 | PASA |
| Lectura después de bloqueo manual | 0 filas | 0 | PASA |
| UPDATE de registro existente sin desbloqueo | 0 filas afectadas | 0 | PASA |
| DELETE de registro existente sin desbloqueo | 0 filas afectadas | 0 | PASA |
| Registro original tras UPDATE/DELETE denegados | Sin cambios | Sin cambios | PASA |
| INSERT con desbloqueo | 1 fila | 1 | PASA |
| UPDATE con desbloqueo | 1 fila | 1 | PASA |
| DELETE después de bloqueo | 0 filas | 0 | PASA |
| Sesión vencida | false | false | PASA |
| Sesión con vencimiento futuro | true | true | PASA |
| Antes de incrementar revision de secreto | true | true | PASA |
| Después de incrementar revision de secreto | false | false | PASA |

**Método:** transacciones `BEGIN ... ROLLBACK`, datos ficticios, JWT de prueba bajo rol `authenticated`. Confirmada limpieza de registros temporales en las rondas previas. No se ejecutó migración de producción.

## Pendiente, no marcar como aprobado
- Ejecutar el borrador completo `sql/deudas_gate_produccion_BORRADOR_NO_EJECUTAR.sql` en un clon aislado compatible con el esquema real de producción.
- Probar fallo de INSERT sin autorización mediante manejo explícito de excepción y verificación de error RLS.
- Verificar privilegios, política RESTRICTIVE, bypass por roles privilegiados y JWT inválidos.
- Verificar que Realtime no envía cambios de Deudas a sesiones bloqueadas (PC y teléfono).
- Actualizar cliente de Deudas a RPC definitivas, conservando modo cerrado hasta despliegue coordinado.
- Respaldos y restauración ensayada; pruebas reales de usuarios y dispositivos.

**Regla de publicación:** backend, frontend y verificación en ventana coordinada; aprobación expresa antes de cualquier cambio en producción.
