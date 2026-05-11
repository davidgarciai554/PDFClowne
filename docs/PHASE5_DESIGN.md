# Fase 5 - Edicion visual de texto PDF

Este documento resume el diseno actual de la Fase 5. No afirma paridad con un editor PDF profesional: la fase deja preparada una arquitectura nativa para extraccion, edicion visual inicial, fallback de fuentes, guardado seguro y trabajo pesado fuera del hilo de UI.

## Stack

- C++/Qt/QML como base de aplicacion.
- MuPDF se mantiene como motor principal del visor existente.
- PDFium se usa solo cuando `PDFCLOWNE_ENABLE_PDFIUM_EDITING=ON` para edicion directa de objetos de texto.
- QPDF, PoDoFo, Tesseract y LibreOffice siguen siendo dependencias opcionales del roadmap.

## Flujo

1. `EditingController` carga el documento PDFium y expone estado a QML.
2. `PdfExtractionWorker` vive en un `QThread`, extrae runs con `PdfPageObjectExtractor` y agrupa bloques con `TextBlockBuilder`.
3. `PdfPageObjectExtractor` recorre objetos de texto directos y, si esa ruta no recupera el texto visible, usa `FPDF_TEXTPAGE` por caracteres como fallback para exports complejos de Canva/Figma/Illustrator. Esos bloques se clasifican como `visualEditable`.
4. `TextBlockModel` publica los bloques de la pagina actual a `PdfViewer.qml`, incluyendo `sourceKind`, `editability`, `editStrategy` y `unicodeQuality`.
5. `EditableTextBox.qml` permite seleccionar, editar texto y reflow visual basico.
6. `FontFallbackManager` selecciona fuentes compatibles y puede devolver rutas de fuentes libres empaquetadas.
7. `PdfSaveWorker` vive en un `QThread`, reextrae paginas sucias, llama a `PdfWriteBackEngine` y guarda con temp -> validar -> rename.

## Threading

`PdfExtractionWorker` y `PdfSaveWorker` son `QObject` movidos con `moveToThread()` a un `QThread` creado por `EditingController`. Ambos emiten:

- `progressChanged(int, QString)` para barra de progreso y texto de estado.
- `finished(...)` cuando terminan correctamente.
- `failed(QString)` para errores recuperables.

El modelo QML solo se actualiza en el hilo principal, cuando el worker devuelve sus datos. El handle `FPDF_DOCUMENT` sigue siendo propiedad de `EditingController`; los workers no lo cierran.

## Estado QML

`EditingController` expone:

- `ready`
- `busy`
- `extracting`
- `saving`
- `progress`
- `statusMessage`
- `scannedDocumentSuspected`
- `currentPageBlocks`

`PdfViewer.qml` muestra una barra de progreso durante extraccion/guardado y un aviso de OCR solo si una pagina no devuelve bloques nativos, visuales ni free text activos. Los textos nuevos usan `qsTr()` y los mensajes C++ nuevos usan `tr()`.

## Guardado seguro

El guardado conserva el invariante del proyecto:

```text
write(tempPath) -> canOpenAsPdf(tempPath) -> rename(tempPath, finalPath)
```

`saveDocument()` rechaza rutas vacias y rechaza sobrescribir directamente el PDF cargado. La UI debe pedir una ruta de copia o una confirmacion explicita antes de reemplazar el original.

## Estrategias de edicion

- `nativeEditable`: se puede reescribir el objeto de texto original.
- `visualEditable`: se puede editar mediante reemplazo visual persistente. Es la ruta por defecto para texto recuperado por fallback estructurado, fuentes subset o exports complejos.
- `ocrEditable`: requiere OCR regional o de pagina antes de editar.
- `notEditable`: no hay region interpretable o el caso no esta soportado.

Los bloques con `isEditable=false` no aceptan `updateBlockText()` ni `reflowText()`. Los bloques `visualEditable` si aceptan edicion, pero `PdfWriteBackEngine` usa mascara persistente en vez de borrar/recrear el stream original.

## Limitaciones

- La mascara persistente usa fondo blanco; paginas con fondos complejos necesitan backdrop tiles o muestreo local.
- La geometria de ciertos bloques puede quedar sobredimensionada cuando el PDF usa objetos de texto muy largos, kerning complejo o matrices no triviales.
- Texto vectorizado, Type 3, OCG complejas y XFA siguen fuera del flujo editable completo.
- La deteccion de PDF escaneado es heuristica: si una pagina no devuelve runs ni bloques, se sugiere OCR.
- El OCR real pertenece a la Fase 6 y todavia no sustituye automaticamente la capa de texto.
- El guardado modifica objetos de texto, pero no reconstruye layout avanzado como ligaduras, tracking exacto o particion semantica original.
- La exportacion ODT/DOCX queda fuera de esta fase y se mantiene para la futura fase LibreOffice/OpenOffice.

## Siguiente pulido visual recomendado

1. Hacer que el bloque activo oculte el texto original con una mascara blanca ajustada al bbox.
2. Revisar conversion pantalla/PDF y altura de reflow para evitar cajas demasiado altas.
3. Separar seleccion, hover y modo escritura para que solo el bloque activo pinte texto editable.
4. Mejorar contraste y espaciado del inspector en tema oscuro.
5. Unificar toolbar superior e inspector para reducir controles duplicados.
