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
import Foundation

/// 系统快捷键扫描器
class SystemHotkeyScanner {
    // 常见的 Action ID 映射
    // 参考: https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.15.sdk/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h
    private let actionNames: [Int: String] = [
        64: "Spotlight 搜索",
        65: "Spotlight 窗口",
        32: "调度中心 (Mission Control)",
        33: "应用程序窗口",
        34: "显示桌面",
        35: "Dashboard",
        79: "切换到上一个输入源",
        80: "切换到下一个输入源",
        81: "切换到上一个输入源 (冲突)",
        82: "切换到下一个输入源 (冲突)",
        60: "输入法菜单",
        61: "显示帮助菜单",
        175: "截取屏幕",
        28: "截取屏幕到剪贴板",
        29: "截取主要窗口",
        30: "截取主要窗口到剪贴板",
        31: "截取选择区域",
        // 其他常见的系统快捷键可以继续添加
        12: "隐藏/显示 Dock",
        57: "服务菜单",
    ]

    /// 扫描系统快捷键
    func scan() -> [ShortcutInfo] {
        var results: [ShortcutInfo] = []
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let plistPath = homeDir.appendingPathComponent(
            "Library/Preferences/com.apple.symbolichotkeys.plist")

        guard let data = try? Data(contentsOf: plistPath),
            let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any],
            let hotkeys = plist["AppleSymbolicHotKeys"] as? [String: Any]
        else {
            print("无法读取系统快捷键配置: \(plistPath)")
            return results
        }

        for (key, value) in hotkeys {
            guard let actionID = Int(key),
                let info = value as? [String: Any],
                // 注意：enabled 字段可能不准确，或者即便为 false 也可能占用键位
                // 我们主要依靠 parameters 中的键码来判断
                let dict = info["value"] as? [String: Any],
                let parameters = dict["parameters"] as? [Int],
                parameters.count >= 3
            else { continue }

            let keyCode = parameters[1]
            let modifiers = parameters[2]

            // 如果键码是 65535 (0xFFFF)，表示没有绑定键
            guard keyCode != 65535 else { continue }

            let name = actionNames[actionID] ?? "系统操作 (ID: \(actionID))"
            let shortcutChar = keyCodeToString(Int64(keyCode))
            let modString = decodeModifiers(modifiers)

            results.append(
                ShortcutInfo(
                    appName: "系统",
                    menuTitle: name,
                    shortcutKey: shortcutChar,
                    modifiers: modString
                ))
        }

        return results
    }

    /// 将键码转换为字符串
    private func keyCodeToString(_ keyCode: Int64) -> String {
        let keyCodeMap: [Int64: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋",
            // 功能键
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 118: "F4", 120: "F2", 122: "F1",
            // 方向键
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]

        return keyCodeMap[keyCode] ?? "Key\(keyCode)"
    }

    private func decodeModifiers(_ mods: Int) -> String {
        var result = ""
        // 标准 Carbon modifiers
        // cmdKey = 1 << 20
        // shiftKey = 1 << 17
        // alphaKey = 1 << 16 (caps lock?)
        // optionKey = 1 << 19
        // controlKey = 1 << 18

        // 这里的 modifiers 值可能和 AX API 不同，需要验证
        // com.apple.symbolichotkeys 使用的是 CGEventFlags 对应的位还是 Carbon 位？
        // 经过查证，parameters[2] 是 modifier flags。
        // Shift=131072, Control=262144, Option=524288, Command=1048576

        if (mods & 131072) != 0 { result += "⇧" }
        if (mods & 262144) != 0 { result += "⌃" }
        if (mods & 524288) != 0 { result += "⌥" }
        if (mods & 1_048_576) != 0 { result += "⌘" }

        return result
    }
}
