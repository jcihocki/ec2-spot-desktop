ROOT_LABEL="$(findmnt / -o label -n)"
if [ $ROOT_LABEL == "permaroot" ]; then 
	exit 0 
else 
	echo "Root label is $ROOT_LABEL which means we need to set up and reboot for chroot" 
fi

apt update
apt install -y nodejs
apt-get install -y python-pip python-setuptools
apt-get install -y aws-api-tools
pip install awscli


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
cp /dev/null /permaroot/home/ubuntu/.ssh/authorized_keys

ZONE=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${ZONE::-1}
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
PASSWD=$(/usr/bin/node generate-passwd.sh)

aws ec2 create-tags --resources $INSTANCE_ID --tags "Key=Password,Value=$PASSWD" --region $REGION
yes $PASSWD | passwd ubuntu
cp /etc/shadow /permaroot/etc/shadow
history -c

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

bash wait-cloud-init-finish.sh &&  reboot  &
