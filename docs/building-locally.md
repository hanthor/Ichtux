# Building Ichtux Locally

This guide explains how to build Ichtux on your local machine for development and testing.

## Prerequisites

### System Requirements

- **OS**: Linux (tested on Ubuntu 22.04, Fedora 39)
- **CPU**: x86_64 with 4+ cores (8+ recommended)
- **RAM**: 8 GB minimum, 16 GB+ recommended
- **Disk**: 50 GB free space minimum
- **Container Runtime**: Docker or Podman with Buildx support

### Software Requirements

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y docker.io docker-buildx git

# Fedora
sudo dnf install -y docker docker-compose git
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

## Quick Start

### Clone the Repository

```bash
git clone https://github.com/hanthor/Ichtux.git
cd Ichtux
```

### Build All Phases

```bash
# Build Phase 1: Toolchain (takes ~45-60 minutes)
docker buildx build \
  --file containerfiles/phase1-toolchain/Containerfile \
  --tag ichtux/phase1-toolchain:latest \
  --target toolchain \
  .

# Build Phase 2: Base OS (takes ~30-40 minutes)
docker buildx build \
  --file containerfiles/phase2-base/Containerfile \
  --tag ichtux/phase2-base:latest \
  --build-arg PHASE1_IMAGE=ichtux/phase1-toolchain:latest \
  --target base-os \
  .

# Build Phase 3: Graphical Stack (takes ~20-30 minutes)
docker buildx build \
  --file containerfiles/phase3-graphical/Containerfile \
  --tag ichtux/phase3-graphical:latest \
  --build-arg PHASE1_IMAGE=ichtux/phase1-toolchain:latest \
  --target graphical-stack \
  .

# Build Phase 4: Final Assembly (takes ~15-20 minutes)
docker buildx build \
  --file containerfiles/phase4-assembly/Containerfile \
  --tag ichtux/final:latest \
  --target final \
  .
```

### Build Script

Use the provided build script for automated building:

```bash
./scripts/build-local.sh
```

## Step-by-Step Build

### Phase 1: Bootstrap Toolchain

This builds GCC, Glibc, and all build tools from source.

```bash
cd Ichtux

# Build with progress output
docker buildx build \
  --file containerfiles/phase1-toolchain/Containerfile \
  --tag ichtux/phase1-toolchain:latest \
  --target toolchain \
  --progress=plain \
  .

# Verify the build
docker run --rm ichtux/phase1-toolchain:latest /tools/bin/gcc --version
docker run --rm ichtux/phase1-toolchain:latest /tools/bin/bash --version
docker run --rm ichtux/phase1-toolchain:latest /tools/bin/wget --version
```

**Expected output**:
```
gcc (GCC) 13.2.0
GNU bash, version 5.2.21
GNU Wget 1.21.4
```

### Phase 2: Base OS

Builds Linux kernel and base system using Phase 1 toolchain.

```bash
docker buildx build \
  --file containerfiles/phase2-base/Containerfile \
  --tag ichtux/phase2-base:latest \
  --build-arg PHASE1_IMAGE=ichtux/phase1-toolchain:latest \
  --target base-os \
  --progress=plain \
  .

# Verify kernel is present
docker run --rm ichtux/phase2-base:latest ls -lh /boot/
```

### Phase 3: Graphical Stack

Builds Mesa, Wayland, and GNOME desktop.

```bash
docker buildx build \
  --file containerfiles/phase3-graphical/Containerfile \
  --tag ichtux/phase3-graphical:latest \
  --build-arg PHASE1_IMAGE=ichtux/phase1-toolchain:latest \
  --target graphical-stack \
  --progress=plain \
  .

# Verify Mesa
docker run --rm ichtux/phase3-graphical:latest glxinfo | head -20
```

### Phase 4: Final Assembly

Creates bootc-compatible final image.

```bash
docker buildx build \
  --file containerfiles/phase4-assembly/Containerfile \
  --tag ichtux/final:latest \
  --target final \
  --progress=plain \
  .

# Verify bootc compatibility
docker inspect ichtux/final:latest | jq '.[0].Config.Labels."bootc.compatible"'
```

## Caching

### Enable BuildKit Cache

For faster rebuilds, use BuildKit's cache:

