#!/bin/bash

while ! test -d "/var/lib/cloud/instances/$1"; do

  sleep 10
  echo "Still waiting"
done

# Fire off SQS msg and reboot

reboot
