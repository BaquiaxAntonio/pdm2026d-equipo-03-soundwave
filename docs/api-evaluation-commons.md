# Evaluación de API musical: Wikimedia Commons

Fecha de evaluación: 18 de octubre de 2026.

## 1. Estado de la decisión

Wikimedia Commons queda registrado como **candidato provisional** para la
prueba técnica de búsqueda, descarga y reproducción offline de SoundWave.

La propuesta es comenzar con un catálogo pequeño y controlado de archivos cuya
licencia y compatibilidad se revisen individualmente. Commons no se considera
todavía una API musical aceptada para todo el MVP y una única muestra no
demuestra un catálogo de canciones completas.

No se ha validado todavía:

- La descarga completa de la muestra mediante el descargador de la aplicación.
- El archivo completo mediante `isValidAudioFile`.
- La persistencia después de cerrar y abrir la aplicación.
- La reproducción real en Android ni la reproducción en modo avión.

## 2. Motivos de la recomendación provisional

- La API de lectura es pública y no necesita un secreto distribuido en la app.
- MediaWiki ofrece búsqueda y metadatos de cada archivo, incluidos `pageid`,
  URL, MIME, tamaño, duración, autor y licencia cuando están disponibles.
- El `pageid` permite conservar una identidad de origen independiente de la URL
  de descarga.
- Commons admite contenido con licencias libres o en dominio público, pero la
  licencia debe revisarse por archivo.
- La muestra seleccionada respondió sin redirección y su cabecera es compatible
  con la validación WAV PCM implementada actualmente por Carmen.
- Las políticas permiten consultar y cachear datos si se respetan las licencias,
  la identificación del cliente y los límites comunicados por el servicio.

## 3. Fuentes oficiales consultadas

### 3.1 API y operación del servicio

