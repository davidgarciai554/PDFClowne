cmake_minimum_required(VERSION 3.22)

project(PDFClowne VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Qml Svg)
find_package(harfbuzz CONFIG REQUIRED)
find_package(Freetype REQUIRED)

set(PDFCLOWNE_ENABLE_PDFIUM_EDITING OFF CACHE BOOL "PDFium editing is retired; MuPDF PdfEditSessionController is the only text editing pipeline." FORCE)
option(ENABLE_OCR "Enable OCR fallback" OFF)
option(ENABLE_FORMS "Enable PDF AcroForm filling via PoDoFo" ON)
option(ENABLE_SIGNATURES "Enable PDF visual and digital signatures" ON)
option(ENABLE_QPDF "Enable QPDF for structural PDF operations (split/merge/repair/encrypt)" ON)
option(ENABLE_PODOFO "Enable PoDoFo for AcroForm and deep PDF manipulation" ON)
option(ENABLE_LIBREOFFICE_EXPORT "Enable LibreOffice headless export to ODT/DOCX (requires LO installed)" OFF)

if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    find_package(Qt6 REQUIRED COMPONENTS Pdf)
    find_package(unofficial-pdfium CONFIG QUIET)
    if(TARGET unofficial::pdfium::pdfium)
        set(PDFCLOWNE_PDFIUM_TARGET unofficial::pdfium::pdfium)
    else()
        find_package(PDFium REQUIRED)
        set(PDFCLOWNE_PDFIUM_TARGET pdfium)
    endif()
    find_package(qpdf CONFIG REQUIRED)
    find_package(podofo CONFIG REQUIRED)
    find_package(spdlog CONFIG REQUIRED)
    set(_PDFCLOWNE_QPDF_FOUND TRUE)
    set(_PDFCLOWNE_PODOFO_FOUND TRUE)
endif()

# Independent QPDF — only searched if PDFIUM block didn't already find it
if(ENABLE_QPDF AND NOT _PDFCLOWNE_QPDF_FOUND)
    find_package(qpdf CONFIG QUIET)
    if(qpdf_FOUND)
        set(_PDFCLOWNE_QPDF_FOUND TRUE)
    else()
        message(STATUS "ENABLE_QPDF=ON but qpdf not found — PdfStructureService will be a stub")
        set(ENABLE_QPDF OFF)
    endif()
endif()

# Independent PoDoFo — only searched if PDFIUM block didn't already find it
if(ENABLE_PODOFO AND NOT _PDFCLOWNE_PODOFO_FOUND)
    find_package(podofo CONFIG QUIET)
    if(podofo_FOUND)
        set(_PDFCLOWNE_PODOFO_FOUND TRUE)
    else()
        message(STATUS "ENABLE_PODOFO=ON but podofo not found — PdfFormService/PdfSignatureService will be stubs")
        set(ENABLE_PODOFO OFF)
    endif()
endif()

set(MUPDF_VERSION_TAG "1.25.6" CACHE STRING "Stable MuPDF version/tag expected by this build")
set(MUPDF_ROOT "" CACHE PATH "MuPDF installation root")
set(MUPDF_EXTRA_LIBRARIES "" CACHE STRING "Additional MuPDF libraries required by this build")

set(MUPDF_DEBUG_HINTS
    "${MUPDF_ROOT}/platform/win32/x64/Debug"
    "$ENV{MUPDF_ROOT}/platform/win32/x64/Debug"
    "${MUPDF_ROOT}/build/debug"
    "$ENV{MUPDF_ROOT}/build/debug"
)

set(MUPDF_RELEASE_HINTS
    "${MUPDF_ROOT}/platform/win32/x64/Release"
    "$ENV{MUPDF_ROOT}/platform/win32/x64/Release"
    "${MUPDF_ROOT}/lib"
    "$ENV{MUPDF_ROOT}/lib"
    "${MUPDF_ROOT}/build/release"
    "$ENV{MUPDF_ROOT}/build/release"
)

find_path(MUPDF_INCLUDE_DIR
    NAMES mupdf/fitz.h
    HINTS
        "${MUPDF_ROOT}/include"
        "$ENV{MUPDF_ROOT}/include"
)

find_library(MUPDF_LIBRARY_DEBUG
    NAMES mupdf libmupdf
    HINTS ${MUPDF_DEBUG_HINTS}
)

