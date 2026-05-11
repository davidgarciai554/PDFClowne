# PROGRESO FASE 5 — EDICIÓN DE TEXTO PDFCLOWNE

> **Fuente única de verdad del estado de la Fase 5.** Este archivo se actualiza
> tras cada acción significativa. Las tareas completadas se eliminan de
> "Pendientes" y se resumen en "Histórico". El archivo se hace más corto con
> el tiempo, no más largo.

> **Regla de verificación de errores reportados por el usuario:** cualquier
> error que el usuario reporte se debe apuntar en este archivo y NO se debe
> borrar ni mover a histórico hasta que el usuario confirme explícitamente que
> funciona correctamente.

---

## 📍 Estado actual

- **Sub-fase activa**: Fase 5 completada; fase extra de pulido activa
- **Última actualización**: 2026-05-08
- **Última acción**: pulido técnico de edición PDFium: caché async, máscaras por línea, guardado real/reapertura y corpus mínimo de pruebas
- **Próxima acción planificada**: verificación manual del usuario en documentos reales antes de cerrar los errores reportados

---

## 🔧 En progreso ahora

> Solo UNA tarea aquí a la vez. Si tienes que pausar para investigar algo,
> anótalo y vuelve a esta tarea.

Verificación manual pendiente por el usuario: los errores reportados siguen en
la sección de confirmación hasta que funcionen correctamente en su máquina.

---

## ✅ Fase 5 — Estado cerrado

*(completada)*

Sub-fase 5.9 *(completada)*: extracción y guardado de edición PDFium movidos a workers `QThread`, con progreso y avisos de OCR/no editable expuestos a QML.

La Fase 5 queda cerrada como infraestructura funcional de edición visual de
texto PDF: extracción PDFium, agrupación de bloques, edición básica QML,
resize/toolbar, fallback de fuentes, persistencia segura, undo/redo y workers
en `QThread`.

No implica que la experiencia visual final esté pulida. El trabajo visual,
ergonómico y de errores reportados pasa a la fase extra.

---

## 📋 Pendientes — Fase extra: pulido visual y estabilidad

- [ ] Corregir el overlay de edición para que el texto original del PDF no se vea duplicado mientras se edita.
- [ ] Ajustar bboxes y alturas de bloques largos para que la caja de edición no invada líneas o secciones cercanas.
- [ ] Mejorar alineación pantalla↔PDF en zoom, scroll y páginas con tamaños distintos.
- [ ] Pulir `EditableTextBox.qml`: estados hover/selección/edición más claros y menos intrusivos.
- [ ] Pulir `EditInspector.qml`: contraste, espaciado, controles deshabilitados y legibilidad en tema oscuro.
- [ ] Reducir duplicidad visual entre toolbar superior, toolbar contextual e inspector.
- [ ] Validar que guardar copia actualiza/reabre el PDF sin perder el estado de la UI.
- [ ] Añadir corpus mínimo de PDFs reales en `tests/pdfs/` para cubrir CVs, PDFs escaneados y documentos con fuentes raras.
- [ ] Crear pruebas visuales/manuales guiadas para edición de texto en documentos reales.
- [ ] Revisar i18n pendiente en cadenas antiguas de QML no tocadas por la Fase 5.

Nota técnica 2026-05-08: se añadieron correcciones incrementales para los
puntos anteriores (`EditingController` cacheado, `lineRects`, máscaras de
líneas, mapping centralizado en `PdfViewer.qml`, guardado PDFium real y
reapertura). Los checks quedan abiertos hasta verificación manual.

---

## 🧾 Errores reportados por el usuario pendientes de verificación

> No eliminar ningún punto de esta sección hasta que el usuario confirme que
> funciona correctamente en su máquina.

- [ ] **Edición visual no permite editar correctamente** — reportado el 2026-05-08. En capturas se ve texto duplicado/superpuesto, caja de selección demasiado grande y problemas visuales del inspector. Estado: corrección técnica aplicada en overlay/bboxes/inspector; pendiente de verificación del usuario.
- [ ] **`PDFClowne.exe` no abre por dependencias faltantes** — reportado el 2026-05-08. Se detectó que faltaban DLLs junto al exe (`pdfium.dll`, `spdlogd.dll`, `fmtd.dll`) al abrir por doble click. Estado: corregido en CMake y build local; pendiente de verificación del usuario.
- [ ] **La UI de edición no coincide con el estilo general de la app** — reportado el 2026-05-08. En capturas se ve mezcla de botones oscuros propios, controles nativos claros (`ComboBox`, `SpinBox`, selector de color), toolbar contextual y toolbar superior sin una misma guía visual. Estado: corregido técnicamente; pendiente de verificación del usuario.
- [ ] **Al pulsar la pestaña de editar se queda pillada la aplicación** — reportado el 2026-05-08. Causa técnica identificada: entrada en modo edición disparaba extracción síncrona de texto desde bindings visuales (`pageTextBlocks()` → `textElementsForPage()`), bloqueando el hilo de UI. Estado: pendiente de corrección y verificación del usuario; nota técnica: ruta síncrona desactivada cuando existe `EditingController`, extracción cacheada/asíncrona con métricas.

