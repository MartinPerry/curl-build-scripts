#!/bin/bash


set -e

source "../prefix.sh"


if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
    echo "Downloading ${OPENSSL_VERSION}.tar.gz"
    curl -LO https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
    echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

#=============================================================================


build() {

# $1: Toolchain Name
# $2: Toolchain architecture
# $3: Android arch
# $4: host for configure
# $5: additional CPP flags
# $6: configure architecture

pushd . > /dev/null


echo "preparing ${1} toolchain"

if [[ ! -d "$ANDROID_NDK_ROOT/platforms/android-${API_VERSION}/arch-${3}" ]]; then
    echo "Architecture ${3} not exist for API ${API_VERSION}"
    return
fi


export PLATFORM_PREFIX="${PWD}/${2}-toolchain"
export BUILD_DIR="${PWD}/build-${2}"


#https://developer.android.com/ndk/guides/standalone_toolchain.html
$ANDROID_NDK_ROOT/build/tools/make_standalone_toolchain.py \
    --api=${API_VERSION} \
    --install-dir=${PLATFORM_PREFIX} \
    --stl=libc++ \
    --arch=${3} \
    --force
  
export PATH=${PLATFORM_PREFIX}/bin:${PATH}

#export CFLAGS="-D__ANDROID_API__=26"
export CPPFLAGS="-fPIE -I${PLATFORM_PREFIX}/include ${CFLAGS} -I${ANDROID_NDK}/sources/android/cpufeatures ${5}"
export LDFLAGS="-fPIE -L${PLATFORM_PREFIX}/lib"
export PKG_CONFIG_PATH="${PLATFORM_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
export TARGET_HOST="${4}"
export CC="${TARGET_HOST}-clang"
export CXX="${TARGET_HOST}-clang++"
if [ "${ENABLE_CCACHE}" ]; then
    export CC="ccache ${TARGET_HOST}-clang"
    export CXX="ccache ${TARGET_HOST}-clang++"
fi

export SYSROOT="${PLATFORM_PREFIX}/sysroot"
export CROSS_SYSROOT="${SYSROOT}"
export LINK="${CXX}"
export LD="${TARGET_HOST}-ld"
export AR="${TARGET_HOST}-ar"
export RANLIB="${TARGET_HOST}-ranlib"
export STRIP="${TARGET_HOST}-strip"

export ANDROID_SYSROOT="${SYSROOT}"
export CROSS_SYSROOT="${SYSROOT}"
export NDK_SYSROOT="${SYSROOT}"

#export CROSS_COMPILE="${4}-"
#export ANDROID_DEV="$ANDROID_NDK_ROOT/platforms/android-26/arch-${3}/usr"

echo "Building ${OPENSSL_VERSION} for ${2} / ${6}"

INSTALL_DIR="${PWD}/install/${2}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${OPENSSL_VERSION}-${2}"
mkdir -p "${INSTALL_DIR}"

cd "${PWD}/${OPENSSL_VERSION}"

perl ./configure "${6}" no-shared no-asm \
        --prefix="${INSTALL_DIR}" \
        --openssldir="${BUILD_DIR}/${OPENSSL_VERSION}-${2}" &> "${BUILD_DIR}/openssl-${2}_configure.log"

#remove -mandroid switch for build on Mac with clang
export LC_ALL=C
export LANG=C
sed -e s/\-mandroid//g Makefile > Makefile_android
mv Makefile_android Makefile
#=====

make depend >> "${BUILD_DIR}/openssl-${2}_make_depend.log" 2>&1
make -j4  >> "${BUILD_DIR}/openssl-${2}_make.log" 2>&1
make install_sw >> "${BUILD_DIR}/openssl-${2}_make_install_sw.log" 2>&1
#make install  >> "${BUILD_DIR}/openssl-${2}_make_install.log" 2>&1
make clean  >> "${BUILD_DIR}/openssl-${2}_make_clean.log" 2>&1

cd ..

mkdir -p "lib/${2}"
#mkdir -p "lib/${2}/include"
#mkdir -p "lib/${2}/include/openssl"

#cp "${INSTALL_DIR}/lib/libssl.a" "lib/$2/libssl.a"
#cp "${INSTALL_DIR}/lib/libcrypto.a" "lib/$2/libcrypto.a"
#cp -a "${INSTALL_DIR}/include/openssl/." "lib/$2/include/openssl/"

cp ${INSTALL_DIR}/lib/*.a ./lib/$2/


rm -rf "${PLATFORM_PREFIX}"
rm -rf "${BUILD_DIR}"

popd > /dev/null
}


echo "======================================="
echo "==== Run OpenSSL build for Android ===="
echo "======================================="

mkdir -p "lib"

####################################################
# Install standalone toolchain x86

build "x86" "x86" "x86" "i686-linux-android" "" "android-x86"

####################################################
# Install standalone toolchain x86_64

build "x86_64" "x86_64" "x86_64" "x86_64-linux-android" "" "android64"


################################################################
# Install standalone toolchain ARMeabi

build "ARMeabi" "armeabi" "arm" "arm-linux-androideabi" "" "android"

################################################################
# Install standalone toolchain ARMeabi-v7a

build "ARMeabi-v7a" "armeabi-v7a" "arm" "arm-linux-androideabi" "-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3" "android"

################################################################
# Install standalone toolchain ARM64-v8a

build "ARM64-v8a" "arm64-v8a" "arm64" "aarch64-linux-android" "" "android64-aarch64"

################################################################
# Install standalone toolchain MIPS

#build "MIPS" "mips" "mips" "mipsel-linux-android" ""

################################################################
# Install standalone toolchain MIPS64

#build "MIPS64" "mips64" "mips64" "mips64el-linux-android" ""

rm -rf "${OPENSSL_VERSION}"

echo "Done"
