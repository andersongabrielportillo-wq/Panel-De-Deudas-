# CL Nexus — informe de seguridad y preparación de despliegue (fase 20)

## Verificación realizada (2026-11-16)

- Laboratorio Supabase: `dozcnytevqhoymzqlxah`. Producción: `josdmjjbnrugiwlwgjky`.
- Las 16 RPC de escritura inspeccionadas del laboratorio son `SECURITY DEFINER` y sus cuerpos hacen referencia a `auth.uid()` y `public.inv_members`. **Esta comprobación textual NO sustituye pruebas de permisos por usuario y operación**.
- Consulta de privilegios: ninguna función `public.inv_%` o `public.cl2_%` del laboratorio otorga `EXECUTE` a `anon` según `has_function_privilege` en el momento de la inspección.
- Las 21 tablas `public.inv_%` revisadas tenían RLS habilitado.
- Producción no tenía funciones `public.inv_%` ni `public.cl2_%` al momento de la consulta. **No se desplegó esquema ni código en producción**.
- El frontend sólo activa el adaptador con el origen explícito del laboratorio y una sesión privada activa. Esto es una salvaguarda adicional, NO una autorización de servidor.
- Los formularios usan confirmación humana antes de escribir y mantienen el UUID de operación para reintentos de movimientos y confirmación de contratos; otras operaciones no tienen idempotencia garantizada y deben revisarse en servidor antes de repetir.

## Problemas abiertos para lanzamiento

1. Desplegar las tablas, funciones, RLS, grants, índices, restricciones y datos de catálogo de CL Nexus mediante migraciones versionadas y revisión de dependencias, **sólo con autorización explícita para producción**.
2. Verificar en el servidor definitivo, con usuarios de prueba admin/secretaria/no miembro, que cada RPC aplica el rol correcto; revisar funciones `SECURITY DEFINER`, `search_path` y propiedad de objetos.
3. Integrar el módulo Deudas detrás de una contraseña adicional **validada del lado del servidor en todas sus rutas de lectura/escritura**. El `__shared_state__` actual permite acceso por la API existente y no se debe presentar un simple modal como protección suficiente.
4. Confirmar formato real de `p_detalles`, `p_ubicaciones`, `p_referencias`, valores permitidos de modalidad/frecuencia/plan y transiciones de reparación antes de habilitar formularios a usuarios.
5. Probar los formularios en navegador con usuarios reales de prueba, incluyendo errores, concurrencia, desconexión, reintentos, stock insuficiente y cambios de sesión.
6. Sustituir presentación JSON crudo por tablas y vistas filtradas; evitar mostrar información sensible de clientes fuera de la vista autorizada.
7. Backup probado, rollback, service worker, pruebas de tres usuarios y publicación controlada.

## Estado

**No apto para publicación.** Implementación en rama `integracion-inventario-fase15`; no fusionar hasta completar bloqueos anteriores. No retomar el workflow HTTP autenticado que el usuario pidió omitir.
