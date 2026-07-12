# 小米 13 全系统 OverlayFS v1.0 实机测试报告

## 结论

版本 1.0 已在指定的小米 13 上通过实机测试。模块当前已安装并启用，手机可正常开机，Magisk Root、移动网络、5G 数据和 Wi-Fi 均正常。

## 测试设备

- 型号：小米 13（2211133C）
- 代号：fuxi
- Android：14
- MIUI：V14.0.5.0.UMCCNXM
- Magisk：alpha 30700，e8a58776-alpha
- 系统分区：EROFS
- 数据分区：F2FS
- SELinux：Enforcing
- 运营商：中国电信，双卡，5G NR

## 已通过项目

- 7 个主要系统目录及 MIUI 嵌套目录全部成功建立可写层。
- 37 个目录逐一执行新建、读取、改名和删除，失败 0。
- MiXplorer 进程能够看到模块挂载。
- `/system/etc/hosts` 修改可跨重启保留，恢复后 SHA-256 与原文件完全一致。
- 多次连续重启正常。
- 普通 `su` 和独立 Magisk 恢复入口均可取得 Root。
- 中国电信语音、短信和数据在网，5G NR 数据连接通过系统联网验证。
- Wi-Fi 可开启并可扫描。
- system_server、zygote64、netd、vold 正常运行。
- modem、DSP、蓝牙固件分区保持原设备和只读挂载。
- 禁用模块后可恢复原只读系统；重新启用后可写层正常恢复。

## 最终手机状态

- 模块：已安装、已启用
- Overlay 挂载：52 条模块相关记录
- Root：正常
- SELinux：Enforcing
- `/system/etc/hosts`：已恢复原内容
- 测试临时文件：已清理
- ext4 镜像：逻辑容量 4 GiB，实际使用约 628 KiB

## 安全边界

本模块不会覆盖根目录、虚拟文件系统、Magisk 恢复目录、基带固件、DSP、蓝牙固件和校准分区。这个边界用于保证正常开机、Root、移动网络、Wi-Fi 和硬件功能，不属于测试缺失。
