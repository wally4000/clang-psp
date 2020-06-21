#!/bin/bash 

#PSP Development Toolchain deployment script
#Copyright PSPDev Team 2020 and designed by Wally
#This script is designed to be deployed automatically via CI, new binaries are offered via CI

#Note this entire script will need to be run as root.

#TODO Fetch ncurses-dev / libusb-1.0 and readline-dev packages

CLANG_VER="10" ## Change this when a new version of llvm / clang becomes avaliable 
BASE_DIR="$PWD"
BUILD_DIR="$BASE_DIR/build"
RUST_URL="https://github.com/overdrivenpotato/rust-psp"
PSPSDK_URL="https://github.com/wally4000/pspsdk" #This is temporary until the SDK is stable and we can merge back to base
NEWLIB_URL="https://github.com/NT-Bourgeois-Iridescence-Technologies/newlib"
PSPLINK_URL="https://github.com/pspdev/psplinkusb"

PREFIX="/usr/mipsel-sony-psp"


function fetch_clang
{
    bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

    # LLVM & Clang
    apt-get -y install libllvm-$CLANG_VER-ocaml-dev libllvm$CLANG_VER llvm-$CLANG_VER llvm-$CLANG_VER-dev llvm-$CLANG_VER-doc llvm-$CLANG_VER-examples llvm-$CLANG_VER-runtime
    apt-get -y install clang-$CLANG_VER clang-tools-$CLANG_VER clang-$CLANG_VER-doc libclang-common-$CLANG_VER-dev libclang-$CLANG_VER-dev libclang1-$CLANG_VER clang-format-$CLANG_VER python-clang-$CLANG_VER clangd-$CLANG_VER
    # libfuzzer, lldb, lld (linker), libc++, OpenMP
    apt-get -y install libfuzzer-$CLANG_VER-dev lldb-$CLANG_VER lld-$CLANG_VER libc++-$CLANG_VER-dev libc++abi-$CLANG_VER-dev libomp-$CLANG_VER-dev

    apt-get -y install git texi2html 
}

function prep_sources
{
    git clone $RUST_URL
    git clone $PSPSDK_URL
    git clone $NEWLIB_URL
    git clone $PSPLINK_URL
}
## Configure Rust - This will fall into root
function fetch_rust
{
    curl https://sh.rustup.rs -sSf | sh -s -- -y

    export PATH=$PATH:$HOME/.cargo/bin
    source $HOME/.cargo/env
    rustup set profile complete
    rustup toolchain install nightly
    rustup default nightly && rustup component add rust-src
    rustup update
    cargo install cargo-psp
}

function compile_libpsp
{
    cargo install xargo

    cat << EOF > rust-psp/psp/Xargo.toml
    [target.mipsel-sony-psp.dependencies.core]
    [target.mipsel-sony-psp.dependencies.alloc]
    [target.mipsel-sony-psp.dependencies.panic_unwind]
    stage = 1
EOF

    cd rust-psp/psp
    xargo rustc --features stub-only --target mipsel-sony-psp -- -C opt-level=3 -C panic=abort
    cd $BUILD_DIR
}

function populateSDK
{
    #Setup Directories
    mkdir -p "$PREFIX/psp/sdk/bin"
    mkdir "$PREFIX/psp/bin" "$PREFIX/psp/sdk/include" "$PREFIX/psp/sdk/share" "$PREFIX/psp/sdk/lib"

    cd pspsdk
    ./bootstrap
    mkdir build; cd build
    ../configure PSP_CC=clang PSP_CFLAGS="--config $PREFIX/psp/sdk/lib/clang.conf" PSP_CXX=clang++ PSP_AS=llvm-as PSP_LD=ld.lld PSP_AR=llvm-ar PSP_NM=llvm-nm PSP_RANLIB=llvm-ranlib --with-pspdev=$PREFIX --disable-sonystubs --disable-psp-graphics --disable-psp-libc
    make install-data

    cp -r "$BASE_DIR/resources/cmake" "$PREFIX/psp/sdk/share"
    cp "/root/.cargo/bin/pack-pbp" "$PREFIX/psp/sdk/bin"
    cp "/root/.cargo/bin/mksfo" "$PREFIX/psp/sdk/bin"
    cp "$BASE_DIR/build/rust-psp/target/mipsel-sony-psp/debug/libpsp.a" "$PREFIX/psp/sdk/lib"
    
    cd $BUILD_DIR
}

function fetch_newlib
{
cd newlib
mkdir build && cd build
CC=clang-$CLANG_VER ../configure AR_FOR_TARGET=llvm-ar-$CLANG_VER AS_FOR_TARGET=llvm-as-$CLANG_VER RANLIB_FOR_TARGET=llvm-ranlib-$CLANG_VER CC_FOR_TARGET=clang-$CLANG_VER CXX_FOR_TARGET=clang++-$CLANG_VER --target=psp --enable-newlib-iconv --enable-newlib-multithread --enable-newlib-mb --prefix=$PREFIX
make -j6
make -j6 install
cd $BUILD_DIR
}

function compileSDK
{
    cd $BUILD_DIR/pspsdk/build
    make && make install
    cd $BUILD_DIR
    cp -r "$BASE_DIR/resources/lib" "$PREFIX/psp/sdk/"
}

function fetch_psplink
{
    ## Will fail if libusb 1.0 is not present
    clang-$CLANG_VER psplinkusb/usbhostfs_pc/main.c -Ipsplinkusb/usbhostfs  -DPC_SIDE -D_FILE_OFFSET_BITS=64 -lusb -lpthread -o $PREFIX/bin/usbhostfs_pc
    clang++-$CLANG_VER psplinkusb/pspsh/*.C -Ipsplinkusb/psplink -D_PCTERM -lreadline -lcurses -o $PREFIX/bin/pspsh
}

mkdir build && cd build

prep_sources
fetch_clang
fetch_rust
compile_libpsp
populateSDK
fetch_newlib
compileSDK
fetch_psplink