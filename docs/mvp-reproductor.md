# Reproductor y bloqueo — evidencia de integración

Responsable: Jeffersson Daniel Ramos (`@ramosdeleon555`). Fecha de revisión:
22 de octubre de 2026. Commit revisado: `1232499`.

Fuente: `docs/plan-mvp.md`, secciones 8.4, 9.1, 10, 11 y 12; y las
dependencias registradas en `docs/mvp-carmen.md`. Este documento describe el
estado real del módulo; no declara terminado el audio real ni la aceptación
Android.

## 1. Alcance que corresponde al reproductor

- **MVP-07:** audio local y cola.
- **MVP-08:** bloquear y desbloquear de forma persistente.
- **Integración con MVP-06:** confirmar la liberación de una pista antes de que
  Descargas borre su archivo.
- **MVP-11:** participación en la prueba Android de reinicio y modo avión.
- **MVP-12:** documentación y evidencias de este módulo.
- **QA / Release:** revisión de PRs, CI verde y evidencia de entrega.

## 2. Matriz de avance

| Actividad | Estado actual y evidencia | Dependencia o siguiente paso |
| --- | --- | --- |
| MVP-07, modelo y cola compartidos | Parcial. El reproductor usa `PlayerSongLocal` y tres canciones mock (`features/player/player_song_local.dart`, `mock_player_data.dart`). No consume `Song` ni las descargas reales. | Migrar a `core/models/song.dart` y cargar la cola desde `DownloadRepository` o `downloadEntriesProvider`. |
| MVP-07, motor de audio real | Pendiente. `PlayerStore` simula posición y duración con `Timer` (`player_store.dart:86`). `just_audio` no está en `pubspec.yaml` y no existe `PlaybackController` en `core/contracts/`. | Henry debe incorporar la dependencia y el contrato acordado; después implementar el motor real detrás de ese contrato. |
| MVP-07, ciclo de vida fuera de la pantalla | Pendiente. El store se crea dentro de `PlayerScreen` (`player_screen.dart:21-24`), por lo que el motor no vive en un proveedor raíz. | Mover el controlador y el motor a un proveedor Riverpod de alcance raíz; evitar reproductores duplicados al cambiar de pestaña. |
| MVP-07, selección por ID y navegación | Pendiente. El reproductor es una pestaña en `main.dart:39`; Inicio usa `onTap: () {}` (`song_list_section.dart:32`) y las filas de Búsqueda y Descargas todavía no abren una pista. | Acordar con Douglas la ruta o el método para abrir el reproductor por `songId` y conectar Inicio, Búsqueda y Descargas. |
| MVP-07, controles y errores | Parcial. Existen play/pausa, seek, anterior y siguiente sobre datos mock. No hay eventos del motor, manejo de archivo ausente/corrupto, duración desconocida ni fin real de cola. | Reemplazar el temporizador por posición, duración y estado del motor; cubrir los errores con un motor falso y pruebas. |
| MVP-08, bloqueo persistente | Parcial. `blockedIds` es un `Set` en memoria (`player_store.dart:15`). `PlaybackPreferencesRepository` existe como contrato, pero no tiene implementación. | Implementar el repositorio sobre `BlockedSongDao`, cargar los bloqueos al iniciar y persistir por colección. |
| MVP-08, desbloqueo y cola bloqueada | Pendiente. Solo existe “Bloquear canción”; no hay forma visible de desbloquear. El estado vacío aparece cuando todo está bloqueado, pero no hay audio real que detener. | Añadir desbloqueo, respetar la colección `offline` y detener el motor cuando no queden pistas disponibles. |
| Integración con MVP-06, eliminación | Pendiente. `canDeleteAudioProvider` devuelve `false` por defecto (`download_providers.dart:30`); por eso las eliminaciones vencidas conservan el archivo indefinidamente. | El módulo de reproducción debe sobrescribir el proveedor y confirmar la liberación solo cuando la pista no esté activa. |
| MVP-10, pruebas del módulo | Parcial. Hay 4 pruebas del store mock (`test/features/player/player_store_test.dart`). No hay pruebas de motor, persistencia de bloqueos, widgets ni integración Android. | Añadir pruebas con motor falso, DAO/repositorio persistente y widgets; mantenerlas en `test/features/player/`. |
| MVP-11, aceptación Android | Pendiente. No hay dispositivo conectado, API/motor integrados ni `integration_test/`. | Completar el flujo con audio real, reinicio, modo avión, bloqueo/desbloqueo y eliminación de la pista activa. |
| MVP-12, documentación y evidencias | Parcial. Este documento registra el estado y los límites. | Añadir resultados Android, dispositivo, versión y commit; enlazar el video de aceptación. |
| QA / Release | Pendiente. El CI existe en `.github/workflows/ci.yml`, pero no hay evidencia de esta revisión en un PR ni aceptación Android. | Revisar PRs pendientes, confirmar CI verde y registrar la evidencia de release. |

## 3. Evidencia ejecutada

Comandos ejecutados desde `soundwave/` el 22 de octubre de 2026:

```sh
flutter test --no-pub test/features/player/player_store_test.dart
flutter test --no-pub
flutter analyze
```

Resultados:

- Pruebas del reproductor: **4 aprobadas**.
- Suite completa: **48 aprobadas** y **1 omitida** (`welcome_to_noxville_manual_network_test.dart`, que requiere `RUN_COMMONS_NETWORK_TEST=true`).
- `flutter analyze`: **sin problemas**.

Estos resultados validan el código actual del repositorio; no validan audio real,
persistencia de bloqueos ni reproducción en Android.

## 4. Límites que no deben ocultarse

- El reproductor actual reproduce una simulación, no audio.
- Los bloqueos se pierden al reiniciar la aplicación.
- No existe integración con Descargas para confirmar la liberación de archivos.
- No se ha probado el flujo en modo avión ni después de cerrar la aplicación.
- La pestaña “Reproductor” no demuestra que una canción descargada abra la pista
  correcta.
- No se instalaron dependencias ni se modificaron contratos compartidos en esta
  revisión.

## 5. Dependencias y decisiones pendientes

1. **Henry:** incorporar `just_audio` y definir el contrato `PlaybackController`
   con firmas, errores y unidades.
2. **Henry y Carmen:** confirmar el uso de `Song`, `DownloadRepository`,
   `AudioFileStore` y `BlockedSongDao` sin duplicar modelos locales.
3. **Carmen:** acordar la semántica de `canDeleteAudioProvider` y el orden
   seguro entre detener/liberar la pista y borrar el archivo.
4. **Douglas y JavEstrada09:** acordar cómo Inicio y Búsqueda abren una canción
   por su ID canónico.
5. **Douglas:** decidir si el reproductor sigue como pestaña o se abre desde una
   canción, según `docs/ux/soundwave-design.md`.
6. **Equipo:** disponer de un dispositivo Android y de la API/motor integrados
   para la aceptación real.

## 6. Plan de implementación recomendado

1. Acordar contrato, dependencia y punto de composición con Henry.
2. Sustituir `PlayerSongLocal` por `Song` y construir la cola desde descargas
   completadas.
3. Implementar el motor real detrás de `PlaybackController` y un motor falso para
   pruebas.
4. Mover el estado a un proveedor raíz y conectar la apertura por `songId`.
5. Implementar el repositorio persistente de bloqueos y el desbloqueo.
6. Sobrescribir `canDeleteAudioProvider` y coordinar la eliminación de la pista
   activa con Carmen.
7. Añadir pruebas de motor, persistencia y widgets.
8. Ejecutar formato, análisis y pruebas; después completar la matriz Android y
   registrar la evidencia.