find_library(MUPDF_LIBRARY_RELEASE
    NAMES mupdf libmupdf
    HINTS ${MUPDF_RELEASE_HINTS}
)

find_library(MUPDF_THIRD_LIBRARY_DEBUG
    NAMES mupdf-third libmupdf-third
    HINTS ${MUPDF_DEBUG_HINTS}
)

find_library(MUPDF_THIRD_LIBRARY_RELEASE
    NAMES mupdf-third libmupdf-third
    HINTS ${MUPDF_RELEASE_HINTS}
)

if(NOT MUPDF_INCLUDE_DIR)
    message(FATAL_ERROR "MuPDF headers were not found. Set MUPDF_ROOT to a MuPDF source or install tree that contains include/mupdf/fitz.h.")
endif()

if(NOT MUPDF_LIBRARY_RELEASE)
    message(FATAL_ERROR "MuPDF release library was not found. Expected libmupdf under one of: ${MUPDF_RELEASE_HINTS}")
endif()

set(MUPDF_LIBRARY ${MUPDF_LIBRARY_RELEASE})
set(MUPDF_THIRD_LIBRARY ${MUPDF_THIRD_LIBRARY_RELEASE})

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(NOT MUPDF_LIBRARY_DEBUG)
        message(FATAL_ERROR
            "Debug build requires MuPDF debug libraries compiled with /MDd. "
            "Build D:/Aplicaciones/mupdf/platform/win32/mupdf.sln for Debug|x64 "
            "or point MUPDF_ROOT to a MuPDF tree that contains platform/win32/x64/Debug/libmupdf.lib."
        )
    endif()

    set(MUPDF_LIBRARY ${MUPDF_LIBRARY_DEBUG})

    if(MUPDF_THIRD_LIBRARY_RELEASE AND NOT MUPDF_THIRD_LIBRARY_DEBUG)
        message(FATAL_ERROR
            "Debug build also requires libthirdparty built for Debug|x64. "
            "Build D:/Aplicaciones/mupdf/platform/win32/mupdf.sln for Debug|x64 "
            "or provide platform/win32/x64/Debug/libthirdparty.lib under MUPDF_ROOT."
        )
    endif()

    set(MUPDF_THIRD_LIBRARY ${MUPDF_THIRD_LIBRARY_DEBUG})
endif()

set(MUPDF_LIBRARIES ${MUPDF_LIBRARY})
if(MUPDF_THIRD_LIBRARY)
    list(APPEND MUPDF_LIBRARIES ${MUPDF_THIRD_LIBRARY})
endif()
if(MUPDF_EXTRA_LIBRARIES)
    list(APPEND MUPDF_LIBRARIES ${MUPDF_EXTRA_LIBRARIES})
endif()

qt_standard_project_setup(REQUIRES 6.5)

set(CPP_SOURCES
    src/main.cpp
    src/backend/DesktopIntegration.cpp
    src/backend/DocumentRenderController.cpp
    src/backend/DocumentSearchController.cpp
    src/backend/OcrService.cpp
    src/backend/PdfAnnotationController.cpp
    src/backend/PdfFormController.cpp
    src/backend/PdfRenderImageProvider.cpp
    src/backend/PdfDocument.cpp
    src/backend/PdfEditableLayout.cpp
    src/backend/PdfEditCommand.cpp
    src/backend/PdfEditSession.cpp
    src/backend/text/PdfGlyphRunModel.cpp
    src/backend/text/PdfTextExtractor.cpp
    src/backend/text/PdfFontResolver.cpp
    src/backend/text/PdfEditSessionController.cpp
    src/backend/render/PdfGlyphOverlayItem.cpp
    src/backend/render/PdfScratchPageRenderer.cpp
    src/backend/pdf/PdfContentWriter.cpp
    src/backend/pdf/PdfFontResourceWriter.cpp
    src/backend/pdf/PdfSaveCoordinator.cpp
    src/core/editing/FontFallbackManager.cpp
    src/core/editing/PdfExtractionDebugRenderer.cpp
    src/core/editing/TextBlockBuilder.cpp
    src/core/editing/TextBlockModel.cpp
)

