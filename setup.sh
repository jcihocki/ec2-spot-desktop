#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -yq jq
apt-get -yq install default-jre
apt-get install -yq python-pip python-setuptools
apt-get install -yq aws-api-tools
pip install awscli


