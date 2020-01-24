#!/bin/sh
#
# cron_recv_osc.sh - Retrieve SFS, Statewide, IDL, and Payserv files from OSC
#
# Project: osc-data-transfer
# Author: Ken Zalewski
# Organization: New York State Senate
# Date: 2019-01-24
#

prog=`basename $0`
script_dir=`dirname $0`
ftype_list="sfs shared idl paysr"

log_msg() {
  ts=`date +%Y%m%d.%H%M%S`
  echo "$ts $@"
}

for ftype in $ftype_list; do
  log_msg "Starting transfer of [$ftype] files from OSC"
  $script_dir/xfer_files.sh get:$ftype
  log_msg "Finished transfer of [$ftype] files from OSC"
done

exit 0
