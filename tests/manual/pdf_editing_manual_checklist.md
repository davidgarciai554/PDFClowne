# PDF Editing Manual Checklist

Use the files in `tests/pdfs/` and repeat the checks at 50%, 100%, 200%, and 300% zoom.

1. Open the PDF and switch to Editar. The UI must stay responsive while extraction progress is shown.
2. Select text near the upper-left and lower-right corners of a block. Hit testing must match the visible text.
3. Double-click a block and edit text. The original rendered text underneath must be covered by the edit layer.
4. Scroll deep into a long document and repeat selection/editing. The overlay must remain aligned.
5. Test a document with mixed page sizes. Bboxes must follow each page's own dimensions.
6. Use Guardar copia, reopen the saved copy automatically, and verify the edited text remains in the PDF.
7. Confirm the active page, zoom, edit mode, and approximate scroll position are not abruptly reset.
8. Launch `PDFClowne.exe` from a clean deployed build folder by double click and confirm no runtime DLL error appears.
