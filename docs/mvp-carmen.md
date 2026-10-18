# Actividades de Carmen — evidencia de integración

Fuente: `docs/plan-mvp.md`, leído completo. Esta matriz registra avance y
dependencias; no modifica el alcance ni sustituye la aceptación Android.

| Actividad del plan | Implementación / evidencia | Dependencia real |
| --- | --- | --- |
| MVP-01, revisión de Descargas | PR #26 revisado, actualizado sin conflictos y fusionado; prueba de navegación preservada | Ninguna |
| MVP-02, revisar API con Henry | Transporte y resolver desacoplados; sin endpoints inventados | Falta selección y evidencia de permisos de la API por su responsable |
| MVP-03/04, revisar contratos y aportar requisitos de archivos | PR #25 aprobado y fusionado; implementación consume Song, DownloadRecord, contratos y DAO existentes | Coordinar formatos de audio definitivos y callback de liberación con sus responsables |
| MVP-06, repositorio y archivos | SQLite, archivo privado, validación de WAV, temporales/finales, progreso, duplicados, reintento, recuperación y reconciliación | Activar resolver de la API y validar sus formatos; otros formatos se rechazan explícitamente |
| MVP-06, eliminación y Deshacer | Eliminación pendiente persistente, Deshacer validado, finalización tras liberación del reproductor, reintento tras fallo y reinicio | Player debe inyectar confirmación de liberación; hasta entonces se conservan archivos pendientes |
| MVP-06, pantalla y cambios entre módulos | Android usa el repositorio; Chrome mantiene demo. Proveedores y stream común emiten cambios tras persistir | Inicio/búsqueda/player deben consumir estos contratos en sus PR; no se reescribieron sus módulos |
| MVP-10 | Pruebas trasladadas a test/features/downloads; nuevas pruebas de HTTP, archivos, persistencia, errores y widgets | PR #27 requiere aprobación de otro integrante; Carmen no puede aprobar su propio PR |
| MVP-11, participación en aceptación Android | Pruebas automatizadas de reinicio SQLite y navegación; revisión visual de demo Chrome | Sin dispositivo Android conectado ni API/motor integrados para el flujo completo de modo avión |
| MVP-12, documentación y evidencias de su módulo | Este documento y README de datos explican configuración, comportamiento seguro y límites | Video Android depende de MVP-11 |

El plazo de Deshacer se configura mediante proveedor (valor inicial: duración
del SnackBar existente). No se fijó una política de negocio definitiva. No se
borra una pista sin confirmación del coordinador de reproducción.

No se presenta la demo Chrome ni las pruebas de archivos como evidencia de
reproducción real en Android. La parte técnica independiente queda cubierta,
pero el flujo final requiere los proveedores y el dispositivo indicados.
