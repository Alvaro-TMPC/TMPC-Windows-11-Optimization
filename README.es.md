# TMPC Windows 11 Optimization

[English](README.md) | **Español**

## Qué es este proyecto

TMPC Windows 11 Optimization es un perfil reproducible para una instalación
limpia de Windows 11. Está pensado para usuarios que quieren un sistema
orientado a la privacidad, con una reducción conservadora de aplicaciones
integradas, y que siga siendo adecuado para gaming, programación y uso diario.

El perfil se entrega como un único archivo de respuestas (`autounattend.xml`)
aplicado durante la instalación de Windows, más una pequeña configuración de
Ventoy (`ventoy.json`) que asocia la ISO de Windows esperada con ese archivo de
respuestas en el USB de instalación.

Para una instalación existente, el archivo autocontenido adicional
[`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1) aplica la parte
post-install relevante del mismo perfil; consulta la sección siguiente.

Plataforma objetivo: Windows 11 Pro 26H2, x64 / amd64 (build base 26300). El
baseline publicado v0.1.5 se validó en Windows 11 Pro 25H2 (referencia
histórica); consulta las secciones de entorno probado y limitaciones.

## Qué hace

El baseline actual aplica las siguientes decisiones:

Privacidad:

- telemetría reducida al mínimo permitido por el sistema, identificador de
  publicidad desactivado y experiencias personalizadas desactivadas;
- activity feed, subida de actividad a la nube y portapapeles entre
  dispositivos desactivados;
- acceso a ubicación denegado y permisos no esenciales de aplicaciones
  denegados de forma forzada;
- acceso a los modelos generativos en el dispositivo denegado, Recall
  impedido y Click to Do desactivado donde sea compatible;
- puntos de entrada de Copilot desactivados y aplicación Copilot eliminada;
- el acceso a cámara y micrófono queda bajo control del usuario;
- el cifrado automático del dispositivo (BitLocker) se impide durante la
  instalación.

Debloat (conservador, con lista curada):

- se eliminan aplicaciones de consumo como noticias, clima, mapas, Solitaire,
  aplicaciones complementarias de Xbox, Teams/Skype de consumo, Sticky Notes,
  To Do, Your Phone, OneNote y Copilot;
- se eliminan componentes heredados como WordPad, PowerShell ISE y Steps
  Recorder;
- se conservan deliberadamente: Microsoft Defender, Microsoft Store, Edge y
  WebView2, Microsoft Photos, Paint y Notepad.

Funciones de Windows:

- Windows Update se mantiene activo para actualizaciones de calidad y
  seguridad, pero los drivers distribuidos mediante Windows Update quedan
  excluidos;
- Microsoft Defender se mantiene activo; solo se reducen las notificaciones no
  críticas de Seguridad de Windows;
- Microsoft Store se mantiene disponible para instalar aplicaciones, reparar y
  resolver dependencias;
- OneDrive se elimina y se bloquea, conservando los datos de usuario que ya
  existan en la carpeta de OneDrive;
- Paint y Notepad se mantienen instalados con sus funciones de IA desactivadas
  por política (Cocreator, Generative Fill, Image Creator y funciones de IA de
  Notepad);
- "No molestar" se configura desactivado en el momento de aplicar el perfil
  (Windows puede volver a activarlo con sus propias reglas automáticas;
  consulta Limitaciones conocidas);
- Game Mode se activa; Game DVR y los servicios complementarios de Xbox Live
  se desactivan;
- el plan de energía es el plan Balanced estándar de Windows; hibernación y
  Fast Startup se desactivan (las opciones Suspender y Hibernar se ocultan del
  menú de energía de Inicio, el bloqueo de Windows sigue disponible);
- los efectos de transparencia se desactivan y el tema por defecto es oscuro;
- File Explorer: vista compacta activada, casillas de elemento desactivadas,
  extensiones de nombre de archivo visibles y archivos ocultos visibles (los
  archivos protegidos del sistema siguen ocultos), menú contextual clásico y
  Acceso rápido limpio;
- Downloads abre sin agrupación por fecha (override por usuario de la vista de
  carpeta); las carpetas normales conservan el comportamiento nativo de
  Windows 11;
- no se aplican tweaks agresivos de CPU, GPU, planificador ni red.

Funciones de IA de Windows que el perfil desactiva: Recall, Click to Do, agente
de IA de Configuración, Paint Cocreator, Paint Generative Fill, Paint Image
Creator, funciones de IA de Notepad y puntos de entrada heredados de Windows
Copilot.

Este README resume el comportamiento; no es un volcado del Registro. El archivo
de respuestas sigue siendo la fuente autoritativa.

## Entorno probado

Referencia actual: Windows 11 Pro 26H2 (x64 / amd64, build base 26300; la
revisión del sistema no está fijada). En una instalación limpia 26H2 usada como
entorno de prueba:

- el par de política de pins de Inicio se aplicó como el par ADMX exacto de
  política de máquina y su resultado se verificó en runtime (sección Pinned
  vacía y pins posteriores del usuario conservados);
- el anclaje promocional de Outlook para Windows estuvo visualmente ausente
  para un usuario local genuinamente nuevo, con Edge, Explorador de archivos y
  Microsoft Store conservados;
- `AllAppsViewMode` (DWord 2) se aplicó de forma programática en un perfil
  existente: Lista visible tras cerrar y abrir sesión, y el valor persistió.

El archivo de respuestas integrado con los últimos cambios no se ha vuelto a
probar en otra instalación limpia, y el standalone no tiene todavía prueba
runtime.

Evidencia histórica: el baseline publicado v0.1.5 completó instalaciones limpias
reales en Windows 11 Pro 25H2 (x64 / amd64), incluyendo:

- instalación, OOBE y llegada al primer escritorio sin errores bloqueantes;
- creación de cuenta local sin prompt obligatorio de red ni de cuenta
  Microsoft;
- personalizaciones de usuario aplicadas mediante una tarea de un solo uso;
- reinicio automático ejecutado por el perfil y llegada al escritorio final;
- cleanup final completado, sin tareas de instalación ni archivos temporales
  residuales;
- valores de Explorer y override de la vista de Downloads verificados.

Esa evidencia documenta el baseline histórico 25H2; no es una afirmación de
instalación limpia 26H2. Otras versiones, ediciones o builds de Windows 11 no
están garantizadas. Builds futuras pueden requerir revalidación.

## Advertencia importante

Una instalación limpia puede destruir datos de forma irreversible. Antes de
empezar:

- haz un backup completo de tus datos y comprueba que se puede leer;
- revisa el archivo de respuestas antes de usarlo; tú eres responsable de lo
  que aplique en tu equipo;
- este perfil NO selecciona ni borra discos: el disco y las particiones los
  eliges tú manualmente en la instalación de Windows, así que verifica con
  atención qué disco vas a modificar;
- si puedes, prueba todo el procedimiento primero en una máquina desechable o
  en una máquina virtual.

## Aplicar las optimizaciones a una instalación de Windows existente

`autounattend.xml` sigue siendo la vía para instalación limpia. El archivo
autocontenido [`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1),
versión standalone 0.2.0, ofrece una vía post-install **sin formatear**, derivada
directamente del archivo de respuestas (v0.1.5 más los bloques candidatos 26H2:
política de pins de Inicio, contenido optimizado en la nube y vista de Todas las
aplicaciones). No necesita otros archivos del repositorio, dependencias externas
ni descargas. El trabajo de Registro es ahora idempotente y verificado: cada
valor se lee primero, solo se escribe si difiere y se vuelve a leer para
confirmar el resultado, de modo que un PC ya conforme no se reescribe.

