# Fase 18 — Preflight de contratos en Comercial Lopez Pruebas

Fecha: 2026-11-15. Inspección SQL de solo lectura sobre proyecto de **pruebas** `dozcnytevqhoymzqlxah`. No se aplicó ninguna migración.

## Inventario real del entorno de pruebas
- `public.inv_members`: existe.
- `public.inv_ventas`: existe.
- `public.inv_contratos`: **no existe**.
- `public.inv_contrato_detalles`: **no existe**.
- `public.inv_crear_contrato_borrador`: **no existe**.
- `public.inv_confirmar_contrato`: **no existe**.
- `public.inv_liberar_garantia`, `public.inv_registrar_venta`, `public.inv_revisar_devolucion`: existen (existencia no equivale a permiso o comportamiento validado).

## Consecuencia
No habilitar el módulo Contratos en el staging conectado. El repositorio contiene migraciones `20261115_fase15i_contratos_base.sql`, `20261115_fase15j_contratos_rpc.sql`, `20261115_fase15q_confirmar_contrato.sql`, además de dependencias intermedias. Los flujos de CI PostgreSQL efímero han finalizado con éxito, pero no demuestran que el proyecto compartido de pruebas esté listo para migrar sin afectar datos existentes.

## Puerta de cambio
1. Inspeccionar dependencias, permisos, RLS y funciones de todas las migraciones en orden.
2. Tomar respaldo comprobable del proyecto de pruebas y plan de reversión; verificar conflictos con tablas existentes.
3. Aplicar únicamente con aprobación explícita del usuario para cambiar el esquema de ese proyecto compartido.
4. Validar con sesiones HTTP reales de admin, secretaria y no miembro; rechazo por permisos y repetición de operaciones.
5. Mantener producción `josdmjjbnrugiwlwgjky` intacta.
