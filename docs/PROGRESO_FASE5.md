# PROGRESO FASE 5 — EDICIÓN DE TEXTO PDFCLOWNE

> **Fuente única de verdad del estado de la Fase 5.** Este archivo se actualiza
> tras cada acción significativa. Las tareas completadas se eliminan de
> "Pendientes" y se resumen en "Histórico". El archivo se hace más corto con
> el tiempo, no más largo.

---

## 📍 Estado actual

- **Sub-fase activa**: 5.0 (Setup)
- **Última actualización**: 2026-05-06 15:39
- **Última acción**: Añadido `vcpkg.json` con dependencias de Qt/PDFium/PoDoFo/QPDF/spdlog
- **Próxima acción planificada**: Configurar `CMakeLists.txt` con `find_package(unofficial-pdfium)`

---

## 🔧 En progreso ahora

> Solo UNA tarea aquí a la vez. Si tienes que pausar para investigar algo,
> anótalo y vuelve a esta tarea.

(ninguna tarea iniciada todavía)

---

## 📋 Pendientes — Sub-fase 5.0: Setup

- [ ] Configurar `CMakeLists.txt` con `find_package(unofficial-pdfium)`
- [ ] Verificar que el paquete pdfium de vcpkg expone `fpdf_edit.h` y `fpdf_text.h`
      (si no, decidir entre compilar PDFium desde fuente o usar pdfium-binaries)
- [ ] Crear estructura de carpetas según §2.3 del prompt
- [ ] Implementar `PdfiumInitializer` con `std::call_once` y `std::recursive_mutex`
- [ ] Implementar macro `PDFIUM_LOCK()` en header global
- [ ] Test "hello world" de PDFium: cargar PDF, contar páginas, imprimir
- [ ] Confirmar que la app sigue compilando y arrancando sin regresiones de Fase 1

## 📋 Pendientes — Sub-fase 5.1: Extracción de page objects

- [ ] Definir structs `PdfTextRun`, `PdfTextLine`, `PdfTextBlock` (§4.1)
- [ ] Implementar `PdfPageObjectExtractor::extractTextRunsFromPage` (§4.2)
- [ ] Implementar `readUnicodeString` con conversión UTF-16 → QString (§4.3)
- [ ] Aplicar filtros de runs no editables (§4.4)
- [ ] Visualización debug: dibujar bboxes en rojo sobre el render
- [ ] Test unitario `TestPdfPageObjectExtractor` con `simple_paragraph.pdf`
- [ ] Test unitario con `mixed_fonts.pdf`
- [ ] Test unitario con `scanned.pdf` (debe retornar lista vacía)

## 📋 Pendientes — Sub-fase 5.2: Agrupación

- [ ] Implementar `groupRunsIntoLines` (§5.1)
- [ ] Implementar `groupLinesIntoBlocks` (§5.2)
- [ ] Implementar `finalizeBlock` con dominantes y alineación (§5.3)
- [ ] Crear `EditingHeuristics.h` con todas las constantes (§5.4)
- [ ] Visualización debug: bloques en azul, líneas en verde
- [ ] Test unitario `TestTextBlockBuilder` cubriendo: 1 línea / 2 líneas
      mismo bloque / 2 líneas distintos bloques / multi-columna
- [ ] Tunear thresholds con corpus de PDFs reales

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
**Decisión:** usar `qtbase`, `qtdeclarative` y `qtwebengine` con feature `pdf`, además de `pdfium`, `podofo`, `qpdf` y `spdlog`.
**Razón:** evita un manifest que no resuelva en vcpkg estándar; `Qt Quick` lo aporta `qtdeclarative` y `Qt PDF` está empaquetado como feature `pdf` de `qtwebengine`.
**Trade-off aceptado:** `qtwebengine[pdf]` puede hacer el bootstrap más pesado que una instalación manual de Qt.
**Reversible:** sí, si el proyecto adopta un registro/overlay que exponga puertos `qt6-*` o si se decide mantener Qt fuera de vcpkg.

---

## ⚠️ Bloqueos / issues abiertos

> Problemas encontrados que requieren resolución antes de avanzar.
> Mover a "Histórico" cuando se resuelvan.

(sin bloqueos)

---

## 📚 Histórico (resumen de tareas completadas)

> Una línea por tarea completada. Formato: `YYYY-MM-DD — [Sub-fase X.Y] descripción breve — commit-hash`

2026-05-06 — [Sub-fase 5.0] añadido manifest vcpkg con dependencias base — 49180cc

---

## 🧪 Estado de tests

- Tests unitarios: 0 / ~25 estimados
- Tests de integración: 0 / 5 estimados
- PDFs de corpus en `tests/pdfs/`: 0 / 9

---

## 📊 Métricas de salud del módulo (actualizar cuando aplique)

- LOC del módulo de edición: 0
- Tiempo de extracción en `large_doc_500pages.pdf`: (sin medir)
- Memoria pico durante edición: (sin medir)
- Latencia de reflow por keystroke: (sin medir)
