#!/bin/bash
set -exu
if [ $UID -ne 0 ]
then
    sudo $0 $@
    exit $?
fi

sysctl net.bridge.bridge-nf-call-arptables=1
sysctl net.bridge.bridge-nf-call-ip6tables=1
sysctl net.bridge.bridge-nf-call-iptables=1

docker network rm osf
docker network create --driver bridge --ipv6 --subnet=2001:db8:1::/64 osf
docker network inspect osf
