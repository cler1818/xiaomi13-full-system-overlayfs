# 小米 13 全系统 OverlayFS 可读写模块

> 来源说明：本仓库 Fork 并改编自 [Zenlua/Overlayfs](https://github.com/Zenlua/Overlayfs)，在其按目录 OverlayFS 思路基础上，为 `cler1818` 的小米 13、Android 14 和 MIUI 系统重新设计 ext4 写入层、全系统挂载拓扑、Magisk 保护与事务回滚流程。

这是为 `cler1818` 的小米 13 实机适配和验证的 Magisk 模块。模块使用一个持久化的 4 GiB 稀疏 ext4 镜像作为 OverlayFS 写入层，让主要动态系统分区以及 MIUI 的嵌套系统目录可以直接增删、修改和重命名文件。

## 版本信息

- 模块版本：1.0
- 作者：cler1818
- 模块 ID：`cler1818_full_system_overlayfs`
- 工作模式：Android 完成开机后延迟挂载
- 写入层：4 GiB 稀疏 ext4 镜像

## 实机参数

- 手机：小米 13
- 设备型号：2211133C
- 设备代号：fuxi
- Android：14
- MIUI：V14.0.5.0.UMCCNXM
- 系统分区格式：EROFS
- 数据分区格式：F2FS
- Magisk：alpha 30700，e8a58776-alpha
- 处理器架构：arm64-v8a
- SELinux：Enforcing
- 测试运营商：中国电信，双卡，5G NR

## 可写范围

模块覆盖以下主要系统目录，并为检测到的小米嵌套系统挂载建立独立写入层：

- `/system`
- `/system_ext`
- `/product`
- `/vendor`
- `/odm`
- `/vendor_dlkm`
- `/system_dlkm`
- MIUI 的 app、priv-app、framework、lib、etc、permissions、sysconfig 等嵌套目录

## 安全例外

“全系统可写”不代表覆盖 Android 的每一个运行时挂载。为了保证正常开机、Magisk Root、移动网络、Wi-Fi、蓝牙和硬件校准，下列位置不会被改造成写入层：

- 根目录 `/`
- `/data`、`/dev`、`/proc`、`/sys`、`/apex`、`/debug_ramdisk` 等运行时或虚拟文件系统
- `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`
- `/mnt/vendor/persist` 以及其他基带、校准、固件分区

这些例外不是普通 EROFS 系统文件。覆盖它们会增加丢失 Root、基带、Wi-Fi、蓝牙或相机功能的风险。

## 使用说明

1. 必须使用已 Root 的小米 13，且系统参数与上面的实机环境一致。
2. 如果安装过 `zenlua_etc_ext4` 测试模块，请先卸载并重启。
3. 在 Magisk 中安装 ZIP 后重启。
4. 模块会在系统完成开机后等待 30 秒，再建立写入层。
5. 修改内容保存在 `/data/adb/cler1818_full_system_overlayfs.img`，不会直接写入 EROFS 原分区。

## 实机测试结果

测试日期：2026 年 7 月 12 日。

- 37 个目标目录逐一完成新建、读取、改名和删除，失败 0。
- 7 个主要系统目录的修改均可跨重启保留。
- `/system/etc/hosts` 实际修改后跨重启保留，随后成功恢复原内容和原 SHA-256。
- 连续多次重启均正常完成开机，模块最终保持启用。
- Magisk 普通 `su` 与 `/debug_ramdisk/magisk su` 均返回 Root。
- MiXplorer 进程命名空间可见全部模块挂载。
- 中国电信语音与数据均为 `IN_SERVICE`，5G NR 数据为 `CONNECTED`、`VALIDATED`。
- Wi-Fi 可开启并可扫描；测试时未连接无线网络。
- modem、DSP、蓝牙固件挂载的来源与只读状态保持不变。
- SELinux 始终为 Enforcing，system_server、zygote64、netd、vold 均正常。
- 禁用模块并重启后，模块挂载数恢复为 0，系统目录恢复只读；重新启用后可写层和历史修改正常恢复。
- 4 GiB ext4 镜像完成测试后实际使用约 628 KiB，剩余空间约 3.8 GiB。

日志中可能出现部分原 MIUI 目录 `Device or resource busy`。这是先尝试普通卸载、再使用惰性卸载分离正在被系统进程引用的旧只读层时产生的预期记录；只要日志最后显示“全部 Overlay 挂载与基础健康检查通过”即为成功。

## 恢复方法

- 在 Magisk 中禁用模块并重启，可恢复原始只读视图。
- 紧急情况下可创建 `/data/adb/cler1818_full_system_overlayfs.disable` 后重启。
- 模块 Action 可即时关闭写入层；如果目录正被进程占用，建议禁用模块后重启。
- 卸载模块默认保留 ext4 镜像，避免误删修改数据。确认不要数据后，再手动删除该镜像。
- 独立 Root 恢复入口：`/debug_ramdisk/magisk su -c`。

## 来源与致谢

本项目是在公开项目和社区方案的基础上针对小米 13 重新设计、适配与实测：

- [Zenlua/Overlayfs](https://github.com/Zenlua/Overlayfs)：按目录建立 OverlayFS 的实现思路。
- [HuskyDG/magic_overlayfs](https://github.com/HuskyDG/magic_overlayfs) 及社区后继版本：Android 动态系统分区 OverlayFS 的早期实现与研究基础。
- [bnsmb/scripts-for-Android](https://github.com/bnsmb/scripts-for-Android)：XDA Overlay 挂载方案和目录冲突处理思路。
- [XDA：How to use overlay mounts in Android](https://xdaforums.com/t/guide-how-to-use-overlay-mounts-in-android-to-make-system-and-other-directories-writable.4746279/)：新式独立目录 Overlay 的讨论和示例。

上游作者保留其原有项目和代码的权利。本模块的设备适配、ext4 写入层、挂载拓扑、事务回滚及中文文档由 `cler1818` 版本维护。

## 风险提示

修改 framework、系统应用、权限 XML、共享库、启动脚本或厂商配置仍可能造成应用崩溃、系统异常或下次开机故障。OverlayFS 便于恢复，但不会让错误修改变得无风险。修改前应保留文件副本，并确保 ADB 和 `/debug_ramdisk/magisk` 恢复通道可用。
