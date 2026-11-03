# Actividades de Carmen — evidencia de integración

## Auditoría y actualización — 3 de noviembre de 2026

### Revisión previa a publicación

Se repitió `git fetch origin`: `main`, `origin/main` y la base de esta rama
siguen en `c7101539dc926a8b7c05c518697271936a71750b`; no hay cambios nuevos
que incorporar ni conflictos con main. #48/#49 siguen fusionados y #50/#51
abiertos. La publicación de esta rama y solicitud de revisión están autorizadas;
la referencia a «sin commit, push ni PR» más abajo describe la entrega anterior.

Se revisó #51 en `9adf7c37bc3e9baf2d79ae83159f4f188afb22ef` sin fusionarlo.
Coinciden seis archivos de producción (`download_factory_native.dart`,
`download_factory_stub.dart`, `download_input.dart`, `http_audio_downloader.dart`,
`sqlite_download_repository.dart`, `download_providers.dart`) y la prueba
`sqlite_download_repository_test.dart`.

Contratos que requieren conciliación con Ramos al integrar #51:

- Conservar una sola composición `createOpenDownload`, los créditos verificados,
  tamaño/SHA-1 y limpieza inmediata de temporales de esta rama.
- Conservar su nuevo `DownloadSession.localAudioUri`: resuelve una ruta relativa
  privada a una URI de archivo y alimenta su motor real. Esta rama no añade un
  segundo contrato de rutas ni sustituye su motor/dependencia `just_audio`.
- Conservar su `releaseForDeletion`, conectado por la composición de reproducción.
  Esta rama mantiene `canDeleteAudioProvider` en false: no basta pausar ni asumir
  que un recurso está liberado. Borrar/Deshacer permanecen seguros y reversibles.
- Su ampliación de formatos requiere conservar validaciones de cada contenedor
  y SHA-1. Esta rama mantiene WAV PCM canónico hasta esa integración.
- #50 cambia el manejo de procedencia ausente. Se sigue usando el resolver de
  Búsqueda sin relajar sus comprobaciones ni fabricar autorización desde la UI.

El PR de Descargas se presenta pendiente de conciliación con #51 y aceptación
Android, con referencias a #7 y #31 sin cerrar automáticamente esos issues.

La comprobación `git merge-tree --write-tree` (sin fusionar la rama) detectó
conflictos de contenido en factory y providers. Se alinearon de forma segura
el orden de imports y la composición del provider con #51. Permanece el punto
de integración de créditos en `download_factory_native.dart`: main ofrece
`audio.attribution`, mientras #51 añade `audio.song`. Ambos preservan créditos;
al integrar #51 se debe usar su canción verificada conservando las protecciones
de esta rama. No se puede consumir `audio.song` aquí antes de integrar ese
contrato, por lo que se documenta el conflicto y se solicita revisión.

Validación repetida antes de publicación: `flutter pub get`, formato y análisis
aprobados; suite completa con 199 aprobadas, 2 omitidas y 0 fallidas. La prueba
externa también se repitió: 2 aprobadas, incluidos los 647212 bytes de Commons,
verificación SHA-1 y conservación de archivo/créditos después de reabrir SQLite.

Esta sección sustituye el estado histórico de la matriz inferior. Alcance:
Descargas de Carmen; sin CRUD de usuarios, cambios del motor de audio ni migraciones.

### GitHub y base de trabajo

- `main` local actualizado por fast-forward de `836c50c` a
  `c7101539dc926a8b7c05c518697271936a71750b`, igual a `origin/main` consultado.
- Rama nueva: `fix/carmen-descargas-reales`, desde esa base. Se conservaron todas
  las ramas, los worktrees existentes y los cinco stashes. Sin commit, push ni PR.
