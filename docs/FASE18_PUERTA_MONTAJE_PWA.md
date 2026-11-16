# Fase 18 — Puerta de integración PWA y API de Contratos

Fecha: 2026-11-15. Rama `integracion-inventario-fase15`, sin despliegue a `main`.

## Backend real en proyecto de pruebas
Siete migraciones de Contratos instaladas. Tablas nuevas con RLS y sin acceso directo SELECT para `anon` ni `authenticated`. Funciones RPC protegidas por comprobaciones de membresía. Avisos de seguridad `SECURITY DEFINER` pendientes de auditoría exhaustiva.

## Staging funcional
- Inventario ficticio: `cl2_sandbox_list` en modo lectura.
- Contratos: `inv_catalogo_vendedores`, `inv_catalogo_articulos_contratos`, `inv_buscar_clientes` (búsqueda manual de al menos dos caracteres), todos por JWT del usuario de pruebas.
- No usa RPC de escritura de clientes, contratos, ventas o garantías.
- Cancelación de consultas, renovación JWT en memoria, limpieza al salir.
- Deudas: bloqueado; nunca consultar `cl2_sandbox_list(p_module='deudas')` ni API real hasta que exista protección de contraseña adicional del lado servidor.

## Puerta de montaje a PWA existente
1. Mantener intacto el origen Supabase productivo del `index.html` y la base real; no apuntar la PWA a proyecto de pruebas.
2. Preparar adaptador de autenticación para que CL Nexus reutilice la sesión de la PWA sin segundo login. No incrustar clave secreta.
3. Auditar acceso a datos de Deudas: el bloqueo visual no basta, deben protegerse las tablas/RPC en servidor.
4. Validar en dispositivos reales los módulos, sesión, permisos, operaciones concurrentes, Service Worker y actualización de caché.
5. Solo después habilitar módulos en `index.html` y publicar mediante revisión explícita, sin reinstalar PWA.

## Limitaciones actuales
No hay respaldo externo recuperable confirmado. No se ha realizado flujo HTTP real completo de escritura de Contratos ni despliegue a PWA instalada.
