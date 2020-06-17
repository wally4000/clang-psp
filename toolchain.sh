#!/bin/bash 

#PSP Development Toolchain deployment script
#Copyright PSPDev Team 2020
#Maintained by Wally
#This script is designed to be deployed automatically via CI, new binaries are offered via CI

#Note this entire script will need to be run as root.

##Dependancies
function fetch_tools
{
apt-get -y install llvm clang clang-tools git
}

## Configure Rust - This will end up in /root/whatever
function fetch_rust
{
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
cp "~/.cargo/bin/pack-pbp" "/usr/local/pspdev/psp/sdk/bin"
cp "~/.cargo/bin/mksfo" "/usr/local/pspdev/psp/sdk/bin"
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

fetch_tools
fetch_rust
populateSDK
fetch_newlib

