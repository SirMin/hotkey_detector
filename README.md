# Hotkey Detector

Hotkey Detector 是一个 macOS 应用程序，旨在帮助开发者和用户识别、管理和冲突检测快捷键。

它能够扫描当前运行的所有应用程序的菜单快捷键，以及 macOS 系统层面的全局快捷键（如 Spotlight、输入法切换等），并提供实时的按键监听功能来识别当前按下的组合键被谁占用了。

<p align="center">
  <img src="Sources/HotkeyDetector/Resources/AppIcon.png" width="128" heigh="128" alt="App Icon">
</p>

## ✨ 主要功能

*   **全方位扫描**：
    *   🔍 **应用快捷键**：自动扫描所有正在运行的应用的菜单栏快捷键。
    *   🖥️ **系统快捷键**：解析系统的 `com.apple.symbolichotkeys.plist`，识别系统级全局热键（如 Command+Space）。
    *   🎹 **混合模式**：同时查看系统和应用的所有快捷键配置。
*   **实时监听**：
    *   按下任意快捷键组合，应用会实时显示捕获到的键码和修饰符。
    *   自动匹配并高亮显示该快捷键可能属于哪个应用或系统功能。
*   **智能搜索**：
    *   支持搜索应用名称、菜单项标题。
    *   支持直接搜索按键（如 "F1", "Space", "Cmd"）。
*   **现代化界面**：
    *   基于 SwiftUI 构建，适配 macOS 最新设计风格。
    *   支持明暗模式。

## 🛠️ 技术要求

*   **macOS**: 13.0 (Ventura) 及以上
*   **Xcode**: 14.0+ (用于编译)
*   **Swift**: 5.7+

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/SirMin/hotkey_detector.git
cd hotkey_detector
```

### 2. 运行项目
使用 Swift Package Manager 直接运行：

```bash
swift run HotkeyDetector
```

```bash
swift run HotkeyDetector
```

或者使用 Xcode 打开 `Package.swift` 文件进行编译和运行。

### 3. 构建发布包 (推荐)
本项目包含一个自动化构建脚本，可以一键生成 `.app` 应用和 `.dmg` 安装包：

```bash
# 赋予脚本执行权限（仅需一次）
chmod +x build/build.sh

# 运行构建
./build/build.sh
```

构建完成后，你可以在 `.build/` 目录下找到：
*   `HotkeyDetector.app`：可直接运行的应用程序。
*   `HotkeyDetector.dmg`：用于分发的安装镜像。

### 4. 授予权限
为了扫描其他应用的菜单和监听全局键盘事件，**必须**授予应用“辅助功能”权限。

1.  首次运行时，应用会提示请求权限。
2.  打开 **系统设置** -> **隐私与安全性** -> **辅助功能**。
3.  找到 `HotkeyDetector`（或者是你的终端应用，如 Terminal/iTerm2，如果是通过终端运行的话）并开启开关。
4.  重启应用以使权限生效。

## 📂 项目结构

本项目采用标准的 Swift SPM 结构：

```text
Sources/HotkeyDetector/
├── App/                # 应用入口与生命周期管理
├── Views/              # SwiftUI 视图 (MainView)
├── Scanners/           # 核心逻辑
│   ├── ShortcutScanner.swift   # 应用菜单扫描
│   ├── SystemHotkeyScanner.swift # 系统配置扫描
│   └── HotkeyMonitor.swift     # 实时按键监听
└── Resources/          # 资源文件 (图标等)
```

## ⚠️ 常见问题

**Q: 为什么没有任何快捷键显示？**
A: 请确保你已经授予了辅助功能权限。如果没有权限，应用无法读取其他应用的菜单栏信息，也无法监听全局按键。

**Q: 系统快捷键显示不全？**
A: 应用读取的是 `symbolichotkeys` 配置文件。某些由第三方软件修改或特殊的系统快捷键可能无法被标准 API 读取。

## 📝 License

Apache License 2.0

