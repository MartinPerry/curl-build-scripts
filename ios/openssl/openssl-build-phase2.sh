#!/bin/bash
#
# This script downlaods and builds the iOS openSSL libraries with Bitcode enabled
#
# Author: Jason Cox, @jasonacox https://github.com/jasonacox/Build-OpenSSL-cURL
# Date: 2020-Aug-15
#

# Modified by Perry

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

# set trap to help debug build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/openssl*.log${alertdim}"; tail -3 /tmp/openssl*.log' INT TERM EXIT

NOBITCODE="yes"

# Set minimum OS versions for target
IOS_MIN_SDK_VERSION="12.0"
IOS_SDK_VERSION=""
VERSION="1.1.1i"				# OpenSSL version default

CORES=$(sysctl -n hw.ncpu)
OPENSSL_VERSION="openssl-${VERSION}"

usage ()
{
	echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-v ${dim}<version>${normal}] [-s ${dim}<version>${normal}] [-t ${dim}<version>${normal}] [-i ${dim}<version>${normal}] [-a ${dim}<version>${normal}] [-u ${dim}<version>${normal}]  [-e] [-m] [-3] [-x] [-h]"
	echo
	echo "         -v   version of OpenSSL (default $VERSION)"
	echo "         -s   iOS min target version (default $IOS_MIN_SDK_VERSION)"
	echo "         -e   compile with engine support"
	echo "         -x   disable color output"
	echo "         -h   show usage"
	echo
	trap - INT TERM EXIT
	exit 127
}

engine=0

while getopts "v:s:exh\?" o; do
	case "${o}" in
		v) OPENSSL_VERSION="openssl-${OPTARG}" ;;
		s) IOS_MIN_SDK_VERSION="${OPTARG}" ;;
		e) engine=1 ;;
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

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		#sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
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
	export CC="${BUILD_TOOLS}/usr/bin/gcc ${CC_BITCODE_FLAG} -arch ${ARCH}"

	echo -e "${subbold}Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} (iOS ${IOS_MIN_SDK_VERSION})"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		TARGET="darwin-i386-cc"
		if [[ $ARCH == "x86_64" ]]; then
			TARGET="darwin64-x86_64-cc"
		fi
		if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
			./Configure no-asm ${TARGET} -no-shared --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		else
			./Configure no-asm ${TARGET} -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		fi
	else
		if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
			# export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
			./Configure iphoneos-cross DSO_LDFLAGS=-fembed-bitcode --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		else
			./Configure iphoneos-cross -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		fi
	fi
	# add -isysroot to CC=
	if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
		sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	else
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	fi

	make -j${CORES} >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	make clean >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null

	# Clean up exports
	export PLATFORM=""
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
	export CROSS_TOP=""
	export CROSS_SDK=""
	export BUILD_TOOLS=""
}

