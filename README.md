# Aether

KDE desktop gaming image built on [Aurora](https://github.com/ublue-os/aurora) with:

- **OGC kernel** (optimized gaming kernel from ublue-os)
- **NVIDIA support** (nvidia-open driver, as a separate image flavor)
- **Gaming runtime**: Steam, Faugus Launcher, MangoHud, vkBasalt, Gamescope, Winetricks
- **Valve-patched Mesa**, Bluez, and Xwayland
- **SCX schedulers** (sched-ext userspace for OGC kernel)
- **Bazzite ujust recipes** (gaming tweaks, maintenance, diagnostics)
- **Non-free firmware**

## Flavors

| Image | Description |
|-------|-------------|
| `aether:latest` | KDE desktop gaming |
| `aether-nvidia:latest` | Same + NVIDIA open driver |

## Usage

Rebase from any Fedora Atomic image:

```bash
# Desktop
rpm-ostree rebase ostree-unverified-registry:ghcr.io/stepharmony/aether:latest

# NVIDIA
rpm-ostree rebase ostree-unverified-registry:ghcr.io/stepharmony/aether-nvidia:latest
```

Rollback: `rpm-ostree rollback`

## Build

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/stepharmony/aether.git

# Build desktop image
just build aether

# Build NVIDIA image
just build-nvidia aether-nvidia
```

## Local testing

```bash
just smoke-test aether
```

## CI

GitHub Actions builds both flavors daily. Set these secrets:

- `GITHUB_TOKEN` — auto-provided, needs `packages: write`
- `SIGNING_SECRET` — cosign private key for image signing (optional)

## Credits

Built on [ublue-os/image-template](https://github.com/ublue-os/image-template). Gaming components borrowed from [Bazzite](https://github.com/ublue-os/bazzite). Base image by [Aurora](https://github.com/ublue-os/aurora).
