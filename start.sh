#!/bin/sh

# Source: https://github.com/moby/hyperkit/blob/master/hyperkitrun.sh

HYPERKIT="hyperkit"

# Linux
KERNEL="vmlinuz"
INITRD="initrd"
CMDLINE="earlyprintk=serial console=ttyS0 rancher.autologin=ttyS0 rancher.state.dev=LABEL=RANCHER_STATE rancher.state.autoformat=[/dev/vda] rancher.state.formatzero"

# FreeBSD
#USERBOOT="test/userboot.so"
#BOOTVOLUME="/somepath/somefile.{img | iso}"
#KERNELENV=""

if [ ! -e hdd.img ]; then
  qemu-img create -f qcow2 -o lazy_refcounts=on,preallocation=metadata hdd.img 16G
fi

MEM="-m 2G"
SMP="-c 2"
# eth0, using vmnet
#NET="-s 2:0,virtio-net" # -s 2:1,virtio-net,vmnet1"
# eth0, use a tap device instead of vmnet. Requires: brew cask install tuntap, and creating bridge interface and ifconfig bridge0 addm tap0
NET="-s 2:0,virtio-tap,tap0"
#IMG_CD="-s 3,ahci-cd,/somepath/somefile.iso"
# /dev/vda
IMG_HDD="-s 4,virtio-blk,file:///Users/ballen/Desktop/Labs/hyperkit_demo/hdd.img,format=qcow"
PCI_DEV="-s 0:0,hostbridge -s 31,lpc"
RND="-s 7,virtio-rnd"
# Stdin/out console
#LPC_DEV="-l com1,stdio"
# Automatically pick a /dev/ttysNN device to use, and symlink it to path $PWD/tty, plus log output to Apple System Logger (asl). Open console via "screen $PWD/tty"
LPC_DEV="-l com1,autopty=$PWD/tty,asl"
ACPI="-A"
UUID="-U deadbeef-dead-dead-dead-deaddeafbeef"

# shellcheck disable=SC2086
$HYPERKIT $ACPI $MEM $SMP $PCI_DEV $LPC_DEV $NET $IMG_CD $IMG_HDD $RND $UUID -f kexec,$KERNEL,$INITRD,"$CMDLINE"

# FreeBSD
#hyperkit $ACPI $MEM $SMP $PCI_DEV $LPC_DEV $NET $IMG_CD $IMG_HDD $UUID -f fbsd,$USERBOOT,$BOOTVOLUME,"$KERNELENV"

# UEFI
#$HYPERKIT $ACPI $MEM $SMP $PCI_DEV $LPC_DEV $NET $IMG_CD $IMG_HDD $UUID -f bootrom,BHYVE_UEFI_20160526.fd

## Example hyperkit from Docker4mac
# com.docker.hyperkit -A -u -F vms/0/hyperkit.pid -c 6 -m 2048M -s 0:0,hostbridge -s 31,lpc -s 1:0,virtio-vpnkit,path=vpnkit.eth.sock,uuid=14e24183-d6ee-47de-ba3b-26447873fdc0 -U ab15ccef-8c80-477b-acaf-ba3afcd341ae -s 2:0,ahci-hd,/Users/ballen/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw -s 3,virtio-sock,guest_cid=3,path=vms/0,guest_forwards=2376;1525 -s 4,ahci-cd,/Applications/Docker.app/Contents/Resources/linuxkit/docker-for-mac.iso -s 5,ahci-cd,vms/0/config.iso -s 6,ahci-cd,/Applications/Docker.app/Contents/Resources/linuxkit/docker.iso -s 7,virtio-rnd -l com1,autopty=vms/0/tty,asl -f bootrom,/Applications/Docker.app/Contents/Resources/uefi/UEFI.fd,,

## Example vpnkit from Docker4mac
#com.docker.vpnkit --ethernet fd:3 --port vpnkit.port.sock --port hyperkit://:62373/./vms/0 --diagnostics fd:4 --pcap fd:5 --vsock-path vms/0/connect --host-names host.docker.internal,docker.for.mac.host.internal,docker.for.mac.localhost --gateway-names gateway.docker.internal,docker.for.mac.gateway.internal,docker.for.mac.http.internal --vm-names docker-for-desktop --listen-backlog 32 --mtu 1500 --allowed-bind-addresses 0.0.0.0 --http /Users/ballen/Library/Group Containers/group.com.docker/http_proxy.json --dhcp /Users/ballen/Library/Group Containers/group.com.docker/dhcp.json --port-max-idle-time 300 --max-connections 2000 --gateway-ip 192.168.65.1 --host-ip 192.168.65.2 --lowest-ip 192.168.65.3 --highest-ip 192.168.65.254 --log-destination asl --udpv4-forwards 123:127.0.0.1:50861 --gc-compact-interval 1800

# Refs:
# - https://imil.net/blog/2019/02/04/Cleaner-micro-Kubernetes-on-OSX/
# - UEFI binary: https://people.freebsd.org/~grehan/bhyve_uefi/BHYVE_UEFI_20160526.fd

# Notes:
# - vmnet creates bridge100, and an en<N> inteface per VM. Adds the en<N> interface to the bridge.
# - vmnet requires running hyperkit with root privs
# - Unsure how vmnet is doing NAT. Appears it might be using Apple's Internet Sharing based on output from: pfctl -v -s rules
# - Vmnet is doing DHCP, find leases in /var/db/dhcpd_leases and /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist
# - Appears with vmnet, the VM *must* use the IP address assigned by DHCP. VLANs don't work.
# - Specifying a UUID causes the generated MAC address to be the same between boots. Based on https://github.com/zchee/go-vmnet/blob/master/vmnet.go. Hyperkit should have a -M option to print the MAC address and exit, but not working in current version in Brew.
# - Find host IP address that will be used for vmnet
#   $ defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet Shared_Net_Address
#  192.168.64.1
# - Seems unlikely that there is actually more than one vmnet based on the above com.apple.vmnet plist. Even though the man page for hyperkit shows a vmnetN syntax.
# - SIGTERM to the hyperkit process is how to gracefully shutdown a VM.
# - Apparent method to automatically find VMs IP, is based on the MAC address (generated via UUID) and then find entry in dhcpd_leases, eg. how docker-machine hyperkit driver is doing it.
# - In general hyperkit's help output and man page doesn't seem realiable. The man page seems to have many byhve/xyhve left overs
