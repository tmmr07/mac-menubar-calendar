//
//  ContentView.swift
//  mac-menubar-calendar
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var authManager = GoogleAuthManager()
    @Environment(\.dismiss) var dismiss
    
    @State private var isShowingAddTaskModal = false
    @State private var isShowingAddEventModal = false
    
    var body: some View {
        ZStack {
            // メインコンテンツ
            VStack(spacing: 0) {
                if authManager.isAuthenticated {
                    HStack(alignment: .top, spacing: 0) {
                        // 1列目（左）：今日の予定（タイムライン表示）
                        VStack(alignment: .leading, spacing: 0) {
                            Text("今日の予定")
                                .font(.headline)
                                .padding(.bottom, 8)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            DailyTimelineView(events: authManager.todayEvents)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        // 2列目（中左）：今日のタスク
                        VStack(alignment: .leading) {
                            Text("今日のタスク")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            List(authManager.todayTasks) { task in
                                TaskRowView(task: task)
                            }
                            .listStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        
                        Divider()
                        
                        // 3列目（中右）：明日の予定（上）と明日のタスク（下）
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading) {
                                Text("明日の予定")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                List(authManager.tomorrowEvents) { event in
                                    EventRowView(event: event)
                                }
                                .listStyle(.plain)
                            }
                            .frame(maxHeight: .infinity)
                            .padding()
                            
                            Divider()
                            
                            VStack(alignment: .leading) {
                                Text("明日のタスク")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                List(authManager.tomorrowTasks) { task in
                                    TaskRowView(task: task)
                                }
                                .listStyle(.plain)
                            }
                            .frame(maxHeight: .infinity)
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                        
                        // 4列目（一番右）：今後のタスク（上）と今後の予定（下）［アプリ独自管理］
                        VStack(alignment: .leading, spacing: 0) {
                            // 上半分：今後のタスク
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("今後のタスク")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        isShowingAddTaskModal = true
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .help("タスクを追加")
                                }
                                .padding(.bottom, 4)
                                
                                List(authManager.customTasks) { task in
                                    CustomTaskRowView(task: task) {
                                        authManager.deleteCustomTask(id: task.id)
                                    }
                                }
                                .listStyle(.plain)
                            }
                            .frame(maxHeight: .infinity)
                            .padding()
                            
                            Divider()
                            
                            // 下半分：今後の予定
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("今後の予定")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        isShowingAddEventModal = true
                                    }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .help("予定を追加")
                                }
                                .padding(.bottom, 4)
                                
                                List(authManager.customEvents) { event in
                                    CustomEventRowView(event: event) {
                                        authManager.deleteCustomEvent(id: event.id)
                                    }
                                }
                                .listStyle(.plain)
                            }
                            .frame(maxHeight: .infinity)
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    
                    Divider()
                    
                    // 下部：ボタンエリア
                    HStack {
                        Button(action: {
                            authManager.logout()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(.plain)
                        .help("ログアウト")
                        
                        Spacer()
                        
                        Button("予定を編集") {
                            openInChrome(url: "https://calendar.google.com/calendar/u/0/r/day?pli=1")
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("予定を追加") {
                            openInChrome(url: "https://calendar.google.com/calendar/u/0/r/month")
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Button(action: {
                            authManager.fetchAllData()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("手動更新")
                    }
                    .padding()
                    
                } else {
                    // 認証前UI
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .imageScale(.large)
                            .foregroundStyle(.red)
                        Text("Google連携が必要です")
                        Button("Googleでログイン") {
                            authManager.signIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            // MARK: - 画面内インラインオーバーレイ
            
            if isShowingAddTaskModal {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowingAddTaskModal = false
                    }
                
                AddCustomTaskView(
                    onAdd: { title, dueDate, category in
                        authManager.addCustomTask(title: title, dueDate: dueDate, category: category)
                        isShowingAddTaskModal = false
                    },
                    onCancel: {
                        isShowingAddTaskModal = false
                    }
                )
            }
            
            if isShowingAddEventModal {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowingAddEventModal = false
                    }
                
                AddCustomEventView(
                    onAdd: { title, startDate, endDate in
                        authManager.addCustomEvent(title: title, startDate: startDate, endDate: endDate)
                        isShowingAddEventModal = false
                    },
                    onCancel: {
                        isShowingAddEventModal = false
                    }
                )
            }
        }
        .frame(width: 1040, height: 500)
        .background(WindowPositioningView())
        .onAppear {
            if authManager.isAuthenticated {
                authManager.fetchAllData()
            }
        }
    }
    
    private func openInChrome(url urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let workspace = NSWorkspace.shared
        if let chromeURL = workspace.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            let configuration = NSWorkspace.OpenConfiguration()
            workspace.open([url], withApplicationAt: chromeURL, configuration: configuration, completionHandler: nil)
        } else {
            workspace.open(url)
        }
    }
}

// MARK: - 4列目用 追加インラインパネルビュー

struct AddCustomTaskView: View {
    @State private var title: String = ""
    @State private var dueDate: Date = Date()
    @State private var category: TaskCategory = .thesis
    
    var onAdd: (String, Date, TaskCategory) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今後のタスクを追加")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("タスクの内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: 関連研究のサーベイ完了", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("タスクの種類")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(TaskCategory.allCases) { cat in
                        Button(action: {
                            category = cat
                        }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(cat.color)
                                    .frame(width: 8, height: 8)
                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: category == cat ? .bold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(category == cat ? cat.color.opacity(0.2) : Color.gray.opacity(0.1))
                            .foregroundColor(category == cat ? cat.color : .primary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(category == cat ? cat.color : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("期限（カレンダーから選択）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                DatePicker("", selection: $dueDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            
            HStack {
                Spacer()
                Button("キャンセル") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("追加") {
                    if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAdd(title, dueDate, category)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}

struct AddCustomEventView: View {
    @State private var title: String = ""
    
    // 開始日時（日付 + テキスト編集＆プルダウン対応の時間）
    @State private var startDate: Date = Date()
    @State private var startHourText: String = "09"
    @State private var startMinuteText: String = "00"
    
    // 終了日時（日付 + テキスト編集＆プルダウン対応の時間）
    @State private var endDate: Date = Date()
    @State private var endHourText: String = "10"
    @State private var endMinuteText: String = "00"
    
    var onAdd: (String, Date, Date) -> Void
    var onCancel: () -> Void
    
    init(onAdd: @escaping (String, Date, Date) -> Void, onCancel: @escaping () -> Void) {
        self.onAdd = onAdd
        self.onCancel = onCancel
        
        // 初期値を現在時刻の次の正時に設定
        let cal = Calendar.current
        let now = Date()
        let currentHour = cal.component(.hour, from: now)
        let nextHour = (currentHour + 1) % 24
        let afterNextHour = (currentHour + 2) % 24
        
        _startHourText = State(initialValue: String(format: "%02d", nextHour))
        _startMinuteText = State(initialValue: "00")
        _endHourText = State(initialValue: String(format: "%02d", afterNextHour))
        _endMinuteText = State(initialValue: "00")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今後の予定を追加")
                .font(.headline)
            
            // 内容入力
            VStack(alignment: .leading, spacing: 4) {
                Text("予定の内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("例: 企業面談・ゼミ発表", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 左右に並べて開始と終了を選択
            HStack(alignment: .top, spacing: 16) {
                // 左側：開始日時
                VStack(alignment: .leading, spacing: 8) {
                    Text("開始日時")
                        .font(.subheadline)
                        .bold()
                    
                    DatePicker("", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: startDate) { _, newValue in
                            if endDate < newValue {
                                endDate = newValue
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("時間")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        EditableTimeInputView(
                            hourText: $startHourText,
                            minuteText: $startMinuteText
                        ) { newHour, newMin in
                            // 開始時間を変更した際、同日かつ終了時間が開始時間以前なら+1時間に自動調整
                            let startVal = newHour * 60 + newMin
                            let endVal = (Int(endHourText) ?? 0) * 60 + (Int(endMinuteText) ?? 0)
                            if Calendar.current.isDate(startDate, inSameDayAs: endDate) && endVal <= startVal {
                                let nextH = min(23, newHour + 1)
                                endHourText = String(format: "%02d", nextH)
                                endMinuteText = String(format: "%02d", newMin)
                            }
                        }
                    }
                    .zIndex(10) // ドロップダウンが他の要素の上に重なるようにする
                }
                .zIndex(2)
                
                Divider()
                    .frame(height: 290)
                
                // 右側：終了日時
                VStack(alignment: .leading, spacing: 8) {
                    Text("終了日時")
                        .font(.subheadline)
                        .bold()
                    
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("時間")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                        
                        EditableTimeInputView(
                            hourText: $endHourText,
                            minuteText: $endMinuteText
                        )
                    }
                    .zIndex(10)
                }
                .zIndex(1)
            }
            
            // ボタン
            HStack {
                Spacer()
                Button("キャンセル") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("追加") {
                    if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        let finalStart = combineDateAndTime(date: startDate, hourStr: startHourText, minuteStr: startMinuteText)
                        var finalEnd = combineDateAndTime(date: endDate, hourStr: endHourText, minuteStr: endMinuteText)
                        if finalEnd < finalStart {
                            finalEnd = finalStart
                        }
                        onAdd(title, finalStart, finalEnd)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
    
    // カレンダーの日付とテキストボックスの時・分を合体させてDateを生成
    private func combineDateAndTime(date: Date, hourStr: String, minuteStr: String) -> Date {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: date)
        let h = min(max(Int(hourStr) ?? 0, 0), 23)
        let m = min(max(Int(minuteStr) ?? 0, 0), 59)
        components.hour = h
        components.minute = m
        components.second = 0
        return cal.date(from: components) ?? date
    }
}

// MARK: - 直接入力＆プルダウン両対応の時間コンポーネント

struct EditableTimeInputView: View {
    @Binding var hourText: String
    @Binding var minuteText: String
    var onTimeChanged: ((Int, Int) -> Void)? = nil
    
    @State private var showHourDropdown = false
    @State private var showMinuteDropdown = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case hour, minute
    }
    
    // 00〜23（1時間刻み）
    let hours = Array(0...23).map { String(format: "%02d", $0) }
    // 00〜55（5分刻み）
    let minutes = stride(from: 0, through: 55, by: 5).map { String(format: "%02d", $0) }
    
    var body: some View {
        HStack(spacing: 6) {
            // 「時」ボックス
            timeBox(
                text: $hourText,
                isDropdownOpen: $showHourDropdown,
                otherDropdownOpen: $showMinuteDropdown,
                field: .hour,
                options: hours,
                maxVal: 23
            )
            
            Text("時")
                .font(.system(size: 13))
            
            // 「分」ボックス
            timeBox(
                text: $minuteText,
                isDropdownOpen: $showMinuteDropdown,
                otherDropdownOpen: $showHourDropdown,
                field: .minute,
                options: minutes,
                maxVal: 59
            )
            
            Text("分")
                .font(.system(size: 13))
        }
    }
    
    @ViewBuilder
    private func timeBox(
        text: Binding<String>,
        isDropdownOpen: Binding<Bool>,
        otherDropdownOpen: Binding<Bool>,
        field: Field,
        options: [String],
        maxVal: Int
    ) -> some View {
        HStack(spacing: 0) {
            // 数字の直接入力エリア
            TextField("00", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 32, height: 26)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, newValue in
                    // 数字のみ許可し、最大2文字に制限
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(2))
                    if filtered != newValue {
                        text.wrappedValue = filtered
                    }
                    if let val = Int(filtered), val > maxVal {
                        text.wrappedValue = String(format: "%02d", maxVal)
                    }
                    notifyChange()
                }
                .onChange(of: focusedField) { _, newFocus in
                    // フォーカスが外れた時に2桁ゼロ埋め整形（例: "7" -> "07"）
                    if newFocus != field {
                        formatTwoDigits(text: text, maxVal: maxVal)
                    }
                }
            
            // プルダウン開閉ボタン（▼）
            Button(action: {
                otherDropdownOpen.wrappedValue = false
                isDropdownOpen.wrappedValue.toggle()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(focusedField == field || isDropdownOpen.wrappedValue ? Color.accentColor : Color.gray.opacity(0.45), lineWidth: 1)
        )
        // 画面内にインライン展開するドロップダウンリスト（別ウィンドウを開かないためアプリが閉じない）
        .overlay(alignment: .bottomLeading) {
            if isDropdownOpen.wrappedValue {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                text.wrappedValue = option
                                isDropdownOpen.wrappedValue = false
                                notifyChange()
                            }) {
                                Text(option)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(text.wrappedValue == option ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(width: 52, height: 130)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: -2)
                // ボックスの上側に展開して見切れを防ぐ
                .offset(y: -30)
            }
        }
    }
    
    private func formatTwoDigits(text: Binding<String>, maxVal: Int) {
        let num = min(max(Int(text.wrappedValue) ?? 0, 0), maxVal)
        text.wrappedValue = String(format: "%02d", num)
        notifyChange()
    }
    
    private func notifyChange() {
        let h = min(max(Int(hourText) ?? 0, 0), 23)
        let m = min(max(Int(minuteText) ?? 0, 0), 59)
        onTimeChanged?(h, m)
    }
}

// MARK: - 4列目用 リスト行ビュー

struct CustomTaskRowView: View {
    let task: CustomTask
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.category.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.category.color.opacity(0.2))
                        .foregroundColor(task.category.color)
                        .cornerRadius(4)
                    
                    Text(task.title)
                        .font(.body)
                        .bold()
                        .lineLimit(2)
                }
                
                Text("締切：\(formatDate(task.dueDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("完了してリストから消す")
        }
        .padding(.vertical, 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
}

struct CustomEventRowView: View {
    let event: CustomEvent
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body)
                    .bold()
                    .lineLimit(2)
                
                Text(formatEventRange(start: event.startDate, end: event.endDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("予定を削除")
        }
        .padding(.vertical, 2)
    }
    
    private func formatEventRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startFormatter = DateFormatter()
        startFormatter.locale = Locale(identifier: "ja_JP")
        startFormatter.dateFormat = "M/d(E) H:mm"
        
        let endFormatter = DateFormatter()
        endFormatter.locale = Locale(identifier: "ja_JP")
        
        if calendar.isDate(start, inSameDayAs: end) {
            endFormatter.dateFormat = "H:mm"
        } else {
            endFormatter.dateFormat = "M/d(E) H:mm"
        }
        
        return "\(startFormatter.string(from: start)) - \(endFormatter.string(from: end))"
    }
}

// MARK: - ウィンドウを左右中央・上端配置に移動するヘルパー

// MARK: - ウィンドウを左右中央・上端配置に移動するヘルパー

struct WindowPositioningView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return PositioningNSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            PositioningNSView.moveWindowToTopCenter(window)
        }
    }
}

private class PositioningNSView: NSView {
    private var observers: [NSObjectProtocol] = []
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        
        guard let window = self.window else { return }
        
        DispatchQueue.main.async {
            Self.moveWindowToTopCenter(window)
        }
        
        // サイズ変更・2回目以降の再表示・アクティブ化のタイミングをすべて監視
        let notificationNames: [NSNotification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didChangeOcclusionStateNotification
        ]
        
        for name in notificationNames {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak window] _ in
                guard let window = window, window.isVisible else { return }
                Self.moveWindowToTopCenter(window)
            }
            observers.append(observer)
        }
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    static func moveWindowToTopCenter(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? window.screen
            ?? NSScreen.main
        
        guard let visibleFrame = screen?.visibleFrame else { return }
        
        let width = max(window.frame.width, 1040)
        let height = window.frame.height
        
        let centerX = visibleFrame.origin.x + (visibleFrame.width - width) / 2.0
        let topY = visibleFrame.maxY - height
        
        let currentOrigin = window.frame.origin
        if abs(currentOrigin.x - centerX) > 1 || abs(currentOrigin.y - topY) > 1 {
            window.setFrameOrigin(NSPoint(x: centerX, y: topY))
        }
    }
}

// MARK: - タイムライン表示用ビュー（1列目）

struct DailyTimelineView: View {
    let events: [CalendarEvent]
    let hourHeight: CGFloat = 45
    
    var allDayEvents: [CalendarEvent] {
        events.filter { $0.start?.date != nil }
    }
    var timedEvents: [CalendarEvent] {
        events.filter { $0.start?.dateTime != nil }
    }
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 8) {
                    if !allDayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(allDayEvents) { event in
                                Text(event.summary ?? "タイトルなし")
                                    .font(.caption)
                                    .bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<25) { hour in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(hourString(hour))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 45, alignment: .trailing)
                                        .offset(y: -6)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight, alignment: .top)
                                .id(hour)
                            }
                        }
                        
                        ForEach(timedEvents) { event in
                            if let startStr = event.start?.dateTime,
                               let endStr = event.end?.dateTime,
                               let start = parseDate(startStr),
                               let end = parseDate(endStr) {
                                
                                TimelineEventCard(event: event, start: start, end: end, hourHeight: hourHeight)
                            }
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 8)
                .onAppear {
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    let targetHour = max(0, currentHour - 1)
                    
                    DispatchQueue.main.async {
                        proxy.scrollTo(targetHour, anchor: .top)
                    }
                }
            }
        }
    }
    
    func hourString(_ hour: Int) -> String {
        if hour == 0 { return "午前0時" }
        else if hour < 12 { return "午前\(hour)時" }
        else if hour == 12 { return "午後12時" }
        else if hour == 24 { return "午前0時" }
        else { return "午後\(hour - 12)時" }
    }
    
    func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}

