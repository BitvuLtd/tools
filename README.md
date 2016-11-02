# tools

A collection of scripts to aid in the day-to-day administrration of software for the company's products.

**format-8GB-SD.sh** - bash script to format a nomimal 8GB SD card with 7 partitions (boot, fs, shadow-fs, logical, data-1, data-2, update)

**mk-SD-img.sh** - bash script to ease the pain of using the dd command to create an image of an SD card. It is to be used in conjunction
with an 8GB SD card that has been formatted using the format-8GB-SD.sh script. This script only copies the exact byte count of the paritions to the specified output image file. 
