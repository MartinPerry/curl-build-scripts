

export OPENSSL_VERNUM="1.1.1t"
export NGHTTP2_VERNUM="1.52.0"
export CURL_VERNUM="8.1.1"

export ANDROID_NDK_HOME="/Users/perry/Library/Android/sdk/ndk/25.2.9519653"

#31 compileSdkVersion, 21 minSdkVersion
export API_VERSION=21


#abiFilters "armeabi-v7a", "x86", "arm64-v8a", "x86_64"

#==============================================================================
initToolchain() {

    local TARGET=$1

    export isValid=1

    export TOOLCHAIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64"

    export NDK_CLANG="${TOOLCHAIN}/bin/${TARGET}${API_VERSION}-clang++"
    if [[ ! -f "${NDK_CLANG}" ]]; then
        echo "Target ${TARGET} not exist for API ${API_VERSION}: ${NDK_CLANG}"
        isValid=0
        return
    fi

    export PATH="${TOOLCHAIN}/bin":${PATH}

    export AR="${TOOLCHAIN}/bin/llvm-ar"
    export CC="${TOOLCHAIN}/bin/${TARGET}${API_VERSION}-clang"
    export AS="$CC"
    export CXX="${TOOLCHAIN}/bin/${TARGET}${API_VERSION}-clang++"
    export LD="${TOOLCHAIN}/bin/ld"
    export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN}/bin/llvm-strip"
        
}

#==============================================================================

initCompilerFlags() {
  local ARCH=$1
  
  local optim="-O2"
  local cppv="-std=c++17"
  
  #local globalCFLAGS="-ffunction-sections -fdata-sections -fno-exceptions -fno-short-wchar -fno-short-enums"
  local globalCFLAGS="-fno-exceptions -fno-short-wchar -fno-short-enums"
  
  #local globalLDFLAGS="-Wl,--gc-sections ${optim} -ffunction-sections -fdata-sections"
  local globalLDFLAGS="${optim}"
  
  case "${ARCH}" in
  "armv7a")
    export CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp -Wno-unused-function -fstrict-aliasing -fPIC -DANDROID -D__ANDROID_API__=${API_VERSION} ${optim} ${globalCFLAGS}"
    export LDFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp -Wl,--fix-cortex-a8 ${globalLDFLAGS}"
    ;;
  "aarch64")
    export CFLAGS="-march=armv8-a -Wno-unused-function -fstrict-aliasing -fPIC -DANDROID -D__ANDROID_API__=${API_VERSION} ${optim} ${globalCFLAGS}"
    export LDFLAGS="-march=armv8-a ${globalLDFLAGS}"
    ;;
  "i686")
    export CFLAGS="-march=i686 -Wno-unused-function -fstrict-aliasing -fPIC -DANDROID -D__ANDROID_API__=${API_VERSION} ${optim} ${globalCFLAGS}"
    export LDFLAGS="-march=i686 ${globalLDFLAGS}"
    ;;
  "x86_64")
    export CFLAGS="-march=x86-64 -msse4.2 -mpopcnt -Wno-unused-function -fstrict-aliasing -fPIC -DANDROID -D__ANDROID_API__=${API_VERSION} ${optim} ${globalCFLAGS}"
    export LDFLAGS="-march=x86-64 ${globalLDFLAGS}"
    ;;
  esac
  
  export CXXFLAGS="${cppv} ${optim} ${globalCFLAGS}"
  export CPPFLAGS=${CFLAGS}
}
