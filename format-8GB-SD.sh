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
# Production SD card is smaller than current LOWER value.
# sd card range (lower=7,562,880KiB)
LOWER=7744389120
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


# Ask user if they would like the whole device 'zerord' before starting the formatting. This has the later potential to
# increase the compression ratio of the image of the SD card when using zip.
echo ""
echo ""
echo "Would you like to write zeros to the SD card before starting formatting?"
echo "This has the potential to make the SD card image smaller after it has been zipped."
echo "This does take quite a long time. To monitor progress issue the commad \"  sudo kill -USR1 \`pidof dd\` \" "
echo "from a second terminal"
echo ""

select yn in "Yes" "No"; do
 	case $yn in
		Yes )  
					echo "Issuing command dd if=/dev/zero of=${args[0]} bs=1M "
					sudo dd if=/dev/zero of=${args[0]} bs=1M
					# When the SD card has been flattened then we have to add a label to the SD card afterwards
					sudo parted ${args[0]} mklabel msdos
					break;;

		No  ) break;;
    esac
done

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
UNIT=KiB

# echo $UNIT

bootp=("primary", "fat32", "40960", "102400")
rootp=("primary", "ext4", "102400", "2150400")
shadowp=("primary", "ext4", "2150400", "4198400")
extendp=("extended", "4198400", "7562880")
## Seems there has to be some space set aside in the extended partition for a partition table(?) before the first allocated logical partition
datap1=("logical", "ext4", "4198401", "5646337")
datap2=("logical", "ext4", "5646338", "7094273")
datap3=("logical", "ext4", "7094274", "7562880")

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
sudo parted -s ${args[0]} unit kib print free

exit 0

