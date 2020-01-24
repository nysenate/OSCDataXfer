#!/bin/sh
#
# cron_send_osc.sh - Send SFS (voucher/encumbrance) and Payserv files to OSC
#
# Project: osc-data-transfer
# Author: Ken Zalewski
# Organization: New York State Senate
# Date: 2019-01-24
#

prog=`basename $0`
script_dir=`dirname $0`
ftype_list="sfs paysr"

log_msg() {
  ts=`date +%Y%m%d.%H%M%S`
  echo "$ts $@"
}

log_msg "Sending files to OSC, types=[$ftype_list]"

for ftype in $ftype_list; do
  log_msg "Starting transfer of [$ftype] files to OSC"
  $script_dir/xfer_files.sh put:$ftype
  log_msg "Finished transfer of [$ftype] files to OSC"
done

log_msg "Completed sending of files to OSC"

exit 0
