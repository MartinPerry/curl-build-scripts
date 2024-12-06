#!/bin/bash

#info https://curl.se/docs/install.html

#openssl: /usr/bin/openssl /usr/lib64/openssl /usr/include/openssl /usr/share/man/man1/openssl.1ssl.gz

LIBCURL="8.6.0"		# https://curl.haxx.se/download.html

install_dir=$(pwd)/install_${LIBCURL}

url="https://curl.se/download/curl-${LIBCURL}.zip"

if [ "$1" == "clear" ]; then
	echo "Clearing the folder..."  
	rm -rf "curl-${LIBCURL}"  
	rm -rf "${install_dir}"
fi 


if [ ! -e curl-${LIBCURL}.zip ]; then
	echo "Downloading ${url}"
	curl -LOs ${url}	
else
	echo "Using ${LIBCURL}.zip"
fi

if [ ! -e curl-${LIBCURL} ]; then
	unzip "curl-${LIBCURL}.zip"
fi	

mkdir ${install_dir}

echo "Install to ${install_dir}"

cd "curl-${LIBCURL}"

./configure --prefix=${install_dir} \
	--disable-shared \
	--enable-static \
	--disable-ldap \
	--disable-ldaps \
	--without-libpsl \
	--with-nghttp2 \
	--with-openssl
	#--with-openssl="/usr"
make
#make test
make install