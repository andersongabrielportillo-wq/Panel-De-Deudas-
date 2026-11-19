# Fase 18 — Verificación posterior a instalación y revisión de seguridad

Proyecto: **Comercial Lopez Pruebas** `dozcnytevqhoymzqlxah`. Producción no intervenida.

## Instalación
Las siete migraciones de vendedores manuales, base de contratos, RPC de contratos, historial de vendedores, catálogos, historial de cliente y confirmación atómica quedaron registradas en `supabase_migrations.schema_migrations`.

## Comprobaciones directas de base
- Siete tablas nuevas con `relrowsecurity=true` y sin `SELECT` directo para `anon` ni `authenticated`.
- RPC `inv_buscar_clientes`, `inv_catalogo_vendedores`, `inv_catalogo_articulos_contratos`, `inv_crear_contrato_borrador`, `inv_confirmar_contrato` tienen comprobaciones de `auth.uid()` y `inv_members` en la definición instalada.
- Los ocho RPC críticos muestreados niegan `EXECUTE` a `anon`, permiten a `authenticated` y requieren su autorización interna.

## Advisor de seguridad (no ignorar)
- `rls_enabled_no_policy`: 24 hallazgos INFO; incluye tablas nuevas deliberadamente cerradas a acceso directo.
- `authenticated_security_definer_function_executable`: **36 WARN**. Se deben auditar individualmente las funciones privilegiadas y sus permisos; no se consideran aprobadas solo por tener `auth.uid()`.
- `auth_leaked_password_protection`: 1 WARN (protección contra contraseñas filtradas no habilitada).

## Interfaz y CI
- `staging/index.html` usa solo el proyecto de pruebas; inventario ficticio y catálogos de contratos de solo lectura, sin llamadas a RPC de creación/confirmación.
- CI del commit `f6dce8d6`: 19 pruebas aprobadas, 0 fallidas. Estas son pruebas estáticas y de aislamiento, no pruebas funcionales de HTTP con sesiones reales.

## Pendiente
1. Ejecutar con usuarios de prueba autorizados: búsqueda de clientes, alta ficticia, contrato borrador, prima, confirmación y deduplicación.
2. Probar rechazos reales de usuarios sin membresía y concurrencia.
3. Auditar 36 avisos `SECURITY DEFINER` y el modelo de datos sensibles antes de habilitar escrituras.
4. Resolver backup externo recuperable: **no existe copia verificada en este flujo**.
5. Mantener Deudas bloqueado hasta contraseña adicional validada del lado servidor y restringir API directa.
