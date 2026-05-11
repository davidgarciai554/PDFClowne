# Arquitectura de edicion PDF robusta

PDFClowne mantiene MuPDF como motor principal del visor. La rama actual tambien
puede compilar una ruta de edicion con `PDFCLOWNE_ENABLE_PDFIUM_EDITING=ON`;
esa ruta se usa como extractor/escritor auxiliar, no como reemplazo del visor.

## Estrategias por elemento

- `nativeEditable`: texto directo con fuente, encoding y objeto reutilizables.
- `visualEditable`: texto localizado visualmente, pero no seguro para reescribir
  en el stream original. Se guarda mediante `persistentVisualReplacement`.
- `ocrEditable`: zona sin texto nativo fiable donde OCR puede generar una capa
  editable posterior.
- `notEditable`: caso sin texto ni region interpretable o restringido.

La regla de producto es no usar `noTextFound` cuando existe texto visible
localizable. PDFs complejos de Canva, Figma, Illustrator o InDesign deben caer
en `visualEditable` si no son seguros para `nativeEditable`.

## Pipeline actual

1. `EditingController` carga el documento auxiliar y lanza `PdfExtractionWorker`
   en `QThread`.
2. `PdfPageObjectExtractor` intenta extraer objetos de texto directos.
3. Si esa ruta queda corta, usa `FPDF_TEXTPAGE` por caracteres para recuperar
   texto visible en exports complejos y lo clasifica como `visualEditable`.
4. `TextBlockBuilder` agrupa runs en lineas y bloques, preservando estrategia,
   fuente dominante, color, bboxes y calidad Unicode basica.
5. `TextBlockModel` expone a QML `sourceKind`, `editability`,
   `editStrategy` y `unicodeQuality`.
6. `EditableTextBox.qml` solo renderiza modelo ya preparado; no extrae texto.
7. Al guardar, `PdfWriteBackEngine` usa reescritura nativa solo si el bloque es
   `nativeEditable`; para `visualEditable` inserta mascara persistente y nuevo
   texto encima.

## Limites actuales

- La mascara persistente usa fondo blanco; fondos complejos necesitan backdrop
  tiles o muestreo local.
- La ruta `visualEditable` no reflowea el documento como Word.
- OCR regional, Type 3, outlines, OCG y XFA siguen como fases posteriores.
- QPDF/PoDoFo siguen previstos para validacion y escritura mas profunda; esta
  fase usa la ruta auxiliar ya presente para resolver la regresion de Canva.
