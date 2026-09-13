\# SoundWave



Aplicación móvil de música desarrollada para el curso de Programación de Dispositivos Móviles.



\## 🎯 Problema



Los usuarios pueden experimentar interrupciones por anuncios al escuchar música, poca capacidad para filtrar o bloquear canciones no deseadas en listas automáticas y un consumo elevado de datos móviles.



SoundWave busca ofrecer una experiencia de reproducción de música más controlada y orientada al uso sin conexión.



\## 👤 Usuario principal



Estudiantes universitarios que escuchan música mientras estudian, se trasladan o realizan diferentes actividades y que buscan escuchar música de forma gratuita, sin interrupciones y sin depender permanentemente de una conexión a Internet.



\## 🚀 Flujo principal del MVP



El flujo inicial definido para el MVP es:



1\. Ingresar a la pantalla principal.

2\. Buscar o descargar una canción o lista.

3\. Omitir o bloquear canciones no deseadas.

4\. Continuar la reproducción de música sin conexión y sin anuncios.



\## 👥 Equipo y roles



| Rol           | Responsable             |

| ------------- | ----------------------- |

| Product / PM  | Douglas Jacobo          |

| Arquitectura  | Henry Baquiax           |

| UX / Research | Rolando de Leon         |

| QA / Release  | Jeffersson Daniel Ramos |

| DevOps        | Carmen Crisóstomo       |



\## 🌿 Regla de contribución

Nadie trabaja directamente sobre `main`.

El flujo obligatorio de trabajo es:



```text

Issue → Branch → Commit → Push → Pull Request → Review → Merge

```

Cada funcionalidad o tarea debe estar asociada a un Issue y desarrollarse en su propia rama.



\## 🏗️ Arquitectura inicial



SoundWave utiliza una arquitectura \*\*Feature-first incremental\*\*.



La aplicación se organiza inicialmente por funcionalidades, manteniendo además módulos comunes para configuración de la aplicación y recursos compartidos.



```text

lib/

├── app/

│   └── routes/

├── core/

│   ├── constants/

│   ├── errors/

│   ├── theme/

│   └── utils/

└── features/

&#x20;   ├── home/

&#x20;   ├── player/

&#x20;   ├── search/

&#x20;   └── downloads/

```



\### Principios de la estructura



\* `app/`: configuración general de la aplicación y navegación.

\* `core/`: elementos compartidos entre diferentes funcionalidades.

\* `features/`: funcionalidades principales de SoundWave.

\* Las capas adicionales como `data`, `domain` o `presentation` se incorporarán dentro de una funcionalidad cuando su complejidad lo justifique.



Esta estructura busca mantener el proyecto organizado y permitir que la arquitectura crezca progresivamente sin introducir complejidad innecesaria desde el inicio.



\## 📝 Convención de nombres



| Elemento            | Convención        | Ejemplo             |

| ------------------- | ----------------- | ------------------- |

| Carpetas            | `snake\_case`      | `downloads/`        |

| Archivos Dart       | `snake\_case.dart` | `audio\_player.dart` |

| Clases              | `PascalCase`      | `AudioPlayer`       |

| Variables           | `camelCase`       | `currentSong`       |

| Métodos / funciones | `camelCase`       | `playSong()`        |

| Constantes          | `lowerCamelCase`  | `defaultDuration`   |

| Enumeraciones       | `PascalCase`      | `DownloadStatus`    |

| Valores de enum     | `camelCase`       | `completed`         |



Las carpetas de funcionalidades utilizan nombres que representan el módulo, por ejemplo:



```text

home/

player/

search/

downloads/

```



No se utilizan nombres de carpetas basados en clases o pantallas, como `HomeScreen/` o `PlayerScreen/`.



\## 📚 Recursos de Flutter



Para consultar documentación y recursos oficiales de Flutter:



\* \[Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)

\* \[Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)

\* \[Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)



Para ayuda adicional:



\* \[Flutter documentation](https://docs.flutter.dev/)