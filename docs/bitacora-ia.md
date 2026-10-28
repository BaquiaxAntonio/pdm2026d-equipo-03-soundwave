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

## 2026-10-22 · @ramosdeleon555 — revisión del reproductor y evidencia

- **Herramienta:** opencode.
- **Especificación:** revisar `docs/mvp-carmen.md` y `docs/plan-mvp.md` para
  identificar las tareas de Jeffersson Daniel Ramos, verificar el estado real
  del módulo de reproducción y crear un documento de evidencia sin declarar
  audio real ni aceptación Android.
- **Resultado:** se creó `docs/mvp-reproductor.md` con la matriz de MVP-07,
  MVP-08, MVP-11 y MVP-12, las dependencias con Carmen, Henry y Douglas, y los
  límites verificados del código actual.
- **Aceptado:** la matriz, el checklist y los resultados de las pruebas. El
  documento usa un nombre descriptivo en lugar de un nombre personal.
- **Rechazado / corregido:** no se instalaron dependencias ni se modificaron
  contratos compartidos; el reproductor sigue siendo el mock fusionado en
  PR #16. No se presentó la simulación como reproducción real.
- **Verificación:** `flutter test --no-pub` (48 aprobadas, 1 omitida por red);
  `flutter test --no-pub test/features/player/player_store_test.dart`
  (4 aprobadas); `flutter analyze` sin problemas.
- **Commit / PR:** pendiente.

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