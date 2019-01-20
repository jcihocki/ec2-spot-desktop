#!/bin/bash

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

while ! test -d "/var/lib/cloud/instances/$INSTANCE_ID"; do
  echo "Waiting for cloud init to finish"
  sleep 10
done


