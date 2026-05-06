# PROGRESO FASE 5 — EDICIÓN DE TEXTO PDFCLOWNE

> **Fuente única de verdad del estado de la Fase 5.** Este archivo se actualiza
> tras cada acción significativa. Las tareas completadas se eliminan de
> "Pendientes" y se resumen en "Histórico". El archivo se hace más corto con
> el tiempo, no más largo.

---

## 📍 Estado actual

- **Sub-fase activa**: 5.1 (Extracción de page objects)
- **Última actualización**: 2026-05-06 21:30
- **Última acción**: Sub-fase 5.2 completa — TextBlockBuilder + DebugRenderer verificados
- **Próxima acción planificada**: Sub-fase 5.3 — `PdfCoordTransform` + `TextBlockModel` + `EditableTextBox.qml`

---

## 🔧 En progreso ahora

> Solo UNA tarea aquí a la vez. Si tienes que pausar para investigar algo,
> anótalo y vuelve a esta tarea.

(ninguna tarea iniciada todavía)

---

## 📋 Pendientes — Sub-fase 5.1: Extracción de page objects

*(completada)*

## 📋 Pendientes — Sub-fase 5.2: Agrupación

*(completada)*

## 📋 Pendientes — Sub-fase 5.3: UI básica QML

- [ ] Implementar `PdfCoordTransform` con conversiones bidireccionales (§6.1)
- [ ] Implementar `TextBlockModel` (QAbstractListModel) (§6.4)
- [ ] Crear `EditableTextBox.qml` con states hover/selected (§6.2)
- [ ] Conectar selección con `EditingController`
- [ ] Test integración: cargar PDF → ver bloques resaltados al hover

## 📋 Pendientes — Sub-fase 5.4: Edición simple con reflow

- [ ] TextEdit en QML activo en modo edición (§6.2)
- [ ] Implementar `reflowText` con QFontMetricsF (§7.1)
- [ ] Live preview en cada keystroke (§7.2)
- [ ] Auto-expansión vertical del bbox al crecer el texto
- [ ] Indicador visual de overflow

## 📋 Pendientes — Sub-fase 5.5: Resize handles + estilos

- [ ] Crear `ResizeHandles.qml` con 8 puntos (§6.3)
- [ ] Conectar resize a reflow en vivo
- [ ] Implementar 3 modos: reflow / escalar fuente / clip (§8.2)
- [ ] Snap a guías con otros bloques (§8.3)
- [ ] Toolbar contextual: fuente, tamaño, color, alineación

## 📋 Pendientes — Sub-fase 5.6: Font fallback

- [ ] Embeber DejaVu Sans, Noto CJK, Noto Arabic en `resources/fonts/`
- [ ] Implementar `canFontRenderText` (§9.1)
- [ ] Implementar `FontFallbackManager` con sustitución selectiva (§9.2)
- [ ] Embebido (subset o full) de fuente fallback en el PDF (§9.3)
- [ ] UI: banner de aviso al usuario

## 📋 Pendientes — Sub-fase 5.7: Persistencia

- [ ] Implementar `PdfWriteBackEngine::writeBackBlock` (§10.1)
- [ ] Wrapper `FileWriter` sobre QFile (§10.2)
- [ ] Opción incremental vs full rewrite en UI (§10.3)
- [ ] Test integración: save → reload → verificar texto modificado presente
- [ ] Test integración: golden image comparison con tolerancia 2%

## 📋 Pendientes — Sub-fase 5.8: Undo/Redo

- [ ] `EditTextCommand` con merge para keystrokes (§11)
- [ ] `ResizeBlockCommand`
- [ ] `MoveBlockCommand`
- [ ] `DeleteBlockCommand`
- [ ] `ChangeStyleCommand`
- [ ] Botones Undo/Redo en toolbar QML conectados a `QUndoStack`

## 📋 Pendientes — Sub-fase 5.9: Threading + polish

- [ ] `ExtractionWorker` en QThread propio (§12.1)
- [ ] `SaveWorker` en QThread propio (§12.2)
- [ ] Barra de progreso en UI durante extracción/guardado
- [ ] Manejo de bloqueos `isEditable=false` (§14.1)
- [ ] Detección de PDF escaneado con sugerencia de OCR (§14.2)
- [ ] i18n: todos los strings con `qsTr()` / `tr()`
- [ ] Logging spdlog en operaciones críticas
- [ ] Documentación final en `docs/PHASE5_DESIGN.md`

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

(sin bloqueos)

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
2026-05-06 — [Sub-fase 5.2] TextBlockBuilder + DebugRenderer (runs/lines/blocks) verificados; 8 unit tests pasan — (pendiente commit)

---

## 🧪 Estado de tests

- Tests unitarios: 6 / ~25 estimados
- Tests de integración: 0 / 5 estimados
- PDFs de corpus en `tests/pdfs/`: 0 / 9

---

## 📊 Métricas de salud del módulo (actualizar cuando aplique)

- LOC del módulo de edición: 296
- Tiempo de extracción en `large_doc_500pages.pdf`: (sin medir)
- Memoria pico durante edición: (sin medir)
- Latencia de reflow por keystroke: (sin medir)
