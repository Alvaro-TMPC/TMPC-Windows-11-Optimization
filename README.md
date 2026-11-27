# TMPC Windows 11 Optimization

**Español** | [English](README.en.md)

Un perfil reproducible para instalar Windows 11 desde cero u optimizar una
instalación existente. Reduce el bloatware de forma conservadora, refuerza la
privacidad y mantiene el sistema preparado para gaming, programación y uso
diario. No tiene interfaz gráfica, no instala software de terceros y no usa
comandos remotos de instalación.

## Características principales

- **Privacidad:** telemetría mínima, identificador de publicidad y experiencias
  personalizadas desactivados; actividad en la nube, portapapeles entre
  dispositivos y acceso a ubicación bloqueados; Copilot y acceso a modelos de
  IA en el dispositivo desactivados.
- **Debloat conservador:** elimina apps de consumo y componentes heredados,
  pero conserva Microsoft Defender, Microsoft Store, Edge/WebView2, Photos,
  Paint y Notepad.
- **Windows funcional:** Windows Update y Defender activos, drivers de Windows
  Update excluidos, Store disponible y OneDrive eliminado sin borrar los datos
  existentes de `%USERPROFILE%\OneDrive`.
- **Gaming y energía:** Game Mode activado, Game DVR y servicios de Xbox Live
  desactivados, plan Balanced e hibernación/Fast Startup desactivados.
- **Interfaz:** tema oscuro, transparencia desactivada, Explorer con extensiones
  y archivos ocultos visibles, menú contextual clásico, Downloads sin agrupar
  por fecha y menú Inicio sin anclajes promocionales en perfiles nuevos.
- **Sin tweaks arriesgados:** no se modifican CPU, GPU, planificador ni red sin
  una necesidad demostrada.

## Requisitos y compatibilidad

- Plataforma objetivo: Windows 11 Pro 26H2, x64 / amd64 (build base 26300; la
  revisión del sistema/UBR no está fijada).
- Instalación por UEFI/amd64 con una ISO genuina de Windows 11 x64 y un USB que
  puedas borrar.
- El baseline publicado v0.1.5 se validó en Windows 11 Pro 25H2 como referencia
  histórica; esa evidencia no se atribuye a 26H2.
- El optimizador postinstalación requiere Windows 11 cliente (build 22000 o
  posterior), Windows PowerShell 5.1 AMD64 nativo y una cuenta de usuario real.
  El modo completo necesita consola elevada.
- Windows Server, Windows 10 o familias anteriores y hosts no AMD64/32 bits no
  son compatibles.
- No se incluyen drivers ni software de terceros: prepáralos tú antes de
  formatear.

## Dos modos de utilización

### Instalación limpia con Ventoy

1. Prepara backups verificados, drivers y una ISO genuina de Windows 11.
2. Crea el USB con [Ventoy](https://www.ventoy.net/) y copia `ventoy.json` en
   `\ventoy\ventoy.json` y `autounattend.xml` en
   `\ventoy\script\autounattend.xml`.
3. Arranca el USB, elige la ISO y selecciona
   `Boot with /ventoy/script/autounattend.xml`.
4. Instala Windows y elige manualmente el disco de destino. El perfil no
   selecciona ni borra discos.

El procedimiento completo, la estructura del USB, Windows Setup, DiskPart, el
primer inicio de sesión y el reinicio automático están en la
**[guía completa en español](docs/guia-completa.md)**.

### Optimización postinstalación

Para un Windows 11 ya instalado, usa el script autocontenido
[`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1). No formatea ni
cambia discos, cuentas o licencias.

```powershell
# Modo completo, desde Windows PowerShell como administrador
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1
```

```powershell
# Solo preferencias del usuario actual, sin elevación
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -UserOnly
```

Revisa el script y haz un backup antes de ejecutarlo. Los parámetros, la matriz
de cobertura, los logs y los códigos de salida están en la
**[guía completa](docs/guia-completa.md#aplicar-las-optimizaciones-a-una-instalación-de-windows-existente)**.

## Descarga

La última versión estable es **v0.3.0**, disponible en la
[release estable v0.3.0](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases/tag/v0.3.0).
La prerelease **v0.4.0-rc.1**, publicada el 27 de noviembre de 2026, está en la
[release v0.4.0-rc.1](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases/tag/v0.4.0-rc.1).

Ambas releases publican cuatro assets descargables con los mismos nombres:
`autounattend.xml`, `ventoy.json`, `Apply-TMPCOptimizations.ps1` y
`SHA256SUMS.txt`. Los assets de `v0.3.0` son inmutables y conservan sus hashes
históricos; los de `v0.4.0-rc.1` tienen hashes propios. Verifica cada descarga
con `SHA256SUMS.txt`; no hay instalador ejecutable ni comando remoto del tipo
`irm ... | iex`.

## Advertencia esencial

- **Haz un backup completo y comprueba que se puede leer.** Una instalación
  limpia puede destruir datos de forma irreversible y no existe rollback
  automático.
- **El disco lo eliges tú.** El perfil no selecciona ni borra discos; confirma
  el disco y las particiones antes de continuar.
- **Revisa el archivo de respuestas** antes de usarlo. Tú eres responsable de
  lo que se aplique en tu equipo.
- **Prueba primero en una máquina virtual o desechable** si puedes.
- OneDrive se elimina, pero el contenido existente en
  `%USERPROFILE%\OneDrive` se conserva. Los archivos solo en línea no son
  copias locales respaldadas.

## Estado de validación

- BUILD publicado de `v0.4.0-rc.1` (commit `ca3ba37`): **73 pruebas aisladas
  OK / 0 FAIL** y **416 comprobaciones estáticas OK / 0 FAIL**.
- Runtime del candidato exacto `v0.4.0-rc.1`: **NOT_TESTED**. No se ha
  ejecutado una instalación limpia ni el optimizador sobre el anfitrión.
- Evidencia runtime histórica: baseline v0.1.5 en Windows 11 Pro 25H2.
- El validador estático y las pruebas aisladas no equivalen a una ejecución
  real; no se declara `RUNTIME_PASS` para `v0.3.0` ni para `v0.4.0-rc.1`.
- La validación runtime N4 queda aplazada por decisión del usuario
  (`N4_RUNTIME_VALIDATION = DEFERRED_BY_USER`).

## Documentación completa

- **[Guía completa en español](docs/guia-completa.md)** y
  **[full guide in English](docs/full-guide.md)**: instalación, modos, matriz
  de cobertura, hashes, limitaciones y fuentes.
- [Preparación previa a la instalación](docs/preparacion-previa-instalacion.md)
  y [Pre-installation preparation](docs/pre-installation-preparation.md).
- [Configuración, pruebas, limitaciones y fuentes](docs/configuracion-pruebas-limitaciones-fuentes.md)
  y [Configuration, testing, limitations and sources](docs/configuration-testing-limitations-sources.md).
- [Comprobaciones posteriores a la instalación](docs/comprobaciones-posteriores-instalacion.md)
  y [Post-installation checks](docs/post-installation-checks.md).
- [README.es.md](README.es.md): página de compatibilidad para enlaces
  antiguos. GitHub no redirige automáticamente enlaces ni anclas.

## Licencia MIT

TMPC Windows 11 Optimization se distribuye bajo la licencia MIT.
Copyright (c) 2026 Alvaro-TMPC. Consulta [LICENSE](LICENSE) y los avisos de
terceros en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
