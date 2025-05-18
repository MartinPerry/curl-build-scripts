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

# Modified by Perry

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

# Set trap to help debug any build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/curl*.log${alertdim}"; tail -3 /tmp/curl*.log' INT TERM EXIT

# Set defaults
CURL_VERSION="curl-7.74.0"
nohttp2="0"
noopenssl="0"
catalyst="0"
NOBITCODE="yes"

#https://github.com/curl/curl/blob/master/docs/INSTALL.md
CURL_PARAMS="--enable-websockets"
CURL_PARAMS="${CURL_PARAMS} --disable-progress-meter --without-ngtcp2 --disable-manual --disable-smtp --disable-pop3 --disable-imap"
CURL_PARAMS="${CURL_PARAMS} --disable-ftp --disable-tftp --disable-telnet --disable-rtsp --disable-ldaps --disable-ldap --disable-doh"
CURL_PARAMS="${CURL_PARAMS} --disable-kerberos-auth --disable-aws --disable-digest-auth --disable-ntlm-wb --disable-negotiate-auth"
CURL_PARAMS="${CURL_PARAMS} --disable-digest-auth --disable-netrc"
CURL_PARAMS="${CURL_PARAMS} --disable-netrc --disable-ntlm --disable-tftp"
CURL_PARAMS="${CURL_PARAMS} --without-brotli --without-zstd --without-librtmp"
CURL_PARAMS="${CURL_PARAMS} --without-libpsl --without-libidn2"
#CURL_PARAMS="${CURL_PARAMS} --without-zlib"


# Set minimum OS versions for target
IOS_MIN_SDK_VERSION="12.0"
IOS_SDK_VERSION=""
CATALYST_IOS="15.0"				# Min supported is iOS 15.0 for Mac Catalyst

CORES=$(sysctl -n hw.ncpu)

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

#====================================================================== 
# Show Usage
#====================================================================== 

usage ()
{
	echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-v ${dim}<curl version>${normal}] [-s ${dim}<version>${normal}] [-b] [-o] [-x] [-n] [-h]"
    echo
	echo "         -v   version of curl (default $CURL_VERSION)"
	echo "         -s   iOS min target version (default $IOS_MIN_SDK_VERSION)"
	echo "         -b   compile without bitcode"
	echo "         -n   compile with nghttp2"
    echo "         -o   compile with openssl"
	echo "         -x   disable color output"
	echo "         -h   show usage"
	echo
	trap - INT TERM EXIT
	exit 127
}

#====================================================================== 
# Process command line arguments
#====================================================================== 

while getopts "v:s:nobxh\?" o; do
    case "${o}" in
        v) CURL_VERSION="curl-${OPTARG}" ;;
		s) IOS_MIN_SDK_VERSION="${OPTARG}" ;;
		n) nohttp2="1" ;;
        o) noopenssl="1" ;;
		b) NOBITCODE="yes" ;;
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

#====================================================================== 
## Init
#====================================================================== 

OPENSSL="${PWD}/../openssl"
DEVELOPER=`xcode-select -print-path`

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

# HTTP2 support
if [ $nohttp2 == "1" ]; then
	# nghttp2 will be in ../nghttp2/{Platform}/{arch}
	NGHTTP2="${PWD}/../nghttp2"
fi

if [ $nohttp2 == "1" ]; then
	echo "Building with HTTP2 Support (nghttp2)"
else
	echo "Building without HTTP2 Support (nghttp2)"
	NGHTTP2CFG=""
	NGHTTP2LIB=""
fi

#====================================================================== 
# Check to see if pkg-config is already installed
#====================================================================== 

