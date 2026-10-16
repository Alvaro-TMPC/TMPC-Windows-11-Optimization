# Configuración, pruebas, limitaciones y fuentes

Este documento describe el estado técnico real del baseline versionado en este
repositorio: qué decisiones aplica el perfil, qué se ha validado, qué sigue sin
validar, qué limitaciones existen y qué referencias de origen están presentes
en los archivos.

Plataforma objetivo: Windows 11 Pro 26H2, x64 / amd64 (build base 26300). El
baseline publicado v0.1.5 se validó en la referencia histórica Windows 11 Pro
25H2; a continuación se distinguen la evidencia histórica y la referencia
actual.

No es una guía de instalación. La preparación previa al formateo se documenta
en `docs/preparacion-previa-instalacion.md`.

Alcance de la evidencia runtime siguiente: **instalación limpia con autounattend.xml**.
El archivo adicional [`Apply-TMPCOptimizations.ps1`](../Apply-TMPCOptimizations.ps1)
deriva de ese XML el perfil post-install relevante, con modos completo y UserOnly.
Solo tiene validación estática, sin resultado runtime/hardware. Sus códigos de
error, logs persistentes, comprobación de identidad, reinicio opcional y
limitaciones (origen local para NetFx3, estado existente de Start/Downloads y
OneNote de escritorio/limpieza insegura de OneDrive diferidos) se describen en
[README](../README.es.md). No reproduce los bypass de Setup/OOBE, los cambios
temporales de red ni el cleanup one-shot. El validador estático comprueba el hash
fuente y los inventarios exactos de Registro/eliminación; la evidencia de
instalación limpia no demuestra equivalencia del standalone.

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
- `ConfigureStartPins` se configura como el par ADMX exacto de política de
  máquina en `HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer`:
  `ConfigureStartPins` (DWord 1) y `ConfigureStartPinsJSON` (REG_EXPAND_SZ) con
  la ruta a `C:\ProgramData\TMPC-Windows-11-Optimization\LayoutModification.json`;
  el archivo contiene la lista vacía y `applyOnce`. El par se aplica en el
  siguiente inicio de sesión; su resultado en Inicio se validó manualmente en
  Windows 11 26H2 y todavía requiere validación runtime del archivo de
  respuestas integrado en instalación limpia.
- `DisableCloudOptimizedContent` se aplica como política de máquina
  (`HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent`, DWord 1) para
  desactivar el contenido optimizado en la nube y evitar anclajes promocionales
  en la barra de tareas, como el marcador de Outlook para Windows, en perfiles
  nuevos. No elimina anclados que ya existan y afecta globalmente al contenido
  personalizado: la colección de fondos de Windows Spotlight deja de estar
  disponible (los fondos estáticos siguen funcionando). La referencia CSP lista
  la opción para ediciones Enterprise/Education, por lo que no es soporte Pro
  documentado. Una comprobación visual con un usuario local genuinamente nuevo
  en Windows 11 Pro 26H2 no mostró anclaje de Outlook, con Edge, Explorador de
  archivos y Microsoft Store conservados y la sección Pinned vacía; la
  validación integrada en instalación limpia y la cobertura de efectos
  secundarios siguen pendientes. El baseline histórico 25H2 no incluía esta
  política.
- La vista de Todas las aplicaciones se inicializa como Lista: `AllAppsViewMode`
  (DWord 2) se escribe una sola vez, en la fase de usuario del primer inicio de
  sesión interactivo, y solo si el valor no existe. Se preserva cualquier
  preferencia previa del usuario (Lista, Cuadrícula o Categoría). Es una
  preferencia normal del usuario, no una política: no se crea ninguna política
  ni tarea recurrente y la vista puede cambiarse después. Comportamiento
  observado del Registro, no una interfaz documentada y soportada por Microsoft.