---

## 🧠 Decisiones tomadas

> Cada vez que tomes una decisión arquitectónica o de implementación que NO
> esté ya resuelta en el prompt, anótala aquí con fecha, contexto y razón.

### 2026-05-06 — Usar nombres reales de puertos vcpkg para Qt 6
**Contexto:** el prompt usa nombres descriptivos `qt6-base`, `qt6-declarative`, `qt6-quick` y `qt6-pdf`, pero el registro oficial de vcpkg publica los módulos Qt 6 con nombres como `qtbase` y `qtdeclarative`.
**Opciones consideradas:** copiar literalmente los nombres del prompt, usar los puertos oficiales de vcpkg, o aplazar Qt a la instalación manual existente.
**Decisión:** usar `qtbase`, `qtdeclarative` y `qtwebengine` con feature `pdf`, además de `podofo`, `qpdf` y `spdlog`; PDFium queda gestionado por SDK externo u overlay.
**Razón:** evita un manifest que no resuelva en vcpkg estándar; `Qt Quick` lo aporta `qtdeclarative`, `Qt PDF` está empaquetado como feature `pdf` de `qtwebengine`, y el port oficial `pdfium` no existe en `microsoft/vcpkg`.
**Trade-off aceptado:** `qtwebengine[pdf]` puede hacer el bootstrap más pesado que una instalación manual de Qt.
**Reversible:** sí, si el proyecto adopta un registro/overlay que exponga puertos `qt6-*` o si se decide mantener Qt fuera de vcpkg.

### 2026-05-06 — Mantener dependencias PDFium detrás de opción CMake
**Contexto:** al añadir `find_package(unofficial-pdfium)` como requerido, la configuración local falló porque vcpkg/PDFium no está instalado en `CMAKE_PREFIX_PATH`.
**Opciones consideradas:** dejar las dependencias como requeridas inmediatamente, no tocar CMake hasta instalar vcpkg, o añadir una opción explícita para activar Fase 5 cuando el entorno esté listo.
**Decisión:** crear `PDFCLOWNE_ENABLE_PDFIUM_EDITING`, desactivada por defecto, y envolver ahí `Qt6::Pdf`, PDFium, QPDF, PoDoFo y spdlog.
**Razón:** preserva la compilación del visor Fase 1 mientras se prepara el toolchain de Fase 5.
**Trade-off aceptado:** la edición PDFium no queda enlazada hasta configurar con `-DPDFCLOWNE_ENABLE_PDFIUM_EDITING=ON`.
**Reversible:** sí, cuando vcpkg esté instalado y verificado se puede activar por defecto o en el preset de desarrollo de Fase 5.

### 2026-05-06 — Usar SDK externo de PDFium si no existe overlay vcpkg
**Contexto:** la búsqueda en el repositorio oficial `microsoft/vcpkg` no encontró `ports/pdfium`; los headers oficiales `public/fpdf_edit.h` y `public/fpdf_text.h` sí existen en `pdfium.googlesource.com`.
**Opciones consideradas:** mantener `"pdfium"` como dependencia esperando un overlay no configurado, compilar PDFium desde fuente, o usar `pdfium-binaries` como SDK externo.
**Decisión:** quitar `pdfium` del manifest estándar y permitir dos rutas en CMake: `unofficial::pdfium::pdfium` si existe un overlay, o `find_package(PDFium)` para un SDK tipo `pdfium-binaries`.
**Razón:** evita que `vcpkg install` falle con un port inexistente y mantiene una vía práctica para obtener `fpdf_edit.h`/`fpdf_text.h` sin compilar Chromium/PDFium desde fuente.
**Trade-off aceptado:** PDFium queda fuera de la resolución estándar de vcpkg hasta que se configure `PDFium_DIR` o un overlay.
**Reversible:** sí, si se añade un overlay oficial del proyecto o un registro privado con port `pdfium`.

