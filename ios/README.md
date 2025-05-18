# Build-OpenSSL-cURL


This Script builds OpenSSL, nghttp2 and cURL/libcurl for 
- Mac Catalyst (x86_64, arm64)
- iOS (armv7, armv7s, arm64 and arm64e)
- iOS Simulator (x86_64, arm64)


## Build

The `build.sh` script calls the three build scripts below (openssl, nghttp and curl) which download the specified release version, configure and build the libraries and binaries.  

The build script accepts several arguments to adjust versions and toggle features:

```
  ./build.sh [-o <OpenSSL version>] [-c <curl version>] [-n <nghttp2 version>] [-d] [-e] [-x] [-h] [...]

         -o <version>   Build OpenSSL version (default 1.1.1o)
         -c <version>   Build curl version (default 7.83.1)
         -n <version>   Build nghttp2 version (default 1.47.0)
         -d             Compile without HTTP2 support
         -e             Compile with OpenSSL engine support
         -b             Compile without bitcode
         -m             Compile Mac Catalyst library
         -u <version>   Mac Catalyst iOS min target version (default 15.0)
         -s <version>   iOS min target version (default 8.0)
         -x             No color output
         -h             Show usage
```

_OpenSSL Engine Note: By default, the OpenSSL source disables ENGINE support for iOS builds.  To force this active use this and the static engine support will be included:_ `./build.sh -e`

_Mac Catalyst Note: Static libraries can be built for Mac Catalyst. This often requires that you specify an recent Mac Catalyst iOS target version (e.g. 15.0). To build Catalyst binaries use the -m switch and specify the iOS target with -u:_ `./build.sh -m -u 15.0`

Minimum macOS and iOS target build versions are set by default in the build scripts or can be specified using command line arguments indicated above.  Apple Silicon arm64 macOS targets will need to be 11.0 or higher.

## Quick Start

1. Run the build script
2. Libraries and Binaries will be in the ./archive folder

```bash
./build.sh
```

Default versions are specified in the `build.sh` script but you can specify the version you want to build via the command line, e.g.:

```bash
./build.sh -o 1.1.1g -c 7.72.0 -n 1.41.0

# Use -m to build for Mac Catalyst as well
./build.sh -o 1.1.1g -c 7.72.0 -n 1.41.0 -m
```

You can update the default version by editing this section in the `build.sh` script:

```bash
################################################
# EDIT this section to Select Default Versions #
################################################

OPENSSL="1.1.1o"        # https://www.openssl.org/source/
LIBCURL="7.83.1"        # https://curl.haxx.se/download.html
NGHTTP2="1.47.0"        # https://nghttp2.org/

################################################
```

## Details

### Dependencies
The build script requires:
* Xcode 10 or higher (12+ recommended)
* Xcode Command Line Tools
* pkg-config tool for nghttp2 (or `brew` to auto-install)

### OpenSSL
The `openssl-build.sh` script creates separate bitcode enabled target libraries for:
* MacOS - OS X (x86-64, arm64)
* iOS - iPhone (armv7, armv7s, arm64 and arm64e) and iPhoneSimulator (i386, x86-64, arm64)

By default, the OpenSSL source disables ENGINE support for iOS builds.  To force this active use `build.sh -e`

	|____lib
	   |____libcrypto.a
	   |____libssl.a

NOTE: This script allows building the OpenSSL 1.1.1 and 1.0.2 series libraries.  The 1.0.2 series will be end of life soon so it is recommended that you use the new long term support (LTS) 1.1.1 version.

### HTTP2 / nghttp2
The `nghttp2-build.sh` script builds the nghttp2 libraries used by libcurl for the HTTP2 protocol.
* MacOS - OS X (x86-64, arm64)
* iOS - iPhone (armv7, armv7s, arm64 and arm64e) and iPhoneSimulator (i386, x86-64, arm64)

Edit `build.sh` to change the default version of nghttp2 that will be downloaded and built or specify the version on the command line.

	build.sh -n 1.40.0 