- [MediaWiki API: Search](https://www.mediawiki.org/wiki/API:Search): búsqueda
  de páginas mediante la Action API.
- [MediaWiki API: Imageinfo](https://www.mediawiki.org/wiki/API:Imageinfo): URL,
  MIME, tamaño, duración y metadatos extendidos de archivos.
- [Wikimedia Foundation API Usage Guidelines](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_API_Usage_Guidelines):
  identificación del cliente, límites dinámicos, cumplimiento de licencias y
  prohibición de evadir restricciones.
- [Wikimedia Foundation User-Agent Policy](https://foundation.wikimedia.org/wiki/Policy:User-Agent_policy):
  formato y obligatoriedad de un `User-Agent` descriptivo.
- [MediaWiki API Etiquette](https://www.mediawiki.org/wiki/API:Etiquette):
  solicitudes en serie, caché, agrupación y espera progresiva ante límites.

Estas políticas regulan el acceso a la API. No conceden por sí mismas derechos
para copiar o conservar un archivo de audio.

### 3.2 Licencia y reutilización del contenido

- [Commons:Licensing](https://commons.wikimedia.org/wiki/Commons:Licensing):
  política de contenido libre o de dominio público de Commons.
- [Commons:Reusing content outside Wikimedia](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia):
  obligaciones y responsabilidad de quien reutiliza cada archivo.
- [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/):
  permiso para copiar y redistribuir la obra en cualquier medio o formato bajo
  las condiciones de atribución.
- [Página de la muestra en Commons](https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav):
  autor, declaración de trabajo propio y licencia concreta del audio probado.

El almacenamiento y la reproducción offline de la muestra se sustentan en su
licencia CC BY 4.0, no en los términos de la API. Se deben conservar el crédito,
el enlace a la licencia y la indicación de cambios. Commons advierte que quien
reutiliza el contenido debe comprobar la información y cumplir la licencia.

### 3.3 Proveedores comparados

- [Internet Archive Developer Portal](https://archive.org/developers/index.html)
- [Internet Archive Items](https://archive.org/developers/items.html)
- [Internet Archive Item Metadata API: Read](https://archive.org/developers/md-read.html)
- [Internet Archive automated access](https://archive.org/developers/bots.html)
- [Jamendo tracks API](https://developer.jamendo.com/v3.0/tracks)
- [Jamendo authentication](https://developer.jamendo.com/v3.0/authentication)
- [Jamendo API Terms of Use](https://devportal.jamendo.com/api_terms_of_use)

Internet Archive no se recomienda con el transporte actual porque sus URLs
archivísticas pueden redirigir y el WAV observado no cumplió la estructura
rígida del validador. Jamendo se descarta porque sus términos indican que las
aplicaciones no deben estar diseñadas específicamente para cachear contenido u
ofrecer acceso offline, aunque la API exponga pistas descargables.

## 4. Audio usado como muestra técnica

| Propiedad | Valor observado |
| --- | --- |
| Archivo | `Welcome to Noxville.wav` |
| Página de origen | https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav |
| Autor | Sir Goose of Honker |
| Origen declarado | Trabajo propio |
| Licencia | Creative Commons Attribution 4.0 International |
| Atribución requerida | Sí |
| `pageid` | `157450501` |
| Duración informada | 6.741333 segundos |
| Tamaño informado | 647,212 bytes |
| MIME | `audio/x-wav` |
| SHA-1 informado | `d7eec8429fe6ecb42aaaa6886353406f562a1e0b` |
| URL | https://upload.wikimedia.org/wikipedia/commons/7/76/Welcome_to_Noxville.wav |
| Formato de la cabecera | WAV PCM, mono, 48 kHz, 16 bits |

La duración es aproximadamente **6.7 segundos**. Sirve como muestra técnica de
transporte, almacenamiento y futura reproducción, pero no demuestra que Commons
ofrezca un catálogo adecuado de canciones completas.

Atribución propuesta si el archivo se utiliza sin modificaciones:

> “Welcome to Noxville” por Sir Goose of Honker, bajo CC BY 4.0, vía Wikimedia
> Commons. Sin modificaciones.

## 5. Compatibilidad observada con el validador de Carmen

Se solicitaron únicamente los primeros 64 bytes del archivo. La cabecera
observada contiene:

- Etiquetas `RIFF`, `WAVE`, `fmt ` y `data` en los offsets esperados.
- Bloque `fmt` de 16 bytes.
- Formato PCM `1`.
- Un canal, 48,000 Hz y 16 bits por muestra.
- `blockAlign` de 2 y `byteRate` de 96,000.
- Tamaño RIFF de `647204`; sumando 8 coincide con 647,212 bytes.
- Tamaño `data` de 647,168; coincide con `647212 - 44`.

Estos valores satisfacen las comprobaciones de
`soundwave/lib/features/downloads/data/audio_validation.dart`. La conclusión es
que la muestra es **estructuralmente compatible según la cabecera y longitud
publicada**. No se declara validado el archivo completo porque todavía no se ha
descargado ni pasado realmente a `isValidAudioFile`.

`Flight Hymn by Ross Bugden.wav` dejó de ser la muestra recomendada. Su cabecera
observada declaraba un bloque `data` que no cubría todos los bytes posteriores a
la cabecera. El validador actual exige que `dataSize == fileLength - 44`, por lo
que ese archivo probablemente sería rechazado aunque sea un WAV PCM.

## 6. Solicitudes ejecutadas y resultados observados

### 6.1 Wikimedia Commons

| Solicitud ejecutada | Resultado registrado |
| --- | --- |
| `action=query` por el título exacto con `prop=imageinfo` | JSON con `pageid`, URL, MIME, tamaño, duración, SHA-1 y metadatos de licencia de la muestra |
| `generator=search` para `Welcome to Noxville` dentro del espacio de nombres `File` | La muestra apareció como primer resultado; también aparecieron archivos no musicales |
| Solicitud inicial durante la evaluación | Se recibió HTTP 429 |
| Repetición identificada con un `User-Agent` descriptivo | Se recibió HTTP 200 |
| `HEAD` a la URL directa de la muestra, sin seguir redirecciones | HTTP 200, sin `Location`, `audio/x-wav`, longitud 647,212 |
| `GET` con `Range: bytes=0-63` | HTTP 206, `Content-Range: bytes 0-63/647212` y 64 bytes de cabecera |

La búsqueda amplia mostró que limitarse al espacio `File` no basta para obtener
música: ese espacio también contiene PDF, imágenes y otros tipos. La consulta y
el adaptador deberán filtrar MIME y volver a validar cada respuesta.

### 6.2 Internet Archive

| Solicitud ejecutada | Resultado registrado |
| --- | --- |
| Búsqueda y consulta de metadatos para `IlopoFerese` | Se encontró un archivo WAVE con metadatos CC BY-SA 4.0 |
| URL archivística del WAV | HTTP 302 hacia un servidor mirror |
| URL del mirror indicada por la redirección | HTTP 200, `audio/x-wav`, longitud 52,000,498 |
| Inspección de cabecera | Bloque `fmt` de 18 bytes y `data` fuera del offset fijo esperado |

El descargador actual no sigue redirecciones y el archivo inspeccionado sería
rechazado por el validador de Carmen. No se realizó reproducción.

### 6.3 Jamendo

Se consultaron la documentación de pistas, autenticación y términos oficiales.
No se ejecutó una solicitud a la API de pistas porque requiere un `client_id`.
La evaluación legal fue suficiente para descartarlo para un MVP centrado en
almacenamiento y reproducción offline.

## 7. Transformación prevista a `Song`

| Campo | Procedencia |
| --- | --- |
| `id` | Prefijo local y `pageid`: `wikimedia_commons:157450501` |
| `title` | Título de la página sin `File:` ni la extensión `.wav` |
| `artist` | `imageinfo.extmetadata.Artist.value`, normalizado de HTML a texto |
| `durationMs` | Duración de `imageinfo` convertida y redondeada a milisegundos |
| `provider` | Valor fijo `wikimedia_commons` |
| `sourceId` | `pageid` convertido a texto |
| `artworkUrl` | `null` si no existe una portada verificable |

Para la muestra, el resultado esperado es:

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

La URL no debe formar parte de la identidad. Antes de descargar, el adaptador
deberá consultar de nuevo por `sourceId` y revisar existencia, HTTPS, MIME,
licencia y restricciones antes de devolver `PermittedAudio`.

El modelo `Song` actual no conserva licencia, atribución ni página de origen.
Esta información será necesaria si el catálogo se amplía y debe persistir para
mostrar correctamente los créditos offline.

## 8. Limitaciones de catálogo, búsqueda y licencia

- Commons es un repositorio multimedia general, no un catálogo musical.
- Título, artista, álbum y género no tienen una estructura uniforme.
- `Artist.value` puede contener HTML, varios autores o estar ausente.
- Un nombre de archivo no siempre representa correctamente el título musical.
- La licencia y la atribución deben comprobarse y conservarse por archivo.
- Las declaraciones de licencia proceden de las páginas mantenidas por los
  usuarios; Commons no reemplaza la verificación del reutilizador.
- Las URLs deben resolverse nuevamente porque no se usarán como identidad.
- No existe una cuota fija garantizada para todas las lecturas. Se deben respetar
  HTTP 429, `Retry-After`, solicitudes en serie, caché y espera progresiva.
- El validador actual acepta solo un WAV PCM con cabecera canónica de 44 bytes.
  Rechaza WAV válidos con metadatos o bloques RIFF adicionales.
- Los WAV de canciones completas pueden consumir mucho almacenamiento y datos.
- Un catálogo controlado deberá contener varias pistas y permitir búsquedas por
  título y artista. Una única muestra corta no cumple la aceptación del MVP.

## 9. Estados de búsqueda y fallback local

Los estados pertenecen a `features/search/`, bajo responsabilidad de
`JavEstrada09`. No se deben mezclar causas distintas bajo el mensaje “Sin
conexión”.

| Causa | Comportamiento y comunicación esperada |
| --- | --- |
| Red caída | Consultar el catálogo local y mostrar que no hay conexión |
| Timeout | Consultar el catálogo local e informar que el servicio tardó demasiado |
| Límite o cuota, incluido HTTP 429 | Respetar la espera indicada; si se usa caché, informar “Límite temporal de solicitudes: mostrando catálogo guardado” |
| Autenticación o configuración | Mostrar un error específico; no presentarlo como problema de red |
| Respuesta online válida | Guardar resultados y mostrarlos como catálogo actualizado |
| Caché vacía | Mostrar un estado vacío y una acción de reintento adecuada a la causa |

Douglas conserva la responsabilidad de integración raíz y navegación. El aviso
de catálogo limitado, el origen local de los resultados y los estados de
búsqueda no deben trasladarse a `main.dart` ni a otra feature.

## 10. Trabajo pendiente antes de aceptar Commons

1. Acordar con Henry cómo representar y persistir licencia, atribución y origen.
2. Acordar cómo comunicar el origen de resultados sin ocultarlo detrás de
   `CatalogRepository.search`, que actualmente solo devuelve `List<Song>`.
3. Acordar con Carmen el `User-Agent` del `HttpAudioDownloader` y ejecutar la
   descarga completa con el transporte existente.
4. Validar el archivo completo con `isValidAudioFile`.
5. Confirmar almacenamiento y persistencia después de reiniciar la aplicación.
6. Conectar un dispositivo o emulador Android y comprobar reproducción real.
7. Probar reproducción después de cerrar la aplicación y activar modo avión.
8. Seleccionar más pistas compatibles, licenciadas y buscables por título y
   artista antes de reemplazar los mocks o declarar aceptado el catálogo.
