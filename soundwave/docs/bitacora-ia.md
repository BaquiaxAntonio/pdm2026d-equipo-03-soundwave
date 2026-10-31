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

## Laboratorio S16: CRUD y migración del módulo de reproducción

- Responsable: Jeffersson Ramos. Se utilizó OpenCode para revisar la hoja de
  trabajo y el código, diseñar e implementar el CRUD de listas del reproductor,
  su migración SQLite, formulario, providers y pruebas.
- Se agregó el acceso **Listas de reproducción** junto al título del reproductor
  (icono de lista musical; también disponible cuando no hay canciones).
  **Nueva lista** permite crear una lista vacía o incluir una copia de las
  canciones de la cola actual. Tocar una lista abre el mismo formulario con su
  nombre; **Guardar cambios** ejecuta UPDATE y conserva su id y sus canciones.
- Una lista vacía se puede eliminar previa confirmación. Si tiene referencias
  en `playlist_songs`, el repositorio impide borrarla dentro de una transacción
  y la interfaz ofrece archivarla. Las archivadas se pueden editar y restaurar.
- La migración v2 agrega `player_managed` y `archived` a `playlists`, y un índice
  UNIQUE parcial por nombre (sin distinguir mayúsculas ASCII y quitando espacios
  de los extremos). Los errores de nombres repetidos se traducen a un mensaje
  humano. Guardar, borrar, archivar y restaurar invalidan el provider de listas.
- Se rechazó imponer nombres únicos a todas las listas: afectaría las
  colecciones de otros módulos y podría impedir migrar datos anteriores con
  nombres repetidos. El CRUD y el índice se limitan a `player_managed = 1`;
  las colecciones anteriores conservan el valor 0 y sus datos.
- Se conservaron las sentencias del esquema v1. Las instalaciones nuevas crean
  v1 y aplican v2; los teléfonos existentes reciben v2 mediante `onUpgrade`.
- Prueba de migración: se crea un archivo SQLite v1 con canción, descarga,
  listas con nombres repetidos, membresía y bloqueo. Se abre como v2 y se
  comprueban datos, columnas y claves foráneas. Después se crea, edita, archiva
  y borra usando el repositorio, se cierra y reabre el archivo y se comprueba
  que las operaciones persisten y el índice UNIQUE sigue funcionando.
- Las reglas del repositorio se prueban tanto en SQLite real como en memoria.
  Las pruebas de widget cubren creación, edición con formulario lleno e id
  estable, copia de la cola, duplicados, borrado y alternativa de archivado.
- Se corrigió la primera ubicación del acceso (AppBar), porque desplazaba los
  controles y hacía fallar pruebas existentes de Siguiente. Se descartó también
  agregarlo al final de la cola, porque alteraba el desplazamiento probado.
  Se integró como icono junto al título del reproductor.
- Se descartó usar SQLite FFI dentro de las pruebas de widget: sus operaciones
  quedaban pendientes con el reloj simulado. La interfaz se prueba con el
  repositorio en memoria y SQLite se verifica en las pruebas de repositorio
  y migración, sin esperas temporizadas artificiales.
- Android mantiene los datos en SQLite. Chrome y los otros destinos conservan
  el modo demostración en memoria que ya usa el proyecto.

### Validación manual

1. Abrir Reproducción y tocar el icono de lista musical junto al título para
   entrar a Listas de reproducción.
2. Crear una lista vacía; tocarla, cambiar el nombre y guardar cambios.
3. Intentar crear otra con el mismo nombre: debe aparecer un mensaje claro.
4. Crear otra incluyendo la cola actual e intentar eliminarla: debe ofrecer
   archivar. Archivarla y restaurarla desde su menú.
5. Eliminar la lista vacía; cerrar y abrir la app en Android y comprobar los
   registros conservados.

### Respuesta para la descripción del PR de migración

Si se edita una migración ya publicada, un teléfono que ya la ejecutó no vuelve
a ejecutarla: su número de versión no cambia. Conservaría el esquema anterior,
pero el código nuevo intentaría usar columnas o índices que no existen. Esto
puede causar errores al abrir o usar la app y dejar instalaciones nuevas y
existentes con esquemas distintos. Una versión nueva y `onUpgrade` aplican el
cambio a los datos existentes sin tener que borrar la base.

### Resultados de verificación local de la implementación inicial

- `flutter test --no-pub --reporter compact`: 152 pruebas aprobadas; una prueba
  externa de red omitida por la configuración existente del proyecto.
- Análisis estático de `lib/` y `test/`: sin observaciones. El servidor de
  análisis del SDK falló al recibir la ruta con tilde (`Ingeniería`); se
  verificó usando una unidad temporal `S:` mediante `subst` y el comando
  `flutter analyze --no-pub S:/lib S:/test`. La unidad se retiró después.
- `git diff --check`: sin errores de espacios.

- La rama con número de issue, los commits, la apertura del PR, su revisión y
  los checks de GitHub quedan pendientes del proceso de entrega del equipo.

## Correcciones del reproductor: cola reactiva y selección individual

- A petición de Jeffersson, se utilizó OpenCode para corregir la cola fija y
  reemplazar la selección de todas o ninguna al crear una lista.
- `PlayerScreen` pasa a la vista de cola la canción actual y el orden circular
  de canciones reproducibles. La canción actual aparece primero, resaltada
  con «En reproducción», seguida por las próximas. Las canciones anteriores
  quedan al final porque el reproductor repite la cola al llegar al final.
