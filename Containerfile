ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG ARCH="${ARCH:-x86_64}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
ARG KERNEL_VERSION="${KERNEL_VERSION:-7.1.5-ogc2.1.fc44.x86_64}"
ARG NVIDIA_FLAVOR="${NVIDIA_FLAVOR:-nvidia-open}"

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-extra
FROM ghcr.io/ublue-os/akmods-${NVIDIA_FLAVOR}:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-nvidia

FROM scratch AS ctx
COPY build_files /

################
# DESKTOP BUILD
################

FROM ghcr.io/ublue-os/aurora:stable AS aether

ARG IMAGE_NAME="${IMAGE_NAME:-aether}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-custom}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG SHA_HEAD_SHORT="${SHA_HEAD_SHORT}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

COPY system_files/shared /
COPY system_files/${BASE_IMAGE_NAME} /

# Install OGC kernel + akmods
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods,src=/rpms/common,dst=/tmp/rpms/common \
    --mount=type=bind,from=akmods,src=/rpms/kmods,dst=/tmp/rpms/kmods \
    --mount=type=bind,from=akmods-extra,src=/rpms/extra,dst=/tmp/rpms/extra \
    --mount=type=bind,from=akmods-extra,src=/rpms/kmods,dst=/tmp/rpms/kmods-extra \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/install-kernel-akmods && \
    /ctx/cleanup

# Setup repos: coprs + terra + negativo17
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/roothome && \
    dnf5 config-manager setopt keepcache=1 && \
    dnf5 -y copr enable ublue-os/bazzite-multilib && \
    dnf5 -y config-manager setopt copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib.priority=98 && \
    dnf5 -y copr enable ublue-os/bazzite && \
    dnf5 -y config-manager setopt copr:copr.fedorainfracloud.org:ublue-os:bazzite.priority=98 && \
    dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release{,-extras,-mesa} && \
    dnf5 -y config-manager setopt "*terra*".priority=1 "*terra*".exclude="nerd-fonts scx-tools scx-scheds python3-protobuf zlib-devel uupd" && \
    dnf5 -y config-manager setopt "terra-mesa".enabled=false && \
    dnf5 -y config-manager setopt "*fedora*".exclude="kernel-core-* kernel-modules-* kernel-uki-virt-*" && \
    /ctx/cleanup

# Install non-free firmware blobs
RUN --mount=type=bind,src=firmware,dst=/ctx/firmware \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    cp -a /ctx/firmware/. /tmp/firmware && \
    find /tmp/firmware -type f -exec setfattr -n user.component -v "aether-nonfree" {} + && \
    rm -rf /tmp/firmware/.git && \
    cp -a /tmp/firmware/. / && \
    rm -rf /tmp/firmware

# Install patched mesa, bluez, Xwayland (gaming swap)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y remove \
        mesa-va-drivers && \
    declare -A toswap=( \
        ["copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib"]="bluez xorg-x11-server-Xwayland" \
        ["copr:copr.fedorainfracloud.org:ublue-os:bazzite"]="wireplumber" \
        ["terra-mesa"]="mesa-filesystem" \
    ) && \
    for repo in "${!toswap[@]}"; do \
        for package in ${toswap[$repo]}; do dnf5 -y swap --from-repo=$repo $package $package; done; \
    done && unset -v toswap repo package && \
    dnf5 versionlock add \
        bluez \
        bluez-cups \
        bluez-libs \
        bluez-obexd \
        xorg-x11-server-Xwayland \
        mesa-dri-drivers \
        mesa-filesystem \
        mesa-libEGL \
        mesa-libGL \
        mesa-libgbm \
        mesa-vulkan-drivers \
        wireplumber \
        wireplumber-libs && \
    dnf5 --enable-repo=terra-mesa -y install \
        mesa-libOpenCL && \
    /ctx/cleanup

# Remove unneeded packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y remove \
        tmux \
        htop \
        nvtop && \
    /ctx/cleanup

# Install base packages + scx-scheds
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y copr enable bieszczaders/kernel-cachyos-addons && \
    dnf5 -y install \
        scx-scheds \
        scx-tools && \
    dnf5 -y copr disable bieszczaders/kernel-cachyos-addons && \
    dnf5 -y install \
        btop \
        duf \
        fastfetch \
        fish \
        iwd \
        ddcutil \
        input-remapper \
        libinput-utils \
        i2c-tools \
        lm_sensors \
        iio-sensor-proxy \
        xdotool \
        wmctrl \
        libcec \
        linuxconsoletools \
        v4l-utils \
        yad \
        lzip \
        libxcrypt-compat \
        vulkan-tools \
        vulkan-low-latency-layer \
        libadwaita \
        qt \
        lshw \
        pipewire-module-filter-chain-sofa \
        plasma-oxygen \
        unrar \
        fuse-libs \
        gum \
        xwininfo \
        python3-icoextract \
        qalculate-qt && \
    /ctx/cleanup

