##########################################################################################
#
# Magisk Module Installer Script
#
##########################################################################################
##########################################################################################
#
# Instructions:
#
# 1. Place your files into system folder (delete the placeholder file)
# 2. Fill in your module's info into module.prop
# 3. Configure and implement callbacks in this file
# 4. If you need boot scripts, add them into common/post-fs-data.sh or common/service.sh
# 5. Add your additional or modified system properties into common/system.prop
#
##########################################################################################

##########################################################################################
# Config Flags
##########################################################################################

# Set to true if you do *NOT* want Magisk to mount
# any files for you. Most modules would NOT want
# to set this flag to true
SKIPMOUNT=false

# Set to true if you need to load system.prop
PROPFILE=false

# Set to true if you need post-fs-data script
POSTFSDATA=true

# Set to true if you need late_start service script
LATESTARTSERVICE=false

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE="
"

##########################################################################################
#
# Function Callbacks
#
# The following functions will be called by the installation framework.
# You do not have the ability to modify update-binary, the only way you can customize
# installation is through implementing these functions.
#
# When running your callbacks, the installation framework will make sure the Magisk
# internal busybox path is *PREPENDED* to PATH, so all common commands shall exist.
# Also, it will make sure /data, /system, and /vendor is properly mounted.
#
##########################################################################################
##########################################################################################
#
# The installation framework will export some variables and functions.
# You should use these variables and functions for installation.
#
# ! DO NOT use any Magisk internal paths as those are NOT public API.
# ! DO NOT use other functions in util_functions.sh as they are NOT public API.
# ! Non public APIs are not guranteed to maintain compatibility between releases.
#
# Available variables:
#
# MAGISK_VER (string): the version string of current installed Magisk
# MAGISK_VER_CODE (int): the version code of current installed Magisk
# BOOTMODE (bool): true if the module is currently installing in Magisk Manager
# MODPATH (path): the path where your module files should be installed
# TMPDIR (path): a place where you can temporarily store files
# ZIPFILE (path): your module's installation zip
# ARCH (string): the architecture of the device. Value is either arm, arm64, x86, or x64
# IS64BIT (bool): true if $ARCH is either arm64 or x64
# API (int): the API level (Android version) of the device
#
# Availible functions:
#
# ui_print <msg>
#     print <msg> to console
#     Avoid using 'echo' as it will not display in custom recovery's console
#
# abort <msg>
#     print error message <msg> to console and terminate installation
#     Avoid using 'exit' as it will skip the termination cleanup steps
#
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target
#
# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context
#
##########################################################################################
##########################################################################################
# If you need boot scripts, DO NOT use general boot scripts (post-fs-data.d/service.d)
# ONLY use module scripts as it respects the module status (remove/disable) and is
# guaranteed to maintain the same behavior in future Magisk releases.
# Enable boot scripts by setting the flags in the config section above.
##########################################################################################

##########################################################################################
# Installation Message
##########################################################################################

# Set what you want to show when installing your mod

print_modname() {
  MODNAME=$(grep_prop name $TMPDIR/module.prop)
  # Split description at every 5th space so long descriptions fit better
  MODDESC=$(grep_prop description $TMPDIR/module.prop | sed 's/\(\([^ ]* \)\{4\}[^ ]*\) /\1\n/g')
  L_DESC=$(echo "$MODDESC" | awk '{if(length($0)>l) l=length($0);}END{l=l+1; print l}')
  NLENGTH=$(echo "$MODNAME" | wc -c)
  WIDTH=$(($L_DESC + 5))
  if [ "$((($WIDTH - $NLENGTH) % 2))" -ne 0 ]; then
     WIDTH=$(($WIDTH + 1))
     L_DESC=$(($L_DESC + 1))
  fi
  BREAK=$(seq -s "#" "$WIDTH" | sed 's/[0-9]//g')
  NSTART=$((($WIDTH - $NLENGTH) / 2))
  NEND=$(($WIDTH - $NSTART - 2)) 
  echo "$BREAK"
  printf "%-${NSTART}s%-${NEND}s%s\n" "#" "$MODNAME" "#"
  echo "$BREAK"
  echo "$MODDESC" | while read OUT; do
     printf "%1s %-${L_DESC}s %1s\n" "#" "$OUT" "#"
  done
  echo "$BREAK"
}

# Copy/extract your module files into $MODPATH in on_install.

on_install() {
  # The following is the default implementation: extract $ZIPFILE/system to $MODPATH
  # Extend/change the logic to whatever you want
  DBGLOG="/data/local/debug.log"
  maybe_debug
  ui_print "- Staging Scripts"
  unzip -o "$ZIPFILE" 'script/*' -d $TMPDIR >&2
  if [ -f $TMPDIR/script/pre.sh ]; then
     ui_print "- Running pre-install script"
     . $TMPDIR/script/pre.sh
     pre_install
  fi

  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2

  if [ -f $TMPDIR/script/post.sh ]; then
     ui_print "- Running post-install script"
     . $TMPDIR/script/post.sh
     post_install
  fi

}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases

set_permissions() {
   return 0
  # The following is the default rule, DO NOT remove
  # My installer handles permissions already
  #set_perm_recursive $MODPATH 0 0 0755 0644

  # Here are some examples:
  # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
  # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0     0       0644
}

# You can add more functions to assist your custom script code

# list_zip_contents <dir>
list_zip_contents() {
   unzip -l "$ZIPFILE" "$1/*" 2>/dev/null | tail -n+4 \
      | rev | cut -d" " -f1 | rev \
      | sed '$d' | sed '$d'
}

maybe_debug() {
   if [ -f /data/local/DEBUG_installer ]; then
      ui_print "- Debug logs located at $DBGLOG"
      exec 2>$DBGLOG
      set -x
   fi
}

