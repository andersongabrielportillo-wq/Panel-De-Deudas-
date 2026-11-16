# Laboratorio aislado — instrucciones de apertura

Estado: **maqueta offline**. No es una PWA conectada, no sincroniza y no prueba JWT. No se publica ni modifica la aplicación real.

## Descarga sin alojamiento ni costo
1. En GitHub Actions, abrir el workflow **Laboratorio aislado - paquete descargable** de la rama `integracion-inventario-fase15`.
2. Abrir la ejecución exitosa y descargar el artefacto `laboratorio-pwa-sin-datos` (archivo ZIP; caduca a los 14 días).
3. Extraer el ZIP en la computadora; abrir `index.html` en Chrome/Edge.
4. En el teléfono, transferir **solo el archivo HTML** por un medio de confianza y abrirlo localmente en el navegador. No instalarlo encima de la PWA real ni usar el mismo acceso directo.
5. Probar los botones de Inventario, Contratos y Deudas. Ninguno permite guardar ni acceder a datos.

## Qué NO se valida
- No hay login, backend, datos reales, Realtime, Service Worker ni instalación PWA.
- La maqueta en dos dispositivos **no implica sincronización**.
- La versión conectada requerirá una base de pruebas **separada**, cuentas ficticias, controles de acceso y un dominio/origen de staging aislado.
- No publicar GitHub Pages ni fusionar la rama sin aprobación explícita.
- No pegar URLs/keys ni credenciales productivas en este HTML.

## Siguiente puerta de decisión
Elegir alojamiento separado y entorno Supabase aislado, verificar disponibilidad/costo, aplicar migraciones con datos ficticios, luego JWT y pruebas en dos dispositivos.