**Compatibilidad (TESTED_ON / SUPPORTED_BY_DESIGN / NOT_RUNTIME_TESTED).** La
referencia probada es Windows 11 Pro 26H2 (build base 26300; la revisión del
sistema no está fijada). Por diseño acepta ediciones cliente de Windows 11
(build 22000 o posterior) en Windows PowerShell 5.1 AMD64 nativo, desde una
cuenta de usuario real; el modo completo requiere consola elevada. Cualquier
otra build de Windows 11 dentro de ese marco se acepta y se registra como
`NOT_RUNTIME_TESTED`: aplican las guardas por operación, las degradaciones se
informan, una actualización acumulativa (UBR) nunca fuerza un rechazo y no se
afirma compatibilidad completa. Windows Server, Windows 10 o familias anteriores
(`UNSUPPORTED`) y hosts no AMD64 o de 32 bits (`INCOMPATIBLE`) se rechazan antes
de cualquier cambio. El baseline publicado de instalación limpia (v0.1.5) tiene
evidencia runtime en la referencia histórica Windows 11 Pro 25H2; este
standalone tiene validación estática más una suite de pruebas automatizadas
aislada y **no** se ha probado en hardware anfitrión. No se afirma un estado
final idéntico en un PC que ya tiene personalizaciones.

Antes de ejecutarlo, haz y verifica un backup, **revisa el script**, guarda tu
trabajo y cierra las aplicaciones afectadas por el debloat. Sal de OneDrive
tras comprobar tus archivos locales/en la nube. El modo completo modifica
configuración del sistema y elimina las apps integradas de la lista del perfil
para todos los usuarios, incluidas las copias provisionadas para cuentas
futuras. La eliminación de apps puede eliminar sus ajustes/estado. Defender,
Store, Edge/WebView2, Photos, Paint y Notepad conservan las decisiones del
baseline. No se cambian discos, particiones, cuentas ni la licencia de Windows.

El modo completo elimina y bloquea OneDrive, pero **conserva todo el contenido
existente en `%USERPROFILE%\OneDrive`**. Los marcadores de posición solo en
línea no son copias locales respaldadas. El borrado de restos de software está
limitado a una lista explícita y rechaza rutas enlazadas/junctions. Si OneDrive
está abierto, el comando de desinstalación no se reconoce o los restos no son
seguros, se informa y se difiere: revisa warnings/errores antes de dar por terminada
la eliminación. Se conservan los binarios de instalación propios de Windows.

