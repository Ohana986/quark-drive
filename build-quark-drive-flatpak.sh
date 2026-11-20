#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
output="$root/dist/flatpak"
app_id=cn.quarkdrive.desktop
version=0.2.0
arch=x86_64
branch=stable
runtime=org.gnome.Platform
runtime_branch=50
sdk=org.gnome.Sdk
upstream=https://github.com/xingzhe11011/quark-drive
bundle_name="QuarkDrive-${version}-${arch}.flatpak"
deb_name="QuarkDrive_${version}_amd64.deb"
deb_sha256=58641aaff346d5707332700eb9b2cf87dc4c7dffc34b82f179f5edced318c7f9
license_sha256=5334ca64b209347d5553d409c80fd2adbfed76ddbd76918fe1189bb42f4c632b

tools=(flatpak sha256sum)
if [[ $# -eq 2 && $1 == --titlebar ]]; then
    binary=$(realpath -e -- "$2")
    source="$root"
    [[ -x $binary && -f $source/LICENSE ]] || { printf '未找到编译产物或源码目录。\n' >&2; exit 1; }
    bundle_name="QuarkDrive-${version}-titlebar-${arch}.flatpak"
    description='<p>This local build integrates the window controls and drag area into the application toolbar.</p>'
    description_zh='<p xml:lang="zh-CN">此本地构建将窗口控制按钮和拖动区域合并到应用工具栏中。</p>'
elif [[ $# -eq 0 ]]; then
    tools+=(curl ar tar)
    description=
    description_zh=
else
    printf '用法：%s [--titlebar 已编译的二进制文件]\n' "$0" >&2
    exit 2
fi

for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null || { printf '缺少命令：%s\n' "$tool" >&2; exit 1; }
done
if [[ $(uname -m) != "$arch" ]]; then
    printf '此脚本用于打包 x86_64 二进制，请在 x86_64 Linux 上运行。\n' >&2
    exit 1
fi
if ! flatpak info --arch="$arch" "$runtime//$runtime_branch" >/dev/null 2>&1; then
    printf '请先安装运行时：flatpak install --user flathub %s//%s\n' "$runtime" "$runtime_branch" >&2
    exit 1
fi

workdir=$(mktemp -d "$root/.quark-flatpak-build.XXXXXX")
trap 'rm -rf -- "$workdir"' EXIT
mkdir -p "$workdir/cache" "$workdir/tmp" "$workdir/payload"
mkdir -m700 "$workdir/run"
export XDG_CACHE_HOME="$workdir/cache" TMPDIR="$workdir/tmp" XDG_RUNTIME_DIR="$workdir/run"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
cd -- "$workdir"

declare -a icons
if [[ -v binary ]]; then
    license="$source/LICENSE"
    icons=("$source/apps/desktop/src-tauri/icons/"{32x32,128x128,128x128@2x}.png)
else
    curl --fail --location --silent --show-error --retry 2 --max-time 120 \
        "$upstream/releases/download/v$version/$deb_name" -o "$deb_name"
    curl --fail --location --silent --show-error --retry 2 --max-time 30 \
        "https://raw.githubusercontent.com/xingzhe11011/quark-drive/v$version/LICENSE" -o LICENSE
    printf '%s  %s\n' "$deb_sha256" "$deb_name" | sha256sum --check --strict
    ar x "$deb_name"
    tar -xf data.tar.* -C payload
    binary=payload/usr/bin/quark-drive
    license=LICENSE
    icons=(payload/usr/share/icons/hicolor/{32x32,128x128,256x256@2}/apps/quark-drive.png)
fi
printf '%s  %s\n' "$license_sha256" "$license" | sha256sum --check --strict

build="$workdir/build"
# 仅重新封装已编译的文件，无需安装完整的 GNOME SDK。
flatpak build-init --arch="$arch" "$build" "$app_id" "$runtime" "$runtime" "$runtime_branch"
files="$build/files"
install -Dm755 "$binary" "$files/bin/quark-drive"
install -Dm644 "$license" "$files/share/licenses/$app_id/LICENSE"
sizes=(32x32 128x128 128x128@2)
for i in "${!sizes[@]}"; do
    install -Dm644 "${icons[i]}" "$files/share/icons/hicolor/${sizes[i]}/apps/$app_id.png"
done

mkdir -p "$files/share/applications" "$files/share/metainfo"
desktop="$files/share/applications/$app_id.desktop"
metainfo="$files/share/metainfo/$app_id.metainfo.xml"
cat > "$desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=QuarkDrive
Name[zh_CN]=夸克网盘（非官方）
Comment=Unofficial Linux client for Quark cloud storage
Comment[zh_CN]=非官方夸克网盘 Linux 客户端
Exec=quark-drive
Icon=cn.quarkdrive.desktop
StartupWMClass=quark-drive
Categories=Network;FileTransfer;
Terminal=false
DESKTOP
cat > "$metainfo" <<METAINFO
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>cn.quarkdrive.desktop</id>
  <name>QuarkDrive</name>
  <summary>Unofficial Linux client for Quark cloud storage</summary>
  <summary xml:lang="zh-CN">非官方夸克网盘 Linux 客户端</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <developer id="io.github.xingzhe11011">
    <name>QuarkDrive contributors</name>
  </developer>
  <description>
    <p>Browse, upload, and download files in your Quark cloud storage account. The client supports QR code sign-in and persistent transfer queues.</p>
    <p xml:lang="zh-CN">支持扫码登录、文件浏览、上传、下载和断点续传。此客户端与夸克官方无关联。</p>
    $description
    $description_zh
  </description>
  <launchable type="desktop-id">cn.quarkdrive.desktop.desktop</launchable>
  <url type="homepage">https://github.com/xingzhe11011/quark-drive</url>
  <url type="bugtracker">https://github.com/xingzhe11011/quark-drive/issues</url>
  <releases>
    <release version="0.2.0" date="2026-11-12"/>
  </releases>
  <content_rating type="oars-1.1" />
</component>
METAINFO

if command -v desktop-file-validate >/dev/null; then
    desktop-file-validate "$desktop"
fi
if command -v appstreamcli >/dev/null; then
    appstreamcli validate --no-net "$metainfo"
fi

# 让运行时的动态链接器检查依赖，不启动应用或访问网盘。
if ! flatpak build --runtime --readonly "$build" /lib64/ld-linux-x86-64.so.2 \
    --list /app/bin/quark-drive > dependencies.log 2>&1; then
    printf '%s\n' "$(<dependencies.log)" >&2
    exit 1
fi
flatpak build-finish --command=quark-drive --sdk="$sdk/$arch/$runtime_branch" \
    --no-inherit-permissions --share=network --share=ipc --socket=wayland \
    --socket=fallback-x11 --device=dri --filesystem=xdg-download "$build"
flatpak build-export --arch="$arch" "$workdir/repo" "$build" "$branch"
flatpak build-bundle --arch="$arch" --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
    "$workdir/repo" "$workdir/$bundle_name" "$app_id" "$branch"
# 在临时用户仓库试装；不修改正常的 Flatpak 安装，也不拉取依赖。
(
    export FLATPAK_USER_DIR="$workdir/verify-install"
    export XDG_DATA_HOME="$workdir/verify-data" XDG_CONFIG_HOME="$workdir/verify-config"
    flatpak install --user --noninteractive --assumeyes --no-deps --no-related \
        --bundle "$workdir/$bundle_name"
    flatpak info --user --show-ref --show-runtime --show-permissions "$app_id" "$branch"
)

sha256sum "$bundle_name" > "$bundle_name.sha256"
mkdir -p "$output"
mv -- "$bundle_name" "$bundle_name.sha256" "$output/"
printf '\n安装包：%s/%s\n' "$output" "$bundle_name"