Include the relevant library into your project. The pkg-config tool is required.  The build script tests for this and will attempt to install if it is missing. Rename the appropriate file to libnghttp2.a:

	|____lib
	   |____libnghttp2_iOS.a
	   |____libnghttp2_iOS-simulator.a
	   |____libnghttp2_iOS-fat.a    <-- Contains both iOS and iOS-simulator binaries
	   |____libnghttp2_Catalyst.a

DISABLE HTTP2: The nghttp2 build can be disabled by using:

	build.sh -d

### cURL / libcurl
The `libcurl-build.sh` script create separate bitcode enabled targets libraries for:
* MacOS - OS X (x86-64, arm64)
* iOS - iPhone (armv7, armv7s, arm64 and arm64e) and iPhoneSimulator (i386, x86-64, arm64)

The curl build uses `--with-ssl` pointing to the above OpenSSL builds and `--with-nghttp2` pointing to the above nghttp2 builds..
Edit `build.sh` to change the version of cURL that will be downloaded and built or specify the version on the command line.

	build.sh -c 7.68.0 
	
Include the relevant library into your project.  Rename the appropriate file to libcurl.a:

	|____lib
	   |____libcurl_iOS.a            <-- Contains iOS (armv7, armv7s, arm64 and arm64e) libraries
	   |____libcurl_iOS-simulator.a  <-- Contains iOS-simulator (x86_64, arm64) libraries
	   |____libcurl_iOS-fat.a        <-- Contains iOS and iOS-simulator (x86_64) libraries
	   |____libcurl_Mac.a            <-- Contains MacOS (x86_64, arm64) libraries
	   |____libcurl_Catalyst.a       <-- Contains Mac Catalyst (x86_64, arm64) libraries

NOTE: By default, this script only builds bitcode versions. To build non-bitcode versions:

	build.sh -b