Descarga/guarda `Apply-TMPCOptimizations.ps1` desde este repositorio mediante
**Raw / Download raw file** en la página del archivo. Abre **Windows PowerShell
como administrador** para el modo completo, sitúate en la carpeta donde lo
guardaste y ejecuta:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1
```

El modo completo no se autoeleva: la elevación solo es necesaria para su fase
de sistema. Después aplica HKCU únicamente si el SID ejecutor coincide con
Explorer en la misma sesión. Si se usaron credenciales de otro administrador o
no puede verificarse el escritorio, omite HKCU con exit code 3: ejecuta
`-UserOnly` desde la cuenta objetivo. También se difiere la limpieza de OneDrive
en contexto de usuario; `-UserOnly` no realiza esa desinstalación.

Para **una nueva cuenta creada posteriormente**, otro usuario local o volver a
aplicar las preferencias personales, inicia sesión en esa cuenta y abre
**Windows PowerShell normal, sin elevación**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -UserOnly
```

`-UserOnly` es la vía recomendada para cuentas posteriores. Aplica el inventario
HKCU completo de la fase de usuario del archivo de respuestas: gaming/Game DVR,
efectos visuales y shortcuts, notificaciones/No molestar, privacidad/IA, sonido,
preferencias de Update/Store del usuario, Explorer/Downloads, Start/Taskbar y
tema oscuro con el wallpaper del baseline. Solo cambia la cuenta ejecutora,
lee HKLM únicamente para comprobaciones/origen de Downloads, no realiza debloat
ni limpieza global de OneDrive y no necesita elevación. Puede repetirse sin
eliminar ningún marker.

