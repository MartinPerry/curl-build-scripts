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
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/nghttp2*.log${alertdim}"; tail -5 /tmp/nghttp2*.log' INT TERM EXIT

# --- Edit this to update default version ---
NGHTTP2_VERNUM="1.41.0"

catalyst="0"

# Set minimum OS versions for target
IOS_MIN_SDK_VERSION="12.0"
IOS_SDK_VERSION=""
CATALYST_IOS="15.0"				# Min supported is iOS 15.0 for Mac Catalyst

CORES=$(sysctl -n hw.ncpu)

usage ()
{
	echo
	echo -e "${bold}Usage:${normal}"
	echo
    echo -e "  ${subbold}$0${normal} [-v ${dim}<nghttp2 version>${normal}] [-s ${dim}<iOS SDK version>${normal}] [-x] [-h]"
    echo
	echo "         -v   version of nghttp2 (default $NGHTTP2_VERNUM)"
	echo "         -s   iOS min target version (default $IOS_MIN_SDK_VERSION)"
	echo "         -m   compile Mac Catalyst library"
	echo "         -u   Mac Catalyst iOS min target version (default $CATALYST_IOS)"
	echo "         -x   disable color output"
	echo "         -h   show usage"	
	echo
	trap - INT TERM EXIT
	exit 127
}

while getopts "v:s:u:mxh\?" o; do    
    case "${o}" in
        v) NGHTTP2_VERNUM="${OPTARG}" ;;
        s) IOS_MIN_SDK_VERSION="${OPTARG}" ;;
		m) catalyst="1" ;;		
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

NGHTTP2_VERSION="nghttp2-${NGHTTP2_VERNUM}"
DEVELOPER=`xcode-select -print-path`

NGHTTP2="${PWD}/../nghttp2"

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

# Check to see if pkg-config is already installed
if (type "pkg-config" > /dev/null 2>&1 ) ; then
	echo "  pkg-config already installed"
else
	echo -e "${alertdim}** WARNING: pkg-config not installed... attempting to install.${dim}"

	# Check to see if Brew is installed
	if (type "brew" > /dev/null 2>&1 ) ; then
		echo "  brew installed - using to install pkg-config"
		brew install pkg-config
	else
		# Build pkg-config from Source
		echo "  Downloading pkg-config-0.29.2.tar.gz"
		curl -LOs https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
		echo "  Building pkg-config"
		tar xfz pkg-config-0.29.2.tar.gz
		pushd pkg-config-0.29.2 > /dev/null
		./configure --prefix=/tmp/pkg_config --with-internal-glib >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		make -j${CORES} >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		make install >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		PATH=$PATH:/tmp/pkg_config/bin
		popd > /dev/null
	fi

	# Check to see if installation worked
	if (type "pkg-config" > /dev/null 2>&1 ) ; then
		echo "  SUCCESS: pkg-config installed"
	else
		echo -e "${alert}** FATAL ERROR: pkg-config failed to install - exiting.${normal}"
		exit 1
	fi
fi 


buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"
  
	PLATFORM="iPhoneOS"
	
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
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG}"
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"
   
	echo -e "${subbold}Building ${NGHTTP2_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} (iOS ${IOS_MIN_SDK_VERSION})"
	
    ./configure --disable-shared --disable-app --disable-threads --enable-lib-only  --prefix="${NGHTTP2}/iOS/${ARCH}" --host="arm-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log"

	make -j8 >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	make install >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	make clean >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	popd > /dev/null

	# Clean up exports
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
}

