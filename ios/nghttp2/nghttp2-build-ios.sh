#!/bin/bash
# This script downlaods and builds the Mac, iOS and tvOS nghttp2 libraries 
#
# Credits:
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL 
#
# NGHTTP2 - https://github.com/nghttp2/nghttp2
#

# > nghttp2 is an implementation of HTTP/2 and its header 
# > compression algorithm HPACK in C
# 
# NOTE: pkg-config is required
 
set -e

BUILD_DIR="${PWD}/build"

mkdir -p "${BUILD_DIR}"

# set trap to help debug build errors
trap 'echo "** ERROR with Build - Check ${BUILD_DIR}/nghttp2*.log"; tail ${BUILD_DIR}/nghttp2*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [nghttp2 version] [iOS SDK version (defaults to latest)]"
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
	NGHTTP2_VERNUM="1.34.0"
else
	NGHTTP2_VERNUM="$1"
fi

# --- Edit this to update version ---

NGHTTP2_VERSION="nghttp2-${NGHTTP2_VERNUM}"
DEVELOPER=`xcode-select -print-path`

NGHTTP2="${PWD}/../nghttp2"

# Check to see if pkg-config is already installed
if (type "pkg-config" > /dev/null) ; then
	echo "pkg-config installed"
else
	echo "ERROR: pkg-config not installed... attempting to install."

	# Check to see if Brew is installed
	if ! type "brew" > /dev/null; then
		echo "FATAL ERROR: brew not installed - unable to install pkg-config - exiting."
		exit
	else
		echo "brew installed - using to install pkg-config"
		brew install pkg-config
	fi

	# Check to see if installation worked
	if (type "pkg-config" > /dev/null) ; then
		echo "SUCCESS: pkg-config installed"
	else
		echo "FATAL ERROR: pkg-config failed to install - exiting."
		exit
	fi
fi 

buildMac()
{
	ARCH=$1
        HOST="i386-apple-darwin"

	echo "Building ${NGHTTP2_VERSION} for ${ARCH}"

	TARGET="darwin-i386-cc"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/clang -fembed-bitcode"
        export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -fembed-bitcode"
        export LDFLAGS="-arch ${ARCH}"

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"
	./configure --disable-shared --disable-app --disable-threads --enable-lib-only \
        --prefix="${NGHTTP2}/Mac/${ARCH}" \
        --host="${HOST}" &> "${BUILD_DIR}/${NGHTTP2_VERSION}-${ARCH}_configure.log"

	make >> "${BUILD_DIR}/${NGHTTP2_VERSION}-${ARCH}_make.log" 2>&1
	make install >> "${BUILD_DIR}/${NGHTTP2_VERSION}-${ARCH}_make_install.log" 2>&1
	make clean >> "${BUILD_DIR}/${NGHTTP2_VERSION}-${ARCH}_make_clean.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"
  
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
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG}  -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto"
    export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -Wl,-s"
    export CXXFLAGS="${CFLAGS} -std=c++11"

	echo "Building ${NGHTTP2_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

    INSTALL_DIR="${NGHTTP2}/iOS/${ARCH}"

    if [[ "${ARCH}" == "arm64" ]]; then
		./configure --disable-shared --disable-threads \
                --disable-python-bindings --disable-examples --disable-app --disable-hpack-tools \
                --enable-lib-only \
                --without-libxml2 --without-systemd \
                --prefix="${INSTALL_DIR}" \
                --host="arm-apple-darwin" &> "${BUILD_DIR}/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
    else
		./configure --disable-shared --disable-threads \
                --disable-python-bindings --disable-examples --disable-app --disable-hpack-tools \
                --enable-lib-only \
                --without-libxml2 --without-systemd \
                --prefix="${INSTALL_DIR}" \
                --host="${ARCH}-apple-darwin" &> "${BUILD_DIR}/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}_configure.log"
    fi

    make -j8 >> "${BUILD_DIR}/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}_make.log" 2>&1
    make install >> "${BUILD_DIR}/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}_make_install.log" 2>&1
    make clean >> "${BUILD_DIR}/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}_make_clean.log" 2>&1
    popd > /dev/null
}


echo "Cleaning up"
rm -rf include/nghttp2/* lib/*
#rm -fr Mac
rm -fr "iOS"

mkdir -p "lib"

rm -rf "${BUILD_DIR}/${NGHTTP2_VERSION}-*"
rm -rf "${BUILD_DIR}/${NGHTTP2_VERSION}-*.log"

rm -rf "${NGHTTP2_VERSION}"

if [ ! -e ${NGHTTP2_VERSION}.tar.gz ]; then
	echo "Downloading ${NGHTTP2_VERSION}.tar.gz"
	curl -LO https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
	echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

#echo "Building Mac libraries"
#buildMac "x86_64"
#
#lipo \
#        "${NGHTTP2}/Mac/x86_64/lib/libnghttp2.a" \
#        -create -output "${NGHTTP2}/lib/libnghttp2_Mac.a"
#

echo "Building iOS libraries (bitcode)"
buildIOS "armv7" "bitcode"
buildIOS "armv7s" "bitcode"
buildIOS "arm64" "bitcode"
buildIOS "x86_64" "bitcode"
buildIOS "i386" "bitcode"

lipo \
    "${NGHTTP2}/iOS/armv7/lib/libnghttp2.a" \
    "${NGHTTP2}/iOS/armv7s/lib/libnghttp2.a" \
    "${NGHTTP2}/iOS/i386/lib/libnghttp2.a" \
    "${NGHTTP2}/iOS/arm64/lib/libnghttp2.a" \
    "${NGHTTP2}/iOS/x86_64/lib/libnghttp2.a" \
    -create -output "${NGHTTP2}/lib/libnghttp2_iOS.a"


echo "Cleaning up"
rm -rf ${BUILD_DIR}/${NGHTTP2_VERSION}-*
rm -rf "${NGHTTP2_VERSION}"

#reset trap
trap - INT TERM EXIT

echo "Done"

