#!/bin/bash 

#PSP Development Toolchain deployment script
#Copyright PSPDev Team 2020 and designed by Wally
#This script is designed to be deployed automatically via CI, new binaries are offered via CI

#Note this entire script will need to be run as root.

CLANG_VER="10" ## Change this when a new version of llvm / clang becomes avaliable 
BASE_DIR="$PWD"

RUST_URL="https://github.com/overdrivenpotato/rust-psp"
PSPSDK_URL="https://github.com/wally4000/pspsdk" #This is temporary until the SDK is stable and we can merge back to base
NEWLIB_URL="git://github.com/NT-Bourgeois-Iridescence-Technologies/newlib"

ROOT_PATH="/usr/mipsel-sony-psp"
function fetch_clang
{
    echo "Fetching Clang"
bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

# LLVM & Clang
    apt-get -y install libllvm-$CLANG_VER-ocaml-dev libllvm$CLANG_VER llvm-$CLANG_VER llvm-$CLANG_VER-dev llvm-$CLANG_VER-doc llvm-$CLANG_VER-examples llvm-$CLANG_VER-runtime
    apt-get -y install clang-$CLANG_VER clang-tools-$CLANG_VER clang-$CLANG_VER-doc libclang-common-$CLANG_VER-dev libclang-$CLANG_VER-dev libclang1-$CLANG_VER clang-format-$CLANG_VER python-clang-$CLANG_VER clangd-$CLANG_VER
    # libfuzzer, lldb, lld (linker), libc++, OpenMP
    apt-get -y install libfuzzer-$CLANG_VER-dev lldb-$CLANG_VER lld-$CLANG_VER libc++-$CLANG_VER-dev libc++abi-$CLANG_VER-dev libomp-$CLANG_VER-dev

    apt-get -y install git texi2html 
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
    git clone $RUST_URL

    cat << EOF > rust-psp/psp/Xargo.toml
    [target.mipsel-sony-psp.dependencies.core]
    [target.mipsel-sony-psp.dependencies.alloc]
    [target.mipsel-sony-psp.dependencies.panic_unwind]
    stage = 1
EOF

    cd rust-psp/psp
    xargo rustc --features stub-only --target mipsel-sony-psp -- -C opt-level=3 -C panic=abort
    cd .. & cd ..

}
function populateSDK
{
#Setup Directories
mkdir -p "$ROOT_PATH/psp/sdk/bin"
mkdir "$ROOT_PATH/psp/bin" "$ROOT_PATH/psp/sdk/include" "$ROOT_PATH/psp/sdk/share" "$ROOT_PATH/psp/sdk/lib"

#Fetch PSPSDK
git clone $PSPSDK_URL

#Move Samples
rm pspsdk/src/samples/Makefile.am
mv pspsdk/src/samples /usr/mipsel-sony-psp/psp/sdk/samples 
#Remove libc folder to avoid conflicts
rm -rf pspsdk/src/libc
#find and move headers to appropriate directory
find pspsdk/src -name '*.h' -exec  mv '{}' /usr/mipsel-sony-psp/psp/sdk/include \;

cp -r "$BASE_DIR/resources/cmake" "$ROOT_PATH/psp/sdk/share"
cp -r "$BASE_DIR/resources/lib" "$ROOT_PATH/psp/sdk/"
cp "/root/.cargo/bin/pack-pbp" "$ROOT_PATH/psp/sdk/bin"
cp "/root/.cargo/bin/mksfo" "$ROOT_PATH/psp/sdk/bin"
cp "rust-psp/target/mipsel-sony-psp/debug/libpsp.a" "$ROOT_PATH/psp/sdk/lib"
clang-$CLANG_VER "$BASE_DIR/src/tools/psp-prxgen.c" -o "$ROOT_PATH/psp/bin/psp-prxgen"
}

function fetch_newlib
{
git clone $NEWLIB_URL

#Patch Newlib - Temporary until patches are done upstream
cd newlib
mkdir build && cd build
CC=clang-$CLANG_VER ../configure AR_FOR_TARGET=llvm-ar-$CLANG_VER AS_FOR_TARGET=llvm-as-$CLANG_VER RANLIB_FOR_TARGET=llvm-ranlib-$CLANG_VER CC_FOR_TARGET=clang-$CLANG_VER CXX_FOR_TARGET=clang++-$CLANG_VER --target=psp --enable-newlib-iconv --enable-newlib-multithread --enable-newlib-mb --prefix=/usr/mipsel-sony-psp
make -j6
make -j6 install
}

mkdir build && cd build

fetch_clang
fetch_rust
compile_libpsp
populateSDK
fetch_newlib