buildIOSsim()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"
  
  	PLATFORM="iPhoneSimulator"
	export $PLATFORM

	TARGET="darwin-i386-cc"
	RUNTARGET=""
	MIPHONEOS="${IOS_MIN_SDK_VERSION}"
	if [[ $ARCH != "i386" ]]; then
		TARGET="darwin64-${ARCH}-cc"
		RUNTARGET="-target ${ARCH}-apple-ios${IOS_MIN_SDK_VERSION}-simulator"
			# e.g. -target arm64-apple-ios11.0-simulator
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
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${MIPHONEOS} ${CC_BITCODE_FLAG} ${RUNTARGET}  "
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"
   
	echo -e "${subbold}Building ${NGHTTP2_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} (iOS ${IOS_MIN_SDK_VERSION})"
    
	if [[ "${ARCH}" == "arm64" || "${ARCH}" == "arm64e"  ]]; then
        ./configure --disable-shared --disable-app --disable-threads --enable-lib-only  --prefix="${NGHTTP2}/iOS-simulator/${ARCH}" --host="arm-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log"
	else
        ./configure --disable-shared --disable-app --disable-threads --enable-lib-only --prefix="${NGHTTP2}/iOS-simulator/${ARCH}" --host="${ARCH}-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log"
	fi

	make -j8 >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	make install >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	make clean >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
	popd > /dev/null

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

	TARGET="darwin64-${ARCH}-cc"
	BUILD_MACHINE=`uname -m`

	export CC="${BUILD_TOOLS}/usr/bin/gcc"
    export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
    export LDFLAGS="-arch ${ARCH}"

	if [[ $ARCH == "x86_64" ]]; then
		TARGET="darwin64-x86_64-cc"
		MACOS_VER="${MACOS_X86_64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - cross compile
			TARGET="darwin64-x86_64-cc"
			MACOS_VER="${MACOS_X86_64_VERSION}"
			export CC="clang"
			export CXX="clang"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} -gdwarf-2 -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		else
			# Apple x86_64 Build Machine Detected - native build
			export CFLAGS=" -mmacosx-version-min=${MACOS_X86_64_VERSION} -arch ${ARCH} -pipe -Os -gdwarf-2 -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
		fi
	fi
	if [[ $ARCH == "arm64" ]]; then
		TARGET="darwin64-arm64-cc"
		MACOS_VER="${MACOS_ARM64_VERSION}"
		if [ ${BUILD_MACHINE} == 'arm64' ]; then
   			# Apple ARM Silicon Build Machine Detected - native build
			TARGET="darwin64-arm64-cc"
			export CFLAGS=" -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} -pipe -Os -gdwarf-2 -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
		else
			# Apple x86_64 Build Machine Detected - cross compile
			TARGET="darwin64-arm64-cc"
			export CC="clang"
			export CXX="clang"
			export CFLAGS=" -Os -mmacosx-version-min=${MACOS_ARM64_VERSION} -arch ${ARCH} -gdwarf-2 -fembed-bitcode -target ${ARCH}-apple-ios${CATALYST_IOS}-macabi "
			export LDFLAGS=" -arch ${ARCH} -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
			export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk "
		fi
	fi

	echo -e "${subbold}Building ${NGHTTP2_VERSION} for ${archbold}${ARCH}${dim} (MacOS ${MACOS_VER} Catalyst iOS ${CATALYST_IOS})"

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"

	# Cross compile required for Catalyst
	if [[ "${ARCH}" == "arm64" ]]; then
		./configure --disable-shared --disable-app --disable-threads --enable-lib-only  --prefix="${NGHTTP2}/Catalyst/${ARCH}" --host="arm-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-catalyst-${ARCH}.log"
	else
		./configure --disable-shared --disable-app --disable-threads --enable-lib-only --prefix="${NGHTTP2}/Catalyst/${ARCH}" --host="${ARCH}-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-catalyst-${ARCH}.log"
	fi
	
	make -j${CORES} >> "/tmp/${NGHTTP2_VERSION}-catalyst-${ARCH}.log" 2>&1
	make install >> "/tmp/${NGHTTP2_VERSION}-catalyst-${ARCH}.log" 2>&1
	make clean >> "/tmp/${NGHTTP2_VERSION}-catalyst-${ARCH}.log" 2>&1
	popd > /dev/null

	# Clean up exports
	export CC=""
	export CXX=""
	export CFLAGS=""
	export LDFLAGS=""
	export CPPFLAGS=""
}

echo -e "${bold}Cleaning up${dim}"
rm -rf include/nghttp2/* lib/*
rm -fr iOS
rm -fr Catalyst

mkdir -p lib
mkdir -p iOS
mkdir -p Catalyst

rm -rf "/tmp/${NGHTTP2_VERSION}-*"
rm -rf "/tmp/${NGHTTP2_VERSION}-*.log"

rm -rf "${NGHTTP2_VERSION}"

if [ ! -e ${NGHTTP2_VERSION}.tar.gz ]; then
	echo "Downloading ${NGHTTP2_VERSION}.tar.gz"
	curl -LOs https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
	echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

#=================================================================================
# Building
#=================================================================================

echo -e "${bold}Building iOS libraries (bitcode)${dim}"
buildIOS "arm64" "bitcode"
buildIOS "arm64e" "bitcode"

buildIOSsim "x86_64" "bitcode"
buildIOSsim "arm64" "bitcode"

if [ $catalyst == "1" ]; then
	echo -e "${bold}Building Catalyst libraries${dim}"
	buildCatalyst "x86_64"
	buildCatalyst "arm64"

	lipo \
		"${NGHTTP2}/Catalyst/x86_64/lib/libnghttp2.a" \
		"${NGHTTP2}/Catalyst/arm64/lib/libnghttp2.a" \
		-create -output "${NGHTTP2}/lib/libnghttp2_Catalyst.a"
fi


lipo \
	"${NGHTTP2}/iOS/arm64/lib/libnghttp2.a" \
	"${NGHTTP2}/iOS/arm64e/lib/libnghttp2.a" \
	-create -output "${NGHTTP2}/lib/libnghttp2_iOS.a"

lipo \
	"${NGHTTP2}/iOS-simulator/x86_64/lib/libnghttp2.a" \
	"${NGHTTP2}/iOS-simulator/arm64/lib/libnghttp2.a" \
	-create -output "${NGHTTP2}/lib/libnghttp2_iOS_simulator.a"

#=================================================================================
# Finalize
#=================================================================================

echo -e "${bold}Cleaning up${dim}"
rm -rf /tmp/${NGHTTP2_VERSION}-*
rm -rf ${NGHTTP2_VERSION}

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"

