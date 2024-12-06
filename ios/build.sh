#!/bin/bash

# This script builds openssl+libcurl libraries for MacOS, iOS and tvOS
#
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
#

# Ensure we stop if build failure occurs
set -e

################################################
# EDIT this section to Select Default Versions #
################################################

OPENSSL="1.1.1t"	# https://www.openssl.org/source/ 
LIBCURL="8.7.1"		# https://curl.haxx.se/download.html
NGHTTP2="1.52.0"	# https://nghttp2.org/

################################################

# Build Machine
BUILD_MACHINE=`uname -m`
BUILD_CMD=$*

# Set minimum OS versions for target
IOS_MIN_SDK_VERSION="12.0"

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}


# Global flags
engine=""
buildnghttp2="-n"
buildopenssl=""
disablebitcode=""
colorflag=""
catalyst=""
sslv3=""

# Formatting
default="\033[39m"
white="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${white}\033[1m"
subbold="\033[0m${green}"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

# Show Usage
usage ()
{
    echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-o ${dim}<OpenSSL version>${normal}] [-c ${dim}<curl version>${normal}] [-n ${dim}<nghttp2 version>${normal}] [-d] [-e] [-3] [-x] [-h] [...]"
	echo
	echo "         -o <version>   Build OpenSSL version (default $OPENSSL)"
	echo "         -c <version>   Build curl version (default $LIBCURL)"
	echo "         -n <version>   Build nghttp2 version (default $NGHTTP2)"
	echo "         -d             Compile without HTTP2 support"
    echo "         -k             Compile with OpenSSL support"
	echo "         -e             Compile with OpenSSL engine support"
	echo "         -b             Compile without bitcode"
	echo "         -3             Compile with SSLv3"
	echo "         -s <version>   iOS min target version (default $IOS_MIN_SDK_VERSION)"
	echo "         -x             No color output"
	echo "         -h             Show usage"
	echo
    exit 127
}

# Process command line arguments
while getopts "o:c:n:u:s:dkeb3xh\?" o; do
    case "${o}" in
		o)
			OPENSSL="${OPTARG}"
			;;
		c)
			LIBCURL="${OPTARG}"
			;;
		n)
			NGHTTP2="${OPTARG}"
			;;
		d)
			buildnghttp2=""
			;;
        k)
            buildopenssl="-o"
            ;;
		e)
			engine="-e"
			;;
		b)
			disablebitcode="-b"
			;;
		3)
       		sslv3="-3"
			;;
		s)
			IOS_MIN_SDK_VERSION="${OPTARG}"
			;;
		x)
			bold=""
			subbold=""
			normal=""
			dim=""
			alert=""
			alertdim=""
			colorflag="-x"
			;;
		*)
			usage
			;;
    esac
done
shift $((OPTIND-1))

# Set OS min versions
OSARGS="-s ${IOS_MIN_SDK_VERSION}"

## Welcome
echo -e "${bold}Build-OpenSSL-cURL${dim}"
echo "This script builds OpenSSL, nghttp2 and libcurl for iOS devices."
echo "Targets: x86_64, arm64 and arm64e"

## Start Counter
START=$(date +%s)

## OpenSSL Build
if [ "$buildopenssl" == "" ]; then
    echo -e "No OpenSSL"
else
    echo
    cd openssl
    echo -e "${bold}Building OpenSSL${normal}"
    ./openssl-build.sh -v "$OPENSSL" $engine $colorflag $sslv3 $OSARGS
    cd ..
fi

## Nghttp2 Build
if [ "$buildnghttp2" == "" ]; then
	NGHTTP2="NONE"
else
	echo
	echo -e "${bold}Building nghttp2 for HTTP2 support${normal}"
    echo "with params: ./nghttp2-build.sh -v ${NGHTTP2} ${colorflag} ${OSARGS}"
	cd nghttp2
   	./nghttp2-build.sh -v "$NGHTTP2" $colorflag $OSARGS
	cd ..
fi

## Curl Build
echo
echo -e "${bold}Building Curl${normal}"
cd curl
./libcurl-build.sh -v "$LIBCURL" $disablebitcode $colorflag $buildnghttp2 $buildopenssl $sslv3 $OSARGS
cd ..

## Archive Libraries and Clean Up
echo
echo -e "${bold}Libraries...${normal}"
if [ "$buildopenssl" != "" ]; then
    echo
    echo -e "${subbold}openssl${normal} [${dim}$OPENSSL${normal}]${dim}"
    xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a