PATH=$PATH:/tmp/pkg_config/bin
if ! (type "pkg-config" > /dev/null 2>&1 ) ; then
	echo -e "${alertdim}** WARNING: pkg-config not installed... attempting to install.${dim}"

	# Check to see if Brew is installed
	if (type "brew" > /dev/null 2>&1 ) ; then
		echo "  brew installed - using to install pkg-config"
		brew install pkg-config
	else
		# Build pkg-config from Source
		curl -LOs https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
		echo "  Building pkg-config"
		tar xfz pkg-config-0.29.2.tar.gz
		pushd pkg-config-0.29.2 > /dev/null
		./configure --prefix=/tmp/pkg_config --with-internal-glib >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		make -j${CORES} >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		make install >> "/tmp/${NGHTTP2_VERSION}.log" 2>&1
		popd > /dev/null
	fi

	# Check to see if installation worked
	if (type "pkg-config" > /dev/null 2>&1 ) ; then
		echo "  SUCCESS: pkg-config now installed"
	else
		echo -e "${alert}** FATAL ERROR: pkg-config failed to install - exiting.${normal}"
		exit 1
	fi
fi 

#====================================================================== 
## Build methods
#====================================================================== 

buildCatalyst()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${CURL_VERSION}"

	PLATFORM="MacOSX"
	TARGET="${ARCH}-apple-ios${CATALYST_IOS}-macabi"
	BUILD_MACHINE=`uname -m`

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""
	else
		CC_BITCODE_FLAG="-fembed-bitcode"
	fi

	if [ $nohttp2 == "1" ]; then
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/Catalyst/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/Catalyst/${ARCH}/lib"
	else 
		NGHTTP2CFG="--without-nghttp2"
		NGHTTP2LIB=""
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}.sdk"
	export CC="${DEVELOPER}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -target $TARGET ${CC_BITCODE_FLAG}"
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${OPENSSL}/catalyst/lib ${NGHTTP2LIB}"

	echo -e "${subbold}Building ${CURL_VERSION} for ${archbold}${ARCH}${dim} ${BITCODE} (Mac Catalyst iOS ${CATALYST_IOS})"

	if [[ "${ARCH}" == "arm64" ]]; then
		./configure -prefix="/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}" $CONF_FLAGS --with-ssl=${OPENSSL}/catalyst ${NGHTTP2CFG} --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}.log"
	else
		./configure -prefix="/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}" $CONF_FLAGS --with-ssl=${OPENSSL}/catalyst ${NGHTTP2CFG} --host="${ARCH}-apple-darwin" &> "/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}.log"
	fi
	
	make -j${CORES} >> "/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}.log" 2>&1
	make install >> "/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}.log" 2>&1
	make clean >> "/tmp/${CURL_VERSION}-catalyst-${ARCH}-${BITCODE}.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${CURL_VERSION}"

	PLATFORM="iPhoneOS"
	PLATFORMDIR="iOS"

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""
	else
		CC_BITCODE_FLAG="-fembed-bitcode"
	fi

	if [ $nohttp2 == "1" ]; then
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/${PLATFORMDIR}/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/${PLATFORMDIR}/${ARCH}/lib"
	fi
 
 
    SSLCFG="--with-secure-transport"
    if [ $noopenssl == "1" ]; then
        SSLCFG="--with-ssl=${OPENSSL}/${PLATFORMDIR}"
    fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export CC="${DEVELOPER}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG}"

	echo -e "${subbold}Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} ${BITCODE} (iOS ${IOS_MIN_SDK_VERSION})"

	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${OPENSSL}/${PLATFORMDIR}/lib ${NGHTTP2LIB}"

	
	./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" --disable-shared --enable-static -with-random=/dev/urandom ${CURL_PARAMS} ${SSLCFG} ${NGHTTP2CFG} --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log"
   	
	make -j${CORES} >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make install >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make clean >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}