if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    list(APPEND CPP_SOURCES
        src/core/editing/PdfPageObjectExtractor.cpp
        src/core/editing/PdfExtractionWorker.cpp
        src/core/editing/PdfSaveWorker.cpp
        src/core/editing/EditingController.cpp
        src/core/editing/FileWriter.cpp
        src/core/editing/PdfWriteBackEngine.cpp
    )
endif()

if(WIN32)
    list(APPEND CPP_SOURCES resources/app.rc)
endif()

set(CPP_HEADERS
    src/backend/DesktopIntegration.h
    src/backend/DocumentRenderController.h
    src/backend/DocumentSearchController.h
    src/backend/Logger.h
    src/backend/OcrService.h
    src/backend/PdfAnnotationController.h
    src/backend/PdfFormController.h
    src/backend/PdfRenderImageProvider.h
    src/backend/PdfDocument.h
    src/backend/PdfEditableLayout.h
    src/backend/PdfEditCommand.h
    src/backend/PdfEditSession.h
    src/backend/PdfTextElement.h
    src/backend/text/PdfGlyphRunModel.h
    src/backend/text/PdfTextExtractor.h
    src/backend/text/PdfFontResolver.h
    src/backend/text/PdfEditSessionController.h
    src/backend/render/PdfGlyphOverlayItem.h
    src/backend/render/PdfScratchPageRenderer.h
    src/backend/pdf/PdfContentWriter.h
    src/backend/pdf/PdfFontResourceWriter.h
    src/backend/pdf/PdfFontWritePlan.h
    src/backend/pdf/PdfSaveCoordinator.h
    src/backend/pdf/PdfTextEditOperation.h
    src/core/editing/EditingHeuristics.h
    src/core/editing/FontFallbackManager.h
    src/core/editing/PdfCoordTransform.h
    src/core/editing/PdfExtractionDebugRenderer.h
    src/core/editing/PdfTextBlock.h
    src/core/editing/PdfTextLine.h
    src/core/editing/PdfTextRun.h
    src/core/editing/TextBlockBuilder.h
    src/core/editing/TextBlockModel.h
    src/core/pdf/PdfiumInitializer.h
    src/services/PdfAnnotationService.h
    src/services/PdfEditService.h
    src/services/PdfExportService.h
    src/services/PdfFormService.h
    src/services/PdfOcrService.h
    src/services/PdfRenderService.h
    src/services/PdfSaveService.h
    src/services/PdfSignatureService.h
    src/services/PdfStructureService.h
)

if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    list(APPEND CPP_HEADERS
        src/core/editing/EditingController.h
        src/core/editing/FileWriter.h
        src/core/editing/PdfExtractionWorker.h
        src/core/editing/PdfPageObjectExtractor.h
        src/core/editing/PdfSaveWorker.h
        src/core/editing/PdfWriteBackEngine.h
    )
endif()

qt_add_executable(PDFClowne ${CPP_SOURCES} ${CPP_HEADERS})

set_source_files_properties(src/qml/Theme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

set_source_files_properties(src/qml/main.qml
    PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)

qt_add_qml_module(PDFClowne
    URI PDFClowne
    VERSION 1.0
    QML_FILES
        src/qml/main.qml
        src/qml/PdfViewer.qml
        src/qml/EditInspector.qml
        src/qml/EditOverlay.qml
        src/qml/EditToolbar.qml
        src/qml/editor/PdfEditOverlay.qml
        src/qml/Theme.qml
        src/qml/ResizeHandles.qml
        src/qml/EditingToolbar.qml
        src/qml/PclToolButton.qml
        src/qml/PclButton.qml
        src/qml/PclComboBox.qml
        src/qml/PclSpinBox.qml
        src/qml/PclCheckBox.qml
        src/qml/PclColorSwatch.qml
        src/qml/FormOverlay.qml
        src/qml/FormInspector.qml
    RESOURCES
        src/qml/ShortcutCatalog.js
        resources/resources.qrc
)

target_include_directories(PDFClowne PRIVATE
    src/backend
    src/backend/text
    src/backend/render
    src/backend/pdf
    src/core/editing
    src/core/pdf
    src/services
    ${MUPDF_INCLUDE_DIR}
)

target_link_libraries(PDFClowne PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
    Freetype::Freetype
    harfbuzz::harfbuzz
    ${MUPDF_LIBRARIES}
)

if(ENABLE_OCR)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_OCR=1)
endif()

