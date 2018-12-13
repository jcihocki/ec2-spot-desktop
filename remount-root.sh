DEVICE=/dev/$(ls -l /dev/disk/by-label|grep permaroot|cut -d / -f 3)
echo "Will use ${DEVICE} as persistent chroot"
NEWMNT=/permaroot
OLDMNT=old-root
e2fsck $DEVICE -f -y
# This has already happened by now
# e2label $DEVICE permaroot
tune2fs $DEVICE -U `uuidgen`
mkdir -p $NEWMNT

#
# point of no return... 
# modify /sbin/init on the ephemeral volume to chain-load from the persistent EBS volume, and then reboot.
#
if [ -L "/sbin/init" ]
then
   mv /sbin/init /sbin/init.backup
   cat >/sbin/init <<EOF
#!/bin/sh
mount $DEVICE $NEWMNT
[ ! -d $NEWMNT/$OLDMNT ] && mkdir -p $NEWMNT/$OLDMNT
   
cd $NEWMNT
pivot_root . ./$OLDMNT
   
for dir in /dev /proc /sys /run; do
   echo "Moving mounted file system ${OLDMNT}\${dir} to \$dir."
   mount --move ./${OLDMNT}\${dir} \${dir}
done
exec chroot . /sbin/init
EOF
   chmod +x /sbin/init
   shutdown -r now
fi
