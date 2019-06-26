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
    --net osf \
    --ip6 2001:db8:1::10 \
    `# for strace` \
    --cap-add SYS_PTRACE \
    -it insomniacslk/osf-build-dhcp-server \
    $@
