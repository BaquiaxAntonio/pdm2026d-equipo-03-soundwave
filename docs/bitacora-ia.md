# Bitácora de uso de IA

Cada uso de IA que termine en el repositorio se registra aquí, con el más
reciente primero. El objetivo es demostrar criterio: qué se pidió, qué se
revisó y qué se corrigió antes de integrar el cambio.

| Campo | Qué registrar |
| --- | --- |
| Fecha / autor | Fecha y usuario de GitHub responsable del cambio |
| Herramienta | Asistente utilizado |
| Especificación | Solicitud y restricciones relevantes |
| Resultado | Resumen de la propuesta recibida |
| Aceptado | Qué se incorporó y por qué |
| Rechazado / corregido | Qué se cambió o descartó y por qué |
| Verificación | Comandos, pruebas o dispositivo utilizado |
| Commit / PR | Enlace cuando exista |

---

## 2026-10-25 · Laboratorio 4, fase de eliminación y Deshacer

- **Herramienta:** Codex.
- **Solicitud:** completar la rama compartida y el PR #36 sin rehacer la
  navegación y los filtros de Henry; conservar cambios y stashes existentes.
- **Revisión:** se leyeron las dos páginas de `Lab4 D.pdf`, el código y el PR.
  No se encontró `AGENTS.md` en el repositorio. Navegación con Notifier,
  IndexedStack, Ver todo, scroll y filtro dependiente ya estaban implementados.
- **Implementación:** Dismissible con `ValueKey(songId)` y escritura en el
  repositorio antes de retirar la fila. Se reutilizan `requestRemoval` y
  `undoRemoval`: eliminación lógica persistente, plazo individual de Deshacer
  y limpieza física posterior cuando el coordinador autoriza liberar el audio.
  El último SnackBar corresponde a la última eliminación; las anteriores
  conservan su botón de Deshacer individual durante su plazo.
- **Corregido / rechazado:** no se añadió otro repositorio ni se borraron
  archivos de audio directamente desde la UI. `confirmDismiss` retorna false
  porque el stream retira la fila tras persistir; así no queda un Dismissible
  descartado en el árbol. Si falla la escritura, la fila vuelve a su posición.
  Se conservaron las fechas originales al eliminar/restaurar para que el mapa
  del registro restaurado sea idéntico. Se corrigió el formato de `main.dart`,
  causa del fallo previo de CI.
- **Verificación local:** `flutter pub get`, `dart format lib test`,
  `flutter analyze` (sin incidencias), `flutter test` (58 aprobadas, 0 fallidas,
  1 prueba de red externa omitida). Pruebas widget de filtro y vacío, deslizar,
  Deshacer, fallos de eliminación/restauración y eliminaciones consecutivas
  asíncronas con filtro activo. Prueba SQLite con cierres/reaperturas reales:
  eliminación pendiente persiste, restauración conserva el mapa completo y
  bytes, no hay duplicados y eliminación vencida se finaliza al autorizarse.
  Se usó la unidad W: para evitar problemas de rutas con tildes en Windows.
  No se realizó comprobación visual en dispositivo o emulador.
- **Entrega:** PR #36; aprobación por otra pareja e integración en main
  dependen de revisión humana. No se fusionó el PR.

## 2026-10-18 · @BaquiaxAntonio — configuración de CI de SoundWave

- **Herramienta:** Codex (asistente de código de OpenAI).
- **Especificación:** revisar la guía del laboratorio S14 y la referencia
  `s14-06-ci` de `saulecch/inkash_d`; preparar los archivos de CI para
  SoundWave, sin alterar funcionalidades de la aplicación ni cambios locales
  ajenos.
- **Resultado:** se configuraron un workflow de GitHub Actions, plantilla de
  Pull Request, `CODEOWNERS` y esta bitácora.
- **Aceptado:** workflow con formato, análisis, pruebas SQLite y APK de
  depuración; la raíz Git contiene `soundwave/`, por lo que los comandos se
  ejecutan desde ese directorio y las rutas de Code Owners se ajustaron.
- **Rechazado / corregido:** se descartaron los campos específicos de Inkash
  (centavos, `occurredOn` y rutas de sus repositorios). La primera ubicación de
  los archivos fue `soundwave/.github`; se corrigió a la raíz que GitHub usa
  para workflows, plantillas y Code Owners.
- **Verificación:** pendiente de completar las comprobaciones locales; el CI
  debe quedar en verde en el Pull Request.
- **Commit / PR:** PR #29.
