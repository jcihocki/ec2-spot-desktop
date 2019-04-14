#!/bin/bash

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"


# Post event back to server.
while : ; do

  echo "Trying to say hello world to the desktop mgmt infra..."  > /dev/stderr
  STATUSCODE=$(curl --silent --output /dev/null --write-out "%{http_code}" -d region="${EC2_REGION}" -X POST https://d1842415.ngrok.io/running-instances)
  if [ $STATUSCODE -eq 204 ]; then break; fi
  echo "Failed, http status is $STATUSCODE" > /dev/stderr
  sleep 15
done


