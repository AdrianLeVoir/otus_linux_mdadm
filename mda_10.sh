#!/bin/bash

set -e

RAID_DEV="/dev/md0"
DISKS=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
MOUNT_BASE="/raid/part"

echo "чистка старых метаданных"
for disk in "${DISKS[@]}"; do
    mdadm --zero-superblock --force "$disk" 2>/dev/null || true
    wipefs -a "$disk" 2>/dev/null || true
done

echo "Создание RAID 10"
mdadm --create --verbose "$RAID_DEV" \
    --level=10 \
    --raid-devices=4 \
    "${DISKS[@]}"

echo "Ожидание инициализации"
sleep 5

echo "Проверка состояния"
cat /proc/mdstat

echo "Сохранение конфигурации"
mdadm --detail --scan | tee -a /etc/mdadm.conf

echo "Разметка GPT и создание разделов"
parted -s "$RAID_DEV" mklabel gpt
for i in {1..5}; do
    start=$(( (i-1) * 20 ))
    end=$(( i * 20 ))
    parted -s "$RAID_DEV" mkpart primary ext4 "${start}%" "${end}%"
done

echo "Создание файловых систем"
for i in {1..5}; do
    mkfs.ext4 "${RAID_DEV}p$i"
done

echo "Монтирование"
mkdir -p ${MOUNT_BASE}{1..5}
for i in {1..5}; do
    mount "${RAID_DEV}p$i" "${MOUNT_BASE}$i"
    echo "${RAID_DEV}p$i  ${MOUNT_BASE}$i  ext4  defaults,nofail  0  2" >> /etc/fstab
done

echo "Готово"
df -h | grep raid
