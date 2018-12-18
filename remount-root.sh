if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  exit 0
fi

bash setup.sh

DEVICE=/dev/$(ls -l /dev/disk/by-label|grep permaroot|cut -d / -f 3)
echo "Will use ${DEVICE} as persistent chroot"
umount ${DEVICE}
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


if [ ! -f $NEWMNT/etc/openvpn/server.key ]; then 
	# Generate new openvpn keys and certs, this is a new desktop
	git clone https://github.com/jcihocki/openvpn-server-conf.git
        cd openvpn-server-conf
	bash server-setup.sh

	cd ..
	cp /etc/openvpn/server.conf /etc/openvpn/ca.crt /etc/openvpn/ca.key /etc/openvpn/ta.key /etc/openvpn/crl.pem /etc/openvpn/server.crt /etc/openvpn/server.key /etc/openvpn/dh.key $NEWMNT/etc/openvpn/
	cp client.ovpn $NEWMNT/home/ubuntu/
fi

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
   chmod +x /sbin/init
fi

bash wait-cloud-init-finish.sh $(curl http://169.254.169.254/latest/meta-data/instance-id) &
