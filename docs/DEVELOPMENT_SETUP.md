# PDFClowne Development Setup Guide

English and Spanish guide to help developers clone, install, build, and run the project with the least friction possible.

---

## English

### What This Repository Is

PDFClowne is a Windows desktop PDF application built with:

- Qt 6 / QML
- C++
- MuPDF
- CMake
- MSVC 2022
- Ninja

This project is currently easiest to develop on **Windows**.

### Official Dependency Links

- Qt downloads: [qt.io/download](https://www.qt.io/download/)
- Qt Online Installer guide: [doc.qt.io/qt-6/qt-online-installation.html](https://doc.qt.io/qt-6/qt-online-installation.html)
- Visual Studio Community 2022: [visualstudio.microsoft.com/vs/community](https://visualstudio.microsoft.com/vs/community/)
- CMake downloads: [cmake.org/download](https://cmake.org/download/)
- Ninja manual: [ninja-build.org/manual](https://ninja-build.org/manual)
- MuPDF source repository: [github.com/ArtifexSoftware/mupdf](https://github.com/ArtifexSoftware/mupdf)
- MuPDF quick start guide: [mupdf.readthedocs.io/.../quick-start-guide.html](https://mupdf.readthedocs.io/en/1.24.0/quick-start-guide.html)
- MuPDF product page: [artifex.com/products/mupdf](https://artifex.com/products/mupdf/)

### Recommended Environment

- Windows 10 or Windows 11
- Visual Studio 2022 Community
- C++ desktop tools installed
- Qt 6.8.x or newer in an MSVC 2022 x64 build
- CMake 3.22+
- Ninja
- MuPDF built locally or downloaded and unpacked in a folder you control

### 1. Clone the Repository

```powershell
git clone <your-repo-url>
cd "PDFClowne 2"
```

### 2. Install Visual Studio 2022

Install Visual Studio Community 2022 from the official Microsoft site.

During installation, enable:

- `Desktop development with C++`

Recommended optional components:

- MSVC v143 build tools
- Windows 10/11 SDK
- CMake tools for C++
- Ninja

### 3. Install Qt

Use the Qt Online Installer.

Recommended Qt components:

- Qt 6.8.x
- `MSVC 2022 64-bit`
- `Qt Quick`
- `Qt Quick Controls`
- `Qt Quick Dialogs`
- Qt Creator optional but recommended

Typical local path after install:

```text
C:\Qt\6.8.3\msvc2022_64
```

### 4. Install CMake and Ninja

If Visual Studio did not already give you a working setup, install them manually:

- CMake: [cmake.org/download](https://cmake.org/download/)
- Ninja: [ninja-build.org/manual](https://ninja-build.org/manual)

Make sure both commands work:

```powershell
cmake --version
ninja --version
```

### 5. Get MuPDF

This project expects MuPDF headers and libraries to be available through `MUPDF_ROOT`.

The easiest developer path is:

1. Clone MuPDF
2. Build it on Windows with Visual Studio
3. Point `MUPDF_ROOT` to that folder

Example:

```powershell
git clone --recursive https://github.com/ArtifexSoftware/mupdf.git
cd mupdf
git submodule update --init
```

Then follow the official Windows build flow from MuPDF's quick start guide.

This repository expects at least:

```text
<MUPDF_ROOT>\include\mupdf\fitz.h
<MUPDF_ROOT>\lib\libmupdf.lib
```

If your MuPDF build also needs extra libraries, you can pass them through `MUPDF_EXTRA_LIBRARIES`.

### 6. Set Environment Variables

Open PowerShell and set:

```powershell
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "D:\Aplicaciones\mupdf"
```

Optional:

```powershell
$env:MUPDF_EXTRA_LIBRARIES = ""
```

If CMake cannot find the MSVC compiler, open a **Developer PowerShell for Visual Studio 2022** before running the build commands.

### 7. Configure the Project

From the repository root:

Debug:

```powershell
cmake --preset debug-msvc
```

Release:

```powershell
cmake --preset release-msvc
```

### 8. Build the Project

Debug:

```powershell
cmake --build --preset debug-msvc
```

Release:

```powershell
cmake --build --preset release-msvc
```

### 9. Run the App

Release binary:

```text
build\release\PDFClowne.exe
```

Debug binary:

```text
build\debug\PDFClowne.exe
```

### 10. Daily Developer Workflow

Typical cycle:

```powershell
cd "D:\Aplicaciones\PDFClowne 2"
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "D:\Aplicaciones\mupdf"
cmake --build --preset debug-msvc
```

If you only changed QML, sometimes the project can pick that up with a much lighter rebuild, but C++ changes still require a normal build.

### Useful Project Paths

- Main QML entry: [`src/qml/main.qml`](../src/qml/main.qml)
- Viewer logic: [`src/qml/PdfViewer.qml`](../src/qml/PdfViewer.qml)
- PDF backend: [`src/backend/PdfDocument.cpp`](../src/backend/PdfDocument.cpp)
- Build presets: [`CMakePresets.json`](../CMakePresets.json)
- Main CMake file: [`CMakeLists.txt`](../CMakeLists.txt)

### Troubleshooting

#### Qt not found

Error example:

```text
Could not find Qt6
```

Fix:

- Check `QT6_DIR`
- Make sure it points to the MSVC 64-bit Qt folder
- Make sure Qt Quick / Controls / Dialogs are installed

#### MuPDF not found

Error example:

```text
MuPDF was not found. Install/build MuPDF and set MUPDF_ROOT
```

Fix:

- Check `MUPDF_ROOT`
- Verify `include\mupdf\fitz.h`
- Verify the library files exist

#### `cl.exe` / compiler problems

If MSVC tools are not available, install or repair the Visual Studio C++ workload.

#### `D8037 : cannot create temporary il file`

This is a local MSVC environment issue, not usually a project code issue.

Try:

- clean your Windows temp folders
- close Visual Studio / terminals and reopen them
- restart Windows
- rebuild from a fresh PowerShell session

### New Contributor Checklist

- [ ] Visual Studio 2022 installed
- [ ] C++ workload installed
- [ ] Qt installed
- [ ] Qt Quick / Controls / Dialogs installed
- [ ] CMake works
- [ ] Ninja works
- [ ] MuPDF downloaded or built
- [ ] `QT6_DIR` set
- [ ] `MUPDF_ROOT` set
- [ ] `cmake --preset debug-msvc` works
- [ ] `cmake --build --preset debug-msvc` works

---

## Español

### Qué Es Este Repositorio

PDFClowne es una aplicación de escritorio para PDF en Windows hecha con:

- Qt 6 / QML
- C++
- MuPDF
- CMake
- MSVC 2022
- Ninja

Ahora mismo, la forma más sencilla de desarrollar este proyecto es en **Windows**.

### Enlaces Oficiales de Dependencias

- Descarga de Qt: [qt.io/download](https://www.qt.io/download/)
- Guía del instalador online de Qt: [doc.qt.io/qt-6/qt-online-installation.html](https://doc.qt.io/qt-6/qt-online-installation.html)
- Visual Studio Community 2022: [visualstudio.microsoft.com/vs/community](https://visualstudio.microsoft.com/vs/community/)
- Descarga de CMake: [cmake.org/download](https://cmake.org/download/)
- Manual de Ninja: [ninja-build.org/manual](https://ninja-build.org/manual)
- Repositorio oficial de MuPDF: [github.com/ArtifexSoftware/mupdf](https://github.com/ArtifexSoftware/mupdf)
- Guía rápida oficial de MuPDF: [mupdf.readthedocs.io/.../quick-start-guide.html](https://mupdf.readthedocs.io/en/1.24.0/quick-start-guide.html)
- Página de MuPDF en Artifex: [artifex.com/products/mupdf](https://artifex.com/products/mupdf/)

### Entorno Recomendado

- Windows 10 o Windows 11
- Visual Studio 2022 Community
- Herramientas de C++ instaladas
- Qt 6.8.x o superior en versión MSVC 2022 x64
- CMake 3.22+
- Ninja
- MuPDF compilado localmente o descargado en una carpeta controlada por ti

### 1. Clonar el Repositorio

```powershell
git clone <url-de-tu-repo>
cd "PDFClowne 2"
```

### 2. Instalar Visual Studio 2022

Instala Visual Studio Community 2022 desde la web oficial de Microsoft.

Durante la instalación, activa:

- `Desktop development with C++`

Componentes opcionales recomendados:

- MSVC v143 build tools
- Windows 10/11 SDK
- CMake tools for C++
- Ninja

### 3. Instalar Qt

Usa el instalador online de Qt.

Componentes recomendados:

- Qt 6.8.x
- `MSVC 2022 64-bit`
- `Qt Quick`
- `Qt Quick Controls`
- `Qt Quick Dialogs`
- Qt Creator es opcional, pero recomendado

Ruta típica local:

```text
C:\Qt\6.8.3\msvc2022_64
```

### 4. Instalar CMake y Ninja

Si Visual Studio no los deja listos, instálalos manualmente:

- CMake: [cmake.org/download](https://cmake.org/download/)
- Ninja: [ninja-build.org/manual](https://ninja-build.org/manual)

Comprueba que ambos comandos funcionan:

```powershell
cmake --version
ninja --version
```

### 5. Conseguir MuPDF

Este proyecto espera que los headers y librerías de MuPDF estén accesibles mediante `MUPDF_ROOT`.

La ruta más simple para desarrollar es:

1. Clonar MuPDF
2. Compilarlo en Windows con Visual Studio
3. Apuntar `MUPDF_ROOT` a esa carpeta

Ejemplo:

```powershell
git clone --recursive https://github.com/ArtifexSoftware/mupdf.git
cd mupdf
git submodule update --init
```

Después sigue la guía oficial de Windows de MuPDF.

Como mínimo, este repositorio espera:

```text
<MUPDF_ROOT>\include\mupdf\fitz.h
<MUPDF_ROOT>\lib\libmupdf.lib
```

Si tu build de MuPDF necesita librerías extra, puedes pasarlas con `MUPDF_EXTRA_LIBRARIES`.

### 6. Configurar Variables de Entorno

Abre PowerShell y define:

```powershell
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "D:\Aplicaciones\mupdf"
```

Opcional:

```powershell
$env:MUPDF_EXTRA_LIBRARIES = ""
```

Si CMake no encuentra el compilador de MSVC, abre antes una **Developer PowerShell for Visual Studio 2022** y ejecuta ahí los comandos de compilación.

### 7. Configurar el Proyecto

Desde la raíz del repo:

Debug:

```powershell
cmake --preset debug-msvc
```

Release:

```powershell
cmake --preset release-msvc
```

### 8. Compilar el Proyecto

Debug:

```powershell
cmake --build --preset debug-msvc
```

Release:

```powershell
cmake --build --preset release-msvc
```

### 9. Ejecutar la App

Binario release:

```text
build\release\PDFClowne.exe
```

Binario debug:

```text
build\debug\PDFClowne.exe
```

### 10. Flujo Diario de Desarrollo

Ciclo típico:

```powershell
cd "D:\Aplicaciones\PDFClowne 2"
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "D:\Aplicaciones\mupdf"
cmake --build --preset debug-msvc
```

Si solo cambiaste QML, a veces el proyecto puede recogerlo con una recompilación mucho más ligera, pero los cambios en C++ sí necesitan una build normal.

### Rutas Útiles del Proyecto

- Entrada principal QML: [`src/qml/main.qml`](../src/qml/main.qml)
- Lógica del visor: [`src/qml/PdfViewer.qml`](../src/qml/PdfViewer.qml)
- Backend del PDF: [`src/backend/PdfDocument.cpp`](../src/backend/PdfDocument.cpp)
- Presets de build: [`CMakePresets.json`](../CMakePresets.json)
- CMake principal: [`CMakeLists.txt`](../CMakeLists.txt)

### Problemas Frecuentes

#### Qt no aparece

Error típico:

```text
Could not find Qt6
```

Solución:

- revisar `QT6_DIR`
- confirmar que apunta a la carpeta MSVC 64-bit de Qt
- confirmar que Qt Quick / Controls / Dialogs están instalados

#### MuPDF no aparece

Error típico:

```text
MuPDF was not found. Install/build MuPDF and set MUPDF_ROOT
```

Solución:

- revisar `MUPDF_ROOT`
- confirmar `include\mupdf\fitz.h`
- confirmar que existen las librerías

#### Problemas con `cl.exe` o compilador

Si las herramientas de MSVC no están disponibles, instala o repara la carga de trabajo de C++ en Visual Studio.

#### `D8037 : cannot create temporary il file`

Esto suele ser un problema del entorno local de MSVC, no del código del proyecto.

Prueba:

- limpiar carpetas temporales de Windows
- cerrar Visual Studio y terminales
- reiniciar Windows
- recompilar desde una nueva sesión de PowerShell

### Checklist Rápido para Nuevos Colaboradores

- [ ] Visual Studio 2022 instalado
- [ ] workload de C++ instalado
- [ ] Qt instalado
- [ ] Qt Quick / Controls / Dialogs instalados
- [ ] CMake funciona
- [ ] Ninja funciona
- [ ] MuPDF descargado o compilado
- [ ] `QT6_DIR` configurado
- [ ] `MUPDF_ROOT` configurado
- [ ] `cmake --preset debug-msvc` funciona
- [ ] `cmake --build --preset debug-msvc` funciona
