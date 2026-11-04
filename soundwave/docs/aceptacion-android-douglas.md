# Aceptación Android — Inicio, navegación y cierre del MVP

Documento de la sección **2.4** del plan de cierre del MVP. Reúne la
configuración Android, el recorrido de aceptación y la evidencia reproducible
que debe adjuntarse al PR de entrega.

## 1. Qué se entregó

- **Inicio con datos compartidos:** `homeSongsProvider` deja de usar un fixture
  propio. En Android lee la **biblioteca** (descargas completadas) desde el
  mismo repositorio que usan Descargas, Buscar y el Reproductor; en el objetivo
  de demostración usa el **catálogo de demostración compartido** de Buscar.
  Conserva los estados de carga, vacío y error con reintento.
- **Acciones reales:** tocar una tarjeta (incluida «Continuar escuchando»),
  tocar un artista, «Ver todo», el botón «Buscar» de la barra superior y el
  CTA del estado vacío navegan a la canción o al módulo correcto. La selección
  viaja por **ID estable** (`selectedSongIdProvider`), nunca por título.
- **Rediseño y navegación conservados:** se mantiene el Inicio de #40 y la
  navegación compartida de #36 (`activeTabProvider` + `IndexedStack`). No se
  restauraron pantallas placeholder ni se duplicaron rutas.
- **Composición real:** `MainShell` mantiene activo
  `playbackIntegrationProvider`, que conecta el controlador de reproducción con
  las descargas reales sin overrides de pruebas.
- **Android:** permiso de Internet en el manifiesto principal (antes solo
  existía en debug/profile, por lo que una APK release no podía consultar
  Commons), nombre visible **SoundWave**, identificador
  `com.equipo03.soundwave` y firma de entrega opcional mediante
  `android/key.properties` (ignorado por Git).

## 2. Qué es real y qué no

| Elemento | Estado |
| --- | --- |
| Catálogo de Buscar (Wikimedia Commons) | Real (red) |
| Biblioteca de Inicio y Descargas | Real (SQLite + archivos descargados) |
| Selección por ID y navegación entre pestañas | Real |
| Selección desde Inicio dentro de la pestaña Reproductor | Real: `openById` resuelve la descarga local o el catálogo, añade la pista a la cola y reproduce el audio. Verificado en Android. |
| Modo demostración (web/escritorio) | Mock identificado con la etiqueta «Modo demostración» |

## 3. Configuración Android de entrega

| Ajuste | Valor |
| --- | --- |
| Permiso de red | `android.permission.INTERNET` en `src/main/AndroidManifest.xml` |
| Nombre visible | `SoundWave` |
| Identificador | `com.equipo03.soundwave` |
| Firma release | `android/key.properties` (no versionado). Sin ese archivo la APK release se firma con la clave de depuración para poder probarla. |

Para firmar la entrega, crear `android/key.properties` con
`storePassword`, `keyPassword`, `keyAlias` y `storeFile` (ruta al `.jks`), y
compilar con `flutter build apk --release`. No se versionan claves ni
contraseñas.

## 4. Recorrido de aceptación en Android

Ejecutar sobre el commit final de `main`, en un emulador o dispositivo real.

