# ADR-0001: Manejo de estado global con Riverpod

| Campo       | Valor                                                      |
| ----------- | ---------------------------------------------------------- |
| Estado      | Aceptado                                                   |
| Fecha       | 2026-10-08                                                 |
| Decisor     | Arquitectura (Henry Baquiax) junto al equipo SoundWave     |
| Issue       | #3                                                         |

## Contexto

SoundWave maneja estado que debe sobrevivir a la navegación entre funcionalidades:

- **Reproducción** (player): canción actual, posición, cola, shuffle/repeat.
- **Descargas**: estado por canción (pendiente, en curso, completado, fallido).
- **Preferencias**: listas, canciones bloqueadas, modo sin conexión.

El equipo desarrolla en paralelo por funcionalidades (Fase 1 del plan paralelo), así
que la solución debe:

1. Permitir que cada feature consuma estado global sin acoplarse a las demás.
2. Ser testeable sin montar la UI (contenedor de prueba independiente del widget).
3. Detectar errores en compilación, no en runtime.
4. Exigir el mínimo de boilerplate para no frenar la Fase 1.

Se evaluaron: `setState`, Provider, Riverpod y Bloc.

## Decisión

Usar **Riverpod** (`flutter_riverpod` 3.4.3) como única solución de estado global:

1. `ProviderScope` envuelve la aplicación en `lib/main.dart`; es el único punto de
   inyección y ningún widget lo duplica.
2. Cada feature define sus providers dentro de su carpeta
   (`lib/features/<feature>/`).
3. Los providers compartidos entre features viven en `lib/core/` y se consolidan en
   Fase 2.
4. Estado global mutable fuera de Riverpod: prohibido (singletons, variables
   globales, `ChangeNotifier` sueltos).
5. Cualquier cambio de esta decisión requiere un nuevo ADR que la reemplace.

## Alternativas consideradas

### Provider

- El enlace entre estado y `BuildContext` obliga a leer valores antes de la
  configuración y falla en runtime si se olvida un `Provider` en el árbol.
- No define una forma estándar de exponer estado asíncrono (futuros/stream).
- Se descarta: menos seguro que Riverpod y con una curva de migración posterior.

### Bloc

- Muy explícito y predecible, ideal cuando hay flujos de eventos complejos.
- Exige boilerplate (estados, eventos, handlers) que ralentiza una Fase 1 todavía
  incremental; su ventaja se nota más en lógica de dominio ya establecida.
- Se descarta por ahora: no impide adoptarlo más adelante dentro de una feature
  puntual si el flujo lo justifica.

### GetX

- Fuerte acoplamiento de la UI con el estado, testing más difícil y fuera del
  ecosistema recomendado por Flutter.
- Se descarta.

## Consecuencias

### Positivas

- Providers tipados: los errores de «provider no encontrado» se detectan al
  compilar.
- Los servicios de estado (player, descargas) se prueban con un contenedor aislado,
  sin renderizar widgets.
- Cada equipo del plan paralelo trabaja en su feature sin tocar el estado ajeno.
- La raíz queda lista para que cualquier feature consuma providers desde el primer
  PR.

### Negativas / riesgos

- El equipo completo debe adoptar Riverpod; un PR que introduzca otro patrón
  debería rechazarse en review (referenciando este ADR).
- Curva de aprendizaje para quien conozca solo `setState` o Provider.
- La versión 3.x es reciente: hay que seguir su guía de migración al actualizar.

## Referencias

- [Riverpod](https://riverpod.dev/)
- [Estado en Flutter (docs oficiales)](https://docs.flutter.dev/data-and-backend/state-mgmt)
- [Provider vs Riverpod](https://riverpod.dev/docs/getting_started/why_provider)
