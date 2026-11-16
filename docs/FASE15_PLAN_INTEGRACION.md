# Fase 15 — Integración del Inventario en Panel de Deudas

Estado: diseño inicial, sin despliegue. Rama: integracion-inventario-fase15.

## Objetivo
Una sola PWA, una sola sesión Supabase Auth y dos módulos independientes:
- Inventario y garantías: artículos, existencias, movimientos, aprobaciones y garantías.
- Deudas: cálculos y sincronización actuales, con contraseña adicional para acceder.

## Hallazgos comprobados
- La aplicación usa index.html, sw.js y manifest.webmanifest.
- Supabase Auth gestiona el inicio de sesión.
- El código actual lee y escribe el estado de deudas en public.debts, fila __shared_state__, mediante cloudSnapshot/cloudSet.
- El estado de deudas también se conserva temporalmente en almacenamiento local.
- La tabla public.workspace_members contiene 3 membresías.
- RLS está activado en public.debts, pero las políticas actuales permiten SELECT/INSERT/UPDATE/DELETE a miembros del workspace sin desbloqueo adicional.
- El Service Worker evita activar actualizaciones automáticamente.

## Restricciones obligatorias
1. No modificar main ni producción hasta revisión y pruebas.
2. No mezclar datos de inventario con el JSON de deudas.
3. No publicar contraseñas, secretos ni service_role en GitHub/frontend.
4. No permitir que una contraseña solo visual sea el control de acceso.
5. Mantener autorizaciones y reglas de negocio de inventario en servidor/base de datos.
6. Mantener bloqueadas las escrituras de CL Nexus que aún no superan la revisión de identidad.
7. Hacer copia de seguridad y plan de reversión antes de migraciones.
8. Validar sesión y permisos por usuario y workspace en todas las operaciones.

## Secuencia propuesta
A. Construir selector de módulos y pantalla de acceso a Deudas en la rama de pruebas, sin activar todavía consultas protegidas.
B. Diseñar verificación adicional de Deudas en servidor con comprobación de contraseña y autorización temporal, vinculada a sesión/usuario, con caducidad, limitación de intentos y revocación.
C. Cambiar el acceso directo actual a public.debts para que no se pueda consultar ni escribir el JSON de deudas sin autorización adicional; probar con usuario autenticado sin desbloqueo.
D. Diseñar tablas independientes para inventario, movimientos, autorizaciones y garantías, con RLS por workspace y permisos.
E. Integrar y probar la UI de inventario, incluida sincronización, manejo de errores y PWA.
F. Validar en entorno de pruebas y luego preparar despliegue controlado.

## Riesgos que deben resolverse antes del despliegue
- Las políticas RLS de deudas permiten hoy acceso por membresía sin segunda contraseña.
- La aplicación guarda copias locales de deudas; la protección debe considerar caché, sesión y cierre de módulo.
- El inventario de CL Nexus vive actualmente en un laboratorio PostgreSQL separado; hace falta definir migración segura al backend definitivo.
- No asumir que los datos o las tablas del laboratorio ya existen en Supabase de producción.

## Criterios de aceptación
- Un usuario autorizado puede iniciar sesión y abrir Inventario sin desbloquear Deudas.
- Sin contraseña adicional no se pueden leer ni modificar deudas ni por UI ni mediante peticiones directas a Supabase.
- Al cerrar sesión o expirar la autorización, Deudas vuelve a bloquearse.
- Las operaciones de Inventario se rigen por permisos reales, no por botones ocultos.
- Los datos, respaldos y sincronización de Deudas permanecen íntegros.