- Avanzar, retroceder, cambiar automáticamente de canción, bloquear y deshacer
  el bloqueo actualizan las filas. Los bloqueos se excluyen del orden visible.
  El filtro sigue afectando únicamente las filas mostradas.
- Se descartó reordenar o eliminar registros en SQLite al avanzar: el orden
  visual se deriva del estado vigente del reproductor, conservando las
  posiciones originales para Anterior y Deshacer.
- El formulario recibe las canciones disponibles y devuelve los ids elegidos
  mediante un callback. Cada fila muestra título, artista y una casilla.
  «Seleccionar todas» y «Limpiar selección» permiten acciones masivas; también
  se puede seleccionar una canción o quitar algunas de una selección completa.
  Los ids se guardan en el orden de la cola, independientemente del orden de
  los toques. La edición del nombre conserva las canciones ya guardadas.
- El formulario conserva la selección si el guardado falla. No conoce SQL ni
  providers y no necesita cambios de esquema o dependencias adicionales.
- Se agregaron pruebas de cola para Siguiente, Anterior, repetición, avance
  automático, filtro, bloqueo y Deshacer. Las pruebas del formulario verifican
  los ids enviados al guardar una canción, varias o ninguna.
- Durante la validación se corrigieron las pruebas de selección masiva para
  esperar a que termine el desplazamiento y las animaciones antes de tocar
  una fila o botón; no se silenciaron los avisos de toques fuera de alcance.

### Validación manual de las correcciones

1. Abrir Reproducción y comprobar la primera fila de la cola. Avanzar y
   retroceder: debe cambiar la canción resaltada y el orden de las filas.
2. Bloquear una canción: desaparece de la cola reproducible. Deshacer debe
   restaurar la canción actual y su lugar en el orden circular.
3. Abrir Listas de reproducción y crear una lista seleccionando solo una
   canción. El contador de la lista guardada debe mostrar una canción.
4. Crear otra lista seleccionando todas y desmarcando una; comprobar su conteo.
5. Probar Limpiar selección y crear una lista vacía.

### Verificación de las correcciones

- `flutter test --no-pub`: 158 pruebas aprobadas y una prueba externa de red
  omitida por su configuración existente.
- `flutter analyze --no-pub S:/lib S:/test`: sin observaciones, usando la misma
  unidad temporal descrita arriba para evitar el problema de rutas con tilde.
- `git diff --check`: sin errores de espacios.

## Corrección: agregar y quitar canciones después de crear una lista

- Jeffersson detectó que una lista creada sin canciones solo permitía cambiar
  su nombre. Se utilizó OpenCode para ampliar el formulario y el repositorio
  de listas existentes.
- Al tocar una lista se consultan sus canciones guardadas. El formulario
  combina esas canciones con las de la cola, sin duplicarlas, y precarga las
  casillas de las que ya pertenecen a la lista. Las canciones guardadas siguen
  visibles aunque hayan salido de la cola.
- Guardar cambios permite agregar o quitar canciones además de renombrar. El
  contador se actualiza invalidando el provider y el id de la lista se conserva.
- La edición SQLite guarda nombre y asociaciones dentro de una transacción.
  Se conservan las membresías de las canciones que permanecen para mantener sus
  bloqueos; solo se eliminan las desmarcadas y se insertan las nuevas. Las que
  permanecen conservan su orden relativo y las nuevas se agregan al final.
  Para compactar posiciones se liberan primero los números usados, evitando
  colisiones con UNIQUE sin reemplazar las filas.
- Se rechazó borrar todas las asociaciones y reinsertarlas: el borrado en
  cascada eliminaría también los bloqueos de canciones conservadas.
- El parámetro opcional `songIds` del repositorio distingue entre no modificar
  canciones (`null`) y vaciar una lista (`[]`), para que las llamadas existentes
  que solo renombran sigan conservando sus canciones. El repositorio demo ahora
  guarda también los ids y permite consultarlos al reabrir el formulario.
- Si no se pueden cargar las canciones se muestra un mensaje y no se abre un
  formulario incompleto que pudiera borrar la selección anterior. Cancelar
  descarta las modificaciones del formulario.
- Pruebas agregadas: crear vacía, agregar canciones, guardar y reabrir con
  selección; conservar canciones fuera de la cola; quitar canciones; cancelar;
  conservar id, orden y bloqueos; aislar otras listas; revertir toda la edición
  si falla una asociación; cerrar y reabrir un archivo SQLite con la edición
  conservada. La duración nula de una canción de catálogo se admite al cargarla.
- Esta corrección utiliza las tablas y dependencias existentes.

### Validación manual de la edición de canciones

1. Crear una lista sin marcar canciones y tocarla después en el listado.
2. Marcar una canción y pulsar Guardar cambios: el contador debe mostrar una.
3. Abrirla otra vez: la canción debe estar marcada. Agregar otra o quitar la
   anterior y guardar.
4. Si una canción sale de la cola, abrir la lista y comprobar que continúa
   apareciendo marcada; cambiar solo el nombre debe conservarla.
5. En Android, cerrar y abrir la aplicación y verificar las canciones guardadas.

### Verificación de la edición de canciones

- `flutter test --no-pub`: 168 pruebas aprobadas; una prueba de red omitida por
  su configuración existente.
- Análisis estático de `lib/` y `test/` usando la unidad temporal: sin observaciones.
- `git diff --check`: sin errores de espacios.
