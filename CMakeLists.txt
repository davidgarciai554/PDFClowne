cmake_minimum_required(VERSION 3.22)

project(PDFClowne VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick)

set(MUPDF_ROOT "" CACHE PATH "MuPDF installation root")
set(MUPDF_EXTRA_LIBRARIES "" CACHE STRING "Additional MuPDF libraries required by this build")

find_path(MUPDF_INCLUDE_DIR
    NAMES mupdf/fitz.h
    HINTS
        "${MUPDF_ROOT}/include"
        "$ENV{MUPDF_ROOT}/include"
)

find_library(MUPDF_LIBRARY
    NAMES mupdf libmupdf
    HINTS
        "${MUPDF_ROOT}/lib"
        "$ENV{MUPDF_ROOT}/lib"
        "${MUPDF_ROOT}/build/release"
        "$ENV{MUPDF_ROOT}/build/release"
)

find_library(MUPDF_THIRD_LIBRARY
    NAMES mupdf-third libmupdf-third
    HINTS
        "${MUPDF_ROOT}/lib"
        "$ENV{MUPDF_ROOT}/lib"
        "${MUPDF_ROOT}/build/release"
        "$ENV{MUPDF_ROOT}/build/release"
)

if(NOT MUPDF_INCLUDE_DIR OR NOT MUPDF_LIBRARY)
    message(FATAL_ERROR "MuPDF was not found. Install/build MuPDF and set MUPDF_ROOT to its installation directory.")
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
        resources/resources.qrc
)

target_include_directories(PDFClowne PRIVATE
    src/backend
    ${MUPDF_INCLUDE_DIR}
)

target_link_libraries(PDFClowne PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    ${MUPDF_LIBRARIES}
)

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