Por defecto **no hay reinicio automático**. Algunos cambios requieren cerrar
y abrir sesión o reiniciar. Para solicitar conscientemente un reinicio en modo
completo, guarda primero todo el trabajo y usa:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -Restart
```

Solo solicita reinicio con exit code 0, con 60 segundos de aviso (Windows puede
cerrar aplicaciones al cumplirse el plazo); cancela con `shutdown.exe /a` si
hace falta. `-UserOnly` no acepta `-Restart`; reinicia manualmente desde Windows.

### Cobertura y diferencias post-install

| Bloque del baseline | Comportamiento post-install |
| --- | --- |
| Registro/políticas de sistema | Mismos nombres, tipos y valores HKLM: privacidad, Update/exclusión de drivers, notificaciones de Defender, gaming, energía, IA, Explorer, Start/Taskbar, supresión de contenido optimizado en la nube y sonido. Los borrados HKCR se resuelven a Classes de máquina, como en la fase SYSTEM original. |
| Registro/personalización de usuario | Mismo inventario HKCU completo y máscaras binarias; Quiet Hours usa la ABI COM nativa del origen y el fallback CloudStore reconocido. Downloads copia HKLM a HKCU sin resetear vistas guardadas. |
| Debloat | Mismos 40 objetivos AppX, 4 de capabilities y Recall; eliminación secuencial comprobada. Se difiere el desinstalador especial de OneNote **de escritorio**, porque strings arbitrarios pueden afectar una suite Office existente; su paquete AppX sigue incluido. |
| OneDrive | Misma intención de eliminación/bloqueo y prevención de autoinstalación en el perfil por defecto, adaptada a identidad verificada y rutas de software protegidas. Sin terminar procesos a la fuerza, tomar ACL recursivamente ni diferir borrados al reinicio. |
| .NET Framework 3.5 | Si no está habilitado, necesita medio local compatible; sin fallback a Windows Update. Añade `-NetFx3Source "D:\sources\sxs"` en modo completo (sustituye `D:` por tu unidad del medio montado). Sin origen se conserva el estado y se informa. |
| Pins de Inicio / cifrado | Par ADMX exacto de política de máquina `ConfigureStartPins` (DWord 1) + `ConfigureStartPinsJSON` (REG_EXPAND_SZ con ruta) apuntando a un `LayoutModification.json` persistente con `applyOnce`; el par se validó manualmente en 26H2 y la prueba integrada de instalación limpia sigue pendiente. `PreventDeviceEncryption` no descifra un BitLocker existente. |
| Contenido optimizado en la nube | La política de máquina `DisableCloudOptimizedContent` (DWord 1) desactiva el contenido optimizado en la nube para evitar anclajes promocionales en la barra de tareas, como el marcador de Outlook para Windows, en perfiles nuevos. No elimina anclados que ya existan, afecta globalmente al contenido personalizado de la nube (los fondos de Windows Spotlight dejan de estar disponibles), la referencia CSP la lista para ediciones Enterprise/Education (sin soporte Pro documentado) y solo se comprobó visualmente con un usuario nuevo en Windows 11 Pro 26H2; la validación integrada en instalación limpia sigue pendiente. |
| Vista de Todas las aplicaciones | `AllAppsViewMode` inicial (DWord 2 = Lista) escrito una sola vez en HKCU y solo si el valor no existe; se preserva cualquier elección previa del usuario (Lista, Cuadrícula o Categoría). Es una preferencia normal del usuario, no una política: no se crea ninguna política ni tarea recurrente y la vista puede cambiarse después. |
| Setup/OOBE | No se reproducen: bypass de hardware, ProductKey/EULA, BypassNRO/pantallas OOBE, desactivar/reactivar red, instalación y creación de cuentas. |
| One-shot / cleanup | No se crean tareas de Setup, tokens, markers de finalización ni limpieza de carpetas de Setup. Los logs se conservan; el reinicio es opcional. |

Puede mantenerse una agrupación de Downloads guardada previamente porque se
conservan `Bags`/`BagMRU`. Las entradas HKCU existentes del menú contextual
también pueden prevalecer sobre Classes de máquina. La efectividad de políticas
puede depender de la edición de Windows o de políticas de administración; siguen
vigentes las limitaciones de la interfaz interna Quiet Hours y de la UI de IA
de Paint. Consulta la matriz completa por líneas del origen en la cabecera.
Setup ejecuta originalmente la fase de sistema como SYSTEM; este standalone
usa un administrador. Las claves existentes protegidas o paquetes AppX en uso
pueden fallar y producir exit code 1; no se toman ACL para forzar esos cambios.

Logs completos: `%ProgramData%\TMPC-Windows-11-Optimization\Logs\`.
Logs UserOnly: `%LOCALAPPDATA%\TMPC-Windows-11-Optimization\Logs\` (sin escritura
elevada). El resumen final muestra modo, operaciones completadas, warnings,
errores, recomendación de reinicio, ruta del log y exit code: 0 = completado
(revisar warnings de limitaciones), 1 = fallo de operación/log, 2 = rechazo del
preflight, 3 = fase de sistema terminada pero preferencias del usuario objetivo
diferidas. No hay rollback automático. El validador comprueba la vinculación
SHA-256 con el XML fuente y los inventarios exactos de Registro/eliminación,
obligando a revisar expresamente los cambios futuros del baseline.

## Antes de empezar

Prepara al menos:

1. Backups y verificación.
   - Respalda Escritorio, Documentos, Descargas, Imágenes, Vídeos, Música,
     proyectos y repositorios, y cualquier dato guardado fuera de las carpetas
     estándar.
   - Abre una muestra de archivos directamente desde el destino del backup
     para verificarlo.
   - Asegúrate de que la unidad de backup no es una de las unidades que vas a
     formatear.
2. Proyectos y datos de desarrollo.
   - Revisa repositorios locales, cambios sin commit, ramas locales, claves
     SSH/GPG y certificados. Publica o respalda lo que solo exista en este
     equipo. No guardes secretos en un repositorio.
3. Partidas guardadas y contenido no reproducible.
   - Comprueba partidas, mods, perfiles de launchers y capturas juego por
     juego; la sincronización en la nube no está garantizada en todos los
     títulos.
4. Archivos en la nube (OneDrive y similares).
   - Verifica que los archivos importantes están realmente disponibles en local
     o respaldados en otro medio; los marcadores de posición en línea no son
     copias locales.
5. BitLocker / cifrado.
   - Si alguna unidad está cifrada, asegúrate de que las claves de recuperación
     están disponibles fuera del equipo que se va a formatear.
6. Drivers.
   - Este perfil excluye los drivers entregados mediante Windows Update.
     Descarga con antelación, desde el fabricante de tu hardware: drivers de
     Ethernet, Wi-Fi (si el equipo depende de él), chipset, audio y GPU.
     Guárdalos en una unidad accesible durante y después de la instalación.
7. Software.
   - Conserva los instaladores de las aplicaciones que necesitarás justo
     después de instalar (navegador, herramientas de desarrollo, launchers de
     juegos). Este repositorio no instala software de terceros
     automáticamente.
8. Medio de instalación.
   - Usa una ISO genuina de Windows 11 x64 / amd64 de una fuente confiable y
     un USB que puedas borrar; instalar Ventoy reparticiona y formatea la
     unidad USB.

## Crear el USB de Ventoy

El medio de instalación se construye con [Ventoy](https://www.ventoy.net/), una
herramienta de código abierto que arranca archivos ISO directamente desde un
USB.

1. Descarga Ventoy desde su fuente oficial (<https://www.ventoy.net/>). Usa la
   última versión estable; este repositorio no fija una versión concreta.

2. Instala Ventoy en la unidad USB.

   Advertencia: instalar Ventoy en una unidad borra y reparticiona esa unidad.
   Asegúrate de seleccionar el dispositivo USB correcto y de que no contiene
   nada que quieras conservar.

3. Copia los archivos del repositorio al USB con exactamente la estructura que
   espera `ventoy.json`:

   ```text
   <raíz del USB>
   ├── Windows11_Client_x64_es-es_26300_9457.iso
   └── ventoy/
       ├── ventoy.json
       └── script/
           └── autounattend.xml
   ```

   - `ventoy.json` va en `\ventoy\ventoy.json` de la partición Ventoy.
   - `autounattend.xml` va en `\ventoy\script\autounattend.xml`; esa es la ruta
     declarada como `template` en `ventoy.json`.
   - La ISO de Windows va en la raíz del USB con el nombre de archivo exacto
     declarado como `image` en `ventoy.json`, actualmente
     `Windows11_Client_x64_es-es_26300_9457.iso`.

4. El nombre y la ruta de la ISO deben coincidir con el valor `image` de
   `ventoy.json`. Si usas otra ISO, renombra tu archivo para que coincida o
   edita `ventoy.json` de forma coherente (lo mismo se aplica a cualquier otra
   ruta). No uses ISOs modificadas ni fuentes no verificadas.

5. Expulsa el USB de forma segura antes de retirarlo.

Cuando arrancas la ISO, Ventoy muestra un menú de arranque para esa imagen con
dos opciones:

- `Boot without auto installation template`: arranca la ISO de Windows sin
  aplicar ningún archivo de respuestas.
- `Boot with /ventoy/script/autounattend.xml`: arranca la ISO aplicando como
  archivo de respuestas el `autounattend.xml` declarado como `template` en
  `ventoy.json`.

Para instalar TMPC Windows 11 Optimization, elige
`Boot with /ventoy/script/autounattend.xml`.

## Arrancar desde el USB

1. Conecta el USB y enciende (o reinicia) el equipo de destino.
2. Abre el menú de arranque UEFI/BIOS de tu equipo. La tecla varía según la
   placa o el dispositivo (habitualmente F12, F10, F2, Esc o Del, pero no hay
   una tecla universal); consulta la documentación de tu equipo si es
   necesario.
3. Selecciona la entrada del USB. Prefiere la entrada UEFI; este perfil está
   orientado a la ruta amd64/UEFI.
4. Ventoy arranca y muestra los archivos ISO encontrados en la unidad.
   Selecciona `Windows11_Client_x64_es-es_26300_9457.iso`. Ventoy muestra entonces el menú
   de arranque de esa imagen: elige
   `Boot with /ventoy/script/autounattend.xml` para instalar con el perfil, o
   `Boot without auto installation template` para arrancar la ISO sin aplicar
   `autounattend.xml`.
5. Comienza la instalación de Windows.

## Windows Setup

- El perfil no automatiza la selección ni el borrado de discos. Selecciona tú
  el disco y las particiones de destino y verifica con mucho cuidado qué disco
  vas a modificar. Si el disco ya contiene una instalación antigua que quieres
  eliminar, borra sus particiones en la instalación o usa el procedimiento
  manual con DiskPart descrito más abajo; asegúrate de trabajar en la unidad
  correcta.
- El archivo de respuestas omite las comprobaciones de requisitos de hardware
  de Windows 11 (TPM, Secure Boot, CPU, RAM, almacenamiento y disco) durante la
  instalación. Instalar en hardware no compatible sigue siendo tu
  responsabilidad.
- Puede aparecer una pantalla de clave de producto: el archivo de respuestas
  contiene una clave de marcador de posición, no una licencia real. Usa tu
  propia clave si la tienes.
- La instalación continúa automáticamente a partir del archivo de respuestas;
  no la interrumpas.
- El OOBE está diseñado para permitir crear una cuenta local. Durante el OOBE
  los adaptadores de red pueden aparecer desactivados; es intencionado y no es
  un error: se vuelven a activar automáticamente en el primer inicio de sesión.
- Completa el OOBE creando tu cuenta de usuario local y llegando al escritorio.

### Preparación manual del disco con DiskPart

El archivo de respuestas no selecciona ni borra ningún disco; tú eres
responsable de elegir el disco de destino correcto. Este procedimiento es
destructivo y es el procedimiento manual documentado para una instalación
limpia en la que preparas el disco explícitamente; no es obligatorio para
todos los escenarios. Si puedes, desconecta cualquier otro disco que no
participe en la instalación.

1. En Windows Setup, pulsa `Shift + F10` para abrir una consola de comandos.
2. Ejecuta DiskPart e identifica el disco de destino.

   > **Advertencia:** `clean` elimina de forma irreversible la estructura de
   > particiones del disco seleccionado. Confirma el número de disco con
   > `list disk` y `detail disk` antes de ejecutarlo.

   ```text
   diskpart
   list disk
   select disk X
   detail disk
   clean
   convert gpt
   exit
   ```

   - Sustituye `X` por el número del disco de destino correcto.
   - `list disk` muestra los discos disponibles.
   - `detail disk` es la comprobación final antes del borrado: confirma que el
     disco seleccionado es el correcto.
   - `clean` elimina la estructura de particiones del disco seleccionado y debe
     tratarse como una operación destructiva.
   - `convert gpt` prepara explícitamente el disco como GPT para el flujo UEFI.
   - No uses `clean all`: no es necesario para este procedimiento.
3. Cierra la consola, vuelve a Windows Setup, pulsa Actualizar (Refresh) y
   selecciona el espacio sin asignar para que Windows cree las particiones
   necesarias.

## Primer inicio de sesión y reinicio automático

Esta parte es importante. El comportamiento del baseline validado es:

1. Windows llega al escritorio por primera vez.
2. Las personalizaciones de usuario se aplican mediante una tarea de un solo
   uso que se ejecuta al iniciar sesión.
3. Cuando el flujo termina, el equipo programa un reinicio automático (se
   muestra un aviso de unos 20 segundos).
4. No apagues, reinicies ni interrumpas el equipo mientras ocurre esto.
5. Después de ese reinicio llegas al escritorio final; los archivos temporales
   de la instalación se eliminan automáticamente al arrancar.

Considera la instalación terminada cuando alcances el escritorio final después
del reinicio automático.

## Después de la instalación

Después del escritorio final:

- Comprueba la conectividad de red. Si los adaptadores no se reactivaron
  automáticamente, actívalos desde Configuración de Windows o el Administrador
  de dispositivos.
- Instala los drivers OEM que preparaste con antelación: chipset, red/Wi-Fi,
  audio y GPU. Recuerda que las actualizaciones de drivers mediante Windows
  Update están excluidas por este perfil.
- Ejecuta Windows Update con normalidad para instalar actualizaciones de
  calidad y seguridad.
- Revisa el Administrador de dispositivos por si hubiera dispositivos sin
  driver.
- Restaura tus datos y vuelve a instalar tus aplicaciones.
- Reconfigura cuentas, servicios y entornos de desarrollo según necesites.
- Verifica que Microsoft Defender está activo y que Seguridad de Windows no
  muestra avisos críticos.

Este repositorio no instala software, navegadores ni utilidades de terceros:
eso sigue siendo una decisión del usuario.

Para una comprobación más completa del hardware y del sistema después de
instalar, incluyendo PCIe/GPU-Z, monitor, RAM, almacenamiento y periféricos,
consulta [Comprobaciones posteriores a la
instalación](docs/comprobaciones-posteriores-instalacion.md).

## Verificación rápida

Lista de comprobación rápida, a nivel de usuario, para una instalación
correcta:

- [ ] Se alcanza el escritorio final después de un reinicio automático.
- [ ] La conectividad de red funciona.
- [ ] Microsoft Defender está activo.
- [ ] Windows Update está disponible (actualizaciones de calidad/seguridad; sin
      actualizaciones de drivers).
- [ ] Microsoft Store abre.
- [ ] OneDrive no está instalado.
- [ ] Game Mode está activado y Game DVR desactivado.
- [ ] File Explorer muestra las extensiones de archivo y los archivos ocultos
      (los archivos protegidos del sistema siguen ocultos), con la vista
      compacta activada.
- [ ] Downloads abre sin agrupar por fecha y el estado persiste tras cerrar y
      reabrir el Explorador.
- [ ] "No molestar" está desactivado.
- [ ] Los efectos de transparencia están desactivados y el tema por defecto es
      oscuro.

Esta lista refleja el comportamiento probado; no sustituye la validación
estática descrita más abajo.

La verificación detallada de hardware (PCIe con GPU-Z, monitor, RAM,
almacenamiento y periféricos) está en [Comprobaciones posteriores a la
instalación](docs/comprobaciones-posteriores-instalacion.md).

## Integridad de archivos (SHA-256)

Hashes del baseline documentado actual:

```text
autounattend.xml
D99BF0EC59A8CB322A84E99F36373FEDD6358350A0D053A02FEB24C11A608EA4

