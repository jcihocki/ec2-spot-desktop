#!/bin/bash

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

while ! test -d "/var/lib/cloud/instances/$INSTANCE_ID"; do
  echo "Waiting for cloud init to finish"
  sleep 10
done

PASSWD=$(/usr/bin/node generate-passwd.sh)
echo "$INSTANCE_ID, $ZONE, $REGION, $PASSWD"

aws ec2 create-tags --resources $INSTANCE_ID --tags "Key=Password,Value=$PASSWD" --region $REGION
yes $PASSWD | passwd ubuntu
cp /etc/shadow /permaroot/etc/shadow
history -c

