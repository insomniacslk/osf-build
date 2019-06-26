#!/bin/bash
set -eux

if [ $UID -ne 0 ]
then
    sudo $0 $@
    exit $?
fi

# no multicast :(
# https://github.com/docker/libnetwork/issues/552

docker run \
    --privileged \
    --net osf \
    --cap-add NET_ADMIN \
    -it insomniacslk/osf-build \
    $@
