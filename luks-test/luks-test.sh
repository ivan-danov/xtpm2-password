#!/bin/bash

set -eu

# Luks test

imageName=test.img
imageAlias=test_image
oldPassword=test
newPassword=test2

echo -n $oldPassword > initPassword.key
echo -n $newPassword > newPassword.key

function atexit {
	sudo cryptsetup close $imageAlias || true
	sudo umount mnt || true
	rmdir mnt 2>/dev/null || true
	echo "clean files"
# 	rm -f $imageName
# 	rm -f initPassword.key
# 	rm -f newPassword.key
# 	sudo rm -f luks-header1.bin
# 	sudo rm -f luks-header2.bin
# 	sudo rm -f master_key.txt
# 	rm -f master_key.bin
	echo "done"
}
trap atexit EXIT


echo "create disk"
dd if=/dev/zero of=$imageName bs=1024 count=4096

echo "encrypt disk"
cryptsetup --batch-mode luksFormat --key-file=initPassword.key --type=luks1 $imageName

echo "open disk"
sudo cryptsetup open --key-file=initPassword.key  $imageName $imageAlias
echo "show in mapper"
ls -laF /dev/mapper/
echo "dump masterkey"
echo -n $oldPassword|cryptsetup --batch-mode  luksDump --dump-master-key test.img

echo "create filesystem"
sudo mkfs.ext4 -L boot /dev/mapper/$imageAlias

echo "mount"
mkdir -p mnt && sudo mount /dev/mapper/$imageAlias mnt

echo "show key"
sudo dmsetup table --showkey /dev/mapper/$imageAlias > master_key.txt
cat master_key.txt|cut -d ' ' -f 5|xxd -r -p - master_key.bin

echo "do something"

echo "umount"
sudo umount mnt && rmdir mnt

echo "close disk"
sudo cryptsetup close $imageAlias
echo "show in mapper"
ls -laF /dev/mapper/

echo "dump"
cryptsetup luksDump $imageName

echo "test old password"
cryptsetup open --verbose --test-passphrase --key-file initPassword.key $imageName || true
echo "test new password"
cryptsetup open --verbose --test-passphrase --key-file newPassword.key $imageName || true

echo "change password"
# sudo cryptsetup luksChangeKey $imageName --key-file initPassword.key newPassword.key
cat initPassword.key | sudo cryptsetup luksChangeKey test.img newPassword.key

echo "dump header 2"
cryptsetup luksHeaderBackup $imageName --header-backup-file luks-header2.bin

echo "dump"
cryptsetup luksDump $imageName

echo "test old password"
cryptsetup open --verbose --test-passphrase --key-file initPassword.key $imageName || true
echo "test new password"
cryptsetup open --verbose --test-passphrase --key-file newPassword.key $imageName || true

