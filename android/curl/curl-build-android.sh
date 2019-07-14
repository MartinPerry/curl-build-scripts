#!/bin/bash


source "../prefix.sh"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
    echo "Downloading ${CURL_VERSION}.tar.gz"
    curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
    echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

OPENSSL="${PWD}/../openssl"
NGHTTP2="${PWD}/../nghttp2"

build() {

# $1: Toolchain Name
# $2: Toolchain architecture
# $3: Android arch
# $4: host for configure
# $5: additional CPP flags

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
--arch=$3 \
--force




NGHTTP2LIB="-L${NGHTTP2}/install/${2}"
#NGHTTP2LIB=""

export PATH="${PLATFORM_PREFIX}/bin:${PATH}"

export CPPFLAGS="-fPIE -I${PLATFORM_PREFIX}/include ${CFLAGS} -I${ANDROID_NDK}/sources/android/cpufeatures -DCURL_STATICLIB $5"
export LDFLAGS="-fPIE -L${PLATFORM_PREFIX}/lib ${NGHTTP2LIB}"
export CXXFLAGS=""
export PKG_CONFIG_PATH="${PLATFORM_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
export TARGET_HOST="${4}"
export CC="$TARGET_HOST-clang"
export CXX="$TARGET_HOST-clang++"
if [ "$ENABLE_CCACHE" ]; then
    export CC="ccache $TARGET_HOST-clang"
    export CXX="ccache $TARGET_HOST-clang++"
fi

export LD="${TARGET_HOST}-ld"
export AR="${TARGET_HOST}-ar"
export AS="${TARGET_HOST}-as"
export RANLIB="${TARGET_HOST}-ranlib"
export STRIP="${TARGET_HOST}-strip"
export NM="${TARGET_HOST}-nm"
export CHOST="${TARGET_HOST}"

INSTALL_DIR="${PWD}/install/${2}"

path="${PWD}/${CURL_VERSION}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_DIR}"

cd "${BUILD_DIR}"

echo "Building ${CURL_VERSION} for ${2}"


sh ${path}/configure --prefix="${INSTALL_DIR}" \
        --disable-shared --disable-smtp --disable-pop3 --disable-imap \
        --disable-ftp --disable-tftp --disable-telnet --disable-rtsp \
        --disable-ldap --disable-manual \
        --disable-debug --disable-gopher --disable-dict --disable-sspi \
        --enable-static --enable-libgcc --enable-ipv6 \
        --without-zlib --without-librtmp --without-gnutls --without-polarssl \
        --without-mbedtls --without-cyassl --without-nss --without-axtls \
        --with-random=/dev/urandom \
        --with-ssl="${OPENSSL}/install/${2}" \
        --with-nghttp2="${NGHTTP2}/install/${2}" \
        --host="${TARGET_HOST}" &> "${BUILD_DIR}/curl-${2}_configure.log"

make clean  >> "${BUILD_DIR}/curl-${2}_make_clean.log" 2>&1
make -j4  >> "${BUILD_DIR}/curl-${2}_make.log" 2>&1
make install  >> "${BUILD_DIR}/curl-${2}_make_install.log" 2>&1


cd ..

mkdir -p "lib/${2}"

cp ${INSTALL_DIR}/lib/*.a ./lib/$2/

rm -rf ${PLATFORM_PREFIX}
rm -rf ${BUILD_DIR}


popd > /dev/null
}


echo "===================================="
echo "==== Run curl build for Android ===="
echo "===================================="

mkdir -p "lib"

source "../build-include.sh"


rm -rf "${CURL_VERSION}"

echo "done"

