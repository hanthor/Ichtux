# Modular Component Architecture

Ichtux publishes individual components as separately tagged OCI images, allowing you to compose custom systems from versioned building blocks.

## Architecture Overview

```
ghcr.io/hanthor/ichtux/
├── core/
│   ├── gcc:13.2.0
│   ├── glibc:2.39
│   ├── bash:5.2.21
│   ├── wget:1.21.4
│   ├── tar:1.35
│   └── ...
├── system/
│   ├── linux-kernel:6.7.0
│   ├── busybox:1.36.1
│   ├── util-linux:2.39.3
│   └── ...
├── graphics/
│   ├── mesa:24.0.0
│   ├── wayland:1.22.0
│   ├── libdrm:2.4.120
│   └── ...
└── phase{1-4}-*/
    └── Complete phase aggregates
```

## Benefits

### 1. **Precise Version Control**
Each component is tagged with its exact upstream version:
```bash
docker pull ghcr.io/hanthor/ichtux/core/wget:1.21.4
docker pull ghcr.io/hanthor/ichtux/graphics/mesa:24.0.0
```

### 2. **Mix and Match**
Build custom systems with specific component versions:
```dockerfile
FROM ghcr.io/hanthor/ichtux/core/gcc:13.2.0 AS compiler
FROM ghcr.io/hanthor/ichtux/core/bash:5.2.21 AS shell
FROM scratch
COPY --from=compiler /tools/bin/gcc /usr/bin/
COPY --from=shell /tools/bin/bash /bin/bash
```

### 3. **Independent Updates**
Update individual components without rebuilding everything:
```bash
# Update just Mesa
docker pull ghcr.io/hanthor/ichtux/graphics/mesa:24.1.0

# Kernel stays at 6.7.0
docker pull ghcr.io/hanthor/ichtux/system/linux-kernel:6.7.0
```

### 4. **Efficient Caching**
Components are cached independently in CI/CD:
- Change wget → only rebuild wget
- Change Mesa → only rebuild Mesa
- All other components pulled from cache

### 5. **Reusability**
Use Ichtux components in other projects:
```dockerfile
# Use Ichtux's GCC in your custom distro
FROM ghcr.io/hanthor/ichtux/core/gcc:13.2.0 AS toolchain
FROM mybase:latest
COPY --from=toolchain /tools /opt/ichtux-gcc
```

## Component Categories

### Core Tools (`/core/*`)
Fundamental build tools built from source in Phase 1:

| Component | Latest Version | Purpose |
|-----------|----------------|---------|
| binutils | 2.42 | Binary utilities (linker, assembler) |
| gcc | 13.2.0 | GNU Compiler Collection |
| glibc | 2.39 | GNU C Library |
| bash | 5.2.21 | Bourne Again Shell |
| coreutils | 9.4 | Core utilities (ls, cp, mv, etc.) |
| wget | 1.21.4 | Network downloader |
| tar | 1.35 | Archive tool |
| make | 4.4.1 | Build automation |
| grep | 3.11 | Pattern matching |
| sed | 4.9 | Stream editor |
| gawk | 5.3.0 | Text processing |
| findutils | 4.9.0 | File finding utilities |
| diffutils | 3.10 | File comparison |
| patch | 2.7.6 | Applying patches |
| bison | 3.8.2 | Parser generator |
| xz | 5.4.6 | Compression |

### System Components (`/system/*`)
Operating system essentials built in Phase 2:

| Component | Latest Version | Purpose |
|-----------|----------------|---------|
| linux-kernel | 6.7.0 | Linux kernel with bootc support |
| busybox | 1.36.1 | Minimal userspace utilities |
| util-linux | 2.39.3 | System utilities |
| e2fsprogs | 1.47.0 | Ext2/3/4 filesystem tools |
| kmod | 31 | Kernel module tools |

### Graphics Components (`/graphics/*`)
Graphics stack built from source in Phase 3:

| Component | Latest Version | Purpose |
|-----------|----------------|---------|
| mesa | 24.0.0 | OpenGL/Vulkan implementation |
| wayland | 1.22.0 | Display server protocol |
| wayland-protocols | 1.33 | Wayland protocol extensions |
| libdrm | 2.4.120 | Direct Rendering Manager |
| pixman | 0.43.2 | Pixel manipulation library |

## Usage Examples

### Example 1: Custom Minimal System

```dockerfile
# Minimal bootable system with just kernel and BusyBox
FROM ghcr.io/hanthor/ichtux/system/linux-kernel:6.7.0 AS kernel
FROM ghcr.io/hanthor/ichtux/system/busybox:1.36.1 AS userspace

FROM scratch
COPY --from=kernel /rootfs/boot /boot
COPY --from=kernel /rootfs/lib/modules /lib/modules
COPY --from=userspace /rootfs /

CMD ["/bin/sh"]
```

### Example 2: Development Environment

```dockerfile
# Custom dev environment with specific tool versions
FROM ghcr.io/hanthor/ichtux/core/gcc:13.2.0 AS gcc
FROM ghcr.io/hanthor/ichtux/core/make:4.4.1 AS make
FROM ghcr.io/hanthor/ichtux/core/bash:5.2.21 AS bash

FROM ubuntu:22.04
COPY --from=gcc /tools/bin/gcc /usr/local/bin/
COPY --from=gcc /tools/lib /usr/local/lib/
COPY --from=make /tools/bin/make /usr/local/bin/
COPY --from=bash /tools/bin/bash /bin/bash

RUN ldconfig
```

