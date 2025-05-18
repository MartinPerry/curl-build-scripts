#!/bin/bash

# This script builds openssl+libcurl libraries for MacOS, iOS and tvOS
#
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
#

# Modified by Perry

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
CATALYST_IOS="15.0"				# Min supported is iOS 15.0 for Mac Catalyst

# Semantic Version Comparison
version_lte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}


# Global flags
engine=""
buildnghttp2="-n"
buildopenssl="-o"
colorflag=""
catalyst=""

#====================================================================== 
# Formatting
#====================================================================== 

default="\033[39m"
white="\033[39m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${white}\033[1m"
subbold="\033[0m${green}"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

#====================================================================== 
# Show Usage
#====================================================================== 

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
	echo "         -m             Compile Mac Catalyst library"
	echo "         -s <version>   iOS min target version (default $IOS_MIN_SDK_VERSION)"
	echo "         -u <version>   Mac Catalyst iOS min target version (default $CATALYST_IOS)"
	echo "         -x             No color output"
	echo "         -h             Show usage"
	echo
    exit 127
}

#====================================================================== 
# Process command line arguments
#====================================================================== 

while getopts "o:c:n:u:s:p:dkemxh\?" o; do
    case "${o}" in
		o) OPENSSL="${OPTARG}" ;;
		c) LIBCURL="${OPTARG}" ;;
		n) NGHTTP2="${OPTARG}" ;;
		d) buildnghttp2="" ;;
		k) buildopenssl="-o" ;;
		e) engine="-e" ;;	
		m) catalyst="-m" ;;	        				
		s) IOS_MIN_SDK_VERSION="${OPTARG}" ;;
		u) catalyst="-m -u ${OPTARG}"; CATALYST_IOS="${OPTARG}" ;;
		x)
			bold=""
			subbold=""
			normal=""
			dim=""
			alert=""
			alertdim=""
			colorflag="-x"
			;;
		*) usage ;;
    esac
done
shift $((OPTIND-1))

# Set OS min versions
OSARGS="-s ${IOS_MIN_SDK_VERSION}"

#====================================================================== 
## Run
#====================================================================== 

echo -e "${bold}Build-OpenSSL-cURL${dim}"
echo
echo -e " - OpenSSL version: ${subbold}${OPENSSL}${dim}"
echo -e " - cURL version:    ${subbold}${LIBCURL}${dim}"
if [ "$buildnghttp2" == "" ]; then
	echo ""
	echo -n "This script builds OpenSSL and libcurl "
else
	echo -e " - nghttp2 version: ${subbold}${NGHTTP2}${dim}"
	echo ""
	echo -n "This script builds OpenSSL, nghttp2 and libcurl "
fi


## Start Counter
START=$(date +%s)

#====================================================================== 
## OpenSSL Build
#====================================================================== 

if [ "$buildopenssl" == "" ]; then
    echo -e "No OpenSSL"
else
    echo    
    echo -e "${bold}Building OpenSSL${normal}"
	echo "with params: ./openssl-build.sh -v ${OPENSSL} ${engine} ${colorflag} ${catalyst} ${OSARGS}"
	cd openssl
    ./openssl-build.sh -v "$OPENSSL" $engine $colorflag $catalyst $OSARGS
    cd ..
fi

#====================================================================== 
## Nghttp2 Build
#====================================================================== 

if [ "$buildnghttp2" == "" ]; then
	NGHTTP2="NONE"
else
	echo
	echo -e "${bold}Building nghttp2 for HTTP2 support${normal}"
    echo "with params: ./nghttp2-build.sh -v ${NGHTTP2} ${colorflag} ${catalyst} ${OSARGS}"
	cd nghttp2
   	./nghttp2-build.sh -v "$NGHTTP2" $colorflag $catalyst $OSARGS
	cd ..
fi

#====================================================================== 
## Curl Build
#====================================================================== 

echo
echo -e "${bold}Building Curl${normal}"
echo "with params: ./libcurl-build.sh -v ${LIBCURL} ${colorflag} ${buildnghttp2} ${buildopenssl} ${catalyst} ${OSARGS}"
cd curl
./libcurl-build.sh -v "$LIBCURL" $colorflag $buildnghttp2 $buildopenssl $catalyst $OSARGS
cd ..

#====================================================================== 
## Archive Libraries
#====================================================================== 

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
if [ "$catalyst" != "" ]; then
	mkdir -p "$ARCHIVE/lib/Catalyst"
fi

mkdir -p "$ARCHIVE/bin"
mkdir -p "$ARCHIVE/framework"
mkdir -p "$ARCHIVE/xcframework"

#====================================================================== 
# Copy libs
#====================================================================== 

# libraries for libcurl, libcrypto and libssl
cp curl/lib/libcurl_iOS.a $ARCHIVE/lib/iOS/libcurl_iOS.a
cp curl/lib/libcurl_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libcurl_iOS_simulator.a

if [ "$catalyst" != "" ]; then
	cp curl/lib/libcurl_Catalyst.a $ARCHIVE/lib/Catalyst/libcurl_Catalyst.a
