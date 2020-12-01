[![Build Status](https://www.travis-ci.org/insomniacslk/osf-build.svg?branch=master)](https://www.travis-ci.org/insomniacslk/osf-build)

# OSF Build

Docker files to build an [Open System Firmware](https://www.opencompute.org/projects/open-system-firmware) image based on [coreboot](https://coreboot.org) and [LinuxBoot](https://linuxboot.org).

Just run either `docker` or `podman`:
```
podman build -t insomniacslk/osf-build -f Dockerfile .
podman run --rm -it insomniacslk/osf-build
```

You can copy the output files with a command like this:
```
podman run --rm -it --mount type=bind,source="${PWD}"/output,target=/home/circleci/output insomniacslk/osf-build sudo cp coreboot.rom disk.img output/
```

This will create an `output` directory on the host system, containing
`coreboot.rom` and `disk.img`.


This is mostly equivalent to the process described in the chapter
[LinuxBoot using coreboot, u-root and systemboot](https://github.com/linuxboot/book/blob/master/coreboot.u-root.systemboot/README.md)
of the [LinuxBoot book](https://github.com/linuxboot/book).
