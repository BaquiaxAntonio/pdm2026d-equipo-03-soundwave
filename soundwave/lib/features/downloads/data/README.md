# Descargas MVP-06

La implementación usa los contratos y DAO compartidos de Henry. Android abre
SQLite y archivos en `getApplicationSupportDirectory()/downloads`; Chrome sigue
con la demo explícita. No se modificó el esquema ni se añadió otro catálogo.

## Integración

- `downloadSessionProvider` es el punto único de acceso al repositorio y a las
  canciones canónicas. Inicio, búsqueda y player pueden consumir
  `downloadEntriesProvider` o `repository.watchDownloads()` sin recargar la app.
- `openDownloadProvider` usa en nativo el `CommonsAudioResolver` existente de
  Búsqueda y `HttpAudioDownloader`, conservando los créditos vigentes en SQLite.
  Usa la canción verificada `audio.song` del contrato integrado por #51;
  un resultado de búsqueda por sí solo no autoriza su descarga. El resolver
  comprueba identidad, metadatos actuales, licencia y URL Commons. Web conserva
  la demo.
- El transporte valida permiso, HTTPS, HTTP 200, MIME, timeout y longitud.
  Las redirecciones se resuelven por el adaptador para revalidar el destino.
  Incluye User-Agent y compara el tamaño del proveedor. Antes de confirmar el
  archivo se verifica su SHA-1 cuando el proveedor lo suministra.
- Se conservan los formatos WAV y Ogg integrados por #51 y su validación de
  contenedor. La ruta local se valida de nuevo antes de entregarse al reproductor.
- La composición de `main.dart` conecta `canDeleteAudioProvider` con la guarda de
  Ramos: solo permite borrar después de `releaseForDeletion`. La prueba integral
  comprueba que un archivo pausado se conserva mientras `stop()` no termina.
  Sin coordinador, el valor seguro sigue siendo false y el archivo se retiene.
- `downloadUndoDurationProvider` es configurable; 4 segundos coincide con el
  SnackBar existente. Es un valor reversible de interfaz, no política definitiva.

## Consistencia

Los datos se escriben antes de notificar. Se guarda primero un temporal `.part`,
se valida y confirma el archivo, y finalmente SQLite registra `completed` y la
pertenencia a la colección offline. Los fallos no tienen ruta disponible.
Se rechazan duplicados y el reintento empieza desde cero.
El rechazo de duplicados conserva los metadatos existentes. Los temporales
se limpian al terminar o fallar; si el almacenamiento impide borrarlos, la
reconciliación del siguiente inicio vuelve a intentarlo.

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
