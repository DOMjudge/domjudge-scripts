# Ansible test bed

Throw-away VMs that start in the state the playbooks expect on a freshly
installed machine: Ubuntu 26.04 or the ICPC contest image (see below), root SSH
with the `make`-generated key, python3 and a static address. Nothing else is
pre-configured. The machines and their addresses are taken from `hosts.vagrant`,
which `bootstrap.sh` links as the inventory (`../hosts`).

Setup, once (Debian):

    # as root
    apt-get install -y libvirt-daemon-system qemu-system-x86 qemu-utils  # run the VMs
    apt-get install -y libvirt-dev build-essential                       # build vagrant-libvirt
    apt-get install -y ansible rsync                                     # run the playbooks
    usermod -aG libvirt <your user>
    # as your user, after logging in again
    vagrant plugin install vagrant-libvirt

Usage, from this directory:

    ./bootstrap.sh                           # key, hosts, group_vars (never overwrites real ones)
    vagrant up && vagrant halt && vagrant snapshot save clean
    vagrant up
    cd .. && make domserver && make judgehost && test/e2e.sh

* `verify.sh` only reads: services, configuration in effect, connectivity.
* `e2e.sh` runs `verify.sh`, then changes state: it reruns both playbooks and
  fails on any change except the intended judgedaemon restart, then loads
  DOMjudge's example contest and checks verdicts: correct submissions in C,
  C++, Java and Python 3 (and Kotlin on the ICPC image), a wrong one, and
  ones exceeding the time and memory limits.
* Fresh start: `vagrant snapshot restore [machine] clean && vagrant up [machine]`.
  The snapshot is of halted VMs, so they boot with the current time.
* `DJ_BRANCH=<commit> ./bootstrap.sh` pins DOMjudge (until `DJ_BRANCH=main`);
  otherwise a new upstream commit between two runs triggers a (legitimate)
  rebuild.
* The judgehost has 3 vCPUs because `cpucore` defaults to core 2.
* VirtualBox works for the stock image if its kernel module builds; it needs
  `* 10.0.0.0/14` in `/etc/vbox/networks.conf`.
* Not covered: keepalived/replication (needs a second domserver),
  `WF_RESTRICTED_NETWORK`, `GRAFANA_MONITORING`, the other playbooks (admin,
  cds, scoreboard, ...), Kotlin on the stock image, UEFI boot order, hardware
  tuning.

Teardown: `vagrant destroy -f` (once per variant), then remove `../hosts` and
`../group_vars/onprem/{all,secret}.yml`; `make distclean` also removes the
generated key and certificates.

## Starting from the ICPC contest image

    ./make-icpc-box.sh /path/to/icpc-image.img     # once, builds the box 'icpc-image'
    vagrant halt                                   # the stock VMs use the same addresses
    export VARIANT=icpc                            # for all commands below
    ./bootstrap.sh                                 # GRAPHICAL=true also tests the desktop tasks
    vagrant up && vagrant halt && vagrant snapshot save clean
    vagrant up
    cd .. && make domserver && make judgehost && test/e2e.sh

With `VARIANT=icpc`, Vagrant manages a separate set of machines (`icpc-*`) and
`bootstrap.sh` sets `ICPC_IMAGE: true` and `AWS: false`. To switch back, halt
them, unset `VARIANT` and rerun `bootstrap.sh`. Vagrant refuses to start one
set while the other is running, or when `bootstrap.sh` was run for the other.

`make-icpc-box.sh` needs no root and never modifies the original image: in a
copy it replaces root's `authorized_keys` with the test key (the image has no
cloud-init and no vagrant user) and enlarges the disk, as the image has only a
few GiB free. On first boot the root filesystem is grown and the private
network is configured with `nmcli`, as Vagrant's own setup leaves this
NetworkManager based image unreachable. The box is for libvirt only, and boots
with BIOS; UEFI is untested.

## Manual testing

Wait until any running provisioning, `e2e.sh` or snapshot restore has
finished: provisioning restarts services and reboots the judgehost, `e2e.sh`
reruns the playbooks and loads the example contest, and a restore resets the
VM.

SSH, from `provision-contest/ansible` (VMs get recreated and restored, so their
host keys change):

    ssh -i roles/ssh/files/id_ed25519 -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null root@<ansible_host from test/hosts.vagrant>

or from this directory `vagrant ssh <machine>` (`icpc-<machine>` with
`VARIANT=icpc`; on the stock image this logs in as `vagrant`, use `sudo -i`).
Once provisioned, the same key also works for the `domjudge` user.

Screen: each VM has a VNC display on 127.0.0.1 of the host. The libvirt domain
names are `test_<machine>` (`test_icpc-<machine>` for the ICPC image).

    virt-viewer --connect qemu:///system test_icpc-domjudge-judgehost1   # package virt-viewer
    virsh -c qemu:///system domdisplay <domain>       # VNC display, :0 is port 5900
    virsh -c qemu:///system screenshot <domain> /tmp/screen.png     # always PNG

From another machine, tunnel the port first, e.g. `ssh -L 5900:127.0.0.1:5900 <host>`.

DOMjudge web interface: `https://<domserver address>/` from the host. The
certificate is self-signed and issued for `domjudge`, so add that name to
`/etc/hosts` or accept the warning. Log in as `admin` with `ADMIN_PASSWORD` from
`../group_vars/onprem/secret.yml`. After `e2e.sh`, the example contest `demo`
contains the submissions of its judging test.

To start over: `vagrant snapshot restore [machine] clean && vagrant up [machine]`.
