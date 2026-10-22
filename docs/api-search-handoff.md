# Continuidad de API y búsqueda

Fecha del handoff: 18 de octubre de 2026.

## 1. Estado de Git verificado

- Rama: `mvp/api-search`.
- Commit: `a303e004dc4eba0380a672174e721e2ff507c1bf`.
- Antes de crear estos documentos, `git status --short --branch` mostró la rama
  y ningún cambio adicional en el árbol de trabajo.
- No se realizó commit ni push.

## 2. Alcance y restricciones vigentes

- Wikimedia Commons es candidato provisional, no proveedor aceptado todavía.
- No se debe crear un segundo descargador ni seguir redirecciones sin validar.
- No se deben convertir formatos automáticamente.
- No se deben reemplazar los mocks antes de completar la prueba técnica.
- No se deben declarar validados la descarga completa, la persistencia offline
  ni la reproducción Android.
- No se modificaron modelos, contratos, dependencias, otras features ni
  `main.dart` durante esta evaluación.
- Chrome continúa como demostración de interfaz; Android es la plataforma de
  aceptación del flujo real.

## 3. Contratos existentes

### `Song`

Ruta: `soundwave/lib/core/models/song.dart`.

Campos actuales:

- `id`: identidad estable dentro de la aplicación.
- `title` y `artist`.
- `durationMs`, opcional.
- `provider` y `sourceId` para conservar la identidad del proveedor.
- `artworkUrl`, opcional.

No existen campos para licencia, atribución o página de origen.

### `CatalogRepository`

Ruta: `soundwave/lib/core/contracts/catalog_repository.dart`.

```dart
abstract interface class CatalogRepository {
  Future<List<Song>> search(String query);
  Future<Song?> findById(String songId);
  Future<void> saveAll(Iterable<Song> songs);
}
```

El retorno `List<Song>` no comunica si los resultados son online, locales o una
respuesta de contingencia tras timeout o cuota.

### Descarga

Rutas:

- `soundwave/lib/features/downloads/data/download_input.dart`
- `soundwave/lib/features/downloads/data/http_audio_downloader.dart`
- `soundwave/lib/features/downloads/download_providers.dart`

Firmas relevantes:

```dart
typedef OpenDownload = Future<DownloadInput> Function(Song song);

final Future<PermittedAudio> Function(Song) resolve;

PermittedAudio(Uri uri, {required bool downloadAllowed});
```

`HttpAudioDownloader` exige permiso explícito, HTTPS, HTTP 200 y un MIME WAV
admitido. Desactiva redirecciones. Aún no establece un `User-Agent` descriptivo.

`openDownloadProvider` continúa usando `platform.unavailable` hasta que la
integración raíz suministre una implementación aprobada.

### Persistencia local

Ruta: `soundwave/lib/core/database/song_dao.dart`.

`SongDao` permite guardar, buscar por ID, buscar por proveedor y `sourceId`, y
buscar localmente por título o artista. Este último comportamiento permite que
un catálogo controlado siga siendo buscable offline.

## 4. Rutas relevantes revisadas

- `docs/plan-mvp.md`: criterios de selección y aceptación del MVP.
- `docs/mvp-carmen.md`: estado de descargas y dependencias de integración.
- `docs/api-evaluation-commons.md`: evidencia completa de esta evaluación.
- `soundwave/lib/core/models/song.dart`: modelo canónico.
- `soundwave/lib/core/contracts/catalog_repository.dart`: contrato de catálogo.
- `soundwave/lib/core/database/song_dao.dart`: caché y búsqueda local.
- `soundwave/lib/features/downloads/data/audio_validation.dart`: validación WAV
  PCM de cabecera canónica.
- `soundwave/lib/features/downloads/data/http_audio_downloader.dart`: transporte
  de audio permitido.
- `soundwave/lib/features/downloads/data/download_input.dart`: contrato de flujo
  descargable.
- `soundwave/lib/features/downloads/download_providers.dart`: proveedor todavía
  no conectado a una fuente de audio.
- `soundwave/lib/features/search/`: feature responsable de búsqueda, estados y
  comunicación del catálogo local.

## 5. Hallazgos que deben conservarse

- Wikimedia Commons permite búsquedas públicas y metadatos sin secreto.
- El permiso de conservar audio offline procede de la licencia de cada archivo,
  no de los términos de la API.
- Wikimedia exige un `User-Agent` descriptivo y el respeto de límites dinámicos.
- Durante la evaluación se observó HTTP 429; una solicitud identificada después
  respondió HTTP 200.
- La muestra `Welcome to Noxville.wav`, `pageid 157450501`, está publicada como
  trabajo propio bajo CC BY 4.0.
- La muestra dura aproximadamente 6.7 segundos. Es útil para una prueba técnica,
  pero no demuestra un catálogo de canciones completas.
- Su URL directa respondió a `HEAD` con HTTP 200, sin redirección, MIME
  `audio/x-wav` y longitud 647,212.
