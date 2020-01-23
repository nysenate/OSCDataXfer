#!/bin/sh
#
# xfer_files.sh - Transfer files to and from OSC
#
# Project: osc-data-transfer
# Author: Ken Zalewski
# Organization: New York State Senate
# Date: 2019-08-14
# Revised: 2020-01-23 - consolidated into a single transfer script
#
# This script handles the transfer of files to and from OSC.
#
# There are four types of files that are transferred from OSC to the Senate:
#   - "sfs": SFS Senate-specific files (22 sent each day; archived)
#   - "shared": SFS Statewide files (20 sent each day; not archived)
#   - "idl": SFS IDL files (1 sent in response to each sent file; archived)
#   - "paysr": Payserv 501, 520, 574a, 574b files (most are daily; archived)
#
# The SFS Senate-specific files from OSC are of the form:
#   <agencyCode>_<fileType>_<date>
# where <agencyCode> is either: 00000 or 04000
#   and <fileType> is one of:
#     DACCTG_CDS, DM041, DM061, DM062, DM081, DM131, DM151, DM171, DMFTEX, D_BD,
#     D_EA, D_EX, D_GB, D_GL, D_KB, D_KK, D_PC, D_PO, D_RV, D_TR, D_VA, D_VO
#   and <date> is of the form: MMDDYY
#
# The SFS Statewide files from OSC are of the form:
#   <agencyCode>_<fileType>_<date>
# where <agencyCode> is either: 95000 or 95001
#   and <fileType> is one of:
#     D_BT, D_CT, D_XL, D_BD, D_CO, D_EA, D_EX, D_GB, D_GL, D_IA, D_IC, D_IM,
#     D_KB, D_KK, D_PC, D_PO, D_RV, D_TR, D_VA, D_VO
#   and <date> is of the form: MMDDYY
# The Senate downloads 5 of those 20 files every day.  Those files are:
#   D_CT, D_XL, D_GL, D_IC, and D_IM
#
# The SFS IDL files from OSC are of the form:
#   IDL_BKLD_<filebase>_<datetime>.dat_<date>.txt
# where <filebase> is the basename of the original file without the extension
#   and <datetime> is of the form: MMDDYYYY_hhmmss.nnn
#   and <date> is of the form: YYYY-MM-DD
#
# The Payserv files from OSC are of the form:
#   paysrp.nhrp<fileType>.ac04000.dat.<date>.<time>
# where <fileType> is one of: 501.a (salary ledger), 520, 574a|574b (AI results)
#   and <date> is of the form: YYYYMMDD
#   and <time> is of the form: hhmmss
#
# There are two types of files that are transferred from the Senate to OSC:
#   - "sfs": SFS voucher and encumbrance files, generated by SFMS
#   - "paysr": Payserv 502 and 573 files, generated by SFMS
#
# The SFS voucher/encumbrance files from the Senate are of the form:
#   SEN01<fileType><date><version>.DAT
# where <fileType> is one of:  V, J, M, R (vouchers) or E (encumbrance)
#   and <date> is of the form: YYMMDD
#   and <version> is of the form: nn; starts at "01"; increments on same date
#
# The Payserv files from the Senate are of the form:
#   paysrp.<fileType>.ac04000.input
# where <fileType> is either "npay502" (time entry) or "nhrp573" (AI)
#
# Note that if any of these files is prefixed with a comma, the file will
# not be sent to OSC.  It is still stored on the local transfer server.
#

prog=`basename $0`
script_dir=`dirname $0`
date_year=`date +%Y`
data_dir=/data/osc
toc_file=xfer_files.lst
lftp_file=script.lftp

# Config file parameters
ftype_str=source
local_dir=
src_host=
src_dir=
src_user=
archive_src=0
dest_host=
dest_dir=
dest_user=

# Command line parameters
xfer_mode=
config_file=
date_pattern=
skip_get=0
skip_put=0
keep_files=0
verbose=0


usage() {
  echo "Usage: $prog [-f config-file] [-d date] [--skip-get] [--skip-put] [--keep-files] [--verbose] transfer_mode" >&2
  echo "  where <transfer_mode> is of the form: <direction>:<filetype>" >&2
  echo '  where <direction> is either "get" or "put"' >&2
  echo "    and <filetype> is one of: sfs, shared, idl, paysr" >&2
}


log_msg() {
  ts=`date +%Y%m%d.%H%M%S`
  echo "$ts $@"
}


while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --config*|-f) shift; config_file="$1" ;;
    --date*|-d) shift; date_pattern="$1" ;;
    --skip-get) skip_get=1 ;;
    --skip-put) skip_put=1 ;;
    --keep*) keep_files=1 ;;
    --verbose|-v) verbose=1 ;;
    -*) echo "$prog: $1: Unknown option" >&2; usage; exit 1 ;;
    *) xfer_mode="$1" ;;
  esac
  shift
done

case "$xfer_mode" in
  get:sfs|get:shared|get:idl|get:paysr|put:sfs|put:paysr) ;;
  "") echo "$prog: transfer_mode must be specified"; usage; exit 1 ;;
  get:*) echo "$prog: Invalid filetype for get; must be one of: sfs, shared, idl, paysr" >&2; exit 1 ;;
  put:*) echo "$prog: Invalid filetype for put; must be one of: sfs, paysr" >&2; exit 1 ;;
  *) echo "$prog: $xfer_mode: Invalid transfer_mode; must be one of: get:sfs, get:shared, get:idl, get:paysr, put:sfs, or put:paysr" >&2; exit 1 ;;
esac

xfer_mode=`echo $xfer_mode | tr : _`

