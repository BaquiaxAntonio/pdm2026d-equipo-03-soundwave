# Base de descargas MVP-06

Implementación inicial independiente de la API, todavía sin activar en la UI.
Consume `DownloadRepository`, `AudioFileStore`, `Song`, `DownloadRecord` y los
DAO compartidos de Henry; no abre otra conexión ni modifica el esquema.

- `LocalAudioFileStore` recibe un directorio privado de la aplicación. Crea
  temporales `.part`, confirma mediante rename y devuelve rutas relativas.
- `SqliteDownloadRepository` recibe la conexión compartida, el almacén y una
  función `OpenDownload`. Esta función debe obtener audio permitido y validar
  respuesta HTTP y tipo de contenido antes de entregar `DownloadInput`.
- Cada operación persiste antes de notificar. No se marca `completed` hasta
  terminar y confirmar un archivo no vacío con longitud esperada cuando existe.
- Se rechazan duplicados; los reintentos fallidos empiezan desde cero. Los
  errores conservan estado `failed` y no exponen una ruta disponible.
- Ejecutar `recoverInterrupted()` una vez antes de habilitar transferencias:
  detecta transferencias interrumpidas y archivos completados ausentes.
- `requestRemoval` recibe el plazo desde el consumidor, conserva el archivo y
  persiste `pendingDeletion`. `undoRemoval` recupera el registro durante el plazo.
- Un único proveedor deberá ser dueño del repositorio y llamar `dispose()`
  después de esperar sus operaciones. No cierra la conexión compartida.

## Pendiente de integración

1. Adaptador de la API elegida: permiso de descarga, HTTP, resolución de URL,
   validación de audio/formato, timeout y cierre de recursos de red.
2. Proveedor Android usando el directorio privado y conexión de Henry; demo Web
   separada. Estos archivos con `dart:io` no se importan desde widgets Web.
3. Conectar `DownloadScreen` al repositorio y filtrar eliminaciones pendientes.
4. Acordar plazo de Deshacer y coordinación de pistas activas antes de finalizar
   borrados vencidos, también al reiniciar. Aún no se finalizan automáticamente.
5. Reconciliar archivos parciales y huérfanos (incluido fallo de SQLite después
   de confirmar archivo); se conservan y no se ofrecen como canciones disponibles.
6. Coordinar pertenencia a la colección offline con Inicio/reproductor y validar
   audio y falta de espacio en Android. No se añadió otra fuente de catálogo.

Pruebas: `flutter test test/features/downloads/sqlite_download_repository_test.dart`.
Usan SQLite FFI y archivos temporales, sin llamadas a una API externa. La prueba
de recreación del repositorio comparte conexión; la reapertura completa de la
base también tiene cobertura en las pruebas de infraestructura de Henry.
