[![Build Status](https://www.travis-ci.org/insomniacslk/osf-build.svg?branch=master)](https://www.travis-ci.org/insomniacslk/osf-build)

# OSF Build

Docker files to build an [Open System Firmware](https://www.opencompute.org/projects/open-system-firmware) image based on [coreboot](https://coreboot.org) and [LinuxBoot](https://linuxboot.org).

Just run:
```
docker build -t insomniacslk/osf-build -f Dockerfile
docker run --rm -it insomniacslk/osf-build
```