ventoy.json
058F0FB83D2BD9EBBB471E518040E04C0CD9D1A752CBBCEC5904166B9EB5908B
```

El archivo de respuestas actual tiene como objetivo Windows 11 Pro 26H2 (build
base 26300) y prepara la política de pins de Inicio como el
par ADMX exacto de política de máquina (`ConfigureStartPins` = DWord 1 y
`ConfigureStartPinsJSON` = REG_EXPAND_SZ con la ruta) apuntando a un diseño
vacío persistente con `applyOnce`. Ese par se validó manualmente en Windows 11
26H2 (sección Pinned vacía y pins posteriores del usuario conservados), pero el
archivo de respuestas integrado todavía necesita una prueba de inicio de sesión
en instalación limpia antes de considerar validado su resultado en Inicio. El
archivo de respuestas actual añade además la política de máquina
`DisableCloudOptimizedContent` (DWord 1) para evitar anclajes promocionales de
contenido optimizado en la nube en perfiles nuevos; no elimina anclados que ya
existan y su resultado integrado en instalación limpia sigue pendiente. El
archivo de respuestas actual también inicializa la vista de Todas las
aplicaciones como Lista (`AllAppsViewMode` = DWord 2) en la fase de usuario de
un solo uso, únicamente si el valor no existe:
`RUNTIME_EXISTING_PROFILE = PASS` (cambio manual del Registro en un perfil
existente de Windows 11 Pro 26H2, Lista visible tras cerrar y abrir sesión, con
Categoría y Cuadrícula todavía disponibles),
`CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED` y
`STANDALONE_RUNTIME = NOT_TESTED`. El resto del perfil conserva la evidencia
runtime del baseline publicado v0.1.5, que se validó en la referencia histórica
Windows 11 Pro 25H2. El archivo de respuestas actual incorpora además el motor
de Registro idempotente y verificado (leer primero, escribir solo si un valor
difiere, releer para verificar) y los bloques endurecidos de OneNote/OneDrive
(sin cadenas de desinstalación arbitrarias, sin terminación forzada de procesos,
sin cambios de propiedad o ACL y sin borrados diferidos). Una suite de pruebas
aislada (`scripts/tests`) ejercita el motor y el endurecimiento con dobles en
memoria.

Verifícalos en tu copia:

```powershell
Get-FileHash -Algorithm SHA256 .\autounattend.xml, .\ventoy.json
```

Si los hashes coinciden, estás usando el baseline documentado. Si difieren,
revisa los archivos antes de usarlos.

## Limitaciones conocidas

- El baseline publicado v0.1.5 se validó específicamente en Windows 11 Pro 25H2
  (referencia histórica); la referencia actual es Windows 11 Pro 26H2 (build
  base 26300). El archivo de respuestas integrado todavía no tiene una
  revalidación en instalación limpia de los últimos cambios y el standalone no
  tiene prueba runtime en anfitrión (solo validación estática más la suite de
  pruebas aislada). Otras builds de Windows 11 cliente dentro del marco admitido
  se aceptan como `NOT_RUNTIME_TESTED` y pueden requerir revalidación.
- No se incluyen drivers específicos del hardware. Prepara tú mismo los
  drivers de chipset, red, audio y GPU.
- El perfil no instala software de terceros.
- `IQuietHoursSettings`, usada para desactivar "No molestar", es una interfaz
  COM interna no documentada; puede cambiar en futuras builds de Windows.
- "No molestar" queda desactivado como estado comprobado en el momento de
  aplicar el perfil, no como garantía permanente. Windows 11 puede volver a
  activarlo mediante su activación automática (reglas disponibles en
  Configuración > Sistema > Notificaciones: determinados horarios, duplicación
  de pantalla, durante juegos, aplicaciones a pantalla completa y la primera
  hora posterior a una actualización de características de Windows; una sesión
  de concentración también lo activa automáticamente). TMPC no modifica,
  desactiva ni sobrescribe esas reglas de Windows, por lo que una reactivación
  de "No molestar" no demuestra por sí sola un fallo de TMPC. La causa concreta
  observada en un PC real no está demostrada. Para las condiciones y valores
  actuales, consulta el soporte oficial de Microsoft: "Notifications and Do Not
  Disturb in Windows"
  (https://support.microsoft.com/en-us/windows/experience/notifications-and-do-not-disturb-in-windows).
- El override por usuario de la vista de la carpeta Downloads depende del
  comportamiento actual de Windows y no es una API pública; una actualización
  mayor puede eliminarlo y la tarea de un solo uso no lo reaplica
  automáticamente. Antes de copiar el FolderType, el perfil verifica el default
  instalado (`GroupBy = System.DateModified`); ese valor se verificó en la
  referencia histórica 25H2 y no se ha vuelto a verificar en 26H2. Si difiere,
  el override se omite y la discrepancia se registra como error en lugar de
  escribir una vista no verificada.
- Paint puede seguir mostrando determinados elementos o avisos relacionados
  con IA aunque sus políticas de IA se apliquen; no se logró una interfaz de
  Paint totalmente limpia de IA. En la instalación de prueba, Notepad no mostró
  funciones de IA visibles.
- Una anomalía visual histórica del primer inicio de sesión (barra de tareas y
  fondo claros hasta un cierre y apertura de sesión) no se reprodujo en el
  baseline actual; su causa sigue sin confirmarse.
- El par de política de pins de Inicio del archivo de respuestas actual (diseño
  vacío persistente con `applyOnce`, aplicado en el siguiente inicio de sesión)
  se validó manualmente en Windows 11 26H2; el archivo de respuestas integrado
  todavía requiere una validación de inicio de sesión en instalación limpia, y
  preparar la política no demuestra por sí solo un menú Inicio vacío. Los
  iconos de la barra de tareas son independientes de los pins de Inicio.
- La política de máquina `DisableCloudOptimizedContent` (añadida para evitar
  anclajes promocionales en la barra de tareas, como el marcador de Outlook
  para Windows, en perfiles nuevos) desactiva globalmente el contenido
  optimizado en la nube: el contenido personalizado y los fondos de Windows
  Spotlight dejan de estar disponibles, aunque se pueden fijar fondos
  estáticos. No elimina anclados que ya existan. La referencia CSP lista la
  opción para ediciones Enterprise/Education: no es soporte Pro documentado.
  Se comprobó visualmente con un usuario local genuinamente nuevo en Windows 11
  Pro 26H2 (Outlook no anclado; Edge, Explorador de archivos y Microsoft Store
  conservados; sección Pinned vacía). La validación integrada en instalación
  limpia y la cobertura de efectos secundarios siguen pendientes; el baseline
  histórico 25H2 no incluía esta política, y el par ADMX de pins de Inicio
  conserva su validación manual previa en 26H2.
- La vista inicial Lista de Todas las aplicaciones es una preferencia de
  usuario `AllAppsViewMode` (DWord 2) escrita durante la fase de personalización
  de usuario del primer inicio de sesión y solo si el valor no existe; nunca se
  sobrescribe una preferencia previa y el ajuste puede cambiarse después a
  Cuadrícula o Categoría. En un perfil existente de Windows 11 Pro 26H2, cambiar
  el valor manualmente y cerrar y abrir sesión mostró la vista Lista
  (`RUNTIME_EXISTING_PROFILE = PASS`), con Categoría y Cuadrícula todavía
  disponibles. La aplicación automática por una instalación limpia
  (`CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED`) y el runtime del standalone
  (`STANDALONE_RUNTIME = NOT_TESTED`) no se han probado; el comportamiento en
  otras builds, incluida la referencia histórica 25H2, tampoco.
  `AllAppsViewMode` es un comportamiento observado del Registro, no una
  interfaz documentada y soportada por Microsoft.

## Estructura del repositorio

```text
README.md
README.es.md
LICENSE
THIRD_PARTY_NOTICES.md
autounattend.xml
Apply-TMPCOptimizations.ps1
ventoy.json
.gitattributes
docs/
  preparacion-previa-instalacion.md
  pre-installation-preparation.md
  configuracion-pruebas-limitaciones-fuentes.md
  configuration-testing-limitations-sources.md
  comprobaciones-posteriores-instalacion.md
  post-installation-checks.md
