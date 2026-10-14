# SoundWave — Propuesta visual (UX)

## 1. Dirección visual
App musical moderna, minimalista y cuidada, con identidad propia:
fondo oscuro `#0B1220`, turquesa `#2DD4BF` como acento principal,
jerarquía clara título > contenido > acción, espacio generoso y
portadas como principal elemento visual. Sin gradientes excesivos,
sin tarjeta-dentro-de-tarjeta, sin sombras fuertes ni decoración
sin propósito. Ningún botón visible sin función.

## 2. Sistema visual
- **Paleta:** fondo `#0B1220`, superficie `#172235`, elevada `#223047`,
  acento `#2DD4BF` sobre `#0B1220`, principal `#F8FAFC`,
  secundario `#CBD5E1`, error `#FCA5A5`. Los estados (foco, resultados,
  descarga futura) combinan color + texto/icono, nunca solo color.
- **Tipografía (sistema, respeta escalado):** pantalla 28 negrita,
  sección 20 seminegrita, canción/principal 16, artista/secundario 14,
  auxiliar 12–13.
- **Espaciado:** 4/8/12/16/24/32; margen horizontal 24 (16 si <360px).
- **Formas:** buscador r16, botones r12, portadas r12 56×56,
  áreas táctiles ≥48×48. Iconos Material consistentes con tooltips.

## 3. Pautas por pantalla (integración futura, no implementadas aquí)
- **Inicio:** encabezado SoundWave + accesos a buscar y descargas +
  secciones con misma tipografía/espaciado.
- **Búsqueda (IMPLEMENTADO en `features/search/`):** buscador destacado
  y sticky, sugerencias/resultados legibles, estados inicial y vacío.
- **Descargas (propuesto):** misma fila que búsqueda; estado con
  texto + icono.
- **Reproductor (propuesto):** portada protagonista, jerarquía
  título/artista, controles accesibles, bloquear diferenciado.
- **Navegación (propuesta, no agregar aún):** inferior con
  Inicio/Buscar/Descargas; el reproductor abre desde una canción.
  Sin navegación ficticia ni minirreproductor sin audio real.

## 4. Búsqueda — lo implementado
Orden: encabezado compacto (“Buscar música” + “Encuentra tu próximo
favorito”), buscador sticky (“Busca una canción o artista”, icono
izquierda, limpiar con 48×48, borde turquesa al foco, cursor/selección
de la paleta), contenido con “Sugerencias para ti” (mocks existentes +
nota “Selección de muestra, no personalizada”) o “Resultados” con
conteo singular/plural, filas limpias sin tarjeta (cover local
determinista por id, `Expanded` + ellipsis, duración m:ss), vacío con
icono + “No encontramos canciones” + “Prueba con otro título o artista”.
Anchos 320–430 verificados por layout, ≤640 centrado en amplio.

## 5. Descarga simulada (SOLO DISEÑO, issue #4 no implementado)
Estados futuros: Descargar → Descargando… → Descargada (icono check).
La pantalla dirá que es simulación; sin depender solo del color;
sin doble tap en progreso.

## 6. Comportamiento y accesibilidad
Teléfono primero, `SafeArea`, teclado sin ocultar el buscador,
transiciones discretas solo si aclaran, sin cargas artificiales
(búsqueda local inmediata).
