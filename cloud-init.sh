#!/bin/bash

cd /root
git clone https://github.com/jcihocki/ec2-spot-desktop.git
cd ec2-spot-desktop
bash setup.sh
bash remount-root.sh
