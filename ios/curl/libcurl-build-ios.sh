#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL 
# Preston Jennings
#   https://github.com/prestonj/Build-OpenSSL-cURL 

set -e

BUILD_DIR="${PWD}/build"

mkdir -p "${BUILD_DIR}"

# set trap to help debug any build errors
trap 'echo "** ERROR with Build - Check ${BUILD_DIR}/curl*.log"; tail ${BUILD_DIR}/curl*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [curl version] [iOS SDK version (defaults to latest)]"
	trap - INT TERM EXIT
	exit 127
}

if [ "$1" == "-h" ]; then
	usage
fi

if [ -z $2 ]; then
	IOS_SDK_VERSION=""
	IOS_MIN_SDK_VERSION="9.0"
else
	IOS_SDK_VERSION=$2
fi

if [ -z $1 ]; then
	CURL_VERSION="curl-7.61.1"
else
	CURL_VERSION="curl-$1"
fi

OPENSSL="${PWD}/../openssl"
DEVELOPER="$(xcode-select --print-path)"
IPHONEOS_DEPLOYMENT_TARGET="6.0"

# HTTP2 support
NOHTTP2="${BUILD_DIR}/no-http2"
if [ ! -f "$NOHTTP2" ]; then
	# nghttp2 will be in ../nghttp2/{Platform}/{arch}
	NGHTTP2="${PWD}/../nghttp2"  
fi

if [ ! -z "$NGHTTP2" ]; then 
	echo "Building with HTTP2 Support (nghttp2)"
else
	echo "Building without HTTP2 Support (nghttp2)"
	NGHTTP2CFG=""
	NGHTTP2LIB=""
fi

buildMac()
{
	ARCH=$1
	HOST="i386-apple-darwin"

	echo "Building ${CURL_VERSION} for ${ARCH}"

	TARGET="darwin-i386-cc"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi

	if [ ! -z "$NGHTTP2" ]; then 
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/Mac/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/Mac/${ARCH}/lib"
	fi
	
	export CC="${BUILD_TOOLS}/usr/bin/clang"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -fembed-bitcode"
	export LDFLAGS="-arch ${ARCH} ${NGHTTP2LIB}"
	pushd . > /dev/null

    INSTALL_DIR="${BUILD_DIR}/${CURL_VERSION}-${ARCH}"

	cd "${CURL_VERSION}"
	./configure -prefix="${INSTALL_DIR}" \
        -disable-shared --enable-static \
        -with-random=/dev/urandom --with-darwinssl ${NGHTTP2CFG} \
        --host="${HOST}" &> "${BUILD_DIR}/${CURL_VERSION}-${ARCH}.log"

	make -j8 >> "${BUILD_DIR}/${CURL_VERSION}-${ARCH}.log" 2>&1
	make install >> "${BUILD_DIR}/${CURL_VERSION}-${ARCH}.log" 2>&1
	# Save curl binary for Mac Version
	cp "${BUILD_DIR}/${CURL_VERSION}-${ARCH}/bin/curl" "${BUILD_DIR}/curl"
	make clean >> "${BUILD_DIR}/${CURL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${CURL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""	
	else
		CC_BITCODE_FLAG="-fembed-bitcode"	
	fi

	if [ ! -z "$NGHTTP2" ]; then 
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/iOS/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/iOS/${ARCH}/lib"
	fi
	  
    #export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG} -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto"
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} ${NGHTTP2LIB} -Wl,-s"
    export CXXFLAGS="${CFLAGS} -std=c++11"
   
	echo "Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH} ${BITCODE}"

    INSTALL_DIR="${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}"

	if [[ "${ARCH}" == "arm64" ]]; then
		#--with-ssl="${OPENSSL}/iOS"
		./configure -prefix="${INSTALL_DIR}" \
			--disable-shared --disable-smtp --disable-pop3 --disable-imap \
			--disable-ftp --disable-tftp --disable-telnet --disable-rtsp \
			--disable-ldap --disable-manual --disable-crypto-auth \
			--disable-debug --disable-gopher --disable-dict --disable-sspi \
			--enable-static \
            --without-zlib --without-librtmp --without-gnutls --without-polarssl \
            --without-mbedtls --without-cyassl --without-nss --without-axtls \
			--with-random=/dev/urandom --with-darwinssl ${NGHTTP2CFG} \
			--host="arm-apple-darwin" &> "${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
	else
		#--with-ssl="${OPENSSL}/iOS"
		./configure -prefix="${INSTALL_DIR}" \
			--disable-shared --disable-smtp --disable-pop3 --disable-imap \
			--disable-ftp --disable-tftp --disable-telnet --disable-rtsp \
			--disable-ldap --disable-manual --disable-crypto-auth \
			--disable-debug --disable-gopher --disable-dict --disable-sspi \
			--enable-static \
            --without-zlib --without-librtmp --without-gnutls --without-polarssl \
            --without-mbedtls --without-cyassl --without-nss --without-axtls \
			--with-random=/dev/urandom --with-darwinssl ${NGHTTP2CFG} \
            --host="${ARCH}-apple-darwin" &> "${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
	fi

	make -j8 >> "${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}_make.log" 2>&1
	make install-strip >> "${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}_make_install.log" 2>&1
	make clean >> "${BUILD_DIR}/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}_make_clean.log" 2>&1

	popd > /dev/null
}


