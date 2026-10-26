import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = GoogleAuthManager()
    
    var body: some View {
        VStack {
            if authManager.isAuthenticated {
                // 認証成功時のUI：取得したカレンダーの予定を表示
                VStack {
                    HStack {
                        Text("直近の予定")
                            .font(.headline)
                        Spacer()
                        // 手動更新ボタン
                        Button(action: {
                            authManager.fetchCalendarEvents()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    List(authManager.events) { event in
                        VStack(alignment: .leading) {
                            Text(event.summary ?? "タイトルなし")
                                .font(.body)
                                .bold()
                            
                            // 時間がある場合と終日の場合で表示を分ける
                            if let dateTime = event.start?.dateTime {
                                Text(dateTime.prefix(16).replacingOccurrences(of: "T", with: " "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let date = event.start?.date {
                                Text("終日: \(date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
                .onAppear {
                    // 画面が表示された瞬間に自動で予定を取得
                    authManager.fetchCalendarEvents()
                }
            } else {
                // 認証前のUI
                Image(systemName: "calendar.badge.exclamationmark")
                    .imageScale(.large)
                    .foregroundStyle(.red)
                Text("Google連携が必要です")
                
                Button("Googleでログイン") {
                    authManager.signIn()
                }
                .padding(.top, 10)
                .buttonStyle(.borderedProminent)
            }
        }
        // メニューバーアプリのウィンドウサイズを指定（リスト表示用に高さを拡張）
        .frame(width: 300, height: 400)
    }
}

#Preview {
    ContentView()
}
