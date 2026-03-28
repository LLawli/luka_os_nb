#!/bin/bash

set -ouex pipefail

### Install packages from repos

dnf5 install -y \
    bat \
    btop \
    eza \
    fd-find \
    fzf \
    jq \
    procs \
    ripgrep \
    tealdeer \
    yq \
    zoxide

### Install tools from GitHub releases
# (not yet available in Fedora repos)

ARCH="x86_64"
INSTALL_DIR="/usr/local/bin"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

gh_latest() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4
}

# delta — git diff viewer
DELTA_VER=$(gh_latest "dandavison/delta")
curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER#v}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/delta-${DELTA_VER#v}-${ARCH}-unknown-linux-musl/delta" "$INSTALL_DIR/delta"

# dust — disk usage (du alternative)
DUST_VER=$(gh_latest "bootandy/dust")
curl -fsSL "https://github.com/bootandy/dust/releases/download/${DUST_VER}/dust-${DUST_VER}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/dust-${DUST_VER}-${ARCH}-unknown-linux-musl/dust" "$INSTALL_DIR/dust"

# ouch — universal archive tool
OUCH_VER=$(gh_latest "ouch-org/ouch")
curl -fsSL "https://github.com/ouch-org/ouch/releases/download/${OUCH_VER}/ouch-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/ouch-${ARCH}-unknown-linux-musl/ouch" "$INSTALL_DIR/ouch"

# sd — sed alternative
SD_VER=$(gh_latest "chmln/sd")
curl -fsSL "https://github.com/chmln/sd/releases/download/${SD_VER}/sd-${SD_VER}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/sd-${SD_VER}-${ARCH}-unknown-linux-musl/sd" "$INSTALL_DIR/sd"

# watchexec — file watcher / task runner
WATCHEXEC_VER=$(gh_latest "watchexec/watchexec")
curl -fsSL "https://github.com/watchexec/watchexec/releases/download/${WATCHEXEC_VER}/watchexec-${WATCHEXEC_VER#v}-${ARCH}-unknown-linux-musl.tar.xz" \
    | tar -xJ -C "$TMPDIR"
install -m755 "$TMPDIR/watchexec-${WATCHEXEC_VER#v}-${ARCH}-unknown-linux-musl/watchexec" "$INSTALL_DIR/watchexec"

# xh — HTTP client (httpie alternative)
XH_VER=$(gh_latest "ducaale/xh")
curl -fsSL "https://github.com/ducaale/xh/releases/download/${XH_VER}/xh-${XH_VER}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/xh-${XH_VER}-${ARCH}-unknown-linux-musl/xh" "$INSTALL_DIR/xh"

# xcp — cp with progress
XCP_VER=$(gh_latest "tarka/xcp")
curl -fsSL "https://github.com/tarka/xcp/releases/download/${XCP_VER}/xcp-${XCP_VER}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/xcp" "$INSTALL_DIR/xcp"

# xsv — CSV toolkit
XSV_VER=$(gh_latest "BurntSushi/xsv")
curl -fsSL "https://github.com/BurntSushi/xsv/releases/download/${XSV_VER}/xsv-${XSV_VER}-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/xsv" "$INSTALL_DIR/xsv"

# zellij — terminal multiplexer
ZELLIJ_VER=$(gh_latest "zellij-org/zellij")
curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VER}/zellij-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/zellij" "$INSTALL_DIR/zellij"

# pipr — interactive shell pipeline builder
PIPR_VER=$(gh_latest "elkowar/pipr")
curl -fsSL "https://github.com/elkowar/pipr/releases/download/${PIPR_VER}/pipr-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/pipr" "$INSTALL_DIR/pipr"

# ripsecrets — secret scanner
RIPSECRETS_VER=$(gh_latest "sirwart/ripsecrets")
curl -fsSL "https://github.com/sirwart/ripsecrets/releases/download/${RIPSECRETS_VER}/ripsecrets-${ARCH}-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$TMPDIR"
install -m755 "$TMPDIR/ripsecrets" "$INSTALL_DIR/ripsecrets"

### Cleanup
dnf5 clean all
