ROOT_LABEL="$(findmnt / -o label -n)"
if [ $ROOT_LABEL == "permaroot" ]; then
	cp /old-root/etc/hostname /etc/hostname
	if [ ! -f $NEWMNT/etc/openvpn/server.key ]; then

		echo "Doing one time OpenVPN setup..."

		# Generate new openvpn keys and certs, this is a new desktop
		git clone https://github.com/jcihocki/openvpn-server-conf.git
		cd openvpn-server-conf
		bash server-setup.sh

		cp /root/client.ovpn /home/ubuntu/
		cd ..
	fi

	bash wait-cloud-init-finish.sh $(curl http://169.254.169.254/latest/meta-data/instance-id) $(cat /root/client.ovpn)
	exit 0
else
	echo "Root label is $ROOT_LABEL which means we need to set up and reboot for chroot"
fi

DEVICE=/dev/$(ls -l /dev/disk/by-label|grep permaroot|cut -d / -f 3)
DEVICE_UUID=$(blkid -o value -s UUID $DEVICE)
INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type)
echo "Will use ${DEVICE} as persistent chroot"
umount ${DEVICE}
NEWMNT=/permaroot
OLDMNT=old-root
e2fsck $DEVICE -f -y
mkdir -p $NEWMNT


mount $DEVICE $NEWMNT
cp /etc/hostname $NEWMNT/etc/hostname
mkdir -p $NEWMNT/$OLDMNT
umount $DEVICE

#
# point of no return...
# modify /sbin/init on the ephemeral volume to chain-load from the persistent EBS volume, and then reboot.
#
mv /sbin/init /sbin/init.backup

cat >/sbin/init <<EOF
#!/bin/sh
mount UUID=$DEVICE_UUID /permaroot
cd $NEWMNT

pivot_root . ./$OLDMNT

for dir in /dev /proc /sys /run; do
   echo "JOHNNY Moving mounted file system ${OLDMNT}\${dir} to \$dir." > /dev/kmsg
   mount --move ./${OLDMNT}\${dir} \${dir}
done

exec chroot . /sbin/init

EOF

chmod +x /sbin/init

bash wait-cloud-init-finish.sh $(curl http://169.254.169.254/latest/meta-data/instance-id) && nohup bash -c "sleep 2 && reboot" &
