#!/bin/sh
#
# decrypt_osc.sh - Decrypt data files that were received from OSC.
#
# Project: osc-data-transfer
# Author: Ken Zalewski
# Organization: New York State Senate
# Date: 2011-04-25
# Revised: 2011-04-27
#
# Note: This script depends on GnuPG (v1, though v2 will work as well) with
#       IDEA support compiled in.  Versions of GnuPG prior to 2016 did not
#       have the IDEA cipher compiled in due to a copyright issue.  As of
#       2016, that copyright has expired, so IDEA is now included.
# Note: The Senate key has a passphrase which much be stored in the file:
#          $HOME/.gnupg/osc_data_xfer_passphrase.txt
#

prog=`basename $0`
passfile="$HOME/.gnupg/osc_data_xfer_passphrase.txt"

usage() {
  echo "Usage: $prog encrypted_file" >&2
}

if [ $# -ne 1 ]; then
  usage
  exit 1
elif [ ! -r "$passfile" ]; then
  echo "$prog: $passfile: Unable to read passphrase file." >&2
  exit 1
fi

enc_file="$1"

if [ ! -r "$enc_file" ]; then
  echo "$prog: $enc_file: Encrypted file not found." >&2
  exit 1
fi

gpg --quiet --batch --passphrase-file "$passfile" "$enc_file"

