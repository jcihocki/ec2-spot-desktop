#!/bin/bash

cd /etc/cloud
git clone -b prod --single-branch https://github.com/jcihocki/ec2-spot-desktop.git
cd ec2-spot-desktop
bash setup.sh
bash remount-root.sh
