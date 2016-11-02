#!/bin/bash

# This is an accompaning script for mk-production-sdcard.sh
# 
# The intention is to make it easy to do a 'dd' copy of a production SD card and that this copy will be
# guaranteed to fit on to any nominal 8GB SD card using the 'dd' command.
#
# Production SD cards are partitioned over the first 7100MiB (1024*1024) of the SD card. This is deliberatrly not the full
# capacity of an 8GB SD card but it should be the 'lowest common demonitor' of a size that all 8GB SD card can hold.

# Do a number of sanity checks first.
# 1) Check that there are two command line parameters. 1) sd card's device and 2) file  name to save dd image as 
# 2) A check the card's byte capacity
# 3) Check that there are 7 partitions on the SD card.

if [ ! $# -eq 2 ]; then 
  echo -e "\n\nUsage: Two input parameters are required.\n1)Specify the device name of the SD card i.e. /dev/sd[x]\n2) Input the name of the image file to be created e.g. ./sdcard.img"; 
  exit 1; 
fi

# First parameter is the sd card device.
# Second parameter is the name of the output file

# First the device has to have the correct capacity; nominally 8GB. We don't handle
# nominal 8GB that have fewer than 7100MiB capacity. 

args=("$@")

# SD cards of nominal size 8GB are not identical in capacity; they have a range of actual byte sizes.

# sd card range (lower=7400MiB)
LOWER=7759462400
UPPER=8000000000

# Have to pass external variables into 'awk' with -v
blockdev --getsize64 ${args[0]} | awk -F ' ' -v lower="$LOWER" -v upper="$UPPER" \
'
{ 
  if (($1 < lower) || ($1 > upper))
  {     
    print "SD card is not the correct size\nIt has to be a nominal 8GB"
    exit 1
  }
} 
'
if [ $? -eq 1 ]; then exit 1; fi 

# Check if the file requested already exists.

if [ -f ${args[1]} ]; then
  read -n 1 -p 'Requested output file already exists. Override? (y/n) ' yn
  echo
  case $yn in
    [Nn] ) exit 0;;
  esac
fi

# Use parted to get the list of SD card partitions. 
# The last logical partition #7's End value is what we want. This is the total size that we want to 'dd'
# We need this value and the 'bs for input and output' and from these two value we can determine 'dd's count value

parts=`sudo parted -s ${args[0]} unit mib print | awk -F ' ' '/^ [1-9]/ {print $1 " " $3}' | sort --reverse`

size=`echo $parts | awk -F ' ' '{ if ( $1 == 7 ) { print $2}} ' | sed 's/MiB//g' `

# echo $size"MiB"

# Prepare the 'dd' arguments

bs=100

count=`expr $size \* 1024 / $bs`

# echo "count = "$count

echo "Issuing command dd if=${args[0]} of=${args[1]} bs=$bs"K" count=$count"
echo "Monitor progress using command 'sudo kill -USR1 `pidof dd` ' from another command window"

if [ -f ${args[1]} ]; then
  rm ${args[1]}
fi

dd if=${args[0]} of=${args[1]} bs=$bs"K" count=$count 

if [ $? != 0 ]; then
  echo "Error from 'dd' command. The copy had a problem."
fi

# If you want to monitor the progress of 'dd' then from another
# terminal issue the commad sudo kill -USR1 `pifof dd`

#while [ `pidof dd` ]; do
#  kill -USR1 `pidof dd`
#  sleep 2
#done

exit 0



