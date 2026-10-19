# Bitácora de uso de IA

Cada uso de IA que termine en el repositorio se registra aquí, con el más
reciente primero. El objetivo es demostrar criterio: qué se pidió, qué se
revisó y qué se corrigió antes de integrar el cambio.

| Campo | Qué registrar |
| --- | --- |
| Fecha / autor | Fecha y usuario de GitHub responsable del cambio |
| Herramienta | Asistente utilizado |
| Especificación | Solicitud y restricciones relevantes |
| Resultado | Resumen de la propuesta recibida |
| Aceptado | Qué se incorporó y por qué |
| Rechazado / corregido | Qué se cambió o descartó y por qué |
| Verificación | Comandos, pruebas o dispositivo utilizado |
| Commit / PR | Enlace cuando exista |

---

## 2026-10-18 · @BaquiaxAntonio — configuración de CI de SoundWave

- **Herramienta:** Codex (asistente de código de OpenAI).
- **Especificación:** revisar la guía del laboratorio S14 y la referencia
  `s14-06-ci` de `saulecch/inkash_d`; preparar los archivos de CI para
  SoundWave, sin alterar funcionalidades de la aplicación ni cambios locales
  ajenos.
- **Resultado:** se propusieron un workflow de GitHub Actions, plantilla de
  Pull Request, `CODEOWNERS` y esta bitácora.
- **Aceptado:** workflow con formato, análisis, pruebas SQLite y APK de
  depuración; plantilla adaptada a Flutter/SoundWave y propietario
  `@BaquiaxAntonio` tomado del repositorio remoto.
- **Rechazado / corregido:** se descartaron los campos específicos de Inkash
  (centavos, `occurredOn` y rutas de sus repositorios), pues no corresponden a
  SoundWave. Los cambios generados de plataformas y `AGENTS.md` no se incluyen
  en este trabajo.
- **Verificación:** pendiente de ejecutar `dart format`, `flutter analyze` y
  `flutter test` localmente, y de comprobar el workflow en el Pull Request.
- **Commit / PR:** pendiente.