echo "Cleaning up"
rm -rf include/curl/* lib/*

mkdir -p "lib"
mkdir -p "include/curl/"

rm -rf ${BUILD_DIR}/${CURL_VERSION}-*
rm -rf ${BUILD_DIR}/${CURL_VERSION}-*.log

rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

#echo "Building Mac libraries"
#buildMac "x86_64"

#echo "Copying headers"
#cp ${BUILD_DIR}/${CURL_VERSION}-x86_64/include/curl/* include/curl/

#lipo \
#	"${BUILD_DIR}/${CURL_VERSION}-x86_64/lib/libcurl.a" \
#	-create -output "lib/libcurl_Mac.a"

echo "Building iOS libraries (bitcode)"
buildIOS "armv7" "bitcode"
buildIOS "armv7s" "bitcode"
buildIOS "arm64" "bitcode"
buildIOS "x86_64" "bitcode"
buildIOS "i386" "bitcode"



lipo \
    "${BUILD_DIR}/${CURL_VERSION}-iOS-armv7-bitcode/lib/libcurl.a" \
    "${BUILD_DIR}/${CURL_VERSION}-iOS-armv7s-bitcode/lib/libcurl.a" \
    "${BUILD_DIR}/${CURL_VERSION}-iOS-i386-bitcode/lib/libcurl.a" \
    "${BUILD_DIR}/${CURL_VERSION}-iOS-arm64-bitcode/lib/libcurl.a" \
    "${BUILD_DIR}/${CURL_VERSION}-iOS-x86_64-bitcode/lib/libcurl.a" \
    -create -output "lib/libcurl_iOS.a"


#echo "Building iOS libraries (nobitcode)"
#buildIOS "armv7" "nobitcode"
#buildIOS "armv7s" "nobitcode"
#buildIOS "arm64" "nobitcode"
#buildIOS "x86_64" "nobitcode"
#buildIOS "i386" "nobitcode"
#
#lipo \
#    "${BUILD_DIR}/${CURL_VERSION}-iOS-armv7-nobitcode/lib/libcurl.a" \
#    "${BUILD_DIR}/${CURL_VERSION}-iOS-armv7s-nobitcode/lib/libcurl.a" \
#    "${BUILD_DIR}/${CURL_VERSION}-iOS-i386-nobitcode/lib/libcurl.a" \
#    "${BUILD_DIR}/${CURL_VERSION}-iOS-arm64-nobitcode/lib/libcurl.a" \
#    "${BUILD_DIR}/${CURL_VERSION}-iOS-x86_64-nobitcode/lib/libcurl.a" \
#    -create -output lib/libcurl_iOS_nobitcode.a


echo "Cleaning up"
rm -rf "${BUILD_DIR}/${CURL_VERSION}-*"
rm -rf "${CURL_VERSION}"

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info lib/*.a

#reset trap
trap - INT TERM EXIT

echo "Done"
