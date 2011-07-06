#!/bin/sh
# A script to restore /bin/busybox and delete created symlinks as defined in $INSTALLDIR/installed-symlinks
#
# Symbolic links are only removed if they are
# a) created by the installer script ("install-binary.sh")
# b) not replaced by a binary (i.e. they are still a symbolic link)
# c) pointing to a busybox binary

# By Dennis Groenen <dennis_groenen@hotmail.com>
# GPLv3 licensed

# Version 0.3 07-03-2011 (MM-DD-YYYY)
# 0.1: Initial release
# 0.2: Minor clean-ups and be quieter
# 0.3: Add support for multiple environments
#      Make use of functions in this script
#      Implement additional checks

INSTALLDIR="/opt/busybox-power"
EXECPWR="$INSTALLDIR/busybox.power"
VERBOSE="0"

# Print extra information in verbose mode
if test $VERBOSE == 1; then 
  echo "busybox-power: verbose mode" \ 
  echo "  binary: $EXECPWR" \ 
  echo "  version string: `$EXECPWR | $EXECPWR head -n 1`"
fi

# Detect environment
CHECK_ENV() {
    if test -d /scratchbox
      then
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

    if test $VERBOSE == 1; then echo "  environment: $ENVIRONMENT"; fi
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
    if test -e $INSTALLDIR/busybox.power.md5
      then
        INSTBINARY_MD5=`md5sum /bin/busybox | awk '{ print $1 }'`
        ORIGBINARY_MD5=`cat $INSTALLDIR/busybox.power.md5`
        if test ! "$INSTBINARY_MD5" == "$ORIGBINARY_MD5"; then
          echo -e "Warning: /bin/busybox has been modified since installing busybox-power (invalid md5 checksum). The original BusyBox binary at the time of installation will replace it if you continue.\n"  >> /tmp/busybox-power-error
        fi
    fi

    if test -e $INSTALLDIR/busybox.original.md5
      then
        INSTBINARY_MD5=`cat $INSTALLDIR/busybox.original.md5`
        ORIGBINARY_MD5=`md5sum $INSTALLDIR/busybox.original | awk '{ print $1 }'`
        if test ! "$INSTBINARY_MD5" == "$ORIGBINARY_MD5"; then
          echo -e "Warning: the backed-up original binary has been modified since installing busybox-power (invalid md5 checksum). Do not continue unless you're sure $INSTALLDIR/busybox.original isn't corrupted.\n"  >> /tmp/busybox-power-error
        fi
      else
        echo -e "Warning: couldn't load the saved md5 checksum of the original binary; the integrity of the backup of the original binary can not be guaranteed.\n"  >> /tmp/busybox-power-error
    fi
}

# Display encountered errors
DISPLAY_ERRORS() {
      case $ENVIRONMENT in
        SDK)
          echo -e "\n\n-----------Attention!-----------"
          cat /tmp/busybox-power-error
          rm /tmp/busybox-power-error
          echo "-> Please press [enter] to ignore the above errors/warnings. Hit [ctrl-c] to break"
          read 
        ;;
        N900)
          echo "Click \"I Agree\" to ignore the above errors/warnings. Ask for help if you don't know what to do." >> /tmp/busybox-power-error
          maemo-confirm-text "Attention!" /tmp/busybox-power-error
          res=$?
          rm /tmp/busybox-power-error
          if test ! $res == 0; then exit 1; fi
        ;;
      esac

      touch $INSTALLDIR/busybox-power.symlinks
}

# Uninstallation of the enhanced binary on the N900
E_N900_UNINST() {
    if test -e $INSTALLDIR/busybox.original 
      then
        cp -f $INSTALLDIR/busybox.original /bin/busybox
        if test -e /bin/busybox; then rm $INSTALLDIR/busybox.original; fi
    fi 
}

# Uninstallation of the enhanced binary in Maemo's SDK
E_SDK_UNINST() {
    if test -e $INSTALLDIR/busybox.original
      then
	cp -f $INSTALLDIR/busybox.original /bin/busybox
	if test -e /bin/busybox; then rm $INSTALLDIR/busybox.original; fi
      else
	rm /bin/busybox
    fi
}

# Remove all symlinks that busybox-power has made
UNSYMLINK() {
    # Load list of installed symlinks
    source $INSTALLDIR/busybox-power.symlinks

    # Walk through all possible destinations
    for DESTDIR in $DESTINATIONS
      do 
        # Enable us to see all entries in $DESTIONATION as variables
        eval "APPLICATIONS=\$$DESTDIR"
        # Set destination dirrectory accordingly
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

      if test $VERBOSE == 1; then echo -e "\nRemoving symlinks in $DIR"; fi
      # Walk through all applications from the current destination
      for APP in $APPLICATIONS
        do
          # The following code is executed for every application in the current destination
          if test -h $DIR/$APP # Check if the app is a symbolic link
	    then
	      if test -n "`ls -l $DIR/$APP | grep busybox`" # Check if the symbolic link points to busybox
	        then
	          if test $VERBOSE == 1; then echo "Removing link: $DIR/$APP"; fi
	          rm $DIR/$APP
	      fi
          fi
      done
    done
}

# Action to be performed after restoring original busybox
POST_UNINST() {
    OLDFILES="busybox-power.symlinks
      busybox.power.md5
      busybox.original.md5"

    for file in $OLDFILES
      do
	if test -e $INSTALLDIR/$file; then
	  rm $INSTALLDIR/$file
	fi
      done
}

### Codepath ###
CHECK_ENV
GENERIC_CHECKS
case $ENVIRONMENT in
  SDK)
    # Check for errors before restoring BusyBox
    if test -e /tmp/busybox-power-error
      then DISPLAY_ERRORS; fi
    E_SDK_UNINST
  ;;
  N900)
    E_N900_CHECKS
    E_N900_PRERM
    # Check for errors before restoring BusyBox
    if test -e /tmp/busybox-power-error
      then DISPLAY_ERRORS; fi
    E_N900_UNINST
  ;;
esac
UNSYMLINK
POST_UNINST

