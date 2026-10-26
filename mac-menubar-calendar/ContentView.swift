//
//  ContentView.swift
//  mac-menubar-calendar
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var authManager = GoogleAuthManager()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                HStack(alignment: .top, spacing: 0) {
                    // 左カラム：今日の予定（タイムライン表示）
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
                    
                    // 中央カラム：今日のタスク
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
                    
                    // 右カラム：明日の予定とタスク（上下分割）
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
        .frame(width: 800, height: 500)
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

// MARK: - タイムライン表示用ビュー

struct DailyTimelineView: View {
    let events: [CalendarEvent]
    let hourHeight: CGFloat = 45 // 1時間あたりの縦幅
    
    // 終日の予定
    var allDayEvents: [CalendarEvent] {
        events.filter { $0.start?.date != nil }
    }
    // 時間指定のある予定
    var timedEvents: [CalendarEvent] {
        events.filter { $0.start?.dateTime != nil }
    }
    
    var body: some View {
        ScrollView {
            // 自動スクロール用のリーダーを追加
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 8) {
                    
                    // 1. 終日予定エリア（上部）
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
                    
                    // 2. タイムラインエリア
                    ZStack(alignment: .topLeading) {
                        // 背景グリッド（0時〜24時）
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
                                // スクロール先として時間（0〜24）のIDを付与
                                .id(hour)
                            }
                        }
                        
                        // 予定ブロックを配置
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
                    // 画面が表示されたときに、現在の時間の1時間前を計算してスクロール
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    // 0時を下回らないように制御
                    let targetHour = max(0, currentHour - 1)
                    
                    // UIの描画が完了した直後にスクロールさせる
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

// タイムライン上の個別イベントブロック
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

// MARK: - リスト表示用ビュー（右カラムで使用）

struct EventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(event.summary ?? "タイトルなし")
                .font(.body)
                .bold()
            
            if let dateTime = event.start?.dateTime {
                Text(dateTime.prefix(16).replacingOccurrences(of: "T", with: " "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let date = event.start?.date {
                Text("終日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
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
