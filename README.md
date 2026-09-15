# DuoBarOnMac

一个原生 macOS 菜单栏状态工具：用一个简洁图标同时呈现 Mac 电池与 Wi‑Fi 状态。

最低支持 macOS 14。仓库包含完整 Swift 源码、自动化测试、构建脚本，以及一个可直接运行的预构建 `DuoBar.app`。

## 功能

- 菜单栏图标实时显示 Mac 内置电池电量。
- 在电池与 Wi‑Fi 状态之间切换中心显示内容。
- 显示 Wi‑Fi 连接状态、信号强度与网络名称（系统权限允许时）。
- 显示充电、低电量、充电暂停、Wi‑Fi 断开等状态。
- 显示已连接的蓝牙设备。
- 提供 SwiftUI 详情面板、登录时启动和退出操作。
- 不扫描附近网络。

## 直接运行

仓库根目录中的 `DuoBar.app` 是 Apple Silicon（arm64）预构建版本：

```sh
open DuoBar.app
```

该版本使用本地 ad-hoc 签名，没有 Apple Developer ID 公证。若 macOS 首次运行时弹出安全提示，请在系统设置的“隐私与安全性”中允许打开。

## 从源码构建

需要 Swift 5.10 或兼容版本，以及 macOS 14 或更高版本。

```sh
swift build
swift test --scratch-path /tmp/DuoBarOnMac-build
./Scripts/build-app.sh
open DuoBar.app
```

`Scripts/build-app.sh` 会生成 release 构建、组装 app bundle，并使用本地 ad-hoc 签名进行验证。

## 隐私说明

DuoBarOnMac 只读取显示状态所需的本机电池、Wi‑Fi、蓝牙和网络路径信息，不上传数据，也不会扫描附近 Wi‑Fi 网络。

## 作者与许可证

Copyright © 2026 Skyler（GitHub: [Longhorn5048](https://github.com/Longhorn5048)）。

本项目采用 [Apache License 2.0](LICENSE)。你可以自由使用、修改和商用，但再发布时必须保留版权与许可证声明，并遵守 `NOTICE` 中的署名要求。
