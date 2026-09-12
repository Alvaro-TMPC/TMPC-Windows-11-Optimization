# Comprobaciones posteriores a la instalación

Esta guía también está disponible en inglés:
[Post-installation checks](post-installation-checks.md).

Esta guía reúne las comprobaciones que puedes hacer después de instalar TMPC
Windows 11 Optimization: desde el escritorio final hasta una prueba breve de
estabilidad. Cubre Windows, drivers, la GPU y su enlace PCIe, el monitor, la
RAM, el almacenamiento, el comportamiento prometido por el baseline TMPC y
los periféricos principales.

Se da por supuesto que la instalación ya ha terminado: has llegado al
escritorio final, ha ocurrido el reinicio automático programado por el perfil
y ha finalizado el cleanup normal. La instalación del perfil se documenta en
el [README en español](../README.es.md).

Ten en cuenta:

- no todas las comprobaciones aplican a todos los equipos; omite las que no
  correspondan a tu hardware o a tu caso de uso;
- un resultado distinto de un ejemplo de esta guía no implica automáticamente
  un fallo; compara siempre el resultado con las especificaciones reales de
  tu GPU, CPU, placa base, RAM, almacenamiento y monitor;
- esta guía solo explica cómo comprobar. El perfil no configura los ajustes
  de firmware o hardware que se mencionan aquí: carriles PCIe, Resizable BAR,
  frecuencia de actualización, XMP/EXPO, Secure Boot, drivers ni firmware.

## Niveles de prioridad

- **Obligatorio**: requisito básico de instalación o de uso.
- **Recomendado**: reduce riesgo o trabajo posterior; puede omitirse con una
  justificación consciente.
- **Opcional**: útil solo en algunos equipos o para algunos usuarios.
- **Solo si hay problemas**: pasos de diagnóstico que no forman parte de la
  checklist normal y solo deben usarse cuando existe un síntoma.

## 1. Punto de partida

Realiza estas comprobaciones después de:

- alcanzar el escritorio final;
- el reinicio automático programado por el perfil (el sistema muestra un
  aviso de unos 20 segundos);
- completar el cleanup normal del perfil. Los archivos temporales de la
  instalación y las tareas de un solo uso se eliminan automáticamente; el
  README describe el flujo esperado.

Un resultado de ejemplo en esta guía es ilustrativo, no un objetivo universal.
Las diferencias de hardware (modelo de GPU, generación PCIe, número de
carriles, kit de memoria, monitor, infraestructura de red) pueden producir
resultados distintos y perfectamente correctos.

## 2. Windows, red y drivers

- [ ] **Obligatorio**: comprueba que la conectividad Ethernet y/o Wi-Fi
      funciona. Si los adaptadores aparecen desactivados después de la
      instalación, actívalos desde Configuración de Windows o el
      Administrador de dispositivos.
- [ ] **Obligatorio**: abre el Administrador de dispositivos y comprueba que
      no hay dispositivos desconocidos ni iconos de aviso. Un dispositivo
      puede seguir mostrando aviso hasta que se instale su driver OEM;
      vuelve a revisarlo tras instalar los drivers.
- [ ] **Obligatorio**: instala los drivers OEM/oficiales que preparaste antes
      de la instalación: chipset, Ethernet, Wi-Fi, audio, GPU y Bluetooth,
      además de cualquier otro dispositivo específico de tu equipo, cuando
      aplique.
- [ ] **Obligatorio**: ejecuta Windows Update con normalidad para instalar
      actualizaciones de calidad y seguridad. Recuerda que este perfil
      excluye los drivers distribuidos mediante Windows Update; los drivers
      de hardware se instalan aparte.
- [ ] **Opcional**: si tienes previsto activar Windows, revisa Configuración
      > Sistema > Activación. La clave de producto del archivo de respuestas
      es un marcador de posición, no una licencia.

Instala los drivers desde el fabricante de tu hardware o de tu equipo. Este
proyecto no recomienda herramientas de terceros de actualización automática
de drivers.

## 3. GPU y enlace PCIe (GPU-Z)

**Utilidad opcional y de terceros.** GPU-Z es una utilidad gratuita publicada
por TechPowerUp que muestra información detallada de la tarjeta gráfica y de
su enlace PCIe. Este proyecto no está afiliado con TechPowerUp, no
redistribuye GPU-Z y no lo incluye como dependencia. Si quieres usarla,
descárgala desde su sitio oficial:
<https://www.techpowerup.com/gpuz/>.

### Bus Interface: capacidad máxima y enlace actual

El campo `Bus Interface` muestra dos cosas distintas:

