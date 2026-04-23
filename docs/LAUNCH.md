# PDFClowne v2.0 - Build & Launch

## Prerequisites

| Tool | Notes |
| --- | --- |
| Qt 6.5+ | Core, Gui and Quick are required |
| MuPDF | Native headers and library are required |
| MSVC 2022 | x64 toolchain |
| CMake 3.22+ | |
| Ninja | |

## Environment Variables

```powershell
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "C:\path\to\mupdf-install"
```

`MUPDF_ROOT` should point to a MuPDF install/build folder containing `include\mupdf\fitz.h` and the MuPDF library.

If your MuPDF build has additional static dependencies, configure with `MUPDF_EXTRA_LIBRARIES`.

## Build Debug

```powershell
cd "D:\Aplicaciones\PDFClowne 2"
cmake --preset debug-msvc
cmake --build --preset debug-msvc
```

Binary:

```text
build\debug\PDFClowne.exe
```

## Build Release

```powershell
cmake --preset release-msvc
cmake --build --preset release-msvc
```

Binary:

```text
build\release\PDFClowne.exe
```

## Current Functional Scope

- Open a PDF.
- Render the first page using MuPDF.
- Show the rendered page in QML.

The reset build does not include zoom, rotation, search, tabs, or password handling yet.

## Troubleshooting

| Error | Cause | Fix |
| --- | --- | --- |
| `MuPDF was not found` | CMake cannot find MuPDF headers/library | Set `MUPDF_ROOT` to the MuPDF install/build folder |
| `Qt6_DIR not found` | Qt path is missing or wrong | Set `QT6_DIR` to the Qt MSVC folder |
| `cl.exe ... D8037` | MSVC temporary compiler files issue | Clean the system temp directory or restart the build environment |
| `QML object creation failed` | QML syntax/import problem | Check the app log |

## Logs

App logs write to:

```text
%LOCALAPPDATA%\PDFClowne\PDFClowne\logs\pdfclowne.log
```