fi
if [ "$buildnghttp2" != "" ]; then
	echo
	echo -e "${subbold}nghttp2 (rename to libnghttp2.a)${normal} [${dim}$NGHTTP2${normal}]${dim}"
	xcrun -sdk iphoneos lipo -info nghttp2/lib/*.a
fi
echo
echo -e "${subbold}libcurl (rename to libcurl.a)${normal} [${dim}$LIBCURL${normal}]${dim}"
xcrun -sdk iphoneos lipo -info curl/lib/*.a

ARCHIVE="archive/libcurl-$LIBCURL"
if [ "$buildopenssl" != "" ]; then
    ARCHIVE="${ARCHIVE}-openssl-$OPENSSL"
fi
if [ "$buildnghttp2" != "" ]; then
    ARCHIVE="${ARCHIVE}-nghttp2-$NGHTTP2"
fi

echo
echo -e "${bold}Creating archive with XCFrameworks for release v$LIBCURL...${dim}"
echo "  See $ARCHIVE"
rm -rf "$ARCHIVE"
mkdir -p "$ARCHIVE"
if [ "$buildopenssl" != "" ]; then
    mkdir -p "$ARCHIVE/include/openssl"
fi
mkdir -p "$ARCHIVE/include/curl"
mkdir -p "$ARCHIVE/lib/iOS"
mkdir -p "$ARCHIVE/lib/iOS-simulator"
mkdir -p "$ARCHIVE/lib/iOS-fat"

mkdir -p "$ARCHIVE/bin"
mkdir -p "$ARCHIVE/framework"
mkdir -p "$ARCHIVE/xcframework"

# libraries for libcurl, libcrypto and libssl
cp curl/lib/libcurl_iOS.a $ARCHIVE/lib/iOS/libcurl_iOS.a
cp curl/lib/libcurl_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libcurl_iOS_simulator.a

if [ "$buildopenssl" != "" ]; then
    cp openssl/iOS/lib/libcrypto_iOS.a $ARCHIVE/lib/iOS/libcrypto_iOS.a
    cp openssl/iOS-simulator/lib/libcrypto_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libcrypto_iOS_simulator.a

    cp openssl/iOS/lib/libssl_iOS.a $ARCHIVE/lib/iOS/libssl_iOS.a
    cp openssl/iOS-simulator/lib/libssl_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libssl_iOS_simulator.a
fi


# Build XCFrameworks
xcodebuild -create-xcframework \
    -library $ARCHIVE/lib/iOS/libcurl_iOS.a \
    -headers curl/include \
    -library $ARCHIVE/lib/iOS-simulator/libcurl_iOS_simulator.a \
    -headers curl/include \
	-output $ARCHIVE/xcframework/libcurl.xcframework
    
if [ "$buildopenssl" != "" ]; then
    xcodebuild -create-xcframework \
        -library $ARCHIVE/lib/iOS/libcrypto_iOS.a \
        -headers openssl/iOS/include \
        -library $ARCHIVE/lib/iOS-simulator/libcrypto_iOS_simulator.a \
        -headers openssl/iOS-simulator/include \
        -output $ARCHIVE/xcframework/libcrypto.xcframework

    xcodebuild -create-xcframework \
        -library $ARCHIVE/lib/iOS/libssl_iOS.a \
        -library $ARCHIVE/lib/iOS-simulator/libssl_iOS_simulator.a \
        -output $ARCHIVE/xcframework/libssl.xcframework

    cp openssl/*.a $ARCHIVE/framework
fi

# libraries for nghttp2
if [ "$buildnghttp2" != "" ]; then
    # nghttp2 libraries
    cp nghttp2/lib/libnghttp2_iOS.a $ARCHIVE/lib/iOS/libnghttp2_iOS.a
    cp nghttp2/lib/libnghttp2_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libnghttp2_iOS_simulator.a
    xcodebuild -create-xcframework \
        -library $ARCHIVE/lib/iOS/libnghttp2_iOS.a \
        -library $ARCHIVE/lib/iOS-simulator/libnghttp2_iOS_simulator.a \
		-output $ARCHIVE/xcframework/libnghttp2.xcframework
fi

# archive header files
if [ "$buildopenssl" != "" ]; then
    cp openssl/iOS/include/openssl/* "$ARCHIVE/include/openssl"
fi
cp curl/include/curl/* "$ARCHIVE/include/curl"

# grab root certs
curl -sL https://curl.se/ca/cacert.pem > $ARCHIVE/cacert.pem

# create README for archive
sed -e "s/ZZZCMDS/$BUILD_CMD/g" -e "s/ZZZLIBCURL/$LIBCURL/g" -e "s/ZZZOPENSSL/$OPENSSL/g" -e "s/ZZZNGHTTP2/$NGHTTP2/g" archive/release-template.md > $ARCHIVE/README.md
echo


## Done - Display Build Duration
echo
echo -e "${bold}Build Complete${dim}"
END=$(date +%s)
secs=$(echo "$END - $START" | bc)
printf '  Duration %02dh:%02dm:%02ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60))
echo -e "${normal}"

rm -f $NOHTTP2
