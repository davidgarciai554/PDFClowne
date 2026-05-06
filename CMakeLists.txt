cmake_minimum_required(VERSION 3.22)

project(PDFClowne VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick)

option(PDFCLOWNE_ENABLE_PDFIUM_EDITING "Enable direct PDFium-backed PDF text editing" OFF)

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
endif()

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
    src/backend/PdfRenderImageProvider.cpp
    src/backend/PdfDocument.cpp
    src/core/pdf/PdfiumInitializer.cpp
)

if(WIN32)
    list(APPEND CPP_SOURCES resources/app.rc)
endif()

set(CPP_HEADERS
    src/backend/DesktopIntegration.h
    src/backend/DocumentRenderController.h
    src/backend/DocumentSearchController.h
    src/backend/Logger.h
    src/backend/PdfRenderImageProvider.h
    src/backend/PdfDocument.h
    src/core/pdf/PdfiumInitializer.h
)

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
        src/qml/Theme.qml
    RESOURCES
        src/qml/ShortcutCatalog.js
        resources/resources.qrc
)

target_include_directories(PDFClowne PRIVATE
    src/backend
    src/core/pdf
    ${MUPDF_INCLUDE_DIR}
)

target_link_libraries(PDFClowne PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    ${MUPDF_LIBRARIES}
)

if(PDFCLOWNE_ENABLE_PDFIUM_EDITING)
    target_compile_definitions(PDFClowne PRIVATE PDFCLOWNE_ENABLE_PDFIUM_EDITING=1)

    target_link_libraries(PDFClowne PRIVATE
        Qt6::Pdf
        ${PDFCLOWNE_PDFIUM_TARGET}
        qpdf::libqpdf
        podofo::podofo
        spdlog::spdlog
    )
endif()

set_target_properties(PDFClowne PROPERTIES
    WIN32_EXECUTABLE TRUE
)

if(WIN32)
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