- `ProductKey` es ficticia, formada por ceros; no es una clave real.
- Los efectos de transparencia se desactivan.
- El estado de "No molestar" se configura mediante la interfaz COM interna
  `IQuietHoursSettings` como vía principal; Windows / WpnUserService materializa
  el estado persistente. La escritura directa del blob de CloudStore de Quiet
  Hours se conserva únicamente como fallback para formatos materializados
  reconocibles. El mecanismo se validó en la referencia histórica Windows 11
  Pro 25H2; la revalidación en Windows 11 26H2 sigue pendiente.
- File Explorer define para el usuario creado durante la instalación: vista
  compacta activada, casillas de elemento desactivadas, extensiones de nombre de
  archivo visibles y elementos ocultos visibles. Todas se aplican en HKCU.
  `ShowSuperHidden` permanece en 0: los archivos protegidos del sistema siguen
  ocultos.
- Windows 11 abre por defecto con "Agrupar por = Ninguno" las vistas de las
  carpetas normales: elementos generales (Generic), Documents, Pictures, Music
  y Videos. El perfil no aplica ninguna personalización de agrupación sobre
  ellas: usa el comportamiento nativo de Windows. Esto se verificó en la
  referencia histórica Windows 11 Pro 25H2; no se ha vuelto a verificar en
  Windows 11 26H2.
- Downloads es la única excepción comprobada: su FolderType de Windows agrupa
  los elementos por fecha de modificación. El perfil crea un override por
  usuario del FolderType de shell: copia el FolderType de Downloads instalado
  por Windows en HKCU y deja `GroupBy` como cadena vacía. No se borran `Bags`
  ni `BagMRU` y no se modifica el FolderType de HKLM.
- Home, Gallery, SearchResults, Libraries, StartMenu y otras vistas especiales
  quedan fuera del alcance. Sus agrupaciones pueden ser estructurales y no se
  modifican automáticamente.

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
- Los hallazgos de la revisión técnica del flujo de personalización están
  corregidos y comprobados estáticamente.
- Los scripts embebidos analizados no se han ejecutado sobre ningún sistema.
- El validador estático local `scripts/validate-baseline.ps1` reproduce estas
  comprobaciones en modo de solo lectura y sin ejecutar los scripts embebidos;
  no sustituye una instalación limpia real.

Hashes SHA-256 del baseline actual:

- `autounattend.xml`:
  `D99BF0EC59A8CB322A84E99F36373FEDD6358350A0D053A02FEB24C11A608EA4`.
- `ventoy.json`:
  `058F0FB83D2BD9EBBB471E518040E04C0CD9D1A752CBBCEC5904166B9EB5908B`.

Baseline actual: motor de Registro idempotente y verificado en XML y
standalone (leer -> comparar tipo y valor exactos -> escribir solo si difiere
-> releer y verificar), con estados diferenciables (`ALREADY_COMPLIANT`,
`APPLIED`, `READ_DENIED`, `WRITE_DENIED`, `VERIFY_FAILED`,
`SKIPPED_NOT_APPLICABLE`) y contadores separados para operaciones aplicadas,
ya conformes y omitidas. Los borrados tratan la ausencia de clave o valor como
conforme y verifican el resultado; una lectura denegada nunca se interpreta
como ausencia. Los bloques embebidos de OneNote y OneDrive están endurecidos
(sin ejecución de cadenas de desinstalación arbitrarias, sin terminación
forzada de procesos, sin `takeown`/`icacls`, sin borrados diferidos al
reinicio y con allowlist estricta y rechazo de reparse points para restos de
OneDrive). La suite aislada `scripts/tests` (dobles en memoria; nunca toca el
Registro, el sistema de archivos ni procesos del anfitrión) cubre el motor,
el preflight, los códigos de salida y los rechazos de seguridad.

### Compatibilidad admitida y clasificación

Categorías documentales del contrato de compatibilidad:

- `TESTED_ON`: Windows 11 Pro 26H2, build base 26300, x64 (la revisión UBR no
  está fijada).