1. Instalar la APK: `flutter install` o `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
2. Abrir la aplicación con red: Inicio debe mostrar la biblioteca (o el estado
   vacío con el botón «Buscar música»).
3. Buscar una canción en **Buscar** y solicitar su descarga.
4. Esperar la descarga completa y comprobar el archivo en **Descargas**.
5. Volver a **Inicio**: la canción descargada aparece en «Recientes» /
   «Continuar escuchando».
6. Tocar la tarjeta: debe abrirse la pestaña **Reproductor** con el ID de esa
   canción seleccionado.
7. Reproducir, pausar, avanzar y navegar la cola.
8. Cerrar por completo la aplicación (quitar de recientes) y reabrir: la
   canción sigue en Inicio y en Descargas.
9. Activar **modo avión** y reproducir la canción descargada.
10. Eliminar la descarga y usar **Deshacer**: Inicio y Descargas deben reflejar
    el estado final.
11. Repetir 2–3 para comprobar los estados de carga, vacío y error (sin red).

## 5. Evidencia reproducible

### 5.1. Ejecución anterior (Douglas)

Datos de la ejecución de aceptación:

| Dato | Valor |
| --- | --- |
| Commit | `257ca458e1b2614a46c01337254d9a7166e41d7b` |
| Fecha | 2026-11-03 22:45 |
| Dispositivo / emulador | HONOR ABR-NX3 (físico) |
| Versión de Android | Android 16 (API 36), arm64-v8a |
| APK (build/flavor) | `app-release.apk` (release, 52.4 MB), instalada con `adb install -r` |
| Resultado del recorrido | Completo (11/11 pasos). Audio local real, persistencia tras cierre forzado, modo avión y Deshacer verificados. |
| Errores observados | (1) La etiqueta «Reproductor» de la barra inferior se parte en dos líneas. (2) «Deshacer» dura 4 s; si se agota, la descarga se borra definitivamente. (3) Sin red, Buscar muestra caché o vacío, no un error explícito. (4) La APK release se firmó con la clave de depuración al no existir `android/key.properties`. |
| Capturas o video | 11 capturas en `docs/evidencia/` (ver detalle abajo) |

#### Capturas del recorrido

1. `evidencia/01-inicio-vacio.png` — Inicio vacío tras instalación limpia.
2. `evidencia/02-inicio-biblioteca-real.png` — Inicio con «Blue Danube» tras la descarga.
3. `evidencia/03-reproductor-local.png` — reproductor con audio local, `0:15 / 7:18`.
4. `evidencia/04-cola-seek.png` — seek a `0:43` y cola de reproducción.
5. `evidencia/05-persistencia-reinicio.png` — Inicio tras cierre forzado y reapertura.
6. `evidencia/06-modo-avion.png` — reproducción con modo avión activo.
7. `evidencia/07-descarga-eliminada.png` — Descargas vacía con «Deshacer».
8. `evidencia/08-descarga-restaurada.png` — Descargas con 1 canción restaurada.
9. `evidencia/09-inicio-tras-deshacer.png` — Inicio coherente tras Deshacer.
10. `evidencia/10-buscar-offline-cache.png` — Buscar sin red con caché.
11. `evidencia/11-buscar-offline-vacio.png` — Buscar sin red sin resultados.

### 5.2. Validación manual reportada por @JavEstrada09

Esta entrada documenta el reporte manual del usuario. OpenCode no repitió el
recorrido ni verificó de forma independiente el audio, la red, la persistencia
o los créditos mostrados por la aplicación.

| Dato | Valor |
| --- | --- |
| Usuario | `@JavEstrada09` |
| Fecha | 2026-11-04 |
| Referencia Git comprobada al documentar | Rama `mvp/api-search`, commit `626a0b75b395783ef2a354c140a84ae449524252`, árbol de trabajo limpio antes de editar |
| Dispositivo / emulador reportado | Emulador Medium Phone (`emulator-5554`) |
| Versión de Android reportada | Android 16 (API 36) |
| Alcance | Una muestra, «Welcome to Noxville», en un emulador. No valida todo el catálogo ni un teléfono físico. |

Resultados reportados por el usuario:

1. La búsqueda de «Welcome to Noxville» encontró la canción de Sir Goose of
   Honker.
2. Tras solicitar la descarga, la canción apareció con el estado «Descargada».
3. Se confirmó reproducción audible y desplazamiento dentro del audio.
4. Se activó el modo avión y se apagó el Wi-Fi.
5. Después de forzar la detención y reabrir la misma instalación, la canción
   permaneció disponible y volvió a reproducirse.
6. La búsqueda sin conexión de «Noxville» encontró la canción e informó que en
   ese estado solo consulta canciones previamente consultadas.
7. Sin conexión se mostraron los créditos `CC BY 4.0`, Sir Goose of Honker,
   `Own work`, la URL de licencia y la página de Commons. Las URL concretas se
   transcriben abajo únicamente desde la captura donde resultan visibles.

#### Incidencia abierta reportada

`flutter run` compiló e instaló el APK, pero falló al conectarse al servicio de
depuración. La aplicación permaneció funcionando y el usuario continuó el
recorrido manualmente. Esta incidencia queda documentada como no resuelta; esta
entrada no aporta diagnóstico de causa ni confirma una corrección.

#### Capturas aportadas

Estas capturas respaldan solo los elementos visibles descritos. No demuestran
por sí solas que el audio fuera audible ni toda la secuencia de detención
forzada y reapertura, que permanecen como resultados reportados por el usuario.

1. [`Inicio_SinConexion.jpg`](evidencia/javier/Inicio_SinConexion.jpg) muestra
   Inicio con «Welcome to Noxville» de Sir Goose of Honker en «Continuar
   escuchando», en una tarjeta y en el mini reproductor. En la barra de estado
   se ve el icono de modo avión.
2. [`Descarga_SinConexion.jpg`](evidencia/javier/Descarga_SinConexion.jpg)
   muestra «Tu colección sin conexión», «1 canción disponible» y la fila de
   «Welcome to Noxville» con el estado «Descargada», además del mini reproductor.
3. [`Busqueda_SInConexion.jpg`](evidencia/javier/Busqueda_SInConexion.jpg)
   muestra la consulta «Noxville», el aviso «Sin conexión. Mostrando solo
   canciones consultadas anteriormente.» y un resultado: «Welcome to Noxville»,
   Sir Goose of Honker, duración `0:06` y estado «Descargada».
4. [`Creditos.jpg`](evidencia/javier/Creditos.jpg) muestra el reproductor con
   «Welcome to Noxville», Sir Goose of Honker, «Archivo local · Sin conexión»,
   posición y duración `0:06`, y el bloque «Créditos · CC BY 4.0» desplegado. En
   ese bloque son visibles `Own work`,
   `https://creativecommons.org/licenses/by/4.0` y
   `https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav`.

## 6. Limitaciones conocidas

- La APK de la ejecución anterior (Douglas) se firmó con la clave de depuración
  porque no existe `android/key.properties`. Para una entrega firmada hay que
  crear el keystore y ese archivo (no versionado) y recompilar con
  `flutter build apk --release`.
- «Deshacer» solo está disponible durante 4 segundos
  (`downloadUndoDurationProvider`). Si se agota, la descarga y el archivo se
  eliminan definitivamente. En la demostración hay que pulsarlo de inmediato.
- En la barra de navegación inferior, la etiqueta «Reproductor» se parte en dos
  líneas y se solapa ligeramente con los iconos en este dispositivo
  (HONOR ABR-NX3, 1080×2412, densidad 480).
- Sin conexión, Buscar recurre a los resultados consultados anteriormente; si no
  hay caché muestra «No encontramos canciones». No se presenta un estado de
  error de red explícito con reintento.
- El modo demostración (Chrome/escritorio) no usa SQLite ni descargas reales y
  se identifica en pantalla.
