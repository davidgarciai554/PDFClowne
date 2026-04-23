# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Release")
  file(REMOVE_RECURSE
  "CMakeFiles\\PDFClowne_autogen.dir\\AutogenUsed.txt"
  "CMakeFiles\\PDFClowne_autogen.dir\\ParseCache.txt"
  "PDFClowne_autogen"
  )
endif()
