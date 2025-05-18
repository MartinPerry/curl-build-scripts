#!/bin/bash
#
# This script downlaods and builds the Mac, Mac Catalyst and tvOS openSSL libraries with Bitcode enabled
#
# Author: Jason Cox, @jasonacox https://github.com/jasonacox/Build-OpenSSL-cURL
# Date: 2020-Aug-15
#

set -e

# Custom build options
CUSTOMCONFIG="enable-ssl-trace"

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${green}\033[1m"
subbold="\033[0m${green}"
archbold="\033[0m${yellow}\033[1m"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

# Set trap to help debug build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/openssl*.log${alertdim}"; tail -3 /tmp/openssl*.log' INT TERM EXIT

# Set defaults
VERSION="1.1.1i"				# OpenSSL version default
catalyst="0"

# Set minimum OS versions for target
MACOS_X86_64_VERSION=""			# Empty = use host version
MACOS_ARM64_VERSION=""			# Min supported is MacOS 11.0 Big Sur
CATALYST_IOS="15.0"				# Min supported is iOS 15.0 for Mac Catalyst

CORES=$(sysctl -n hw.ncpu)
OPENSSL_VERSION="openssl-${VERSION}"

if [ -z "${MACOS_X86_64_VERSION}" ]; then
	MACOS_X86_64_VERSION=$(sw_vers -productVersion)
fi
if [ -z "${MACOS_ARM64_VERSION}" ]; then
	MACOS_ARM64_VERSION=$(sw_vers -productVersion)
fi

usage ()
{
	echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-v ${dim}<version>${normal}] [-s ${dim}<version>${normal}] [-t ${dim}<version>${normal}] [-i ${dim}<version>${normal}] [-a ${dim}<version>${normal}] [-u ${dim}<version>${normal}] [-e] [-m] [-3] [-x] [-h]"
	echo
	echo "         -v   version of OpenSSL (default $VERSION)"
	echo "         -i   macOS 86_64 min target version (default $MACOS_X86_64_VERSION)"
	echo "         -a   macOS arm64 min target version (default $MACOS_ARM64_VERSION)"
	echo "         -e   compile with engine support"
	echo "         -m   compile Mac Catalyst library"
	echo "         -u   Mac Catalyst iOS min target version (default $CATALYST_IOS)"
	echo "         -x   disable color output"
	echo "         -h   show usage"
	echo
	trap - INT TERM EXIT
	exit 127
}

engine=0

while getopts "v:i:a:u:s:emxh\?" o; do
	case "${o}" in
		v) OPENSSL_VERSION="openssl-${OPTARG}" ;;	
		i) MACOS_X86_64_VERSION="${OPTARG}" ;;
		a) MACOS_ARM64_VERSION="${OPTARG}" ;;
		e) engine=1 ;;
		m) catalyst="1" ;;
		u) catalyst="1"
		   CATALYST_IOS="${OPTARG}"
		   ;;
		s) ;;
		x)
			bold=""
			subbold=""
			normal=""
			dim=""
			alert=""
			alertdim=""
			archbold=""
			;;
		*) usage ;;
	esac
done
shift $((OPTIND-1))

DEVELOPER=`xcode-select -print-path`

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}
if version_lte $MACOS_ARM64_VERSION 11.0; then
        MACOS_ARM64_VERSION="11.0"      # Min support for Apple Silicon is 11.0
fi

buildMac()
{
	ARCH=$1

	TARGET="darwin-i386-cc"
	BUILD_MACHINE=`uname -m`

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
		MACOS_VER="${MACOS_X86_64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - cross compile
			export CC="clang"
			export CXX="clang"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		else
			# Apple x86_64 Build Machine Detected - native build
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} "
		fi
	fi
	if [[ $ARCH == "arm64" ]]; then
		TARGET="darwin64-arm64-cc"
		MACOS_VER="${MACOS_ARM64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - native build
			export CC="${BUILD_TOOLS}/usr/bin/gcc"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} "
		else
			# Apple x86_64 Build Machine Detected - cross compile
			export CC="clang"
			export CXX="clang"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		fi
	fi

	echo -e "${subbold}Building ${OPENSSL_VERSION} for ${archbold}${ARCH}${dim} (MacOS ${MACOS_VER})"

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
		./Configure no-asm ${TARGET} -no-shared  --prefix="/tmp/${OPENSSL_VERSION}-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-${ARCH}.log"
	else
		./Configure no-asm ${TARGET} -no-shared  --openssldir="/tmp/${OPENSSL_VERSION}-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-${ARCH}.log"
	fi
	make -j${CORES} >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	# Keep openssl binary for Mac version
	cp "/tmp/${OPENSSL_VERSION}-${ARCH}/bin/openssl" "/tmp/openssl-${ARCH}"
	cp "/tmp/${OPENSSL_VERSION}-${ARCH}/bin/openssl" "/tmp/openssl"
	make clean >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
	popd > /dev/null

	if [ $ARCH == ${BUILD_MACHINE} ]; then
		echo -e "Testing binary for ${BUILD_MACHINE}:"
		/tmp/openssl version
	fi

	# Clean up exports
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
}

