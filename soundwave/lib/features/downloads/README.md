# Descargas simuladas — Issues #5 y #6

Pantalla independiente con el fondo #0B1220 y acento turquesa #2DD4BF del
documento UX. No necesita assets, red, audio ni dependencias adicionales.

## Vista temporal

Desde la carpeta del proyecto Flutter (`pdm2026d-equipo-03-soundwave/soundwave`),
agregar manualmente en `lib/main.dart`:

```dart
import 'package:soundwave/features/downloads/download_screen.dart';
```

Cambiar temporalmente solo la propiedad de `MaterialApp`:

```dart
// Antes:
home: const MyHomePage(title: 'Flutter Demo Home Page'),
// Durante la prueba:
home: const DownloadScreen(),
```

Conservar el `ProviderScope` raíz existente. Ejecutar:

```sh
flutter run -d chrome --no-web-resources-cdn
```

Para Android, iniciar un emulador desde Android Studio y ejecutar
`flutter devices`, seguido de `flutter run -d ID_DEL_EMULADOR`.
Restaurar la línea original y retirar el import después de obtener evidencia.
Estos cambios en main.dart no se han realizado automáticamente.

## Pantalla blanca en Chrome: diagnóstico y solución

Con Flutter 3.44.8 / Dart 3.12.2 se reprodujeron errores
`net::ERR_SOCKET_NOT_CONNECTED` al solicitar `canvaskit.js` y
`canvaskit.wasm` a `https://www.gstatic.com/flutter-canvaskit/…`, seguidos de
`TypeError: Failed to fetch` en flutter_bootstrap.js. El motor no alcanzaba
a crear una vista Flutter; el módulo no solicita imágenes ni fuentes de red.

La opción `--no-web-resources-cdn`, admitida por este SDK, sirve CanvasKit
desde localhost. Se verificó una captura real de Chrome con «Mis descargas»,
la colección de seis canciones y el diseño oscuro/turquesa. No requiere
cambiar web/index.html, pubspec.yaml, main.dart ni el SDK. No utiliza el
renderer HTML retirado. Detener la ejecución anterior antes de ejecutar:

```sh
flutter run -d chrome --no-web-resources-cdn
```

Esta opción localiza CanvasKit; no convierte automáticamente todas las fuentes
de respaldo de Flutter en recursos locales. En la ejecución verificada no se
observaron errores de fuentes. Si otra red bloquea Roboto, se debe evaluar
incluir la fuente como asset local (requiere acordar un cambio en pubspec.yaml)
o configurar fontFallbackBaseUrl en un bootstrap propio. No se aplicaron esos
cambios compartidos porque no fueron necesarios.

Validación del diagnóstico: ocho pruebas del módulo aprobadas y dart analyze
sin incidencias. flutter analyze --no-pub volvió a fallar por un FormatException
interno del servidor LSP. La captura final de Chrome a 430 × 1200 muestra las
seis canciones; CanvasKit se descargó desde localhost y se creó la vista Flutter.

## Estado y evidencia

`downloadStoreProvider` conserva una lista inmutable sin `autoDispose` dentro
del ProviderScope raíz. Desmontar y volver a montar DownloadScreen conserva
las eliminaciones. Reiniciar la aplicación o destruir el ProviderScope carga
los ejemplos nuevamente. No crear un ProviderScope nuevo por pantalla.

- Captura #5: lista inicial, resumen y portadas; eliminar todos los registros
  para capturar el vacío. «Restaurar ejemplos» recupera la lista.
- #6: la persistencia y el desmontaje/remontaje están cubiertos por pruebas.
  Cuando exista navegación compartida, grabar un GIF: eliminar una canción,
  salir a otra pantalla y volver; comprobar que sigue ausente. No realizar
  hot restart durante la grabación. La navegación y el GIF siguen pendientes.
- «Deshacer» recupera la última canción eliminada en su posición original.
  Los tamaños y duraciones son ficticios.

## Archivos

- `download_screen.dart`: encabezado, resumen, lista, eliminación y vacío.
- `download_status.dart`: registro local inmutable de descarga completada.
- `mock_download_data.dart`: seis canciones ficticias.
- `download_store.dart`: estado Riverpod, eliminar, restaurar y reiniciar demo.
- `download_theme.dart`: tema oscuro local compatible con la propuesta UX.
- `download_cover.dart`: portadas geométricas dibujadas con widgets.
- `../../../test/features/downloads/download_screen_test.dart`: estado inmutable, deshacer, persistencia al
  desmontar/remontar y layout a 320/360/430 px con texto al 100 % y 200 %.

Las ocho pruebas están en `test/features/downloads/`, conforme a MVP-10 del
plan MVP. La suite habitual y el CI raíz las descubren con `flutter test`,
sin ejecutar comandos adicionales ni modificar el workflow. Desde `soundwave/`:

```sh
flutter test
# Para ejecutar únicamente las pruebas de descargas:
flutter test test/features/downloads/download_screen_test.dart
```

Validación de formato: `dart format --output=none --set-exit-if-changed lib test`.
Análisis: `flutter analyze`.
En este entorno flutter analyze terminó por un FormatException del servidor
LSP; se utilizó también dart analyze como alternativa.