### 2026-05-06 — Adaptar extractor a la API real del SDK PDFium instalado
**Contexto:** el prompt citaba `FPDFPageObj_GetBBox`, `FPDFTextObj_GetTextMatrix` y `FPDFFont_GetFontName`, pero el SDK instalado en `D:\Aplicaciones\pdfium\include` expone los equivalentes disponibles `FPDFPageObj_GetBounds`, `FPDFPageObj_GetMatrix` y `FPDFFont_GetBaseFontName`.
**Opciones consideradas:** bloquear la tarea esperando otro build de PDFium, envolver ambas variantes con detección compleja, o usar directamente las APIs estables presentes en el SDK instalado.
**Decisión:** usar `FPDFPageObj_GetBounds`, `FPDFPageObj_GetMatrix` y `FPDFFont_GetBaseFontName` en `PdfPageObjectExtractor`.
**Razón:** permite compilar contra el PDFium disponible sin perder la información necesaria para bbox, matriz y nombre de fuente.
**Trade-off aceptado:** el código queda documentado contra los nombres reales del SDK actual, no contra los nombres del pseudocódigo del prompt.
**Reversible:** sí, si se cambia de SDK y se necesita compatibilidad condicional por versión.

### 2026-05-06 — Mantener la visualización debug desacoplada de la UI actual
**Contexto:** `PdfViewer.qml` ya contiene una capa de edición basada en MuPDF y además tenía cambios de trabajo ajenos sin commitear.
**Opciones consideradas:** modificar directamente `PdfViewer.qml`, esperar a `EditingController`, o crear una utilidad core que pinte bboxes sobre una imagen renderizada.
**Decisión:** crear `PdfExtractionDebugRenderer` como utilidad core, sin tocar la UI sucia.
**Razón:** permite verificar la conversión PDF Y-up → imagen Y-down y reutilizar el overlay cuando exista el controlador PDFium de Fase 5.
**Trade-off aceptado:** la conexión visible en QML queda para la integración con `EditingController`/workers.
**Reversible:** sí, cuando la UI de Fase 5 esté lista se conecta el renderer o se reemplaza por una capa QML equivalente.

---

## ⚠️ Bloqueos / issues abiertos

> Problemas encontrados que requieren resolución antes de avanzar.
> Mover a "Histórico" cuando se resuelvan.

- `PDFCLOWNE_ENABLE_PDFIUM_EDITING=ON` requiere configurar `PDFium_DIR=D:/Aplicaciones/pdfium` y `CMAKE_PREFIX_PATH` con Qt/vcpkg/PDFium; verificado el 2026-05-08.
- QPDF y PoDoFo no están instalados en el preset debug actual; CMake degrada esas áreas a stubs.
- Fuentes añadidas desde proyectos libres: DejaVu 2.37 y Noto Fonts/Noto CJK bajo OFL.
- La edición visual todavía necesita pulido: el overlay no tapa el texto original mientras se escribe, algunos bboxes quedan sobredimensionados y el inspector tiene bajo contraste en estado oscuro.

---

## 📚 Histórico (resumen de tareas completadas)

> Una línea por tarea completada. Formato: `YYYY-MM-DD — [Sub-fase X.Y] descripción breve — commit-hash`

