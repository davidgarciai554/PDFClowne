Package: harfbuzz[core,freetype]:x64-windows@14.2.0#2

**Host Environment**

- Host: x64-windows
- Compiler: MSVC 19.44.35225.0
- CMake Version: 4.3.2
-    vcpkg-tool version: 2026-04-08-e0612b42ce44e55a0e630f2ee9d3c533a63d8bc1
    vcpkg-scripts version: 77826283b4 2026-05-06 (5 days ago)

**To Reproduce**

`vcpkg install `

**Failure logs**

```
-- Found Python version '3.14.2 at D:/Aplicaciones/vcpkg/downloads/tools/python/python-3.14.2-x64-1/python.exe'
-- Using meson: D:/Aplicaciones/vcpkg/downloads/tools/meson-1.9.0-99f340/meson.py
Downloading https://github.com/harfbuzz/harfbuzz/archive/14.2.0.tar.gz -> harfbuzz-harfbuzz-14.2.0.tar.gz
Successfully downloaded harfbuzz-harfbuzz-14.2.0.tar.gz
-- Extracting source D:/Aplicaciones/vcpkg/downloads/harfbuzz-harfbuzz-14.2.0.tar.gz
-- Applying patch fix-eol-mismatch.diff
-- Using source at D:/Aplicaciones/vcpkg/buildtrees/harfbuzz/src/14.2.0-927b2ed351.clean
-- Using cached msys2-mingw-w64-x86_64-pkgconf-1~2.5.1-1-any.pkg.tar.zst
-- Using cached msys2-msys2-runtime-3.6.5-1-x86_64.pkg.tar.zst
-- Using msys root at D:/Aplicaciones/vcpkg/downloads/tools/msys2/3e71d1f8e22ab23f
-- Configuring x64-windows-dbg
-- Getting CMake variables for x64-windows
-- Loading CMake variables from D:/Aplicaciones/vcpkg/buildtrees/harfbuzz/cmake-get-vars_C_CXX-x64-windows.cmake.log
-- Configuring x64-windows-dbg done
-- Configuring x64-windows-rel
-- Configuring x64-windows-rel done
-- Package x64-windows-dbg
CMake Error at scripts/cmake/vcpkg_execute_required_process.cmake:127 (message):
    Command failed: D:\\Aplicaciones\\vcpkg\\downloads\\tools\\ninja-1.13.2-windows\\ninja.exe install -v
    Working Directory: D:/Aplicaciones/vcpkg/buildtrees/harfbuzz/x64-windows-dbg
    Error code: 1181
    See logs for more information:
      D:\Aplicaciones\vcpkg\buildtrees\harfbuzz\package-x64-windows-dbg-out.log

Call Stack (most recent call first):
  D:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/share/vcpkg-tool-meson/vcpkg_install_meson.cmake:33 (vcpkg_execute_required_process)
  ports/harfbuzz/portfile.cmake:117 (vcpkg_install_meson)
  scripts/ports.cmake:206 (include)



```

<details><summary>D:\Aplicaciones\vcpkg\buildtrees\harfbuzz\package-x64-windows-dbg-out.log</summary>

