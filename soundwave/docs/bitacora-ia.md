# Bitácora de uso de IA

## Laboratorio 4: navegación

- Se usó IA para revisar la estructura existente y actualizar `MainShell` para
  que Riverpod controle la pestaña activa y `IndexedStack` conserve las vistas.
- Se agregó el acceso **Ver todo** en la sección Recientes; selecciona Buscar
  mediante el provider para abrir el listado disponible.
- Se añadieron pruebas para navegar desde Inicio y conservar el scroll de Inicio
  al cambiar de pestaña y regresar.
- En la Etapa A, las pruebas detectaron desbordamiento al colocar "Ver todo"
  junto a títulos largos. Se corrigieron los títulos con espacio flexible y se
  confirmó el caso de texto grande con la suite completa.

## Laboratorio 4: filtros reactivos

- Se implementó un filtro inmutable para mostrar todas las descargas o solo
  las completadas. `downloadEntriesProvider` observa el filtro con `ref.watch`
  y vuelve a escuchar el repositorio cuando cambia.
- Se conservaron los estados de carga, error/reintento, vacío y datos del flujo
  existente. Los registros pendientes de eliminación siguen disponibles para
  la futura interfaz de Deshacer.
- Se agregó una prueba enfocada del estado inmutable y de la actualización
  reactiva del proveedor al seleccionar "Completadas".
- Se rechazó acoplar el filtro a `SearchScreen`, porque la lista de descargas
  ya usa el repositorio y el estado asíncrono que requiere el laboratorio.
- No se rechazaron otras sugerencias de IA.
