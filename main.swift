import ApplicationServices
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
import Cocoa

// 检查辅助功能权限
func checkAccessibilityPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}

// 递归遍历菜单项
func findShortcuts(in element: AXUIElement, appName: String) {
    var children: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)

    guard result == .success, let childrenArray = children as? [AXUIElement] else { return }

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

            if charResult == .success, modResult == .success, let char = cmdChar as? String,
                let mods = modifiers as? Int, !char.isEmpty
            {
                let modString = decodeModifiers(mods)
                print("[\(appName)] 发现快捷键: \(modString)\(char) -> \(title as? String ?? "未知菜单项")")
            }
        }

        // 递归处理子菜单
        findShortcuts(in: child, appName: appName)
    }
}

// 解码修饰键位掩码
func decodeModifiers(_ mods: Int) -> String {
    var result = ""
    if (mods & 0x01) != 0 { result += "⇧" }  // Shift
    if (mods & 0x02) != 0 { result += "⌥" }  // Option
    if (mods & 0x04) != 0 { result += "⌃" }  // Control
    if (mods & 0x08) == 0 { result += "⌘" }  // Command (Default is usually Command unless bit 8 is set? Actually bit 8 being 0 usually means Command is included in some Carbon contexts, but for AX it's simpler)

    // 注意: AXMenuItemCmdModifiers 的具体位映射可能因应用而异，
    // 标准映射通常是: 0=None, 1=Shift, 2=Option, 4=Control, 8=NoCommand (特殊)
    // 这里简化处理，Command 默认通常是存在的。
    return result
}

print("开始扫描运行中的应用快捷键...")

if !checkAccessibilityPermissions() {
    print("错误: 请在“系统设置 > 隐私与安全性 > 辅助功能”中允许终端运行。")
}

let runningApps = NSWorkspace.shared.runningApplications
for app in runningApps {
    if app.activationPolicy == .regular {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXMenuBarAttribute as CFString, &menuBar)

        if result == .success {
            findShortcuts(in: menuBar as! AXUIElement, appName: app.localizedName ?? "未知应用")
        }
    }
}

print("扫描完成。")