```
[1/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-paint-bounded.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-paint-bounded.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-paint-bounded.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[2/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-number.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-number.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-number.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[3/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-common.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-common.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-common.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[4/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-blob.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-blob.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-blob.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[5/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-draw.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-draw.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-draw.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[6/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-paint-extents.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-paint-extents.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-paint-extents.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[7/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-buffer-verify.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-buffer-verify.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-buffer-verify.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[8/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-buffer-serialize.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-buffer-serialize.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-buffer-serialize.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[9/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-map.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-map.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-map.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[10/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-paint.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-paint.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-paint.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[11/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-fallback-shape.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-fallback-shape.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-fallback-shape.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
...
Skipped 568 lines
...
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[63/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-cff-common.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-cff-common.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-cff-common.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[64/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-input.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-input.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-input.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[65/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-cff2-to-cff1.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-cff2-to-cff1.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-cff2-to-cff1.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[66/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-ot-face.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-ot-face.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-ot-face.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[67/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne\\" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "2/vcpkg_installed/x64-windows/debug/../include" "2/vcpkg_installed/x64-windows/debug/../include/libpng16" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz.dll.p\hb-static.cc.pdb" /Fosrc/harfbuzz.dll.p/hb-static.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-static.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include' ignored
cl : Command line warning D9024 : unrecognized source file type '2/vcpkg_installed/x64-windows/debug/../include/libpng16', object file assumed
cl : Command line warning D9027 : source file '2/vcpkg_installed/x64-windows/debug/../include/libpng16' ignored
cl : Command line warning D9030 : '/showIncludes' is incompatible with multiprocessing; ignoring /MP switch
[68/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-cff2.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-cff2.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-cff2.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[69/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-cff1.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-cff1.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-cff1.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[70/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/link.exe"  /MACHINE:x64 /OUT:src/harfbuzz.dll src/harfbuzz.dll.p/hb-aat-layout.cc.obj src/harfbuzz.dll.p/hb-aat-map.cc.obj src/harfbuzz.dll.p/hb-blob.cc.obj src/harfbuzz.dll.p/hb-buffer-serialize.cc.obj src/harfbuzz.dll.p/hb-buffer-verify.cc.obj src/harfbuzz.dll.p/hb-buffer.cc.obj src/harfbuzz.dll.p/hb-common.cc.obj src/harfbuzz.dll.p/hb-draw.cc.obj src/harfbuzz.dll.p/hb-paint.cc.obj src/harfbuzz.dll.p/hb-paint-bounded.cc.obj src/harfbuzz.dll.p/hb-paint-extents.cc.obj src/harfbuzz.dll.p/hb-face.cc.obj src/harfbuzz.dll.p/hb-face-builder.cc.obj src/harfbuzz.dll.p/hb-fallback-shape.cc.obj src/harfbuzz.dll.p/hb-font.cc.obj src/harfbuzz.dll.p/hb-map.cc.obj src/harfbuzz.dll.p/hb-number.cc.obj src/harfbuzz.dll.p/hb-ot-cff1-table.cc.obj src/harfbuzz.dll.p/hb-ot-cff2-table.cc.obj src/harfbuzz.dll.p/hb-ot-color.cc.obj src/harfbuzz.dll.p/hb-ot-face.cc.obj src/harfbuzz.dll.p/hb-ot-font.cc.obj src/harfbuzz.dll.p/hb-outline.cc.obj src/harfbuzz.dll.p/OT_Var_VARC_VARC.cc.obj src/harfbuzz.dll.p/hb-ot-layout.cc.obj src/harfbuzz.dll.p/hb-ot-map.cc.obj src/harfbuzz.dll.p/hb-ot-math.cc.obj src/harfbuzz.dll.p/hb-ot-meta.cc.obj src/harfbuzz.dll.p/hb-ot-metrics.cc.obj src/harfbuzz.dll.p/hb-ot-name.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-arabic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-default.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-hangul.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-hebrew.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-indic-table.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-indic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-khmer.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-myanmar.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-syllabic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-thai.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-use.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-vowel-constraints.cc.obj src/harfbuzz.dll.p/hb-ot-shape-fallback.cc.obj src/harfbuzz.dll.p/hb-ot-shape-normalize.cc.obj src/harfbuzz.dll.p/hb-ot-shape.cc.obj src/harfbuzz.dll.p/hb-ot-tag.cc.obj src/harfbuzz.dll.p/hb-ot-var.cc.obj src/harfbuzz.dll.p/hb-set.cc.obj src/harfbuzz.dll.p/hb-shape-plan.cc.obj src/harfbuzz.dll.p/hb-shape.cc.obj src/harfbuzz.dll.p/hb-shaper.cc.obj src/harfbuzz.dll.p/hb-static.cc.obj src/harfbuzz.dll.p/hb-style.cc.obj src/harfbuzz.dll.p/hb-ucd.cc.obj src/harfbuzz.dll.p/hb-unicode.cc.obj src/harfbuzz.dll.p/hb-ft.cc.obj "-INCREMENTAL" "/release" "/nologo" "/DEBUG" "/PDB:src\harfbuzz.pdb" "/DLL" "/IMPLIB:src\harfbuzz.lib" "-machine:x64" "-nologo" "-debug" "/LIBPATH:D:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/debug/lib" "2/vcpkg_installed/x64-windows/debug/lib" "/LIBPATH:D:/Aplicaciones/PDFClowne\\" "freetyped.lib" "kernel32.lib" "user32.lib" "gdi32.lib" "winspool.lib" "shell32.lib" "ole32.lib" "oleaut32.lib" "uuid.lib" "comdlg32.lib" "advapi32.lib"
FAILED: [code=1181] src/harfbuzz.dll src/harfbuzz.pdb 
"C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/link.exe"  /MACHINE:x64 /OUT:src/harfbuzz.dll src/harfbuzz.dll.p/hb-aat-layout.cc.obj src/harfbuzz.dll.p/hb-aat-map.cc.obj src/harfbuzz.dll.p/hb-blob.cc.obj src/harfbuzz.dll.p/hb-buffer-serialize.cc.obj src/harfbuzz.dll.p/hb-buffer-verify.cc.obj src/harfbuzz.dll.p/hb-buffer.cc.obj src/harfbuzz.dll.p/hb-common.cc.obj src/harfbuzz.dll.p/hb-draw.cc.obj src/harfbuzz.dll.p/hb-paint.cc.obj src/harfbuzz.dll.p/hb-paint-bounded.cc.obj src/harfbuzz.dll.p/hb-paint-extents.cc.obj src/harfbuzz.dll.p/hb-face.cc.obj src/harfbuzz.dll.p/hb-face-builder.cc.obj src/harfbuzz.dll.p/hb-fallback-shape.cc.obj src/harfbuzz.dll.p/hb-font.cc.obj src/harfbuzz.dll.p/hb-map.cc.obj src/harfbuzz.dll.p/hb-number.cc.obj src/harfbuzz.dll.p/hb-ot-cff1-table.cc.obj src/harfbuzz.dll.p/hb-ot-cff2-table.cc.obj src/harfbuzz.dll.p/hb-ot-color.cc.obj src/harfbuzz.dll.p/hb-ot-face.cc.obj src/harfbuzz.dll.p/hb-ot-font.cc.obj src/harfbuzz.dll.p/hb-outline.cc.obj src/harfbuzz.dll.p/OT_Var_VARC_VARC.cc.obj src/harfbuzz.dll.p/hb-ot-layout.cc.obj src/harfbuzz.dll.p/hb-ot-map.cc.obj src/harfbuzz.dll.p/hb-ot-math.cc.obj src/harfbuzz.dll.p/hb-ot-meta.cc.obj src/harfbuzz.dll.p/hb-ot-metrics.cc.obj src/harfbuzz.dll.p/hb-ot-name.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-arabic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-default.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-hangul.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-hebrew.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-indic-table.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-indic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-khmer.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-myanmar.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-syllabic.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-thai.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-use.cc.obj src/harfbuzz.dll.p/hb-ot-shaper-vowel-constraints.cc.obj src/harfbuzz.dll.p/hb-ot-shape-fallback.cc.obj src/harfbuzz.dll.p/hb-ot-shape-normalize.cc.obj src/harfbuzz.dll.p/hb-ot-shape.cc.obj src/harfbuzz.dll.p/hb-ot-tag.cc.obj src/harfbuzz.dll.p/hb-ot-var.cc.obj src/harfbuzz.dll.p/hb-set.cc.obj src/harfbuzz.dll.p/hb-shape-plan.cc.obj src/harfbuzz.dll.p/hb-shape.cc.obj src/harfbuzz.dll.p/hb-shaper.cc.obj src/harfbuzz.dll.p/hb-static.cc.obj src/harfbuzz.dll.p/hb-style.cc.obj src/harfbuzz.dll.p/hb-ucd.cc.obj src/harfbuzz.dll.p/hb-unicode.cc.obj src/harfbuzz.dll.p/hb-ft.cc.obj "-INCREMENTAL" "/release" "/nologo" "/DEBUG" "/PDB:src\harfbuzz.pdb" "/DLL" "/IMPLIB:src\harfbuzz.lib" "-machine:x64" "-nologo" "-debug" "/LIBPATH:D:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/debug/lib" "2/vcpkg_installed/x64-windows/debug/lib" "/LIBPATH:D:/Aplicaciones/PDFClowne\\" "freetyped.lib" "kernel32.lib" "user32.lib" "gdi32.lib" "winspool.lib" "shell32.lib" "ole32.lib" "oleaut32.lib" "uuid.lib" "comdlg32.lib" "advapi32.lib"
LINK : warning LNK4075: ignoring '/INCREMENTAL' due to '/RELEASE' specification
LINK : fatal error LNK1181: cannot open input file '2\vcpkg_installed\x64-windows\debug\lib.obj'
[71/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-raster.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-raster.dll.p\hb-raster-image.cc.pdb" /Fosrc/harfbuzz-raster.dll.p/hb-raster-image.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-raster-image.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[72/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-raster.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-raster.dll.p\hb-raster-draw.cc.pdb" /Fosrc/harfbuzz-raster.dll.p/hb-raster-draw.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-raster-draw.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[73/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-raster.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-raster.dll.p\hb-raster.cc.pdb" /Fosrc/harfbuzz-raster.dll.p/hb-raster.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-raster.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[74/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-vector.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-vector.dll.p\hb-zlib.cc.pdb" /Fosrc/harfbuzz-vector.dll.p/hb-zlib.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-zlib.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[75/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-raster.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-raster.dll.p\hb-raster-paint.cc.pdb" /Fosrc/harfbuzz-raster.dll.p/hb-raster-paint.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-raster-paint.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[76/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-gpu.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-gpu.dll.p\hb-static.cc.pdb" /Fosrc/harfbuzz-gpu.dll.p/hb-static.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-static.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[77/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-vector.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-vector.dll.p\hb-vector.cc.pdb" /Fosrc/harfbuzz-vector.dll.p/hb-vector.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-vector.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[78/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-static.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-static.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-static.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[79/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-vector.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-vector.dll.p\hb-vector-draw.cc.pdb" /Fosrc/harfbuzz-vector.dll.p/hb-vector-draw.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-vector-draw.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[80/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-plan-var.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-plan-var.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-plan-var.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[81/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-plan.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-plan.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-plan.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[82/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-serialize.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-serialize.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-serialize.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[83/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\graph_gsubgpos-context.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/graph_gsubgpos-context.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/graph/gsubgpos-context.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[84/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-plan-layout.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-plan-layout.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-plan-layout.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[85/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-table-cff.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-table-cff.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-table-cff.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[86/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-table-var.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-table-var.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-table-var.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[87/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-raster.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-raster.dll.p\hb-static.cc.pdb" /Fosrc/harfbuzz-raster.dll.p/hb-static.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-static.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[88/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-table-color.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-table-color.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-table-color.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[89/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[90/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-table-other.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-table-other.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-table-other.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
[91/129] "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-Isrc\harfbuzz-subset.dll.p" "-Isrc" "-I..\src\14.2.0-927b2ed351.clean\src" "-I." "-I..\src\14.2.0-927b2ed351.clean" "-ID:/Aplicaciones/PDFClowne 2/vcpkg_installed/x64-windows/include" "/MDd" "/nologo" "/showIncludes" "/utf-8" "/Zc:__cplusplus" "/W2" "/EHs-c-" "/std:c++14" "/permissive-" "/Zi" "/wd4244" "/bigobj" "/utf-8" "-DHAVE_CONFIG_H" "-nologo" "-DWIN32" "-D_WINDOWS" "-utf-8" "-GR" "-EHsc" "-MP" "-MDd" "-Z7" "-Ob0" "-Od" "-RTC1" "-DHB_DLL_EXPORT" "/Fdsrc\harfbuzz-subset.dll.p\hb-subset-table-layout.cc.pdb" /Fosrc/harfbuzz-subset.dll.p/hb-subset-table-layout.cc.obj "/c" ../src/14.2.0-927b2ed351.clean/src/hb-subset-table-layout.cc
cl : Command line warning D9025 : overriding '/EHs' with '/EHs-'
cl : Command line warning D9025 : overriding '/EHc' with '/EHc-'
cl : Command line warning D9025 : overriding '/Z7' with '/Zi'
cl : Command line warning D9025 : overriding '/EHs-' with '/EHs'
cl : Command line warning D9025 : overriding '/EHc-' with '/EHc'
cl : Command line warning D9025 : overriding '/Zi' with '/Z7'
ninja: build stopped: subcommand failed.
```
</details>

**Additional context**

<details><summary>vcpkg.json</summary>

```
{
  "$schema": "https://raw.githubusercontent.com/microsoft/vcpkg-tool/main/docs/vcpkg.schema.json",
  "name": "pdfclowne",
  "version-semver": "2.0.0",
  "dependencies": [
    "qtbase",
    "qtdeclarative",
    {
      "name": "qtwebengine",
      "features": [
        "pdf"
      ]
    },
    "qpdf",
    "podofo",
    "spdlog",
    "freetype",
    "harfbuzz"
  ]
}

```
</details>
