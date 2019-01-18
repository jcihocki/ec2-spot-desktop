ROOT_LABEL="$(findmnt / -o label -n)"
if [ $ROOT_LABEL == "permaroot" ]; then 
	exit 0 
else 
	echo "Root label is $ROOT_LABEL which means we need to set up and reboot for chroot" 
fi

DEVICE=/dev/$(ls -l /dev/disk/by-label|grep permaroot|cut -d / -f 3)
INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type)
echo "Will use ${DEVICE} as persistent chroot"
umount ${DEVICE}
NEWMNT=/permaroot
OLDMNT=old-root
e2fsck $DEVICE -f -y
# This has already happened by now
# e2label $DEVICE permaroot
#tune2fs $DEVICE -U `uuidgen`
mkdir -p $NEWMNT


mount $DEVICE $NEWMNT
# if [ ! -f $NEWMNT/etc/openvpn/server.key ]; then
#   # Generate new openvpn keys and certs, this is a new desktop
#   git clone https://github.com/jcihocki/openvpn-server-conf.git
#         cd openvpn-server-conf
#   bash server-setup.sh
#
#   cd ..
#   cp /etc/openvpn/server.conf /etc/openvpn/ca.crt /etc/openvpn/ca.key /etc/openvpn/ta.key /etc/openvpn/crl.pem /etc/openvpn/server.crt /etc/openvpn/server.key /etc/openvpn/dh.key $NEWMNT/etc/openvpn/
#   cp client.ovpn $NEWMNT/home/ubuntu/
# fi
cp /etc/hostname $NEWMNT/etc/hostname
mkdir -p $NEWMNT/$OLDMNT
umount $DEVICE

#
# point of no return... 
# modify /sbin/init on the ephemeral volume to chain-load from the persistent EBS volume, and then reboot.
#
mv /sbin/init /sbin/init.backup
if [[ $INSTANCE_TYPE == m5* || $INSTANCE_TYPE == r5* ]]; then
  
  # Jan 18 20:38:45 ip-10-0-5-152 kernel: [    6.697871] JOHNNY Path is /sbin:/usr/sbin:/bin:/usr/bin
  # Jan 18 20:38:45 ip-10-0-5-152 kernel: [    6.707010] JOHNNY Mount: /bin/mount Unshare: /usr/bin/unshare chroot: /usr/sbin/chroot pivot_root: /sbin/pivot_root
  # Jan 18 20:38:45 ip-10-0-5-152 kernel: [    6.711831] JOHNNY had to bail out of chroot for some reason. Check kernel logs
  
   cat >/sbin/init <<EOF
#!/bin/sh
mount $DEVICE $NEWMNT 
echo "JOHNNY Path is \$PATH" > /dev/kmsg
echo "JOHNNY Mount: \$(which mount) Unshare: \$(which unshare) chroot: \$(which chroot) pivot_root: \$(which pivot_root)" > /dev/kmsg
cd $NEWMNT
echo "JOHNNY mount point $NEWMNT: \$(ls)" > /dev/kmsg

unshare -m
echo "Unshare exit status: \$?" > /dev/kmsg
pivot_root . ./$OLDMNT 2> /tmp/pivot-root-error.txt


PIVOT_STATUS=\$?
echo "JOHNNY Pivot root status: \$PIVOT_STATUS Mount status: \$(mount)" > /dev/kmsg
cat /tmp/pivot-root-error.txt > /dev/kmsg

if [ -f /old-root/sbin/init.backup ]; then
  # pivot root worked.
  echo "JOHNNY pivot root worked" > /dev/kmsg  
  
  # Undo
  pivot_root /old-root /old-root/permaroot
  
  echo "JOHNNY pivot root back exited with \$?" > /dev/kmsg  
else 
  echo "JOHNNY pivot root didn't work" > /dev/kmsg  
fi

exec /sbin/init.backup

if [ "\$PIVOT_STATUS" = "0" ]; then 
  for dir in /dev /proc /sys /run; do
     echo "JOHNNY Moving mounted file system ${OLDMNT}\${dir} to \$dir." > /dev/kmsg
     mount --move ./${OLDMNT}\${dir} \${dir}
  done

  exec chroot . /sbin/init
fi

echo "JOHNNY had to bail out of chroot for some reason. Check kernel logs" > /dev/kmsg
exec /sbin/init.backup
EOF
  
else
  


   cat >/sbin/init <<EOF
#!/bin/sh
mount $DEVICE $NEWMNT

[ ! -d $NEWMNT/$OLDMNT ] && mkdir -p $NEWMNT/$OLDMNT

   
# TODO add any ssh pubkeys here   
   
cd $NEWMNT
pivot_root . ./$OLDMNT
   
for dir in /dev /proc /sys /run; do
   echo "Moving mounted file system ${OLDMNT}\${dir} to \$dir."
   mount --move ./${OLDMNT}\${dir} \${dir}
done
exec chroot . /sbin/init
EOF
fi
chmod +x /sbin/init

bash wait-cloud-init-finish.sh $(curl http://169.254.169.254/latest/meta-data/instance-id) &