- La lectura parcial de 64 bytes respondió HTTP 206 y mostró una cabecera WAV
  PCM canónica compatible con las comprobaciones actuales.
- El archivo completo no fue descargado ni validado.
- Internet Archive usa redirecciones en la URL estable probada y el WAV revisado
  tenía una estructura incompatible con el validador actual.
- Jamendo requiere `client_id` y sus términos descartan una aplicación diseñada
  específicamente para caché o acceso offline.
- Commons mezcla muchos tipos de archivo y sus metadatos musicales no son
  uniformes. Se requiere un catálogo controlado de varias pistas verificadas.

## 6. Mapeo de la muestra

```dart
Song(
  id: 'wikimedia_commons:157450501',
  title: 'Welcome to Noxville',
  artist: 'Sir Goose of Honker',
  durationMs: 6741,
  provider: 'wikimedia_commons',
  sourceId: '157450501',
  artworkUrl: null,
)
```

El adaptador debe usar `pageid` como `sourceId`, no la URL. La URL, el MIME, la
licencia y las restricciones deben resolverse otra vez antes de cada intento de
descarga.

## 7. Decisiones pendientes con Henry

1. Definir dónde se guardarán licencia, URL de licencia, atribución y página de
   origen para que los créditos sobrevivan offline.
2. Decidir si `CatalogRepository` debe devolver un resultado con origen y aviso,
   o si `features/search/` expondrá ese estado mediante otro contrato.
3. Confirmar el uso de `dart:io HttpClient` para consultar JSON en Android sin
   instalar una dependencia nueva.
4. Confirmar la separación de plataforma: implementación nativa en Android y
   demostración en Chrome, sin importar `dart:io` desde código Web.
5. Confirmar el punto de composición del repositorio y su acceso a `SongDao`.

`HttpClient` se propone únicamente para las consultas JSON del catálogo. Los
bytes de audio deben continuar pasando por `HttpAudioDownloader`.

## 8. Decisiones pendientes con Carmen

1. Definir cómo establecer un `User-Agent` descriptivo en
   `HttpAudioDownloader` sin crear otro transporte.
2. Ejecutar la descarga completa de `Welcome to Noxville.wav` con el descargador
   existente.
3. Pasar el archivo completo por `isValidAudioFile` y comprobar su persistencia.
4. Revisar si el validador WAV canónico se conserva como límite temporal o si se
   amplía después para recorrer bloques RIFF estándar.
5. Mantener la validación de permiso, HTTPS, estado, MIME, longitud y cierre del
   flujo ante errores.

## 9. Límites de responsabilidad

- `JavEstrada09` conserva la responsabilidad de `features/search/`, incluidos
  búsqueda online, fallback local, mensajes de causa y aviso de catálogo
  limitado.
- Douglas conserva la integración raíz, navegación y el futuro override de
  `openDownloadProvider` en el punto de composición aprobado.
- Douglas no debe absorber en `main.dart` los estados internos de búsqueda.
- Carmen conserva el descargador, archivos privados y validación del audio.
- Henry conserva modelos, contratos, SQLite, proveedores compartidos y
  dependencias.

## 10. Estados de búsqueda que no deben confundirse

| Estado | Fallback y mensaje |
| --- | --- |
| Red caída | Usar caché si existe e informar falta de conexión |
| Timeout | Usar caché si existe e informar que el servicio tardó demasiado |
| Cuota o HTTP 429 | Respetar la espera; si se usa caché, informar el límite temporal de solicitudes |
| Autenticación o configuración | Mostrar un error específico, no “Sin conexión” |
| Respuesta válida | Guardar y mostrar catálogo actualizado |
| Sin caché | Mostrar vacío recuperable y reintento adecuado a la causa |

La API pública de Commons no requiere autenticación para estas lecturas. El
estado de autenticación se mantiene separado para no convertir futuros errores
de configuración o de otro proveedor en falsos problemas de red.

## 11. Entorno pendiente

No hay un dispositivo Android conectado ni un emulador creado para completar la
aceptación. También se habían observado licencias pendientes del Android SDK.
Sin un destino Android y un motor de audio integrado no se puede demostrar
reproducción real, reinicio ni modo avión.

## 12. Próximo paso recomendado

1. Revisar con Henry y Carmen las decisiones anteriores sin modificar todavía
   contratos ni dependencias.
2. Conectar un dispositivo o crear un emulador Android utilizable.
3. Resolver la URL actual de la muestra por `pageid` y entregarla al
   `HttpAudioDownloader` existente con permiso explícito.
4. Descargar el archivo completo, validar su longitud y ejecutar
   `isValidAudioFile`.
5. Verificar almacenamiento y reapertura antes de incorporar más pistas.
6. Revisar compatibilidad del formato real y seleccionar varias muestras
   buscables por título y artista.
7. Solo después de esa prueba, decidir si Commons supera la prueba técnica antes
   de reemplazar los mocks.
