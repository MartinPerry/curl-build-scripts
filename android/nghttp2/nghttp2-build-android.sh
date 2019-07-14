#!/bin/sh


source "../prefix.sh"


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
    curl -LO https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
    echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

#=============================================================================

build() {

# $1: Toolchain Name
# $2: Toolchain architecture
# $3: Android arch
# $4: host for configure
# $5: additional CPP flags

pushd . > /dev/null

echo "preparing ${1} toolchain"

if [[ ! -d "$ANDROID_NDK_ROOT/platforms/android-${API_VERSION}/arch-${3}" ]]; then
    echo "Architecture ${3} not exist for API ${API_VERSION}"
    return
fi

export PLATFORM_PREFIX="${PWD}/${2}-toolchain"
export BUILD_DIR="${PWD}/build-${2}"

#https://developer.android.com/ndk/guides/standalone_toolchain.html
$ANDROID_NDK_ROOT/build/tools/make_standalone_toolchain.py \
   --api=${API_VERSION} \
   --install-dir=$PLATFORM_PREFIX \
   --stl=libc++ \
   --arch=$3 \
   --force


export PATH="${PLATFORM_PREFIX}/bin:${PATH}"

export CPPFLAGS="-fPIE -I${PLATFORM_PREFIX}/include ${CFLAGS} -I${ANDROID_NDK}/sources/android/cpufeatures ${5}"
export LDFLAGS="-fPIE -L${PLATFORM_PREFIX}/lib"
export PKG_CONFIG_PATH="${PLATFORM_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
export TARGET_HOST="${4}"
export CC="${TARGET_HOST}-clang"
export CXX="${TARGET_HOST}-clang++"
if [ "$ENABLE_CCACHE" ]; then
    export CC="ccache ${TARGET_HOST}-clang"
    export CXX="ccache ${TARGET_HOST}-clang++"
fi

INSTALL_DIR="${PWD}/install/${2}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${NGHTTP2_VERSION}-${2}"
mkdir -p "${INSTALL_DIR}"

path="${PWD}/${NGHTTP2_VERSION}"


cd "${BUILD_DIR}"

sh ${path}/configure --enable-lib-only --host="${TARGET_HOST}" \
                --prefix="${INSTALL_DIR}" \
                --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
                --disable-shared --disable-app --disable-python-bindings --disable-threads &> "${BUILD_DIR}/nghttp2-${2}_configure.log"

make clean  >> "${BUILD_DIR}/nghttp2-${2}_make_clean.log" 2>&1
make -j4  >> "${BUILD_DIR}/nghttp2-${2}_make.log" 2>&1
make install  >> "${BUILD_DIR}/nghttp2-${2}_make_install.log" 2>&1

cd ..

mkdir -p "lib/${2}"
#mkdir -p "lib/${2}/include"

#cp -a "${BUILD_DIR}/${NGHTTP2_VERSION}-${2}/lib/." "./lib/${2}/"
#cp -a "${BUILD_DIR}/${NGHTTP2_VERSION}-${2}/include/." "./lib/${2}/include/"

cp ${INSTALL_DIR}/lib/*.a ./lib/$2/

rm -rf "${PLATFORM_PREFIX}"
rm -rf "${BUILD_DIR}"


popd > /dev/null
}


echo "======================================="
echo "==== Run nghttp2 build for Android ===="
echo "======================================="

mkdir -p "lib"

source "../build-include.sh"

rm -rf "${NGHTTP2_VERSION}"

echo "done"