# Calculate config_file from the xfer_mode
[ "$config_file" ] || config_file="/etc/osc_xfer_${xfer_mode}.cfg"

if [ ! -r "$config_file" ]; then
  echo "$prog: $config_file: Configuration file not found" >&2
  exit 1
fi

# Read in the config parameters.
. "$config_file" || exit 1

# Check that required config parameters were set.
for p in local_dir src_host src_dir src_user archive_src dest_host dest_dir dest_user; do
  if [ -z "${!p}" ]; then
    echo "$prog: $p: Config parameter is not set; check [$config_file]" >&2
    exit 1
  fi
done

# If local_dir was specified as a relative path, make it absolute.
if [ "${local_dir:0:1}" != "/" ]; then
  local_dir="$data_dir/$local_dir/$date_year"
fi

if [ ! -r "$local_dir" ]; then
  echo "$prog: $local_dir: Archive directory not found on local filesystem" >&2
  exit 1
fi

# All work will be done within the local archive directory.
cd "$local_dir" || exit 1

src_url="sftp://$src_host/$src_dir"
dest_url="sftp://$dest_host/$dest_dir"

# If a date-matching pattern was not given, then use yesterday's date
# in the format MMDDYY.
[ "$date_pattern" ] || date_pattern=`date --date="-1 day" +%m%d%y`

# Set the source filename matching pattern for the given xfer_mode
case "$xfer_mode" in
  get_sfs) fpattern="*_$date_pattern" ;;
  get_shared)
    # The statewide files cannot be archived.  The only way to prevent
    # downloading these files more than once is to check against the archive.
    dlfiles=
    for ftype in CT XL GL IC IM; do
      if [ ! -f 9500[01]_D_${ftype}_${date_pattern} ]; then
        dlfiles="$dlfiles *_D_${ftype}_${date_pattern}"
      fi
    done

    if [ "$dlfiles" ]; then
      fpattern="$dlfiles"
    else
      log_msg "All $ftype_str files for [$date_pattern] were already downloaded"
      fpattern="*_NO_FILES_TO_DOWNLOAD"
    fi
    ;;
  get_idl) fpattern="IDL_BKLD_*" ;;
  get_paysr) fpattern="paysrp.*" ;;
  put_sfs) fpattern="SEN01* ,SEN01*" ;;
  put_paysr) fpattern="paysrp.* ,paysrp.*" ;;
esac

[ $verbose -eq 1 ] && log_msg "File matching pattern: $fpattern"


##############################################################################
# Step 1:  Generate the list of files to be downloaded from the source host
##############################################################################
if [ $skip_get -ne 1 ]; then
  log_msg "Generating list of $ftype_str files to be downloaded from $src_url"
  rm -f "$toc_file"
  lftp -u "$src_user",'' "$src_url" << EOF
    cls -1 $fpattern > "$toc_file"
EOF
else
  [ -r "$toc_file" ] || touch "$toc_file"
fi

fcount=`cat "$toc_file" | wc -l`

##############################################################################
# Step 2:  Download the files from the source host to the local server
##############################################################################
if [ $skip_get -ne 1 ]; then
  if [ $fcount -ne 0 ]; then
    log_msg "List of files to be transferred:"
    cat "$toc_file"

    log_msg "Generating lftp script for download"
    echo "open -u $src_user,'' $src_url" > "$lftp_file"
    echo "echo Transferring files..." >> "$lftp_file"
    sed 's;^;get ;' "$toc_file" >> "$lftp_file"
    if [ $archive_src -eq 1 ]; then
      echo "echo Archiving files..." >> "$lftp_file"
      sed -e 's;^;mv ;' -e 's;$; archive/;' "$toc_file" >> "$lftp_file"
    fi

    if [ $verbose -eq 1 ]; then
      log_msg "Contents of lftp script:"
      cat "$lftp_file"
    fi

    log_msg "Downloading $ftype_src files from $src_url"
    lftp -f "$lftp_file"
    log_msg "Finished downloading $ftype_str files from $src_url"
  else
    log_msg "There are no files to download from $src_url"
  fi
else
  log_msg "Skipping the download of $ftype_str files from $src_url"
fi

log_msg "There were $fcount $ftype_str file(s) retrieved from $src_url"

##############################################################################
# Step 3:  Upload the files from the local server to the destination host
##############################################################################
if [ $skip_put -ne 1 ]; then
  if [ $fcount -ne 0 ]; then
    log_msg "Generating lftp script for upload"
    echo "open -u $dest_user,'' $dest_url" > "$lftp_file"
    echo "echo Transferring files..." >> "$lftp_file"
    # Do not upload files that begin with a comma.
    grep -v '^,' "$toc_file" | sed 's;^;put ;' >> "$lftp_file"

    if [ $verbose -eq 1 ]; then
      log_msg "Contents of lftp script:"
      cat "$lftp_file"
    fi

    log_msg "Uploading $ftype_str files to $dest_url"
    lftp -f "$lftp_file"
    log_msg "Finished uploading $ftype_str files to $dest_url"

    # Rename outbound Payserv files on the local server, since these
    # files do not include a timestamp.
    if [ $xfer_mode = "put_paysr" ]; then
      log_msg "Renaming local files to add a timestamp"
      ts=`date +%Y%m%d.%H%M%S`
      sed -e "s;^\(.*\)\$;mv \1 \1.$ts;" "$toc_file" | sh
    fi
  else
    log_msg "There are no files to upload to $dest_url"
  fi
else
  log_msg "Skipping the upload of $ftype_str files to $dest_url"
fi

if [ $keep_files -ne 1 ]; then
  rm -f "$toc_file" "$lftp_file"
fi

exit 0