- `SUPPORTED_BY_DESIGN`: Windows 11 cliente (build >= 22000), AMD64 nativo,
  Windows PowerShell 5.1 Desktop, proceso de 64 bits, cuenta de usuario real;
  Full exige consola elevada y UserOnly mantiene su contrato sin elevación.
- `NOT_RUNTIME_TESTED`: cualquier otra build de Windows 11 dentro de ese marco;
  se acepta, aplican las guardas por operación, las degradaciones se informan y
  no se afirma compatibilidad completa; una actualización de UBR no fuerza un
  rechazo.
- `UNSUPPORTED`: Windows 10 o familias anteriores y ediciones de servidor.
- `INCOMPATIBLE`: hosts no AMD64, PowerShell de 32 bits o no Desktop.

El sistema admitido se separa de lo efectivamente comprobado: la única
referencia runtime probada del standalone es 26H2; el baseline histórico
publicado v0.1.5 corresponde a Windows 11 Pro 25H2.

### Gestión de errores de la fase SYSTEM (specialize)

La fase SYSTEM de specialize registra en el log cada fallo de operación. Esos
fallos no fuerzan una salida global distinta de cero en esa fase: así se evita
convertir fallos parciales de personalización no críticos en un bloqueo de
Windows Setup, y la fase conserva su diseño fail-open.

La fase de personalización de usuario (`-UserCustomizations`) sí sale con un
código distinto de cero cuando termina con errores. Ese código forma parte de
la semántica de reintento/recuperación de la one-shot: la tarea programada se
conserva o se restaura para que el siguiente logon pueda reintentar.

El registro inicial de la one-shot usa un reintento acotado de hasta 3
intentos, con una espera corta únicamente entre intentos fallidos. Un fallo
definitivo tras el tercer intento sigue quedando registrado como error; no crea
un bucle y no bloquea Windows Setup.

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

### Comprobado experimentalmente (usuario local limpio, Windows 11 25H2)

En un usuario local desechable sobre Windows 11 25H2 se
validó el mecanismo del override de Downloads:

- Perfil limpio antes del experimento: `UseCompactMode` ausente,
  `AutoCheckSelect = 1`, `HideFileExt = 1`, `Hidden = 2`,
  `ShowSuperHidden = 0`, `UseAutoGrouping` ausente; el override de Downloads en
  HKCU no existía y `Bags` no existía.
- Antes de aplicar cualquier personalización, las carpetas normales abiertas
  por primera vez en el usuario limpio ya mostraban "Agrupar por = Ninguno":
  Generic, Documents, Pictures, Music y Videos (PASS). La única vista que
  agrupaba era Downloads, por fecha de modificación.
- Método: copiar recursivamente el FolderType de Downloads de HKLM a HKCU con
  `reg.exe copy /s /f` y cambiar únicamente
  `TopViews\{00000000-0000-0000-0000-000000000000}\GroupBy` a cadena vacía
  (`REG_SZ`). El resto de valores (`ColumnList`, `GroupAscending`,
  `LogicalViewMode`, `Name`, `Order`, `PrimaryProperty`, `SortByList`) quedaron
  idénticos a HKLM.
- Resultados runtime del override de Downloads: primera apertura con
  "Agrupar por = Ninguno" (PASS), persistencia tras cerrar y reabrir (PASS),
  sin regresión observable en `Bags` ni en carpetas genéricas; `Bags` apareció
  tras la primera apertura con 0 valores de agrupación; `BAGS_RESET_REQUIRED =
  NO`; `USEAUTOGROUPING_REQUIRED = NO`.
- La agrupación por defecto de las carpetas normales es la nativa de Windows 11
  25H2 (`GLOBAL_NORMAL_FOLDER_GROUPING = PASS experimental`); la única
  personalización de agrupación del perfil es el override de Downloads
  (`NATIVE_NONE_DEFAULT + DOWNLOADS_SPECIFIC_OVERRIDE`).
- `UseAutoGrouping = 0` se probó antes y se RECHAZÓ: Downloads siguió agrupando
  por fecha de modificación. No forma parte del baseline.
