# TMPC Windows 11 Optimization

Este repositorio contiene una configuración reproducible para instalar y
personalizar Windows 11, con foco en:

- privacidad;
- reducción conservadora de bloatware;
- gaming;
- programación;
- mantenibilidad;
- evitar tweaks agresivos o poco justificables.

Plataforma objetivo actual: Windows 11 25H2, x64 / amd64.

## Estado actual

La configuración sigue en desarrollo y no es una versión release final.

El `autounattend.xml` actual, con la corrección de "No molestar", ha completado
una instalación limpia real en Windows 11 Pro 25H2 sobre un equipo de prueba
desechable:

- instalación, OOBE y llegada al escritorio sin errores bloqueantes;
- sin prompt obligatorio de red ni de cuenta Microsoft;
- particionado GPT/EFI creado automáticamente por Setup;
- "No molestar" desactivado tras la instalación, con el interruptor modificable
  y reactivable manualmente;
- cleanup final del perfil completado.

Esa instalación confirma la corrección de "No molestar" basada en la interfaz
COM interna `IQuietHoursSettings`, con la escritura directa del blob de
CloudStore únicamente como fallback.

El candidato actual, que añade la corrección del registro del cleanup (Branch A)
y las preferencias de File Explorer con el override de Downloads, también ha
completado una instalación limpia real en el mismo equipo de prueba, sin
instrumentación de prueba en el medio:

- ruta normal de F2 completa: one-shot retirada y verificada, cleanup registrado
  y verificado, marcador eliminado, reinicio automático y cleanup final sin
  residuos de Autounattend;
- preferencias de Explorer aplicadas en Registro y agrupación validada
  visualmente: las carpetas normales conservan "Agrupar por = Ninguno" de forma
  nativa y Downloads no agrupa mediante el override, manteniendo el estado tras
  cerrar y reabrir el Explorador.

El recorrido de recuperación de F2 quedó observado previamente en runtime
mediante una prueba controlada con inyección de fallo.

La anomalía histórica de primer logon (barra y fondo visualmente claros hasta un
logoff/logon) no se reprodujo en la instalación del candidato actual; su causa
sigue sin comprobarse y no se declara resuelta.

Comprobado estáticamente:

- `autounattend.xml` bien formado.
- Componentes objetivo únicamente `amd64`.
- PowerShell embebido analizado sintácticamente sin errores:
  - `SystemCustomizations.ps1`;
  - `BloatRemoval.ps1`;
  - `OneDriveRemoval.ps1`.
- `ventoy.json` válido.
- Hallazgos F1, F2 y F3 de la auditoría interna corregidos y comprobados
  estáticamente.

Pendiente:

- revisión de los hallazgos F4 y posteriores de la auditoría;
- efectividad completa de las funciones de IA de Paint (Notepad quedó sin
  funciones de IA visibles en la prueba real);
- auditoría de fuentes, licencias y atribuciones antes de la publicación
  pública;
- versionado o tag del baseline probado.

Una validación estática no equivale a una instalación real, y una instalación
limpia correcta en un equipo de prueba no convierte este baseline en una
versión release ni garantiza compatibilidad con otras versiones, ediciones o
builds de Windows 11.

## Archivos principales

- `autounattend.xml`: automatización y personalización de la instalación de
  Windows 11.
- `ventoy.json`: configuración de Ventoy para seleccionar el XML de
  instalación.
- `.gitattributes`: política reproducible de finales de línea.
- `README.md`: documentación principal.

## Documentación

- [`docs/preparacion-previa-instalacion.md`](docs/preparacion-previa-instalacion.md):
  comprobaciones previas al formateo, backups y preparación de drivers.
- [`docs/configuracion-pruebas-limitaciones-fuentes.md`](docs/configuracion-pruebas-limitaciones-fuentes.md):
  configuración aplicada, estado de validación, limitaciones y fuentes.

## Validación estática local

El repositorio incluye un validador local de solo lectura:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
```

Comprueba la estructura del repositorio, la sintaxis del XML y del PowerShell
embebido, `ventoy.json`, los hashes documentados, los finales de línea y la
coherencia documental. No ejecuta los scripts embebidos y no sustituye una
instalación limpia real.

## Decisiones principales del perfil

- Microsoft Defender conservado.
- Windows Update conservado.
- Microsoft Store conservada.
- Edge y WebView2 conservados por compatibilidad.
- Microsoft Photos conservada.
- Paint y Notepad conservados. Notepad quedó sin funciones de IA visibles en la
  prueba real; en Paint las políticas de IA se aplican, pero la interfaz
  todavía muestra opciones o avisos relacionados con IA, por lo que su limpieza
  completa sigue pendiente.
- OneDrive eliminado y bloqueado, conservando los datos del usuario.
- Game Mode activado.
- Game DVR desactivado.
- Plan de energía Balanced.
- Hibernación y Fast Startup desactivados.
- Efectos de transparencia desactivados.
- UAC con comportamiento normal y Secure Desktop.
- Print Spooler conservado.
- Bloqueo de Windows conservado.
- Drivers mediante Windows Update excluidos.
- Sin optimizaciones agresivas de CPU, GPU, scheduler o red.

## Advertencia de uso

`autounattend.xml` puede modificar de forma amplia una instalación de Windows.
Debe revisarse antes de utilizarse, y se recomienda probarlo primero en una
máquina de prueba o en un entorno desechable.

El perfil no automatiza la selección ni la destrucción de discos. Antes de una
instalación real deben prepararse los backups y los drivers necesarios.

## Estructura prevista

```text
README.md
autounattend.xml
ventoy.json
.gitattributes
docs/
  preparacion-previa-instalacion.md
  configuracion-pruebas-limitaciones-fuentes.md
scripts/
  validate-baseline.ps1
```

## Licencias y fuentes

La licencia definitiva del repositorio todavía no está definida. La revisión de
fuentes, licencias y atribuciones de todos los componentes está pendiente antes
de cualquier publicación pública.
