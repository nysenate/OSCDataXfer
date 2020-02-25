#!/bin/sh
#
# cron_send_osc.sh - Send SFS (voucher/encumbrance) and Payserv files to OSC
#
# Project: osc-data-transfer
# Author: Ken Zalewski
# Organization: New York State Senate
# Date: 2019-01-24
# Revised: 2020-02-25 - allow file types to be specified on the command line
#

prog=`basename $0`
script_dir=`dirname $0`
default_ftypes="sfs paysr"
ftype_list=

log_msg() {
  ts=`date +%Y%m%d.%H%M%S`
  echo "$ts $@"
}

usage() {
  echo "Usage: $prog [filetype [filetype ...] ]" >&2
  echo "Default file types if none provided: $default_ftypes" >&2
}


while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    -*) echo "$prog: $1: Invalid option" 2>&1; usage; exit 1 ;;
    *) ftype_list="$ftype_list $1" ;;
  esac
  shift
done

[ "$ftype_list" ] || ftype_list="$default_ftypes"

log_msg "Sending files to OSC, types=[$ftype_list]"

for ftype in $ftype_list; do
  log_msg "Starting transfer of [$ftype] files to OSC"
  $script_dir/xfer_files.sh put:$ftype
  log_msg "Finished transfer of [$ftype] files to OSC"
done

log_msg "Completed sending of files to OSC"

exit 0