- No fue necesario borrar `Bags` ni `BagMRU`; en una instalación limpia las
  vistas guardadas no existen antes de que se aplique el override.
- El override de FolderTypes en HKCU no es una API pública estable de Microsoft
  y está validado específicamente en Windows 11 25H2; una actualización mayor
  puede eliminar la clave HKCU y revertir el comportamiento.

El equipo de prueba está permanentemente detectado como slate
(`ConvertibleSlateMode = 0`, `SM_CONVERTIBLESLATEMODE = 0`) aunque se instaló el
driver Lenovo ACPI oficial (`LENOVO_VPC2004_DRIVER = PASS`,
`LENOVO_POSTURE_DETECTION = FAIL`). Por ello, la apariencia visual de vista
compacta y casillas en ese equipo no se usa como criterio bloqueante; la
agrupación de Downloads sí se valida funcionalmente porque no depende del
espaciado táctil. No se introducen hacks de convertibilidad en el baseline.

### Comprobado experimentalmente (usuario local genuinamente nuevo, Windows 11 Pro 26H2)

Sobre una instalación Hyper-V existente de Windows 11 Pro 26H2 (build
26300.9457) cuya política de pins de Inicio ya estaba validada, se preparó la
política de máquina `DisableCloudOptimizedContent` (DWord 1) y se creó un
usuario local genuinamente nuevo:

- Outlook para Windows no quedó anclado en la barra de tareas.
- Microsoft Edge, Explorador de archivos y Microsoft Store se conservaron.
- La sección Pinned de Inicio quedó vacía.
- La prueba integrada en instalación limpia con el nuevo archivo de respuestas
  sigue pendiente.

Es evidencia visual de un usuario y una build; no es cobertura de versiones ni
implica soporte oficial documentado para Pro.

### Comprobado experimentalmente (perfil existente, Windows 11 Pro 26H2)

En un perfil existente de Windows 11 Pro 26H2 se estableció `AllAppsViewMode`
(REG_DWORD 2) de forma programática y se cerró y volvió a abrir la sesión:

- `RUNTIME_EXISTING_PROFILE = PASS`: la vista de Todas las aplicaciones mostró
  el diseño Lista tras volver a iniciar sesión y el valor persistió.
- Categoría y Cuadrícula siguieron disponibles como opciones.
- `CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED`: el archivo de respuestas
  integrado no ha ejecutado una instalación limpia que escriba este valor
  automáticamente.
- `STANDALONE_RUNTIME = NOT_TESTED`: el standalone no se ha ejecutado.

Es un perfil y una build. No se afirma soporte oficial de Microsoft para
`AllAppsViewMode`: es un comportamiento observado del Registro.

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

El recorrido de reintento/recuperación de la one-shot se observó además en
runtime el 2026-09-12 con una prueba controlada de fallo sobre el baseline
publicado `C0EA1741BB09EA88F83F2D4C841081C9441AEE9F81DC4D2681ED6C9C9A5F03D1`:
la one-shot se eliminó y verificó antes del fallo, el fallo no se reportó como
éxito, la recuperación restauró y verificó la one-shot, el reintento del
siguiente logon completó el cleanup y el reinicio final arrancó con el sistema
limpio. Estado: ruta normal de la one-shot = PASS; recuperación = PASS.

### Implementación evaluada: instalación limpia real y Explorer integrado (2026-09-12)

La implementación evaluada (corrección del registro del cleanup de la one-shot,
preferencias de Explorer y override de Downloads) completó una instalación
limpia destructiva real en el equipo de prueba, con el medio verificado por
SHA-256 y sin instrumentación de prueba. Resultado:

- llegada al escritorio final correcta, con modo oscuro y fondo por defecto
  (`AppsUseLightTheme = 0`, `SystemUsesLightTheme = 0`,
  `WallPaper = C:\Windows\Web\Wallpaper\Windows\img19.jpg`);
