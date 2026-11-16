# Fase 18 — Corrección de concurrencia UI antes del montaje

Se corrigieron dos errores de ciclo de vida en `staging/index.html`:

1. Una consulta abortada al cambiar módulo podía mantener `busy=true` hasta que finalizara una petición anterior; ahora se libera inmediatamente, y el `finally` solo modifica el estado si la petición aún es la activa.
2. El login llamaba `show('inventario')` antes de `stop()`, abortando la carga inicial. Ahora cancela tareas previas antes de iniciar la vista y el intervalo.
3. La carga conserva `requestedView` y solo presenta datos si `ticket===seq`, `session===s` y `view===requestedView`.
4. Dos nuevas pruebas de regresión añadidas a `tests/fase18-staging.test.mjs`.

No se ha montado el staging en la PWA de producción, ni se ha autorizado publicar o mezclar ramas. Las pruebas de navegador HTTP reales siguen pendientes.