struct TimelineEventCard: View {
    let event: CalendarEvent
    let start: Date
    let end: Date
    let hourHeight: CGFloat
    
    var body: some View {
        let calendar = Calendar.current
        let startHour = CGFloat(calendar.component(.hour, from: start))
        let startMin = CGFloat(calendar.component(.minute, from: start))
        let durationMin = CGFloat(end.timeIntervalSince(start) / 60.0)
        
        let offsetY = (startHour * hourHeight) + (startMin / 60.0 * hourHeight)
        let height = max((durationMin / 60.0) * hourHeight, 15)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(event.summary ?? "タイトルなし")
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            
            Text("\(formatTime(start)) - \(formatTime(end))")
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height)
        .background(Color.blue.opacity(0.15))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
        )
        .padding(.leading, 53)
        .padding(.trailing, 0)
        .offset(y: offsetY)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 3列目用 リスト表示ビュー

struct EventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(event.summary ?? "タイトルなし")
                .font(.body)
                .bold()
            
            Text(formatEventTime())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func formatEventTime() -> String {
        if let dateTime = event.start?.dateTime,
           let date = ISO8601DateFormatter().date(from: dateTime) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "H:mm"
            return formatter.string(from: date)
        } else if event.start?.date != nil {
            return "終日"
        }
        return ""
    }
}

struct TaskRowView: View {
    let task: TaskItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.title ?? "無題のタスク")
                .font(.body)
                .bold()
            
            if let due = task.due {
                Text("締切：\(formatTaskDate(due))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatTaskDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ja_JP")
        outputFormatter.dateFormat = "M月d日"
        return outputFormatter.string(from: date)
    }
}
