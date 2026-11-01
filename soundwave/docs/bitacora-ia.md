# Bitácora de uso de IA

## Laboratorio 4: navegación

- Se usó IA para revisar la estructura existente y actualizar `MainShell` para
  que Riverpod controle la pestaña activa y `IndexedStack` conserve las vistas.
- Se agregó el acceso **Ver todo** en la sección Recientes; selecciona Buscar
  mediante el provider para abrir el listado disponible.
- Se añadieron pruebas para navegar desde Inicio y conservar el scroll de Inicio
  al cambiar de pestaña y regresar.
- En la Etapa A, las pruebas detectaron desbordamiento al colocar "Ver todo"
  junto a títulos largos. Se corrigieron los títulos con espacio flexible y se
  confirmó el caso de texto grande con la suite completa.

## Cierre del MVP: Inicio, navegación y aceptación Android (2.4)

- Se usó IA para revisar el Inicio de #40 y detectar que su provider mantenía
  un fixture propio (`mock_songs.dart`) separado del catálogo y la biblioteca
  compartidos. Se sustituyó por la biblioteca de descargas en Android y por el
  catálogo de demostración de Buscar en el objetivo de demostración.
- Se agregó `selectedSongIdProvider` para que Inicio, Buscar y el Reproductor
  compartan la canción por ID estable en lugar de por título.
- Se conectaron las acciones que no hacían nada (tarjetas, artistas, estado
  vacío) y se conservó la navegación por `activeTabProvider` de #36.
- Se conectó `playerFromDownloadsProvider` en `MainShell` para no depender de
  overrides de pruebas.
- Se corrigió el manifiesto Android (permiso de Internet en el manifiesto
  principal, nombre e identificador) y se añadió firma release opcional vía
  `key.properties` ignorado por Git.
- Se rechazó reescribir la pantalla del Reproductor: la unificación del motor
  real y de la cola pertenece a la tarea 2.3. Inicio deja el ID seleccionado y
  avisa si la canción todavía no está en la cola visible.

## Laboratorio 4: filtros reactivos

- Se implementó un filtro inmutable para mostrar todas las descargas o solo
  las completadas. `downloadEntriesProvider` observa el filtro con `ref.watch`
  y vuelve a escuchar el repositorio cuando cambia.
- Se conservaron los estados de carga, error/reintento, vacío y datos del flujo
  existente. Los registros pendientes de eliminación siguen disponibles para
  la futura interfaz de Deshacer.
- Se agregó una prueba enfocada del estado inmutable y de la actualización
  reactiva del proveedor al seleccionar "Completadas".
- Se rechazó acoplar el filtro a `SearchScreen`, porque la lista de descargas
  ya usa el repositorio y el estado asíncrono que requiere el laboratorio.
- No se rechazaron otras sugerencias de IA.

## Laboratorio 16: migración de listas a v3

- Se subió `databaseVersion` a 3 con la columna `archived` en `playlists` y un
  índice único de nombre sin distinguir mayúsculas, aplicado únicamente en
  `onUpgrade`.
- Al integrar `main` apareció el conflicto real: la versión 2 ya estaba usada
  por las columnas de licencia de `songs` y la tabla `users`. En vez de
  fusionar ambas cosas en el mismo paso 2 (los teléfonos que ya migraron no lo
  volverían a ejecutar), la migración de listas pasó a ser el paso 3.
- La migración v1 y la v2 quedaron intactas y, si el teléfono ya tenía nombres
  repetidos, se renombran con sufijos en lugar de borrar listas: crear el
  índice único habría fallado y la app no habría vuelto a abrir.
- El paso 3 comprueba con `PRAGMA table_info` si `archived` ya existe y crea el
  índice con `IF NOT EXISTS`, porque una compilación previa de esta rama pudo
  haber guardado el cambio como versión 2.
- La IA propuso editar `createPlaylistsTable` y reemplazar la v1; se rechazó
  porque los teléfonos que ya migraron no vuelven a ejecutar ese paso. El
  esquema v1 quedó congelado dentro de la prueba, no en producción.
- Las pruebas abren una base v1 con canciones, listas y membresías y una base
  v2 con usuarios y licencias, las actualizan a v3 y comprueban que los datos
  siguen, que `archived` existe y que el índice rechaza nombres repetidos.

## Laboratorio 16: CRUD de listas

- La entidad fue `playlists`: listar, crear, editar, archivar y borrar. El
  formulario `PlaylistForm` es uno solo para crear y editar; recibe el registro
  inicial (o nada) y una función `onSave`, y no conoce SQL ni providers.
  Renombrar hace UPDATE de la misma fila por id, así que el id no cambia.
- Las reglas viven en `SqlitePlaylistRepository`: el nombre repetido se traduce
  de `DatabaseException` a un mensaje humano y borrar una lista con canciones
  se bloquea con el conteo y la opción de archivarla.
- La pantalla invalida `playlistEntriesProvider` después de crear, editar,
  archivar o borrar; nunca inserta el valor guardado a mano en la lista.
- Se rechazó que el formulario consultara la base para validar duplicados: la
  validación queda en el repositorio y el formulario solo muestra el mensaje.
  También se rechazó borrar en cascada las canciones de una lista, porque la
  regla pide proteger lo que está en uso.
- Las pruebas cubren repositorio (nombre único, borrado en uso, id estable) y
  widget (formulario lleno, guardar cambios, mensaje de nombre repetido y
  archivado tras intentar borrar una lista en uso).
