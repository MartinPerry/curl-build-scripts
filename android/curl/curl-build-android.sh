#!/bin/bash


source "../prefix.sh"

CURL_VERSION="curl-${CURL_VERNUM}"

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

echo "OpenSSL path: ${OPENSSL}"
echo "NGHTTP2 path: ${NGHTTP2}"

build() {

# $1: Android Arch Name


#ARCH = aarch64, armv7a, i686, x86_64
export ARCH=$1

export TARGET="${ARCH}-linux-android"
if [[ ${ARCH} == "armv7a" ]]; then
    TARGET="${TARGET}eabi"
fi

echo "Building ${CURL_VERSION} for ${ARCH} / ${TARGET}"

initToolchain "${TARGET}"
if [[ ${isValid} == 0 ]]; then
    return
fi

export CUR_DIR=${PWD}

initCompilerFlags "${ARCH}"

#export CPPFLAGS="-fPIE ${CFLAGS} ${ADDITIONAL_CPP_FLAGS}"
#export LDFLAGS="-fPIE"

export BUILD_DIR="${CUR_DIR}/build-${ARCH}"
export INSTALL_DIR="${CUR_DIR}/install/${ARCH}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${CURL_VERSION}-${ARCH}"
mkdir -p "${INSTALL_DIR}"

echo "Load OpenSSL from ${OPENSSL}/install/${ARCH}"
echo "Load nghttp2 from ${NGHTTP2}/install/${ARCH}"

cd "${BUILD_DIR}"

sh ${CUR_DIR}/${CURL_VERSION}/configure --prefix="${INSTALL_DIR}" \
        --disable-shared --disable-smtp --disable-pop3 --disable-imap \
        --disable-ftp --disable-tftp --disable-telnet --disable-rtsp \
        --disable-ldap --disable-manual \
        --disable-debug --disable-gopher --disable-dict --disable-sspi \
        --enable-static --enable-ipv6 \
        --without-zlib --without-librtmp --without-gnutls \
        --without-mbedtls --without-nss \
        --with-random=/dev/urandom \
        --with-ssl="${OPENSSL}/install/${ARCH}" \
        --with-nghttp2="${NGHTTP2}/install/${ARCH}" \
        --host="${TARGET}" &> "${BUILD_DIR}/curl-${ARCH}_configure.log"

make clean  >> "${BUILD_DIR}/curl-${ARCH}_make_clean.log" 2>&1
make -j4  >> "${BUILD_DIR}/curl-${ARCH}_make.log" 2>&1
make install  >> "${BUILD_DIR}/curl-${ARCH}_make_install.log" 2>&1

cd ${CUR_DIR}

mkdir -p "lib/${ARCH}"

cp ${INSTALL_DIR}/lib/*.a ./lib/${ARCH}/

#rm -rf ${BUILD_DIR}

}


echo "===================================="
echo "==== Run curl build for Android ===="
echo "===================================="

mkdir -p "lib"

####################################################
# Install standalone toolchain x86

build "i686"

####################################################
# Install standalone toolchain x86_64

build "x86_64"

################################################################
# Install standalone toolchain arm64

build "aarch64"

################################################################
# Install standalone toolchain armv7a

build "armv7a"


rm -rf "${CURL_VERSION}"

echo "done"

