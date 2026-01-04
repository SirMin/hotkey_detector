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
import SwiftUI

struct MainView: View {
    @StateObject private var hotkeyMonitor = HotkeyMonitor()
    @StateObject private var shortcutScanner = ShortcutScanner()
    @State private var searchText = ""
    @State private var selectedTab = 0

    var filteredShortcuts: [ShortcutInfo] {
        if searchText.isEmpty {
            return shortcutScanner.shortcuts
        } else {
            return shortcutScanner.shortcuts.filter { shortcut in
                shortcut.appName.localizedCaseInsensitiveContains(searchText)
                    || shortcut.menuTitle.localizedCaseInsensitiveContains(searchText)
                    || shortcut.displayShortcut.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // 侧边栏
            List {
                Section("功能") {
                    Label("实时监听", systemImage: "keyboard")
                        .tag(0)
                        .onTapGesture { selectedTab = 0 }
                        .foregroundColor(selectedTab == 0 ? .accentColor : .primary)

                    Label("快捷键列表", systemImage: "list.bullet")
                        .tag(1)
                        .onTapGesture { selectedTab = 1 }
                        .foregroundColor(selectedTab == 1 ? .accentColor : .primary)
                }

                Section("权限状态") {
                    HStack {
                        Image(
                            systemName: hotkeyMonitor.hasPermission
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(hotkeyMonitor.hasPermission ? .green : .red)
                        Text(hotkeyMonitor.hasPermission ? "已授权" : "未授权")
                    }

                    if !hotkeyMonitor.hasPermission {
                        Button("请求权限") {
                            hotkeyMonitor.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            // 主内容区
            if selectedTab == 0 {
                liveMonitorView
            } else {
                shortcutsListView
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            hotkeyMonitor.checkPermission()
            // 强制激活应用并获取焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        // 点击窗口背景时激活应用
        .onTapGesture {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - 实时监听视图
    private var liveMonitorView: some View {
        VStack(spacing: 20) {
            Text("实时按键监听")
                .font(.title)
                .fontWeight(.bold)

            Text("按下任意快捷键组合来检测")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 当前按键显示
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 300, height: 120)

                if let event = hotkeyMonitor.lastKeyEvent {
                    VStack(spacing: 8) {
                        Text(event.displayShortcut)
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("键码: \(event.keyCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("等待按键...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            // 监听控制按钮
            HStack(spacing: 16) {
                Button(action: {
                    if hotkeyMonitor.isMonitoring {
                        hotkeyMonitor.stopMonitoring()
                    } else {
                        hotkeyMonitor.startMonitoring()
                    }
                }) {
                    Label(
                        hotkeyMonitor.isMonitoring ? "停止监听" : "开始监听",
                        systemImage: hotkeyMonitor.isMonitoring ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(hotkeyMonitor.isMonitoring ? .red : .green)
            }

            // 查找匹配的快捷键
            if let event = hotkeyMonitor.lastKeyEvent {
                let matches = shortcutScanner.shortcuts.filter { shortcut in
                    shortcut.displayShortcut.uppercased() == event.displayShortcut.uppercased()
                }

                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("可能的占用应用:")
                            .font(.headline)

                        ForEach(matches) { match in
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundColor(.blue)
                                Text(match.appName)
                                    .fontWeight(.medium)
                                Text("→")
                                    .foregroundColor(.secondary)
                                Text(match.menuTitle)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Spacer()

            // 提示信息
            if !hotkeyMonitor.hasPermission {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("请先在'系统设置 > 隐私与安全性 > 辅助功能'中授予权限")
                        .font(.caption)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }

    // MARK: - 快捷键列表视图
    @State private var selectedScanMode: ShortcutScanner.ScanMode = .appsOnly

    private var shortcutsListView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("已发现的快捷键")
                    .font(.headline)

                Spacer()

                Picker("扫描模式", selection: $selectedScanMode) {
                    ForEach(ShortcutScanner.ScanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                .onChange(of: selectedScanMode) { newValue in
                    // 切换模式时自动扫描? 或者只是切换？
                    // 用户习惯可能倾向于切换即扫描
                    if !shortcutScanner.isScanning {
                        shortcutScanner.scan(mode: newValue)
                    }
                }

                Button(action: {
                    shortcutScanner.scan(mode: selectedScanMode)
                }) {
                    Label(
                        shortcutScanner.isScanning ? "扫描中..." : "刷新",
                        systemImage: "arrow.clockwise")
                }
                .disabled(shortcutScanner.isScanning)
            }
            .padding()

            // 快捷键表格
            if filteredShortcuts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(shortcutScanner.shortcuts.isEmpty ? "点击'扫描应用'开始扫描" : "没有找到匹配的快捷键")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                Table(filteredShortcuts) {
                    TableColumn("应用") { shortcut in
                        Text(shortcut.appName)
                            .fontWeight(.medium)
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn("菜单项") { shortcut in
                        Text(shortcut.menuTitle)
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("快捷键") { shortcut in
                        Text(shortcut.displayShortcut)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    .width(min: 80, ideal: 100)
                }
                .padding(.top, 8)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索应用名、菜单项或快捷键...")
    }
}

#Preview {
    MainView()
}