fi

if [ "$buildopenssl" != "" ]; then
    cp openssl/iOS/lib/libcrypto.a $ARCHIVE/lib/iOS/libcrypto_iOS.a
    cp openssl/iOS-simulator/lib/libcrypto.a $ARCHIVE/lib/iOS-simulator/libcrypto_iOS_simulator.a

    cp openssl/iOS/lib/libssl.a $ARCHIVE/lib/iOS/libssl_iOS.a
    cp openssl/iOS-simulator/lib/libssl.a $ARCHIVE/lib/iOS-simulator/libssl_iOS_simulator.a

	if [ "$catalyst" != "" ]; then		
		cp openssl/Catalyst/lib/libcrypto.a $ARCHIVE/lib/Catalyst/libcrypto_Catalyst.a
		cp openssl/Catalyst/lib/libssl.a $ARCHIVE/lib/Catalyst/libssl_Catalyst.a
	fi
fi

if [ "$buildnghttp2" != "" ]; then
    # nghttp2 libraries
    cp nghttp2/lib/libnghttp2_iOS.a $ARCHIVE/lib/iOS/libnghttp2_iOS.a
    cp nghttp2/lib/libnghttp2_iOS_simulator.a $ARCHIVE/lib/iOS-simulator/libnghttp2_iOS_simulator.a

	if [ "$catalyst" != "" ]; then	
		cp nghttp2/lib/libnghttp2_Catalyst.a $ARCHIVE/lib/Catalyst/libnghttp2_Catalyst.a
	fi
fi

	
#====================================================================== 
# Build XCFrameworks
#====================================================================== 

if [ "$catalyst" != "" ]; then
	xcodebuild -create-xcframework \
		-library $ARCHIVE/lib/iOS/libcurl_iOS.a \
		-headers curl/include \
		-library $ARCHIVE/lib/iOS-simulator/libcurl_iOS_simulator.a \
		-headers curl/include \
		-library $ARCHIVE/lib/Catalyst/libcurl_Catalyst.a \
        -headers curl/include \
		-output $ARCHIVE/xcframework/libcurl.xcframework
else
	xcodebuild -create-xcframework \
		-library $ARCHIVE/lib/iOS/libcurl_iOS.a \
		-headers curl/include \
		-library $ARCHIVE/lib/iOS-simulator/libcurl_iOS_simulator.a \
		-headers curl/include \
		-output $ARCHIVE/xcframework/libcurl.xcframework
fi

if [ "$buildopenssl" != "" ]; then
	if [ "$catalyst" != "" ]; then
		xcodebuild -create-xcframework \
			-library $ARCHIVE/lib/iOS/libcrypto_iOS.a \
			-headers openssl/iOS/include \
			-library $ARCHIVE/lib/iOS-simulator/libcrypto_iOS_simulator.a \
			-headers openssl/iOS-simulator/include \
			-library $ARCHIVE/lib/Catalyst/libcrypto_Catalyst.a \
        	-headers openssl/Catalyst/include \
			-output $ARCHIVE/xcframework/libcrypto.xcframework

		xcodebuild -create-xcframework \
			-library $ARCHIVE/lib/iOS/libssl_iOS.a \
			-library $ARCHIVE/lib/iOS-simulator/libssl_iOS_simulator.a \
			-library $ARCHIVE/lib/Catalyst/libssl_Catalyst.a \
			-output $ARCHIVE/xcframework/libssl.xcframework
	else
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
	fi
    cp openssl/*.a $ARCHIVE/framework
fi


# libraries for nghttp2
if [ "$buildnghttp2" != "" ]; then
    if [ "$catalyst" != "" ]; then
		xcodebuild -create-xcframework \
			-library $ARCHIVE/lib/iOS/libnghttp2_iOS.a \
			-library $ARCHIVE/lib/iOS-simulator/libnghttp2_iOS_simulator.a \
			-library $ARCHIVE/lib/Catalyst/libnghttp2_Catalyst.a \
			-output $ARCHIVE/xcframework/libnghttp2.xcframework
	else   
		xcodebuild -create-xcframework \
			-library $ARCHIVE/lib/iOS/libnghttp2_iOS.a \
			-library $ARCHIVE/lib/iOS-simulator/libnghttp2_iOS_simulator.a \
			-output $ARCHIVE/xcframework/libnghttp2.xcframework
	fi
fi

#====================================================================== 
# Finalize
#====================================================================== 

# archive header files
if [ "$buildopenssl" != "" ]; then
    cp openssl/iOS/include/openssl/* "$ARCHIVE/include/openssl"
fi
cp curl/include/curl/* "$ARCHIVE/include/curl"

# grab root certs
curl -sL https://curl.se/ca/cacert.pem > $ARCHIVE/cacert.pem

#====================================================================== 
## Done - Display Build Duration
#====================================================================== 

echo
echo -e "${bold}Build Complete${dim}"
END=$(date +%s)
secs=$(echo "$END - $START" | bc)
printf '  Duration %02dh:%02dm:%02ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60))
echo -e "${normal}"

rm -f $NOHTTP2
