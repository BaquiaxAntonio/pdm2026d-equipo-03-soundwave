# Aceptación Android — Inicio, navegación y cierre del MVP (Douglas)

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
  `playerFromDownloadsProvider`, de modo que el controlador de reproducción se
  alimenta de las descargas reales sin overrides de pruebas.
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
| Selección desde Inicio dentro de la pestaña Reproductor | **Parcial**: la canción se elige por ID y, si aún no está en la cola visible del reproductor, se informa al usuario. La sustitución del motor simulado por audio real y la unificación de la cola es la tarea 2.3 (Ramos). |
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

Completar en el PR de entrega:

| Dato | Valor |
| --- | --- |
| Commit | |
| Fecha | |
| Dispositivo / emulador | |
| Versión de Android | |
| APK (build/flavor) | |
| Resultado del recorrido | |
| Errores observados | |
| Capturas o video | |

## 6. Limitaciones conocidas

- La cola visible del Reproductor aún se alimenta de datos de laboratorio; la
  entrega de audio real corresponde a la tarea 2.3. Inicio ya entrega el ID
  estable y el controlador compartido se mantiene activo en la composición.
- El modo demostración (Chrome/escritorio) no usa SQLite ni descargas reales y
  se identifica en pantalla.