- el enlace máximo que soporta la tarjeta, por ejemplo `PCIe x16 4.0`;
- el enlace negociado en ese momento, que aparece después de la `@`, por
  ejemplo `@ x16 3.0`.

Una GPU NO tiene que funcionar siempre a PCIe x16. El ancho y la generación
efectivos dependen de:

- el diseño de la propia GPU: algunos modelos usan x8 por diseño y otros x16;
- la CPU, la placa base y la ranura concreta que se usa (una ranura
  físicamente larga puede ser eléctricamente x8 o x4);
- la plataforma: algunas placas comparten carriles entre la ranura PCIe
  principal y ranuras M.2 u otros dispositivos.

Las funciones de ahorro energético pueden reducir la velocidad o generación
negociada del enlace PCIe mientras la GPU está en reposo. El número de
carriles (x16, x8 o x4) depende del diseño de la GPU, la CPU, la placa base,
la ranura utilizada y el reparto de líneas de la plataforma; una reducción
del número de carriles no es el comportamiento normal del ahorro energético.
Comprueba siempre el enlace bajo carga antes de diagnosticar un problema:

1. abre GPU-Z;
2. inicia el test de renderizado asociado al campo `Bus Interface`;
3. observa el enlace negociado mientras se ejecuta la prueba.

Ejemplo (solo ilustrativo, **no es un objetivo universal**):

```text
En reposo:  PCIe x16 4.0 @ x16 1.1
Bajo carga: PCIe x16 4.0 @ x16 4.0
```

Esos valores NO son un requisito. Una tarjeta PCIe 4.0 x8 funcionando a x8
puede ser perfectamente correcta; no diagnostiques un problema solo porque no
aparezca x16. Compara el resultado con las especificaciones de tu GPU, de tu
CPU y de tu placa base, y con la ranura que estés usando realmente.

### Resizable BAR

- [ ] **Opcional**: comprueba Resizable BAR si tu GPU y tu plataforma lo
      soportan. GPU-Z muestra si está habilitado y ofrece información
      detallada. No es un requisito universal: la compatibilidad y el
      comportamiento dependen de la GPU, la placa base y el firmware.

No cambies ajustes de BIOS/UEFI automáticamente porque un valor no coincida
con un ejemplo. Consulta primero la documentación de tu GPU, tu CPU y tu
placa base.

## 4. Monitor

- [ ] **Obligatorio**: configura la resolución nativa del monitor.
- [ ] **Obligatorio**: configura una frecuencia de actualización compatible
      con el monitor (Configuración > Sistema > Pantalla > Pantalla
      avanzada). Un error habitual tras una instalación limpia es quedarse
      accidentalmente a 60 Hz en un monitor que soporta más.
- [ ] **Recomendado**: usa una escala de Windows razonable (100 %, 125 %,
      150 %...) para que el texto y las ventanas sean cómodos en la
      resolución elegida.
- [ ] **Opcional**: activa HDR solo si tu monitor y tu uso se benefician de
      ello.
- [ ] **Opcional**: activa VRR / FreeSync / G-SYNC cuando tu monitor y tu GPU
      lo soporten.
- [ ] **Recomendado**: comprueba que el monitor está conectado a la GPU que
      pretendes utilizar. En un PC de sobremesa convencional orientado a
      gaming con GPU dedicada, normalmente se usan las salidas de la GPU
      dedicada. Los portátiles, los sistemas híbridos/muxless y las
      configuraciones multi-GPU pueden funcionar de otra manera, así que una
      salida de vídeo de la placa base no es incorrecta de forma universal.

El perfil no configura ninguno de estos ajustes; esta guía solo muestra cómo
comprobarlos y ajustarlos. No existe una combinación correcta única: HDR, VRR
y una frecuencia determinada dependen de tu hardware y de tus preferencias.

## 5. RAM

- [ ] **Obligatorio**: comprueba que Windows reconoce toda la memoria
      instalada (Administrador de tareas > Rendimiento > Memoria).
- [ ] **Recomendado**: comprueba los módulos y ranuras instalados, y la
      capacidad total.
- [ ] **Recomendado**: comprueba la velocidad/data rate configurada de la
      memoria. El Administrador de tareas y
      `Get-CimInstance Win32_PhysicalMemory` muestran la velocidad que está
      usando Windows.
- [ ] **Opcional**: comprueba el channel mode (single/dual/quad) solo cuando
      el firmware o una herramienta adecuada de tu plataforma lo informe.
- [ ] **Opcional**: comprueba XMP/EXPO solo si esperabas utilizarlo. XMP/EXPO
      es un perfil de firmware (BIOS/UEFI) de la placa base; no es un ajuste
      de TMPC.

Comprobación de solo lectura:

