#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
src="$root"
work="$root/.quark-titlebar-build"
[[ -f $src/Cargo.lock ]] || { printf '未找到源码：%s\n' "$src" >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { printf '此脚本用于构建 x86_64 安装包。\n' >&2; exit 1; }

sdk=org.gnome.Sdk
platform=org.gnome.Platform
rust_ext=org.freedesktop.Sdk.Extension.rust-stable
node_ext=org.freedesktop.Sdk.Extension.node24
for ref in "$sdk//50" "$platform//50" "$rust_ext//25.08" "$node_ext//25.08"; do
    flatpak info "$ref" >/dev/null || { printf '需要安装 %s。\n' "$ref" >&2; exit 1; }
done

mkdir -p "$work/cache"
context=$(mktemp -d "$work/context.XXXXXX")
trap 'rm -rf -- "$context"' EXIT
mkdir -m700 "$context/run"
mkdir -p "$context/tmp"
export XDG_CACHE_HOME="$work/cache" XDG_RUNTIME_DIR="$context/run" TMPDIR="$context/tmp"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

build="$context/build"
flatpak build-init --arch=x86_64 --sdk-extension="$rust_ext" --sdk-extension="$node_ext" \
    "$build" cn.quarkdrive.desktop "$sdk" "$platform" 50
sandbox=(--bind-mount="/run/quark-src=$src" --bind-mount="/run/quark-work=$work")
setup='export PATH=/usr/lib/sdk/rust-stable/bin:/usr/lib/sdk/node24/bin:$PATH
export CARGO_HOME=/run/quark-work/cargo CARGO_TARGET_DIR=/run/quark-work/target
export CARGO_BUILD_JOBS=5 npm_config_cache=/run/quark-work/npm
cd /run/quark-src'

# 仅在下载依赖时联网，使用锁定的依赖版本。
flatpak build --share=network "${sandbox[@]}" "$build" /bin/bash -ec "$setup
(cd apps/desktop && npm ci --no-audit --no-fund)
cargo fetch --locked --target x86_64-unknown-linux-gnu"
flatpak build "${sandbox[@]}" "$build" /bin/bash -ec "$setup
(cd apps/desktop && npm test && npm run build)
cargo build --locked --offline --release -p quark-drive --features custom-protocol"

"$root/build-quark-drive-flatpak.sh" --titlebar "$work/target/release/quark-drive"
