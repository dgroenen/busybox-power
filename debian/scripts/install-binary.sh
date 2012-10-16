#!/bin/sh
# A script to replace /bin/busybox and create missing symlinks to its applets.
#
# The target directories for BusyBox' applets are defined in the "applets" file.
# This script will only create symbolic links when 1) they do not already exist 
# in the filesystem, and 2) the BusyBox binary supports the applet. A list of 
# all made symbolic links is written out to the file "busybox-power.symlinks", 
# which will be used during uninstallation of busybox-power.
#
# NB The BusyBox binary needs to support the install applet.
#
# By Dennis Groenen <tj.groenen@gmail.com>
# GPLv3 licensed
#

INSTALLDIR="/opt/busybox-power"
EXECPWR="$INSTALLDIR/busybox.power"
VERBOSE="0"

# Load shared functions
source $INSTALLDIR/functions

# Check whether the applets file exists
CHECK_APPLETSFILE() {
    if test ! -e $INSTALLDIR/applets; then
      echo "error: cannot find list of defined applets"
      exit 1
    fi
}

# Check whether symlinks have been made before
CHECK_SYMLINKSFILE() {
    if test -e $INSTALLDIR/busybox-power.symlinks; then
      echo "error: symlinks already seem to be made?"
      echo "  this script is not supposed to be ran twice"
      exit 1
    fi
}

# Create SHA1 hashes of relevant binaries
HASH_BINARIES() {
    $EXECPWR sha1sum $INSTALLDIR/busybox.power | $EXECPWR awk '{ print $1 }' \
      > $INSTALLDIR/busybox.power.sha1
    $EXECPWR sha1sum /bin/busybox | $EXECPWR awk '{ print $1 }' \
      > $INSTALLDIR/busybox.original.sha1
}

# Backup the original BusyBox binary
BACKUP() {
    case $ENVIRONMENT in
      SDK)
        # Scratchbox does not ship with BusyBox by default
        if test -e /bin/busybox; then
          $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original; fi
        ;;
      FREMANTLE)
        # Check whether busybox-power isn't somehow installed already
        INSTBINARY_SHA1=`$EXECPWR cat $INSTALLDIR/busybox.power.sha1`
        ORIGBINARY_SHA1=`$EXECPWR cat $INSTALLDIR/busybox.original.sha1`
        if test "$INSTBINARY_SHA1" == "$ORIGBINARY_SHA1"; then
          echo "warning: installed busybox binary matches the binary"
          echo "  that is to be installed"
          if ! test -e $INSTALLDIR/busybox.original; then 
            $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original; fi
        else
          $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original
        fi
        ;;
    esac
}

# Overwrite the installed binary with the enhanced binary
INSTALL() {
    /usr/sbin/dpkg-divert --local --divert /bin/busybox.distrib /bin/busybox
    $EXECPWR cp -f $INSTALLDIR/busybox.power /bin/busybox
}

# Create missing symlinks to the enhanced binary
SYMLINK() {
    # Load defined BusyBox applets
    source $INSTALLDIR/applets

    # Get a list of supported applets by busybox-power
    if test -d /tmp/busybox-power; then 
      $EXECPWR rm -Rf /tmp/busybox-power; fi
    $EXECPWR mkdir -p /tmp/busybox-power
    $EXECPWR --install -s /tmp/busybox-power
    $EXECPWR ls /tmp/busybox-power/ > $INSTALLDIR/applets_supported
    $EXECPWR rm -Rf /tmp/busybox-power

    # Prepare file that will keep track of installed symlinks by busybox-power
    echo "# Automatically generated by busybox-power. DO NOT EDIT" > $INSTALLDIR/busybox-power.symlinks
    echo -e "\nDESTINATIONS=\"$DESTINATIONS\"" >> $INSTALLDIR/busybox-power.symlinks
    echo -e "\n# Installed symlinks" >> $INSTALLDIR/busybox-power.symlinks

    # Walk through all possible destinations
    for DESTDIR in $DESTINATIONS; do 
      # Enable us to see all entries in $DESTINATION as variables
      eval "APPLICATIONS=\$$DESTDIR"

      # Set destination directory accordingly
      case $DESTDIR in
        DEST_BIN)
          DIR="/bin"
          ;;
        DEST_SBIN)
          DIR="/sbin"
          ;;
        DEST_USRBIN)
          DIR="/usr/bin"
          ;;
        DEST_USRSBIN)
          DIR="/usr/sbin"
          ;;
      esac

      # Keep track of installed symlinks per destination
      SYMLINKS="$DESTDIR=\""

      ECHO_VERBOSE "\nSymlinking applets in $DIR"
      # Walk through all applications from the current destination
      for APP in $APPLICATIONS; do
        # The following code is executed for all applets in the current destination
        if test ! -e $DIR/$APP; then
          # Check whether the applet is supported by the busybox binary
          if `$EXECPWR grep -Fq "$APP" $INSTALLDIR/applets_supported`; then
            ECHO_VERBOSE "Symlinking: /bin/busybox -> $DIR/$APP"
            $EXECPWR ln -s /bin/busybox $DIR/$APP
            SYMLINKS="$SYMLINKS $APP" 
          fi
        fi
      done

      # Write out installed symlinks
      echo "$SYMLINKS\"" >> $INSTALLDIR/busybox-power.symlinks
    done

    $EXECPWR rm $INSTALLDIR/applets_supported
}

### Codepath ###
ECHO_VERBOSE "busybox-power: verbose mode"
ECHO_VERBOSE "  binary: $EXECPWR"
ECHO_VERBOSE "  version string: `$EXECPWR | $EXECPWR head -n 1`"
CHECK_ENV && ECHO_VERBOSE "  environment: $ENVIRONMENT"

CHECK_STANDALONE
CHECK_APPLETSFILE
CHECK_SYMLINKSFILE
if test "$ENVIRONMENT" != "SDK"; then
  CHECK_ROOT
  HASH_BINARIES
fi
BACKUP
INSTALL
SYMLINK