# Install Steam + Faugus Launcher + gaming packages
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    dnf5 -y swap libfdk-aac fdk-aac-free && \
    dnf5 --enable-repo=terra --enable-repo=terra-mesa -y --setopt=install_weak_deps=False install \
        terra-gamescope.x86_64 \
        terra-gamescope-libs.x86_64 \
        terra-gamescope-libs.i686 \
        umu-launcher \
        umu-wrapper \
        libFAudio.x86_64 \
        libFAudio.i686 \
        vkBasalt.x86_64 \
        vkBasalt.i686 \
        mangohud.x86_64 \
        mangohud.i686 \
        openxr \
        steam \
        faugus-launcher \
        protonplus \
        obs-studio-plugin-vkcapture.x86_64 \
        obs-studio-plugin-vkcapture-hook-libs.x86_64 \
        obs-studio-plugin-vkcapture-hook-libs.i686 && \
    /ctx/ghcurl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks && \
    setfattr -n user.component -v "winetricks" /usr/bin/winetricks && \
    setfattr -n user.component -v "steam" /usr/share/applications/steam.desktop && \
    /ctx/cleanup

# Install ujust-picker from GitHub releases (optional, non-fatal)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    ( /ctx/ghcurl "$(/ctx/ghcurl "https://api.github.com/repos/ublue-os/bazzite-ujust-picker/releases/latest" -s | jq -r '.assets[] | select(.name | test("x86_64$")) | .browser_download_url')" -sL -o /usr/bin/ujust-picker 2>/dev/null && \
      chmod +x /usr/bin/ujust-picker && \
      setfattr -n user.component -v "ujust-picker" /usr/bin/ujust-picker \
    ) || true && \
    /ctx/cleanup

# Configure KDE desktop
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 -y install \
        kdeconnectd \
        kdeplasma-addons \
        kgamma \
        oxygen-icon-theme && \
    dnf5 -y install --enable-repo=copr:copr.fedorainfracloud.org:ublue-os:packages \
        ublue-os-media-automount-udev && \
    systemctl enable ublue-os-media-automount.service 2>/dev/null || true && \
    cp --no-dereference --preserve=links /usr/lib64/libdrm.so.2 /usr/lib64/libdrm.so && \
    cp --no-dereference --preserve=links /usr/lib/libdrm.so.2 /usr/lib/libdrm.so && \
    sed -i 's@/usr/bin/steam@/usr/bin/steam@g' /usr/share/applications/steam.desktop && \
    mkdir -p /etc/skel/.config/autostart/ && \
    cp "/usr/share/applications/steam.desktop" "/etc/skel/.config/autostart/steam.desktop" && \
    sed -i 's@/usr/bin/steam %U@/usr/bin/steam -silent %U@g' /etc/skel/.config/autostart/steam.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/nvtop.desktop 2>/dev/null || true && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/btop.desktop && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/yad-icon-browser.desktop && \
    sed -i 's/#UserspaceHID.*/UserspaceHID=true/' /etc/bluetooth/input.conf && \
    rm -f /usr/lib/systemd/system/service.d/50-keep-warm.conf && \
    rm -f /etc/profile.d/toolbox.sh && \
    mkdir -p /var/tmp && chmod 1777 /var/tmp && \
    /ctx/cleanup

# Cleanup & finalize
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/image-info && \
    /ctx/build-initramfs && \
    /ctx/finalize

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

################
# NVIDIA BUILD
################

FROM aether AS aether-nvidia

ARG IMAGE_NAME="${IMAGE_NAME:-aether-nvidia}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-custom}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-kinoite}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

# Fetch NVIDIA driver + system files
COPY system_files/nvidia/shared /

# Remove packages that conflict with NVIDIA
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 config-manager unsetopt skip_if_unavailable && \
    dnf5 -y remove \
        nvidia-gpu-firmware 2>/dev/null || true && \
    /ctx/cleanup

# Install NVIDIA driver
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/rpms/nvidia \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=GITHUB_TOKEN \
    dnf5 config-manager setopt "terra-mesa".enabled=1 && \
    dnf5 -y copr enable ublue-os/staging && \
    dnf5 -y install \
        egl-wayland.x86_64 \
        egl-wayland.i686 \
        egl-wayland2.x86_64 \
        egl-wayland2.i686 && \
    IMAGE_NAME="${BASE_IMAGE_NAME}" AKMODNV_PATH="/tmp/rpms/nvidia" MULTILIB=1 /tmp/rpms/nvidia/ublue-os/nvidia-install.sh && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
    dnf5 config-manager setopt "terra-mesa".enabled=0 && \
    dnf5 -y copr disable ublue-os/staging && \
    /ctx/cleanup

# Cleanup & finalize (NVIDIA)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    systemctl disable supergfxd.service 2>/dev/null || true && \
    dnf5 config-manager setopt skip_if_unavailable=1 && \
    if [ -f /etc/modprobe.d/nvidia-modeset.conf ]; then \
      cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf \
    ; fi && \
    /ctx/image-info && \
    /ctx/build-initramfs && \
    /ctx/finalize

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint
