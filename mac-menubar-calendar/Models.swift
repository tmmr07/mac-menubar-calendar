//
//  Models.swift
//  mac-menubar-calendar
//

import Foundation
import SwiftUI

// MARK: - Google API用モデル

struct CalendarResponse: Decodable {
    let items: [CalendarEvent]?
}

struct CalendarEvent: Identifiable, Decodable {
    let id: String
    let summary: String?
    let start: EventDateTime?
    let end: EventDateTime?
}

struct EventDateTime: Decodable {
    let dateTime: String?
    let date: String?
}

struct TaskResponse: Decodable {
    let items: [TaskItem]?
}

struct TaskItem: Identifiable, Decodable {
    let id: String
    let title: String?
    let due: String?
}

// MARK: - アプリ独自追加用モデル（4列目用）

enum TaskCategory: String, CaseIterable, Codable, Identifiable {
    case thesis = "修論"
    case correction = "添削"
    case jobHunting = "就活"
    case other = "その他"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .thesis: return .red
        case .correction: return .green
        case .jobHunting: return .cyan // 水色
        case .other: return .purple
        }
    }
}

struct CustomTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var category: TaskCategory
}

struct CustomEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
}