if(ENABLE_FORMS)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_FORMS=1)
endif()

if(ENABLE_SIGNATURES)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_SIGNATURES=1)
endif()

if(ENABLE_QPDF AND _PDFCLOWNE_QPDF_FOUND AND NOT PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_QPDF=1)
    target_link_libraries(PDFClowne PRIVATE qpdf::libqpdf)
elseif(ENABLE_QPDF AND _PDFCLOWNE_QPDF_FOUND)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_QPDF=1)
endif()

if(ENABLE_PODOFO AND _PDFCLOWNE_PODOFO_FOUND AND NOT PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_PODOFO=1)
    target_link_libraries(PDFClowne PRIVATE podofo::podofo)
elseif(ENABLE_PODOFO AND _PDFCLOWNE_PODOFO_FOUND)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_PODOFO=1)
endif()

if(ENABLE_LIBREOFFICE_EXPORT)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_LIBREOFFICE_EXPORT=1)
endif()

if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_PDFIUM_EDITING=1)

    target_link_libraries(PDFClowne PRIVATE
        Qt6::Pdf
        ${PDFCLOWNE_PDFIUM_TARGET}
        qpdf::libqpdf
        podofo::podofo
        spdlog::spdlog
    )

    if(WIN32)
        if(DEFINED PDFium_LIBRARY AND EXISTS "${PDFium_LIBRARY}")
            add_custom_command(TARGET PDFClowne POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                    "${PDFium_LIBRARY}"
                    "$<TARGET_FILE_DIR:PDFClowne>"
                COMMENT "Deploying PDFium runtime from PDFium_LIBRARY..."
                VERBATIM
            )
        endif()
    endif()
endif()

enable_testing()

# TextBlockBuilder test — pure Qt, no PDFium required
add_executable(TextBlockBuilderTest
    tests/cpp/TextBlockBuilderTest.cpp
    src/core/editing/TextBlockBuilder.cpp
)

target_include_directories(TextBlockBuilderTest PRIVATE
    src/core/editing
)

target_link_libraries(TextBlockBuilderTest PRIVATE
    Qt6::Core
    Qt6::Gui
)

add_test(NAME TextBlockBuilder COMMAND TextBlockBuilderTest)

add_executable(PdfEditCommandTest
    tests/cpp/PdfEditCommandTest.cpp
    src/backend/PdfEditCommand.cpp
    src/backend/PdfEditSession.cpp
)

target_include_directories(PdfEditCommandTest PRIVATE
    src/backend
)

target_link_libraries(PdfEditCommandTest PRIVATE
    Qt6::Core
)

add_test(NAME PdfEditCommand COMMAND PdfEditCommandTest)

add_executable(PdfEditSessionVisualSnapshotTest
    tests/cpp/PdfEditSessionVisualSnapshotTest.cpp
    src/backend/text/PdfGlyphRunModel.cpp
    src/backend/text/PdfTextExtractor.cpp
    src/backend/text/PdfFontResolver.cpp
    src/backend/text/PdfEditSessionController.cpp
    src/backend/render/PdfScratchPageRenderer.cpp
    src/backend/pdf/PdfContentWriter.cpp
    src/backend/pdf/PdfFontResourceWriter.cpp
    src/backend/pdf/PdfSaveCoordinator.cpp
)

target_include_directories(PdfEditSessionVisualSnapshotTest PRIVATE
    src/backend
    src/backend/text
    src/backend/render
    src/backend/pdf
    ${MUPDF_INCLUDE_DIR}
)

target_link_libraries(PdfEditSessionVisualSnapshotTest PRIVATE
    Qt6::Core
    Qt6::Gui
    Freetype::Freetype
    harfbuzz::harfbuzz
    ${MUPDF_LIBRARIES}
)

add_test(NAME PdfEditSessionVisualSnapshot
    COMMAND PdfEditSessionVisualSnapshotTest "${CMAKE_SOURCE_DIR}/tests/pdfs/01-base.pdf")

