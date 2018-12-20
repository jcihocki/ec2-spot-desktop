#!/bin/bash

while ! test -d "/var/lib/cloud/instances/$1"; do
  echo "Waiting for cloud init to finish"
  sleep 10
done

# Fire off SQS msg and reboot

nohup bash -c "sleep 15 && reboot" &
