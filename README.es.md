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

Plataforma objetivo: Windows 11 25H2, x64 / amd64.

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
- "No molestar" se configura desactivado;
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

El baseline ha completado instalaciones limpias reales en Windows 11 Pro 25H2
(x64 / amd64), incluyendo:

- instalación, OOBE y llegada al primer escritorio sin errores bloqueantes;
- creación de cuenta local sin prompt obligatorio de red ni de cuenta
  Microsoft;
- personalizaciones de usuario aplicadas mediante una tarea de un solo uso;
- reinicio automático ejecutado por el perfil y llegada al escritorio final;
- cleanup final completado, sin tareas de instalación ni archivos temporales
  residuales;
- valores de Explorer y override de la vista de Downloads verificados.

Otras versiones, ediciones o builds de Windows 11 no están garantizadas.
Builds futuras pueden requerir revalidación.

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
   ├── Win11_25H2_Spanish_x64_v2.iso
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
     `Win11_25H2_Spanish_x64_v2.iso`.

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
   Selecciona `Win11_25H2_Spanish_x64_v2.iso`. Ventoy muestra entonces el menú
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
70D5DA63FEA8078FDA45F8F20FCA82E4A476060DDB5304EDEB3DA8A21CC95FF6

ventoy.json
2231E01E9B0BA0622888D97EFEDA0F476DBD73A9CB90B11B48656E1F889F2796
```

Verifícalos en tu copia:

```powershell
Get-FileHash -Algorithm SHA256 .\autounattend.xml, .\ventoy.json
```

Si los hashes coinciden, estás usando el baseline documentado. Si difieren,
revisa los archivos antes de usarlos.

## Limitaciones conocidas

- Validado específicamente en Windows 11 25H2. La compatibilidad con otras
  versiones, ediciones o builds no está probada; builds futuras pueden
  requerir revalidación.
- No se incluyen drivers específicos del hardware. Prepara tú mismo los
  drivers de chipset, red, audio y GPU.
- El perfil no instala software de terceros.
- `IQuietHoursSettings`, usada para desactivar "No molestar", es una interfaz
  COM interna no documentada; puede cambiar en futuras builds de Windows.
- El override por usuario de la vista de la carpeta Downloads depende del
  comportamiento actual de Windows y no es una API pública; una actualización
  mayor puede eliminarlo y la tarea de un solo uso no lo reaplica
  automáticamente.
- Paint puede seguir mostrando determinados elementos o avisos relacionados
  con IA aunque sus políticas de IA se apliquen; no se logró una interfaz de
  Paint totalmente limpia de IA. En la instalación de prueba, Notepad no mostró
  funciones de IA visibles.
- Una anomalía visual histórica del primer inicio de sesión (barra de tareas y
  fondo claros hasta un cierre y apertura de sesión) no se reprodujo en el
  baseline actual; su causa sigue sin confirmarse.

## Estructura del repositorio

```text
README.md
README.es.md
LICENSE
THIRD_PARTY_NOTICES.md
autounattend.xml
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
```

Archivos principales:

- `autounattend.xml`: automatización y perfil de personalización de la
  instalación.
- `ventoy.json`: configuración de Ventoy que enlaza la ISO con el archivo de
  respuestas.
- `.gitattributes`: política de finales de línea del repositorio.
- `LICENSE`: licencia del proyecto (MIT).
- `THIRD_PARTY_NOTICES.md`: avisos de copyright y licencia de los componentes
  de terceros.
- `scripts/validate-baseline.ps1`: validador estático local de solo lectura.

## Validación estática local

El repositorio incluye un validador estático de solo lectura:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
```

Comprueba la estructura del repositorio, que el XML esté bien formado y su
arquitectura, la sintaxis del PowerShell embebido, `ventoy.json`, los hashes
documentados, los finales de línea y los enlaces de la documentación. Nunca
ejecuta los scripts embebidos y no sustituye una instalación limpia real.

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
  (versión 2.3), `OneDriveRemoval.ps1` (versión 1.2) y lógica
  auxiliar/automatización relacionada. El perfil local ha sido modificado y
  ampliado para este proyecto.
- El archivo de respuestas conserva la atribución histórica
  <https://github.com/memstechtips/Autounattend> presente en esos scripts; la
  referencia canónica usada para licencias y trazabilidad de esta release es
  <https://github.com/memstechtips/UnattendedWinstall>.
