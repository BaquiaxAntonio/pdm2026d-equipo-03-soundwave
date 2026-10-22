# Descargas MVP-06

La implementación usa los contratos y DAO compartidos de Henry. Android abre
SQLite y archivos en `getApplicationSupportDirectory()/downloads`; Chrome sigue
con la demo explícita. No se modificó el esquema ni se añadió otro catálogo.

## Integración

- `downloadSessionProvider` es el punto único de acceso al repositorio y a las
  canciones canónicas. Inicio, búsqueda y player pueden consumir
  `downloadEntriesProvider` o `repository.watchDownloads()` sin recargar la app.
- El propietario de API debe sobrescribir `openDownloadProvider` con
  `HttpAudioDownloader(resolvePermittedAudio).open` o un adaptador compatible.
  El resolver recibe `Song` y devuelve `PermittedAudio` con URL vigente y permiso
  explícito. No hay endpoints, tokens ni proveedor ficticio en producción.
- El transporte valida permiso, HTTPS, HTTP 200, MIME, timeout y longitud.
  Las redirecciones se resuelven por el adaptador para revalidar el destino.
- Hasta acordar formatos con la API, se acepta únicamente WAV PCM canónico,
  validando cabecera, tamaños, canales, frecuencia y alineación. Otros formatos
  fallan como no disponibles; no se presentan bytes arbitrarios como audio.
- El propietario del motor debe sobrescribir `canDeleteAudioProvider`: devuelve
  true solo después de soltar la pista. Sin coordinador, el valor seguro es false
  y el registro/archivo se conserva pendiente, incluso tras vencer Deshacer.
- `downloadUndoDurationProvider` es configurable; 4 segundos coincide con el
  SnackBar existente. Es un valor reversible de interfaz, no política definitiva.

## Consistencia

Los datos se escriben antes de notificar. Se guarda primero un temporal `.part`,
se valida y confirma el archivo, y finalmente SQLite registra `completed` y la
pertenencia a la colección offline. Los fallos no tienen ruta disponible.
Se rechazan duplicados y el reintento empieza desde cero.

Al iniciar se recuperan transferencias interrumpidas como fallidas, se detectan
archivos ausentes/corruptos y se reconcilian temporales y archivos huérfanos
únicamente dentro del directorio privado de descargas. No se siguen enlaces.

Eliminar persiste `pendingDeletion`, oculta la canción y conserva el archivo.
Deshacer dentro del plazo valida el archivo antes de restaurarlo. Al vencer,
solo con permiso del coordinador se retira el archivo y después, en transacción,
el registro y su pertenencia offline. Un fallo de archivo conserva el registro
para reintentar; al reiniciar se procesan también las eliminaciones vencidas.

## Validación y límites

La suite `flutter test` descubre pruebas de repositorio, HTTP local controlado,
SQLite con cierre y reapertura reales, fallos de espacio/borrado, reconciliación,
archivos inválidos, progreso, duplicados y widgets/navegación. Los widgets usan
un doble de contrato; las pruebas de persistencia usan SQLite y archivos reales.

La aplicación Web compilada con CanvasKit local se revisó visualmente en Chrome,
430 × 1200: Descargas, seis mocks y navegación inferior visibles sin desbordes.
Esto valida la demo, no sustituye la aceptación Android ni prueba audio offline.
No había un dispositivo Android conectado al ejecutar las validaciones.