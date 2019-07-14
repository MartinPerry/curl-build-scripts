
export API_VERSION=0

####################################################
# Install standalone toolchain x86

API_VERSION=${API_VERSION_x86}
build "x86" "x86" "x86" "i686-linux-android" "" "android-x86"


####################################################
# Install standalone toolchain x86_64

API_VERSION=${API_VERSION_x64}
build "x86_64" "x86_64" "x86_64" "x86_64-linux-android" "" "android64"


################################################################
# Install standalone toolchain ARMeabi

API_VERSION=${API_VERSION_x86}
build "ARMeabi" "armeabi" "arm" "arm-linux-androideabi" "" "android"

################################################################
# Install standalone toolchain ARMeabi-v7a

API_VERSION=${API_VERSION_x86}
build "ARMeabi-v7a" "armeabi-v7a" "arm" "arm-linux-androideabi" "-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3" "android"

################################################################
# Install standalone toolchain ARM64-v8a

API_VERSION=${API_VERSION_x64}
build "ARM64-v8a" "arm64-v8a" "arm64" "aarch64-linux-android" "" "android64-aarch64"

################################################################
# Install standalone toolchain MIPS

#export API_VERSION=${API_VERSION_x86}
#build "MIPS" "mips" "mips" "mipsel-linux-android" ""

################################################################
# Install standalone toolchain MIPS64

#export API_VERSION=${API_VERSION_x64}
#build "MIPS64" "mips64" "mips64" "mips64el-linux-android" ""
