#!/bin/sh

. /share/common.sh

TGT=$1
DRIVE=$2
ROOT_SIZE=$3
SWAP_SIZE=$4
DRIVEPP=$DRIVE
[ $DRIVEPP -eq /dev/nvme0n1 ] && DRIVEPP=/dev/nvme0n1p

create_partitions() {
    for i in $(fdisk -l | grep -o ^/dev/sda[^\ ]* | sed s_/dev/sda__)
    do
        POISON="${POISON}${i}"
    done
    UNUSED_PARTS=$(echo -e "1\n2\n3\n4" | grep "[^${POISON}]")
    UNUSED_PARTS_NUM=$(echo "${UNUSED_PARTS}" | wc -l)
    if [ "${UNUSED_PARTS_NUM}" == "0" ]
    then
        echo "Not enough free partitions: manual invervention needed" 1>&2
        exit 1
    elif [ "${UNUSED_PARTS_NUM}" == "1" ]
    then
        fdisk $DRIVE > /dev/null << EOF
n
e


n

+2048M
n

+${ROOT_SIZE}K
n

+${SWAP_SIZE}K
n


t
7
82
w
EOF
    else
        PARTITION_CHOICE=$(echo "${UNUSED_PARTS}" | head -n 1)
        fdisk $DRIVE > /dev/null << EOF
n
e
${PARTITION_CHOICE}


n
l

+2048M
n
l

+${ROOT_SIZE}K
n
l

+${SWAP_SIZE}K
n
l


t
7
82
w
EOF
    fi
    mkfs.ext4 -F -L pixie_data ${DRIVEPP}5 > /dev/null || error "Error creating pixie_data"
    mkfs.ext4 -F -L pixie_home ${DRIVEPP}8 > /dev/null || error "Error creating pixie_home"
    mkswap -L pixie_swap ${DRIVEPP}7 > /dev/null || error "Error creating pixie_swap"
    mount ${DRIVEPP}5 /mnt || error "Error mounting pixie_data"
    echo $PIXIE_MAGIC > /mnt/pixie_magic || error "Error creating the magic file"
    umount /mnt || error "Error umounting pixie_data"
}

wipe_all() {
    fdisk $DRIVE > /dev/null << EOF
o
w
EOF
    create_partitions
}

wipe_linux() {
    LINUX_PARTS="$(fdisk -l $DRIVE | tr \* \  | grep ^$DRIVEPP | sed s/\ \ */\ /g | cut -d ' ' -f 1,5 | grep -e 83$ -e 82$ | cut -f 1 -d \  | sed s_${DRIVEPP}__)"
    EXTENDED_PARTS="$(fdisk -l $DRIVE | tr \* \  | grep ^$DRIVEPP | sed s/\ \ */\ /g | cut -d ' ' -f 1,5 | grep 5$ | cut -f 1 -d \  | sed s_${DRIVEPP}__)"
    for i in $LINUX_PARTS $EXTENDED_PARTS
    do
        fdisk $DRIVE > /dev/null << EOF
d
$i
w
EOF
    done
    create_partitions
}

wipe_pixie() {
    #TODO: make something smarter here.
    wipe_linux
}

case $TGT in
    pixie) wipe_pixie;;
    linux) wipe_linux;;
    all) wipe_all;;
    *) echo "Invalid wipe type" 1>&2; exit 1;;
esac
