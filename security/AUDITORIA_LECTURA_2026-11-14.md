# Comercial López 2 — Auditoría de solo lectura (2026-11-14)

**Estado: INCOMPLETA / NO APROBADA.** Sin cambios a datos ni funciones de producción. Sin despliegues ni recursos de pago.

## Evidencia de aislamiento
Consulta a Supabase `list_branches` para el proyecto `dozcnytevqhoymzqlxah`: `{"branches":[]}`. No existe rama de base de datos aislada accesible mediante este conector. El esquema `cl2_sandbox` dentro del proyecto principal no constituye aislamiento físico del entorno de producción. **Por seguridad no se realizaron pruebas de escritura ni se crearon ramas/proyectos.**

## Privilegios (consulta de catálogo, solo lectura)
Se inspeccionaron las funciones `public.inv_*` y `public.cl2_*` con `pg_proc`, `pg_namespace` y `has_function_privilege`. Las 7 funciones `cl2_sandbox_*` y 15 funciones operativas `inv_*` exponen EXECUTE a `authenticated`, no a `anon`. Ocho funciones auxiliares de `inv_*` no exponen EXECUTE a ninguno de esos dos roles. Esto **no prueba** los permisos efectivos individuales por JWT; estos dependen además de la consulta a `inv_members`.

## Revisión del código fuente de seis funciones SECURITY DEFINER
- `inv_anular_venta`: admite explícitamente `admin` y `secretaria`; requiere motivo; bloquea cabecera y detalles, comprueba devoluciones y compensaciones previas, y crea movimientos compensatorios.
- `inv_crear_vendedor`: admite explícitamente `admin` y `secretaria`; valida nombre.
- `inv_liberar_garantia`: admite ambos perfiles; valida destino 1/2, cantidad, artículo activo, stock de garantía, autorización y movimiento. **No recibe clave de idempotencia del cliente**; genera UUID nuevo dentro del servidor. Una respuesta perdida seguida de reenvío podría ejecutar otra liberación si queda stock suficiente. Este es un riesgo de reintento en producción, sin prueba destructiva.
- `inv_registrar_movimiento`: admite ambos perfiles, solo `salida` y `traslado`, rechaza ubicación 4 y valida stock. Acepta `p_client_op_id` opcional y rechaza duplicados; si cliente no envía clave, el servidor genera una nueva.
- `inv_revisar_devolucion`: ambos perfiles, valida pendiente y destino de garantía, incrementa stock solo al aprobar.
- `inv_revisar_entrada`: ambos perfiles, valida pendiente, incrementa stock solo al aprobar.

Las seis funciones examinadas son `SECURITY DEFINER` con `SET search_path TO ''`. Los nombres de objetos referenciados en los cuerpos inspeccionados están generalmente calificados; la presente revisión no equivale a una auditoría integral de dependencias, RLS ni disparadores.

## Pendiente y bloqueo
1. Entorno independiente de pruebas sin costo garantizado, con esquema, funciones, triggers, políticas y usuarios ficticios replicados, **sin copiar datos reales**.
2. Pruebas con JWT auténticos de Administrador y Secretaria, incluyendo negativas para `anon`, usuario no miembro, revocación y cambio de rol.
3. Matriz exhaustiva de entradas, salidas, traslados, devoluciones, garantías, reparaciones, ventas, anulaciones, concurrencia, reintentos y rollback.
4. Definir si Secretaria debe poder anular ventas y crear vendedores.
5. Propuesta de clave idempotente de cliente para `inv_liberar_garantia` y compatibilidad con interfaz, sin desplegar hasta aprobación.

No se puede declarar éxito ni realizar pruebas exhaustivas de escritura de forma segura mientras no exista aislamiento independiente verificable.