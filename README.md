# PDFClowne v2.0

Desktop PDF app for Windows built with Qt 6 / QML and MuPDF.

## Current State

This branch is a MuPDF reset build. The first milestone is intentionally small:

- Open a PDF from the file dialog.
- Render the first page with MuPDF.
- Show that rendered page in QML.

There is no zoom, rotation, search, tabs, password dialog, status bar, or Qt PDF viewer in this reset milestone.

## Requirements

| Component | Minimum |
| --- | --- |
| Qt | 6.5+ with Core, Gui and Quick |
| MuPDF | Native headers and library |
| Visual Studio Build Tools | 2022, MSVC x64 |
| CMake | 3.22+ |
| Ninja | Any recent version |

## Environment

Set Qt and MuPDF before configuring:

```powershell
$env:QT6_DIR = "C:\Qt\6.8.3\msvc2022_64"
$env:MUPDF_ROOT = "C:\path\to\mupdf-install"
```

`MUPDF_ROOT` must contain:

- `include\mupdf\fitz.h`
- a MuPDF library under `lib\` or `build\release\`

If your MuPDF build needs extra static libraries, pass them through `MUPDF_EXTRA_LIBRARIES` when configuring CMake.

## Build

```powershell
cmake --preset debug-msvc
cmake --build --preset debug-msvc
```

The debug binary is expected at:

```text
build\debug\PDFClowne.exe
```

## Shortcut

| Action | Shortcut |
| --- | --- |
| Open PDF | `Ctrl+O` |

## Project Structure

```text
PDFClowne/
├── CMakeLists.txt
├── CMakePresets.json
├── src/
│   ├── main.cpp
│   ├── backend/
│   │   ├── Logger.h
│   │   ├── PdfDocument.cpp
│   │   └── PdfDocument.h
│   └── qml/
│       ├── main.qml
│       ├── PdfViewer.qml
│       └── Theme.qml
└── resources/
    └── resources.qrc
```
