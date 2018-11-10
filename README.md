# curl-build-scripts

CURL library build scripts for Mac, iOS and Android. All scripts are intended to run from Mac.

CURL is build with OpenSSL support (Android) and for Mac / iOS with DarwinSSL (however, Openssl can be turn on).
CURL is build with NGHTTP2 for HTTP/2.0 support.

Mac and iOS version is taken from https://github.com/jasonacox/Build-OpenSSL-cURL and slightly changed (removed TvOS, added some configuration options).

For Android build, use the same API version as in your application, or linker error will show (https://github.com/curl/curl/issues/3247).

If linking OpenSSL, link ssl before crypto, or linker error will show.