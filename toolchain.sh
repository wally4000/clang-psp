#!/bin/bash 

#PSP Development Toolchain deployment script
#Copyright PSPDev Team 2020
#Maintained by Wally
#This script is designed to be deployed automatically via CI, new binaries are offered via CI

#Note this entire script will need to be run as root.

##LLVM / Clang
function fetch_clang
{
    echo "Fetching Clang"
bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

# LLVM
apt-get -y install libllvm-10-ocaml-dev libllvm10 llvm-10 llvm-10-dev llvm-10-doc llvm-10-examples llvm-10-runtime
# Clang and co
apt-get -y install clang-10 clang-tools-10 clang-10-doc libclang-common-10-dev libclang-10-dev libclang1-10 clang-format-10 python-clang-10 clangd-10
# libfuzzer, lldb, lld (linker), libc++, OpenMP
apt-get -y install libfuzzer-10-dev lldb-10 lld-10 libc++-10-dev libc++abi-10-dev libomp-10-dev

apt-get -y install git
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
mkdir "/usr/local/pspdev" "/usr/local/pspdev/psp/" "/usr/local/pspdev/psp/sdk/" "/usr/local/pspdev/psp/sdk/include" "/usr/local/pspdev/psp/sdk/share/" "/usr/local/pspdev/psp/sdk/lib/"

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
}

#Fetch current compatible newlib 1.20 for PSP and patch for clang
function fetch_newlib
{
git clone --single-branch --branch newlib-1_20_0-PSP git://github.com/pspdev/newlib/

#Patch Newlib - Temporary until patches are done upstream
cd newlib
patch -p1 < ../patches/newlib-clang.patch
 mkdir build && cd build
../configure AR_FOR_TARGET=llvm-ar AS_FOR_TARGET=llvm-as RANLIB_FOR_TARGET=llvm-ranlib CC_FOR_TARGET=clang CXX_FOR_TARGET=clang++ --target=psp --enable-newlib-iconv --enable-newlib-multithread --enable-newlib-mb --prefix=/usr/local/pspdev
make -j6
make -j6 install
}

fetch_clang
fetch_rust
populateSDK
fetch_newlib

