//
//  Models.swift
//  mac-menubar-calendar
//

import Foundation

// カレンダーAPIのレスポンス全体
struct CalendarResponse: Decodable {
    let items: [CalendarEvent]?
}

// 個別の予定データ
struct CalendarEvent: Identifiable, Decodable {
    let id: String
    let summary: String?
    let start: EventDateTime?
    let end: EventDateTime?
}

struct EventDateTime: Decodable {
    let dateTime: String? // 時間指定がある場合
    let date: String?     // 終日の場合
}

// --- 追加: タスクAPIのレスポンス全体 ---
struct TaskResponse: Decodable {
    let items: [TaskItem]?
}

// 個別のタスクデータ
struct TaskItem: Identifiable, Decodable {
    let id: String
    let title: String?
    let due: String? // "2023-10-26T00:00:00.000Z" のような形式
}
