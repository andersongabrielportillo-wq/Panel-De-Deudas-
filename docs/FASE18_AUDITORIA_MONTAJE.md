# Fase 18 — Auditoría del punto de montaje (2026-11-15)

## Inspección directa de `index.html` en rama de integración
- El login existente usa `SB.auth.signInWithPassword` y cliente Supabase con `persistSession` y `autoRefreshToken`.
- `#privateApp` se mantiene oculto e inerte antes de `connectCloud()`; el cierre de sesión retira canal y vuelve al gate.
- La navegación de la app actual proviene de `const TABS` (Inicio, Deudas, Movimientos, Calendario, Presupuesto, Informes, Datos, Excel, Guía) y `render()` genera botones de navegación y vista central.
- El código actual utiliza el proyecto Supabase de producción en su configuración; por eso **no se debe probar esta página directamente con cuentas ficticias** ni hacer staging mediante mera publicación de la rama.
- La sincronización de Deudas actualmente carga `SB.from('debts').select('data')` sobre el estado compartido. **Una contraseña de pantalla no protege este endpoint**: para cumplir el requisito de contraseña adicional debe rediseñarse la autorización en servidor y restringirse el acceso directo a los datos de deudas.
- `laboratorio/conectado-lectura.html` es una aplicación aparte con proyecto ficticio fijado, polling y RPC; no es todavía un módulo montado detrás del login existente.

## Orden de implementación recomendado (sin cambiar producción)
1. Crear una variante de staging completamente aislada, que apunte SOLO a `Comercial Lopez Pruebas` y tenga datos ficticios; prohibir configuración de producción por pruebas automáticas.
2. Implementar en el servidor de staging la puerta adicional de Deudas que cubra lectura y escritura de API; no confiar en ocultar la pestaña.
3. Incorporar navegación y componentes de Inventario/Garantías/Contratos al contenedor `#privateApp`, sin alterar el motor de Deudas ni reemplazar datos.
4. Probar roles y autorización por API con sesiones reales; luego concurrencia, multibodega, garantías y sincronización de clientes.
5. Respaldos, pruebas de regresión y autorización explícita antes de cualquier despliegue productivo.

## Estado
CI de aislamiento: **success** (run 43808887871). Montaje funcional: **pendiente**. Publicación: **no autorizada**.
