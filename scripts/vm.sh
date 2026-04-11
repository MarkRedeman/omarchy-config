#!/usr/bin/env bash
set -euo pipefail

# VM configuration -- adjust these as needed
VM_NAME="omarchy-test"
VM_DISK="$HOME/VMs/${VM_NAME}.qcow2"
VM_ISO="$HOME/VMs/omarchy.iso"
VM_CPUS=4
VM_RAM=8192    # MB
VM_DISK_SIZE=40  # GB
VM_SSH_USER="${VM_SSH_USER:-$(whoami)}"
VM_SSH_PORT=2222  # host port forwarded to guest port 22
VIRSH_URI="qemu:///session"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  create   Create a new VM and boot from the Omarchy ISO
  start    Start an existing VM
  stop     Gracefully stop the VM
  destroy  Delete the VM and its disk image
  ssh      SSH into the VM (via localhost:$VM_SSH_PORT)
  status   Show VM status
EOF
    exit 1
}

require_virsh() {
    if ! command -v virsh &>/dev/null; then
        echo "Error: libvirt is not installed. See VM.md for setup instructions."
        exit 1
    fi
}

# Wrapper: always connect to the correct libvirt URI
virsh() { command virsh --connect "$VIRSH_URI" "$@"; }

cmd_create() {
    require_virsh

    if virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "VM '$VM_NAME' already exists. Use 'destroy' first or 'start' to boot it."
        exit 1
    fi

    if [[ ! -f "$VM_ISO" ]]; then
        echo "Error: ISO not found at $VM_ISO"
        echo "See VM.md for download instructions."
        exit 1
    fi

    mkdir -p "$(dirname "$VM_DISK")"

    echo "Creating VM '$VM_NAME' with ${VM_DISK_SIZE}G disk..."
    virt-install \
        --connect "$VIRSH_URI" \
        --name "$VM_NAME" \
        --memory "$VM_RAM" \
        --vcpus "$VM_CPUS" \
        --disk path="$VM_DISK",format=qcow2,bus=virtio,size="$VM_DISK_SIZE" \
        --cdrom "$VM_ISO" \
        --os-variant archlinux \
        --network none \
        --qemu-commandline="-netdev" \
        --qemu-commandline="user,id=mynet0,hostfwd=tcp::${VM_SSH_PORT}-:22" \
        --qemu-commandline="-device" \
        --qemu-commandline="virtio-net-pci,netdev=mynet0,bus=pcie.0,addr=0x5" \
        --graphics spice \
        --video virtio \
        --boot uefi \
        --check path_in_use=off \
        --noautoconsole

    echo "VM created. SSH will be available at localhost:$VM_SSH_PORT"
    echo "Opening virt-manager..."
    virt-manager --connect "$VIRSH_URI" --show-domain-console "$VM_NAME" &
}

cmd_start() {
    require_virsh

    if ! virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "Error: VM '$VM_NAME' does not exist. Run 'create' first."
        exit 1
    fi

    local state
    state=$(virsh domstate "$VM_NAME" 2>/dev/null)

    if [[ "$state" == "running" ]]; then
        echo "VM '$VM_NAME' is already running."
    else
        echo "Starting VM '$VM_NAME'..."
        virsh start "$VM_NAME"
    fi

    echo "SSH available at localhost:$VM_SSH_PORT"
    virt-manager --connect "$VIRSH_URI" --show-domain-console "$VM_NAME" &
}

cmd_stop() {
    require_virsh

    if ! virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "VM '$VM_NAME' does not exist."
        exit 0
    fi

    local state
    state=$(virsh domstate "$VM_NAME" 2>/dev/null)

    if [[ "$state" != "running" ]]; then
        echo "VM '$VM_NAME' is not running (state: $state)."
        exit 0
    fi

    echo "Stopping VM '$VM_NAME'..."
    virsh shutdown "$VM_NAME" || virsh destroy "$VM_NAME"
}

cmd_destroy() {
    require_virsh

    if ! virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "VM '$VM_NAME' does not exist."
        exit 0
    fi

    read -rp "Delete VM '$VM_NAME' and its disk? [y/N] " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo "Aborted."
        exit 0
    fi

    # Stop if running
    local state
    state=$(virsh domstate "$VM_NAME" 2>/dev/null || true)
    if [[ "$state" == "running" ]]; then
        virsh destroy "$VM_NAME" || true
    fi

    virsh undefine "$VM_NAME" --nvram --remove-all-storage 2>/dev/null \
        || virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null \
        || virsh undefine "$VM_NAME"

    # Clean up disk if undefine didn't remove it
    if [[ -f "$VM_DISK" ]]; then
        rm -f "$VM_DISK"
    fi

    echo "VM '$VM_NAME' destroyed."
}

cmd_ssh() {
    require_virsh

    echo "Connecting to $VM_SSH_USER@localhost:$VM_SSH_PORT..."
    ssh -p "$VM_SSH_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$VM_SSH_USER@localhost"
}

cmd_status() {
    require_virsh

    if ! virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "VM '$VM_NAME' does not exist."
        exit 0
    fi

    virsh dominfo "$VM_NAME"
    echo "SSH: localhost:$VM_SSH_PORT"
}

# Main
case "${1:-}" in
    create)  cmd_create  ;;
    start)   cmd_start   ;;
    stop)    cmd_stop    ;;
    destroy) cmd_destroy ;;
    ssh)     cmd_ssh     ;;
    status)  cmd_status  ;;
    *)       usage       ;;
esac
