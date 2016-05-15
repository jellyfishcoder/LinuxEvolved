#!/bin/bash

# Inform user of what this file will do
echo "This script will setup this Linux system to show up in the Mac OS X EFI boot sources menu, which you can access by holding the OPTION/ALT key as soon as the Mac boots."

# Set the package manager
# (PM stands for package manager, IC stands for install command)
case `uname` in
	Linux )
		LINUX=1
		# Check for which package manager they use
		## ADD SUPPORT FOR MULTIPLE PACKAGE MANAGERS LATER ##
		;;
	Darwin )
		DARWIN=1
		echo "Please read the description on Github, this is meant to be ran from a Linux system that you want to duel boot with OS X, not from the OS X system, it makes no changes to the OS X System or OS X EFI."
		exit 1
		;;
esac

echo "This script expects hfsprogs and icnsutils to be installed, by default it will install them automatically using apt-get. This is recommended and will ensure the script will be able to run, but if you do not have apt-get on your distro, stop this setup script, install hfsprogs and icnsutils using the package manager of your choice, then rerun this script and type skip when prompted to automatically install dependencies."
read -p 'Type skip to skip dependency installation (must have previously installed manually: ' skipvar
if [ "$skipvar" = "skip" ]
then
	skip=1
	echo "Skiping apt-get dependency installation."
else
	skip=0
	
	## First install hfsprogs using apt-get
	echo "Installing hfsprogs using apt-get"
	echo "hfsprogs provides support for the Apple HFS filesystem, this allows the setup script to create a small boot partition later that the Apple EFI can recognize and use to boot from."
	# Thats a lot of important text, so give the user a bit to read it
	sleep 5
	apt-get install hfsprogs -qq && echo "Finished installing hfsprogs"
	
	## Now install icnsutils using apt-get
	echo "Installing icnsutils using apt-get"
	echo "icnsutils provides support for creating and manipulating Mac OS X .icns files. This lets the setup script be able to add a icon to the Mac OS X boot menu, which only will display .icns files."
	# Thats a lot of important text, so give the user a bit to read it
	sleep 5
	apt-get install icnsutils -qq && echo "Finished installing icnsutils"
fi

## Here is where the main part of LinuxEvolved begins
## Before now was just installing dependencies

# As this involves modifying the partition map, make sure the user understands the risks and ask them which partition should be reformated as HFS boot filesystem
echo "IMPORTANT: The next steps will modify your disk's partition map. If you dont know what a partition map is, hitting control-X is a good idea. Modifying the partition map could cause damage to whatever disk you enter as your filesystem. LinuxEvolved is not liable for ANY damage caused by this utility. If you mess up, this script will NOT be able to revert the partitioning once applied. Be at least 101% sure that you enter the correct disk ID before continuing. The disk ID should be in the form /dev/sda, /dev/sdb, /dev/sdc, etc depending on which disk the linux system is installed on. If you enter the wrong disk, it may be damaged, corrupted, or erased (IDK which one, never tried it)."
# Yeah, that stuff is really important, wait for a bit, then give them a 5 page test to see if they read it, if they miss one question stop the setup, JK
sleep 5
## Ask which disk ID is their linux installation
read -p 'Enter the disk ID of your linux installation (Ex: /dev/sda) But dont copy+paste that, be sure to check your disk ID: ' didvar

## Show the partitions on that disk so they will be able to select one (hopefully not their main filesystem)
echo "The following partitions are avaliable on the disk $didvar "
sfdisk -l $didvar
echo "Sadly, right now LinuxEvolved will not create a partition for you, you must specify a partition previously made to format as HFS. If you did not create a partition before running this script, exit this script (control-c normally) and use parted or gparted to make a small partition (10 MB to be safe, though 2 MB should work, but wont leave much room for future updates or custom icons). "
# prtvar stands for partition variable
read -p 'Enter the NUMBER (1, 2, 3, etc) of the partition you would like to be ERASED and used to boot (type N to stop): ' prtvar

if [ $prtvar = "N" ]
then
	# If they said stop then exit with error code 1 (IDK which error code is for user stoping process
	echo "Ok, exiting..."
	exit 1
fi

# Make sure partition is a number
case $prtvar in
	N)
		echo "Ok, exiting..." >&2
		exit 1
		;;
	''|*[!0-9*)
		echo "Please enter a single-digit positive numeber" >&2
		exit 10
		;;
	*)
		echo "Formating ${didvar}${prtvar} as HFS boot partition" >&1
		;;
esac

## Ask for the name of the distro, this will be the name of the HFS partition
# (dstvar stands for distro variable)
read -p 'Distro Name (Debian on Debian, Ubuntu on Ubuntu, etc):' dstvar

## Create the filesystem
mkfs.hfsplus ${didvar}${prtvar} -v ${dstvar}
echo "$didvar$prtvar formated as HFS+ partition, now adding fstab entry"

## Add fstab entry for new filesystem
echo $(blkid -o export -s UUID ${didvar}${prtvar}) /boot/efi auto defaults 0 0 >> /etc/fstab

## Mount the filesystem
echo "Mounting the filesystem"
mkdir /boot/efi
mount /boot/efi

## Modify /usr/sbin/grub-install
echo "Currently, LinuxEvolved can not modify grub install for you, please open anew terminal window, run \'sudo nano /usr/sbin/grub-install\' and remove \n if test \"x\$efi_fs\" = xfat; then :; else \n   echo \" \${efidir} doesn\'t look like an EFI partition.\" 1>&2 \n   efidir= \n fi"
