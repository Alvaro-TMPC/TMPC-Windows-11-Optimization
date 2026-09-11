# Preparación previa a una instalación limpia

Este documento es una lista de comprobación para ejecutar **antes** de arrancar
el instalador de Windows en una instalación limpia. Está orientado al perfil de
este proyecto:

- Windows 11 25H2 x64 / amd64;
- uso para gaming y programación;
- prioridad de privacidad;
- instalación limpia a partir de la automatización del repositorio.

No es un tutorial de instalación de Windows ni una guía de particionado. La
fase de instalación propiamente dicha y la validación posterior se documentan
por separado.

## Convenciones

- **Obligatorio**: no debe omitirse antes de formatear.
- **Recomendado** (o **recomendable**): reduce riesgo o trabajo posterior;
  puede omitirse con una justificación consciente.
- **Solo si es necesario** (o **solo si aplica**): depende de que el equipo o
  el usuario utilice esa función o almacene ese tipo de datos.

Las casillas se marcan cuando el punto se ha revisado y, cuando corresponda,
verificado. Una tarea de verificación no se considera completa solo por haber
copiado datos: hay que comprobar que el destino es legible.

## 1. Backup de datos

Revisar y respaldar, según corresponda a este equipo:

- [ ] **Obligatorio**: Escritorio.
- [ ] **Obligatorio**: Documentos.
- [ ] **Obligatorio**: Descargas que deban conservarse.
- [ ] **Obligatorio**: Imágenes.
- [ ] **Obligatorio**: Vídeos.
- [ ] **Obligatorio**: Música.
- [ ] **Obligatorio**: proyectos y repositorios locales.
- [ ] **Recomendable**: archivos fuera de las carpetas estándar del usuario:
      otras unidades, carpetas creadas en la raíz, rutas de trabajo
      personalizadas o directorios de aplicaciones.
- [ ] **Solo si aplica**: máquinas virtuales y sus discos.
- [ ] **Solo si aplica**: bases de datos locales.
- [ ] **Obligatorio**: archivos de trabajo en curso.
- [ ] **Recomendable**: configuraciones importantes de aplicaciones que no se
      puedan reconstruir fácilmente.

Copiar únicamente las carpetas estándar del usuario no es suficiente si existen
datos almacenados en otras rutas. Antes de formatear, revisar el árbol completo
de las unidades que se vayan a borrar y localizar cualquier dato que viva fuera
de las ubicaciones habituales.

Verificación del backup:

- [ ] Abrir una muestra representativa de archivos directamente desde el
      destino del backup, no solo desde el origen.
- [ ] Comprobar que la estructura de carpetas y los nombres se conservan.
- [ ] Confirmar que el destino del backup no se encuentra en una unidad que
      vaya a formatearse.

## 2. Desarrollo y programación

Antes del formateo:

- [ ] Revisar todos los repositorios Git locales.
- [ ] Revisar cambios sin commit y decidir en cada caso si se conservan,
      se descartan de forma consciente o se trasladan.
- [ ] Publicar o respaldar los commits que todavía no estén en un remoto.
- [ ] Identificar las ramas locales relevantes y comprobar que están
      respaldadas.
- [ ] Revisar archivos no rastreados que deban conservarse.
- [ ] Respaldar configuraciones locales de herramientas.
- [ ] Respaldar snippets y plantillas propias.
- [ ] Respaldar la configuración del editor y sus extensiones o plugins.
- [ ] Respaldar bases de datos de desarrollo si contienen datos que no puedan
      regenerarse.
- [ ] Respaldar contenedores o volúmenes con datos que no puedan regenerarse.
- [ ] Respaldar máquinas virtuales de desarrollo.
- [ ] Respaldar claves SSH.
- [ ] Respaldar claves GPG si se utilizan.
- [ ] Respaldar certificados personales si se utilizan.

Reglas de seguridad:

- Las claves privadas, los tokens, los archivos `.env`, los certificados y
  cualquier credencial deben respaldarse mediante un método privado y seguro,
  nunca subiéndolos a un repositorio.
- No trasladar secretos a Git, a documentación, a capturas ni a servicios
  externos no previstos para ello.
- No se debe indicar ni registrar ningún valor real de clave, token o
  contraseña en este documento ni en el repositorio.

## 3. Navegadores, cuentas y autenticación

Comprobar antes del formateo:

- [ ] Sincronización del navegador, si se utiliza.
- [ ] Marcadores que no estén cubiertos por la sincronización.
- [ ] Contraseñas guardadas que no estén sincronizadas o exportables.
- [ ] Extensiones importantes y su configuración.
- [ ] Perfiles de navegador separados.
- [ ] Códigos de recuperación y métodos 2FA cuando corresponda.

Los códigos de recuperación, tokens y contraseñas no deben almacenarse en este
repositorio ni en documentación pública. Si se guardan, debe ser en un medio
privado y seguro.

## 4. Juegos y contenido no regenerable

Revisar individualmente:

- [ ] Partidas guardadas locales.
- [ ] Juegos o perfiles que no utilicen guardado en la nube.
- [ ] Mods y su configuración.
- [ ] Configuraciones personalizadas, controles y perfiles.
- [ ] Capturas y grabaciones que se quieran conservar.
- [ ] Perfiles de launchers y plataformas.
- [ ] Contenido descargado que no pueda regenerarse o que sea costoso de
      recuperar.

Steam Cloud, Xbox Cloud y otros sistemas de sincronización no deben darse por
supuestos: comprobar juego por juego los títulos importantes. No todos los
juegos admiten guardado en la nube, y algunos solo lo hacen parcialmente.

## 5. OneDrive y archivos en la nube

El perfil de este proyecto elimina y bloquea OneDrive en la instalación nueva,
conservando los datos del usuario. Antes de formatear la instalación anterior:

- [ ] Comprobar que los archivos necesarios están realmente descargados de
      forma local o respaldados en otro medio.
- [ ] No asumir que un marcador de posición de OneDrive (archivo en línea) es
      una copia local completa: verificar el estado de cada carpeta importante.
- [ ] Revisar el contenido importante antes de borrar o abandonar la
      instalación anterior.

Esta guía no modifica ni desinstala OneDrive; solo cubre la comprobación previa
de datos.

## 6. BitLocker y cifrado

Advertencia:

- Antes de formatear o manipular unidades cifradas, comprobar si BitLocker u
  otro sistema de cifrado está activo y disponer de las claves de recuperación
  necesarias.
- Sin la clave de recuperación, un volumen cifrado puede quedar inaccesible de
  forma permanente al cambiar el equipo, el firmware o la instalación.
- Las claves de recuperación no deben pegarse en la terminal, en Git, en
  documentación, en capturas ni en chats como método de respaldo.
- No deben guardarse dentro de este repositorio.

Pasos:

- [ ] **Solo si aplica**: comprobar si alguna unidad está cifrada con BitLocker
      u otro sistema.
- [ ] **Solo si aplica**: confirmar que las claves de recuperación están
      disponibles fuera del equipo que se va a formatear.
- [ ] **Solo si aplica**: verificar que una clave de recuperación disponible
      se puede leer y no depende únicamente del sistema que se va a borrar.

La gestión efectiva del cifrado se realiza fuera de esta guía y no se automatiza
aquí. El perfil del repositorio aplica una política orientada a impedir el
cifrado automático de dispositivo en la instalación nueva, pero eso no sustituye
la comprobación ni la gestión del cifrado existente.

## 7. Drivers y software a preparar

El perfil de este proyecto excluye los drivers distribuidos mediante Windows
Update, por lo que esta sección es importante. Preparar previamente, según el
hardware real del equipo:

Drivers:

- [ ] **Obligatorio**: Ethernet.
- [ ] **Obligatorio si el equipo depende del Wi-Fi**: Wi-Fi.
- [ ] **Recomendado**: chipset.
- [ ] **Recomendado**: audio.
- [ ] **Recomendado**: GPU (Intel, AMD o NVIDIA, según corresponda al equipo).
- [ ] **Solo si es necesario**: almacenamiento y controladoras, cuando el
      instalador o el arranque no reconozcan el hardware o su modo.
- [ ] **Solo si es necesario**: Bluetooth y otros dispositivos específicos del
      fabricante, si se utilizan.

Recomendaciones:

- Obtener los drivers preferentemente de fuentes oficiales del fabricante del
  hardware o del equipo.
- No se recomiendan modelos, versiones ni enlaces concretos de drivers: la
  selección depende del hardware exacto y debe verificarse antes de la
  instalación. Si el hardware no está confirmado, tratar sus drivers como no
  aplicables todavía.