- un reinicio automático observado durante el flujo;
- ruta normal de la one-shot completa: tarea retirada y verificada, cleanup
  registrado y verificado, marcador de usuario eliminado, reinicio automático
  ejecutado, cleanup final completado y arranque posterior sin residuos
  (`AUTOUNATTEND_TASK_COUNT = 0`, `C:\ProgramData\Autounattend` ausente,
  `HKLM\SOFTWARE\Autounattend` ausente, marcador de usuario ausente);
- Registro de Explorer: `UseCompactMode = 1`, `AutoCheckSelect = 0`,
  `HideFileExt = 0`, `Hidden = 1`, `ShowSuperHidden = 0`; override HKCU de
  Downloads presente con `GroupBy` vacío (`REG_SZ`) y HKLM conservando
  `System.DateModified`; `UseAutoGrouping` ausente;
- validación visual/funcional: Generic, Documents, Pictures, Music y Videos
  abren con "Agrupar por = Ninguno" de forma nativa y Downloads abre con
  "Agrupar por = Ninguno" mediante el override y conserva el estado tras cerrar
  y reabrir el Explorador.

Estados: ruta normal de la one-shot revalidada = PASS, validación runtime de la
implementación evaluada = PASS, validación del Registro de Explorer = PASS,
instalación limpia con Explorer integrado = PASS, persistencia al reabrir
Downloads = PASS, validación runtime = PASS.

La anomalía histórica de primer logon (barra y fondo visualmente claros hasta un
logoff/logon) no se reprodujo en esta instalación; su causa sigue sin
comprobarse y no se declara resuelta. La vista compacta y las casillas no se
usan como criterio visual en el equipo de prueba por su anomalía slate ya
documentada; sus valores de Registro sí se comprobaron.

### Pendiente / no comprobado

- Causa exacta del "No molestar" activado en la primera instalación limpia:
  PENDIENTE / NO COMPROBADA; el blob compacto de 13 bytes no equivale a
  `PriorityOnly` y no debe documentarse como DND activado.
- La cobertura runtime de los hallazgos revisados restantes es parcial: algunos
  no se observaron en runtime y otros están verificados solo parcialmente.
- Corrección y comprobación de los hallazgos restantes de la revisión técnica.
- Efectividad completa de las funciones de IA de Paint: las políticas se
  aplican, pero la limpieza visual no se logró y el efecto concreto de cada
  función sigue sin confirmarse.
- Compatibilidad con versiones, ediciones o builds distintos de Windows 11
  26H2.
- Cualquier otro elemento marcado como pendiente en la documentación del
  repositorio.
- La detección de postura del equipo de prueba está permanentemente en modo
  slate (`ConvertibleSlateMode = 0`, `SM_CONVERTIBLESLATEMODE = 0`); la
  apariencia visual de vista compacta y casillas en ese equipo no es evidencia
  fiable y no se usa como criterio bloqueante. La agrupación de Downloads sí se
  valida funcionalmente en ese equipo.

**Una validación estática no sustituye una instalación limpia real.** El XML
publicado `v0.1.5` completó instalaciones limpias reales en la referencia
histórica Windows 11 Pro 25H2. El archivo de respuestas actual tiene como
objetivo Windows 11 Pro 26H2 (build base 26300) e incluye los candidatos no
publicados de la política de pins de Inicio, de contenido optimizado en la nube
y de la vista de Todas las aplicaciones: el par ADMX exacto de pins superó una
prueba manual
en Windows 11 26H2 (Pinned vacío en el siguiente inicio de sesión y pins
posteriores del usuario conservados), la política de contenido optimizado se
comprobó visualmente con un usuario nuevo en esa misma build y la preferencia
inicial de Lista se verificó en un perfil existente de la misma build
(`RUNTIME_EXISTING_PROFILE = PASS`; `CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED`;
`STANDALONE_RUNTIME = NOT_TESTED`), pero el archivo de respuestas integrado
todavía requiere validación de inicio de sesión en instalación limpia. El
versionado o etiquetado de una release documenta el baseline validado
correspondiente, pero no amplía ni garantiza la compatibilidad con otras
versiones, ediciones o builds de Windows.

