#!/bin/bash
echo "Cleaning Build-OpenSSL-cURL"
rm -fr curl/curl-* "curl/include" "curl/lib" "curl/build"
rm -fr openssl/openssl-1* "openssl/Mac" "openssl/iOS" "openssl/build"
rm -fr nghttp2/nghttp2-1* "nghttp2/Mac" "nghttp2/iOS" "nghttp2/lib" "nghttp2/build"
