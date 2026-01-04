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
import Carbon
import Cocoa

/// 按键事件信息
struct KeyEventInfo: Equatable {
    let keyCode: Int64
    let modifiers: CGEventFlags
    let keyChar: String
    let timestamp: Date

    var displayModifiers: String {
        var result = ""
        if modifiers.contains(.maskControl) { result += "⌃" }
        if modifiers.contains(.maskAlternate) { result += "⌥" }
        if modifiers.contains(.maskShift) { result += "⇧" }
        if modifiers.contains(.maskCommand) { result += "⌘" }
        return result
    }

    var displayShortcut: String {
        return displayModifiers + keyChar.uppercased()
    }
}

/// 全局热键监听器
class HotkeyMonitor: ObservableObject {
    @Published var lastKeyEvent: KeyEventInfo?
    @Published var isMonitoring = false
    @Published var hasPermission = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        checkPermission()
    }

    /// 检查辅助功能权限
    func checkPermission() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(options)
    }

    /// 请求辅助功能权限
    func requestPermission() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // 延迟检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkPermission()
        }
    }

    /// 开始监听
    func startMonitoring() {
        guard hasPermission else {
            requestPermission()
            return
        }

        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // 创建事件回调
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let keyChar = monitor.keyCodeToString(keyCode)

                let info = KeyEventInfo(
                    keyCode: keyCode,
                    modifiers: flags,
                    keyChar: keyChar,
                    timestamp: Date()
                )

                DispatchQueue.main.async {
                    monitor.lastKeyEvent = info
                }
            }

            // 允许事件继续传递
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap = eventTap else {
            print("无法创建事件监听器，请检查辅助功能权限")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isMonitoring = true
    }

    /// 停止监听
    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
    }

    /// 将键码转换为字符串
    private func keyCodeToString(_ keyCode: Int64) -> String {
        // 常用键码映射
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

    deinit {
        stopMonitoring()
    }
}
