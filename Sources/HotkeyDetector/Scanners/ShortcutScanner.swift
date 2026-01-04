//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import ApplicationServices
import Cocoa

/// 快捷键信息模型
struct ShortcutInfo: Identifiable, Hashable {
    let id = UUID()
    let appName: String
    let menuTitle: String
    let shortcutKey: String
    let modifiers: String

    var displayShortcut: String {
        return modifiers + shortcutKey
    }
}

/// 快捷键扫描器
class ShortcutScanner: ObservableObject {
    @Published var shortcuts: [ShortcutInfo] = []
    @Published var isScanning = false

    /// 检查辅助功能权限
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    enum ScanMode: String, CaseIterable, Identifiable {
        case appsOnly = "应用快捷键"
        case systemOnly = "系统快捷键"
        case all = "所有快捷键"

        var id: String { rawValue }
    }

    /// 扫描应用
    func scan(mode: ScanMode = .appsOnly) {
        isScanning = true
        shortcuts.removeAll()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var foundShortcuts: [ShortcutInfo] = []

            // 1. 扫描系统快捷键
            if mode == .systemOnly || mode == .all {
                let systemScanner = SystemHotkeyScanner()  // Assuming SystemHotkeyScanner exists
                foundShortcuts.append(contentsOf: systemScanner.scan())
            }

            // 2. 扫描应用快捷键
            if mode == .appsOnly || mode == .all {
                let runningApps = NSWorkspace.shared.runningApplications
                let currentAppId = NSRunningApplication.current.processIdentifier

                for app in runningApps {
                    guard app.activationPolicy == .regular,
                        app.processIdentifier != currentAppId
                    else { continue }

                    let appElement = AXUIElementCreateApplication(app.processIdentifier)
                    var menuBar: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(
                        appElement, kAXMenuBarAttribute as CFString, &menuBar)

                    if result == .success, let menuBarElement = menuBar {
                        let appShortcuts = self?.findShortcuts(
                            in: menuBarElement as! AXUIElement, appName: app.localizedName ?? "未知应用"
                        )
                        foundShortcuts.append(contentsOf: appShortcuts ?? [])
                    }
                }
            }

            DispatchQueue.main.async {
                self?.shortcuts = foundShortcuts
                self?.isScanning = false
            }
        }
    }

    @available(*, deprecated, renamed: "scan(mode:)")
    func scanAllApps() {
        scan(mode: .appsOnly)
    }

    /// 递归查找菜单项中的快捷键
    private func findShortcuts(in element: AXUIElement, appName: String) -> [ShortcutInfo] {
        var result: [ShortcutInfo] = []

        var children: CFTypeRef?
        let axResult = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &children)

        guard axResult == .success, let childrenArray = children as? [AXUIElement] else {
            return result
        }

        for child in childrenArray {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)

            if (role as? String) == kAXMenuItemRole {
                var cmdChar: CFTypeRef?
                var modifiers: CFTypeRef?
                var title: CFTypeRef?

                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                let charResult = AXUIElementCopyAttributeValue(
                    child, kAXMenuItemCmdCharAttribute as CFString, &cmdChar)
                let modResult = AXUIElementCopyAttributeValue(
                    child, kAXMenuItemCmdModifiersAttribute as CFString, &modifiers)

                if charResult == .success, modResult == .success,
                    let char = cmdChar as? String, let mods = modifiers as? Int, !char.isEmpty
                {
                    let modString = decodeModifiers(mods)
                    // 处理特殊字符转换
                    let displayChar = formatKeyChar(char)

                    let info = ShortcutInfo(
                        appName: appName,
                        menuTitle: title as? String ?? "未知菜单项",
                        shortcutKey: displayChar,
                        modifiers: modString
                    )
                    result.append(info)
                }
            }

            // 递归处理子菜单
            result.append(contentsOf: findShortcuts(in: child, appName: appName))
        }

        return result
    }

    /// 格式化按键字符，处理特殊Unicode
    private func formatKeyChar(_ char: String) -> String {
        guard let scalar = char.unicodeScalars.first else { return char }
        let val = scalar.value

        // F1-F12 映射 (NSF1FunctionKey = 0xF704)
        if val >= 0xF704 && val <= 0xF70F {
            return "F\(val - 0xF704 + 1)"
        }
        // F13-F35
        if val >= 0xF710 && val <= 0xF726 {
            return "F\(val - 0xF710 + 13)"
        }

        switch val {
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF728: return "⌦"  // Forward Delete
        case 0xF739: return "⌫"  // Clear/Delete
        case 0x001B: return "⎋"  // Esc
        case 0x0009: return "⇥"  // Tab
        case 0x000D, 0x0003: return "↩"  // Return/Enter
        case 0x0020: return "Space"
        default: return char.uppercased()
        }
    }

    /// 解码修饰键位掩码
    private func decodeModifiers(_ mods: Int) -> String {
        var result = ""
        // 标准 AXMenuItemCmdModifiers 映射:
        // 0 = Command only
        // 1 = Shift + Command
        // 2 = Option + Command
        // 4 = Control + Command
        // 8 = No Command (kMenuNoCommandModifier)

        if (mods & 0x04) != 0 { result += "⌃" }  // Control
        if (mods & 0x02) != 0 { result += "⌥" }  // Option
        if (mods & 0x01) != 0 { result += "⇧" }  // Shift

        // 只有当第3位没有被设置时，才添加 Command
        if (mods & 0x08) == 0 {
            result += "⌘"
        }

        return result
    }
}
