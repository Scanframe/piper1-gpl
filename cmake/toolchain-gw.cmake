# Windows x86_64 cross-compiler toolchain file.
set(CMAKE_SYSTEM_NAME "Windows")
set(CMAKE_C_COMPILER_LAUNCHER "/usr/bin/ccache")
set(CMAKE_CXX_COMPILER_LAUNCHER "/usr/bin/ccache")
# Use mingw 64-bit compilers.
set(CMAKE_C_COMPILER "x86_64-w64-mingw32-gcc-posix")
set(CMAKE_CXX_COMPILER "x86_64-w64-mingw32-c++-posix")
set(CMAKE_RC_COMPILER "x86_64-w64-mingw32-windres")
set(CMAKE_RANLIB "x86_64-w64-mingw32-ranlib")
set(CMAKE_FIND_ROOT_PATH "/usr/x86_64-w64-mingw32")
# Adjust the default behavior of the find commands:
# search headers and libraries in the target environment
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Search programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_C_COMPILER_LAUNCHER "/usr/bin/ccache")
set(CMAKE_CXX_COMPILER_LAUNCHER "/usr/bin/ccache")
# Paths to set the WINEPATH with to execute the cross-compiled executable with Wine.
set(WINE_PATH_EXT
	"/usr/lib/gcc/x86_64-w64-mingw32/13-posix" #[[libstdc++-6.dll, libgcc_s_seh-1.dll]]
	"/usr/x86_64-w64-mingw32/lib" #[[libwinpthread-1.dll]]
	"${CMAKE_CURRENT_SOURCE_DIR}/libpiper/lib/onnxruntime-win-x64-${ONNXRUNTIME_VERSION}/lib" #[[onnxruntime.dll]]
)
message(VERBOSE "Required WINEPATH: ${WINE_PATH_EXT}")