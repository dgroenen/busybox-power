#!/bin/sh
# A script to restore /bin/busybox and delete the symlinks made during 
# installation.
#
# Symbolic links to applets are only removed if they are
# 1) created by the installer script ("install-binary.sh")
# 2) not replaced by a binary (i.e. they are still a symbolic link)
# 3) pointing to a busybox binary
#
# By Dennis Groenen <tj.groenen@gmail.com>
# GPLv3 licensed
#

INSTALLDIR="/opt/busybox-power"
EXECPWR="$INSTALLDIR/busybox.power"
VERBOSE="0"
MODIFIEDBIN="0"
DIVERTED="0"

INSTBINARY_SHA1=`sha1sum $EXECPWR | awk '{ print $1 }'`
if test -e $INSTALLDIR/busybox.original; then
  ORIGBINARY_SHA1=`sha1sum $INSTALLDIR/busybox.original | awk '{ print $1 }'`; fi

# Load shared functions
source $INSTALLDIR/functions

# Check whether we can load the list of created symlinks during installation
CHECK_SYMLINKSFILE() {
    if test ! -e $INSTALLDIR/busybox-power.symlinks; then
      echo -e "Error: cannot find the list of symlinks to be removed. No symlinks will be removed at all!\n" >> /tmp/busybox-power-error
    fi
}

# Check for a diversion of /bin/busybox
CHECK_DIVERT() {
    if test -e /bin/busybox.distrib; then
      DIVERTED="1"; fi
}

# Check the (integrity) of our BusyBox backup
CHECK_BACKUP() {
    # SDK doesn't ship with BusyBox by default, there might be no backup at all
    if test ! -e $INSTALLDIR/busybox.original -a "$ENVIRONMENT" == "SDK" ; then
      return; fi

    # Firstly, check whether the backup still exists
    if test ! -e $INSTALLDIR/busybox.original; then
      echo -e "Error: original binary is missing! Continuing will only remove the symlinks made during installation, /bin/busybox stays untouched.\n" >> /tmp/busybox-power-error
      return
    fi

    # Secondly, check the integrity of the backup
    if test -e $INSTALLDIR/busybox.original.sha1; then
      if test ! "`cat $INSTALLDIR/busybox.original.sha1`" == "$ORIGBINARY_SHA1"; then
        echo -e "Warning: the backed-up original binary has been modified since installing busybox-power (invalid SHA1 checksum). Do not continue unless you're sure $INSTALLDIR/busybox.original isn't corrupted.\n" >> /tmp/busybox-power-error
      fi
    else
      echo -e "Warning: couldn't load the saved SHA1 checksum of the original binary; the integrity of the backup of the original binary can not be guaranteed.\n" >> /tmp/busybox-power-error
    fi
}

# Check whether /bin/busybox has been modified after bb-power's installation
CHECK_INSTALLEDBIN() {
    if test ! "$INSTBINARY_SHA1" == "`sha1sum /bin/busybox | awk '{ print $1 }'`"; then
      echo -e "Warning: /bin/busybox has been modified since installing busybox-power (invalid SHA1 checksum). Your current /bin/busybox won't be touched, our backup of the original /bin/busybox will be copied to /opt/busybox.original. \n" >> /tmp/busybox-power-error
      MODIFIEDBIN="1"
    fi
}

# Display encountered errors
DISPLAY_ERRORS() {
    case $ENVIRONMENT in
      SDK)
        echo -e "\n\n-----------Attention!-----------"
        cat /tmp/busybox-power-error
        rm /tmp/busybox-power-error
        echo "-> Please press [enter] to ignore the above errors/warnings."
        echo "   Hit [ctrl-c] to break"
        read 
        ;;
      FREMANTLE)
        echo "Click \"I Agree\" to ignore the above errors/warnings. Ask for help if you don't know what to do." >> /tmp/busybox-power-error
        echo "Please confirm the text on the screen of your device"
        maemo-confirm-text "Attention!" /tmp/busybox-power-error
        res=$?
        rm /tmp/busybox-power-error
        if test ! $res == 0; then exit 1; fi
        ;;
      esac
}

# Uninstallation of the enhanced binary
UNINSTALL() {
    if test $DIVERTED == 1; then
      # A package tried to install /bin/busybox since installing busybox-power
      # This binary has priority over our own (old) backup
      mv -f /bin/busybox.distrib /bin/busybox
      rm $INSTALLDIR/busybox.original
    elif test $MODIFIEDBIN == 1; then
      # /bin/busybox has been modified since installing busybox-power
      # Do not overwrite this modified version with our backup
      mv -f $INSTALLDIR/busybox.original /opt/busybox.original
    elif test -e $INSTALLDIR/busybox.original; then
      cp -f $INSTALLDIR/busybox.original /bin/busybox
      if test -e /bin/busybox; then
        rm $INSTALLDIR/busybox.original; fi
    elif test "$ENVIRONMENT" == "SDK"; then
      # There was no /bin/busybox to begin with..
      rm /bin/busybox
    fi

    /usr/sbin/dpkg-divert --remove /bin/busybox
}

# Remove all symlinks that the installation script has made
UNSYMLINK() {
    # Load list of installed symlinks
    touch $INSTALLDIR/busybox-power.symlinks
    source $INSTALLDIR/busybox-power.symlinks

    # Walk through all possible destinations
    for DESTDIR in $DESTINATIONS; do 
      # Enable us to see all entries in $DESTINATIONS as variables
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

      ECHO_VERBOSE "\nRemoving symlinks in $DIR"
      # Walk through all applications from the current destination
      for APP in $APPLICATIONS; do
        # The following code is executed for every application in the current destination
        if test -h $DIR/$APP; then 
          # Good, this app is still a symbolic link ..
          if test -n "`ls -l $DIR/$APP | grep busybox`"; then
            ECHO_VERBOSE "Removing link: $DIR/$APP"
            rm $DIR/$APP
          fi
        fi
      done
    done
}

# Action to be performed after restoring original busybox
CLEANUP() {
    OLDFILES="busybox-power.symlinks
      busybox.original.sha1"

    for file in $OLDFILES; do
      if test -e $INSTALLDIR/$file; then
        rm $INSTALLDIR/$file
      fi
    done
}

### Codepath ###
ECHO_VERBOSE "busybox-power: verbose mode"
ECHO_VERBOSE "  binary: $EXECPWR"
ECHO_VERBOSE "  version string: `$EXECPWR | $EXECPWR head -n 1`"
CHECK_ENV && ECHO_VERBOSE "  environment: $ENVIRONMENT"

CHECK_STANDALONE
CHECK_SYMLINKSFILE
CHECK_DIVERT
if test "$ENVIRONMENT" != "SDK"; then
  CHECK_ROOT
  CHECK_BACKUP
  CHECK_INSTALLEDBIN
fi
if test -e /tmp/busybox-power-error; then
  # An error has occured during the checks
  DISPLAY_ERRORS
fi
UNSYMLINK
UNINSTALL
CLEANUP