```powershell
Get-CimInstance Win32_PhysicalMemory |
  Select-Object BankLabel, DeviceLocator, Capacity, Speed, ConfiguredClockSpeed
```

`Get-CimInstance Win32_PhysicalMemory` sirve para inventariar los módulos
instalados y consultar `Speed` y `ConfiguredClockSpeed`, pero no debe
presentarse como prueba fiable del modo single/dual/quad channel; ese modo lo
informa el firmware o una herramienta adecuada de la plataforma.

No existe una frecuencia de memoria universalmente correcta: compara la
velocidad/data rate configurada de la memoria con las especificaciones de tu
CPU, tu placa base y tu kit de memoria. El data rate de la memoria DDR suele
expresarse en MT/s aunque algunas herramientas lo etiqueten como MHz; no
confundas la frecuencia real con el data rate DDR. Si la memoria funciona por
debajo de su velocidad nominal y esperabas usar XMP/EXPO, revisa ese ajuste
en el firmware. No apliques overclock manual.

## 6. Almacenamiento y arranque

- [ ] **Obligatorio**: comprueba que aparecen todas las unidades SSD/HDD
      esperadas, con su capacidad aproximada (Administrador de tareas >
      Rendimiento, o Administración de discos).
- [ ] **Recomendado**: comprueba el estado de salud de las unidades cuando el
      sistema pueda informarlo.
- [ ] **Obligatorio**: confirma que la instalación objetivo sigue el flujo
      UEFI/GPT documentado. En Windows, `msinfo32` muestra el `Modo de BIOS`
      en el Resumen del sistema y la Administración de discos muestra el
      estilo de partición (GPT para el flujo documentado).
- [ ] **Recomendado**: comprueba que TRIM está habilitado en los SSD.

Comprobaciones de solo lectura desde PowerShell:

```powershell
Get-PhysicalDisk |
  Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus
Get-Disk |
  Select-Object Number, FriendlyName, PartitionStyle, BusType
Get-Volume |
  Select-Object DriveLetter, FileSystem, HealthStatus, Size, SizeRemaining
```

Comprobación de TRIM:

```text
fsutil behavior query DisableDeleteNotify
```

Para NTFS, `DisableDeleteNotify = 0` significa que las notificaciones de
borrado (TRIM) están habilitadas; un valor de 1 significa que están
deshabilitadas. Esta comprobación informa del ajuste de Windows, no del
estado físico de la unidad: no es una prueba absoluta de salud del SSD. Para
más detalle, usa el estado que informe la propia unidad y, si lo necesitas,
la herramienta de su fabricante.

No uses benchmarks destructivos ni escrituras intensivas como paso
obligatorio; no son necesarios para validar una instalación normal.

## 7. Checklist del baseline TMPC

Esta checklist comprueba el comportamiento prometido por el perfil. Es una
versión detallada de la lista rápida del README.

Seguridad y actualizaciones:

- [ ] Microsoft Defender está activo.
- [ ] Seguridad de Windows no muestra avisos críticos.
- [ ] Windows Update está disponible para actualizaciones de calidad y
      seguridad. Las actualizaciones de drivers distribuidas mediante
      Windows Update siguen excluidas.

Componentes conservados:

- [ ] Microsoft Store abre.
- [ ] Edge y WebView2 están presentes.
- [ ] Microsoft Photos está presente.
- [ ] Paint está presente.
- [ ] Notepad está presente.

Componentes eliminados:

- [ ] OneDrive no está instalado.

Gaming y energía:

- [ ] Game Mode está activado (Configuración > Juegos > Modo de juego).
- [ ] Game DVR está desactivado (Configuración > Juegos > Capturas).
- [ ] El plan de energía activo es Balanced (Equilibrado).
- [ ] La hibernación está desactivada.
- [ ] Fast Startup (Inicio rápido) está desactivado.

Interfaz:

- [ ] "No molestar" está desactivado.
- [ ] Los efectos de transparencia están desactivados.
- [ ] El tema por defecto es oscuro.

File Explorer:

- [ ] La vista compacta está activada.
- [ ] Las extensiones de nombre de archivo son visibles.
- [ ] Los archivos ocultos son visibles.
- [ ] Los archivos protegidos del sistema siguen ocultos ("Ocultar los
      archivos protegidos del sistema operativo" permanece activado en
      Opciones de carpeta).
- [ ] Las casillas de selección están desactivadas.

Downloads:

- [ ] Downloads abre con Agrupar por = Ninguno (sin agrupar por fecha).
- [ ] Cierra y vuelve a abrir Downloads (o el Explorador): la vista sin
      agrupación persiste.