scripts/
  validate-baseline.ps1
  tests/
    TMPC.Tests.Helpers.ps1
    Invoke-TMPCTests.ps1
```

Archivos principales:

- `autounattend.xml`: automatización y perfil de personalización de la
  instalación.
- `Apply-TMPCOptimizations.ps1`: vía post-install independiente Full / UserOnly.
- `ventoy.json`: configuración de Ventoy que enlaza la ISO con el archivo de
  respuestas.
- `.gitattributes`: política de finales de línea del repositorio.
- `LICENSE`: licencia del proyecto (MIT).
- `THIRD_PARTY_NOTICES.md`: avisos de copyright y licencia de los componentes
  de terceros.
- `scripts/validate-baseline.ps1`: validador estático local de solo lectura.
- `scripts/tests/`: pruebas automatizadas aisladas con dobles en memoria; nunca
  tocan el Registro, el sistema de archivos ni los procesos del anfitrión.

## Validación estática local

El repositorio incluye un validador estático de solo lectura:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
```

Comprueba la estructura del repositorio, que el XML esté bien formado y su
arquitectura, la sintaxis del PowerShell embebido, `ventoy.json`, los hashes
documentados, los finales de línea y los enlaces de la documentación. También
parsea el standalone y comprueba su vínculo fuente, inventarios del perfil,
motor de Registro idempotente, preflight de compatibilidad por capas y
protecciones estáticas críticas. Nunca ejecuta ninguno de los optimizadores ni
sustituye una prueba runtime controlada.

