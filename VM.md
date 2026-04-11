# Testing with a VM

Use a QEMU/KVM virtual machine to test config changes without affecting your main system.

## Host setup

Install the virtualization stack (one-time):

```bash
omarchy-pkg-add qemu-full libvirt virt-manager dnsmasq edk2-ovmf
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```

Log out and back in for the group change to take effect.

## Download the Omarchy ISO

Grab the latest ISO from the [Omarchy releases](https://github.com/basecamp/omarchy/releases):

```bash
mkdir -p ~/VMs
curl -L -o ~/VMs/omarchy.iso https://iso.omarchy.org/omarchy-3.5.0-2.iso
```

Check the [releases page](https://github.com/basecamp/omarchy/releases) for newer versions and update the URL accordingly.

## Create and boot the VM

A helper script is included at `scripts/vm.sh`:

```bash
# Create a new VM and boot from the ISO (first run)
./scripts/vm.sh create

# Start an existing VM (subsequent runs)
./scripts/vm.sh start

# Stop the VM
./scripts/vm.sh stop

# Delete the VM and its disk
./scripts/vm.sh destroy

# SSH into the VM (after Omarchy is installed and SSH is enabled)
./scripts/vm.sh ssh

# Show VM info
./scripts/vm.sh status
```

The script creates a VM with:
- 4 CPU cores, 8 GB RAM (adjustable at the top of the script)
- 40 GB virtual disk
- UEFI boot (required by Omarchy)
- virtio graphics, network, and disk for best performance
- SSH port forwarding: guest port 22 is accessible at `localhost:2222`

## Install Omarchy in the VM

1. Run `./scripts/vm.sh create` -- this opens a virt-manager window with the ISO booted
2. Follow the Omarchy installer in the VM
3. After installation completes, the VM will reboot into Omarchy
4. Log in and enable SSH so you can push config changes:
   ```bash
   omarchy-pkg-add openssh
   sudo systemctl enable --now sshd
   ```
5. If a firewall is active (e.g. UFW), allow SSH:
   ```bash
   sudo ufw allow 22/tcp
   ```
   Note: the host forwards port 2222 to the guest's port 22, so the guest
   firewall only needs port 22 open.

## Set up SSH access

The VM forwards guest port 22 to `localhost:2222` on the host. Add a host alias
to `~/.ssh/config` for convenience:

```
Host omarchy-vm
    HostName localhost
    Port 2222
    User <your-username>
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Then you can use `omarchy-vm` as a target in ssh/rsync commands, or just run
`./scripts/vm.sh ssh`.

## Deploy your config into the VM

From the **host**:

```bash
# Copy this repo into the VM
rsync -avz -e 'ssh -p 2222' --exclude='.git' --exclude='old-dots' \
  ~/projects/omarchy-config/ localhost:~/projects/omarchy-config/
```

Or using the SSH config alias:

```bash
rsync -avz --exclude='.git' --exclude='old-dots' \
  ~/projects/omarchy-config/ omarchy-vm:~/projects/omarchy-config/
```

Then **SSH into the VM** and deploy:

```bash
./scripts/vm.sh ssh
# now inside the VM:
cd ~/projects/omarchy-config
./scripts/deploy.sh
```

For iterating on a single package, from the **host**:

```bash
# Push just the hypr config
rsync -avz -e 'ssh -p 2222' dotfiles/hypr/ \
  localhost:~/projects/omarchy-config/dotfiles/hypr/
```

Then **inside the VM**:

```bash
stow --restow --target=$HOME --dir=~/projects/omarchy-config/dotfiles hypr
hyprctl reload
```

## Tips

- **Clipboard sharing**: Run `omarchy-pkg-add spice-vdagent` in the guest for clipboard sync between host and VM.
- **Shared folder**: Use `rsync`/`scp` to push files. The rsync approach above is simplest.
- **Resolution**: The VM defaults to virtio GPU. You can resize the virt-manager window and the guest display will follow.
- **Snapshots**: Use `virsh snapshot-create-as omarchy-test clean-install` before testing destructive changes, then revert with `virsh snapshot-revert omarchy-test clean-install`.
- **SSH port**: Defaults to `localhost:2222`. Change `VM_SSH_PORT` in `scripts/vm.sh` if that port is in use.

## Troubleshooting

### `virt-install` fails with "No module named 'gi'"

`virt-install` uses `#!/usr/bin/env python3`, which may resolve to a
version manager (mise, pyenv, asdf) instead of system Python. The `gi` module
(`python-gobject`) is only installed for system Python. The repo includes a
`.mise.toml` that disables mise's Python in this directory. If you use a
different version manager, ensure `python3` resolves to `/usr/bin/python3`
when running `vm.sh`.

### PCI slot conflict on create

If `vm.sh create` fails with an error like:

```
PCI: slot X function 0 not available for virtio-vga, in use by virtio-net-pci
```

The `--qemu-commandline` network device is colliding with another PCI device.
Edit the PCI address in `vm.sh` (look for `addr=0x5`) and try a different slot
number (e.g. `0x6`, `0x7`).

### SSH hangs or "Connection refused"

The VM forwards guest port 22 to host port 2222 via QEMU user-mode networking.
If `./scripts/vm.sh ssh` hangs:

1. Make sure `sshd` is running **inside the VM**:
   ```bash
   omarchy-pkg-add openssh
   sudo systemctl enable --now sshd
   ```
2. If a firewall is active in the guest, allow port 22 (not 2222):
   ```bash
   sudo ufw allow 22/tcp
   ```
3. Verify the port is listening on the host: `ss -tlnp | grep 2222`

### VM has no internet

The script uses `qemu:///session` with SLIRP (user-mode) networking, which
should provide internet access out of the box via NAT. If the guest has no
connectivity:

1. Check the interface exists: `ip link` (look for `enp1s0` or similar)
2. Verify a DHCP client is running: `networkctl status`
3. Try manually: `sudo ip link set enp1s0 up && sudo dhcpcd enp1s0`
