# PDFClowne shortcuts

Lista de atajos y gestos funcionales hoy en la app. Esta guia esta alineada con el catalogo compartido de `src/qml/ShortcutCatalog.js`.

## Archivo

| Atajo | Accion | Disponibilidad |
| --- | --- | --- |
| `Ctrl+O` | Abrir un PDF. | Siempre disponible. |
| `Ctrl+S` | Guardar el PDF activo sobrescribiendo con las ediciones aplicadas. | Solo cuando el documento activo tiene cambios pendientes. |
| `Ctrl+Shift+S` | Guardar una copia editada del PDF activo. | Solo cuando el documento activo tiene cambios pendientes. |
| `Ctrl+R` | Recargar el PDF activo desde disco. | Requiere un PDF abierto. |
| `Ctrl+H` | Abrir la pantalla de inicio con los archivos recientes. | Siempre disponible. |

## Vista

| Atajo o gesto | Accion | Disponibilidad |
| --- | --- | --- |
| `Ctrl+1` | Cambiar a vista de pagina unica. | Requiere un PDF abierto. |
| `Ctrl+2` | Cambiar a vista continua. | Requiere un PDF abierto. |
| `Ctrl+3` | Cambiar a vista de dos paginas. | Requiere un PDF abierto. |
| `Ctrl+4` | Cambiar a vista continua de dos paginas. | Requiere un PDF abierto. |
| `F6` | Mover el foco al siguiente panel principal de la interfaz. | Siempre disponible. |
| `Shift+F6` | Mover el foco al panel principal anterior. | Siempre disponible. |
| `Arrastrar pestana` | Reordenar las pestanas abiertas. | Requiere dos o mas PDFs abiertos. |

## Busqueda

| Atajo | Accion | Disponibilidad |
| --- | --- | --- |
| `Ctrl+F` | Poner el foco en la busqueda. | Requiere un PDF abierto. |
| `F3` | Ir al siguiente resultado de busqueda. | Requiere resultados de busqueda en el PDF activo. |
| `Shift+F3` | Ir al resultado anterior de busqueda. | Requiere resultados de busqueda en el PDF activo. |
| `Ctrl+L` | Mostrar u ocultar el panel de busqueda. | Requiere un PDF abierto. |
| `Ctrl+Shift+F` | Limpiar la busqueda actual. | Requiere una busqueda activa en el PDF abierto. |

## Lectura

| Atajo | Accion | Disponibilidad |
| --- | --- | --- |
| `F11` | Activar o salir del modo pantalla completa de lectura. | Requiere un PDF abierto. |
| `F5` | Activar o salir del modo presentacion. | Requiere un PDF abierto. |
| `H` | Activar o desactivar la herramienta mano. | Requiere un PDF abierto y no estar en reflow. |
| `Ctrl+Shift+R` | Activar o desactivar el modo reflow. | Requiere un PDF abierto. |
| `Alt+Left` | Volver a la pagina anterior del historial interno del documento. | Requiere historial hacia atras en el PDF activo. |
| `Alt+Right` | Avanzar a la pagina siguiente del historial interno del documento. | Requiere historial hacia delante en el PDF activo. |
| `Escape` | Salir del modo inmersivo activo. | Disponible en pantalla completa o presentacion. |
| `Right` | Ir a la pagina siguiente. | Disponible en pantalla completa o presentacion. |
| `Left` | Ir a la pagina anterior. | Disponible en pantalla completa o presentacion. |
| `Space` | Ir a la pagina siguiente. | Disponible en pantalla completa o presentacion. |
| `Backspace` | Ir a la pagina anterior. | Disponible en pantalla completa o presentacion. |

## Edicion

| Atajo | Accion | Disponibilidad |
| --- | --- | --- |
| `Ctrl+Z` | Deshacer la ultima edicion del documento activo. | Requiere cambios editables previos en el PDF activo. |
| `Ctrl+Y` | Rehacer la ultima edicion deshecha del documento activo. | Requiere cambios deshechos en el PDF activo. |

## Texto

| Atajo | Accion | Disponibilidad |
| --- | --- | --- |
| `Ctrl+C` | Copiar el texto seleccionado. | Requiere texto seleccionado en el PDF activo. |
| `Ctrl+Shift+C` | Copiar el texto visible o extraible. | Requiere un PDF abierto. |

## Pestanas

| Atajo o gesto | Accion | Disponibilidad |
| --- | --- | --- |
| `Clic en X` | Cerrar la pestana pulsada. | Requiere una pestana abierta. |
| `Clic rueda` | Cerrar la pestana pulsada como en un navegador. | Requiere una pestana abierta. |
| `Boton +` | Abrir otro PDF en una pestana nueva. | Siempre disponible cuando se ve la barra de pestanas. |
