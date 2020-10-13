#!/bin/bash

SECONDS=0

if [ "$1" = "--help" ]; then
  echo "Help:"
  echo "  bash flash.sh [device] [current username] [raspberry-pi username] [image]"
  echo "Example:"
  echo "  sudo bash flash.sh /dev/sdc slyke pi 2020-02-13-raspbian-buster-lite.img"
  echo "or"
  echo "  sudo bash flash.sh"
  exit 0
fi

lsblk | grep "sd"

if [ -z ${1+x} ]; then
  echo ""
  echo "Enter partition or drive to use."
  read DRIVE;
else
  DRIVE=$1
fi

if [ -z ${2+x} ]; then
  USER=$(whoami)
else
  USER=$2
fi

PIUSR="pi"
if [ -z ${3+x} ]; then
  echo ""
  read -p "Enter User of raspberry pi, or press enter to use '$PIUSR': " PIUSRIN
  PIUSR=${PIUSRIN:-$PIUSR}
else
  PIUSR=$3
fi

FLASH=$(ls -1 | grep "raspbian" | head -1)

if [ -z ${4+x} ]; then
  echo "Images available:"
  ls -1 | grep "raspbian"
  echo ""
  read -p "Enter new file name, or press enter to use '$FLASH': " OPTFLASH
  OPTFLASH=${OPTFLASH:-$FLASH}
  FLASH=$OPTFLASH
else
  FLASH=$4
fi

BOOTDIR=/media/$USER/boot
ROOTFSDIR=/media/$USER/rootfs
LCLRC=$ROOTFSDIR/etc/rc.local

echo ""
echo ""
echo "Current User:                $USER"
echo "Pi User:                     $PIUSR"
echo "Adding SSH enable file to:   $BOOTDIR"
echo "Adding WIFI config file to:  $BOOTDIR"
echo "Adding injection script to:  $LCLRC"
echo "Output Devicve:              $DRIVE"
echo "Input File:                  $FLASH"

echo ""
echo ""

if [ "$5" = "--dry" ]; then
  echo "Skipping image writing..."
  echo ""
else
  echo "Starting Flash..."
  sleep 5

  echo ""
  echo "This may take 10 minutes to 1 hour to complete."
  echo ""

  dd bs=1M if=$FLASH of=$DRIVE status=progress
  sync
fi

DDRES=$?

if [ $DDRES -eq 0 ];then
  sync
  echo "Remounting drive..."
  sleep 5
  sync
  eject $DRIVE
  sleep 20
  eject -t $DRIVE
  sync
  sleep 10
  echo "Writing configs"
  touch $BOOTDIR/ssh > /dev/null
  while [ ! -f $BOOTDIR/ssh ]
  do
    sync
    printf "."
    sleep 1
    touch $BOOTDIR/ssh > /dev/null
  done
  touch $BOOTDIR/setup.txt
  cp ./wpa_supplicant.conf $BOOTDIR

  sleep 1
  echo "Writing init script"
  while [ ! -f $LCLRC ]
  do
    printf "."
    sleep 1
  done

  sed -i -e "$(grep -n 'exit 0' $LCLRC | cut -f1 -d: | tail -n 1)d" $LCLRC
  echo "" >> $LCLRC
  echo "touch /tmp/rc.local_out.txt" >> $LCLRC
  echo "whoami > /tmp/rc.local_out.txt" >> $LCLRC
  echo "if [ -e /boot/setup.txt ]; then" >> $LCLRC
  echo "  wget -O - https://raw.githubusercontent.com/Slyke/Deploy/master/init_root.sh | bash >> /tmp/rc.local_out.txt" >> $LCLRC
  echo "sleep 5" >> $LCLRC
  echo "  wget -O - https://raw.githubusercontent.com/Slyke/Deploy/master/init_user.sh | su - $PIUSR -c bash >> /tmp/rc.local_out.txt" >> $LCLRC
  echo "  rm /boot/setup.txt" >> $LCLRC
  echo "else" >> $LCLRC
  echo "  echo \"init.sh not run due to no /boot/setup.txt file\" >> /tmp/rc.local_out.txt" >> $LCLRC
  echo "fi" >> $LCLRC
  echo "" >> $LCLRC
  echo "exit 0" >> $LCLRC
  sleep 1
  DURATION=$SECONDS
  echo "Finished!"
  echo "Run time: $(($DURATION / 60)) minutes and $(($DURATION % 60)) seconds."
  exit 0
else
  echo "Something went wrong. You may have to run as root."
  DURATION=$SECONDS
  echo "Run time: $(($DURATION / 60)) minutes and $(($DURATION % 60)) seconds."
  exit 1
fi

sync
