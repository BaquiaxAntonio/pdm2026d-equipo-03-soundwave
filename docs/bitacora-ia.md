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

## 2026-10-29 · @Ortizcarmen — integración del PR #32 con main

- **Herramienta:** Codex.
- **Solicitud:** resolver conflictos preservando los aportes de todos; sin cambiar protecciones ni stashes.
- **Cambio:** integración de `main` (`9d21967`, incluye #38, #39 y #40), conservación de ambas entradas de la bitácora y adaptación del repositorio falso de Búsqueda al contrato `loadDownloads` de #32.
- **Verificación local:** copia aislada con ruta ASCII y caché nueva; `flutter pub get`, formato, análisis sin incidencias y suite completa con 128 aprobadas, 0 fallidas y 1 prueba externa omitida. No se declara descarga externa ni reproducción real.
- **Entrega:** actualización del PR #32; compilación y checks remotos se verifican después de publicar.

## 2026-10-18 · @Ortizcarmen — S14, estados de Descargas (pasos 5 y 6)

- **Herramienta:** Codex.
- **Especificación:** leer las dos páginas del laboratorio, verificar el paso 4 de Henry (`66f9e52`), implementar cuatro estados y pruebas widget con overrides, conservar SQLite, eliminación y Deshacer, y publicar el PR de #31.
- **Resultado / aceptado:** `repository_download_view.dart` consume `downloadEntriesFutureProvider` con `AsyncValue.when`; conserva el Stream para invalidar el snapshot ante cambios reales. Error humano con Reintentar, vacío con navegación a Buscar y regreso, carga y lista con el diseño existente. El modo demo existente se conserva.
- **Archivos:** pantalla anterior y `test/features/downloads/repository_download_view_test.dart`; formato de `download_providers.dart` y `download_entries_future_provider_test.dart`; esta bitácora. Contrato Future, SQLite, falsos y retry desactivado del paso 4 verificados sin crear otra arquitectura.
- **Rechazado / corregido:** la primera ejecución de pruebas detectó doble invalidación del Future al refrescar el Stream y ausencia de botón Atrás en la ruta de búsqueda; se evitó invalidar con valores retenidos durante loading y se agregó AppBar. No se recrea la sesión SQLite al recuperarse de un fallo de lectura. Se excluyeron archivos generados por Flutter.
- **Verificación:** `dart format lib test`; `flutter test --reporter expanded`: **52 pruebas aprobadas**, incluyendo error y recuperación sin retry automático, carga con Completer, vacío con navegación, datos, eliminación/Deshacer y navegación del MVP. `dart analyze`: sin problemas. `flutter analyze` falló inicialmente en el protocolo LSP con `FormatException`; el SDK usa `message.length` para Content-Length y la ruta contiene una tilde. Con un alias temporal ASCII (`subst W:`), `flutter analyze` pasó sin modificar ni desactivar el análisis.
- **Entrega:** PR chore/ci #29 integrado con aprobación y checks verdes; ruleset activo de main verificado por API (PR, una aprobación, Code Owners, check de calidad y sin force push). No se intentó push directo a main ni se cambió la protección. No se realizó demostración visual en dispositivo; quedan las capturas de la regla y del push rechazado y la aprobación externa para la entrega del equipo en Moodle.
- **Commit / PR:** rama `feat/31-estados-descargas`, vinculada con #31; enlace del PR disponible al publicar.
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
