# Fase 19 — Integración de CL Nexus en Panel de Deudas

## Estado y límites verificados
- Rama de trabajo: `integracion-inventario-fase15`. No fusionar a `main` antes de completar el lanzamiento controlado.
- `index.html` usa el Supabase de producción `josdmjjbnrugiwlwgjky`, almacena y sincroniza el estado de Deudas mediante `debts`, `workspace_members` y Realtime. **No sustituir ni migrar este estado automáticamente**.
- `staging/index.html` usa exclusivamente el Supabase de pruebas `dozcnytevqhoymzqlxah`, con sesión independiente y lectura de inventario/contratos.
- La interfaz de staging incluye navegación Inventario, Garantías, Contratos y Deudas; Garantías y Deudas no tienen API conectada allí. La interfaz real de `index.html` aún no monta CL Nexus.
- Las pruebas HTTP autenticadas quedaron sin completar por decisión del propietario. No declararlas aprobadas ni reabrir esa fase.

## Contrato de integración antes de lanzar
1. **Un inicio de sesión:** mantener el flujo Auth de la PWA real. No introducir una segunda pantalla de credenciales ni reutilizar credenciales del proyecto de pruebas en producción.
2. **Separación estricta:** datos y RPC de inventario/garantías/contratos separados del estado `debts`; nunca escribir inventario dentro de `cp_v2` ni `__shared_state__`.
3. **Autorización de Deudas:** el desbloqueo adicional debe verificarse en servidor y cubrir API, no solamente ocultar un botón. La PWA actual no demuestra este control; bloquear publicación hasta implementarlo y validarlo.
4. **Permisos:** admin y secretaria con controles de autorización en servidor, no por etiquetas en el navegador.
5. **Operaciones:** entradas, salidas, traslados, devoluciones pendientes de revisión, garantías y contratos requieren endpoints/RPC confirmados en el proyecto de destino y pruebas de integridad.
6. **Sincronización:** conservar la suscripción actual de Deudas; cada módulo nuevo necesita sus propias suscripciones o refresco seguro, con cancelación al cerrar sesión.
7. **Actualizaciones PWA:** mantener `manifest.webmanifest`, `sw.js` y aviso de actualización; aumentar versión de caché solo cuando se publique la versión integrada y se compruebe la actualización.
8. **Lanzamiento:** copia de seguridad verificada, plan de reversión, pruebas funcionales con tres usuarios, revisión de accesos, publicación controlada y seguimiento de errores.

## Secuencia de implementación
- [x] Auditar puntos de acoplamiento de Auth, Realtime y shell de la PWA.
- [x] Documentar frontera de seguridad y contrato de integración.
- [ ] Crear adaptador de módulos en la rama, desacoplado de `debts` y con sesión Auth real.
- [ ] Montar menú y vistas en `index.html` preservando navegación y funciones actuales.
- [ ] Conectar APIs de inventario, garantías y contratos del entorno de destino con autorización de servidor.
- [ ] Implementar protección adicional de Deudas en servidor y cliente.
- [ ] Pruebas de UI, roles, sincronización y recuperación ante fallos sin retomar el workflow HTTP omitido.
- [ ] Lanzamiento controlado con autorización explícita.

**Advertencia:** el proyecto de pruebas y el de producción tienen IDs distintos; la existencia de RPCs en pruebas no implica que estén desplegadas en producción. No conectar la UI real a un backend ficticio ni copiar claves secretas al frontend.