## 3. Limitaciones y dependencias

- Windows 11 Pro 26H2 (build base 26300) es la referencia actual. Su archivo de
  respuestas integrado todavía requiere una revalidación en instalación limpia
  de los últimos cambios, y el standalone no tiene prueba runtime. La
  compatibilidad con otras versiones, ediciones o builds no está comprobada ni
  garantizada.
- `BypassNRO` puede depender de la versión o build concreta de Windows.
- `ConfigureStartPins` usa el par ADMX de política de máquina con un JSON
  persistente y `applyOnce`; su aplicación efectiva en el menú Inicio se validó
  manualmente en Windows 11 26H2 y la validación runtime del archivo de
  respuestas integrado en instalación limpia sigue pendiente; debe revalidarse
  ante cambios de Windows. `applyOnce` requiere Windows 11 24H2 o posterior con
  KB5062660.
- `DisableCloudOptimizedContent` desactiva globalmente el contenido optimizado
  en la nube. Evita anclajes promocionales en la barra de tareas de perfiles
  nuevos (por ejemplo, el marcador de Outlook para Windows), pero no elimina
  anclados ya existentes; el contenido personalizado y la colección de fondos
  de Windows Spotlight dejan de estar disponibles. La referencia CSP lista la
  opción para ediciones Enterprise/Education: no es soporte Pro documentado.
  Se comprobó visualmente con un usuario local nuevo en Windows 11 Pro 26H2;
  la validación integrada en instalación limpia, la cobertura de efectos
  secundarios y la compatibilidad fuera de esa build siguen pendientes.
  Revertirla solo requiere eliminar ese valor: no exige resetear la barra de
  tareas, borrar perfiles ni tocar la política de pins de Inicio.
- La vista inicial Lista de Todas las aplicaciones depende de `AllAppsViewMode`
  (`HKCU\Software\Microsoft\Windows\CurrentVersion\Start`, DWord 2). Es un
  comportamiento observado del Registro, no una interfaz documentada y
  soportada por Microsoft, y debe revalidarse ante cambios de Windows. Solo se
  escribe si el valor no existe, por lo que nunca se sobrescribe una
  preferencia previa del usuario. La evidencia en perfil existente es un cambio
  manual en Windows 11 Pro 26H2 (Lista visible tras cerrar y abrir sesión, con
  Categoría y Cuadrícula todavía disponibles); la aplicación automática por una
  instalación limpia (`CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED`) y el runtime
  del standalone (`STANDALONE_RUNTIME = NOT_TESTED`) siguen pendientes, y el
  comportamiento en otras builds, incluida la referencia histórica 25H2, no
  está probado. Revertirla solo requiere cambiar o eliminar ese valor de
  usuario; no existe ninguna política, tarea, GPO ni reaplicación recurrente.
- La configuración de CloudStore/Quiet Hours depende de detalles de
  implementación validados en la referencia histórica Windows 11 Pro 25H2; la
  revalidación en la referencia actual Windows 11 26H2 sigue pendiente. La vía
  principal usa la interfaz interna no documentada `IQuietHoursSettings`, que
  puede cambiar en futuras builds y debe revalidarse.
- "No molestar" solo se desactiva en el momento de aplicar el perfil; no es una
  garantía permanente. Windows 11 puede volver a activarlo mediante su
  activación automática (Configuración > Sistema > Notificaciones:
  determinados horarios, duplicación de pantalla, durante juegos, aplicaciones
  a pantalla completa y la primera hora posterior a una actualización de
  características de Windows; una sesión de concentración también lo activa
  automáticamente). TMPC no configura ni desactiva esas reglas del usuario o
  del sistema, por lo que una reactivación posterior no demuestra por sí sola
  un fallo de TMPC. La causa exacta observada en un PC real sigue sin
  confirmarse. Condiciones y valores actuales: soporte oficial de Microsoft,
  https://support.microsoft.com/en-us/windows/experience/notifications-and-do-not-disturb-in-windows.
