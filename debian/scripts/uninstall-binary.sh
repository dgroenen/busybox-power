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
# Last updated: 03-11-2012 (MM-DD-YYYY)
# 

INSTALLDIR="/opt/busybox-power"
EXECPWR="$INSTALLDIR/busybox.power"
VERBOSE="0"

ECHO_VERBOSE() {
  if test $VERBOSE == 1; then 
    echo -e "$1"; fi
}

# Detect environment
CHECK_ENV() {
    if test -d /scratchbox; then
      ENVIRONMENT="SDK"
    else
      PROD=$(cat /proc/component_version | grep product | cut -d" " -f 6)
      case $PROD in
        RX-51)
          ENVIRONMENT="N900"
          ;;
        *)
          # Unsupported, use the least strict environment (SDK)
          ENVIRONMENT="SDK"
          ;;
      esac
    fi
}

# Environment-independent checks before continuing
GENERIC_CHECKS() {
    #if test -n "`pgrep dpkg`" -o "`pgrep apt`"
    if ! lsof /var/lib/dpkg/lock >> /dev/null; then 
      echo "error: you're running me as a stand-alone application"
      echo "  do not do this, I will be called automatically upon"
      echo "  deinstallation of busybox-power"
      exit 1
    fi

    if test ! -e $INSTALLDIR/busybox-power.symlinks; then
      echo -e "Error: cannot find the list of symlinks to be removed. No symlinks will be removed at all!\n" >> /tmp/busybox-power-error
    fi
}

# Additional checks for the N900
E_N900_CHECKS() {
    if test "`id -u`" -ne 0; then
      echo "error: you're not running me as root, aborting"
      echo "  also, DO NOT run me as a stand-alone application"
      echo "  I will be called automatically upon deinstallation"
      echo "  of busybox-power"
      exit 1
    fi

    if test ! -e $INSTALLDIR/busybox.original; then
      echo -e "Error: original binary is missing! Continuing will only remove the symlinks made during installation, /bin/busybox stays untouched.\n" >> /tmp/busybox-power-error
    fi
}

# N900-specific code executed prior to uninstalling the enhanced binary
E_N900_PRERM() {
    if test -e $INSTALLDIR/busybox.power.md5; then
      INSTBINARY_MD5=`md5sum /bin/busybox | awk '{ print $1 }'`
      ORIGBINARY_MD5=`cat $INSTALLDIR/busybox.power.md5`
      if test ! "$INSTBINARY_MD5" == "$ORIGBINARY_MD5"; then
        echo -e "Warning: /bin/busybox has been modified since installing busybox-power (invalid md5 checksum). The original BusyBox binary at the time of installation will replace it if you continue.\n" >> /tmp/busybox-power-error
      fi
    fi

    if test -e $INSTALLDIR/busybox.original.md5; then
      INSTBINARY_MD5=`cat $INSTALLDIR/busybox.original.md5`
      ORIGBINARY_MD5=`md5sum $INSTALLDIR/busybox.original | awk '{ print $1 }'`
      if test ! "$INSTBINARY_MD5" == "$ORIGBINARY_MD5"; then
        echo -e "Warning: the backed-up original binary has been modified since installing busybox-power (invalid md5 checksum). Do not continue unless you're sure $INSTALLDIR/busybox.original isn't corrupted.\n" >> /tmp/busybox-power-error
      fi
    else
      echo -e "Warning: couldn't load the saved md5 checksum of the original binary; the integrity of the backup of the original binary can not be guaranteed.\n" >> /tmp/busybox-power-error
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
      N900)
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
    if test -e $INSTALLDIR/busybox.original; then
      cp -f $INSTALLDIR/busybox.original /bin/busybox
      if test -e /bin/busybox; then
        rm $INSTALLDIR/busybox.original; fi
    else
      if test "$ENVIRONMENT" == "SDK"; then
        # There was no /bin/busybox to begin with..
        rm /bin/busybox
      fi
    fi
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
      busybox.power.md5
      busybox.original.md5"

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
GENERIC_CHECKS
case $ENVIRONMENT in
  N900)
    E_N900_CHECKS
    E_N900_PRERM
    ;;
esac
if test -e /tmp/busybox-power-error; then
  # An error has occured during the checks
  DISPLAY_ERRORS
fi
UNSYMLINK
UNINSTALL
CLEANUP