buildCatalyst()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	TARGET="darwin64-${ARCH}-cc"
	BUILD_MACHINE=`uname -m`
	export PLATFORM="MacOSX"
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH} -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
		MACOS_VER="${MACOS_X86_64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - cross compile
			export CC="clang"
			export CXX="clang"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		else
			# Apple x86_64 Build Machine Detected - native build
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
		fi
	fi
	if [[ $ARCH == "arm64" ]]; then
		TARGET="darwin64-arm64-cc"
		MACOS_VER="${MACOS_ARM64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - native build
			export CC="${BUILD_TOOLS}/usr/bin/gcc"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
		else
			# Apple x86_64 Build Machine Detected - cross compile
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		fi
	fi

	echo -e "${subbold}Building ${OPENSSL_VERSION} for ${archbold}${ARCH}${dim} (MacOS ${MACOS_VER} Catalyst iOS ${CATALYST_IOS})"

	if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
		./Configure no-asm ${TARGET} -no-shared  --prefix="/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}.log"
	else
		./Configure no-asm ${TARGET} -no-shared  --openssldir="/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}.log"
	fi

	#if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
	#	sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} !" "Makefile"
	#else
	#	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} !" "Makefile"
	#fi

	make -j${CORES} >> "/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}.log" 2>&1
	make clean >> "/tmp/${OPENSSL_VERSION}-catalyst-${ARCH}.log" 2>&1
	popd > /dev/null

	# Clean up exports
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
}



# echo -e "${bold}Cleaning up${dim}"
# rm -rf include/openssl/* lib/*

mkdir -p Mac/lib
mkdir -p Catalyst/lib
mkdir -p Mac/include/openssl/
mkdir -p Catalyst/include/openssl/

rm -rf "/tmp/openssl"
rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"

rm -rf "${OPENSSL_VERSION}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -LOs https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
	echo "** Building OpenSSL 1.1.1 **"
else
	if [[ "$OPENSSL_VERSION" = "openssl-1.0."* ]]; then
		echo "** Building OpenSSL 1.0.x ** "
		echo -e "${alert}** WARNING: End of Life Version - Upgrade to 1.1.1 **${dim}"
	else
		echo -e "${alert}** WARNING: This build script has not been tested with $OPENSSL_VERSION **${dim}"
	fi
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

if [ "$engine" == "1" ]; then
	echo "+ Activate Static Engine"
	sed -ie 's/\"engine/\"dynamic-engine/' ${OPENSSL_VERSION}/Configurations/15-ios.conf
fi

## Mac
echo -e "${bold}Building Mac libraries${dim}"
buildMac "x86_64"
buildMac "arm64"

echo "  Copying headers and libraries"
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* Mac/include/openssl/

lipo \
	"/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-arm64/lib/libcrypto.a" \
	-create -output Mac/lib/libcrypto.a

lipo \
	"/tmp/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-arm64/lib/libssl.a" \
	-create -output Mac/lib/libssl.a

## Catalyst
if [ $catalyst == "1" ]; then
	echo -e "${bold}Building Catalyst libraries${dim}"
	buildCatalyst "x86_64"
	buildCatalyst "arm64"

	echo "  Copying headers and libraries"
	cp /tmp/${OPENSSL_VERSION}-catalyst-x86_64/include/openssl/* Catalyst/include/openssl/

	lipo \
		"/tmp/${OPENSSL_VERSION}-catalyst-x86_64/lib/libcrypto.a" \
		"/tmp/${OPENSSL_VERSION}-catalyst-arm64/lib/libcrypto.a" \
		-create -output Catalyst/lib/libcrypto.a

	lipo \
		"/tmp/${OPENSSL_VERSION}-catalyst-x86_64/lib/libssl.a" \
		"/tmp/${OPENSSL_VERSION}-catalyst-arm64/lib/libssl.a" \
		-create -output Catalyst/lib/libssl.a
fi


if [ $catalyst == "1" ]; then
	libtool -no_warning_for_no_symbols -static -o openssl-ios-x86_64-maccatalyst.a Catalyst/lib/libcrypto.a Catalyst/lib/libssl.a
fi

#echo -e "${bold}Cleaning up${dim}"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

#reset trap
trap - INT TERM EXIT

#echo -e "${normal}Done"
