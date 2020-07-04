set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR mips)

set(triple mips-unknown-linux)
set (CMAKE_SYSROOT /usr/mipsel-sony-psp/psp)


set(CMAKE_C_COMPILER clang)
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_CXX_COMPILER_TARGET ${triple})

set(CMAKE_C_FLAGS "--config /usr/mipsel-sony-psp/psp/sdk/lib/clang.conf -fgnuc-version=0")
set(CMAKE_CXX_FLAGS "--config /usr/mipsel-sony-psp/psp/sdk/lib/clang.conf -fgnuc-version=0" )

