#!/bin/bash

source "../prefix.sh"

OPENSSL_VERSION="openssl-${OPENSSL_VERNUM}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
    echo "Downloading ${OPENSSL_VERSION}.tar.gz"
    curl -LO https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
    echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

#echo "Unpacking openssl"
#tar xfz "${OPENSSL_VERSION}.tar.gz"

#=============================================================================

#https://ruiying.io/posts/compile-openssl-and-curl-for-android
#https://github.com/openssl/openssl/blob/master/NOTES-ANDROID.md

#https://developer.android.com/ndk/guides/other_build_systems

build() {

# $1: Android Arch Name
# $2: Toolchain architecture


#ARCH = aarch64, armv7a, i686, x86_64
export ARCH=$1

#SSL_ARCH = android-arm, android-arm64, android-mips, android-mip64, android-x86 and android-x86_64
export SSL_ARCH=$2


export TARGET="${ARCH}-linux-android"
if [[ ${ARCH} == "armv7a" ]]; then
    TARGET="${TARGET}eabi"
fi

echo "Building ${OPENSSL_VERSION} for ${ARCH} / ${TARGET} / ${SSL_ARCH}"

initToolchain "${TARGET}"
if [[ ${isValid} == 0 ]]; then
    return
fi

#export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME}"
#export ANDROID_NDK="${ANDROID_NDK_HOME}"
  
export CUR_DIR=${PWD}
  
initCompilerFlags "${ARCH}"
  
export BUILD_DIR="${CUR_DIR}/build-${ARCH}"
export INSTALL_DIR="${CUR_DIR}/install/${ARCH}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}"
mkdir -p "${INSTALL_DIR}"

#export CROSS_COMPILE=${CC}
#--cross-compile-prefix=${CROSS_COMPILE} \

echo "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}"

echo "Unpacking openssl to: ${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}"
tar xfz "${OPENSSL_VERSION}.tar.gz" -C "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}" --strip-components=1
        
cd "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}"
        
./Configure "${SSL_ARCH}" no-shared no-asm \
        -D__ANDROID_API__=${API_VERSION} \
        --prefix="${INSTALL_DIR}" \
        --openssldir="${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}" &> "${BUILD_DIR}/openssl-${ARCH}_configure.log"

#perl configdata.pm --dump

echo "Running make"

make depend >> "${BUILD_DIR}/openssl-${ARCH}_make_depend.log" 2>&1
make -j4  >> "${BUILD_DIR}/openssl-${ARCH}_make.log" 2>&1
make install_sw >> "${BUILD_DIR}/openssl-${ARCH}_make_install_sw.log" 2>&1
#make install  >> "${BUILD_DIR}/openssl-${ARCH}_make_install.log" 2>&1
make clean  >> "${BUILD_DIR}/openssl-${ARCH}_make_clean.log" 2>&1

cd ${CUR_DIR}

mkdir -p "lib/${ARCH}"
#mkdir -p "lib/${ARCH}/include"
#mkdir -p "lib/${ARCH}/include/openssl"

#cp "${INSTALL_DIR}/lib/libssl.a" "lib/$ARCH/libssl.a"
#cp "${INSTALL_DIR}/lib/libcrypto.a" "lib/$ARCH/libcrypto.a"
#cp -a "${INSTALL_DIR}/include/openssl/." "lib/$ARCH/include/openssl/"

cp ${INSTALL_DIR}/lib/*.a ./lib/${ARCH}/

rm -rf "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}"
#rm -rf "${BUILD_DIR}"

}


echo "======================================="
echo "==== Run OpenSSL build for Android ===="
echo "======================================="

mkdir -p "lib"

####################################################
# Install standalone toolchain x86

build "i686" "android-x86"

####################################################
# Install standalone toolchain x86_64

build "x86_64" "android-x86_64"

################################################################
# Install standalone toolchain arm64

build "aarch64" "android-arm64"

################################################################
# Install standalone toolchain armv7a

build "armv7a" "android-arm"


#rm -rf "${OPENSSL_VERSION}"

echo "Done"
