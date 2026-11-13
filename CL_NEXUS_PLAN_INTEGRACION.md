# CL Nexus — plan de integración segura (rama experimental)

## Estado auditado
- Fuente: `index.html` de `main` copiado a `cl-nexus-prototipo`.
- Autenticación: Supabase Auth con correo y contraseña.
- Autorización inicial: consulta a `workspace_members` por `user_id`.
- Deudas: lectura/escritura en `debts` usando el registro `__shared_state__` y `workspace_id`.
- Sincronización: suscripción a cambios Postgres y respaldo local `cp_v2`.
- PWA: `sw.js` y `manifest.webmanifest`.
- El código actual de GitHub **no contiene una segunda autorización de Deudas claramente verificable**. Una captura de la versión publicada sí muestra un menú con Deudas bloqueadas e Inventario · consulta. Esto sugiere una diferencia entre el código accesible en GitHub y la versión que se muestra al usuario (posible caché de Service Worker u otra publicación). **No se debe suponer que el bloqueo es seguro hasta probarlo.**

## Bloqueadores antes de integrar datos
1. **Segunda autorización de Deudas**: no basta con ocultar un botón o un panel. La API/base de datos debe denegar acceso a registros de deudas si la autorización adicional no está vigente. Diseñar y probar mecanismo del lado del servidor (por ejemplo, RPC/Edge Function con sesión de autorización corta y validación de permisos); no almacenar contraseña adicional en HTML, JS, localStorage ni variables públicas.
2. **Separación de entornos**: el proyecto de inventario V17 está en Supabase TEST; Deudas utiliza otro proyecto. No conectar datos TEST a la aplicación real ni copiar registros ficticios a producción.
3. **Cuentas y permisos**: validar identidad de las tres cuentas, roles admin/secretaria, políticas RLS y permisos para cada operación.
4. **Sincronización**: V17 utiliza actualización periódica cada 8 segundos; no llamarla Supabase Realtime. Mantener independencia de estados y errores de cada módulo.
5. **Diferencias entre versión publicada y repositorio**: confirmar el HTML que sirve GitHub Pages y revisar `sw.js` para descartar caché obsoleta.

## Secuencia de implementación
- [x] Recuperar repositorio actual y crear rama aislada.
- [x] Agregar prototipo visual independiente `cl-nexus-preview.html`.
- [x] Aplicar capa visual experimental a `index.html` sin reescribir su lógica.
- [x] Documentar puntos de integración y riesgos.
- [ ] Verificar código publicado y protección real del módulo Deudas.
- [ ] Preparar respaldo verificable y prueba de restauración de datos de producción (solo con autorización).
- [ ] Implementar acceso adicional del lado del servidor y pruebas de bypass.
- [ ] Crear navegación CL Nexus con módulos aislados y permisos.
- [ ] Adaptar Inventario V17 al inicio de sesión unificado y al backend definitivo.
- [ ] Importar MERCADERIA únicamente, tras conciliar ubicaciones y duplicados.
- [ ] Probar sincronización, permisos, PWA, actualizaciones, desconexión y recuperación.
- [ ] Publicar tras aprobación explícita.

## Reglas de seguridad
- No modificar `main`, Supabase de producción ni datos reales durante las pruebas.
- No crear usuarios, contraseñas ni claves en el repositorio.
- No declarar como implementada una función que solo aparece en la interfaz.
- No aprobar recibos de prueba ni importar productos ficticios.
