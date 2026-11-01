## Qué cambia

<!-- Describe la entidad, el esquema o la regla que toca este PR. -->

## Cómo probarlo

1. 
2. 

## Checklist

- [ ] `dart format --output=none --set-exit-if-changed lib test` sin cambios
- [ ] `flutter analyze` sin avisos
- [ ] `flutter test` en verde
- [ ] Si hay cambio de esquema: versión nueva en `onUpgrade` y prueba que abre
      una base de la versión anterior con datos
- [ ] Bitácora de IA actualizada en `docs/bitacora-ia.md`
- [ ] El formulario no conoce SQL ni providers; editar conserva el id
