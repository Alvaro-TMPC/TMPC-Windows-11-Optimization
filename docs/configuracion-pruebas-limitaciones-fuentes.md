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
- El estado de "No molestar" se configura mediante la interfaz COM interna
  `IQuietHoursSettings` como vía principal; Windows / WpnUserService materializa
  el estado persistente. La escritura directa del blob de CloudStore de Quiet
  Hours se conserva únicamente como fallback para formatos materializados
  reconocibles. Dependiente de Windows 11 25H2.

La segunda instalación limpia confirmó el comportamiento de "No molestar" y
los efectos de transparencia. Las políticas de IA de Notepad quedaron limpias
en runtime. La limpieza completa de la interfaz de IA de Paint sigue sin
cerrarse: las políticas de Registro se aplican, pero la aplicación todavía
muestra opciones o avisos relacionados con IA.

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
- El validador estático local `scripts/validate-baseline.ps1` reproduce estas
  comprobaciones en modo de solo lectura y sin ejecutar los scripts embebidos;
  no sustituye una instalación limpia real.

Hashes SHA-256 del baseline actual:

- `autounattend.xml`:
  `C0EA1741BB09EA88F83F2D4C841081C9441AEE9F81DC4D2681ED6C9C9A5F03D1`.
- `ventoy.json`:
  `2231E01E9B0BA0622888D97EFEDA0F476DBD73A9CB90B11B48656E1F889F2796`.

### Comprobado con evidencia previa

En Windows 11 25H2 se observó previamente, con ProcMon y Registro del sistema,
que el estado de "No molestar" se almacena en el blob de CloudStore de Quiet
Hours:

- `Microsoft.QuietHoursProfile.PriorityOnly` = No molestar activado.
- `Microsoft.QuietHoursProfile.Unrestricted` = No molestar desactivado.

Esa evidencia corresponde a observaciones anteriores y no se ha reproducido en
esta revisión. El fallback del script preserva el blob existente y sustituye
únicamente la cadena de perfil cuando corresponde.

### Comprobado experimentalmente (Windows 11 Pro 25H2, prueba aislada)

Una instalación real del baseline anterior reveló que el estado de "No
molestar" no quedaba desactivado. La corrección se apoya en una prueba
experimental aislada realizada en Windows 11 Pro 25H2:

- CLSID `{F53321FA-34F8-4B7F-B9A3-361877CB94CF}` e IID
  `{6BFF4732-81EC-4FFB-AE67-B6C1BC29631F}` activados con
  `CoCreateInstance(CLSCTX_LOCAL_SERVER)`.
- Slots de vtable validados: 3 (`get_UserSelectedProfile`), 4
  (`put_UserSelectedProfile`) y 9 (`get_OffProfileId`).
- En un usuario nuevo, con el estado compacto, la llamada
  `put_UserSelectedProfile(get_OffProfileId())` materializó el estado
  (`isInitialized = true`, `selectedProfile =
  Microsoft.QuietHoursProfile.Unrestricted`) y el interruptor de "No molestar"
  quedó desactivado y seguía siendo modificable.

La causa exacta por la que la primera instalación limpia terminó con "No
molestar" activado no está identificada con precisión: PENDIENTE / NO
COMPROBADA. En particular, el blob compacto de 13 bytes observado entonces no
equivale a `PriorityOnly` y no debe documentarse como DND activado: en un
usuario genuinamente no inicializado la lectura devuelve estado vacío y el
perfil COM es `Microsoft.QuietHoursProfile.Unrestricted`.

`IQuietHoursSettings` es una interfaz interna no documentada: no es una API
pública con soporte contractual de Microsoft y puede cambiar en futuras
builds.

### Comprobado en instalación limpia real (Windows 11 Pro 25H2)

El `autounattend.xml` corregido se grabó en el medio con el SHA-256 de origen
verificado, el SSD se limpió y se convirtió a GPT, y Setup creó sus particiones
automáticamente. Resultado:

- instalación, OOBE y llegada al escritorio correctos;
- sin prompt obligatorio de red ni de cuenta Microsoft;
- sin errores de Setup bloqueantes.

En la primera instalación se observaron mensajes transitorios BFSVC/BCD no
bloqueantes en `setuperr.log`; la instalación terminó y arrancó correctamente,
con el disco en GPT/EFI saludable. Se clasifica como incidencia de Setup
observada y no bloqueante.

Antes de tocar la interfaz de "No molestar", la evidencia fue:

- CloudStore con `Data` `REG_BINARY` materializado de 116 bytes;
- lectura del estado de Quiet Hours: `isInitialized = true`,
  `selectedProfile = Microsoft.QuietHoursProfile.Unrestricted`;
- getter COM: `HRESULT 0x00000000`,
  `Microsoft.QuietHoursProfile.Unrestricted`.

Comprobación visual posterior: "No molestar" desactivado, interruptor
modificable y reactivación manual correcta. El cleanup final se completó: sin
`C:\ProgramData\Autounattend`, sin tarea programada, sin marcador y sin logs
del perfil. La ausencia del marcador final es coherente con el cleanup completo
y no debe interpretarse como un fallo.

### Pendiente / no comprobado

- Causa exacta del "No molestar" activado en la primera instalación limpia:
  PENDIENTE / NO COMPROBADA; el blob compacto de 13 bytes no equivale a
  `PriorityOnly` y no debe documentarse como DND activado.
- Recorrido de recuperación de F2 en runtime: solo se observó la ruta normal.
- F1 en runtime (no observado) y F3 en runtime (parcial).
- Corrección y comprobación de los hallazgos F4 y posteriores de la auditoría.
- Efectividad completa de las funciones de IA de Paint: las políticas se
  aplican, pero la limpieza visual no se logró y el efecto concreto de cada
  función sigue sin confirmarse.
- Compatibilidad con versiones, ediciones o builds distintos de Windows 11
  25H2.
- Auditoría de fuentes, licencias y atribuciones.
- Cualquier otro elemento marcado como pendiente en la documentación del
  repositorio.

**Una validación estática no sustituye una instalación limpia real.** El XML
actual ha completado una instalación limpia en Windows 11 Pro 25H2; eso no lo
convierte en una versión release ni garantiza compatibilidad con otras builds.

## 3. Limitaciones y dependencias

- Windows 11 25H2 es la referencia actual. La compatibilidad con otras
  versiones, ediciones o builds no está comprobada ni garantizada.
- `BypassNRO` puede depender de la versión o build concreta de Windows.
- `ConfigureStartPins` usa una implementación que debe revalidarse ante cambios
  de Windows.
- La configuración de CloudStore/Quiet Hours depende de detalles de
  implementación de Windows 11 25H2. La vía principal usa la interfaz interna
  no documentada `IQuietHoursSettings`, que puede cambiar en futuras builds y
  debe revalidarse.
- Las funciones de IA de Notepad quedaron sin presencia visible en la prueba
  real; las funciones de IA de Paint siguen sin confirmarse y su limpieza
  visual no se logró.
- F4 y posteriores siguen pendientes.
- El recorrido de recuperación de F2 no se observó en runtime.
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
