# Phase 1: Bootstrap Toolchain

## Overview

Phase 1 creates a cross-compilation toolchain from scratch, building:
- **Binutils 2.42**: Assembler, linker, and binary utilities
- **GCC 13.2.0**: GNU Compiler Collection (C/C++)
- **Glibc 2.39**: GNU C Library
- **Linux Headers 6.7.0**: Kernel API headers

## Build Strategy

### Temporary Build Host

We use **Alpine Linux 3.19** as a minimal temporary build environment. This is a pragmatic choice:
- ✅ Minimal footprint (~5MB base)
- ✅ Fast package installation
- ✅ Only used for building - **nothing from Alpine enters the final image**

### Two-Pass Compilation

Following LFS methodology, GCC is built in two passes:

1. **Pass 1**: Static GCC without libc support
   - Targets cross-compilation
   - No standard library dependencies
   - Produces `x86_64-lfs-linux-gnu-gcc`

2. **Pass 2**: Full GCC with Glibc
   - Built against our custom Glibc
   - Complete C/C++ support
   - Produces production-ready toolchain

## Build Process

```
Alpine (temp) → Binutils Pass 1
              ↓
              GCC Pass 1 (static)
              ↓
              Linux Headers
              ↓
              Glibc
              ↓
              Libstdc++
              ↓
              GCC Pass 2 (full)
              ↓
              Extract to scratch → Final toolchain image
```

## Dependencies Managed by Renovate

```dockerfile
ARG BINUTILS_VERSION=2.42      # GNU Binutils
ARG GCC_VERSION=13.2.0         # GNU Compiler Collection
ARG GLIBC_VERSION=2.39         # GNU C Library
ARG LINUX_VERSION=6.7.0        # Linux Kernel
ARG MPFR_VERSION=4.2.1         # Multiple Precision Float
ARG GMP_VERSION=6.3.0          # GNU Multiple Precision
ARG MPC_VERSION=1.3.1          # Multiple Precision Complex
```

Renovate automatically tracks these versions and creates PRs when updates are available.

## Key Configuration

### Binutils Configuration

```bash
../configure \
    --prefix=/tools \
    --with-sysroot=/tools \
    --target=${LFS_TGT} \
    --disable-nls \
    --enable-gprofng=no \
    --disable-werror
```

### GCC Configuration (Pass 2)

```bash
../configure \
    --prefix=/tools \
    --with-build-sysroot=/tools \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-languages=c,c++
```

### Glibc Configuration

```bash
../configure \
    --prefix=/tools \
    --host=${LFS_TGT} \
    --enable-kernel=4.19 \
    --with-headers=/tools/include
```

## Output

The final image is built `FROM scratch` and contains:
- `/tools/bin/`: Compiler binaries (gcc, g++, ld, as, etc.)
- `/tools/lib/`: Libraries (libc, libstdc++, etc.)
- `/tools/include/`: System headers
- `/tools/libexec/`: GCC internals

## Verification

After build, verify the toolchain:

```bash
# Check GCC
docker run --rm ghcr.io/hanthor/ichtux/phase1-toolchain:latest \
  /tools/bin/gcc --version

# Compile test program
echo 'int main(){}' > test.c
docker run --rm -v $(pwd):/work ghcr.io/hanthor/ichtux/phase1-toolchain:latest \
  /tools/bin/gcc /work/test.c -o /work/a.out
```

## Disk Space

Phase 1 build requires approximately **8-10 GB** of temporary disk space.

## Build Time

- **GitHub Actions**: ~45-60 minutes (2 vCPU)
- **Local (8 cores)**: ~20-30 minutes
- **Cached rebuild**: ~2-5 minutes

## Troubleshooting

### Build Fails at GCC Pass 1

**Symptom**: `configure: error: C compiler cannot create executables`

**Solution**: Ensure Alpine base image has complete `build-base` package.

### Glibc Build Fails

**Symptom**: Missing kernel headers

**Solution**: Verify Linux headers are properly installed in `/tools/include`.

### Out of Disk Space

**Symptom**: Build fails with "no space left on device"

**Solution**: 
- Run on self-hosted runner with more space
- Or use aggressive cleanup between stages

## Next Phase

Once Phase 1 completes, the toolchain is used in **Phase 2** to build the kernel and base OS.

[Continue to Phase 2: Base OS →](phase2-base.md)
