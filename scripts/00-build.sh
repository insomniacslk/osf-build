#!/bin/bash
set -eux

if [ $UID -ne 0 ]
then
    sudo $0 $@
    exit $?
fi

docker build -t insomniacslk/osf-build -f Dockerfile .
docker build -t insomniacslk/osf-build-dhcp-server -f Dockerfile.dhcp-server .
