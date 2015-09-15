#!/bin/bash

set -e

BUILD=$(pwd)/build
OUTPUT=$(pwd)/output

BUNDLE_DIR="/usr/local/libexec/SmartCardServices/drivers/ifd-yubico.bundle"
INFO_PLIST="$BUNDLE_DIR/Contents/Info.plist"

LIBUSB_DIR="libusb-1.0.9"
LIBUSB="$LIBUSB_DIR.tar.bz2"
LIBCCID_DIR="ccid-1.4.20"
LIBCCID="$LIBCCID_DIR.tar.bz2"

# Check for sources
MISSING_SOURCES=0
if [ ! -f $LIBUSB ]; then
  echo "File: ./$LIBUSB missing. Download it from http://www.libusb.org/"
  MISSING_SOURCES=1
fi

if [ ! -f $LIBCCID ]; then
  echo "File: ./$LIBCCID missing. Download it from https://alioth.debian.org/frs/?group_id=30105"
  MISSING_SOURCES=1
fi

if [ $MISSING_SOURCES -eq 1 ]; then
  echo "Source files missing. Aborting."
  exit 1
fi

# Set up directories
if [ -d $BUILD ]; then
  rm -rf $BUILD/*
else
  mkdir $BUILD
fi

if [ ! -d $OUTPUT ]; then
  mkdir $OUTPUT
fi

# Build libusb
tar xf $LIBUSB -C $BUILD
(cd $BUILD/$LIBUSB_DIR && \
  ./configure --prefix="$BUILD" --disable-dependency-tracking --enable-static --disable-shared && \
  make && \
  make install
)

# Build libccid
tar xf $LIBCCID -C $BUILD
export PKG_CONFIG_PATH=$BUILD/lib/pkgconfig
(cd $BUILD/$LIBCCID_DIR && \
  ./MacOSX/configure --enable-bundle=ifd-yubico.bundle && \
  make && \
  make install DESTDIR="$BUILD"
)

# Create installer
SCRIPTS="$BUILD/scripts"
mkdir $SCRIPTS
cp osx-patch-ccid $SCRIPTS/preinstall
cp Info.plist $SCRIPTS/
cp $BUILD$BUNDLE_DIR/Contents/MacOS/libccid.dylib $SCRIPTS/
pkgbuild --identifier com.yubico.libccid --nopayload --scripts "$SCRIPTS" $BUILD/ifd-yubico.pkg

# Require reboot after installation
pkgutil --expand "$BUILD/ifd-yubico.pkg" "$BUILD/ifd-yubico-expanded"
sed -e 's/postinstall-action=\"none\"/postinstall-action=\"restart\"/' -i '' "$BUILD/ifd-yubico-expanded/PackageInfo"
pkgutil --flatten "$BUILD/ifd-yubico-expanded" "$OUTPUT/ifd-yubico.pkg"

echo "SUCCESS"
echo "Resulting installer is in $OUTPUT"
