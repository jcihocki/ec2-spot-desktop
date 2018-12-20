#!/bin/bash

while ! test -d "/var/lib/cloud/instances/$1"; do
  echo "Waiting for cloud init to finish"
  sleep 10
done

# Fire off SQS msg and reboot
while : ; do

  echo "Trying to say hello world to the desktop mgmt infra..."  > /dev/stderr
  STATUSCODE=$(curl --silent --output /dev/null --write-out "%{http_code}" -X POST https://dev.remotewarriors.work/running-instances)
  if [ $STATUSCODE -eq 204 ]; then break; fi
  echo "Failed, http status is $STATUSCODE" > /dev/stderr
  sleep 15
done


nohup bash -c "sleep 2 && reboot" &