2026-05-06 — [Sub-fase 5.0] añadido manifest vcpkg con dependencias base — 49180cc
2026-05-06 — [Sub-fase 5.0] configurado CMake para dependencias PDFium bajo opción explícita — 84ae98c
2026-05-06 — [Sub-fase 5.0] verificado packaging PDFium y añadido fallback a SDK externo — eca5f36
2026-05-06 — [Sub-fase 5.0] creada estructura local de directorios sin placeholders — de0499e
2026-05-06 — [Sub-fase 5.0] implementado `PdfiumInitializer` thread-safe — ddf78f7
2026-05-06 — [Sub-fase 5.0] implementado macro `PDFIUM_LOCK()` — ddf78f7
2026-05-06 — [Sub-fase 5.0] verificada compilación debug y arranque básico de Fase 1 — 33d3890
2026-05-06 — [Sub-fase 5.0] añadido y ejecutado smoke test hello world de PDFium — 61e1bc1
2026-05-06 — [Sub-fase 5.0] resuelto bloqueo de dependencias y validado build con edición PDFium activada — 4f4fa0b
2026-05-06 — [Sub-fase 5.1] definidos modelos planos de texto PDF — 4ed88b2
2026-05-06 — [Sub-fase 5.1] implementado extractor PDFium de runs de texto por página — 17fea57
2026-05-06 — [Sub-fase 5.1] implementada lectura Unicode UTF-16 de objetos de texto — 17fea57
2026-05-06 — [Sub-fase 5.1] aplicados filtros de runs vacíos, sin bbox e invisibles — 7e1c94f
2026-05-06 — [Sub-fase 5.2] creado `EditingHeuristics.h` con constantes iniciales — 7e1c94f
2026-05-06 — [Sub-fase 5.1] añadido renderer core de bboxes rojos para debug de extracción — b240a2d
2026-05-06 — [Sub-fase 5.1] añadido test CTest de extractor con PDF simple generado por PDFium — e5f6940
2026-05-06 — [Sub-fase 5.1] tests MixedFonts y Scanned pasando; fix PATH vcpkg+PDFium en CTest — d89fc6d
2026-05-06 — [Sub-fase 5.2] TextBlockBuilder + DebugRenderer (runs/lines/blocks) verificados; 8 unit tests pasan — 04ac54a
2026-05-06 — [Sub-fase 5.3] phase5BlockOverlay añadido a PdfViewer.qml; conecta EditingController→selectBlock
2026-05-06 — [Sub-fase 5.4] TextEdit+reflowText(QFontMetricsF)+live preview+overflow indicator implementados
2026-05-06 — [Sub-fase 5.5] ResizeHandles.qml (8 puntos), snap-to-guides, 3 modos, EditingToolbar implementados
2026-05-07 — [Sub-fase 5.6] FontFallbackManager + banner QML de sustitución de fuente implementados
2026-05-07 — [Sub-fase 5.7] Persistencia PDFium reforzada con cache multipágina, salida explícita obligatoria y bloqueo de overwrite directo
2026-05-07 — [Sub-fase 5.7] PdfWriteBackEngine guarda con temp → valida con PDFium → renombra
2026-05-07 — [Sub-fase 5.8] EditToolbar expone botones Undo/Redo conectados a `undoActiveDocumentEdit`/`redoActiveDocumentEdit`
2026-05-07 — [Sub-fase 5.8] PdfEditCommand añade comandos tipados para texto, resize, move, delete y estilo con merge de edición de texto por bloque
2026-05-07 — [Sub-fase 5.8] PdfEditSession expone helpers QML para comandos tipados y estado `canUndo`/`canRedo`
2026-05-08 — [Sub-fase 5.6] FontFallbackResult transporta ruta embebible y PdfWriteBackEngine usa `FPDFText_LoadFont`/`FPDFPageObj_CreateTextObj` si hay fuente local
2026-05-08 — [Sub-fase 5.6] Añadidas `DejaVuSans.ttf`, `NotoSansArabic-Regular.ttf` y `NotoSansCJK-Regular.otf` con licencias en `resources/fonts`
2026-05-08 — [Sub-fase 5.7] EditInspector añade selección incremental/full rewrite y EditingController conserva el modo en `SaveMode`
2026-05-08 — [Sub-fase 5.7] PdfWriteBackIntegrationTest valida save→reload y comparación visual con tolerancia 2% en build PDFium
2026-05-08 — [Sub-fase 5.9] PdfExtractionWorker y PdfSaveWorker ejecutan extracción/guardado en `QThread`
2026-05-08 — [Sub-fase 5.9] EditingController expone `busy`, `progress`, `statusMessage` y aviso de PDF escaneado para QML
2026-05-08 — [Sub-fase 5.9] PdfViewer muestra progreso durante extracción/guardado y sugerencia OCR si no hay texto editable
2026-05-08 — [Sub-fase 5.9] Bloques `isEditable=false` rechazan edición y muestran motivo en `EditableTextBox`
2026-05-08 — [Sub-fase 5.9] Documentada arquitectura final y limitaciones en `docs/PHASE5_DESIGN.md`

---

## 🧪 Estado de tests

- Tests unitarios: 6 / ~25 estimados
- Tests estáticos/contrato PowerShell: añadidos para arquitectura nativa, persistencia PDFium, replacement, extractor e inline editor
- Tests de integración: 1 / 5 estimados
- PDFs de corpus en `tests/pdfs/`: 0 / 9

---

## 📊 Métricas de salud del módulo (actualizar cuando aplique)

- LOC del módulo de edición: (pendiente de recalcular)
- Tiempo de extracción en `large_doc_500pages.pdf`: (sin medir)
- Memoria pico durante edición: (sin medir)
- Latencia de reflow por keystroke: (sin medir)
