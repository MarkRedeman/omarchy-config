# Intel Panther Lake XPU Getting Started

Hardware: Dell XPS with Intel Core Ultra 7 358H (Panther Lake / Lunar Lake)  
Operating System: Omarchy (Arch Linux) with Hyprland  
Date: 2026-05-25

---

## Hardware Overview

Panther Lake / Lunar Lake features an integrated **XPU (eXtended Processing Unit)** with:

| Component | Model    | Architecture           | Kernel Driver |
|-----------|----------|------------------------|---------------|
| **GPU**   | Arc B390 | Xe3                    | `xe`          |
| **NPU**   | NPU 3.0  | Neural Processing Unit | `intel_vpu`   |

**Minimum Kernel Requirements:** Linux 6.12+ (Linux 7.1+ recommended for FRED performance improvements)

**Working Kernel:** On Omarchy, a special kernel with Panther Lake support is available. Verified working:
```
Linux mark-ptl-xps-omarchy 7.0.3-arch1-2-ptl
```

The `-ptl` suffix indicates Omarchy's Panther Lake optimized kernel build.

---

## Prerequisites

### Verify Kernel Support

```bash
# Check kernel version (should be 6.12+)
uname -r

# Check if drivers are loaded
lsmod | grep -E 'xe|intel_vpu'

# Check hardware detection
lspci -knnd ::1200   # NPU
lspci -knnd ::0300   # GPU
lspci -knnd ::0380   # Display controller
```

### User Groups

For GPU/NPU access, your user needs to be in the `render` group:

```bash
# Check current groups
groups

# Add to render group if missing
sudo usermod -aG render $USER

# Add to uucp group for serial/USB device access (optional but useful for dev)
sudo usermod -aG uucp $USER
```

**Important:** Log out and back in for group changes to take effect.

---

## Step 1: Install GPU/XPU Drivers (Official Repos)

These packages provide user-space drivers for the Arc B390 GPU:

```bash
omarchy pkg add mesa vulkan-intel intel-compute-runtime intel-graphics-compiler level-zero-headers intel-media-driver
```

**Package breakdown:**

| Package                   | Purpose                                       |
|---------------------------|-----------------------------------------------|
| `mesa`                    | OpenGL and Vulkan drivers                     |
| `vulkan-intel`            | Intel Vulkan driver for Xe3                   |
| `intel-compute-runtime`   | Level Zero and OpenCL (for AI compute on GPU) |
| `intel-graphics-compiler` | OpenCL C/C++ compiler (dependency)            |
| `level-zero-headers`      | Level Zero API headers                        |
| `intel-media-driver`      | Hardware video encoding/decoding (VA-API)     |

---

## Step 2: Install NPU Driver (AUR)

The NPU 3.0 requires user-space drivers from the AUR:

```bash
omarchy pkg aur add intel-npu-driver-bin
```

### Important: The NPU Library Path Issue

The AUR package `intel-npu-driver-bin` extracts **Ubuntu .deb files**, placing libraries under:

```
/usr/lib/x86_64-linux-gnu/    ← Debian/Ubuntu path
```

Instead of the standard Arch path:

```
/usr/lib/                      ← Arch Linux path
```

### The Fix

Create an ldconfig configuration to make the NPU libraries discoverable:

```bash
# Add the Debian library path to ldconfig
echo "/usr/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/intel-npu.conf

# Rebuild the library cache
sudo ldconfig
```

### Alternative: Symlink (less clean)

```bash
# Option B - direct symlink
sudo ln -s /usr/lib/x86_64-linux-gnu/libze_intel_npu.so /usr/lib/libze_intel_npu.so
sudo ldconfig
```

---

## Step 3: Install Level Zero Loader

The `level-zero-loader` provides `libze_loader.so`, which is the Level Zero dispatch layer that AI applications use to discover and communicate with GPU/NPU devices:

```bash
omarchy pkg add level-zero-loader
```

---

## Step 4: Optional Video Acceleration Libraries

For hardware-accelerated video encoding/decoding:

```bash
omarchy pkg add vpl-gpu-rt libva-utils onevpl-tools libvpl libvpl-tools
```

| Package                                  | Purpose                     |
|------------------------------------------|-----------------------------|
| `vpl-gpu-rt`                             | Intel oneVPL GPU Runtime    |
| `libva-utils`                            | VA-API utilities (`vainfo`) |
| `onevpl-tools`, `libvpl`, `libvpl-tools` | oneVPL video processing     |

---

## Step 5: Verification

### Kernel & Hardware

