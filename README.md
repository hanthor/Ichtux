# Ichtux Linux

<div align="center">

![Ichtux Logo](https://via.placeholder.com/200x200/0066cc/ffffff?text=Ichtux)

**A Reproducible Linux Distribution Built From Scratch**

[![Build Status](https://github.com/hanthor/Ichtux/actions/workflows/build.yml/badge.svg)](https://github.com/hanthor/Ichtux/actions)
[![License](https://img.shields.io/github/license/hanthor/Ichtux)](LICENSE)
[![Bootc Compatible](https://img.shields.io/badge/bootc-compatible-brightgreen)](https://github.com/containers/bootc)

</div>

## 🎯 Overview

Ichtux is a reproducible Linux distribution built from scratch following [Linux From Scratch](https://www.linuxfromscratch.org/) (LFS) principles, packaged as bootc-compatible OCI images. It represents a modern approach to distribution building: source-based, reproducible, and container-native.

### Key Features

- ✅ **Built from Source**: Core components (toolchain, kernel, graphics) built from upstream sources
- ✅ **Reproducible Builds**: Automated via GitHub Actions with complete build transparency
- ✅ **Bootc Compatible**: Direct deployment to bare metal or VMs via bootc
- ✅ **OCI Native**: Distributed as standard container images
- ✅ **GNOME Desktop**: Full-featured desktop environment
- ✅ **Automated Updates**: Renovate-managed dependency tracking

## 📦 Quick Start

### Pull the Image

```bash
podman pull ghcr.io/hanthor/ichtux:latest
```

### Deploy to Disk

```bash
sudo bootc install to-disk \
  --image ghcr.io/hanthor/ichtux:latest \
  /dev/sdX
```

### Generate ISO

```bash
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v ./output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --rootfs ext4 \
  ghcr.io/hanthor/ichtux:latest
```

### Run in VM (QCOW2)

```bash
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v ./output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  ghcr.io/hanthor/ichtux:latest

# Boot with QEMU
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -drive file=output/disk.qcow2,format=qcow2 \
  -enable-kvm
```

## 🏗️ Architecture

Ichtux follows a **four-phase modular build strategy**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Phase 1: Bootstrap Toolchain                 │
│  • Binutils 2.42  • GCC 13.2.0  • Glibc 2.39                   │
│  Built from scratch using temporary Alpine build environment    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Phase 2: Base OS                           │
│  • Linux Kernel 6.7  • systemd 255  • Core utilities           │
│  Built from source using Phase 1 toolchain                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Phase 3: Graphical Stack                      │
│  • Mesa 24.0  • Wayland 1.22  • GTK 3/4  • GNOME Desktop       │
│  Graphics components from source + GNOME packages               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Phase 4: Final Assembly                        │
│  Bootc-compatible unified image with all components             │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Build Methodology

### "LFS - The OCI Way"

Ichtux adopts a **pragmatic approach** to Linux From Scratch:

1. **Core Components from Source**: Toolchain, kernel, and graphics stack are built from upstream tarballs
2. **Temporary Build Hosts**: Alpine Linux used only as a temporary build environment (discarded in final images)
3. **Strategic Package Use**: Complex GNOME components use Fedora packages to avoid rebuilding 100+ dependencies
4. **Multi-Stage Builds**: Each phase is isolated, cached, and can be built in parallel

### Build Infrastructure

- **CI/CD**: GitHub Actions with matrix strategy for parallel builds
- **Caching**: GitHub Actions cache (`type=gha`) for build artifact reuse
- **Artifacts**: SBOM generation, provenance attestation
- **Automation**: Renovate for automatic dependency updates

## 📁 Repository Structure

```
Ichtux/
├── containerfiles/
│   ├── phase1-toolchain/
│   │   └── Containerfile          # Bootstrap GCC/Glibc from scratch
│   ├── phase2-base/
│   │   └── Containerfile          # Kernel + systemd + core utilities
│   ├── phase3-graphical/
│   │   └── Containerfile          # Mesa + Wayland + GNOME
│   └── phase4-assembly/
│       └── Containerfile          # Final bootc-compatible image
├── .github/
│   └── workflows/
│       └── build.yml              # CI/CD pipeline
├── docs/                          # Documentation
├── scripts/                       # Build and utility scripts
├── renovate.json                  # Dependency management
├── LICENSE                        # GPL-3.0
└── README.md                      # This file
```

## 🔄 Automated Dependency Management

Ichtux uses **Renovate** with custom regex managers to automatically track and update:

- **Linux Kernel** (kernel.org)
- **GCC, Glibc, Binutils** (GNU mirrors)
- **systemd** (GitHub releases)
- **Mesa** (mesa3d.org)
- **Wayland** (freedesktop.org GitLab)
- **GNOME components** (GNOME GitLab)

Updates are proposed as PRs with a 3-day stabilization period.

## 🧪 Testing

Each build includes:

- ✅ Bootc compatibility verification
- ✅ OSTree metadata validation
- ✅ Package presence checks
- ✅ systemd functionality tests
- ✅ SBOM generation

## 📊 System Requirements

### Build Requirements

- **GitHub Actions runner** or self-hosted with:
  - 14 GB+ free disk space (aggressive cleanup applied)
  - Docker/Buildx
  - Multi-core CPU (parallel builds)

### Runtime Requirements

- **CPU**: x86_64, 2+ cores recommended
- **RAM**: 2 GB minimum, 4 GB+ recommended
- **Disk**: 10 GB minimum
- **Graphics**: Mesa-compatible GPU (Intel, AMD, Virtio)

## 🚀 Usage

### Default Credentials

```
Username: ichtux
Password: ichtux
```

**⚠️ Change the default password immediately after first login!**

### System Updates

```bash
# Update to latest image
sudo bootc upgrade

# Check current status
bootc status

# Rollback if needed
sudo bootc rollback
```

### Package Management

```bash
# Install packages
sudo rpm-ostree install <package>
sudo systemctl reboot

# Remove packages
sudo rpm-ostree uninstall <package>
sudo systemctl reboot
```

## 📚 Documentation

- [Phase 1: Toolchain Build](docs/phase1-toolchain.md)
- [Phase 2: Base OS Build](docs/phase2-base.md)
- [Phase 3: Graphical Stack](docs/phase3-graphical.md)
- [Phase 4: Assembly & Bootc](docs/phase4-assembly.md)
- [Building Locally](docs/building-locally.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md).

## 📜 License

Ichtux is licensed under the [GNU General Public License v3.0](LICENSE).

## 🙏 Acknowledgments

- [Linux From Scratch](https://www.linuxfromscratch.org/) project
- [bootc](https://github.com/containers/bootc) project
- [CentOS Bootc](https://github.com/CentOS/centos-bootc) team
- All upstream open-source projects

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/hanthor/Ichtux/issues)
- **Discussions**: [GitHub Discussions](https://github.com/hanthor/Ichtux/discussions)

---

<div align="center">

**Built with ❤️ using Linux From Scratch principles**

</div>