buildIOSsim()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${CURL_VERSION}"

	PLATFORM="iPhoneSimulator"
	PLATFORMDIR="iOS-simulator"

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""
	else
		CC_BITCODE_FLAG="-fembed-bitcode"
	fi

	if [ $nohttp2 == "1" ]; then
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/${PLATFORMDIR}/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/${PLATFORMDIR}/${ARCH}/lib"
	fi
 
    SSLCFG="--with-secure-transport"
    if [ $noopenssl == "1" ]; then
        SSLCFG="--with-ssl=${OPENSSL}/${PLATFORMDIR}"
    fi

	TARGET="darwin-i386-cc"
	RUNTARGET=""
	MIPHONEOS="${IOS_MIN_SDK_VERSION}"
	if [[ $ARCH != "i386" ]]; then
		TARGET="darwin64-${ARCH}-cc"
		RUNTARGET="-target ${ARCH}-apple-ios${IOS_MIN_SDK_VERSION}-simulator"
	fi

	# set up exports for build 
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export CC="${DEVELOPER}/usr/bin/gcc"
	export CXX="${DEVELOPER}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${MIPHONEOS} ${CC_BITCODE_FLAG} ${RUNTARGET} "
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${OPENSSL}/${PLATFORMDIR}/lib ${NGHTTP2LIB} "
	export CPPFLAGS=" -I.. -isysroot ${DEVELOPER}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk "

	echo -e "${subbold}Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} ${BITCODE} (iOS ${IOS_MIN_SDK_VERSION})"

	if [[ "${ARCH}" == *"arm64"* || "${ARCH}" == "arm64e" ]]; then
		./configure -prefix="/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}" --disable-shared --enable-static -with-random=/dev/urandom ${CURL_PARAMS} ${SSLCFG} ${NGHTTP2CFG} --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}.log"
	else
		./configure -prefix="/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}" --disable-shared --enable-static -with-random=/dev/urandom ${CURL_PARAMS} ${SSLCFG} ${NGHTTP2CFG} --host="${ARCH}-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}.log"
	fi
 

	make -j${CORES} >> "/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}.log" 2>&1
	make install >> "/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}.log" 2>&1
	make clean >> "/tmp/${CURL_VERSION}-iOS-simulator-${ARCH}.log" 2>&1
	popd > /dev/null
}

#====================================================================== 
## Run
#====================================================================== 

echo -e "${bold}Cleaning up${dim}"
rm -rf include/curl/* lib/*

mkdir -p lib
mkdir -p include/curl/

rm -fr "/tmp/curl"
rm -rf "/tmp/${CURL_VERSION}-*"
rm -rf "/tmp/${CURL_VERSION}-*.log"

rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -LOs https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

if ! [[ "${NOBITCODE}" == "yes" ]]; then
	BITCODE="bitcode"
else
	BITCODE="nobitcode"
fi

#================

if [ $catalyst == "1" ]; then
	echo -e "${bold}Building Catalyst libraries${dim}"
	buildCatalyst "x86_64" "${BITCODE}"
	buildCatalyst "arm64" "${BITCODE}"

	lipo \
		"/tmp/${CURL_VERSION}-catalyst-x86_64/lib/libcurl.a" \
		"/tmp/${CURL_VERSION}-catalyst-arm64/lib/libcurl.a" \
		-create -output lib/libcurl_Catalyst.a
fi

echo -e "${bold}Building iOS libraries (${BITCODE})${dim}"
buildIOS "arm64" "${BITCODE}"
buildIOS "arm64e" "${BITCODE}"

lipo \
	"/tmp/${CURL_VERSION}-iOS-arm64/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-arm64e/lib/libcurl.a" \
	-create -output lib/libcurl_iOS.a

buildIOSsim "x86_64" "${BITCODE}"
buildIOSsim "arm64" "${BITCODE}"

lipo \
	"/tmp/${CURL_VERSION}-iOS-simulator-x86_64/lib/libcurl.a" \
	"/tmp/${CURL_VERSION}-iOS-simulator-arm64/lib/libcurl.a" \
	-create -output lib/libcurl_iOS_simulator.a


echo "  Copying headers"
cp /tmp/${CURL_VERSION}-iOS-arm64/include/curl/* include/curl/

#=================================================================================
# Finalize
#=================================================================================

echo -e "${bold}Cleaning up${dim}"
rm -rf /tmp/${CURL_VERSION}-*
rm -rf ${CURL_VERSION}

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info lib/*.a

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
