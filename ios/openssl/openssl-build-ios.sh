#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS openSSL libraries with Bitcode enabled

# Credits:
#
# Stefan Arentz
#   https://github.com/st3fan/ios-openssl
# Felix Schulze
#   https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# James Moore
#   https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
#   https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL

set -e

BUILD_DIR="${PWD}/build"

mkdir -p ${BUILD_DIR}

# set trap to help debug build errors
trap 'echo "** ERROR with Build - Check ${BUILD_DIR}/openssl*.log"; tail ${BUILD_DIR}/openssl*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [openssl version] [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)]"
	trap - INT TERM EXIT
	exit 127
}

if [ "$1" == "-h" ]; then
	usage
fi

if [ -z $2 ]; then
	IOS_SDK_VERSION=""
	IOS_MIN_SDK_VERSION="9.0"
	
	TVOS_SDK_VERSION="" #"9.0"
	TVOS_MIN_SDK_VERSION="9.0"
else
	IOS_SDK_VERSION=$2
	TVOS_SDK_VERSION=$3
fi

if [ -z $1 ]; then
	OPENSSL_VERSION="openssl-1.0.1t"
else
	OPENSSL_VERSION="openssl-$1"
fi

DEVELOPER="$(xcode-select --print-path)"
SDKROOT="$(xcodebuild -version -sdk $4 | grep -E '^Path' | sed 's/Path: //')"

buildMac()
{
	ARCH=$1

	echo "Building ${OPENSSL_VERSION} for ${ARCH}"

	TARGET="darwin-i386-cc"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
	fi

	export CC="${BUILD_TOOLS}/usr/bin/clang -fembed-bitcode"

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	./Configure no-asm ${TARGET} --openssldir="${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}" &> "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}_configure.log"

	make >> "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}_make.log" 2>&1
	make install_sw >> "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}_make_install_sw.log" 2>&1

    # Keep openssl binary for Mac version
	cp "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}/bin/openssl" "${BUILD_DIR}/openssl"
	make clean >> "${BUILD_DIR}/${OPENSSL_VERSION}-${ARCH}_make_clean.log" 2>&1

	popd > /dev/null
}

buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"
   
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	if [[ "${ARCH}" == "x86_64" ]]; then
		./Configure no-asm darwin64-x86_64-cc \
            --openssldir="${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}" &> "${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}_configure.log"
	else
		./Configure iphoneos-cross \
            --openssldir="${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}" &> "${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}_configure.log"
	fi
	# add -isysroot to CC=
	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"

	make >> "${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}_make.log" 2>&1
	make install_sw >> "${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}_make_install_sw.log" 2>&1
	make clean >> "${BUILD_DIR}/${OPENSSL_VERSION}-iOS-${ARCH}_make_clean.log" 2>&1
	popd > /dev/null
}

echo "Cleaning up"
rm -rf "include/openssl/*" "lib/*"


mkdir -p "Mac/lib"
mkdir -p "iOS/lib"
mkdir -p "Mac/include/openssl/"
mkdir -p "iOS/include/openssl/"

rm -rf ${BUILD_DIR}/${OPENSSL_VERSION}-*
rm -rf ${BUILD_DIR}/${OPENSSL_VERSION}-*.log

rm -rf "${OPENSSL_VERSION}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -LO https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

echo "Building Mac libraries"
buildMac "x86_64"

echo "Copying headers"
cp -a "${BUILD_DIR}/${OPENSSL_VERSION}-x86_64/include/openssl/." "Mac/include/openssl/"
cp -a "${BUILD_DIR}/${OPENSSL_VERSION}-x86_64/include/openssl/." "iOS/include/openssl/"

lipo \
	"${BUILD_DIR}/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
	-create -output "Mac/lib/libcrypto.a"

lipo \
	"${BUILD_DIR}/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
	-create -output "Mac/lib/libssl.a"

echo "Building iOS libraries"
buildIOS "armv7"
buildIOS "armv7s"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

lipo \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
	-create -output "iOS/lib/libcrypto.a"

lipo \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"${BUILD_DIR}/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
	-create -output "iOS/lib/libssl.a"



echo "Cleaning up"
rm -rf ${BUILD_DIR}/${OPENSSL_VERSION}-*
rm -rf "${OPENSSL_VERSION}"

#reset trap
trap - INT TERM EXIT

echo "Done"
