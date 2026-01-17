# Contributing to Ichtux Linux

Thank you for your interest in contributing to Ichtux! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Testing](#testing)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

**Be respectful, inclusive, and constructive.**

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When you create a bug report, include:

- **Clear title** and description
- **Steps to reproduce** the problem
- **Expected behavior** vs **actual behavior**
- **Environment details** (OS, Docker version, etc.)
- **Build logs** if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title** and description
- **Use case** - why is this enhancement useful?
- **Proposed solution** if you have one
- **Alternatives considered**

### Contributing Code

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Test your changes** thoroughly
5. **Commit with clear messages**
6. **Push to your fork**
7. **Open a Pull Request**

## Development Setup

### Prerequisites

- Linux system (Ubuntu 22.04+ or Fedora 39+ recommended)
- Docker 24.0+ with Buildx
- Git 2.30+
- 50GB+ free disk space
- 8GB+ RAM

### Local Build Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/Ichtux.git
cd Ichtux

# Add upstream remote
git remote add upstream https://github.com/hanthor/Ichtux.git

# Create a branch
git checkout -b feature/my-feature

# Build locally
./scripts/build-local.sh
```

See [Building Locally](docs/building-locally.md) for detailed instructions.

## Pull Request Process

### Before Submitting

1. **Test your changes** - ensure all phases build successfully
2. **Update documentation** - if you change functionality
3. **Check formatting** - Containerfiles should be well-formatted
4. **Verify labels** - ensure OCI labels are correct
5. **Test with GitHub Actions** - push to your fork and verify CI passes

### PR Checklist

- [ ] Code builds without errors
- [ ] Documentation updated
- [ ] Commit messages follow conventions
- [ ] No unnecessary files included
- [ ] PR description explains what and why
- [ ] Related issue referenced (if applicable)

### PR Title Format

```
<type>(<scope>): <short summary>

Examples:
feat(phase1): add support for ARM64 architecture
fix(phase2): correct kernel config for bootc
docs: update README with new badges
chore(ci): improve caching strategy
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintain, CI/CD, dependencies

Scopes:
- `phase1`: Bootstrap toolchain
- `phase2`: Base OS
- `phase3`: Graphical stack
- `phase4`: Final assembly
- `ci`: GitHub Actions
- `docs`: Documentation

### Review Process

1. Maintainers will review your PR
2. Address any feedback
3. Once approved, a maintainer will merge

## Coding Standards

### Containerfile Style

```dockerfile
# Comments explaining what this stage does
FROM base:tag AS stage-name

# Group related RUN commands
RUN command1 && \
    command2 && \
    command3

# Use ARG for versions (Renovate-managed)
ARG PACKAGE_VERSION=1.2.3

# Clear ENV documentation
ENV PATH=/tools/bin:$PATH \
    LC_ALL=POSIX

# Descriptive labels
LABEL org.opencontainers.image.title="Clear Title"
LABEL org.opencontainers.image.description="Clear description"
```

### Shell Script Style

```bash
#!/usr/bin/env bash

# Use strict mode
set -euo pipefail

# Document functions
# Description of what function does
# Arguments:
#   $1 - first argument description
function_name() {
    local var="$1"
    # implementation
}

# Use meaningful variable names
DESCRIPTIVE_NAME="value"

# Check exit codes
if command; then
    # success
else
    # failure
fi
```

### Documentation Style

- Use **Markdown** for all documentation
- Include **code examples** where appropriate
- Keep **line length** under 100 characters where reasonable
- Use **semantic line breaks** (one sentence per line in source)
- Include **links** to related documentation

## Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Examples

```
feat(phase1): add ccache support for faster rebuilds

Implements ccache in the toolchain build to cache compilation
results, reducing rebuild times by up to 70%.

Closes #123
```

```
fix(phase2): kernel fails to boot on some hardware

- Enable CONFIG_ACPI_BUTTON
- Add CONFIG_INPUT_EVDEV=y
- Include virtio drivers by default

Fixes #456
```

### Guidelines

- Use imperative mood ("add feature" not "added feature")
- First line under 50 characters
- Body wraps at 72 characters
- Explain **what** and **why**, not **how**
- Reference issues and PRs

## Testing

### Manual Testing

Before submitting a PR:

```bash
# Build all phases
./scripts/build-local.sh

# Test Phase 1
docker run --rm ichtux/phase1-toolchain:latest /tools/bin/gcc --version

# Test Phase 4 (final image)
docker run --rm -it ichtux/final:latest /bin/bash
```

### CI Testing

GitHub Actions will automatically:
- Build all phases
- Run compatibility tests
- Generate SBOMs
- Check bootc compatibility

Monitor your PR's CI runs and fix any failures.

### Test Checklist

- [ ] Phase 1 builds successfully
- [ ] Phase 2 builds successfully
- [ ] Phase 3 builds successfully
- [ ] Phase 4 builds successfully
- [ ] GCC version check passes
- [ ] Kernel is present in Phase 2
- [ ] Bootc compatibility label exists
- [ ] No new security vulnerabilities
- [ ] Documentation builds without errors

## Version Management

### Renovate

We use Renovate to automatically track and update dependencies. When adding new components:

1. Add ARG with version in Containerfile
2. Add regex manager in `renovate.json`
3. Test that Renovate detects it

Example:
```json
{
  "matchStrings": [
    "ARG NEW_PACKAGE_VERSION=(?<currentValue>.*?)\\n"
  ],
  "depNameTemplate": "package-name",
  "datasourceTemplate": "github-releases"
}
```

## Areas Needing Help

We especially welcome contributions in these areas:

- **ARM64 support** - Adapt build for ARM architecture
- **Additional architectures** - RISC-V, PowerPC, etc.
- **Performance optimizations** - Reduce build times
- **Documentation** - Tutorials, guides, translations
- **Testing** - Automated tests, CI improvements
- **Security** - Vulnerability scanning, hardening

## Questions?

- Open a [Discussion](https://github.com/hanthor/Ichtux/discussions)
- Join our community chat (TBD)
- Email maintainers (see README)

## License

By contributing, you agree that your contributions will be licensed under the project's GPL-3.0 License.

---

**Thank you for contributing to Ichtux!** 🎉