### Architectures in Mach-O Universal (Fat) Libraries

	xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a
	xcrun -sdk iphoneos lipo -info nghttp2/lib/*.a
	xcrun -sdk iphoneos lipo -info curl/lib/*.a

* Catalyst (Intel + Apple Silicon)
	* openssl/Catalyst/lib/libcrypto.a are: x86_64 arm64 
	* openssl/Catalyst/lib/libssl.a are: x86_64 arm64 
	* nghttp2/lib/libnghttp2_Catalyst.a are: x86_64 arm64 
	* curl/lib/libcurl_Catalyst.a are: x86_64 arm64 

* Mac (Intel + Apple Silicon)
	* openssl/Mac/lib/libcrypto.a are: x86_64 arm64 
	* openssl/Mac/lib/libssl.a are: x86_64 arm64 
	* nghttp2/lib/libnghttp2_Mac.a are: x86_64 arm64 
	* curl/lib/libcurl_Mac.a are: x86_64 arm64 

* iOS Only
	* openssl/iOS/lib/libcrypto.a are: armv7 armv7s arm64 arm64e 
	* openssl/iOS/lib/libssl.a are: armv7 armv7s arm64 arm64e 
	* nghttp2/lib/libnghttp2_iOS.a are: armv7 armv7s arm64 arm64e 
	* curl/lib/libcurl_iOS.a are: armv7 armv7s arm64 arm64e 

* iOS Simulator (Intel + Apple Silicon)
	* openssl/iOS-simulator/lib/libcrypto.a are: i386 x86_64 arm64 
	* openssl/iOS-simulator/lib/libssl.a are: i386 x86_64 arm64 
	* nghttp2/lib/libnghttp2_iOS-simulator.a are: i386 x86_64 arm64 
	* curl/lib/libcurl_iOS-simulator.a are: i386 x86_64 arm64 

* iOS + Intel Mac Simulator 
	* openssl/iOS-fat/lib/libcrypto.a are: armv7 armv7s i386 x86_64 arm64 arm64e 
	* openssl/iOS-fat/lib/libssl.a are: armv7 armv7s i386 x86_64 arm64 arm64e 
	* nghttp2/lib/libnghttp2_iOS-fat.a are: armv7 armv7s i386 x86_64 arm64 arm64e 
	* curl/lib/libcurl_iOS-fat.a are: armv7 armv7s i386 x86_64 arm64 arm64e 

* Universal Mac Binaries
	* curl: Mach-O universal binary with 2 architectures:
		* (for architecture x86_64): Mach-O 64-bit executable x86_64
		* (for architecture arm64):  Mach-O 64-bit executable arm64
	* openssl: Mach-O universal binary with 2 architectures:
		* (for architecture x86_64): Mach-O 64-bit executable x86_64
		* (for architecture arm64):  Mach-O 64-bit executable arm64

* Consolidated OpenSSL Libraries for iOS
	* openssl/openssl-ios-armv7_armv7s_arm64_arm64e.a are: armv7 armv7s arm64 arm64e 
	* openssl/openssl-ios-x86_64-simulator.a are: i386 x86_64 
	* openssl/openssl-ios-x86_64-maccatalyst.a is architecture: x86_64

* XCFrameworks

        |__ libcrypto.xcframework
        │   |__ ios-arm64_arm64e_armv7_armv7s
        │   |__ ios-arm64_i386_x86_64-simulator
        |
        |__ libcurl.xcframework
        │   |__ ios-arm64_arm64e_armv7_armv7s
        │   |__ ios-arm64_i386_x86_64-simulator
        |
        |__ libnghttp2.xcframework
        │   |__ ios-arm64_arm64e_armv7_armv7s
        │   |__ ios-arm64_i386_x86_64-simulator
        |
        |__ libssl.xcframework
            |__ ios-arm64_arm64e_armv7_armv7s
            |__ ios-arm64_i386_x86_64-simulator

### Archive

The `build.sh` script will create an ./archive folder and store all the *.a libraries built along with the header files and a MacOS binaries for `curl` and `openssl`.

        |___libcurl-7.66.0-openssl-1.1.1d-nghttp2-1.39.2
             |
             |____cacert.pem
             |
             |____bin/
             |  |____openssl*
             |  |____curl*
             |
             |____framework/
             |
             |____lib/
             |  |____Catalyst/
             |  |____iOS/
             |  |____iOS-simulator/
             |  |____iOS-fat/        <-- Contains universal iOS and iOS-simulator binaries
             |  |____MacOS/
             |  |____tvOS/
             |
             |____include/
                |____openssl/
                |____curl/

## Credit and Thanks

### Library Authors

* Daniel Stenberg, @bagder, author and maintainer of cURL and libcurl
   https://daniel.haxx.se/
* OpenSSL Software Foundation, maintainer of OpenSSL
   https://www.openssl.org/
* Tatsuhiro Tsujikawa, @tatsuhiro_t, author and maintainer of nghttp2 library and tools
   https://github.com/nghttp2/nghttp2

### Maintainer

* Jason Cox, @jasonacox
   https://github.com/jasonacox/Build-OpenSSL-cURL

### Contributors

* Preston Jennings, @prestonj, Fixed Mac target build (was building for iOS not OSX) #2
* TosSense, @tossense, Fixed typo and add a header example of curlbuild.h #13
* Jbfitb, @jbfitb, Added armv7s to lipo for libcrypto and libssl #25
* Sammy Lan, @SammyLan, Added support for -b(disablebitcode) option #37
* Tom Peeters, @Tommy2d, Mac Catalyst build support and separated binaries for simulators #42 #45
* Foster Brereton, @fosterbrereton, Increased compilation speed using all cores #48
* Mo Farajmandi, @mofarajmandi, Added support for XCFramework and Apple Silicon tvOS Simulator #51

### Reference Projects

* Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
* Bochun Bai
   https://github.com/sinofool/build-libcurl-ios
* Stefan Arentz
   https://github.com/st3fan/ios-openssl
* Felix Schulze
   https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
* James Moore
   https://gist.github.com/foozmeat/5154962
* Peter Steinberger, PSPDFKit GmbH, @steipete.
   https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0