- Carmen: [#48](https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave/pull/48)
  fusionado; incluye refresco de listas y pruebas CRUD (`edde068`).
- Henry: [#49](https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave/pull/49)
  fusionado; migración SQLite v3 idempotente (`a3e973c`). No se modificó.
- Douglas: #45, #46 y #47 fusionados; Inicio usa biblioteca y navegación por ID.
- JavEstrada09: [#50](https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave/pull/50)
  abierto, rama `464dad6`, corrige procedencia y créditos ausentes.
- Ramos: [#51](https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave/pull/51)
  abierto, rama `9adf7c3`, propone audio real, composición y formatos ampliados.
- CI de `main` #41395195750 y checks de #50/#51 exitosos al consultar. No se
  fusionaron ramas pendientes ni se confundió su implementación con la de main.
- Issues abiertos: #2, #4, #6, #7, #8, #9, #10 y #31; los títulos/estados no
  sustituyen la comprobación del código ni la evidencia Android.

### Funcionalidades revisadas

| Funcionalidad | Clasificación y evidencia actual |
| --- | --- |
| Búsqueda Commons | Implementada y verificada por pruebas existentes en `search/commons_*`; `CommonsCatalogRepository.searchWithContext`, fallback y debounce ya existían (#39). |
| URL autorizada | Implementada y verificada para la muestra revisada: `CommonsAudioResolver.resolve` ya existía; se conecta ahora al proveedor nativo. Rechaza archivos sin evidencia, identidad diferente, URL o licencia no autorizadas. |
| HTTP real | Implementada y verificada: `HttpAudioDownloader.open`; descarga externa de 647212 bytes y SHA-1 verificado. HTTPS, MIME, estado, timeout y redirecciones desactivadas ya existían. Se añaden User-Agent y tamaño del proveedor. |
| Archivo privado | Implementada en `createSession` y `LocalAudioFileStore.commit`; archivos reales verificados en Windows. Parcial respecto de aceptación Android: no se ejecutó la app en Android. |
| SQLite y créditos | Implementada y verificada: `SqliteDownloadRepository`, `SongDao`, esquema de Henry. El proveedor nativo guarda los créditos actuales devueltos por el resolver. Prueba externa cierra y reabre SQLite conservando audio/créditos. |
| Estados, progreso y reintento | Implementados y verificados por pruebas de repositorio y widgets; no se reimplementaron. Los bytes recibidos y tamaño real alimentan el progreso. |
| Duplicados | Implementados; se corrige el sobrescrito de créditos previo al rechazo: reserva y actualización de canción en una transacción. |
| Integridad | Implementada y verificada para WAV PCM canónico. Nuevo SHA-1 contra metadatos del proveedor antes de `completed`; corrupción y archivo incompleto fallan sin ruta disponible. |
| Recuperación | Implementada y verificada: `recoverInterrupted` marca interrupciones/archivos ausentes o inválidos como fallidos; pruebas previas incluyen reapertura real de SQLite. |
| Riverpod / Búsqueda → Descargas | Implementada y verificada: un solo `openDownloadProvider` y `downloadSessionProvider`; prueba nueva recorre acción de Search, HTTP local, SQLite y créditos. |
| Listado/filtros/loading/error/empty/data | Implementados y verificados; se preservan #32/#36 y sus pruebas. Sin rediseño de pantallas. |
| Eliminar y Deshacer | Implementados y verificados: `requestRemoval`, `undoRemoval`, `finalizeExpiredRemovals`; conserva archivo hasta vencer plazo y recibir permiso del coordinador. |
| Limpieza de temporales | Implementada; se añade limpieza inmediata del parcial al terminar/fallar, además de reconciliación al reiniciar. Fallos de limpieza quedan para el próximo inicio. |
| Borrado durante reproducción | Seguro por defecto: `canDeleteAudioProvider` devuelve false y retiene archivo. Integración de liberación bloqueada por Ramos; la guarda actual de main solo considera `isPlaying` y no demuestra liberación de un recurso pausado. |
| Reproducción local real | Bloqueada por integración de #51: main no tiene la dependencia de audio real y conserva controladores simulados. No se modificó el motor. |
| Archivado | Descargas usa eliminación pendiente; el archivado existente pertenece a listas. No se añadió un contrato nuevo de archivado de descargas. |
| Cancelación | Fuera de alcance: no se encontró confirmación del equipo/profesor en issues/PR/plan consultados. |

### Cambios y compatibilidad

Archivos de producción modificados, todos dentro de Descargas:
`data/download_factory_native.dart`, `data/download_factory_stub.dart`,
`data/download_input.dart`, `data/http_audio_downloader.dart`,
`data/sqlite_download_repository.dart` y `download_providers.dart`.
Pruebas: `http_audio_downloader_test.dart`, `sqlite_download_repository_test.dart`
y nueva `commons_download_integration_test.dart`. Se actualizan este informe
y `soundwave/lib/features/downloads/data/README.md`.

`DownloadInput.expectedSha1` y `PermittedAudio.sha1/size` son opcionales para
conservar compatibilidad con los consumidores actuales. Se reutiliza `crypto`
ya instalado. No cambian esquema, dependencias, modelos ni providers compartidos.
No hubo conflictos Git. Se corrigió durante validación una incompatibilidad
entre `SongDao(Database)` y `Transaction`, usando la transacción ya abierta.

Antes de integrar hay que conciliar con #51 los archivos de Descargas que ese PR
también modifica: factory, providers, input, transporte y repositorio. Se usan
los mismos nombres de checksum y tamaño que propone ese PR. No se copiaron sus
cambios del motor ni su ampliación de formatos. #50 afecta las ausencias de
procedencia: se sigue delegando la autorización al resolver del responsable.

### Verificación y límites

- `flutter pub get` aprobado; sin actualizar versiones de dependencias.
- `dart format` ejecutado sobre Descargas y sus pruebas.
- `flutter analyze --no-pub` aprobado tras usar ruta ASCII temporal `W:`.
- Suite completa inicial: 198 aprobadas, 1 externa omitida.
- Suite completa final: 199 aprobadas, 2 externas omitidas, ninguna fallida.
- Suite Descargas tras agregar prueba de composición nativa: 46 aprobadas,
  1 externa omitida.
- Prueba externa nueva con `RUN_COMMONS_NETWORK_TEST=true`: 2 aprobadas.
  Se consultó el resolver real, descargaron 647212 bytes desde Commons,
  verificaron SHA-1 y WAV, cerró/reabrió SQLite y comprobaron archivo y créditos.
  Es evidencia de Windows con HTTP/SQLite/archivos reales; no demuestra Android.
- Las primeras ejecuciones fallaron por LSP en ruta con tilde y caché nativa
  apuntando a `W:` ausente. La asignación temporal del repositorio a `W:` permitió
  validar sin borrar cachés ni alterar fuentes de otros módulos.
  Para reproducir: asignar `W:` a la raíz del repositorio con `subst`, ejecutar
  los comandos desde `W:\soundwave` y retirar la asignación con `subst W: /D`.
- `flutter devices`: Windows, Chrome y Edge; ningún Android conectado.
  No se comprobó instalación, sonido, cierre forzado ni modo avión en Android.

Pendientes para cierre: Ramos debe integrar audio real y confirmación de
liberación; JavEstrada09 ampliar evidencia de pistas/formatos y completar #50;
Douglas coordinar aceptación Android sobre la integración final. La migración
v3 de Henry ya está disponible y no bloquea estas pruebas. La rama requiere
reconciliación con #51 y aceptación Android antes de declarar completo el módulo.

Fuente: `docs/plan-mvp.md`, leído completo. Esta matriz registra avance y
dependencias; no modifica el alcance ni sustituye la aceptación Android.

| Actividad del plan | Implementación / evidencia | Dependencia real |
| --- | --- | --- |
| MVP-01, revisión de Descargas | PR #26 revisado, actualizado sin conflictos y fusionado; prueba de navegación preservada | Ninguna |
| MVP-02, revisar API con Henry | Transporte y resolver desacoplados; sin endpoints inventados | Falta selección y evidencia de permisos de la API por su responsable |
| MVP-03/04, revisar contratos y aportar requisitos de archivos | PR #25 aprobado y fusionado; implementación consume Song, DownloadRecord, contratos y DAO existentes | Coordinar formatos de audio definitivos y callback de liberación con sus responsables |
| MVP-06, repositorio y archivos | SQLite, archivo privado, validación de WAV, temporales/finales, progreso, duplicados, reintento, recuperación y reconciliación | Activar resolver de la API y validar sus formatos; otros formatos se rechazan explícitamente |
| MVP-06, eliminación y Deshacer | Eliminación pendiente persistente, Deshacer validado, finalización tras liberación del reproductor, reintento tras fallo y reinicio | Player debe inyectar confirmación de liberación; hasta entonces se conservan archivos pendientes |
| MVP-06, pantalla y cambios entre módulos | Android usa el repositorio; Chrome mantiene demo. Proveedores y stream común emiten cambios tras persistir | Inicio/búsqueda/player deben consumir estos contratos en sus PR; no se reescribieron sus módulos |
| MVP-10 | Pruebas trasladadas a test/features/downloads; nuevas pruebas de HTTP, archivos, persistencia, errores y widgets | PR #27 requiere aprobación de otro integrante; Carmen no puede aprobar su propio PR |
| MVP-11, participación en aceptación Android | Pruebas automatizadas de reinicio SQLite y navegación; revisión visual de demo Chrome | Sin dispositivo Android conectado ni API/motor integrados para el flujo completo de modo avión |
| MVP-12, documentación y evidencias de su módulo | Este documento y README de datos explican configuración, comportamiento seguro y límites | Video Android depende de MVP-11 |

El plazo de Deshacer se configura mediante proveedor (valor inicial: duración
del SnackBar existente). No se fijó una política de negocio definitiva. No se
borra una pista sin confirmación del coordinador de reproducción.

No se presenta la demo Chrome ni las pruebas de archivos como evidencia de
reproducción real en Android. La parte técnica independiente queda cubierta,
pero el flujo final requiere los proveedores y el dispositivo indicados.