```bash
# Check kernel modules loaded
lsmod | grep -E 'xe|intel_vpu'

# Should show:
# intel_vpu
# xe

# Check NPU device node (should exist)
ls -l /dev/accel/accel0

# Should show: crw-rw---- 1 root render 261, 0 ...
```

### Libraries

```bash
# Verify NPU libraries are in the cache
ldconfig -p | grep npu

# Should show:
#   libze_intel_npu.so.1 => /usr/lib/x86_64-linux-gnu/libze_intel_npu.so.1
#   libze_intel_npu.so => /usr/lib/x86_64-linux-gnu/libze_intel_npu.so
```

### OpenCL (for GPU compute)

```bash
# Install clinfo for verification
omarchy pkg add clinfo

# Check OpenCL devices
clinfo | grep -i "device name"
```

### Level Zero / AI

```bash
# Level Zero devices will be detected by applications that use:
# - OpenVINO
# - PyTorch with IPEX
# - Directly via libze_loader.so
```

---

## Step 6: AI Frameworks

### OpenVINO (Recommended for NPU)

OpenVINO is Intel's optimized AI toolkit. It's the primary way to use the NPU:

```bash
# Install OpenVINO from official repos
omarchy pkg add openvino python python-pip
```

**Verify OpenVINO can see all devices:**

```python
from openvino import Core

c = Core()
print('Devices:', c.available_devices)
# Should show: ['CPU', 'GPU', 'NPU']
```

### PyTorch with IPEX (for GPU training)

```bash
# Basic PyTorch (CPU version as base)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Intel Extension for PyTorch (IPEX) for GPU acceleration
pip install intel-extension-for-pytorch
```

**Verify PyTorch XPU is available:**

```python
import torch

print("XPU available:", torch.xpu.is_available())
print("XPU devices:", torch.xpu.device_count())
```

---

## Step 7: Additional Tools

### Huggingface CLI

For downloading and managing models from Huggingface Hub:

```bash
uv tool install huggingface_hub

# Login to access private/gated models
hf auth login
```

### mise (dev tools)

If using mise for version management:

```bash
mise use prek
mise use jq
mise use rg
```

---

## Troubleshooting

### Issue: NPU not detected

**Check 1: Is `intel_vpu` module loaded?**
```bash
lsmod | grep intel_vpu
```

**Check 2: Are NPU libraries in ldconfig?**
```bash
ldconfig -p | grep npu
```

If not, re-run the fix:
```bash
echo "/usr/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/intel-npu.conf
sudo ldconfig
```

**Check 3: User in render group?**
```bash
groups | grep render
```

### Issue: GPU not detected

**Check `xe` module:**
```bash
lsmod | grep xe
```

**Check kernel logs:**
```bash
# GPU logs
sudo journalctl -kg xe | tail -20

# NPU logs
sudo journalctl -kg intel_vpu | tail -20
```

### Issue: Level Zero not working

Make sure `level-zero-loader` is installed:
```bash
pacman -Qs level-zero
```

Should show both `level-zero-headers` and `level-zero-loader`.

---

## Quick Reference

### Installation Cheat Sheet

```bash
# GPU drivers
omarchy pkg add mesa vulkan-intel intel-compute-runtime intel-graphics-compiler level-zero-headers intel-media-driver

# NPU driver (AUR)
omarchy pkg aur add intel-npu-driver-bin

# NPU library path fix
echo "/usr/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/intel-npu.conf
sudo ldconfig

# Level Zero loader
omarchy pkg add level-zero-loader

# User groups
sudo usermod -aG render $USER
sudo usermod -aG uucp $USER

# OpenVINO
omarchy pkg add openvino python python-pip

# Video acceleration (optional)
omarchy pkg add vpl-gpu-rt libva-utils onevpl-tools libvpl libvpl-tools
```

### Verification Commands

```bash
# Kernel
lsmod | grep -E 'xe|intel_vpu'
lspci -knnd ::1200    # NPU
lspci -knnd ::0300    # GPU

# Device
ls -l /dev/accel/accel0
groups | grep render

# Libraries
ldconfig -p | grep npu

# OpenCL
clinfo | grep -i "device name"
```

---

## References

- [Intel Arc Graphics - Arch Wiki](https://wiki.archlinux.org/title/Intel_Arc_Graphics)
- [intel-compute-runtime - Arch Wiki](https://wiki.archlinux.org/title/GPGPU#Intel)
- [OpenVINO Documentation](https://docs.openvino.ai/)
- [Intel NPU Driver](https://github.com/intel/linux-npu-driver)