Limitación de Paint: el perfil aplica las políticas de IA de Paint, pero
Paint puede seguir mostrando determinadas opciones o avisos relacionados con
IA. No se logró una interfaz de IA de Paint totalmente limpia, así que no
esperes que Paint esté libre de esos elementos.

## 8. Conectividad y periféricos

Comprueba, según apliquen a tu equipo:

- [ ] **Obligatorio**: Ethernet funciona.
- [ ] **Recomendado**: si el adaptador Ethernet es 2.5/5/10 GbE, comprueba
      la velocidad de enlace negociada. Debe corresponder a la
      infraestructura de la que dispones. No esperes la velocidad máxima
      teórica si el switch, el cableado o el otro extremo no la soportan.
- [ ] **Obligatorio si usas Wi-Fi**: el Wi-Fi funciona con la banda y el
      rendimiento esperados en tu entorno.
- [ ] **Recomendado si lo usas**: el Bluetooth se empareja y funciona con tus
      dispositivos.
- [ ] **Obligatorio**: la salida de audio funciona (altavoces, auriculares,
      altavoces del monitor).
- [ ] **Recomendado**: la entrada de micrófono funciona.
- [ ] **Recomendado**: la webcam funciona.
- [ ] **Recomendado**: los puertos USB que usas enumeran sus dispositivos.
- [ ] **Opcional**: los mandos de juego funcionan.
- [ ] **Opcional**: las impresoras y los escáneres funcionan.
- [ ] **Opcional**: los periféricos especiales (tarjetas capturadoras,
      interfaces de audio, tabletas gráficas, volantes...) funcionan con los
      drivers de su fabricante.

## 9. Seguridad y firmware

- [ ] **Obligatorio**: Microsoft Defender está activo y Seguridad de Windows
      no muestra alertas críticas.
- [ ] **Obligatorio**: el Firewall de Windows está habilitado para las redes
      activas.
- [ ] **Solo si aplica**: comprueba el estado de TPM y Secure Boot si tu
      hardware y tu política los utilizan. `msinfo32` (Resumen del sistema) y
      `tpm.msc` muestran su estado en modo de solo lectura.

Nota: el archivo de respuestas omite las comprobaciones de TPM y Secure Boot
durante la instalación. Eso NO significa que el perfil desactive TPM o Secure
Boot: esas comprobaciones se omiten para instalar y el perfil no cambia el
estado del firmware. No cambies ajustes de firmware que no necesites.

## 10. Smoke de estabilidad

Una prueba breve y razonable es suficiente para ganar confianza:

- [ ] **Recomendado**: abre tus aplicaciones habituales y úsalas unos
      minutos.
- [ ] **Recomendado**: reproduce audio y vídeo.
- [ ] **Recomendado en un PC gaming**: ejecuta un juego o una carga 3D
      durante una sesión corta.
- [ ] **Recomendado**: observa si aparecen cuelgues, congelaciones, errores
      de driver o reinicios inesperados.
- [ ] **Opcional**: vigila las temperaturas con la herramienta de
      monitorización que prefieras. Los límites razonables dependen del
      hardware concreto, de su refrigeración y de su diseño; no hay umbrales
      universales.

Es un smoke test, no una certificación. No requiere horas de estrés,
puntuaciones de benchmarks concretos, temperaturas universales, overclock ni
undervolt.

## 11. Diagnóstico solo si hay problemas

Esta sección es independiente de la checklist normal. Úsala solo cuando
aparezca un síntoma real: cuelgues, congelaciones, errores o rendimiento
anómalo.

- Visor de eventos (`eventvwr.msc`) para localizar errores alrededor del
  momento del síntoma.
- Monitor de confiabilidad (`perfmon /rel`) para ver una línea temporal de
  fallos.
- `sfc /scannow` y `DISM /Online /Cleanup-Image /RestoreHealth` para
  comprobar archivos del sistema, desde una consola elevada.
- Diagnóstico de memoria de Windows (`mdsched.exe`) si sospechas de errores
  de memoria.
- Diagnósticos específicos de CPU, GPU, disco o red si necesitas reproducir
  y aislar el problema.
- Diagnósticos del fabricante del hardware concreto.

NO ejecutes `sfc /scannow` ni DISM como ritual obligatorio después de cada
instalación si no existe ningún síntoma. Son herramientas de diagnóstico; no
forman parte de la checklist normal posterior a la instalación.

## Véase también

- [README en español](../README.es.md): visión general del proyecto,
  instalación y resumen del baseline.
- [Preparación previa a la
  instalación](preparacion-previa-instalacion.md): backups, drivers y medio
  de instalación antes de formatear.
- [Configuración, pruebas, limitaciones y
  fuentes](configuracion-pruebas-limitaciones-fuentes.md): estado técnico del
  baseline.
