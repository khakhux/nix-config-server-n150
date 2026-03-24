lsblk

NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0   1.8T  0 disk 
├─sda1        8:1    0   1.8T  0 part /mnt/MyPassport
└─sda2        8:2    0   9.8G  0 part 

# Install dislocker temporarily (currently depends on libraries marked as insecure)
NIXPKGS_ALLOW_INSECURE=1 nix-shell -p dislocker --impure

# Then mount as before
sudo mkdir -p /mnt/bitlocker-raw /mnt/bitlocker
sudo dislocker -V /dev/sda2 -upassword -- /mnt/bitlocker-raw
sudo mount -o loop /mnt/bitlocker-raw/dislocker-file /mnt/bitlocker

sudo umount /mnt/bitlocker
sudo umount /mnt/bitlocker-raw
