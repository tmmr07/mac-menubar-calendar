//
//  Models.swift
//  mac-menubar-calendar
//
//  Created by k22129kk on 2026/10/26.
//

import Foundation

// カレンダーAPIのレスポンス全体
struct CalendarResponse: Decodable {
    let items: [CalendarEvent]?
}

// 個別の予定データ（Listで扱うためにIdentifiableに準拠）
struct CalendarEvent: Identifiable, Decodable {
    let id: String
    let summary: String? // 予定のタイトル
    let start: EventDateTime?
    let end: EventDateTime?
}

// 日時データ
struct EventDateTime: Decodable {
    let dateTime: String? // 時間指定がある場合
    let date: String?     // 終日の場合
}