buildIOSsim()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	PLATFORM="iPhoneSimulator"
	export $PLATFORM

	TARGET="darwin-i386-cc"
	RUNTARGET=""
	MIPHONEOS="${IOS_MIN_SDK_VERSION}"
	if [[ $ARCH != "i386" ]]; then
		TARGET="darwin64-${ARCH}-cc"
		RUNTARGET="-target ${ARCH}-apple-ios${IOS_MIN_SDK_VERSION}-simulator"
			# e.g. -target arm64-apple-ios11.0-simulator
		#if [[ $ARCH == "arm64" ]]; then
		#	if (( $(echo "${MIPHONEOS} < 11.0" |bc -l) )); then
		#		MIPHONEOS="11.0"	# Min support for Apple Silicon is iOS 11.0 
		#	fi
		#fi
	fi

	if [[ "${BITCODE}" == "nobitcode" ]]; then
			CC_BITCODE_FLAG=""
	else
			CC_BITCODE_FLAG="-fembed-bitcode"
	fi
	
	# set up exports for build 
	export CFLAGS=" -Os -miphoneos-version-min=${MIPHONEOS} ${CC_BITCODE_FLAG} -arch ${ARCH} ${RUNTARGET} "
	export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk "
	export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk "
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CXX="${BUILD_TOOLS}/usr/bin/gcc"

	echo -e "${subbold}Building ${OPENSSL_VERSION} for ${PLATFORM} ${iOS_SDK_VERSION} ${archbold}${ARCH}${dim} (iOS ${MIPHONEOS})"

	# configure
	if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
		./Configure no-asm ${TARGET} -no-shared --prefix="/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}.log"
	else
		./Configure no-asm ${TARGET} -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}" $CUSTOMCONFIG &> "/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}.log"
	fi

	# add -isysroot to CC=
	# no longer needed with exports
	#if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
	#	sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	#else
	#	sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	#fi

	# make
	make -j${CORES} >> "/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}.log" 2>&1
	make clean >> "/tmp/${OPENSSL_VERSION}-iOS-Simulator-${ARCH}.log" 2>&1
	popd > /dev/null

	# Clean up exports
	export PLATFORM=""
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
	export CROSS_TOP=""
	export CROSS_SDK=""
	export BUILD_TOOLS=""
}

#echo -e "${bold}Cleaning up${dim}"
#rm -rf include/openssl/* lib/*

#mkdir -p Mac/lib
#mkdir -p Catalyst/lib
mkdir -p iOS/lib
mkdir -p iOS-simulator/lib
#mkdir -p Mac/include/openssl/
#mkdir -p Catalyst/include/openssl/
mkdir -p iOS/include/openssl/
mkdir -p iOS-simulator/include/openssl/

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

if ! [[ "${NOBITCODE}" == "yes" ]]; then
	BITCODE="bitcode"
else
	BITCODE="nobitcode"
fi

if [ "$engine" == "1" ]; then
	echo "+ Activate Static Engine"
	sed -ie 's/\"engine/\"dynamic-engine/' ${OPENSSL_VERSION}/Configurations/15-ios.conf
fi

echo -e "${bold}Building iOS libraries${dim} (${BITCODE})"


#================================================================
# Device
#================================================================

buildIOS "arm64" "${BITCODE}"
buildIOS "arm64e" "${BITCODE}"

echo "  Copying headers and libraries"
cp /tmp/${OPENSSL_VERSION}-iOS-arm64/include/openssl/* iOS/include/openssl/

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64e/lib/libcrypto.a" \
	-create -output iOS/lib/libcrypto.a

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-arm64e/lib/libssl.a" \
	-create -output iOS/lib/libssl.a

echo "  Creating combined OpenSSL libraries for iOS"
libtool -no_warning_for_no_symbols -static -o openssl-ios-arm64_arm64e.a iOS/lib/libcrypto.a iOS/lib/libssl.a

#================================================================
# Simulator
#================================================================

buildIOSsim "x86_64" "${BITCODE}"
buildIOSsim "arm64" "${BITCODE}"

echo "  Copying headers and libraries"
cp /tmp/${OPENSSL_VERSION}-iOS-Simulator-x86_64/include/openssl/* iOS-simulator/include/openssl/

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-Simulator-x86_64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-Simulator-arm64/lib/libcrypto.a" \
	-create -output iOS-simulator/lib/libcrypto.a

lipo \
	"/tmp/${OPENSSL_VERSION}-iOS-Simulator-x86_64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-iOS-Simulator-arm64/lib/libssl.a" \
	-create -output iOS-simulator/lib/libssl.a

echo "  Creating combined OpenSSL libraries for iOS-simulator"
libtool -no_warning_for_no_symbols -static -o openssl-ios-x86_64_arm64-simulator.a iOS-simulator/lib/libcrypto.a iOS-simulator/lib/libssl.a

#=================================================================================
# Finalize
#=================================================================================

echo -e "${bold}Cleaning up${dim}"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

#reset trap
trap - INT TERM EXIT

#echo -e "${normal}Done"
