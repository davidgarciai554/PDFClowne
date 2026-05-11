# Stack tecnologico PDFClowne

## Estado

PDFClowne es una aplicacion nativa de escritorio basada en C++ y Qt/QML.
El visor actual debe seguir funcionando como prioridad maxima. Esta nota
documenta la arquitectura preparada; no implica que todas las areas esten
implementadas de extremo a extremo.

## Restricciones

- No usar Apryse/PDFTron.
- No usar Electron ni convertir PDFClowne en una app web.
- No usar Java.
- No introducir servicios cloud obligatorios.
- Mantener C++ + Qt/QML como base principal.
- Mantener MuPDF como motor principal de renderizado.
- Usar dependencias open source o gratuitas.

## Stack aprobado

| Tecnologia | Uso |
| --- | --- |
| C++17/C++20 | Logica de negocio, servicios y motores PDF |
| Qt 6 / QML | Interfaz, modelos y puente C++/QML |
| MuPDF | Renderizado, visor y extraccion basica de texto |
| PoDoFo | Formularios AcroForm, firma digital y objetos PDF internos |
| QPDF | Validacion, reparacion, split/merge, cifrado y normalizacion |
| Tesseract + Leptonica | OCR opcional |
| OpenSSL | Criptografia para firma digital |
| LibreOffice headless/UNO | Exportacion futura a ODT/DOCX |
| CMake | Configuracion de build |
| Ninja / VS 2022 | Compilacion en Windows |

## Arquitectura modular

Las interfaces abstractas viven en `src/services/`. Separan contratos de
servicio de las implementaciones concretas para que cada dependencia opcional
pueda activarse o desactivarse sin romper el visor.

| Servicio | Motor previsto | Estado |
| --- | --- | --- |
| `PdfRenderService` | MuPDF | Contrato preparado; visor actual usa `PdfDocument` y controladores backend |
| `PdfFormService` | PoDoFo | Contrato preparado para AcroForm |
| `PdfSignatureService` | PoDoFo + OpenSSL | Contrato preparado para firma visual y digital |
| `PdfAnnotationService` | In-memory / MuPDF | Contrato preparado; existe controlador backend de anotaciones |
| `PdfEditService` | PDFium, detras de flag | Contrato preparado para edicion visual de texto |
| `PdfOcrService` | Tesseract + Leptonica | Contrato preparado; OCR completo pendiente |
| `PdfStructureService` | QPDF | Contrato preparado para operaciones estructurales |
| `PdfExportService` | LibreOffice headless/UNO | Contrato preparado para exportacion futura |
| `PdfSaveService` | MuPDF + QPDF | Contrato preparado para guardado seguro |

## Opciones CMake

```cmake
PDFCLOWNE_ENABLE_PDFIUM_EDITING  # OFF por defecto
ENABLE_FORMS                     # ON por defecto
ENABLE_SIGNATURES                # ON por defecto
ENABLE_OCR                       # OFF por defecto
ENABLE_QPDF                      # ON por defecto
ENABLE_PODOFO                    # ON por defecto
ENABLE_LIBREOFFICE_EXPORT        # OFF por defecto
```

Las dependencias opcionales deben ser degradables: si una dependencia no esta
disponible, el build base del visor no debe romperse. Activar una flag no debe
mezclar logica pesada en QML; la funcionalidad se expone desde C++ mediante
tipos claros y APIs validables.

## Guardado seguro

El invariante de guardado es:

```text
write(tempPath) -> canOpenAsPdf(tempPath) -> backup original opcional -> rename(tempPath, finalPath)
```

Por defecto se debe guardar como copia. Sobrescribir el original solo debe
ocurrir con confirmacion explicita del usuario.

## Limitaciones conocidas

- Formularios XFA no estan soportados; el objetivo es AcroForm estandar.
- La edicion de texto se clasifica por elemento como `nativeEditable`,
  `visualEditable`, `ocrEditable` o `notEditable`. Si un PDF de Canva/Figma/
  Illustrator expone texto localizable pero no seguro para reescritura nativa,
  debe caer en `visualEditable` con reemplazo visual persistente, no en
  `noTextFound`.
- La edicion visual de texto todavia tiene limites con fondos complejos,
  ligaduras, Type 3, outlines, OCG y layouts muy fragmentados.
- La firma visual no equivale a firma digital criptografica.
- La firma digital real requiere certificados PFX/P12, OpenSSL y validacion
  compatible con visores externos.
- OCR requiere idiomas y datos de Tesseract instalados localmente.
- La conversion PDF a ODT/DOCX mediante LibreOffice es lossy; puede perder
  posicionamiento, estilos, imagenes o campos de formulario.

## Prioridad de evolucion

1. Mantener estable `viewMode: "view"`.
2. Formularios PDF.
3. Firma visual.
4. Anotaciones.
5. Edicion visual de texto.
6. Firma digital real.
7. OCR.
8. Exportacion ODT/DOCX.