function(add_pdf_text_edit_save_test target_name source_file test_name)
    add_executable(${target_name}
        ${source_file}
        src/backend/text/PdfGlyphRunModel.cpp
        src/backend/text/PdfTextExtractor.cpp
        src/backend/text/PdfFontResolver.cpp
        src/backend/text/PdfEditSessionController.cpp
        src/backend/render/PdfScratchPageRenderer.cpp
        src/backend/pdf/PdfContentWriter.cpp
        src/backend/pdf/PdfFontResourceWriter.cpp
        src/backend/pdf/PdfSaveCoordinator.cpp
    )
    target_include_directories(${target_name} PRIVATE
        src/backend
        src/backend/text
        src/backend/render
        src/backend/pdf
        ${MUPDF_INCLUDE_DIR}
    )
    target_link_libraries(${target_name} PRIVATE
        Qt6::Core
        Qt6::Gui
        Freetype::Freetype
        harfbuzz::harfbuzz
        ${MUPDF_LIBRARIES}
    )
    add_test(NAME ${test_name}
        COMMAND ${target_name} "${CMAKE_SOURCE_DIR}/tests/pdfs/01-base.pdf")

    if(WIN32 AND DEFINED VCPKG_INSTALLED_DIR)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            set(_PDFCLOWNE_VCPKG_RUNTIME_DIR "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin")
        else()
            set(_PDFCLOWNE_VCPKG_RUNTIME_DIR "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")
        endif()

        if(EXISTS "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}")
            add_custom_command(TARGET ${target_name} POST_BUILD
                COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/harfbuzz.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/freetyped.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/bz2d.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/libpng16d.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/brotlicommon.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/brotlidec.dll"
                    "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/zd.dll"
                    "$<TARGET_FILE_DIR:${target_name}>"
                COMMENT "Deploying vcpkg runtime dependencies for ${target_name}..."
                VERBATIM
            )
        endif()
    endif()
endfunction()

add_pdf_text_edit_save_test(PdfTextEditSaveSingleLineTest
    tests/cpp/PdfTextEditSaveSingleLineTest.cpp
    PdfTextEditSaveSingleLine)
add_pdf_text_edit_save_test(PdfTextEditSaveMultipleEditsTest
    tests/cpp/PdfTextEditSaveMultipleEditsTest.cpp
    PdfTextEditSaveMultipleEdits)
add_pdf_text_edit_save_test(PdfTextEditSaveUnicodeTest
    tests/cpp/PdfTextEditSaveUnicodeTest.cpp
    PdfTextEditSaveUnicode)
add_pdf_text_edit_save_test(PdfTextEditSaveInPlaceTest
    tests/cpp/PdfTextEditSaveInPlaceTest.cpp
    PdfTextEditSaveInPlace)
add_pdf_text_edit_save_test(PdfTextEditSaveNoWhiteCoverTest
    tests/cpp/PdfTextEditSaveNoWhiteCoverTest.cpp
    PdfTextEditSaveNoWhiteCover)
add_pdf_text_edit_save_test(PdfTextEditSaveReopenExtractionTest
    tests/cpp/PdfTextEditSaveReopenExtractionTest.cpp
    PdfTextEditSaveReopenExtraction)

if(WIN32 AND DEFINED VCPKG_INSTALLED_DIR)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_PDFCLOWNE_VCPKG_RUNTIME_DIR "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin")
    else()
        set(_PDFCLOWNE_VCPKG_RUNTIME_DIR "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")
    endif()

    if(EXISTS "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}")
        add_custom_command(TARGET PdfEditSessionVisualSnapshotTest POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/harfbuzz.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/freetyped.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/bz2d.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/libpng16d.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/brotlicommon.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/brotlidec.dll"
                "${_PDFCLOWNE_VCPKG_RUNTIME_DIR}/zd.dll"
                "$<TARGET_FILE_DIR:PdfEditSessionVisualSnapshotTest>"
            COMMENT "Deploying vcpkg runtime dependencies for PDF edit snapshot tests..."
            VERBATIM
        )
    endif()
endif()

