# Linsk 离线编译与 LVM/ext4 测试指南

## 一、离线编译

### 1.1 准备资源文件

编译前需将以下文件下载到 `assets/files/` 目录：

```bash
# x86_64 Alpine ISO (约 49MB)
wget https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.3-x86_64.iso \
  -O assets/files/alpine-virt-3.20.3-x86_64.iso

# aarch64 Alpine ISO (约 69MB)
wget https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/aarch64/alpine-virt-3.20.3-aarch64.iso \
  -O assets/files/alpine-virt-3.20.3-aarch64.iso

# aarch64 EFI BIOS (约 64MB，需先解压)
wget https://github.com/qemu/qemu/raw/92ec7805190313c9e628f8fc4eb4f932c15247bd/pc-bios/edk2-aarch64-code.fd.bz2
bunzip2 edk2-aarch64-code.fd.bz2
mv edk2-aarch64-code.fd assets/files/
```

### 1.2 编译

```bash
go build -o linsk .
```

编译后二进制约 145MB（含嵌入资源），可在完全离线的机器运行。

---

## 二、构建 VM 镜像

首次运行前必须先构建 VM 镜像。此步骤需要 root 权限。

```bash
sudo ./linsk build
```

如果之前构建失败有残留，使用 `--overwrite` 覆盖：

```bash
sudo ./linsk build --overwrite
```

构建过程会从嵌入资源中提取 Alpine ISO 和 EFI 文件，然后在 QEMU 中安装 Alpine Linux 系统。首次构建约需 1-2 分钟。

---

## 三、LVM + ext4 测试（以 `/Volumes/QSANDISK` 为例）

### 3.1 确认磁盘设备

```bash
diskutil list /Volumes/QSANDISK
```

示例输出：
```
/dev/disk4 (external, physical):
   0:     FDisk_partition_scheme                        *30.8 GB    disk4
   1:             Windows_FAT_32 QSANDISK                30.8 GB    disk4s1
```

磁盘设备为 `/dev/disk4`。

### 3.2 卸载磁盘

```bash
sudo diskutil unmountDisk /dev/disk4
```

### 3.3 启动 Linsk Shell

透传参数为位置参数（非 flag）：

```bash
sudo ./linsk shell "dev:/dev/disk4"
```

### 3.4 在 VM 中创建 LVM + ext4

```bash
# 查看磁盘（透传的磁盘通常是 /dev/vdb）
lsblk

# 如果磁盘有旧分区，先清除分区表
wipefs -a /dev/vdb

# 创建物理卷
pvcreate /dev/vdb

# 创建卷组
vgcreate testvg /dev/vdb

# 创建逻辑卷（使用全部空间）
lvcreate -L 28G -n testlv testvg

# 创建 ext4 文件系统
mkfs.ext4 /dev/testvg/testlv

# 验证
lvs
vgs
lsblk
```

### 3.5 退出 Shell

输入 `exit` 或按 `Ctrl+D`。

---

## 四、通过 FTP 访问 LVM 上的 ext4

### 4.1 启动 FTP 共享

**注意**：`linsk run` 默认挂载整个透传设备。如果设备上有 LVM，需要指定逻辑卷设备名作为第二个参数。LVM 逻辑卷在 VM 中的路径为 `/dev/mapper/testvg-testlv`，但 linsk 只接受设备名（不含 `/dev/` 前缀），所以使用 `mapper/testvg-testlv`：

```bash
sudo ./linsk run --share-backend ftp "dev:/dev/disk4" mapper/testvg-testlv
```

**注意**：`linsk run` 默认挂载整个透传设备。如果设备上有 LVM，需要指定逻辑卷设备名作为第二个参数：

```bash
sudo ./linsk run --share-backend ftp "dev:/dev/disk4" testvg/testlv
```

或者指定为 `/dev/mapper/testvg-testlv`：

```bash
sudo ./linsk run --share-backend ftp "dev:/dev/disk4" mapper/testvg-testlv
```

### 4.2 连接 FTP

使用任意 FTP 客户端连接：
- 地址：`ftp://127.0.0.1:2121`（默认端口，以实际输出为准）
- 用户名/密码：程序启动时会自动生成并显示

### 4.3 浏览 LVM 逻辑卷

FTP 根目录会映射到 VM 中的挂载点 `/mnt`。

---

## 五、清理

```bash
# 删除 Linsk 数据目录（含 VM 镜像）
./linsk clean

# 或手动删除
rm -rf ~/.linsk
```

---

## 六、常见问题

### 6.1 编译时提示 "no matching files found"

确保资源文件已放入 `assets/files/` 目录，文件名与 `assets/embed.go` 中 `//go:embed` 指令一致。

### 6.2 "device passthrough requires root"

`linsk` 的透传功能需要 root 权限运行。

### 6.3 USB 设备不稳定

macOS 上 USB 透传不稳定，建议使用 `dev:/dev/diskX` 块设备透传方式。

### 6.4 QEMU 启动报错 "Library not loaded: libglib-2.0.0.dylib"

Homebrew 升级后 glib 软链接可能失效。修复方法：

```bash
# 查看当前 glib 版本
ls /opt/homebrew/Homebrew/Cellar/glib/

# 重新创建软链接（将 x.x.x 替换为实际版本号）
rm -f /opt/homebrew/opt/glib
ln -s ../Homebrew/Cellar/glib/x.x.x /opt/homebrew/opt/glib
```

### 6.5 "image already exists"

之前构建失败导致残留文件。清理后重试：

```bash
sudo rm -rf ~/.linsk
sudo ./linsk build
```

或使用 `--overwrite`：

```bash
sudo ./linsk build --overwrite
```

### 6.6 "unknown filesystem type 'LVM2_member'"

`linsk run` 默认尝试挂载整个磁盘（如 `/dev/vdb`），但 LVM 逻辑卷需要指定具体的 LV 设备。使用第二个位置参数指定逻辑卷（格式为 `mapper/<vg>-<lv>`）：

```bash
sudo ./linsk run --share-backend ftp "dev:/dev/disk4" mapper/testvg-testlv
``` "unknown filesystem type 'LVM2_member'"

`linsk run` 默认尝试挂载整个磁盘（如 `/dev/vdb`），但 LVM 逻辑卷需要指定具体的 LV 设备。使用第二个位置参数指定逻辑卷：

```bash
sudo ./linsk run --share-backend ftp "dev:/dev/disk4" testvg/testlv
```

### 6.7 "Cannot use /dev/vdb: device is partitioned"

磁盘上已有分区表。如果确定要清除数据，先使用 `wipefs -a /dev/vdb` 清除分区表，再创建物理卷。
