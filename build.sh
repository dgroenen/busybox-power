#!/bin/sh
# Helper script to build busybox-power
# Please run me from within Scratchbox
#
# Run `sh build.sh thumb` to enable the thumb ISA. Make sure your Scratchbox
# target is properly set up to compile thumb binaries.
# Instructions to set up a Fremantle thumb target in Scratchbox:
# http://talk.maemo.org/showpost.php?p=1223814&postcount=164

BBVERSION="1.20.1"
MAKETHREADS="8"
SCRIPTDIR=`dirname $(readlink -f $0)`
BUILDDIR="$SCRIPTDIR/../busybox-power-build"
VERSION_DEBIAN=`cat $SCRIPTDIR/debian/changelog | awk -F'[()]' '{if(NR==1) print $2}'`

BUILD_OPTIONS="parallel=$MAKETHREADS"
THUMB=false

if [ "$1" == "thumb" ]; then
  THUMB=true; fi

hash wget 2>&- || { 
  echo >&2 "this script requires wget, exiting now"
  exit 1 
}

mkdir -p $BUILDDIR
cd $BUILDDIR

if ! test -e busybox-$BBVERSION.tar.bz2; then
  wget http://busybox.net/downloads/busybox-$BBVERSION.tar.bz2; fi

if test -d busybox-$BBVERSION/; then
  echo "`pwd`/busybox-$BBVERSION already exists,"
  echo "please (re)move it before rerunning this script"
  exit 1
fi

tar -jxf busybox-$BBVERSION.tar.bz2
cp -af $SCRIPTDIR/debian/ busybox-$BBVERSION/

if $THUMB; then
  # Append "~thumb" to the package's Debian version string
  # NB: we feed sed directly with $VERSION_DEBIAN, it is not escaped in any way
  sed -i "s/$VERSION_DEBIAN/$VERSION_DEBIAN~thumb/" busybox-$BBVERSION/debian/changelog
  BUILD_OPTIONS="$BUILD_OPTIONS,thumb,vfp"
fi

# Build
cd busybox-$BBVERSION/ && DEB_BUILD_OPTIONS="$BUILD_OPTIONS" dpkg-buildpackage -r"fakeroot -u" -uc -us -nc
