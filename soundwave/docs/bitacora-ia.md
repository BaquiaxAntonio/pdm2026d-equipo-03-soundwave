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
