#!/bin/sh


source "../prefix.sh"

NGHTTP2_VERSION="nghttp2-${NGHTTP2_VERNUM}"

# Check to see if pkg-config is already installed
if (type "dpkg" > /dev/null) ; then
    echo "dpkg installed"
else
    echo "ERROR: dpkg not installed... attempting to install."

    # Check to see if Brew is installed
    if ! type "brew" > /dev/null; then
        echo "FATAL ERROR: brew not installed - unable to install dpkg - exiting."
        exit
    else
        echo "brew installed - using to install dpkg"
        brew install dpkg
    fi

    # Check to see if installation worked
    if (type "dpkg" > /dev/null) ; then
        echo "SUCCESS: dpkg installed"
    else
        echo "FATAL ERROR: dpkg failed to install - exiting."
        exit
    fi
fi



if [ ! -e ${NGHTTP2_VERSION}.tar.gz ]; then
    echo "Downloading ${NGHTTP2_VERSION}.tar.gz"
    curl -LO  https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
    echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

#=============================================================================

build() {

# $1: Android Arch Name

#ARCH = aarch64, armv7a, i686, x86_64
export ARCH=$1

export TARGET="${ARCH}-linux-android"
if [[ ${ARCH} == "armv7a" ]]; then
    TARGET="${TARGET}eabi"
fi

echo "Building ${NGHTTP2_VERSION} for ${ARCH} / ${TARGET}"


initToolchain "${TARGET}"
if [[ ${isValid} == 0 ]]; then
    return
fi

export CUR_DIR=${PWD}

initCompilerFlags "${ARCH}"

export BUILD_DIR="${CUR_DIR}/build-${ARCH}"
export INSTALL_DIR="${CUR_DIR}/install/${ARCH}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${NGHTTP2_VERSION}-${ARCH}"
mkdir -p "${INSTALL_DIR}"

#path="${CUR_DIR}/${NGHTTP2_VERSION}"

cd "${BUILD_DIR}"

sh ${CUR_DIR}/${NGHTTP2_VERSION}/configure --enable-lib-only --host="${TARGET}" \
                --prefix="${INSTALL_DIR}" \
                --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
                --disable-shared --disable-app \
                --disable-threads &> "${BUILD_DIR}/nghttp2-${ARCH}_configure.log"

make clean  >> "${BUILD_DIR}/nghttp2-${ARCH}_make_clean.log" 2>&1
make -j4  >> "${BUILD_DIR}/nghttp2-${ARCH}_make.log" 2>&1
make install  >> "${BUILD_DIR}/nghttp2-${ARCH}_make_install.log" 2>&1

cd ${CUR_DIR}

mkdir -p "lib/${ARCH}"
#mkdir -p "lib/${2}/include"

#cp -a "${BUILD_DIR}/${NGHTTP2_VERSION}-${2}/lib/." "./lib/${2}/"
#cp -a "${BUILD_DIR}/${NGHTTP2_VERSION}-${2}/include/." "./lib/${2}/include/"

cp ${INSTALL_DIR}/lib/*.a ./lib/$ARCH/

#rm -rf "${BUILD_DIR}"

}


echo "======================================="
echo "==== Run nghttp2 build for Android ===="
echo "======================================="

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


rm -rf "${NGHTTP2_VERSION}"

echo "done"