```bash
docker buildx build \
  --file containerfiles/phase1-toolchain/Containerfile \
  --tag ichtux/phase1-toolchain:latest \
  --cache-from type=local,src=/tmp/buildx-cache \
  --cache-to type=local,dest=/tmp/buildx-cache,mode=max \
  --target toolchain \
  .
```

### Registry Cache

Push intermediate images to a registry for caching:

```bash
docker buildx build \
  --file containerfiles/phase1-toolchain/Containerfile \
  --tag registry.local/ichtux/phase1-toolchain:latest \
  --cache-from type=registry,ref=registry.local/ichtux/phase1-toolchain:cache \
  --cache-to type=registry,ref=registry.local/ichtux/phase1-toolchain:cache,mode=max \
  --push \
  --target toolchain \
  .
```

## Testing the Build

### Run in Container

```bash
# Run the final image
docker run --rm -it ichtux/final:latest /bin/bash

# Inside the container
systemctl status
ls /usr/share/doc/ichtux/
cat /etc/os-release
```

### Generate ISO

Requires `bootc-image-builder`:

```bash
mkdir -p output

sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --rootfs ext4 \
  docker://ichtux/final:latest

# ISO will be in ./output/
ls -lh output/*.iso
```

### Test in QEMU

```bash
# Generate QCOW2 image
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  docker://ichtux/final:latest

# Boot with QEMU
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -drive file=output/disk.qcow2,format=qcow2 \
  -enable-kvm \
  -display gtk
```

## Troubleshooting

### Out of Disk Space

**Problem**: Build fails with "no space left on device"

**Solution**:
```bash
# Clean up Docker
docker system prune -a -f --volumes

# Or move Docker data directory to a larger partition
sudo systemctl stop docker
sudo mv /var/lib/docker /mnt/large-partition/docker
sudo ln -s /mnt/large-partition/docker /var/lib/docker
sudo systemctl start docker
```

### Build Takes Too Long

**Problem**: Builds are very slow

**Solution**:
```bash
# Increase parallel jobs
export MAKEFLAGS="-j$(nproc)"

# Use more CPU cores in Docker
# Edit /etc/docker/daemon.json
{
  "cpu-count": 8
}

sudo systemctl restart docker
```

### Phase 1 Fails to Build GCC

**Problem**: GCC compilation errors

**Solution**:
```bash
# Check if you have enough RAM (needs 4GB minimum per core)
free -h

# Reduce parallel builds if low on RAM
docker buildx build --build-arg MAKEFLAGS="-j2" ...
```

### Cannot Connect to GitHub

**Problem**: wget fails to download sources

**Solution**:
```bash
# Use a mirror or proxy
# Edit Containerfile and add:
ENV HTTP_PROXY=http://your-proxy:port
ENV HTTPS_PROXY=http://your-proxy:port
```

## Development Workflow

### Modify a Phase

1. Edit the Containerfile
2. Build only that phase
3. Test the changes
4. Rebuild dependent phases

Example:
```bash
# Modify Phase 1
vim containerfiles/phase1-toolchain/Containerfile

# Rebuild Phase 1
docker buildx build -f containerfiles/phase1-toolchain/Containerfile \
  -t ichtux/phase1-toolchain:dev .

# Test it
docker run --rm ichtux/phase1-toolchain:dev /tools/bin/gcc --version

# Rebuild Phase 2 with dev image
docker buildx build -f containerfiles/phase2-base/Containerfile \
  --build-arg PHASE1_IMAGE=ichtux/phase1-toolchain:dev \
  -t ichtux/phase2-base:dev .
```

### Test Individual Stages

```bash
# Build and test a specific stage
docker buildx build \
  -f containerfiles/phase1-toolchain/Containerfile \
  --target gcc-pass1 \
  -t ichtux/gcc-pass1:test \
  .

docker run --rm -it ichtux/gcc-pass1:test /bin/bash
```

## Performance Tips

1. **Use SSD**: Build on SSD for 2-3x faster builds
2. **More RAM**: 16GB+ allows more parallel compilation
3. **Cache Layers**: Use `--cache-from` and `--cache-to`
4. **Ccache**: Add ccache to toolchain for C/C++ caching
5. **Local Registry**: Run a local registry for faster image operations

## Next Steps

- [Phase 1 Documentation](phase1-toolchain.md)
- [Phase 2 Documentation](phase2-base.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