- No asumir que todos los dispositivos necesitan instalación manual de drivers:
  algunos pueden funcionar o completarse de otra forma después de la
  instalación. Preparar al menos los críticos.
- Disponer de los drivers en un medio accesible durante la instalación, no solo
  en el equipo que se va a formatear.

Software:

- [ ] **Recomendado**: tener localizados los instaladores del software que se
      vaya a usar de inmediato después de instalar (navegador, herramientas de
      desarrollo, launchers de juegos, utilidades habituales). Este repositorio
      no instala software de terceros de forma automática.

### Recomendación opcional de terceros: Visual C++ Redistributable

Como conveniencia opcional, se puede preparar el paquete "Visual C++
Redistributable Runtime Package All-in-One" publicado por TechPowerUp:

- Fuente: <https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/>
- No es un paquete oficial de Microsoft: es un recopilatorio de terceros.
- Es una recomendación opcional; su uso no es requisito del `autounattend.xml`
  ni de este proyecto.
- Antes de descargarlo o usarlo, debe verificarse la página de origen vigente y
  sus condiciones de uso, distribución y licencia.
- Este repositorio no afirma ninguna licencia concreta de ese paquete porque no
  la ha comprobado.

## 8. Inventario previo

Si resulta útil como referencia, conservar un inventario mínimo de:

- [ ] Aplicaciones importantes instaladas.
- [ ] Herramientas de desarrollo.
- [ ] Launchers y plataformas de juegos.
- [ ] Periféricos especiales y su software asociado.
- [ ] Configuración de red especial.
- [ ] Software con licencias o activaciones que deban recuperarse.

El inventario puede incluir nombres de aplicaciones y notas de configuración,
pero no debe recopilar claves de producto, credenciales ni identificadores
reales.

## 9. Medio de instalación

Según los archivos actuales del repositorio:

- La plataforma objetivo es Windows 11 25H2 x64 / amd64.
- El medio se prepara con Ventoy y su configuración `ventoy.json`.
- El archivo de respuestas esperado es `autounattend.xml`.
- La configuración de Ventoy declara una entrada de instalación concreta con
  ese archivo como plantilla. Esa entrada debe coincidir con la imagen de
  instalación realmente presente en el medio.

Comprobaciones:

- [ ] **Obligatorio**: preparar y revisar el medio antes de arrancar el equipo
      objetivo.
- [ ] **Obligatorio**: confirmar que la imagen de instalación presente en el
      medio coincide con la entrada declarada en `ventoy.json`.
- [ ] **Recomendable**: comprobar que `autounattend.xml` está presente en la
      ruta esperada por la configuración de Ventoy.
- [ ] **Recomendable**: probar el arranque del medio en un equipo o entorno
      desechable antes de usarlo en el equipo definitivo.

No se recomienda aquí ninguna ISO, build ni origen de descarga concretos. La
imagen debe obtenerse de una fuente confiable y corresponder a la plataforma
objetivo.

Nota: el perfil de este repositorio no automatiza la selección ni el borrado de
discos. Esa decisión se toma manualmente en el instalador y debe revisarse con
atención en el momento de la instalación.

## 10. Comprobación final antes de formatear

Confirmar todas las casillas antes de continuar:

- [ ] Backup realizado.
- [ ] Backup comprobado abriendo archivos desde el destino.
- [ ] Proyectos y repositorios importantes a salvo.
- [ ] Secretos y claves privadas respaldados de forma segura y fuera de Git.
- [ ] Partidas y contenido de juegos importantes respaldados.
- [ ] Datos de OneDrive o de otros servicios en la nube comprobados como
      realmente locales o respaldados.
- [ ] Claves de recuperación de cifrado disponibles, si aplican.
- [ ] Drivers críticos preparados y accesibles.
- [ ] Instalador y medio de instalación preparados y revisados.
- [ ] Dispositivos externos que NO deban tocarse identificados.
- [ ] Usuario consciente de que una instalación limpia puede borrar datos de
      forma irreversible.

## 11. Fuera de alcance

- Esta guía no instala Windows ni selecciona discos o particiones.
- Esta guía no modifica, desactiva ni desbloquea BitLocker u otro cifrado.
- Esta guía no configura drivers, cuentas ni software en el sistema destino.
- Una preparación correcta no demuestra por sí sola que la instalación vaya a
  funcionar: la validación real se realiza después de instalar y usar el
  sistema.
