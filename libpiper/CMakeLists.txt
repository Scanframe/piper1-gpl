# Builds libpiper
cmake_minimum_required(VERSION 3.26)

message(STATUS "SF_COMPILER: ${SF_COMPILER}")
message(STATUS "SF_EXEC_DIR_SUFFIX: $ENV{SF_EXEC_DIR_SUFFIX}")
message(STATUS "SF_EXECUTABLE_DIR: $ENV{SF_EXECUTABLE_DIR}")
message(STATUS "SF_LIBRARY_DIR: $ENV{SF_LIBRARY_DIR}")
message(STATUS "CMAKE_BINARY_DIR: ${CMAKE_BINARY_DIR}")
message(STATUS "CMAKE_RUNTIME_OUTPUT_DIRECTORY: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
message(STATUS "CMAKE_LIBRARY_OUTPUT_DIRECTORY: ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")

project(piper LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(ExternalProject)

# Install location for espeak-ng
set(ESPEAKNG_BUILD_DIR ${CMAKE_BINARY_DIR}/espeak_ng)
set(ESPEAKNG_INSTALL_DIR ${CMAKE_BINARY_DIR}/espeak_ng-install)

if (NOT TARGET espeak_ng_external)

# ucd-tools is built (not installed) by espeak-ng, so we reference its static
# library directly from the build tree. Multi-config generators (e.g. Visual
# Studio) place the output in a per-config subdirectory whose name is only
# known at build time, so resolve it with a $<CONFIG> generator expression.
# Single-config generators (Unix Makefiles, Ninja) write directly into the
# build directory with no subdirectory.
get_property(IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTI_CONFIG)
    set(UCD_CONFIG_SUBDIR "$<CONFIG>/")
else()
    set(UCD_CONFIG_SUBDIR "")
endif()

set(UCD_TOOLS_DIR ${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external-build/src/ucd-tools)

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # MSVC emits .lib files (espeak-ng is re-exported from piper.dll)
    set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/espeak-ng.lib)
    set(UCD_STATIC_LIB ${UCD_TOOLS_DIR}/${UCD_CONFIG_SUBDIR}ucd.lib)
else()
    set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/libespeak-ng.a)
    set(UCD_STATIC_LIB ${UCD_TOOLS_DIR}/${UCD_CONFIG_SUBDIR}libucd.a)
endif()

ExternalProject_Add(espeak_ng_external
    GIT_REPOSITORY https://github.com/espeak-ng/espeak-ng.git
    GIT_TAG 724808c  # 2026-Apr-06
    PREFIX ${ESPEAKNG_BUILD_DIR}
    GIT_SHALLOW TRUE
    CMAKE_ARGS
        # Forward the current toolchain file.
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DCMAKE_INSTALL_PREFIX=${ESPEAKNG_INSTALL_DIR}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DBUILD_SHARED_LIBS:BOOL=OFF
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
        -DUSE_ASYNC:BOOL=OFF
        -DUSE_MBROLA:BOOL=OFF
        -DUSE_LIBSONIC:BOOL=OFF
        -DUSE_LIBPCAUDIO:BOOL=OFF
        -DUSE_KLATT:BOOL=OFF
        -DUSE_SPEECHPLAYER:BOOL=OFF
        -DEXTRA_cmn:BOOL=ON
        -DEXTRA_ru:BOOL=ON
        # Need to explicitly add ucd include directory for CI
        "-DCMAKE_C_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        "-DCMAKE_CXX_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
    BUILD_BYPRODUCTS
        ${ESPEAKNG_STATIC_LIB}
        ${UCD_STATIC_LIB}
    UPDATE_DISCONNECTED TRUE
)

endif ()

include_directories(
    ${ESPEAKNG_INSTALL_DIR}/include
)

# ---- onnxruntime ---

find_package(onnxruntime QUIET)

# Look for onnxruntime files in <root>/lib
if(NOT TARGET onnxruntime::onnxruntime AND NOT DEFINED ONNXRUNTIME_DIR)
    if(NOT DEFINED ONNXRUNTIME_VERSION)
        set(ONNXRUNTIME_VERSION "1.22.0")
    endif()

    if(WIN32)
        # Windows x86-64
        set(ONNXRUNTIME_PREFIX "onnxruntime-win-x64-${ONNXRUNTIME_VERSION}")
        set(ONNXRUNTIME_EXT "zip")
    elseif (APPLE)
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL x86_64)
            # MacOS x86-64
            set(ONNXRUNTIME_PREFIX "onnxruntime-osx-x86_64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL arm64)
            # MacOS Apple Silicon
            set(ONNXRUNTIME_PREFIX "onnxruntime-osx-arm64-${ONNXRUNTIME_VERSION}")
        else()
            message(FATAL_ERROR "Unsupported architecture for onnxruntime")
        endif()

        set(ONNXRUNTIME_EXT "tgz")
    else()
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL x86_64)
            # Linux x86-64
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL aarch64)
            # Linux ARM 64-bit
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL armv7l)
            # Linux ARM 32-bit
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-arm32-${ONNXRUNTIME_VERSION}")
            set(ONNXRUNTIME_URL "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/onnxruntime-linux-arm32-${ONNXRUNTIME_VERSION}.tgz")
        else()
            message(FATAL_ERROR "Unsupported architecture for onnxruntime")
        endif()

        set(ONNXRUNTIME_EXT "tgz")
    endif()

    if(NOT DEFINED ONNXRUNTIME_URL)
        set(ONNXRUNTIME_URL "https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/${ONNXRUNTIME_PREFIX}.${ONNXRUNTIME_EXT}")
    endif()

    set(ONNXRUNTIME_FILENAME "${ONNXRUNTIME_PREFIX}.${ONNXRUNTIME_EXT}")
    set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/${ONNXRUNTIME_PREFIX}")

    if(NOT EXISTS "${ONNXRUNTIME_DIR}")
        if(NOT EXISTS "download/${ONNXRUNTIME_FILENAME}")
            # Download onnxruntime release
            message("Downloading ${ONNXRUNTIME_URL}")
            file(DOWNLOAD "${ONNXRUNTIME_URL}" "download/${ONNXRUNTIME_FILENAME}" STATUS _status SHOW_PROGRESS)
            # First entry in list is the exit code.
            list(GET _status 0 _exitcode)
            # Bailout on failure and delete the file.
            if (NOT _exitcode EQUAL 0)
                # Remove the empty file first when created.
                if(EXISTS "download/${ONNXRUNTIME_FILENAME}")
                    execute_process(COMMAND ${CMAKE_COMMAND} -E rm "download/${ONNXRUNTIME_FILENAME}")
                endif ()
                message(FATAL_ERROR "Download status: ${_status}")
            endif ()
        endif()

        # Extract .zip or .tgz to a directory like lib/onnxruntime-linux-x64-1.22.0/
        file(ARCHIVE_EXTRACT INPUT "download/${ONNXRUNTIME_FILENAME}" DESTINATION "${CMAKE_CURRENT_LIST_DIR}/lib")
    endif()
    # Get the dynamic library files.
    file(GLOB _DynLibFiles "${ONNXRUNTIME_DIR}/lib/*.so*" "${ONNXRUNTIME_DIR}/lib/*.dll")
    # Dynamic libraries are required to be in the executable directory for a Windows application.
    if (WIN32)
        # Check if the global library output directory has been set.
        if (DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
            # Copy the files to the output directory.
            message(STATUS "Copying onnxruntime dynlibs to: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
            file(COPY ${_DynLibFiles} DESTINATION "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
        else ()
            # When not able to copy files, set a cache entry.
            message(STATUS "Writing onnxruntime cache entry 'ONNXRUNTIME_DYNLIB_FILES' with dynlibs.")
           set(ONNXRUNTIME_DYNLIB_FILES "${_DynLibFiles}" CACHE INTERNAL "Location of the onnxruntime dynamic-library files.")
        endif ()
    else ()
        # Check if the global library output directory has been set.
        if (DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
            # Copy the files to the output directory.
            message(STATUS "Copying onnxruntime dynlibs to: ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
            file(COPY ${_DynLibFiles} DESTINATION "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
        else ()
            # When not able to copy files, set a cache entry.
            message(STATUS "Writing onnxruntime cache entry 'ONNXRUNTIME_DYNLIB_FILES' with dynlibs.")
           set(ONNXRUNTIME_DYNLIB_FILES "${_DynLibFiles}" CACHE INTERNAL "Location of the onnxruntime dynamic-library files.")
        endif ()
    endif ()
endif()

if(DEFINED ONNXRUNTIME_DIR)
    find_library(ONNXRUNTIME_LIB NAMES onnxruntime PATHS "${ONNXRUNTIME_DIR}/lib" REQUIRED NO_CMAKE_FIND_ROOT_PATH)
    add_library(onnxruntime::onnxruntime UNKNOWN IMPORTED)
    set_target_properties(onnxruntime::onnxruntime PROPERTIES
        IMPORTED_LOCATION ${ONNXRUNTIME_LIB}
        INTERFACE_INCLUDE_DIRECTORIES ${ONNXRUNTIME_DIR}/include
    )
endif()

# ---- libpiper ---

add_library(piper SHARED ${CMAKE_CURRENT_SOURCE_DIR}/src/piper.cpp)
#set_target_properties(piper PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
target_compile_definitions(piper PRIVATE _PIPER_PKG)
add_library(piper::shared ALIAS piper)

add_dependencies(piper espeak_ng_external)
target_include_directories(piper PUBLIC
    ${ESPEAKNG_INSTALL_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_libraries(piper
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    onnxruntime::onnxruntime
)


# ---- libpiper static ---

add_library(piper-static STATIC ${CMAKE_CURRENT_SOURCE_DIR}/src/piper.cpp)
target_compile_definitions(piper-static PUBLIC _PIPER_ARC)

add_library(piper::static ALIAS piper-static)

add_dependencies(piper-static espeak_ng_external)
target_include_directories(piper-static
  PRIVATE
    ${ESPEAKNG_INSTALL_DIR}/include
    ${ONNXRUNTIME_DIR}/include
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_directories(piper-static
  PUBLIC
    ${ONNXRUNTIME_DIR}/lib
)
target_link_libraries(piper-static
  PRIVATE
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    onnxruntime::onnxruntime
)


# ---- piper exe ---
add_subdirectory(src/main)

# ---- version
file(READ "${CMAKE_CURRENT_LIST_DIR}/../setup.py" SETUP_PY_CONTENTS)
string(REGEX MATCH "version=\"([0-9]+\\.[0-9]+\\.[0-9]+)\"" _ ${SETUP_PY_CONTENTS})
set(PIPER_VERSION ${CMAKE_MATCH_1})

if(PIPER_VERSION)
  message(STATUS "Parsed Piper Version: ${PIPER_VERSION}")
  target_compile_definitions(piper PRIVATE PIPER_VERSION="${PIPER_VERSION}")
else()
  message(WARNING "Could not parse version from setup.py")
endif()

# ---- install ---

include(GNUInstallDirs)

install(TARGETS piper
    DESTINATION ${CMAKE_INSTALL_PREFIX}
)

install(
    FILES ${CMAKE_CURRENT_SOURCE_DIR}/include/piper.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(
    DIRECTORY ${ONNXRUNTIME_DIR}/lib/
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Copy espeak-ng-data
set(ESPEAKNG_DATA_SRC ${CMAKE_BINARY_DIR}/espeak_ng-install/share/espeak-ng-data)
set(ESPEAKNG_DATA_DST ${CMAKE_INSTALL_PREFIX}/espeak-ng-data)

install(
    DIRECTORY ${ESPEAKNG_DATA_SRC}
    DESTINATION ${CMAKE_INSTALL_PREFIX}
)

# ----------------
# Testing
# ----------------
option(PIPER_BUILD_TESTS "Build piper tests" OFF)

if(PIPER_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

#[[
# ---- clang format ---
find_program(CLANG_FORMAT clang-format)

set(CLANG_FORMAT_ARGS "-i" CACHE STRING "Arguments for clang-format")

if(CLANG_FORMAT)
    file(GLOB_RECURSE FORMAT_SOURCES
        "src/*.cpp"
        "src/*.h"
        "src/*.hpp"
        "tests/*.cpp"
        "tests/*.h"
        "tests/*.hpp"
        "include/piper.h"
        "include/piper_impl.hpp"
    )

    add_custom_target(format
        COMMAND ${CLANG_FORMAT} ${CLANG_FORMAT_ARGS} ${FORMAT_SOURCES}
        COMMENT "Formatting C/C++ files with clang-format"
    )
    message(STATUS "Added 'format' target to run clang-format.")
    add_dependencies(piper format)
else()
    message(WARNING "clang-format not found. The 'format' target will not be available.")
endif()
]]

if (BUILD_APPS)
    add_subdirectory(app/cli)
endif ()