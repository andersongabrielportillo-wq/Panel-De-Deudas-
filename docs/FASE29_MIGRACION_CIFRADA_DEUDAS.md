# Migración cifrada de caché Deudas — procedimiento controlado (rama de integración)

Estado: **PREPARACIÓN / NO-GO**. No aplicar en producción ni borrar cp_v2.

## Componentes implementados
- `debt-legacy-backup.cjs`: captura exacta de cp_v2, cp_v2_bak, cp_v2_corrupt, cp_prev, cp_items y cp_pend; restauración únicamente si las claves de destino están vacías.
- `debt-encrypted-backup.cjs`: exportación AES-256-GCM con PBKDF2-SHA256 (310 000 iteraciones), sal aleatoria e IV aleatorio. La frase no se almacena.
- `index.html`: botón de exportación manual tras verificar acceso a Deudas, actualmente oculto porque DEBT_GATE_ENABLED=false.
- `sw.js`: incluye los módulos en caché de la rama.

## Prueba con datos ficticios
1. Crear almacenamiento de prueba aislado con cp_v2 de transacciones inventadas, cp_v2_bak y cp_pend=1.
2. Capturar y cifrar con frase larga de prueba. Confirmar que JSON cifrado no contiene nombres ni movimientos.
3. Descifrar con frase correcta y comparar todos los valores y el indicador cp_pend.
4. Rechazar frase incorrecta, modificación del cifrado y archivo con campos inesperados.
5. Restaurar exclusivamente en almacenamiento vacío. Rechazar cualquier destino con una clave existente, sin sobrescribirla.
6. Simular fallo de escritura y verificar recuperación; confirmar que la fuente original nunca se modificó.
7. Repetir en navegador PWA de laboratorio con cuentas reales y un dispositivo secundario.

## Riesgos pendientes
- La restauración está disponible como función, **no** conectada aún a una pantalla de importación: no se debe importar mientras el estado de la app esté activo o sincronizando.
- La copia cifrada es una exportación de recuperación, **no** cifrado del almacenamiento local persistente. cp_v2 sigue en texto claro hasta completar una migración de almacenamiento.
- El indicador cp_pend por sí solo no garantiza sincronización completa. No borrar claves originales sin reconciliación de movimientos y consentimiento.
- El control de Deudas requiere políticas RLS de producción y sesiones reales antes de activarse.
- Los respaldos cifrados son irrecuperables si se pierde la frase; deben conservarse en un lugar seguro.
- No se han ejecutado los tests del repositorio en GitHub Actions ni pruebas de dos dispositivos reales.

## Criterios de GO
Pruebas automatizadas aprobadas, restauración segura sin sincronización concurrente, cifrado local en reposo o política explícita de eliminación, auditoría de pendientes, backup de base de datos verificable, pruebas Auth/RLS/Realtime con admin y secretaria, autorización de publicación.
