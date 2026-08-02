export project_root := `git rev-parse --show-toplevel`
kernver := `skopeo list-tags docker://ghcr.io/ublue-os/akmods 2>/dev/null | jq -r '.Tags[]' 2>/dev/null | grep 'ogc-44-.*x86_64' | sort -V | tail -1 | sed 's/ogc-44-//' || echo "7.1.5-ogc2.1.fc44.x86_64"`

_default:
    @just --list

image_name:
    @echo "aether"

generate-default-tag:
    @date +%Y%m%d

# Build desktop image
build image_name="aether" tag="":
    @#!/usr/bin/bash
    tag="${tag:-$(date +%Y%m%d)}"
    buildah build \
        --target "{{ image_name }}" \
        --build-arg IMAGE_NAME="{{ image_name }}" \
        --build-arg FEDORA_VERSION=44 \
        --build-arg KERNEL_FLAVOR=ogc \
        --build-arg KERNEL_VERSION="{{ kernver }}" \
        --build-arg VERSION_TAG="${tag}" \
        --build-arg VERSION_PRETTY="$(date +%Y.%m.%d)" \
        --tag "{{ image_name }}:${tag}" \
        --tag "{{ image_name }}:latest" \
        -f Containerfile .

# Build NVIDIA image
build-nvidia image_name="aether-nvidia" tag="":
    @#!/usr/bin/bash
    tag="${tag:-$(date +%Y%m%d)}"
    buildah build \
        --target "{{ image_name }}" \
        --build-arg IMAGE_NAME="{{ image_name }}" \
        --build-arg FEDORA_VERSION=44 \
        --build-arg KERNEL_FLAVOR=ogc \
        --build-arg KERNEL_VERSION="{{ kernver }}" \
        --build-arg VERSION_TAG="${tag}" \
        --build-arg VERSION_PRETTY="$(date +%Y.%m.%d)" \
        --tag "{{ image_name }}:${tag}" \
        --tag "{{ image_name }}:latest" \
        -f Containerfile .

# Build all images
build-all tag="":
    @#!/usr/bin/bash
    tag="${tag:-$(date +%Y%m%d)}"
    just build aether "${tag}"
    just build-nvidia aether-nvidia "${tag}"

# Run smoke test in container
smoke-test image_name="aether" tag="latest":
    @#!/usr/bin/bash
    podman run --rm "{{ image_name }}:{{ tag }}" sh -exc '
        echo "=== OS Release ===" && head -5 /usr/lib/os-release
        echo "=== Kernel ===" && rpm -q kernel
        echo "=== Key packages ===" && rpm -q steam faugus-launcher mangohud
        echo "=== Ujust ===" && ujust --list | head -10
    '

# Clean images
clean-images:
    @buildah images aether --format '{{.ID}}' | xargs -r buildah rmi || true
    @buildah images aether-nvidia --format '{{.ID}}' | xargs -r buildah rmi || true
