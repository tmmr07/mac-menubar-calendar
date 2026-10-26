//
//  mac_menubar_calendarApp.swift
//  mac-menubar-calendar
//
//  Created by k22129kk on 2026/10/26.
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
