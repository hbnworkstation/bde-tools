# Default compiler-less toolchains for BDE build system.
# The actual compiler for this toolchain is passed via build environment.
#
# Windows, cl

string(CONCAT DEFAULT_CXX_FLAGS
       "/TP "
       "/FS "
       "/MP "
       "/GR "
       "/GT "
       "/nologo "
       "/D_WIN32_WINNT=0x0502 "
       "/DWINVER=0x0502 "
      )
set(CMAKE_CXX_FLAGS ${DEFAULT_CXX_FLAGS} CACHE STRING "Default" FORCE)

string(CONCAT DEFAULT_C_FLAGS
       "/TC "
       "/FS "
       "/MP "
       "/GT "
       "/nologo "
      )
set(CMAKE_C_FLAGS   ${DEFAULT_C_FLAGS}   CACHE STRING "Default" FORCE)


set(CMAKE_CXX_FLAGS_RELEASE         "/O2 /Ob1 /Oi /Ot /GS- /Gs /GF /Gy /DNDEBUG"
    CACHE STRING "Release"        FORCE)
set(CMAKE_CXX_FLAGS_MINSIZEREL      "/O1 /Ob1 /Os /DNDEBUG"
    CACHE STRING "MinSizeRel"     FORCE)
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO  "/O2 /Ob1 /Oi /Ot /GS- /Gs /GF /Gy /Zi /DNDEBUG"
    CACHE STRING "RelWithDebInfo" FORCE)
set(CMAKE_CXX_FLAGS_DEBUG           "/Zi"
    CACHE STRING "Debug"          FORCE)

set(CMAKE_C_FLAGS_RELEASE         "/O2 /Ob1 /Oi /Ot /GS- /Gs /GF /Gy -DNDEBUG"
    CACHE STRING "Release"        FORCE)
set(CMAKE_C_FLAGS_MINSIZEREL      "/O1 /Ob1 /Os /DNDEBUG"
    CACHE STRING "MinSizeRel"     FORCE)
set(CMAKE_C_FLAGS_RELWITHDEBINFO  "/O2 /Ob1 /Oi /Ot /GS- /Gs /GF /Gy /Zi /DNDEBUG"
    CACHE STRING "RelWithDebInfo" FORCE)
set(CMAKE_C_FLAGS_DEBUG           "/Zi"
    CACHE STRING "Debug"          FORCE)
