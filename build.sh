#!/bin/bash

PACKAGE="realtime-monitor"
VERSION="1.0"

PACKAGE="realtime-monitor"
VERSION="1.0"

mkdir -p build/$PACKAGE/DEBIAN
mkdir -p build/$PACKAGE/usr/local/bin
mkdir -p build/$PACKAGE/etc
mkdir -p build/$PACKAGE/etc/systemd/system

cp debian/control build/$PACKAGE/DEBIAN/

# FIXED LINE (important)
install -m 755 debian/postinst build/$PACKAGE/DEBIAN/postinst

cp usr/local/bin/monitor-realtime.sh build/$PACKAGE/usr/local/bin/
cp etc/monitor.conf build/$PACKAGE/etc/
cp etc/systemd/monitor.service build/$PACKAGE/etc/systemd/system/

dpkg-deb --build build/$PACKAGE

echo "Package created: build/$PACKAGE.deb"