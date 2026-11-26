//
//  mac_menubar_calendarApp.swift
//  mac-menubar-calendar
//

import SwiftUI

@main
struct MenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("My App", systemImage: "calendar") {
            // メニューバーのアイコンをクリックした時に展開されるビュー
            ContentView()
        }
        .menuBarExtraStyle(.window) // .windowにするとポップオーバー風のUIになります
    }
}
