#!/bin/bash

echo "Running android builds"


cd "openssl"
sh "./openssl-build-android.sh"
cd ..


cd "nghttp2"
sh "./nghttp2-build-android.sh"
cd ..

cd "curl"
sh "./curl-build-android.sh"
cd ..
