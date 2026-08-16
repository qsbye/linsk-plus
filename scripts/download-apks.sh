#!/bin/bash
# 下载 Alpine APK 包及其依赖到 assets/files/apks/
# 需要在 Alpine Linux 容器或 Alpine 系统中运行

set -e

ARCH="${ARCH:-aarch64}"
ALPINE_VERSION="${ALPINE_VERSION:-3.20}"
APK_DIR="assets/files/apks/${ALPINE_VERSION}/${ARCH}"

mkdir -p "$APK_DIR"

echo "Downloading APK packages for Alpine ${ALPINE_VERSION} ${ARCH}..."

# 更新 APK 索引
apk update

# 下载所需包及其依赖到本地目录
# 这些包是 linsk VM 构建时需要的
PACKAGES="
    alpine-base
    openssh
    openssh-server
    lvm2
    util-linux
    cryptsetup
    vsftpd
    samba
    samba-common
    samba-server
    netatalk
"

for pkg in $PACKAGES; do
    echo "Fetching $pkg..."
    apk fetch --recursive --output "$APK_DIR" "$pkg" || true
done

# 复制 APK 索引文件（如果存在）
if [ -f /var/cache/apk/APKINDEX.${ALPINE_VERSION}.tar.gz ]; then
    cp /var/cache/apk/APKINDEX.${ALPINE_VERSION}.tar.gz "$APK_DIR/"
fi

# 创建本地仓库索引
cd "$APK_DIR"
apk index -o APKINDEX.tar.gz *.apk 2>/dev/null || true

# 统计下载的包数量
APK_COUNT=$(ls -1 "$APK_DIR"/*.apk 2>/dev/null | wc -l)
echo "Downloaded ${APK_COUNT} APK packages to ${APK_DIR}"