### Example 3: Graphics Workstation

```dockerfile
# Custom graphics-enabled system
FROM ghcr.io/hanthor/ichtux/graphics/mesa:24.0.0 AS mesa
FROM ghcr.io/hanthor/ichtux/graphics/wayland:1.22.0 AS wayland
FROM ghcr.io/hanthor/ichtux/system/linux-kernel:6.7.0 AS kernel

FROM fedora:39
COPY --from=mesa /rootfs/usr /usr
COPY --from=wayland /rootfs/usr /usr
COPY --from=kernel /rootfs/boot/vmlinuz /boot/vmlinuz-custom

RUN ldconfig
```

### Example 4: Version Pinning for Reproducibility

```dockerfile
# Pin exact versions for reproducible builds
FROM ghcr.io/hanthor/ichtux/core/gcc:13.2.0 AS gcc
FROM ghcr.io/hanthor/ichtux/core/glibc:2.39 AS libc

FROM scratch AS builder
COPY --from=gcc /tools /tools
COPY --from=libc /tools/lib /tools/lib

# Your build steps here...
RUN /tools/bin/gcc --version  # Always 13.2.0
```

## CI/CD Integration

### Using Components in Your Pipeline

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Pull Ichtux GCC
        run: docker pull ghcr.io/hanthor/ichtux/core/gcc:13.2.0
      
      - name: Compile with Ichtux GCC
        run: |
          docker run --rm -v $(pwd):/work \
            ghcr.io/hanthor/ichtux/core/gcc:13.2.0 \
            /tools/bin/gcc /work/myapp.c -o /work/myapp
```

### Version Matrix Testing

```yaml
strategy:
  matrix:
    gcc_version: ['12.3.0', '13.2.0', '14.0.0']
steps:
  - name: Test with GCC ${{ matrix.gcc_version }}
    run: |
      docker pull ghcr.io/hanthor/ichtux/core/gcc:${{ matrix.gcc_version }}
      # Run tests...
```

## Renovate Integration

All component versions are automatically tracked:

```json
{
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "matchPackageNames": ["ghcr.io/hanthor/ichtux/core/*"],
      "automerge": false
    }
  ]
}
```

Renovate will:
1. Detect new upstream releases
2. Create PRs with updated ARG versions
3. Trigger rebuilds of affected components
4. Publish new versioned tags

## Component Discovery

### List All Available Components

```bash
# List all core tools
docker search ghcr.io/hanthor/ichtux/core

# List all system components
docker search ghcr.io/hanthor/ichtux/system

# List all graphics components
docker search ghcr.io/hanthor/ichtux/graphics
```

### Check Component Metadata

```bash
# Inspect a component
docker inspect ghcr.io/hanthor/ichtux/core/gcc:13.2.0

# Check labels
docker inspect ghcr.io/hanthor/ichtux/core/gcc:13.2.0 \
  --format '{{json .Config.Labels}}' | jq
```

## Version Compatibility

### Component Dependencies

Some components depend on others:

```
gcc:13.2.0 requires:
  ├── glibc:2.39
  ├── binutils:2.42
  └── linux-headers:6.7.0

mesa:24.0.0 requires:
  ├── libdrm:2.4.120
  └── wayland:1.22.0
```

### Phase Aggregates

For guaranteed compatibility, use phase aggregates:
- `phase1-toolchain:1.0.0` - All core tools, tested together
- `phase2-base:1.0.0` - Kernel + system tools, tested together
- `phase3-graphical:1.0.0` - Graphics stack, tested together
- `phase4-assembly:1.0.0` - Complete system, tested together

## Best Practices

### 1. Pin Specific Versions in Production
```dockerfile
# Good
FROM ghcr.io/hanthor/ichtux/core/gcc:13.2.0

# Avoid in production
FROM ghcr.io/hanthor/ichtux/core/gcc:latest
```

### 2. Use Phase Aggregates for Simplicity
```dockerfile
# If you need multiple components from same phase
FROM ghcr.io/hanthor/ichtux/phase1-toolchain:1.0.0
# Contains all core tools with tested compatibility
```

### 3. Test Component Updates
```bash
# Before updating in production
docker pull ghcr.io/hanthor/ichtux/core/gcc:13.3.0
docker run --rm -it ghcr.io/hanthor/ichtux/core/gcc:13.3.0 /tools/bin/gcc --version
# Test your builds with new version
```

### 4. Document Your Component Versions
```yaml
# components.yml
ichtux:
  core:
    gcc: "13.2.0"
    bash: "5.2.21"
  graphics:
    mesa: "24.0.0"
```

## Migration Guide

### From Monolithic to Modular

Before:
```dockerfile
FROM ghcr.io/hanthor/ichtux:latest
```

After:
```dockerfile
# Use specific components you need
FROM ghcr.io/hanthor/ichtux/phase4-assembly:1.0.0
# Or build from individual components
```

## Component Catalog

For a complete list of all published components with versions, see:
- [Component Catalog](component-catalog.md) (auto-generated)
- [GitHub Packages](https://github.com/hanthor/Ichtux/packages)

## Related Documentation

- [Building Locally](building-locally.md)
- [Phase 1: Toolchain](phase1-toolchain.md)
- [Contributing](../CONTRIBUTING.md)
