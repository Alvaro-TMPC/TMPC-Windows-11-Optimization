# Configuración, pruebas, limitaciones y fuentes

Este documento describe el estado técnico real del baseline versionado en este
repositorio: qué decisiones aplica el perfil, qué se ha validado, qué sigue sin
validar, qué limitaciones existen y qué referencias de origen están presentes
en los archivos.

Plataforma objetivo: Windows 11 25H2, x64 / amd64.

No es una guía de instalación. La preparación previa al formateo se documenta
en `docs/preparacion-previa-instalacion.md`.

## 1. Configuración principal

Los archivos de referencia son `autounattend.xml` y `ventoy.json`. Este resumen
recoge las decisiones vigentes del perfil y no reproduce las listas completas
de claves del archivo de respuestas.

- Windows Update se conserva activo. El perfil ajusta preferencias conservadoras
  de reinicio y de experiencia de actualización, pero no desactiva el servicio
  de actualizaciones.
- Los drivers distribuidos mediante Windows Update se excluyen.
- Microsoft Defender se conserva. Solo se reducen las notificaciones no críticas
  de Windows Security.
- Microsoft Store se conserva por compatibilidad, reparación e instalación de
  dependencias.
- Edge y WebView2 se conservan por compatibilidad con Windows y aplicaciones.
- Microsoft Photos se conserva como visor de imágenes integrado.
- Paint se conserva. Las políticas configuradas desactivan Cocreator, Generative
  Fill e Image Creator.
- Notepad se conserva. La política configurada desactiva sus funciones de IA.
- OneDrive se elimina y se bloquea según el diseño actual. Esto no elimina el
  contenido que el usuario tenga en su carpeta de OneDrive; el script preserva
  esos datos.
- Game Mode se activa. Game DVR se desactiva.
- Plan de energía: Balanced estándar de Windows. No se fuerza CPU al 100 %,
  EPP 0, ajustes ocultos de procesador, overrides de USB ni clones de alto
  rendimiento.
- Hibernación y Fast Startup se desactivan.
- UAC mantiene el comportamiento normal para administradores y el aviso en el
  escritorio seguro.
- Print Spooler se conserva en inicio Automático.
- El bloqueo de Windows se conserva: Win+L, opción del menú de inicio y
  Ctrl+Alt+Del siguen disponibles.
- No se aplican optimizaciones agresivas de CPU, GPU, planificador ni red.
- OOBE y `BypassNRO` se mantienen.
- `ConfigureStartPins` se mantiene con lista vacía y `applyOnce`.
- `ProductKey` es ficticia, formada por ceros; no es una clave real.
- Los efectos de transparencia se desactivan.
- El estado de "No molestar" se configura a través del blob de CloudStore de
  Quiet Hours, dependiente de Windows 11 25H2.

La efectividad real de las políticas de IA de Paint y Notepad, así como el
comportamiento final de la transparencia y de "No molestar", siguen pendientes
de validación funcional en una instalación limpia del XML exacto actual.

## 2. Estado de validación

### Comprobado estáticamente

Sobre los archivos reales del repositorio:

- `autounattend.xml` está bien formado como XML.
- Todos los componentes del XML son `amd64`: 3 componentes
  (`Microsoft-Windows-Setup`, `Microsoft-Windows-Deployment` y
  `Microsoft-Windows-Shell-Setup`); `x86` = 0; `arm64` = 0.
- El PowerShell embebido se analizó sintácticamente con el parser de Windows
  PowerShell 5.1: `SystemCustomizations.ps1`, `BloatRemoval.ps1` y
  `OneDriveRemoval.ps1`, con 0 errores.
- `ventoy.json` es JSON válido.
- Los hallazgos F1, F2 y F3 de la auditoría interna están corregidos y
  comprobados estáticamente.
- Los scripts embebidos analizados no se han ejecutado sobre ningún sistema.

Hashes SHA-256 del baseline actual:

- `autounattend.xml`:
  `BF71877E1C3CBF2389891AD92ED507FC13BFE8AE81B7DBE6E141FEAE59DDA579`.
- `ventoy.json`:
  `2231E01E9B0BA0622888D97EFEDA0F476DBD73A9CB90B11B48656E1F889F2796`.

### Comprobado con evidencia previa

En Windows 11 25H2 se observó previamente, con ProcMon y Registro del sistema,
que el estado de "No molestar" se almacena en el blob de CloudStore de Quiet
Hours:

- `Microsoft.QuietHoursProfile.PriorityOnly` = No molestar activado.
- `Microsoft.QuietHoursProfile.Unrestricted` = No molestar desactivado.

Esa evidencia corresponde a observaciones anteriores y no se ha reproducido en
esta revisión. La implementación actual preserva el blob existente y sustituye
únicamente la cadena de perfil cuando corresponde.

### Pendiente / no comprobado

- Instalación limpia del `autounattend.xml` exacto actualmente versionado.
- Validación funcional completa posterior a esa instalación.
- Corrección y comprobación de los hallazgos F4 y posteriores de la auditoría.
- Efectividad real de las políticas de IA de Paint y Notepad.
- Comportamiento final de transparencia y de "No molestar" en una instalación
  limpia del XML exacto actual.
- Correcciones F1, F2 y F3 probadas en instalación real.
- Compatibilidad con versiones, ediciones o builds distintos de Windows 11
  25H2.
- Auditoría de fuentes, licencias y atribuciones.
- Cualquier otro elemento marcado como pendiente en la documentación del
  repositorio.

**Una validación estática no equivale a una instalación limpia real.** El
baseline actual no está probado en instalación limpia.

## 3. Limitaciones y dependencias

- Windows 11 25H2 es la referencia actual; no se garantiza compatibilidad con
  otras versiones, ediciones o builds.
- `BypassNRO` puede depender de la versión o build concreta de Windows.
- `ConfigureStartPins` usa una implementación que debe revalidarse ante cambios
  de Windows.
- La configuración de CloudStore/Quiet Hours depende de detalles de
  implementación de Windows 11 25H2.
- Las políticas de IA de Paint y Notepad necesitan validación funcional real.
- F4 y posteriores siguen pendientes.
- El XML exacto actual no tiene instalación limpia validada.
- Todavía no existe un baseline etiquetado como versión release probada.

## 4. Fuentes, licencias y atribuciones

Referencias de origen presentes en los archivos versionados:

- `autounattend.xml` incluye la referencia
  `Source: https://github.com/memstechtips/Autounattend` en las notas de dos
  scripts generados: `BloatRemoval.ps1` (versión 2.3) y `OneDriveRemoval.ps1`
  (versión 1.2). Ambas referencias ya forman parte del archivo público.

Estado:

- La revisión completa de fuentes, licencias y atribuciones sigue pendiente.
- No se ha comprobado la licencia de los componentes referenciados; no debe
  afirmarse ninguna licencia concreta sin verificarla.
- La licencia definitiva del repositorio todavía no está establecida.
- Las atribuciones existentes no deben eliminarse ni modificarse.
