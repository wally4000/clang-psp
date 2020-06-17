#!/bin/bash 

#PSP Development Toolchain deployment script
#Copyright PSPDev Team 2020
#Maintained by Wally
#This script is designed to be deployed automatically via CI, new binaries are offered via CI

#Note this entire script will need to be run as root.

# To make it easier to update clang via CI.
CLANG_VER=10

##LLVM / Clang
function fetch_clang
{
    echo "Fetching Clang"
bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

# LLVM
apt-get -y install libllvm-$CLANG_VER-ocaml-dev libllvm$CLANG_VER llvm-$CLANG_VER llvm-$CLANG_VER-dev llvm-$CLANG_VER-doc llvm-$CLANG_VER-examples llvm-$CLANG_VER-runtime
# Clang and co
apt-get -y install clang-$CLANG_VER clang-tools-$CLANG_VER clang-$CLANG_VER-doc libclang-common-$CLANG_VER-dev libclang-$CLANG_VER-dev libclang1-$CLANG_VER clang-format-$CLANG_VER python-clang-$CLANG_VER clangd-$CLANG_VER
# libfuzzer, lldb, lld (linker), libc++, OpenMP
apt-get -y install libfuzzer-$CLANG_VER-dev lldb-$CLANG_VER lld-$CLANG_VER libc++-$CLANG_VER-dev libc++abi-$CLANG_VER-dev libomp-$CLANG_VER-dev

apt-get -y install git texi2html
}

## Configure Rust - This will end up in /root/whatever
function fetch_rust
{
    echo "Fetching Rust"
    ##Deploy rust without interaction
curl https://sh.rustup.rs -sSf | sh -s -- -y

export PATH=$PATH:$HOME/.cargo/bin
source $HOME/.cargo/env

rustup set profile complete
rustup toolchain install nightly
rustup default nightly && rustup component add rust-src
rustup update
cargo install cargo-psp
}

function populateSDK
{
    echo "Populate SDK"
#Setup Directories
mkdir "/usr/local/pspdev" "/usr/local/pspdev/psp/" "/usr/local/pspdev/psp/sdk/" "/usr/local/pspdev/psp/sdk/include" "/usr/local/pspdev/psp/sdk/share/" "/usr/local/pspdev/psp/sdk/lib/" "/usr/local/pspdev/psp/sdk/bin"

#Fetch PSPSDK
git clone git://github.com/pspdev/pspsdk

#Move Samples
rm pspsdk/src/samples/Makefile.am
mv pspsdk/src/samples /usr/local/pspdev/psp/sdk/samples 
#Remove libc folder to avoid conflicts
rm -rf pspsdk/src/libc
#find and move headers to appropriate directory
find pspsdk/src -name '*.h' -exec  mv '{}' /usr/local/pspdev/psp/sdk/include \;

cp -r "resources/cmake" "/usr/local/pspdev/psp/sdk/share"
cp -r "resources/lib" "/usr/local/pspdev/psp/sdk/"
cp "~/root/.cargo/bin/pack-pbp" "/usr/local/pspdev/psp/sdk/bin"
cp "/root/.cargo/bin/mksfo" "/usr/local/pspdev/psp/sdk/bin"
}

#Fetch current compatible newlib 1.20 for PSP and patch for clang
function fetch_newlib
{
git clone --single-branch --branch newlib-1_20_0-PSP git://github.com/pspdev/newlib/

#Patch Newlib - Temporary until patches are done upstream
cd newlib
patch -p1 < ../patches/newlib-clang.patch
 mkdir build && cd build
CC=clang-$CLANG_VER ../configure AR_FOR_TARGET=llvm-ar-$CLANG_VER AS_FOR_TARGET=llvm-as-$CLANG_VER RANLIB_FOR_TARGET=llvm-ranlib-$CLANG_VER CC_FOR_TARGET=clang-$CLANG_VER CXX_FOR_TARGET=clang++-$CLANG_VER --target=psp --enable-newlib-iconv --enable-newlib-multithread --enable-newlib-mb --prefix=/usr/local/pspdev
make -j6
make -j6 install
}

fetch_clang
fetch_rust
populateSDK
fetch_newlib

