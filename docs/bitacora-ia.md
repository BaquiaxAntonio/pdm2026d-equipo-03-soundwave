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

## 2026-10-18 · @Ortizcarmen — S14, estados de Descargas (pasos 5 y 6)

- **Herramienta:** Codex.
- **Especificación:** leer las dos páginas del laboratorio, verificar el paso 4 de Henry (`66f9e52`), implementar cuatro estados y pruebas widget con overrides, conservar SQLite, eliminación y Deshacer, y publicar el PR de #31.
- **Resultado / aceptado:** `repository_download_view.dart` consume `downloadEntriesFutureProvider` con `AsyncValue.when`; conserva el Stream para invalidar el snapshot ante cambios reales. Error humano con Reintentar, vacío con navegación a Buscar y regreso, carga y lista con el diseño existente. El modo demo existente se conserva.
- **Archivos:** pantalla anterior y `test/features/downloads/repository_download_view_test.dart`; formato de `download_providers.dart` y `download_entries_future_provider_test.dart`; esta bitácora. Contrato Future, SQLite, falsos y retry desactivado del paso 4 verificados sin crear otra arquitectura.
- **Rechazado / corregido:** la primera ejecución de pruebas detectó doble invalidación del Future al refrescar el Stream y ausencia de botón Atrás en la ruta de búsqueda; se evitó invalidar con valores retenidos durante loading y se agregó AppBar. No se recrea la sesión SQLite al recuperarse de un fallo de lectura. Se excluyeron archivos generados por Flutter.
- **Verificación:** `dart format lib test`; `flutter test --reporter expanded`: **52 pruebas aprobadas**, incluyendo error y recuperación sin retry automático, carga con Completer, vacío con navegación, datos, eliminación/Deshacer y navegación del MVP. `dart analyze`: sin problemas. `flutter analyze` falló inicialmente en el protocolo LSP con `FormatException`; el SDK usa `message.length` para Content-Length y la ruta contiene una tilde. Con un alias temporal ASCII (`subst W:`), `flutter analyze` pasó sin modificar ni desactivar el análisis.
- **Entrega:** PR chore/ci #29 integrado con aprobación y checks verdes; ruleset activo de main verificado por API (PR, una aprobación, Code Owners, check de calidad y sin force push). No se intentó push directo a main ni se cambió la protección. No se realizó demostración visual en dispositivo; quedan las capturas de la regla y del push rechazado y la aprobación externa para la entrega del equipo en Moodle.
- **Commit / PR:** rama `feat/31-estados-descargas`, vinculada con #31; enlace del PR disponible al publicar.

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
