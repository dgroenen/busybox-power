#!/bin/sh
# A script to replace /bin/busybox and creates symlinks to new functions.
# The default locations of busybox' functions (applets) are defined in the file $INSTALLDIR/functions
# It keeps track of the installed symlinks by writing them to $INSTALLDIR/installed-symlinks in
# a similiar fashion as locations are defined in the "functions" file.
#
# The scripts check whether symlinks/binaries of the utilities already exist, and if not,
# it checks whether the new busybox binary supports it. If so, it creates a symlink to /bin/busybox.
#
# NB The busybox binary needs to support the install applet
#
# By Dennis Groenen <tj.groenen@gmail.com>
# GPLv3 licensed
#
# Last updated: 11-22-2011 (MM-DD-YYYY)
# 

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
        PROD=$($EXECPWR cat /proc/component_version | $EXECPWR grep product | $EXECPWR cut -d" " -f 6)
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
      echo "  installation of busybox-power"
      exit 1
    fi

    if test ! -e $INSTALLDIR/functions; then
      echo "error: cannot find list of defined functions"
      exit 1
    fi

    if test -e $INSTALLDIR/busybox-power.symlinks; then
      echo "error: symlinks already seem to be made?"
      echo "  this script is not supposed to be ran twice"
      exit 1
    fi
}

# Additional checks for the N900
E_N900_CHECKS() {
    if test "`$EXECPWR id -u`" -ne 0; then
      echo "error: you're not running me as root, aborting"
      echo "  also, DO NOT run me as a stand-alone application"
      echo "  I will be called automatically upon installation"
      echo "  of busybox-power"
      exit 1
    fi
}

# N900-specific code executed prior to installing the enhanced binary
E_N900_PREINST() {
    md5sum $INSTALLDIR/busybox.power | $EXECPWR awk '{ print $1 }' > $INSTALLDIR/busybox.power.md5
    md5sum /bin/busybox | $EXECPWR awk '{ print $1 }' > $INSTALLDIR/busybox.original.md5

    # Check whether busybox-power isn't installed already
    INSTBINARY_MD5=`$EXECPWR cat $INSTALLDIR/busybox.power.md5`
    ORIGBINARY_MD5=`$EXECPWR cat $INSTALLDIR/busybox.original.md5`
    if test "$INSTBINARY_MD5" == "$ORIGBINARY_MD5"
      then
        echo "warning: installed busybox binary matches the binary"
        echo "  that is to be installed"
        if ! test -e $INSTALLDIR/busybox.original; then 
          $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original; fi
      else
        $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original
    fi
}

# SDK-specific code executed prior to installing the enhanced binary
E_SDK_PREINST() {
    if test -e /bin/busybox
      then
        $EXECPWR cp /bin/busybox $INSTALLDIR/busybox.original
    fi
}

# Overwrite old busybox binary with bbpower's one
INSTALL() {
    $EXECPWR cp -f $INSTALLDIR/busybox.power /bin/busybox
}

# Creates missing symlinks to busybox' binary
SYMLINK() {
    # Load defined BusyBox functions
    source $INSTALLDIR/functions

    # Get a list of supported functions by busybox-power
    if test -d /tmp/busybox-power; then $EXECPWR rm -Rf /tmp/busybox-power; fi
    $EXECPWR mkdir -p /tmp/busybox-power
    $INSTALLDIR/busybox.power --install -s /tmp/busybox-power
    $EXECPWR ls /tmp/busybox-power/ > $INSTALLDIR/functions_supported
    $EXECPWR rm -Rf /tmp/busybox-power

    # Prepare file which keeps track of installed symlinks by busybox-power
    echo "# Automatically generated by busybox-power. DO NOT EDIT" > $INSTALLDIR/busybox-power.symlinks
    echo -e "\nDESTINATIONS=\"$DESTINATIONS\"" >> $INSTALLDIR/busybox-power.symlinks
    echo -e "\n# Installed symlinks" >> $INSTALLDIR/busybox-power.symlinks

    # Walk through all possible destinations
    for DESTDIR in $DESTINATIONS
      do 
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

      if test $VERBOSE == 1; then echo -e "\nSymlinking functions in $DIR"; fi
      # Walk through all applications from the current destination
      for APP in $APPLICATIONS
        do
          # The following code is executed for every application in the current destination
          if test ! -e $DIR/$APP
            then
              # Check whether the function is supported by the busybox binary
              if `$EXECPWR grep -Fq "$APP" $INSTALLDIR/functions_supported` 
                then
                  if test $VERBOSE == 1; then echo "Symlinking: /bin/busybox -> $DIR/$APP"; fi
                  $EXECPWR ln -s /bin/busybox $DIR/$APP
                  SYMLINKS="$SYMLINKS $APP" 
              fi
          fi
      done

      # Write out installed symlinks
      echo "$SYMLINKS\"" >> $INSTALLDIR/busybox-power.symlinks
    done

    $EXECPWR rm $INSTALLDIR/functions_supported
}

### Codepath ###
CHECK_ENV
GENERIC_CHECKS
case $ENVIRONMENT in
  SDK)
    E_SDK_PREINST
  ;;
  N900)
    E_N900_CHECKS
    E_N900_PREINST
  ;;
esac
INSTALL
SYMLINK

