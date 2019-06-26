# {docker build -t insomniacslk/osf-build -f Dockerfile .}

# based on github.com/systemboot/systemboot/.travis/docker/*

FROM uroottest/test-image-amd64:v3.2.4

# Install dependencies
RUN sudo apt-get update &&                          \
	sudo apt-get install -y --no-install-recommends \
		`# libraries used by vpd`                   \
		uuid-dev                                    \
		`# tools for creating bootable disk images` \
		gdisk \
		e2fsprogs \
		qemu-utils qemu-system-common \
		patch \
		strace \
		kmod \
		tar \
		iptables isc-dhcp-client \
		bridge-utils uml-utilities \
		tcpdump tshark \
		&& \
	sudo rm -rf /var/lib/apt/lists/*

# make sure u-root's tools don't override coreutils's ones
ENV PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/go/bin:/usr/local/go/bin"

# Get u-root
RUN go get github.com/u-root/u-root/...
RUN go get github.com/systemboot/systemboot/...
RUN sudo chmod -R a+w /go/src

# build the initramfs with u-root and systemboot
RUN set -x; \
	cd /go/src/github.com/systemboot/systemboot && \
	go get -v ./...  && \
	u-root -o ~/initramfs.linux_amd64.cpio -build=bb core uinit localboot netboot cmds/fixmynetboot && \
	xz --check=crc32 --lzma2=dict=512KiB ~/initramfs.linux_amd64.cpio

# Get Linux kernel
#
# Config based on the coreboot chapter of the LinuxBoot Book,
# https://github.com/linuxboot/book .
COPY config/linux-config .

RUN set -x; \
	git clone -q --depth 1 -b v4.19 https://github.com/torvalds/linux.git && \
	mv linux-config linux/.config && \
	(cd linux/ && make oldconfig && make ) && \
	cp linux/arch/x86/boot/bzImage bzImage && \
	rm -r linux/

# Config files from https://github.com/linuxboot/demo/blob/master/20190203-FOSDEM-barberio-hendricks/config/
COPY config/coreboot-config .
COPY config/qemu.fmd .

# required to cherry-pick
RUN set -x; \
	git config --global user.email "osf-build@example.org" && \
	git config --global user.name "OSF Build"

# install vpd, required later to write boot entries
RUN set -x; \
	git clone https://chromium.googlesource.com/chromiumos/platform/vpd && \
	( \
		cd vpd && \
		make ) && \
	cp vpd/vpd_s ~/vpd_s

RUN set -x; \
	git clone https://review.coreboot.org/coreboot.git && \
	mv coreboot-config coreboot/.config && \
	mv qemu.fmd coreboot/ && \
	( \
		cd coreboot && \
		`# fetch qemu-vpd patch` \
		git fetch https://review.coreboot.org/coreboot refs/changes/87/32087/6 && \
		git cherry-pick FETCH_HEAD && \
		BUILD_LANGUAGES=c CPUS=$(nproc) make crossgcc-i386 && \
		make oldconfig && \
		make) && \
	`# create RO_VPD partition with boot entries` \
	~/vpd_s -f coreboot/build/coreboot.rom -i RO_VPD -O && \
	~/vpd_s -f coreboot/build/coreboot.rom -i RO_VPD -s 'Boot0000={"type":"netboot","method":"dhcpv6", "debug_on_failure": true}' && \
	~/vpd_s -f coreboot/build/coreboot.rom -i RO_VPD -s 'Boot0001={"type":"localboot","method":"grub"}' && \
	cp coreboot/build/coreboot.rom . && \
	rm -r coreboot/

# Create a bootable disk image to test localboot; the init just prints a banner
COPY uinit/* /go/src/uinit/
RUN sudo chmod -R a+w /go/src/uinit

RUN set -x; \
	mkdir rootfs && \
	cp bzImage rootfs/ && \
	u-root -build=bb -o rootfs/ramfs.cpio \
		core \
		uinit  && \
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
	mv disk.qcow2 disk.img

COPY config/bridge.conf /etc/qemu/bridge.conf
RUN go get github.com/insomniacslk/exdhcp/dhclient/...

 CMD set -x; \
	sudo ip link add link eth0 name macvtap0 type macvtap mode bridge && \
	sudo ip link set macvtap0 up && \
	sudo bash -c './qemu-system-x86_64 \
		-M q35 \
		-L pc-bios/ `# for vga option rom` \
		-bios coreboot.rom \
		-m 1024 \
		-nographic \
		-object 'rng-random,filename=/dev/urandom,id=rng0' \
		-device 'virtio-rng-pci,rng=rng0' \
		-net nic,model=e1000,macaddr=$(cat /sys/class/net/macvtap0/address) \
		-net tap,fd=3 3<>/dev/tap$(cat /sys/class/net/macvtap0/ifindex) \
		-hda disk.img'

#CMD set -x; \
#	sudo brctl addbr br0 && \
#	sudo brctl addif br0 eth0 && \
#	sudo iptables -I FORWARD -m physdev --physdev-is-bridge -j ACCEPT && \
#	sudo bash -c './qemu-system-x86_64 \
#	-M q35 \
#	-L pc-bios/ `# for vga option rom` \
#	-bios coreboot.rom \
#	-m 1024 \
#	-nographic \
#	-object 'rng-random,filename=/dev/urandom,id=rng0' \
#	-device 'virtio-rng-pci,rng=rng0' \
#	`# -net nic,model=virtio-net-pci -net bridge,br=br0` \
#	-hda disk.img'
