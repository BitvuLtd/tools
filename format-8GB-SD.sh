#!/bin/bash

# Script that uses 'parted' to create multiple pre-defined partitions on a nominal 8GB SD card.
#----------------------------------------------------------------------------------------------

if [ $# -eq 0 ]; then echo -e "\n\nUsage: Specify the SD card device to be formatted i.e. /dev/sd[x]\nBe *absolutely* certain you specify the correct device."; exit; fi

# First parameter is the sd card device.

# First the device has to have the correct capacity; nominally 8GB. We don't handle
# 4GB or greater than 8GB. This is constrained by the hardware requirements and not just
# some arbitary limit.
args=("$@")

# SD cards of nominal size 8GB are not identical in capacity; they have a range of actual byte sizes.

# sd card range (lower=74MiB)
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

# Delete all current partitions
parts=`sudo parted -s ${args[0]} print | awk -F ' ' '/^ [1-9]/ {print $1}' | sort --reverse`

 echo $parts

for p in $parts; do 
  # echo " remove partition $p"
  sudo parted -s ${args[0]} rm $p
done


# Recreate partitions for our usage.
# Partition set up. Sizes are in MiB (1024*1024)
# This choice help when we want to 'dd' the disk because then we can setup 'dd' to copy only the extent of
# all the partitions and _not_ the entire SD card.
UNIT=MiB

# echo $UNIT

bootp=("primary", "fat32", "40", "100")
rootp=("primary", "ext4", "100", "2100")
shadowp=("primary", "ext4", "2100", "4100")
extendp=("extended", "4100", "7400")
## Seems there has to be some space set aside in the extended partition for a partition table(?) before the first allocated logical partition
datap1=("logical", "ext4", "4102", "5502")
datap2=("logical", "ext4", "5502", "6902")
datap3=("logical", "ext4", "6902", "7400")

# echo "First Method:  ${bootp[*]}"
# echo "Second Method: ${bootp[@]}"

 # echo  ${bootp[*]} | sed 's/,//g'

# Give user some feedback
echo -e "Creating partitions ...\n"
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${bootp[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${rootp[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${shadowp[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${extendp[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${datap1[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${datap2[*]} | sed 's/,//g'`
sudo parted -s -a optimal ${args[0]} unit $UNIT mkpart `echo ${datap3[*]} | sed 's/,//g'`
echo -e "Done\n"

# Count the partitions
sudo parted -s ${args[0]} print | awk -F ' ' '/^ [1-9]/ {print $1}' | wc -l > /dev/null

# echo "We have " `sudo parted -s ${args[0]} print | awk -F ' ' '/^ [1-9]/ {print $1}' | wc -l` "newly created partitions."

# reload fstab
# sudo mount -a 

echo -e "Formatting partitions...\n"
mkfs.vfat ${args[0]}1 -n boot -F32
mkfs.ext4 ${args[0]}2 -L root
mkfs.ext4 ${args[0]}3 -L shadow
# 
# Can't format an extended partition
#
mkfs.ext4 ${args[0]}5 -L data1
mkfs.ext4 ${args[0]}6 -L data2
mkfs.ext4 ${args[0]}7 -L data2

echo -e "Done\n\n\n"

# Print what has been created.
sudo parted -s ${args[0]} unit mib print free

exit 0

