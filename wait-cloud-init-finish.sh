#!/bin/bash

while ! test -d "/var/lib/cloud/instances/$1"; do
  echo "Waiting for cloud init to finish"
  sleep 10
done

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

# Fire off SQS msg and reboot
while : ; do

  echo "Trying to say hello world to the desktop mgmt infra..."  > /dev/stderr
  STATUSCODE=$(curl --silent --output /dev/null --write-out "%{http_code}" -d region="${EC2_REGION}" -d ovpn="$(cat $2)" -X POST https://dev.remotewarriors.work/running-instances)
  if [ $STATUSCODE -eq 204 ]; then break; fi
  echo "Failed, http status is $STATUSCODE" > /dev/stderr
  sleep 15
done