# PDFium-dependent tests
if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    cmake_path(GET PDFium_LIBRARY PARENT_PATH _PDFium_BIN_DIR)
    get_target_property(_spdlog_dll spdlog::spdlog IMPORTED_LOCATION_DEBUG)
    if(_spdlog_dll)
        cmake_path(GET _spdlog_dll PARENT_PATH _VCPKG_DEBUG_BIN_DIR)
    else()
        get_target_property(_spdlog_dll spdlog::spdlog IMPORTED_LOCATION_RELEASE)
        cmake_path(GET _spdlog_dll PARENT_PATH _VCPKG_DEBUG_BIN_DIR)
    endif()
    set(_PDFIUM_TEST_ENVMOD
        "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>;PATH=path_list_prepend:${_PDFium_BIN_DIR};PATH=path_list_prepend:${_VCPKG_DEBUG_BIN_DIR}"
    )

    function(add_pdfium_test target_name source_file test_name)
        add_executable(${target_name}
            ${source_file}
            src/core/editing/PdfPageObjectExtractor.cpp
            src/core/editing/TextBlockBuilder.cpp
            src/core/pdf/PdfiumInitializer.cpp
        )
        target_include_directories(${target_name} PRIVATE src/core/editing src/core/pdf)
        target_link_libraries(${target_name} PRIVATE
            Qt6::Core Qt6::Gui ${PDFCLOWNE_PDFIUM_TARGET} spdlog::spdlog)
        target_compile_definitions(${target_name} PRIVATE
            PDFCLOWNE_ENABLE_PDFIUM_EDITING=1
            PDFCLOWNE_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
        add_test(NAME ${test_name} COMMAND ${target_name})
        set_tests_properties(${test_name} PROPERTIES ENVIRONMENT_MODIFICATION "${_PDFIUM_TEST_ENVMOD}")
    endfunction()

    add_pdfium_test(PdfPageObjectExtractorSimpleParagraphTest
        tests/cpp/PdfPageObjectExtractorSimpleParagraphTest.cpp
        PdfPageObjectExtractorSimpleParagraph)

    add_pdfium_test(PdfPageObjectExtractorMixedFontsTest
        tests/cpp/PdfPageObjectExtractorMixedFontsTest.cpp
        PdfPageObjectExtractorMixedFonts)

    add_pdfium_test(PdfPageObjectExtractorScannedTest
        tests/cpp/PdfPageObjectExtractorScannedTest.cpp
        PdfPageObjectExtractorScanned)

    add_pdfium_test(PdfPageObjectExtractorCanvaRegressionTest
        tests/cpp/PdfPageObjectExtractorCanvaRegressionTest.cpp
        PdfPageObjectExtractorCanvaRegression)

    add_executable(PdfWriteBackIntegrationTest
        tests/cpp/PdfWriteBackIntegrationTest.cpp
        src/core/editing/FileWriter.cpp
        src/core/editing/PdfWriteBackEngine.cpp
        src/core/pdf/PdfiumInitializer.cpp
    )
    target_include_directories(PdfWriteBackIntegrationTest PRIVATE src/core/editing src/core/pdf)
    target_link_libraries(PdfWriteBackIntegrationTest PRIVATE
        Qt6::Core Qt6::Gui ${PDFCLOWNE_PDFIUM_TARGET} spdlog::spdlog)
    target_compile_definitions(PdfWriteBackIntegrationTest PRIVATE PDFCLOWNE_ENABLE_PDFIUM_EDITING=1)
    add_test(NAME PdfWriteBackIntegration COMMAND PdfWriteBackIntegrationTest)
    set_tests_properties(PdfWriteBackIntegration PROPERTIES ENVIRONMENT_MODIFICATION "${_PDFIUM_TEST_ENVMOD}")
endif()

set_target_properties(PDFClowne PROPERTIES
    WIN32_EXECUTABLE TRUE
)

if(WIN32)
    add_custom_command(TARGET PDFClowne POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_RUNTIME_DLLS:PDFClowne>"
            "$<TARGET_FILE_DIR:PDFClowne>"
        COMMAND_EXPAND_LISTS
        COMMENT "Deploying linked runtime dependencies..."
        VERBATIM
    )

    find_program(WINDEPLOYQT windeployqt
        HINTS "${Qt6_DIR}/../../../bin"
              "$ENV{QT6_DIR}/bin"
    )
    if(WINDEPLOYQT)
        add_custom_command(TARGET PDFClowne POST_BUILD
            COMMAND "${WINDEPLOYQT}"
                --qmldir "${CMAKE_SOURCE_DIR}/src/qml"
                --no-translations
                "$<TARGET_FILE:PDFClowne>"
            COMMENT "Deploying Qt dependencies..."
            VERBATIM
        )
    endif()
endif()
