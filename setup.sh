#!/bin/sh

apt-get update
apt-get install -y jq
apt-get -y install default-jre
apt-get install -y python-pip python-setuptools
apt-get install -y aws-api-tools
pip install awscli


