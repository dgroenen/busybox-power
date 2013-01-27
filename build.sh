#!/bin/sh
# Helper script to build busybox-power
# Please run me from within Scratchbox

BBVERSION="1.21.0"
MAKETHREADS=`grep -i 'processor.:' /proc/cpuinfo |wc -l`
if [ -z "$MAKETHREADS" -o "$MAKETHREADS" -eq 0 ] ; then MAKETHREADS=1; fi
SCRIPTDIR=`dirname $(readlink -f $0)`
BUILDDIR="$SCRIPTDIR/../busybox-power-build"

BUILD_OPTIONS="parallel=$MAKETHREADS"

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

# Build
cd busybox-$BBVERSION/ && DEB_BUILD_OPTIONS="$BUILD_OPTIONS" dpkg-buildpackage -r"fakeroot -u" -uc -us -nc