Las pruebas automatizadas aisladas ejecutan la misma lógica con dobles en
memoria y nunca tocan el Registro, el sistema de archivos ni los procesos del
anfitrión:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\Invoke-TMPCTests.ps1
```

## Documentación técnica

Documentos de referencia avanzada:

- [`docs/preparacion-previa-instalacion.md`](docs/preparacion-previa-instalacion.md):
  preparación previa a la instalación, backups y lista de drivers.
- [`docs/configuracion-pruebas-limitaciones-fuentes.md`](docs/configuracion-pruebas-limitaciones-fuentes.md):
  configuración aplicada, estado de validación, limitaciones y fuentes.
- [`docs/comprobaciones-posteriores-instalacion.md`](docs/comprobaciones-posteriores-instalacion.md):
  comprobación detallada de hardware y del sistema después de instalar.

Ningún paso imprescindible para instalar el perfil existe únicamente en esos
documentos; este README es autosuficiente.

## Fuentes y licencias

- TMPC Windows 11 Optimization se distribuye bajo la licencia MIT.
  Copyright (c) 2026 Alvaro-TMPC. Consulta [LICENSE](LICENSE).
- Los componentes de terceros conservan sus propios avisos de copyright y
  licencia; consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Parte de `autounattend.xml` deriva de, o se basa en, código distribuido en
  [memstechtips/UnattendedWinstall](https://github.com/memstechtips/UnattendedWinstall)
  (revisión de referencia `cca752363772a845eb0fed9d3a5b89b5d0a10d20`, licencia
  MIT, Copyright (c) 2025 Marco du Plessis). Esto incluye `BloatRemoval.ps1`
  (versión 2.3), `OneDriveRemoval.ps1` (versión 1.2, endurecido localmente en el
  perfil TMPC) y lógica auxiliar/automatización relacionada. El perfil local ha
  sido modificado y ampliado para este proyecto.
- El archivo de respuestas conserva la atribución histórica
  <https://github.com/memstechtips/Autounattend> presente en esos scripts; la
  referencia canónica usada para licencias y trazabilidad de esta release es
  <https://github.com/memstechtips/UnattendedWinstall>.
