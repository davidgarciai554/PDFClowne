.pragma library

var sections = [
    {
        title: "Archivo",
        entries: [
            { kind: "keyboard", trigger: "Ctrl+O", description: "Abrir un PDF.", availability: "Siempre disponible." },
            { kind: "keyboard", trigger: "Ctrl+S", description: "Guardar el PDF activo sobrescribiendo con las rotaciones aplicadas.", availability: "Solo cuando el documento activo tiene rotaciones pendientes." },
            { kind: "keyboard", trigger: "Ctrl+Shift+S", description: "Guardar una copia rotada del PDF activo.", availability: "Solo cuando el documento activo tiene rotaciones pendientes." }
        ]
    },
    {
        title: "Vista",
        entries: [
            { kind: "keyboard", trigger: "Ctrl+1", description: "Cambiar a vista de pagina unica.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "Ctrl+2", description: "Cambiar a vista continua.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "Ctrl+3", description: "Cambiar a vista de dos paginas.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "Ctrl+4", description: "Cambiar a vista continua de dos paginas.", availability: "Requiere un PDF abierto." },
            { kind: "gesture", trigger: "Arrastrar pestana", description: "Reordenar las pestanas abiertas.", availability: "Requiere dos o mas PDFs abiertos." }
        ]
    },
    {
        title: "Busqueda",
        entries: [
            { kind: "keyboard", trigger: "Ctrl+F", description: "Poner el foco en la busqueda.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "F3", description: "Ir al siguiente resultado de busqueda.", availability: "Requiere resultados de busqueda en el PDF activo." },
            { kind: "keyboard", trigger: "Shift+F3", description: "Ir al resultado anterior de busqueda.", availability: "Requiere resultados de busqueda en el PDF activo." },
            { kind: "keyboard", trigger: "Ctrl+L", description: "Mostrar u ocultar el panel de busqueda.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "Ctrl+Shift+F", description: "Limpiar la busqueda actual.", availability: "Requiere una busqueda activa en el PDF abierto." }
        ]
    },
    {
        title: "Lectura",
        entries: [
            { kind: "keyboard", trigger: "F11", description: "Activar o salir del modo pantalla completa de lectura.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "F5", description: "Activar o salir del modo presentacion.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "H", description: "Activar o desactivar la herramienta mano.", availability: "Requiere un PDF abierto y no estar en reflow." },
            { kind: "keyboard", trigger: "Ctrl+Shift+R", description: "Activar o desactivar el modo reflow.", availability: "Requiere un PDF abierto." },
            { kind: "keyboard", trigger: "Escape", description: "Salir del modo inmersivo activo.", availability: "Disponible en pantalla completa o presentacion." },
            { kind: "keyboard", trigger: "Right", description: "Ir a la pagina siguiente.", availability: "Disponible en pantalla completa o presentacion." },
            { kind: "keyboard", trigger: "Left", description: "Ir a la pagina anterior.", availability: "Disponible en pantalla completa o presentacion." },
            { kind: "keyboard", trigger: "Space", description: "Ir a la pagina siguiente.", availability: "Disponible en pantalla completa o presentacion." },
            { kind: "keyboard", trigger: "Backspace", description: "Ir a la pagina anterior.", availability: "Disponible en pantalla completa o presentacion." }
        ]
    },
    {
        title: "Texto",
        entries: [
            { kind: "keyboard", trigger: "Ctrl+C", description: "Copiar el texto seleccionado.", availability: "Requiere texto seleccionado en el PDF activo." },
            { kind: "keyboard", trigger: "Ctrl+Shift+C", description: "Copiar el texto visible o extraible.", availability: "Requiere un PDF abierto." }
        ]
    },
    {
        title: "Pestanas",
        entries: [
            { kind: "gesture", trigger: "Clic en X", description: "Cerrar la pestana pulsada.", availability: "Requiere una pestana abierta." },
            { kind: "gesture", trigger: "Clic rueda", description: "Cerrar la pestana pulsada como en un navegador.", availability: "Requiere una pestana abierta." },
            { kind: "gesture", trigger: "Boton +", description: "Abrir otro PDF en una pestana nueva.", availability: "Siempre disponible cuando se ve la barra de pestanas." }
        ]
    }
]
