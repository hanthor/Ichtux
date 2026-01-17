#!/usr/bin/env bash
#
# Ichtux Build Script
# Builds all phases of the Ichtux Linux distribution locally
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY=${REGISTRY:-"localhost"}
TAG=${TAG:-"latest"}
CACHE_DIR=${CACHE_DIR:-"/tmp/ichtux-cache"}
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}

# Image names
PHASE1_IMAGE="${REGISTRY}/ichtux/phase1-toolchain:${TAG}"
PHASE2_IMAGE="${REGISTRY}/ichtux/phase2-base:${TAG}"
PHASE3_IMAGE="${REGISTRY}/ichtux/phase3-graphical:${TAG}"
PHASE4_IMAGE="${REGISTRY}/ichtux/final:${TAG}"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx is not available"
        exit 1
    fi
    
    # Check disk space (need at least 50GB)
    available_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$available_space" -lt 50 ]; then
        log_warning "Low disk space: ${available_space}GB available (50GB recommended)"
    fi
    
    log_success "Requirements check passed"
}

create_builder() {
    log_info "Setting up Docker Buildx builder..."
    
    if ! docker buildx inspect ichtux-builder &> /dev/null; then
        docker buildx create --name ichtux-builder --driver docker-container --use
        log_success "Created ichtux-builder"
    else
        docker buildx use ichtux-builder
        log_info "Using existing ichtux-builder"
    fi
}

build_phase1() {
    log_info "========================================="
    log_info "Building Phase 1: Bootstrap Toolchain"
    log_info "========================================="
    log_info "This builds GCC, Glibc, and all tools from source"
    log_info "Estimated time: 45-60 minutes"
    log_info ""
    
    docker buildx build \
        --file containerfiles/phase1-toolchain/Containerfile \
        --tag "${PHASE1_IMAGE}" \
        --target toolchain \
        --cache-from type=local,src="${CACHE_DIR}/phase1" \
        --cache-to type=local,dest="${CACHE_DIR}/phase1",mode=max \
        --build-arg MAKEFLAGS="-j${PARALLEL_JOBS}" \
        --progress=plain \
        --load \
        .
    
    log_success "Phase 1 complete: ${PHASE1_IMAGE}"
    
    # Verify
    log_info "Verifying Phase 1..."
    docker run --rm "${PHASE1_IMAGE}" /tools/bin/gcc --version
    docker run --rm "${PHASE1_IMAGE}" /tools/bin/bash --version
}

build_phase2() {
    log_info "========================================="
    log_info "Building Phase 2: Base OS"
    log_info "========================================="
    log_info "This builds Linux kernel and base system"
    log_info "Estimated time: 30-40 minutes"
    log_info ""
    
    docker buildx build \
        --file containerfiles/phase2-base/Containerfile \
        --tag "${PHASE2_IMAGE}" \
        --target base-os \
        --build-arg PHASE1_IMAGE="${PHASE1_IMAGE}" \
        --build-arg MAKEFLAGS="-j${PARALLEL_JOBS}" \
        --cache-from type=local,src="${CACHE_DIR}/phase2" \
        --cache-to type=local,dest="${CACHE_DIR}/phase2",mode=max \
        --progress=plain \
        --load \
        .
    
    log_success "Phase 2 complete: ${PHASE2_IMAGE}"
    
    # Verify
    log_info "Verifying Phase 2..."
    docker run --rm "${PHASE2_IMAGE}" ls -lh /boot/vmlinuz* || log_warning "Kernel verification failed"
}

build_phase3() {
    log_info "========================================="
    log_info "Building Phase 3: Graphical Stack"
    log_info "========================================="
    log_info "This builds Mesa, Wayland, and GNOME"
    log_info "Estimated time: 20-30 minutes"
    log_info ""
    
    docker buildx build \
        --file containerfiles/phase3-graphical/Containerfile \
        --tag "${PHASE3_IMAGE}" \
        --target graphical-stack \
        --build-arg PHASE1_IMAGE="${PHASE1_IMAGE}" \
        --cache-from type=local,src="${CACHE_DIR}/phase3" \
        --cache-to type=local,dest="${CACHE_DIR}/phase3",mode=max \
        --progress=plain \
        --load \
        .
    
    log_success "Phase 3 complete: ${PHASE3_IMAGE}"
}

