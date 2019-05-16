# {docker build -t insomniacslk/osf-build -f Dockerfile .}

# based on github.com/systemboot/systemboot/.travis/docker/*

FROM uroottest/test-image-amd64:v3.2.4

# Install dependencies
RUN sudo apt-get update &&                          \
	sudo apt-get install -y --no-install-recommends \
		`# tools for creating bootable disk images` \
		gdisk \
		e2fsprogs \
		qemu-utils \
		patch \
		tar \
		&& \
	sudo rm -rf /var/lib/apt/lists/*

# make sure u-root's tools don't override coreutils's ones
ENV PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/go/bin:/usr/local/go/bin"

# Get u-root
RUN go get github.com/u-root/u-root/...
RUN go get github.com/systemboot/systemboot/...

# build the initramfs with u-root and systemboot
RUN set -x; \
	sudo chmod -R a+w /go/src && \
	cd /go/src/github.com/systemboot/systemboot && \
	go get -v ./...  && \
	u-root -o ~/initramfs.linux_amd64.cpio -build=bb core uinit localboot netboot && \
	xz --check=crc32 --lzma2=dict=512KiB ~/initramfs.linux_amd64.cpio

# Get Linux kernel
#
# Config taken from:
#   https://raw.githubusercontent.com/linuxboot/demo/master/20190203-FOSDEM-barberio-hendricks/config/linux-config
COPY linux-config .

RUN set -x; \
	git clone -q --depth 1 -b v4.19 https://github.com/torvalds/linux.git && \
	mv linux-config linux/.config && \
	(cd linux/ && make oldconfig && make ) && \
	cp linux/arch/x86/boot/bzImage bzImage && \
	rm -r linux/

# Config files from https://github.com/linuxboot/demo/blob/master/20190203-FOSDEM-barberio-hendricks/config/
COPY coreboot-config .
COPY qemu.fmd .

# required to cherry-pick
RUN set -x; \
	git config --global user.email "osf-build@example.org" && \
	git config --global user.name "OSF Build"

RUN set -x; \
	git clone -b 4.9 https://review.coreboot.org/coreboot.git && \
	mv coreboot-config coreboot/.config && \
	mv qemu.fmd coreboot/ && \
	( \
		cd coreboot && \
		BUILD_LANGUAGES=c CPUS=$(nproc) make crossgcc-i386 && \
		make oldconfig && \
		make) && \
	cp coreboot/build/coreboot.rom . && \
	rm -r coreboot/

# Create a bootable disk image to test localboot; the init there simply shuts down.
RUN set -x; \
	mkdir rootfs && \
	cp bzImage rootfs/ && \
	u-root -build=bb -o rootfs/ramfs.cpio -initcmd shutdown  && \
	xz --check=crc32 --lzma2=dict=512KiB rootfs/ramfs.cpio && \
	{ \
		echo menuentry; \
		echo linux bzImage; \
		echo initrd ramfs.cpio.xz; \
	} > rootfs/grub2.cfg && \
	du -a rootfs/ && \
	qemu-img create -f raw disk.img 20m && \
	sgdisk --clear --new 1::-0 --typecode=1:8300 --change-name=1:'Linux root filesystem' \
		disk.img && \
	mkfs.ext2 -F -E 'offset=1048576' -d rootfs/ disk.img 18m && \
	gdisk -l disk.img && \
	qemu-img convert -f raw -O qcow2 disk.img disk.qcow2 && \
	mv disk.qcow2 disk.img && \
	rm -r rootfs/

CMD ./qemu-system-x86_64 \
	-M q35 \
	-L pc-bios/ `# for vga option rom` \
	-bios coreboot.rom \
	-m 1024 \
	-nographic \
	-object 'rng-random,filename=/dev/urandom,id=rng0' \
	-device 'virtio-rng-pci,rng=rng0' \
	-hda disk.img