- El override por usuario del FolderType de Downloads no es una API pública de
  Microsoft; una actualización mayor puede eliminar `HKCU\...\FolderTypes` y
  revertir el default de agrupación. Antes de copiar el FolderType, el perfil
  verifica el default instalado (`GroupBy = System.DateModified`); ese valor se
  verificó en la referencia histórica 25H2 y no se ha vuelto a verificar en
  26H2. Si difiere, el override se omite y la discrepancia se registra como
  error en lugar de escribir una vista no verificada. El resto de carpetas
  normales usa el default nativo de Windows 11 (verificado en la referencia
  histórica 25H2) y no tiene override.
- Las funciones de IA de Notepad quedaron sin presencia visible en la prueba
  real; las funciones de IA de Paint siguen sin confirmarse y su limpieza
  visual no se logró.
- Los hallazgos restantes de la revisión técnica siguen pendientes.
- El versionado o etiquetado de releases no amplía el alcance de
  compatibilidad: la referencia actual es Windows 11 Pro 26H2 (build base
  26300), cuya validación integrada sigue pendiente, mientras que el baseline
  histórico 25H2 permanece validado.

## 4. Fuentes, licencias y atribuciones

Referencias de origen presentes en los archivos versionados:

- `autounattend.xml` incluye la referencia
  `Source: https://github.com/memstechtips/Autounattend` en las notas de dos
  scripts generados: `BloatRemoval.ps1` (versión 2.3) y `OneDriveRemoval.ps1`
  (versión 1.2). Esa URL histórica se conserva deliberadamente dentro del XML
  para no alterar el baseline validado.

Licencia del proyecto:

- TMPC Windows 11 Optimization se distribuye bajo la licencia MIT.
- Copyright (c) 2026 Alvaro-TMPC.
- El texto completo está en `LICENSE`.

Componentes de terceros:

- Parte de `autounattend.xml` deriva de, o se basa en, código distribuido en
  `memstechtips/UnattendedWinstall`.
- Revisión de referencia (snapshot):
  `cca752363772a845eb0fed9d3a5b89b5d0a10d20`.
- Licencia del snapshot: MIT License.
- Copyright: Copyright (c) 2025 Marco du Plessis (memstechtips).
- Componentes identificados: `BloatRemoval.ps1` (versión 2.3),
  `OneDriveRemoval.ps1` (versión 1.2) y lógica auxiliar/automatización
  relacionada.
- Referencia canónica para licencias y trazabilidad:
  `https://github.com/memstechtips/UnattendedWinstall`. La URL histórica
  `https://github.com/memstechtips/Autounattend` permanece dentro del XML y se
  documenta por separado.
- Los avisos completos de terceros, incluido el texto MIT con su copyright,
  están en `THIRD_PARTY_NOTICES.md`.

Otros componentes evaluados:

- Ventoy: el repositorio solo incluye configuración propia (`ventoy.json`); el
  usuario descarga Ventoy externamente y no se redistribuyen binarios de
  Ventoy.
- Microsoft: no se redistribuye Windows, ISO ni binarios de Microsoft; la
  `ProductKey` de ceros es ficticia.
- TechPowerUp: aparece únicamente como proveedor de herramientas externas
  opcionales enlazadas desde la documentación del proyecto (por ejemplo, la
  recomendación opcional del paquete Visual C++ Redistributable en
  `docs/preparacion-previa-instalacion.md` y GPU-Z en las guías posteriores a
  la instalación); no se incorporan ni redistribuyen binarios ni contenido
  suyo como parte del proyecto.

Estado:

- Auditoría de procedencia, licencias y atribuciones: CERRADA.
- El historial Git no requiere reescritura por motivos de licensing.
