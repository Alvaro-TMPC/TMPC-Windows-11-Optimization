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

La configuración sigue en desarrollo. El `autounattend.xml` exacto que está
versionado todavía no ha sido validado mediante una instalación limpia
completa.

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

- instalación limpia del `autounattend.xml` exacto actualmente versionado;
- validación funcional completa posterior a esa instalación;
- revisión de los hallazgos F4 y posteriores de la auditoría;
- auditoría de fuentes, licencias y atribuciones antes de la publicación
  pública.

Una validación estática no equivale a una instalación real validada. El
baseline actual no está probado en instalación limpia.

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
- Paint y Notepad conservados; existen políticas configuradas para desactivar
  sus funciones de IA, cuya efectividad real sigue pendiente de validación.
- OneDrive eliminado y bloqueado, conservando los datos del usuario.
- Game Mode activado.
- Game DVR desactivado.
- Plan de energía Balanced.
- Hibernación y Fast Startup desactivados.
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