build_phase4() {
    log_info "========================================="
    log_info "Building Phase 4: Final Assembly"
    log_info "========================================="
    log_info "This creates the bootc-compatible final image"
    log_info "Estimated time: 15-20 minutes"
    log_info ""
    
    docker buildx build \
        --file containerfiles/phase4-assembly/Containerfile \
        --tag "${PHASE4_IMAGE}" \
        --target final \
        --cache-from type=local,src="${CACHE_DIR}/phase4" \
        --cache-to type=local,dest="${CACHE_DIR}/phase4",mode=max \
        --progress=plain \
        --load \
        .
    
    log_success "Phase 4 complete: ${PHASE4_IMAGE}"
    
    # Verify bootc compatibility
    log_info "Verifying bootc compatibility..."
    BOOTC_COMPAT=$(docker inspect "${PHASE4_IMAGE}" | jq -r '.[0].Config.Labels."bootc.compatible"')
    if [ "$BOOTC_COMPAT" = "true" ]; then
        log_success "Image is bootc-compatible"
    else
        log_error "Image is NOT bootc-compatible"
    fi
}

show_summary() {
    echo ""
    log_info "========================================="
    log_info "Build Summary"
    log_info "========================================="
    echo ""
    echo "Phase 1 (Toolchain):     ${PHASE1_IMAGE}"
    echo "Phase 2 (Base OS):       ${PHASE2_IMAGE}"
    echo "Phase 3 (Graphical):     ${PHASE3_IMAGE}"
    echo "Phase 4 (Final):         ${PHASE4_IMAGE}"
    echo ""
    log_info "Next steps:"
    echo "  1. Run the image: docker run --rm -it ${PHASE4_IMAGE} /bin/bash"
    echo "  2. Generate ISO:  sudo podman run --rm --privileged \\"
    echo "                      -v /var/lib/containers/storage:/var/lib/containers/storage \\"
    echo "                      -v ./output:/output \\"
    echo "                      quay.io/centos-bootc/bootc-image-builder:latest \\"
    echo "                      --type iso docker://${PHASE4_IMAGE}"
    echo ""
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [PHASE]

Build Ichtux Linux distribution locally

PHASES:
    phase1      Build Phase 1: Bootstrap Toolchain only
    phase2      Build Phase 2: Base OS only (requires Phase 1)
    phase3      Build Phase 3: Graphical Stack only (requires Phase 1)
    phase4      Build Phase 4: Final Assembly only
    all         Build all phases (default)

OPTIONS:
    -h, --help          Show this help message
    -t, --tag TAG       Tag for images (default: latest)
    -r, --registry REG  Registry prefix (default: localhost)
    -j, --jobs NUM      Parallel jobs for make (default: $(nproc))
    --no-cache          Disable build cache
    --clean             Clean build cache before building

EXAMPLES:
    # Build everything
    $0

    # Build only Phase 1 with custom tag
    $0 --tag dev phase1

    # Build with 4 parallel jobs
    $0 --jobs 4

    # Clean build without cache
    $0 --clean --no-cache

ENVIRONMENT VARIABLES:
    REGISTRY            Docker registry prefix (default: localhost)
    TAG                 Image tag (default: latest)
    CACHE_DIR           Build cache directory (default: /tmp/ichtux-cache)
    PARALLEL_JOBS       Number of parallel make jobs (default: $(nproc))

EOF
}

clean_cache() {
    log_info "Cleaning build cache..."
    if [ -d "${CACHE_DIR}" ]; then
        rm -rf "${CACHE_DIR}"
        log_success "Cache cleaned: ${CACHE_DIR}"
    else
        log_info "No cache to clean"
    fi
}

# Parse arguments
USE_CACHE=true
PHASE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --no-cache)
            USE_CACHE=false
            shift
            ;;
        --clean)
            clean_cache
            shift
            ;;
        phase1|phase2|phase3|phase4|all)
            PHASE="$1"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Ichtux Build Script"
    log_info "Registry: ${REGISTRY}"
    log_info "Tag: ${TAG}"
    log_info "Parallel jobs: ${PARALLEL_JOBS}"
    log_info "Cache directory: ${CACHE_DIR}"
    echo ""
    
    check_requirements
    create_builder
    
    mkdir -p "${CACHE_DIR}"
    
    START_TIME=$(date +%s)
    
    case $PHASE in
        phase1)
            build_phase1
            ;;
        phase2)
            build_phase2
            ;;
        phase3)
            build_phase3
            ;;
        phase4)
            build_phase4
            ;;
        all)
            build_phase1
            build_phase2
            build_phase3
            build_phase4
            ;;
    esac
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    
    echo ""
    log_success "Build completed in ${HOURS}h ${MINUTES}m"
    
    show_summary
}

main
